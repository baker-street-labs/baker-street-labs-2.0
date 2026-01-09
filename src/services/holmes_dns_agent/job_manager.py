"""
In-memory job manager for Holmes DNS Agent.

This is a lightweight placeholder until we wire up a proper
task queue (Celery/RQ/etc.). It tracks job states and purges
completed jobs after a configurable retention window.
"""

from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Optional
from uuid import UUID

from .models import RecordJob, RecordJobStatus
from .config import get_settings


class JobManager:
    """Stores and retrieves job metadata."""

    _PURGE_INTERVAL_SECONDS = 60

    def __init__(self) -> None:
        self._jobs: Dict[UUID, RecordJob] = {}
        self._last_purge: Optional[datetime] = None

        settings = get_settings()
        self._cache_dir = Path(settings.job_cache_dir).expanduser()
        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._load_cached_jobs()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def add_job(self, job: RecordJob) -> RecordJob:
        self._jobs[job.job_id] = job
        self._maybe_purge()
        cache_path = self._cache_path(job.job_id)
        if cache_path.exists():
            cache_path.unlink(missing_ok=True)
        return job

    def get_job(self, job_id: UUID) -> Optional[RecordJob]:
        job = self._jobs.get(job_id)
        if job:
            return job

        cache_path = self._cache_path(job_id)
        if not cache_path.exists():
            return None

        try:
            job = RecordJob.parse_raw(cache_path.read_text())
        except Exception:
            cache_path.unlink(missing_ok=True)
            return None

        self._jobs[job.job_id] = job
        self._maybe_purge()
        return job

    def update_status(
        self,
        job_id: UUID,
        status: RecordJobStatus,
        message: Optional[str] = None,
        **kwargs,
    ) -> Optional[RecordJob]:
        job = self._jobs.get(job_id)
        if not job:
            return None
        job.status = status
        if message:
            job.message = message
        for key, value in kwargs.items():
            setattr(job, key, value)
        if status in (RecordJobStatus.COMPLETED, RecordJobStatus.FAILED):
            job.completed_at = datetime.utcnow()
            self._persist_job(job)
        self._maybe_purge()
        return job

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _cache_path(self, job_id: UUID) -> Path:
        return self._cache_dir / f"{job_id}.json"

    def _persist_job(self, job: RecordJob) -> None:
        cache_path = self._cache_path(job.job_id)
        cache_path.write_text(job.json())

    def _load_cached_jobs(self) -> None:
        settings = get_settings()
        cutoff = datetime.utcnow() - timedelta(minutes=settings.job_retention_minutes)
        for cache_file in self._cache_dir.glob("*.json"):
            try:
                job = RecordJob.parse_raw(cache_file.read_text())
            except Exception:
                cache_file.unlink(missing_ok=True)
                continue

            if job.completed_at and job.completed_at < cutoff:
                cache_file.unlink(missing_ok=True)
                continue

            self._jobs[job.job_id] = job

    def _maybe_purge(self) -> None:
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
                job = RecordJob.parse_raw(cache_file.read_text())
            except Exception:
                cache_file.unlink(missing_ok=True)
                continue

            if job.completed_at and job.completed_at < cutoff:
                cache_file.unlink(missing_ok=True)


job_manager = JobManager()


