"""
LLM orchestrator for Holmes AWX Agent.

Uses LangChain ReAct agent for simple requests and LangGraph
for complex multi-step workflows.
"""

import logging
from typing import Dict, Any, List, Optional

from langchain.agents import AgentExecutor, create_react_agent
from langchain_core.prompts import PromptTemplate
from langchain.memory import ConversationBufferMemory

from .llm_provider import get_llm
from .tools import get_awx_tools
from .graph import get_workflow, GraphState

logger = logging.getLogger(__name__)


# ReAct prompt template for AWX orchestration
REACT_PROMPT = """You are an automation orchestrator for AWX (Ansible Automation Platform). 
Your job is to help users automate infrastructure tasks by breaking down their requests into 
AWX job template executions.

You have access to the following tools:
{tools}

Use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

Previous conversation history:
{history}

Question: {input}
Thought: {agent_scratchpad}"""


class LLMOrchestrator:
    """Orchestrates AWX jobs via LLM reasoning."""

    def __init__(self):
        self.llm = get_llm()
        self.tools = get_awx_tools()
        self.memory = ConversationBufferMemory(
            memory_key="history",
            return_messages=True,
        )
        
        # Create ReAct agent
        prompt = PromptTemplate.from_template(REACT_PROMPT)
        agent = create_react_agent(self.llm, self.tools, prompt)
        self.agent_executor = AgentExecutor(
            agent=agent,
            tools=self.tools,
            memory=self.memory,
            verbose=True,
            handle_parsing_errors=True,
            max_iterations=10,
        )

    def orchestrate(
        self,
        request: str,
        context: Optional[Dict[str, Any]] = None,
        use_graph: bool = True,
    ) -> Dict[str, Any]:
        """
        Orchestrate a natural language request into AWX job executions.
        
        Args:
            request: Natural language request (e.g., "Deploy nginx on Kubernetes")
            context: Optional additional context for the LLM
            use_graph: Use LangGraph for multi-step workflows (default: True)
        
        Returns:
            Dict with:
                - response: LLM's final answer or workflow summary
                - steps: List of reasoning steps or tasks
                - awx_jobs: List of AWX job IDs launched
        """
        try:
            logger.info(f"Orchestrating request: {request} (use_graph={use_graph})")
            
            # Use LangGraph for complex workflows
            if use_graph:
                return self._orchestrate_with_graph(request, context)
            else:
                # Use simple ReAct agent for single-step requests
                return self._orchestrate_with_agent(request, context)
                
        except Exception as e:
            logger.error(f"Error in orchestration: {e}", exc_info=True)
            return {
                "response": f"Error during orchestration: {e}",
                "steps": [],
                "awx_jobs": [],
                "error": str(e),
            }
    
    def _orchestrate_with_graph(
        self,
        request: str,
        context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Orchestrate using LangGraph state machine."""
        workflow = get_workflow()
        
        # Initialize state
        initial_state: GraphState = {
            "messages": [],
            "user_request": request,
            "decomposed_tasks": [],
            "current_task_index": 0,
            "awx_job_ids": [],
            "completed_tasks": [],
            "error": None,
            "context": context or {},
        }
        
        # Execute workflow
        final_state = workflow.invoke(initial_state)
        
        # Build response
        response_parts = [f"Orchestrated request: {request}"]
        
        if final_state.get("error"):
            response_parts.append(f"Error: {final_state['error']}")
        else:
            response_parts.append(f"Completed {len(final_state['completed_tasks'])} task(s)")
            for task in final_state["completed_tasks"]:
                status = task.get("status", "unknown")
                response_parts.append(f"  - {task.get('description', task.get('action', 'task'))}: {status}")
        
        return {
            "response": "\n".join(response_parts),
            "steps": final_state["decomposed_tasks"],
            "awx_jobs": final_state["awx_job_ids"],
            "completed_tasks": final_state["completed_tasks"],
            "error": final_state.get("error"),
        }
    
    def _orchestrate_with_agent(
        self,
        request: str,
        context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Orchestrate using simple ReAct agent."""
        # Build input with context if provided
        input_text = request
        if context:
            context_str = "\n".join(f"{k}: {v}" for k, v in context.items())
            input_text = f"{request}\n\nContext:\n{context_str}"
        
        # Execute agent
        result = self.agent_executor.invoke({"input": input_text})
        
        response = result.get("output", "No response generated")
        
        # Extract AWX job IDs from the response
        awx_jobs = []
        if "AWX Job ID:" in response:
            import re
            job_ids = re.findall(r"AWX Job ID: (\d+)", response)
            awx_jobs = [int(jid) for jid in job_ids]
        
        return {
            "response": response,
            "steps": [],
            "awx_jobs": awx_jobs,
        }

    def clear_memory(self):
        """Clear conversation memory."""
        self.memory.clear()


# Singleton instance
_orchestrator: Optional[LLMOrchestrator] = None


def get_orchestrator() -> LLMOrchestrator:
    """Get singleton orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = LLMOrchestrator()
    return _orchestrator

