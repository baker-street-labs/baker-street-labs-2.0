"""
Pydantic models used by the Holmes DNS Agent.
"""

from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, validator


class RecordType(str, Enum):
    """Supported DNS record types."""

    A = "A"
    AAAA = "AAAA"
    CNAME = "CNAME"
    TXT = "TXT"
    MX = "MX"
    NS = "NS"
    PTR = "PTR"
    SRV = "SRV"


class RecordRequest(BaseModel):
    """Request payload for creating or updating a DNS record."""

    zone: str = Field(..., example="bakerstreetlabs.io")
    name: str = Field(..., example="border.bakerstreetlabs.io")
    record_type: RecordType = Field(default=RecordType.A)
    content: str = Field(..., example="192.168.0.7")
    ttl: int = Field(default=60, ge=1, le=86400)
    metadata: Dict[str, str] = Field(
        default_factory=dict,
        description="Optional metadata for auditing / documentation",
    )

    @validator("zone", "name")
    def lower_case_fqdn(cls, value: str) -> str:
        if "." not in value:
            raise ValueError("Zone and name must be fully-qualified domains.")
        return value.rstrip(".").lower()


class RecordJobStatus(str, Enum):
    """Status for asynchronous record operations."""

    RECEIVED = "received"
    VALIDATING = "validating"
    APPLYING = "applying"
    DOCUMENTING = "documenting"
    COMPLETED = "completed"
    FAILED = "failed"


class RecordJob(BaseModel):
    """State container for a record management job."""

    job_id: UUID = Field(default_factory=uuid4)
    status: RecordJobStatus = RecordJobStatus.RECEIVED
    requested_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    request: RecordRequest
    message: Optional[str] = None
    powerdns_response: Optional[Dict] = None
    doc_changes: Optional[List[str]] = None


class JobResponse(BaseModel):
    """Response returned to API clients when a job is created."""

    job_id: UUID
    status: RecordJobStatus
    message: str


class JobDetailResponse(BaseModel):
    """Detailed job status response."""

    job_id: UUID
    status: RecordJobStatus
    requested_at: datetime
    completed_at: Optional[datetime]
    request: RecordRequest
    message: Optional[str]
    powerdns_response: Optional[Dict]
    doc_changes: Optional[List[str]]


