This repository is one of the Nine Laboratories of Baker Street.
It shall remain focused, independent, and well-documented.
We do not rebuild Frankenstein.
— The Baker Street Compact, 2026

# Holmes AWX Agent

LLM-powered automation orchestrator for AWX (Ansible Automation Platform).

## Overview

The Holmes AWX Agent provides natural language interface to AWX through LLM orchestration. It can decompose complex automation requests into multi-step workflows executed via AWX job templates.

## Features

- **Natural Language Interface**: Submit requests like "Deploy nginx on Kubernetes"
- **Multi-Step Orchestration**: LangGraph state machine for complex workflows
- **AWX Integration**: Full API support for job templates, execution, and monitoring
- **Multi-LLM Support**: Ollama (local 70b), OpenAI, Anthropic
- **A2A Security**: Token-based authentication (future: StepCA/OIDC)
- **Webhook Support**: Receive callbacks from AWX jobs

## Architecture

```
User Request → LLM Orchestrator → LangGraph Workflow → AWX Job Templates → Results
```

## Quick Start

### 1. Install Dependencies

```bash
cd baker-street-labs
python3 -m venv .venv
source .venv/bin/activate
pip install -r services/holmes_awx_agent/requirements.txt
```

### 2. Configuration

Add to `~/.secrets`:
```bash
AWX_API_URL=https://rangeawx.bakerstreetlabs.io
AWX_USERNAME=admin
AWX_PASSWORD=<password>
HOLMES_AWX_TOKEN=<agent-token>
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://macmini.bakerstreetlabs.io:11434
OLLAMA_MODEL=llama3.1:70b
```

### 3. Start Service

```bash
export PYTHONPATH=$(pwd)
uvicorn services.holmes_awx_agent.main:app --host 0.0.0.0 --port 9001 --reload
```

### 4. Test

```bash
# Health check
curl http://localhost:9001/health

# List job templates
curl -H "X-Holmes-AWX-Token: <token>" \
  http://localhost:9001/v1/job-templates

# Orchestrate
curl -X POST \
  -H "X-Holmes-AWX-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{"request": "Run the hello world test template"}' \
  http://localhost:9001/v1/orchestrate
```

## API Endpoints

### System
- `GET /health` - Health check

### Job Templates
- `GET /v1/job-templates` - List all templates
- `GET /v1/job-templates/{id}` - Get specific template

### Jobs
- `POST /v1/jobs` - Launch job template
- `GET /v1/jobs/{job_id}` - Get job status

### Orchestration
- `POST /v1/orchestrate` - Natural language request
- `GET /v1/orchestrate/{job_id}` - Get orchestration status

### Webhooks
- `POST /v1/webhooks/awx` - AWX job completion callback

## Project Structure

```
holmes_awx_agent/
├── __init__.py           # Package initialization
├── config.py            # Pydantic settings
├── models.py             # Data models
├── job_manager.py        # Job tracking
├── awx_adapter.py        # AWX API client
├── llm_provider.py       # LLM abstraction
├── tools.py              # LangChain tools
├── llm_orchestrator.py   # ReAct orchestrator
├── graph.py              # LangGraph state machine
├── webhook_handler.py    # Webhook endpoint
├── main.py               # FastAPI service
└── requirements.txt      # Dependencies
```

## Documentation

- **Implementation Plan**: `docs/AWX_AGENT_IMPLEMENTATION_PLAN.md`
- **Phase 1**: `docs/AWX_AGENT_PHASE1_COMPLETE.md`
- **Phase 2**: `docs/AWX_AGENT_PHASE2_COMPLETE.md`
- **Phase 3**: `docs/AWX_AGENT_PHASE3_COMPLETE.md`
- **AWX Setup**: `examples/configure_awx.md`

## Status

**Current**: Phase 3 Complete (Multi-Agent Workflow)  
**Next**: Phase 4 (Webhooks & Production Deployment)

---

**Maintained By**: Baker Street Labs Infrastructure Team

