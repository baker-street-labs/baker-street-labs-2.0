"""
AWX API adapter for Holmes AWX Agent.

Provides a clean interface to AWX (Ansible Automation Platform) API
with OAuth2 token authentication and auto-refresh.
"""

import logging
import time
from typing import Dict, List, Optional, Any
from urllib.parse import urljoin

import httpx

from .config import get_settings
from .models import AWXJobStatus, JobTemplateInfo

logger = logging.getLogger(__name__)


class AWXAdapter:
    """Client for interacting with AWX API."""

    def __init__(self) -> None:
        settings = get_settings()
        self.base_url = str(settings.awx_api_url).rstrip("/")
        self.username = settings.awx_username
        self.password = settings.awx_password
        self.verify_ssl = settings.awx_verify_ssl
        self.poll_interval = settings.job_poll_interval
        self.job_timeout = settings.job_timeout
        
        self._token: Optional[str] = None
        self._token_expires: Optional[float] = None
        self._client: Optional[httpx.Client] = None

    def _get_client(self) -> httpx.Client:
        """Get or create HTTP client with authentication."""
        if self._client is None:
            self._client = httpx.Client(
                base_url=self.base_url,
                verify=self.verify_ssl,
                timeout=30.0,
            )
        return self._client

    def _get_token(self) -> str:
        """Get OAuth2 token, refreshing if needed."""
        now = time.time()
        
        # Refresh token if expired or about to expire (within 60 seconds)
        if self._token is None or (self._token_expires and now >= self._token_expires - 60):
            logger.info("Refreshing AWX OAuth2 token")
            client = self._get_client()
            
            # AWX uses /api/v2/tokens/ endpoint for token creation
            response = client.post(
                "/api/v2/tokens/",
                json={"description": "holmes-awx-agent"},
                auth=(self.username, self.password),
            )
            response.raise_for_status()
            
            data = response.json()
            self._token = data["token"]
            # AWX tokens typically expire in 1 hour, but we'll refresh proactively
            self._token_expires = now + 3600
            
            logger.info("AWX token refreshed successfully")
        
        return self._token

    def _request(
        self,
        method: str,
        path: str,
        **kwargs,
    ) -> httpx.Response:
        """Make authenticated request to AWX API."""
        client = self._get_client()
        token = self._get_token()
        
        headers = kwargs.pop("headers", {})
        headers["Authorization"] = f"Bearer {token}"
        headers.setdefault("Content-Type", "application/json")
        
        url = urljoin(self.base_url + "/", path.lstrip("/"))
        response = client.request(method, url, headers=headers, **kwargs)
        
        # If token expired, retry once
        if response.status_code == 401:
            logger.warning("Token expired, refreshing and retrying")
            self._token = None
            self._token_expires = None
            token = self._get_token()
            headers["Authorization"] = f"Bearer {token}"
            response = client.request(method, url, headers=headers, **kwargs)
        
        response.raise_for_status()
        return response

    def list_job_templates(self, search: Optional[str] = None) -> List[JobTemplateInfo]:
        """List all job templates, optionally filtered by search term."""
        params = {}
        if search:
            params["search"] = search
        
        response = self._request("GET", "/api/v2/job_templates/", params=params)
        data = response.json()
        
        templates = []
        for item in data.get("results", []):
            templates.append(JobTemplateInfo(
                id=item["id"],
                name=item["name"],
                description=item.get("description"),
                job_type=item.get("job_type"),
                inventory=item.get("inventory"),
                project=item.get("project"),
                playbook=item.get("playbook"),
                extra_vars=item.get("extra_vars"),
            ))
        
        return templates

    def get_job_template(self, template_id: int) -> Optional[JobTemplateInfo]:
        """Get a specific job template by ID."""
        try:
            response = self._request("GET", f"/api/v2/job_templates/{template_id}/")
            data = response.json()
            return JobTemplateInfo(
                id=data["id"],
                name=data["name"],
                description=data.get("description"),
                job_type=data.get("job_type"),
                inventory=data.get("inventory"),
                project=data.get("project"),
                playbook=data.get("playbook"),
                extra_vars=data.get("extra_vars"),
            )
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return None
            raise

    def search_job_template(self, name: str) -> Optional[JobTemplateInfo]:
        """Search for a job template by name."""
        templates = self.list_job_templates(search=name)
        for template in templates:
            if template.name.lower() == name.lower():
                return template
        return None

    def launch_job_template(
        self,
        template_id: int,
        extra_vars: Optional[Dict[str, Any]] = None,
        inventory_id: Optional[int] = None,
        limit: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Launch a job template."""
        payload: Dict[str, Any] = {}
        if extra_vars:
            payload["extra_vars"] = extra_vars
        if inventory_id:
            payload["inventory"] = inventory_id
        if limit:
            payload["limit"] = limit
        
        response = self._request(
            "POST",
            f"/api/v2/job_templates/{template_id}/launch/",
            json=payload,
        )
        return response.json()

    def get_job_status(self, job_id: int) -> Dict[str, Any]:
        """Get current status of an AWX job."""
        response = self._request("GET", f"/api/v2/jobs/{job_id}/")
        return response.json()

    def get_job_output(self, job_id: int) -> str:
        """Get stdout output from an AWX job."""
        response = self._request("GET", f"/api/v2/jobs/{job_id}/stdout/")
        return response.text

    def wait_for_job(
        self,
        job_id: int,
        timeout: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Wait for a job to complete, polling status."""
        timeout = timeout or self.job_timeout
        start_time = time.time()
        
        while True:
            job_data = self.get_job_status(job_id)
            status = job_data.get("status")
            
            if status in ("successful", "failed", "error", "canceled"):
                logger.info(f"Job {job_id} completed with status: {status}")
                return job_data
            
            elapsed = time.time() - start_time
            if elapsed > timeout:
                raise TimeoutError(f"Job {job_id} timed out after {timeout} seconds")
            
            logger.debug(f"Job {job_id} status: {status}, waiting {self.poll_interval}s...")
            time.sleep(self.poll_interval)

    def cancel_job(self, job_id: int) -> Dict[str, Any]:
        """Cancel a running AWX job."""
        response = self._request("POST", f"/api/v2/jobs/{job_id}/cancel/")
        return response.json()


# Singleton instance
awx_adapter = AWXAdapter()

