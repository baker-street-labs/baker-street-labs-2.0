#!/bin/bash
#
# Quick setup script for AWX test templates
# Run this on the AWX server (rangeawx.bakerstreetlabs.io)
#

set -euo pipefail

AWX_URL="${AWX_URL:-https://rangeawx.bakerstreetlabs.io}"
USERNAME="${AWX_USERNAME:-admin}"
PASSWORD="${AWX_PASSWORD:-}"

if [ -z "$PASSWORD" ]; then
    echo "Error: AWX_PASSWORD not set"
    echo "Usage: AWX_PASSWORD=<password> ./setup_awx.sh"
    exit 1
fi

echo "Configuring AWX at $AWX_URL..."

# Install httpx if needed
python3 -m pip install --user httpx 2>/dev/null || true

# Run configuration script
python3 /tmp/configure_awx_templates.py "$AWX_URL" "$USERNAME" "$PASSWORD"

echo ""
echo "✓ AWX configuration complete!"
echo ""
echo "Next steps:"
echo "1. Upload playbooks to AWX project directory"
echo "2. Sync project in AWX UI"
echo "3. Test with Holmes AWX Agent"

