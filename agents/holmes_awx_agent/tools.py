"""
LangChain tools for AWX operations.

These tools allow the LLM to interact with AWX through function calling.
"""

import logging
from typing import List, Optional, Dict, Any

from langchain.tools import BaseTool
from pydantic import BaseModel, Field

from .awx_adapter import awx_adapter
from .models import JobTemplateInfo

logger = logging.getLogger(__name__)


class ListJobTemplatesInput(BaseModel):
    """Input for list_awx_job_templates tool."""
    search: Optional[str] = Field(None, description="Optional search term to filter job templates")


class LaunchJobInput(BaseModel):
    """Input for launch_awx_job tool."""
    template_name: str = Field(..., description="Name of the AWX job template to launch")
    extra_vars: Optional[Dict[str, Any]] = Field(None, description="Extra variables to pass to the job template (JSON object)")
    inventory_id: Optional[int] = Field(None, description="Optional inventory ID to use")
    limit: Optional[str] = Field(None, description="Optional host limit string (e.g., 'web*:!web01')")


class CheckJobStatusInput(BaseModel):
    """Input for check_awx_job_status tool."""
    job_id: int = Field(..., description="AWX job ID to check")


class GetJobOutputInput(BaseModel):
    """Input for get_awx_job_output tool."""
    job_id: int = Field(..., description="AWX job ID to get output for")


class ListJobTemplatesTool(BaseTool):
    """Tool for listing AWX job templates."""
    name = "list_awx_job_templates"
    description = """List available AWX job templates. Use this to discover what automation templates are available.
    You can optionally provide a search term to filter templates by name."""
    args_schema = ListJobTemplatesInput

    def _run(self, search: Optional[str] = None) -> str:
        """Execute the tool."""
        try:
            templates = awx_adapter.list_job_templates(search=search)
            if not templates:
                return f"No job templates found{' matching search: ' + search if search else ''}"
            
            result = f"Found {len(templates)} job template(s):\n"
            for template in templates:
                result += f"  - ID: {template.id}, Name: {template.name}"
                if template.description:
                    result += f", Description: {template.description}"
                result += "\n"
            return result
        except Exception as e:
            logger.error(f"Error listing job templates: {e}")
            return f"Error listing job templates: {e}"


class LaunchJobTool(BaseTool):
    """Tool for launching AWX job templates."""
    name = "launch_awx_job"
    description = """Launch an AWX job template. You must provide the template name (exact match or close).
    You can optionally provide extra_vars (a JSON object with key-value pairs) to customize the job execution.
    Returns the AWX job ID which you can use to check status."""
    args_schema = LaunchJobInput

    def _run(
        self,
        template_name: str,
        extra_vars: Optional[Dict[str, Any]] = None,
        inventory_id: Optional[int] = None,
        limit: Optional[str] = None,
    ) -> str:
        """Execute the tool."""
        try:
            # Search for template by name
            template = awx_adapter.search_job_template(template_name)
            if not template:
                return f"Job template '{template_name}' not found. Use list_awx_job_templates to see available templates."
            
            # Launch the job
            job_data = awx_adapter.launch_job_template(
                template_id=template.id,
                extra_vars=extra_vars or {},
                inventory_id=inventory_id,
                limit=limit,
            )
            
            job_id = job_data.get("id")
            status = job_data.get("status", "unknown")
            
            return f"Job launched successfully! AWX Job ID: {job_id}, Status: {status}. Use check_awx_job_status to monitor progress."
        except Exception as e:
            logger.error(f"Error launching job: {e}")
            return f"Error launching job: {e}"


class CheckJobStatusTool(BaseTool):
    """Tool for checking AWX job status."""
    name = "check_awx_job_status"
    description = """Check the status of a running or completed AWX job. Provide the AWX job ID.
    Returns the current status (new, pending, running, successful, failed, etc.)."""
    args_schema = CheckJobStatusInput

    def _run(self, job_id: int) -> str:
        """Execute the tool."""
        try:
            job_data = awx_adapter.get_job_status(job_id)
            status = job_data.get("status", "unknown")
            started = job_data.get("started", "N/A")
            finished = job_data.get("finished", "N/A")
            
            result = f"Job {job_id} Status: {status}"
            if started != "N/A":
                result += f", Started: {started}"
            if finished != "N/A":
                result += f", Finished: {finished}"
            
            if status in ("successful", "failed", "error", "canceled"):
                result += " (Job completed)"
            else:
                result += " (Job still running)"
            
            return result
        except Exception as e:
            logger.error(f"Error checking job status: {e}")
            return f"Error checking job status: {e}"


class GetJobOutputTool(BaseTool):
    """Tool for getting AWX job output."""
    name = "get_awx_job_output"
    description = """Get the stdout output from a completed AWX job. Provide the AWX job ID.
    This is useful for seeing what the job did and any results."""
    args_schema = GetJobOutputInput

    def _run(self, job_id: int) -> str:
        """Execute the tool."""
        try:
            output = awx_adapter.get_job_output(job_id)
            if not output:
                return f"Job {job_id} has no output yet or output is empty."
            
            # Truncate very long output
            max_length = 5000
            if len(output) > max_length:
                return f"Job {job_id} output (truncated):\n{output[:max_length]}...\n[Output truncated, {len(output) - max_length} more characters]"
            
            return f"Job {job_id} output:\n{output}"
        except Exception as e:
            logger.error(f"Error getting job output: {e}")
            return f"Error getting job output: {e}"


def get_awx_tools() -> List[BaseTool]:
    """Get all AWX tools for LangChain agent."""
    return [
        ListJobTemplatesTool(),
        LaunchJobTool(),
        CheckJobStatusTool(),
        GetJobOutputTool(),
    ]

