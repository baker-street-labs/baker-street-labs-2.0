# Holmes AWX Agent - Testing Guide

**Date**: November 18, 2025  
**Status**: Ready for Testing  
**Prerequisites**: Code must be synced to Mac Studio

---

## 📋 **Pre-Testing Checklist**

### 1. Code Synchronization
The `services/holmes_awx_agent/` directory must be present on Mac Studio:

```bash
# On Mac Studio (192.168.0.53)
cd ~/agentic-pipeline/baker-street-labs
git pull origin main  # Or sync via your preferred method
ls -la services/holmes_awx_agent/  # Verify directory exists
```

### 2. Dependencies Installation

```bash
# Create virtual environment
python3.11 -m venv ~/.venvs/holmes-awx-agent
source ~/.venvs/holmes-awx-agent/bin/activate

# Install dependencies
cd ~/agentic-pipeline/baker-street-labs
pip install -r services/holmes_awx_agent/requirements.txt
```

### 3. Configuration

Create/update `~/.secrets` with AWX credentials:

```bash
cat >> ~/.secrets <<EOF
AWX_API_URL=https://rangeawx.bakerstreetlabs.io
AWX_USERNAME=admin
AWX_PASSWORD=<awx-admin-password>
HOLMES_AWX_TOKEN=test-token-12345
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://macmini.bakerstreetlabs.io:11434
OLLAMA_MODEL=llama3.1:70b
EOF
```

**To get AWX admin password:**
```bash
# On AWX server (192.168.0.75)
kubectl get secret awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 -d
```

---

## 🧪 **Testing Steps**

### Step 1: Quick Component Test

```bash
cd ~/agentic-pipeline/baker-street-labs
export PYTHONPATH=$HOME/agentic-pipeline/baker-street-labs
source ~/.venvs/holmes-awx-agent/bin/activate
python3 services/holmes_awx_agent/scripts/quick_test.py
```

**Expected Output:**
```
✅ All imports successful!
✅ Configuration loaded!
✅ Models work!
🎉 All tests passed!
```

### Step 2: Start Service

```bash
cd ~/agentic-pipeline/baker-street-labs
export PYTHONPATH=$HOME/agentic-pipeline/baker-street-labs
source ~/.venvs/holmes-awx-agent/bin/activate
source ~/.secrets  # Load credentials

uvicorn services.holmes_awx_agent.main:app \
  --host 0.0.0.0 \
  --port 9001 \
  --log-level info
```

**Expected Output:**
```
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:9001
```

### Step 3: Test Health Endpoint

```bash
curl http://localhost:9001/health | jq .
```

**Expected Response:**
```json
{
  "status": "ok",
  "service": "holmes-awx-agent",
  "awx_api_url": "https://rangeawx.bakerstreetlabs.io",
  "llm_provider": "ollama"
}
```

### Step 4: Test Job Template Listing

```bash
TOKEN="test-token-12345"
curl -H "X-Holmes-AWX-Token: $TOKEN" \
  http://localhost:9001/v1/job-templates | jq .
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "name": "Hello World",
    "description": "Test template",
    ...
  }
]
```

### Step 5: Test Direct Job Launch

```bash
TOKEN="test-token-12345"
curl -X POST \
  -H "X-Holmes-AWX-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "job_template_name": "Hello World",
    "extra_vars": {"greeting_name": "Baker Street"}
  }' \
  http://localhost:9001/v1/jobs | jq .
```

**Expected Response:**
```json
{
  "job_id": "uuid-here",
  "status": "received",
  "message": "Job accepted for processing."
}
```

### Step 6: Test Orchestration (if LLM available)

```bash
TOKEN="test-token-12345"
curl -X POST \
  -H "X-Holmes-AWX-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "Run the hello world test template"
  }' \
  http://localhost:9001/v1/orchestrate | jq .
```

**Expected Response:**
```json
{
  "job_id": "uuid-here",
  "status": "received",
  "message": "Orchestration request accepted for processing."
}
```

### Step 7: Check Job Status

```bash
TOKEN="test-token-12345"
JOB_ID="<job-id-from-step-5>"
curl -H "X-Holmes-AWX-Token: $TOKEN" \
  http://localhost:9001/v1/jobs/$JOB_ID | jq .
```

---

## 🔍 **Troubleshooting**

### Import Errors

**Problem**: `ModuleNotFoundError: No module named 'services'`

**Solution**:
```bash
export PYTHONPATH=$HOME/agentic-pipeline/baker-street-labs
# Or run from repo root:
cd ~/agentic-pipeline/baker-street-labs
python3 -m services.holmes_awx_agent.main
```

### AWX Connection Errors

**Problem**: `Failed to get AWX token`

**Solutions**:
1. Verify AWX is accessible:
   ```bash
   curl -k https://rangeawx.bakerstreetlabs.io/api/v2/ping
   ```
2. Check credentials in `~/.secrets`
3. Verify AWX admin password is correct

### LLM Provider Errors

**Problem**: `Failed to initialize LLM`

**Solutions**:
1. For Ollama: Verify service is running:
   ```bash
   curl http://macmini.bakerstreetlabs.io:11434/api/tags
   ```
2. Check model is available:
   ```bash
   curl http://macmini.bakerstreetlabs.io:11434/api/tags | jq '.models[] | select(.name | contains("llama3"))'
   ```
3. For OpenAI/Anthropic: Verify API keys in `~/.secrets`

### Port Already in Use

**Problem**: `Address already in use`

**Solution**:
```bash
# Find process using port 9001
lsof -i :9001
# Kill it or use different port
uvicorn ... --port 9002
```

---

## 📊 **Test Results Template**

```markdown
## Test Results - [Date]

### Environment
- **Host**: Mac Studio (192.168.0.53)
- **Python**: 3.11.x
- **AWX URL**: https://rangeawx.bakerstreetlabs.io
- **LLM Provider**: ollama

### Component Tests
- [ ] Quick test (imports, config, models)
- [ ] Service startup
- [ ] Health endpoint
- [ ] Job template listing
- [ ] Direct job launch
- [ ] Job status check
- [ ] Orchestration (simple)
- [ ] Orchestration (multi-step)

### Issues Found
1. [Issue description]
   - **Resolution**: [How it was fixed]

### Next Steps
- [ ] Configure AWX with test templates
- [ ] Test webhook endpoint
- [ ] Test LangGraph workflows
- [ ] Production deployment
```

---

## 🚀 **Automated Test Script**

Use the provided test script:

```bash
cd ~/agentic-pipeline/baker-street-labs
./services/holmes_awx_agent/scripts/test_agent.sh
```

Or use the setup script:

```bash
./services/holmes_awx_agent/scripts/setup_and_test.sh
```

---

**Maintained By**: Baker Street Labs Infrastructure Team  
**Last Updated**: November 18, 2025

