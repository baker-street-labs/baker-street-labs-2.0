#!/bin/bash
#
# Test script for Holmes AWX Agent
# Run this on Mac Studio after setting up the service
#

set -euo pipefail

AGENT_URL="${AGENT_URL:-http://localhost:9001}"
TOKEN="${HOLMES_AWX_TOKEN:-test-token-12345}"

echo "Testing Holmes AWX Agent at $AGENT_URL"
echo ""

# Test 1: Health check
echo "=== Test 1: Health Check ==="
curl -s "$AGENT_URL/health" | jq '.' || curl -s "$AGENT_URL/health"
echo ""
echo ""

# Test 2: List job templates (requires token)
echo "=== Test 2: List Job Templates ==="
curl -s -H "X-Holmes-AWX-Token: $TOKEN" \
  "$AGENT_URL/v1/job-templates" | jq '.' || \
  curl -s -H "X-Holmes-AWX-Token: $TOKEN" \
  "$AGENT_URL/v1/job-templates"
echo ""
echo ""

# Test 3: Launch a simple job (if templates exist)
echo "=== Test 3: Launch Job Template ==="
TEMPLATE_NAME="test-hello-world"
curl -s -X POST \
  -H "X-Holmes-AWX-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"job_template_name\": \"$TEMPLATE_NAME\"}" \
  "$AGENT_URL/v1/jobs" | jq '.' || \
  curl -s -X POST \
  -H "X-Holmes-AWX-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"job_template_name\": \"$TEMPLATE_NAME\"}" \
  "$AGENT_URL/v1/jobs"
echo ""
echo ""

echo "=== Tests Complete ==="

