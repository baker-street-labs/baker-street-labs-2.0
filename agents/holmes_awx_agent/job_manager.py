"""
In-memory job manager for Holmes AWX Agent.

This is a lightweight placeholder until we wire up a proper
task queue (Celery/RQ/etc.). It tracks job states and purges
completed jobs after a configurable retention window.
"""

from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Optional, Union
from uuid import UUID

from .models import AWXJob, OrchestrationJob, AWXAgentJobStatus
from .config import get_settings


class JobManager:
    """Stores and retrieves job metadata."""

    _PURGE_INTERVAL_SECONDS = 60

    def __init__(self) -> None:
        self._jobs: Dict[UUID, Union[AWXJob, OrchestrationJob]] = {}
        self._last_purge: Optional[datetime] = None

        settings = get_settings()
        self._cache_dir = Path(settings.job_cache_dir).expanduser()
        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._load_cached_jobs()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def add_job(self, job: Union[AWXJob, OrchestrationJob]) -> Union[AWXJob, OrchestrationJob]:
        """Add a new job to the manager."""
        self._jobs[job.job_id] = job
        self._maybe_purge()
        cache_path = self._cache_path(job.job_id)
        if cache_path.exists():
            cache_path.unlink(missing_ok=True)
        return job

    def get_job(self, job_id: UUID) -> Optional[Union[AWXJob, OrchestrationJob]]:
        """Retrieve a job by ID, loading from cache if needed."""
        job = self._jobs.get(job_id)
        if job:
            return job

        cache_path = self._cache_path(job_id)
        if not cache_path.exists():
            return None

        try:
            # Try to deserialize as AWXJob first, then OrchestrationJob
            job_data = cache_path.read_text()
            try:
                job = AWXJob.parse_raw(job_data)
            except Exception:
                job = OrchestrationJob.parse_raw(job_data)
        except Exception:
            cache_path.unlink(missing_ok=True)
            return None

        self._jobs[job.job_id] = job
        self._maybe_purge()
        return job

    def update_status(
        self,
        job_id: UUID,
        status: AWXAgentJobStatus,
        message: Optional[str] = None,
        **kwargs,
    ) -> Optional[Union[AWXJob, OrchestrationJob]]:
        """Update job status and optional fields."""
        job = self._jobs.get(job_id)
        if not job:
            return None
        job.status = status
        if message:
            job.message = message
        for key, value in kwargs.items():
            setattr(job, key, value)
        if status in (AWXAgentJobStatus.COMPLETED, AWXAgentJobStatus.FAILED, AWXAgentJobStatus.CANCELED):
            job.completed_at = datetime.utcnow()
            self._persist_job(job)
        self._maybe_purge()
        return job

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _cache_path(self, job_id: UUID) -> Path:
        """Return the cache file path for a job ID."""
        return self._cache_dir / f"{job_id}.json"

    def _persist_job(self, job: Union[AWXJob, OrchestrationJob]) -> None:
        """Write job to disk cache."""
        cache_path = self._cache_path(job.job_id)
        cache_path.write_text(job.json())

    def _load_cached_jobs(self) -> None:
        """Load recent jobs from disk cache."""
        settings = get_settings()
        cutoff = datetime.utcnow() - timedelta(minutes=settings.job_retention_minutes)
        for cache_file in self._cache_dir.glob("*.json"):
            try:
                job_data = cache_file.read_text()
                try:
                    job = AWXJob.parse_raw(job_data)
                except Exception:
                    job = OrchestrationJob.parse_raw(job_data)
            except Exception:
                cache_file.unlink(missing_ok=True)
                continue

            if job.completed_at and job.completed_at < cutoff:
                cache_file.unlink(missing_ok=True)
                continue

            self._jobs[job.job_id] = job

    def _maybe_purge(self) -> None:
        """Purge old jobs if enough time has passed."""
        now = datetime.utcnow()
        if (
            self._last_purge
            and (now - self._last_purge).total_seconds() < self._PURGE_INTERVAL_SECONDS
        ):
            return
        self.purge_old_jobs()
        self._last_purge = now

    def purge_old_jobs(self) -> None:
        """Remove completed jobs older than configured retention window."""
        settings = get_settings()
        cutoff = datetime.utcnow() - timedelta(minutes=settings.job_retention_minutes)

        # Purge from memory
        for job_id, job in list(self._jobs.items()):
            if job.completed_at and job.completed_at < cutoff:
                del self._jobs[job_id]

        # Purge from disk cache
        for cache_file in self._cache_dir.glob("*.json"):
            try:
                job_data = cache_file.read_text()
                try:
                    job = AWXJob.parse_raw(job_data)
                except Exception:
                    job = OrchestrationJob.parse_raw(job_data)
            except Exception:
                cache_file.unlink(missing_ok=True)
                continue

            if job.completed_at and job.completed_at < cutoff:
                cache_file.unlink(missing_ok=True)


job_manager = JobManager()

