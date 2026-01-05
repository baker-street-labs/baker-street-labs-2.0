"""
Pydantic models used by the Holmes AWX Agent.
"""

from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, validator


class AWXJobStatus(str, Enum):
    """AWX job status values."""

    NEW = "new"
    PENDING = "pending"
    WAITING = "waiting"
    RUNNING = "running"
    SUCCESSFUL = "successful"
    FAILED = "failed"
    ERROR = "error"
    CANCELED = "canceled"


class AWXAgentJobStatus(str, Enum):
    """Status for asynchronous AWX agent operations."""

    RECEIVED = "received"
    VALIDATING = "validating"
    LAUNCHING = "launching"
    MONITORING = "monitoring"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELED = "canceled"


class JobTemplateRequest(BaseModel):
    """Request payload for launching an AWX job template."""

    job_template_id: Optional[int] = Field(
        None,
        description="AWX job template ID (if known)",
    )
    job_template_name: Optional[str] = Field(
        None,
        description="AWX job template name (searched if ID not provided)",
    )
    extra_vars: Dict[str, Any] = Field(
        default_factory=dict,
        description="Extra variables to pass to the job template",
    )
    inventory_id: Optional[int] = Field(
        None,
        description="Inventory ID to use (if template allows override)",
    )
    limit: Optional[str] = Field(
        None,
        description="Host limit string (e.g., 'web*:!web01')",
    )
    metadata: Dict[str, str] = Field(
        default_factory=dict,
        description="Optional metadata for auditing / documentation",
    )


class OrchestrationRequest(BaseModel):
    """Request payload for natural language orchestration."""

    request: str = Field(
        ...,
        description="Natural language request (e.g., 'Deploy nginx on Kubernetes')",
        min_length=10,
    )
    context: Dict[str, Any] = Field(
        default_factory=dict,
        description="Additional context for the LLM",
    )
    metadata: Dict[str, str] = Field(
        default_factory=dict,
        description="Optional metadata for auditing / documentation",
    )


class AWXJob(BaseModel):
    """State container for an AWX job execution."""

    job_id: UUID = Field(default_factory=uuid4)
    status: AWXAgentJobStatus = AWXAgentJobStatus.RECEIVED
    requested_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    request: JobTemplateRequest
    message: Optional[str] = None
    
    # AWX-specific fields
    awx_job_id: Optional[int] = None
    awx_job_status: Optional[AWXJobStatus] = None
    awx_job_output: Optional[str] = None
    awx_job_facts: Optional[Dict[str, Any]] = None
    awx_error: Optional[str] = None
    
    # Orchestration fields (for multi-step workflows)
    parent_job_id: Optional[UUID] = None
    child_job_ids: List[UUID] = Field(default_factory=list)
    step_number: Optional[int] = None
    total_steps: Optional[int] = None


class OrchestrationJob(BaseModel):
    """State container for LLM orchestration requests."""

    job_id: UUID = Field(default_factory=uuid4)
    status: AWXAgentJobStatus = AWXAgentJobStatus.RECEIVED
    requested_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    request: OrchestrationRequest
    message: Optional[str] = None
    
    # LLM orchestration fields
    decomposed_tasks: List[Dict[str, Any]] = Field(default_factory=list)
    awx_jobs: List[AWXJob] = Field(default_factory=list)
    llm_response: Optional[str] = None
    llm_error: Optional[str] = None


class JobTemplateInfo(BaseModel):
    """Information about an AWX job template."""

    id: int
    name: str
    description: Optional[str] = None
    job_type: Optional[str] = None
    inventory: Optional[int] = None
    project: Optional[int] = None
    playbook: Optional[str] = None
    extra_vars: Optional[Dict[str, Any]] = None


class JobResponse(BaseModel):
    """Response returned to API clients when a job is created."""

    job_id: UUID
    status: AWXAgentJobStatus
    message: str


class JobDetailResponse(BaseModel):
    """Detailed job status response."""

    job_id: UUID
    status: AWXAgentJobStatus
    requested_at: datetime
    completed_at: Optional[datetime]
    request: JobTemplateRequest
    message: Optional[str]
    awx_job_id: Optional[int]
    awx_job_status: Optional[AWXJobStatus]
    awx_job_output: Optional[str]
    awx_error: Optional[str]


class OrchestrationResponse(BaseModel):
    """Response for orchestration requests."""

    job_id: UUID
    status: AWXAgentJobStatus
    message: str


class OrchestrationDetailResponse(BaseModel):
    """Detailed orchestration status response."""

    job_id: UUID
    status: AWXAgentJobStatus
    requested_at: datetime
    completed_at: Optional[datetime]
    request: OrchestrationRequest
    message: Optional[str]
    decomposed_tasks: List[Dict[str, Any]]
    awx_jobs: List[Dict[str, Any]]
    llm_response: Optional[str]
    llm_error: Optional[str]

