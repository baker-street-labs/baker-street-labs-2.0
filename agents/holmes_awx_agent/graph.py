"""
LangGraph state machine for multi-agent AWX orchestration.

This implements a stateful workflow for complex multi-step automation tasks.
"""

import logging
from typing import TypedDict, Annotated, List, Dict, Any, Optional, Literal

from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages

from .llm_provider import get_llm
from .tools import get_awx_tools
from .awx_adapter import awx_adapter

logger = logging.getLogger(__name__)


class GraphState(TypedDict):
    """State for the LangGraph workflow."""
    messages: Annotated[List[Dict[str, Any]], add_messages]
    user_request: str
    decomposed_tasks: List[Dict[str, Any]]
    current_task_index: int
    awx_job_ids: List[int]
    completed_tasks: List[Dict[str, Any]]
    error: Optional[str]
    context: Dict[str, Any]


def analyze_request(state: GraphState) -> GraphState:
    """Analyze user request and decompose into tasks."""
    logger.info("Analyzing request: %s", state["user_request"])
    
    # Simple task decomposition (can be enhanced with LLM)
    request = state["user_request"].lower()
    tasks = []
    
    # Pattern matching for common requests
    if "deploy" in request and "kubernetes" in request:
        tasks = [
            {"action": "provision-k8s-cluster", "description": "Provision Kubernetes cluster"},
            {"action": "configure-k8s", "description": "Configure Kubernetes"},
        ]
    elif "install" in request:
        package = "nginx"  # Default, could extract from request
        if "nginx" in request:
            package = "nginx"
        elif "docker" in request:
            package = "docker"
        tasks = [
            {"action": f"install-{package}", "description": f"Install {package}"},
        ]
    else:
        # Fallback: single task
        tasks = [
            {"action": "execute-request", "description": state["user_request"]},
        ]
    
    state["decomposed_tasks"] = tasks
    state["current_task_index"] = 0
    state["awx_job_ids"] = []
    state["completed_tasks"] = []
    
    logger.info("Decomposed into %d tasks", len(tasks))
    return state


def launch_subtask(state: GraphState) -> GraphState:
    """Launch the current subtask via AWX."""
    if state["current_task_index"] >= len(state["decomposed_tasks"]):
        return state
    
    task = state["decomposed_tasks"][state["current_task_index"]]
    logger.info("Launching subtask %d: %s", state["current_task_index"], task["action"])
    
    try:
        # Map action to job template name
        template_name = f"test-{task['action'].replace('_', '-')}"
        
        # Try to find template
        template = awx_adapter.search_job_template(template_name)
        if not template:
            # Fallback to generic template
            template = awx_adapter.search_job_template("test-hello-world")
            if not template:
                raise ValueError(f"Could not find job template for: {task['action']}")
        
        # Launch job
        job_data = awx_adapter.launch_job_template(
            template_id=template.id,
            extra_vars=state.get("context", {}),
        )
        
        awx_job_id = job_data.get("id")
        if awx_job_id:
            state["awx_job_ids"].append(awx_job_id)
            task["awx_job_id"] = awx_job_id
            task["status"] = "launched"
            logger.info("Launched AWX job %d for task: %s", awx_job_id, task["action"])
        else:
            raise ValueError("AWX did not return a job ID")
            
    except Exception as e:
        logger.error("Error launching subtask: %s", e)
        task["status"] = "failed"
        task["error"] = str(e)
        state["error"] = f"Failed to launch task {task['action']}: {e}"
    
    return state


def wait_for_completion(state: GraphState) -> GraphState:
    """Wait for current AWX job to complete."""
    if not state["awx_job_ids"]:
        return state
    
    current_job_id = state["awx_job_ids"][-1]
    logger.info("Waiting for AWX job %d to complete", current_job_id)
    
    try:
        job_data = awx_adapter.wait_for_job(current_job_id)
        status = job_data.get("status", "unknown")
        
        current_task = state["decomposed_tasks"][state["current_task_index"]]
        current_task["awx_status"] = status
        current_task["completed"] = True
        
        if status == "successful":
            logger.info("Job %d completed successfully", current_job_id)
            # Move to next task
            state["current_task_index"] += 1
        else:
            logger.warning("Job %d completed with status: %s", current_job_id, status)
            state["error"] = f"Job {current_job_id} failed with status: {status}"
            
    except Exception as e:
        logger.error("Error waiting for job: %s", e)
        state["error"] = f"Error waiting for job {current_job_id}: {e}"
    
    return state


def handle_callback(state: GraphState) -> GraphState:
    """Handle webhook callback from AWX (placeholder for Phase 4)."""
    # This will be implemented in Phase 4 with webhook endpoint
    logger.debug("Callback handling (Phase 4)")
    return state


def check_next_task(state: GraphState) -> Literal["launch_subtask", "finalize"]:
    """Check if there are more tasks to execute."""
    if state.get("error"):
        return "finalize"
    
    if state["current_task_index"] < len(state["decomposed_tasks"]):
        return "launch_subtask"
    else:
        return "finalize"


def finalize(state: GraphState) -> GraphState:
    """Finalize workflow and prepare response."""
    logger.info("Finalizing workflow")
    
    # Mark all tasks as completed
    for task in state["decomposed_tasks"]:
        if task.get("status") != "failed":
            task["status"] = "completed"
        state["completed_tasks"].append(task)
    
    return state


def create_workflow_graph() -> StateGraph:
    """Create the LangGraph workflow."""
    workflow = StateGraph(GraphState)
    
    # Add nodes
    workflow.add_node("analyze_request", analyze_request)
    workflow.add_node("launch_subtask", launch_subtask)
    workflow.add_node("wait_for_completion", wait_for_completion)
    workflow.add_node("handle_callback", handle_callback)
    workflow.add_node("finalize", finalize)
    
    # Set entry point
    workflow.set_entry_point("analyze_request")
    
    # Add edges
    workflow.add_edge("analyze_request", "launch_subtask")
    workflow.add_edge("launch_subtask", "wait_for_completion")
    workflow.add_edge("wait_for_completion", "handle_callback")
    workflow.add_conditional_edges(
        "handle_callback",
        check_next_task,
        {
            "launch_subtask": "launch_subtask",
            "finalize": "finalize",
        },
    )
    workflow.add_edge("finalize", END)
    
    return workflow.compile()


# Singleton workflow instance
_workflow: Optional[Any] = None


def get_workflow():
    """Get singleton workflow instance."""
    global _workflow
    if _workflow is None:
        _workflow = create_workflow_graph()
    return _workflow

