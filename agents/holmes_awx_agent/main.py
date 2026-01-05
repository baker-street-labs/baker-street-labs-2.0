"""
Holmes AWX Agent - FastAPI service.

Features:
    - Authenticated API for submitting AWX job template requests
    - Async background processing with in-memory job tracking
    - Job template discovery and management
"""

import asyncio
import logging
from uuid import UUID

from fastapi import FastAPI, Depends, Header, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse

from .config import get_settings
from .models import (
    JobTemplateRequest,
    OrchestrationRequest,
    AWXJob,
    OrchestrationJob,
    JobResponse,
    JobDetailResponse,
    OrchestrationResponse,
    OrchestrationDetailResponse,
    AWXAgentJobStatus,
    JobTemplateInfo,
)
from .job_manager import job_manager
from .awx_adapter import awx_adapter
from .llm_orchestrator import get_orchestrator
from .webhook_handler import register_webhook_routes

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Holmes AWX Agent",
    description="LLM-powered automation orchestrator for AWX (Ansible Automation Platform)",
    version="0.1.0",
)

# Register webhook routes
register_webhook_routes(app)


def verify_token(x_holmes_awx_token: str = Header(None)) -> str:
    """Simple token-based auth guard (placeholder for StepCA/OIDC)."""
    settings = get_settings()
    if not x_holmes_awx_token or x_holmes_awx_token != settings.holmes_awx_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing X-Holmes-AWX-Token header.",
        )
    return x_holmes_awx_token


@app.get("/health", tags=["System"])
async def health() -> JSONResponse:
    """Health probe for liveness/readiness checks."""
    settings = get_settings()
    return JSONResponse(
        {
            "status": "ok",
            "service": "holmes-awx-agent",
            "awx_api_url": str(settings.awx_api_url),
            "llm_provider": settings.llm_provider,
        }
    )


@app.get("/v1/job-templates", tags=["Job Templates"])
async def list_job_templates(
    search: str = None,
    token: str = Depends(verify_token),
) -> JSONResponse:
    """List all AWX job templates, optionally filtered by search term."""
    try:
        templates = awx_adapter.list_job_templates(search=search)
        return JSONResponse(
            {
                "count": len(templates),
                "templates": [t.dict() for t in templates],
            }
        )
    except Exception as e:
        logger.error(f"Error listing job templates: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/job-templates/{template_id}", tags=["Job Templates"])
async def get_job_template(
    template_id: int,
    token: str = Depends(verify_token),
) -> JSONResponse:
    """Get a specific job template by ID."""
    try:
        template = awx_adapter.get_job_template(template_id)
        if not template:
            raise HTTPException(status_code=404, detail="Job template not found")
        return JSONResponse(template.dict())
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting job template: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/jobs", response_model=JobResponse, tags=["Jobs"])
async def submit_job(
    request: JobTemplateRequest,
    background: BackgroundTasks,
    token: str = Depends(verify_token),
) -> JobResponse:
    """Submit an AWX job template execution request."""
    # Validate that at least one template identifier is provided
    if not request.job_template_id and not request.job_template_name:
        raise HTTPException(
            status_code=400,
            detail="Either job_template_id or job_template_name must be provided",
        )
    
    job = AWXJob(request=request)
    job_manager.add_job(job)
    background.add_task(process_awx_job, job.job_id)
    logger.info("Queued job %s for template %s", job.job_id, request.job_template_name or request.job_template_id)
    return JobResponse(
        job_id=job.job_id,
        status=job.status,
        message="Job accepted for processing.",
    )


@app.get("/v1/jobs/{job_id}", response_model=JobDetailResponse, tags=["Jobs"])
async def get_job(job_id: UUID, token: str = Depends(verify_token)) -> JobDetailResponse:
    """Return job status and metadata."""
    job = job_manager.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    
    if not isinstance(job, AWXJob):
        raise HTTPException(status_code=400, detail="Job is not an AWX job.")
    
    return JobDetailResponse(
        job_id=job.job_id,
        status=job.status,
        requested_at=job.requested_at,
        completed_at=job.completed_at,
        request=job.request,
        message=job.message,
        awx_job_id=job.awx_job_id,
        awx_job_status=job.awx_job_status,
        awx_job_output=job.awx_job_output,
        awx_error=job.awx_error,
    )


