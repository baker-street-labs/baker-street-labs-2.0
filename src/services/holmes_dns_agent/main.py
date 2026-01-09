"""
Holmes DNS Agent - FastAPI service.

Features:
    - Authenticated API for submitting DNS record jobs
    - Async background processing with in-memory job tracking
    - Hooks for documentation/IPAM updates
"""

import asyncio
import logging
from uuid import UUID

from fastapi import FastAPI, Depends, Header, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse

from .config import get_settings
from .models import (
    RecordRequest,
    RecordJob,
    JobResponse,
    JobDetailResponse,
    RecordJobStatus,
)
from .job_manager import job_manager
from .pdns_adapter import pdns_adapter
from .technitium_adapter import technitium_adapter
from . import ipam_adapter

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Holmes DNS Agent",
    description="Automated DNS orchestration for Baker Street Labs",
    version="0.1.0",
)


def verify_token(x_holmes_token: str = Header(None)) -> str:
    """Simple token-based auth guard (placeholder for StepCA/OIDC)."""
    settings = get_settings()
    if not x_holmes_token or x_holmes_token != settings.holmes_api_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing X-Holmes-Token header.",
        )
    return x_holmes_token


@app.get("/health", tags=["System"])
async def health() -> JSONResponse:
    """Health probe for liveness/readiness checks."""
    settings = get_settings()
    health_data = {
        "status": "ok",
        "service": "holmes-dns-agent",
        "dns_backend": settings.dns_backend,
    }
    if settings.dns_backend == "technitium":
        health_data["technitium_api"] = str(settings.technitium_api_url)
    else:
        health_data["powerdns_api"] = str(settings.powerdns_api_url)
    return JSONResponse(health_data)


@app.post("/v1/records", response_model=JobResponse, tags=["Records"])
async def submit_record_job(
    request: RecordRequest,
    background: BackgroundTasks,
    token: str = Depends(verify_token),
) -> JobResponse:
    """Submit a DNS record change request."""
    job = RecordJob(request=request)
    job_manager.add_job(job)
    background.add_task(process_record_job, job.job_id)
    logger.info("Queued job %s for %s", job.job_id, request.name)
    return JobResponse(
        job_id=job.job_id,
        status=job.status,
        message="Job accepted for processing.",
    )


@app.get("/v1/runs/{job_id}", response_model=JobDetailResponse, tags=["Records"])
async def get_job(job_id: UUID, token: str = Depends(verify_token)) -> JobDetailResponse:
    """Return job status and metadata."""
    job = job_manager.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    return JobDetailResponse(**job.dict())


async def process_record_job(job_id: UUID) -> None:
    """Background worker for applying DNS record requests."""
    job = job_manager.get_job(job_id)
    if not job:
        logger.error("Job %s vanished before processing.", job_id)
        return

    settings = get_settings()
    # Select adapter based on backend configuration
    adapter = technitium_adapter if settings.dns_backend == "technitium" else pdns_adapter
    backend_name = "Technitium" if settings.dns_backend == "technitium" else "PowerDNS"

    try:
        job_manager.update_status(job_id, RecordJobStatus.VALIDATING, "Validating zone.")
        success, error = adapter.ensure_zone(job.request.zone)
        if not success:
            raise RuntimeError(f"Zone validation failed: {error}")

        job_manager.update_status(job_id, RecordJobStatus.APPLYING, "Applying record.")
        success, error = adapter.upsert_record(
            zone=job.request.zone,
            name=job.request.name,
            record_type=job.request.record_type.value,
            content=job.request.content,
            ttl=job.request.ttl,
        )
        if not success:
            raise RuntimeError(f"{backend_name} update failed: {error}")

        job_manager.update_status(
            job_id,
            RecordJobStatus.DOCUMENTING,
            "Updating documentation.",
        )
        notes = [
            ipam_adapter.build_ipam_note(job.request.name, job.request.content)
        ]
        ipam_adapter.append_ipam_notes(notes)

        job_manager.update_status(
            job_id,
            RecordJobStatus.COMPLETED,
            message="Change applied successfully.",
            doc_changes=notes,
        )
    except Exception as exc:
        logger.exception("Job %s failed: %s", job_id, exc)
        job_manager.update_status(
            job_id,
            RecordJobStatus.FAILED,
            message=str(exc),
        )


