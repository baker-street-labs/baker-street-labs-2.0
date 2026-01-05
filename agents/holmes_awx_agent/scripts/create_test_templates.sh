#!/bin/bash
#
# Create test job templates in AWX for Holmes AWX Agent testing.
# This script uses AWX API to create sample job templates.
#
# Usage: ./create_test_templates.sh <awx-url> <username> <password>
#

set -euo pipefail

AWX_URL="${1:-https://rangeawx.bakerstreetlabs.io}"
USERNAME="${2:-admin}"
PASSWORD="${3:-}"

if [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <awx-url> <username> <password>"
    exit 1
fi

echo "Connecting to AWX at $AWX_URL..."

# Get OAuth2 token
TOKEN=$(curl -s -X POST "$AWX_URL/api/v2/tokens/" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"description": "test-template-creation"}' | jq -r '.token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to get token"
    exit 1
fi

echo "Token obtained. Creating test templates..."

# Function to create a job template
create_template() {
    local name=$1
    local description=$2
    local playbook=$3
    local extra_vars=$4
    
    echo "Creating template: $name"
    
    # First, we need a project. Let's use the default project or create one.
    # For simplicity, we'll assume a project exists. In real setup, create project first.
    
    # Create job template
    curl -s -X POST "$AWX_URL/api/v2/job_templates/" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$description\",
            \"job_type\": \"run\",
            \"playbook\": \"$playbook\",
            \"extra_vars\": \"$extra_vars\"
        }" | jq '.'
    
    echo ""
}

# Create simple test templates
# Note: These require actual playbooks in AWX. For testing, we'll create minimal ones.

echo "Creating test job templates..."
echo "Note: These templates require playbooks to be uploaded to AWX first."
echo ""

# Template 1: Hello World
create_template \
    "test-hello-world" \
    "Simple hello world test template" \
    "hello.yml" \
    "{}"

# Template 2: System Info
create_template \
    "test-system-info" \
    "Gather system information" \
    "system_info.yml" \
    "{}"

# Template 3: Install Package
create_template \
    "test-install-package" \
    "Install a package on target hosts" \
    "install_package.yml" \
    "{\"package_name\": \"nginx\"}"

echo "Done! Test templates created."
echo ""
echo "Note: You'll need to:"
echo "1. Create/upload playbooks to AWX projects"
echo "2. Assign inventories to templates"
echo "3. Configure credentials"