async def process_awx_job(job_id: UUID) -> None:
    """Background worker for processing AWX job requests."""
    job = job_manager.get_job(job_id)
    if not job or not isinstance(job, AWXJob):
        logger.error("Job %s vanished before processing or wrong type.", job_id)
        return

    try:
        # Validate job template
        job_manager.update_status(job_id, AWXAgentJobStatus.VALIDATING, "Validating job template.")
        
        template_id = job.request.job_template_id
        if not template_id:
            # Search for template by name
            template = awx_adapter.search_job_template(job.request.job_template_name or "")
            if not template:
                raise ValueError(f"Job template '{job.request.job_template_name}' not found")
            template_id = template.id
            job.request.job_template_id = template_id
        
        # Verify template exists
        template = awx_adapter.get_job_template(template_id)
        if not template:
            raise ValueError(f"Job template ID {template_id} not found")

        # Launch job
        job_manager.update_status(job_id, AWXAgentJobStatus.LAUNCHING, f"Launching job template '{template.name}'.")
        
        awx_job_data = awx_adapter.launch_job_template(
            template_id=template_id,
            extra_vars=job.request.extra_vars or {},
            inventory_id=job.request.inventory_id,
            limit=job.request.limit,
        )
        
        awx_job_id = awx_job_data.get("id")
        if not awx_job_id:
            raise ValueError("AWX did not return a job ID")
        
        job.awx_job_id = awx_job_id
        job.awx_job_status = AWXJobStatus(awx_job_data.get("status", "new"))
        job_manager.update_status(
            job_id,
            AWXAgentJobStatus.MONITORING,
            f"Job launched with AWX job ID {awx_job_id}.",
            awx_job_id=awx_job_id,
            awx_job_status=job.awx_job_status,
        )

        # Monitor job (run in thread pool to avoid blocking)
        loop = asyncio.get_event_loop()
        job_data = await loop.run_in_executor(
            None,
            awx_adapter.wait_for_job,
            awx_job_id,
        )
        
        job.awx_job_status = AWXJobStatus(job_data.get("status", "error"))
        
        # Get job output
        try:
            job.awx_job_output = await loop.run_in_executor(
                None,
                awx_adapter.get_job_output,
                awx_job_id,
            )
        except Exception as e:
            logger.warning(f"Could not retrieve job output: {e}")
            job.awx_job_output = None

        # Determine final status
        if job.awx_job_status == AWXJobStatus.SUCCESSFUL:
            job_manager.update_status(
                job_id,
                AWXAgentJobStatus.COMPLETED,
                f"Job completed successfully. AWX job ID: {awx_job_id}",
            )
        else:
            error_msg = f"Job failed with status: {job.awx_job_status}"
            if job_data.get("job_explanation"):
                error_msg += f" - {job_data['job_explanation']}"
            job.awx_error = error_msg
            job_manager.update_status(
                job_id,
                AWXAgentJobStatus.FAILED,
                error_msg,
            )

    except Exception as e:
        logger.error(f"Error processing job {job_id}: {e}", exc_info=True)
        job.awx_error = str(e)
        job_manager.update_status(
            job_id,
            AWXAgentJobStatus.FAILED,
            f"Job processing failed: {e}",
        )


@app.post("/v1/orchestrate", response_model=OrchestrationResponse, tags=["Orchestration"])
async def submit_orchestration(
    request: OrchestrationRequest,
    background: BackgroundTasks,
    token: str = Depends(verify_token),
) -> OrchestrationResponse:
    """Submit a natural language orchestration request."""
    job = OrchestrationJob(request=request)
    job_manager.add_job(job)
    background.add_task(process_orchestration_job, job.job_id)
    logger.info("Queued orchestration job %s: %s", job.job_id, request.request[:100])
    return OrchestrationResponse(
        job_id=job.job_id,
        status=job.status,
        message="Orchestration request accepted for processing.",
    )


@app.get("/v1/orchestrate/{job_id}", response_model=OrchestrationDetailResponse, tags=["Orchestration"])
async def get_orchestration_job(
    job_id: UUID,
    token: str = Depends(verify_token),
) -> OrchestrationDetailResponse:
    """Return orchestration job status and metadata."""
    job = job_manager.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    
    if not isinstance(job, OrchestrationJob):
        raise HTTPException(status_code=400, detail="Job is not an orchestration job.")
    
    return OrchestrationDetailResponse(
        job_id=job.job_id,
        status=job.status,
        requested_at=job.requested_at,
        completed_at=job.completed_at,
        request=job.request,
        message=job.message,
        decomposed_tasks=job.decomposed_tasks,
        awx_jobs=[j.dict() for j in job.awx_jobs],
        llm_response=job.llm_response,
        llm_error=job.llm_error,
    )


async def process_orchestration_job(job_id: UUID) -> None:
    """Background worker for processing orchestration requests."""
    job = job_manager.get_job(job_id)
    if not job or not isinstance(job, OrchestrationJob):
        logger.error("Orchestration job %s vanished before processing or wrong type.", job_id)
        return

    try:
        job_manager.update_status(
            job_id,
            AWXAgentJobStatus.VALIDATING,
            "Analyzing request with LLM.",
        )
        
        # Get orchestrator
        orchestrator = get_orchestrator()
        
        # Run orchestration
        result = orchestrator.orchestrate(
            request=job.request.request,
            context=job.request.context,
        )
        
        job.llm_response = result.get("response")
        job.decomposed_tasks = result.get("steps", [])
        
        # Extract AWX job IDs from response
        awx_job_ids = result.get("awx_jobs", [])
        
        if awx_job_ids:
            job_manager.update_status(
                job_id,
                AWXAgentJobStatus.MONITORING,
                f"Orchestration completed. Launched {len(awx_job_ids)} AWX job(s).",
            )
            
            # Create AWXJob entries for tracking
            for awx_job_id in awx_job_ids:
                # Create a minimal AWXJob for tracking
                awx_job = AWXJob(
                    request=JobTemplateRequest(
                        job_template_id=None,
                        job_template_name="Orchestrated",
                        extra_vars={},
                    ),
                    awx_job_id=awx_job_id,
                )
                job.awx_jobs.append(awx_job)
        else:
            job_manager.update_status(
                job_id,
                AWXAgentJobStatus.COMPLETED,
                "Orchestration completed (no AWX jobs launched).",
            )
        
        # Mark as completed
        if job.status != AWXAgentJobStatus.COMPLETED:
            job_manager.update_status(
                job_id,
                AWXAgentJobStatus.COMPLETED,
                "Orchestration completed successfully.",
            )

    except Exception as e:
        logger.error(f"Error processing orchestration job {job_id}: {e}", exc_info=True)
        job.llm_error = str(e)
        job_manager.update_status(
            job_id,
            AWXAgentJobStatus.FAILED,
            f"Orchestration failed: {e}",
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=9001, reload=True)

