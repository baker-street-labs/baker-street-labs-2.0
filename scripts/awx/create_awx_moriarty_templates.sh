#!/bin/bash
# EXTRACTED FROM PRODUCTION BAKER STREET MONOREPO – 2025-12-03
# Verified working in active cyber range for 18+ months
# Part of the official Tier 1 / Tier 2 crown jewels audit (Conservative Option A)
# DO NOT REFACTOR UNLESS EXPLICITLY APPROVED

# Create AWX Job Templates for Moriarty Attack Scenario
# This script creates all job templates via AWX API

set -euo pipefail

# Configuration
AWX_URL="${AWX_URL:-https://rangeawx.bakerstreetlabs.io}"
AWX_USERNAME="${AWX_USERNAME:-admin}"
AWX_PASSWORD="${AWX_PASSWORD:-}"
AWX_TOKEN="${AWX_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get AWX API token
get_token() {
    if [ -z "$AWX_TOKEN" ]; then
        echo -e "${YELLOW}Getting AWX API token...${NC}"
        
        if [ -z "$AWX_PASSWORD" ]; then
            echo -e "${RED}Error: AWX_PASSWORD or AWX_TOKEN must be set${NC}"
            exit 1
        fi
        
        AWX_TOKEN=$(curl -sk -X POST "${AWX_URL}/api/v2/tokens/" \
            -u "${AWX_USERNAME}:${AWX_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d '{"description":"moriarty-template-creation"}' \
            | jq -r '.token // empty')
        
        if [ -z "$AWX_TOKEN" ] || [ "$AWX_TOKEN" = "null" ]; then
            echo -e "${RED}Error: Failed to get AWX token${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Token obtained${NC}"
    fi
}

# Function to create job template
create_template() {
    local name="$1"
    local description="$2"
    local inventory_id="$3"
    local project_id="$4"
    local playbook="$5"
    local credential_ids="$6"
    local extra_vars="$7"
    local tags="$8"
    local timeout="${9:-3600}"
    
    echo -e "${YELLOW}Creating template: $name${NC}"
    
    local response=$(curl -sk -X POST "${AWX_URL}/api/v2/job_templates/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AWX_TOKEN}" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$description\",
            \"job_type\": \"run\",
            \"inventory\": $inventory_id,
            \"project\": $project_id,
            \"playbook\": \"$playbook\",
            \"credentials\": [$credential_ids],
            \"forks\": 5,
            \"verbosity\": 1,
            \"extra_vars\": \"$extra_vars\",
            \"job_tags\": \"$tags\",
            \"timeout\": $timeout,
            \"become_enabled\": true,
            \"allow_simultaneous\": false
        }")
    
    local template_id=$(echo "$response" | jq -r '.id // empty')
    
    if [ -n "$template_id" ] && [ "$template_id" != "null" ]; then
        echo -e "${GREEN}✓ Created template: $name (ID: $template_id)${NC}"
        return 0
    else
        local error=$(echo "$response" | jq -r '.detail // .msg // "Unknown error"')
        echo -e "${RED}✗ Failed to create template: $name${NC}"
        echo -e "${RED}  Error: $error${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "AWX Moriarty Template Creation"
    echo "=========================================="
    echo ""
    
    get_token
    
    # Default values (update as needed)
    RANGE_XDR_INVENTORY_ID="${RANGE_XDR_INVENTORY_ID:-1}"
    RANGE_XSIAM_INVENTORY_ID="${RANGE_XSIAM_INVENTORY_ID:-2}"
    PROJECT_ID="${PROJECT_ID:-1}"
    CREDENTIAL_ID="${CREDENTIAL_ID:-3}"
    
    echo -e "${YELLOW}Using configuration:${NC}"
    echo "  Range XDR Inventory ID: $RANGE_XDR_INVENTORY_ID"
    echo "  Range XSIAM Inventory ID: $RANGE_XSIAM_INVENTORY_ID"
    echo "  Project ID: $PROJECT_ID"
    echo "  Credential ID: $CREDENTIAL_ID"
    echo ""
    
    # Create Range XDR templates
    create_template \
        "Moriarty - Infrastructure Setup (Range XDR)" \
        "Automate infrastructure deployment for Moriarty attack scenario on Range XDR (172.29.0.0/16)" \
        "$RANGE_XDR_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/infrastructure-setup-xdr.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xdr","network":"172.29.0.0/16","domain":"moriartyxdr.ad.bakerstreetlabs.io","dc_ip":"172.29.4.65","ca_ip":"172.29.3.67","client01_ip":"172.29.2.45","client02_ip":"172.29.2.46","attacker_ip":"172.29.2.47"}' \
        "infrastructure,setup,range_xdr" \
        7200
    
    create_template \
        "Moriarty - Configuration (Range XDR)" \
        "Configure vulnerable AD settings, create user accounts, and install attack tools for Moriarty scenario on Range XDR" \
        "$RANGE_XDR_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/configuration-xdr.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xdr","domain":"moriartyxdr.ad.bakerstreetlabs.io"}' \
        "configuration,vulnerable,range_xdr" \
        10800
    
    create_template \
        "Moriarty - Attack Execution (Range XDR)" \
        "Execute the complete Moriarty attack chain on Range XDR. WARNING: Executes real attack tools." \
        "$RANGE_XDR_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/attack-execution-xdr.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xdr","domain":"moriartyxdr.ad.bakerstreetlabs.io","dc_ip":"172.29.4.65","dry_run":false}' \
        "attack,execution,range_xdr" \
        3600
    
    create_template \
        "Moriarty - Reset Environment (Range XDR)" \
        "Reset Range XDR Moriarty environment to Pre-Attack snapshot" \
        "$RANGE_XDR_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/reset-environment-xdr.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xdr","reset_type":"snapshot","snapshot_name":"Pre-Attack"}' \
        "reset,cleanup,range_xdr" \
        1800
    
    # Create Range XSIAM templates
    create_template \
        "Moriarty - Infrastructure Setup (Range XSIAM)" \
        "Automate infrastructure deployment for Moriarty attack scenario on Range XSIAM (172.30.0.0/16)" \
        "$RANGE_XSIAM_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/infrastructure-setup-xsiam.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xsiam","network":"172.30.0.0/16","domain":"moriartysiam.ad.bakerstreetlabs.io","dc_ip":"172.30.4.65","ca_ip":"172.30.3.67","client01_ip":"172.30.2.45","client02_ip":"172.30.2.46","attacker_ip":"172.30.2.47"}' \
        "infrastructure,setup,range_xsiam" \
        7200
    
    create_template \
        "Moriarty - Configuration (Range XSIAM)" \
        "Configure vulnerable AD settings, create user accounts, and install attack tools for Moriarty scenario on Range XSIAM" \
        "$RANGE_XSIAM_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/configuration-xsiam.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xsiam","domain":"moriartysiam.ad.bakerstreetlabs.io"}' \
        "configuration,vulnerable,range_xsiam" \
        10800
    
    create_template \
        "Moriarty - Attack Execution (Range XSIAM)" \
        "Execute the complete Moriarty attack chain on Range XSIAM. WARNING: Executes real attack tools." \
        "$RANGE_XSIAM_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/attack-execution-xsiam.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xsiam","domain":"moriartysiam.ad.bakerstreetlabs.io","dc_ip":"172.30.4.65","dry_run":false}' \
        "attack,execution,range_xsiam" \
        3600
    
    create_template \
        "Moriarty - Reset Environment (Range XSIAM)" \
        "Reset Range XSIAM Moriarty environment to Pre-Attack snapshot" \
        "$RANGE_XSIAM_INVENTORY_ID" \
        "$PROJECT_ID" \
        "moriarty/reset-environment-xsiam.yml" \
        "$CREDENTIAL_ID" \
        '{"range":"xsiam","reset_type":"snapshot","snapshot_name":"Pre-Attack"}' \
        "reset,cleanup,range_xsiam" \
        1800
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Template creation complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Verify templates in AWX UI"
    echo "2. Create workflow job templates"
    echo "3. Test each template individually"
    echo "4. Configure playbooks in project"
}

main "$@"

