"""
Webhook handler for AWX job completion callbacks.

This endpoint receives POST requests from AWX when jobs complete,
allowing for asynchronous workflow progression.
"""

import logging
from typing import Dict, Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, Header, Depends
from pydantic import BaseModel

from .job_manager import job_manager
from .awx_adapter import awx_adapter
from .models import AWXAgentJobStatus, AWXJobStatus

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/webhooks", tags=["Webhooks"])


class AWXWebhookPayload(BaseModel):
    """Payload from AWX webhook callback."""
    job_id: int
    status: str
    job_explanation: str = ""
    extra_data: Dict[str, Any] = {}


@router.post("/awx")
async def awx_webhook(
    payload: AWXWebhookPayload,
    x_holmes_awx_token: str = Header(None),
) -> Dict[str, Any]:
    """
    Receive webhook callback from AWX when a job completes.
    
    AWX job templates can POST to this endpoint using the uri module:
    
    ```yaml
    - name: Notify Holmes Agent
      uri:
        url: "https://holmes-awx-agent:9001/v1/webhooks/awx"
        method: POST
        body_format: json
        body:
          job_id: "{{ ansible_job_id }}"
          status: "{{ job_status }}"
    ```
    """
    # TODO: Add webhook signature validation in Phase 4
    
    logger.info(
        "Received webhook for AWX job %d with status: %s",
        payload.job_id,
        payload.status,
    )
    
    try:
        # Find orchestration jobs that are waiting for this AWX job
        # This is a simplified implementation - in production, we'd track
        # job relationships more explicitly
        
        # For now, we'll just log the webhook
        # In Phase 4, we'll implement proper job relationship tracking
        
        return {
            "status": "received",
            "message": f"Webhook received for job {payload.job_id}",
            "job_id": payload.job_id,
            "job_status": payload.status,
        }
    except Exception as e:
        logger.error(f"Error processing webhook: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def register_webhook_routes(app):
    """Register webhook routes with FastAPI app."""
    app.include_router(router)

