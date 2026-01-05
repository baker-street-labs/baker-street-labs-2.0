#!/bin/bash
#
# Setup and test Holmes AWX Agent on Mac Studio
#

set -euo pipefail

REPO_DIR="${HOLMES_AGENT_ROOT:-$HOME/agentic-pipeline/baker-street-labs}"
SERVICE_DIR="${REPO_DIR}/services/holmes_awx_agent"
VENV_DIR="${HOLMES_AGENT_VENV:-$HOME/.venvs/holmes-awx-agent}"

echo "Setting up Holmes AWX Agent for testing..."
echo ""

# 1. Check if repo is synced
if [ ! -d "$SERVICE_DIR" ]; then
    echo "Error: Service directory not found at $SERVICE_DIR"
    echo "Please sync the repository first"
    exit 1
fi

# 2. Create virtual environment
echo "Creating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    /opt/homebrew/bin/python3.11 -m venv "$VENV_DIR"
fi

# 3. Install dependencies
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip wheel
pip install --quiet -r "$SERVICE_DIR/requirements.txt"

# 4. Check for secrets
SECRETS_FILE="$HOME/.secrets"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Warning: ~/.secrets not found"
    echo "Creating minimal .secrets file..."
    cat > "$SECRETS_FILE" <<EOF
AWX_API_URL=https://rangeawx.bakerstreetlabs.io
AWX_USERNAME=admin
AWX_PASSWORD=changeme
HOLMES_AWX_TOKEN=test-token-12345
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://macmini.bakerstreetlabs.io:11434
OLLAMA_MODEL=llama3.1:70b
EOF
    echo "Created $SECRETS_FILE - please update with real credentials"
fi

# 5. Load secrets
echo "Loading secrets..."
set -a
source "$SECRETS_FILE"
set +a

# 6. Set PYTHONPATH
export PYTHONPATH="$REPO_DIR:${PYTHONPATH:-}"

# 7. Start service in background
echo "Starting service..."
cd "$REPO_DIR"
"$VENV_DIR/bin/uvicorn" services.holmes_awx_agent.main:app \
  --host 0.0.0.0 \
  --port 9001 \
  --log-level info &
SERVICE_PID=$!

echo "Service started with PID $SERVICE_PID"
echo "Waiting for service to be ready..."
sleep 3

# 8. Run tests
echo ""
echo "Running tests..."
"$REPO_DIR/services/holmes_awx_agent/scripts/test_agent.sh"

# 9. Keep service running (user can Ctrl+C to stop)
echo ""
echo "Service is running. Press Ctrl+C to stop."
wait $SERVICE_PID

