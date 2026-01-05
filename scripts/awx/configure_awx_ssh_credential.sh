#!/bin/bash
# EXTRACTED FROM PRODUCTION BAKER STREET MONOREPO – 2025-12-03
# Verified working in active cyber range for 18+ months
# Part of the official Tier 1 / Tier 2 crown jewels audit (Conservative Option A)
# DO NOT REFACTOR UNLESS EXPLICITLY APPROVED

# Configure AWX to use SSH key from automan user
# This script creates a Machine credential in AWX with the SSH private key
# generated in the automan user's home directory

set -e

# Configuration
AWX_URL="${AWX_URL:-https://rangeawx.bakerstreetlabs.io}"
AWX_USERNAME="${AWX_USERNAME:-admin}"
AWX_SERVER="192.168.0.75"
AUTOMAN_USER="automan"
SSH_KEY_NAME="${SSH_KEY_NAME:-automan-ssh-key}"
CREDENTIAL_NAME="${CREDENTIAL_NAME:-Baker Street SSH Key}"

# Detect if we're running locally on AWX server
IS_LOCAL=false
if [ "$(hostname -I | grep -o "$AWX_SERVER")" = "$AWX_SERVER" ] || \
   [ "$(hostname -f 2>/dev/null | grep -i rangeawx)" != "" ] || \
   [ -f "/etc/rancher/k3s/k3s.yaml" ] || \
   [ -n "$K3S_TOKEN" ]; then
    IS_LOCAL=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "AWX SSH Credential Configuration"
echo "=========================================="
echo ""
echo "AWX URL: $AWX_URL"
echo "AWX Username: $AWX_USERNAME"
echo "SSH Key Name: $SSH_KEY_NAME"
echo "Credential Name: $CREDENTIAL_NAME"
echo ""

# Step 1: Get AWX admin password
echo -e "${YELLOW}Step 1: Retrieving AWX admin password...${NC}"
AWX_PASSWORD=""

# Check if password provided via environment variable
if [ -n "$AWX_PASSWORD" ]; then
    echo "Using AWX password from environment variable"
elif [ "$IS_LOCAL" = true ] && command -v kubectl &> /dev/null; then
    echo "Attempting to get password from Kubernetes secret (local)..."
    AWX_PASSWORD=$(sudo kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
fi

if [ -z "$AWX_PASSWORD" ]; then
    echo -e "${YELLOW}Kubernetes secret not available.${NC}"
    echo "You can set AWX_PASSWORD environment variable or enter it now:"
    read -sp "Enter AWX admin password: " AWX_PASSWORD
    echo ""
fi

if [ -z "$AWX_PASSWORD" ]; then
    echo -e "${RED}Error: AWX password is required${NC}"
    echo "Set AWX_PASSWORD environment variable or run with:"
    echo "  export AWX_PASSWORD=<password>"
    echo "  $0"
    exit 1
fi

echo -e "${GREEN}✓ AWX password retrieved${NC}"
echo ""

# Step 2: Get AWX API token
echo -e "${YELLOW}Step 2: Getting AWX API token...${NC}"
# Create temp JSON file for curl (avoids escaping issues)
TEMP_JSON=$(mktemp)
echo '{"description":"ssh-credential-config"}' > "$TEMP_JSON"
TOKEN_RESPONSE=$(curl -sk -X POST "${AWX_URL}/api/v2/tokens/" \
    -u "${AWX_USERNAME}:${AWX_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "@${TEMP_JSON}" || echo "")
rm -f "$TEMP_JSON"

if [ -z "$TOKEN_RESPONSE" ]; then
    echo -e "${RED}Error: Failed to get AWX token. Check AWX URL and credentials.${NC}"
    exit 1
fi

# Check for error in response
if echo "$TOKEN_RESPONSE" | grep -q '"detail"'; then
    echo -e "${RED}Error: Failed to get AWX token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

AWX_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$AWX_TOKEN" ]; then
    echo -e "${RED}Error: Failed to extract token from response${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ AWX API token obtained${NC}"
echo ""

# Step 3: Find SSH private key on AWX server
echo -e "${YELLOW}Step 3: Locating SSH private key...${NC}"
SSH_KEY_PATH=""

# Try common key locations
KEY_PATHS=(
    "/home/${AUTOMAN_USER}/id_rsa"
    "/home/${AUTOMAN_USER}/.ssh/id_rsa"
    "/home/${AUTOMAN_USER}/id_ed25519"
    "/home/${AUTOMAN_USER}/.ssh/id_ed25519"
    "/home/${AUTOMAN_USER}/${SSH_KEY_NAME}"
)

for key_path in "${KEY_PATHS[@]}"; do
    echo "Checking: $key_path"
    if [ "$IS_LOCAL" = true ]; then
        # Running locally, check directly
        if [ -f "$key_path" ]; then
            SSH_KEY_PATH="$key_path"
            echo -e "${GREEN}✓ Found SSH key at: $SSH_KEY_PATH${NC}"
            break
        fi
    else
        # Running remotely, use SSH
        if ssh -i ~/.ssh/id_rsa_baker_street ${AUTOMAN_USER}@${AWX_SERVER} \
            "test -f $key_path" 2>/dev/null; then
            SSH_KEY_PATH="$key_path"
            echo -e "${GREEN}✓ Found SSH key at: $SSH_KEY_PATH${NC}"
            break
        fi
    fi
done

if [ -z "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}SSH key not found in standard locations.${NC}"
    echo "Please specify the full path to the SSH private key:"
    read -p "SSH Key Path: " SSH_KEY_PATH
    
    # Verify the key exists
    if [ "$IS_LOCAL" = true ]; then
        if [ ! -f "$SSH_KEY_PATH" ]; then
            echo -e "${RED}Error: SSH key not found at $SSH_KEY_PATH${NC}"
            exit 1
        fi
    else
        if ! ssh -i ~/.ssh/id_rsa_baker_street ${AUTOMAN_USER}@${AWX_SERVER} \
            "test -f $SSH_KEY_PATH" 2>/dev/null; then
            echo -e "${RED}Error: SSH key not found at $SSH_KEY_PATH${NC}"
            exit 1
        fi
    fi
fi

echo ""

# Step 4: Read SSH private key
echo -e "${YELLOW}Step 4: Reading SSH private key...${NC}"
if [ "$IS_LOCAL" = true ]; then
    # Running locally, read directly
    SSH_KEY_DATA=$(cat "$SSH_KEY_PATH" 2>/dev/null || echo "")
else
    # Running remotely, use SSH
    SSH_KEY_DATA=$(ssh -i ~/.ssh/id_rsa_baker_street ${AUTOMAN_USER}@${AWX_SERVER} \
        "cat $SSH_KEY_PATH" 2>/dev/null || echo "")
fi

if [ -z "$SSH_KEY_DATA" ]; then
    echo -e "${RED}Error: Failed to read SSH private key${NC}"
    exit 1
fi

# Validate it's a private key
if ! echo "$SSH_KEY_DATA" | grep -q "BEGIN.*PRIVATE KEY"; then
    echo -e "${RED}Error: File does not appear to be a valid private key${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SSH private key read successfully${NC}"
echo ""

# Step 5: Get Machine credential type ID
echo -e "${YELLOW}Step 5: Getting Machine credential type ID...${NC}"
CRED_TYPE_RESPONSE=$(curl -sk "${AWX_URL}/api/v2/credential_types/?name=Machine" \
    -H "Authorization: Bearer ${AWX_TOKEN}" \
    -H "Content-Type: application/json" || echo "")

if [ -z "$CRED_TYPE_RESPONSE" ]; then
    echo -e "${RED}Error: Failed to get credential types${NC}"
    exit 1
fi

CRED_TYPE_ID=$(echo "$CRED_TYPE_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$CRED_TYPE_ID" ]; then
    echo -e "${RED}Error: Failed to extract Machine credential type ID${NC}"
    echo "Response: $CRED_TYPE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Machine credential type ID: $CRED_TYPE_ID${NC}"
echo ""

# Step 6: Get current user ID
echo -e "${YELLOW}Step 6: Getting current user ID...${NC}"
USER_RESPONSE=$(curl -sk "${AWX_URL}/api/v2/me/" \
    -H "Authorization: Bearer ${AWX_TOKEN}" \
    -H "Content-Type: application/json" || echo "")

if [ -z "$USER_RESPONSE" ]; then
    echo -e "${RED}Error: Failed to get current user info${NC}"
    exit 1
fi

USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$USER_ID" ]; then
    echo -e "${RED}Error: Failed to extract user ID${NC}"
    echo "Response: $USER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Current user ID: $USER_ID${NC}"
echo ""

# Step 7: Check if credential already exists
echo -e "${YELLOW}Step 7: Checking for existing credential...${NC}"
EXISTING_CRED=$(curl -sk "${AWX_URL}/api/v2/credentials/?name=${CREDENTIAL_NAME}" \
    -H "Authorization: Bearer ${AWX_TOKEN}" \
    -H "Content-Type: application/json" || echo "")

EXISTING_ID=$(echo "$EXISTING_CRED" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -n "$EXISTING_ID" ]; then
    echo -e "${YELLOW}Credential '${CREDENTIAL_NAME}' already exists (ID: $EXISTING_ID)${NC}"
    read -p "Update existing credential? (y/N): " UPDATE_EXISTING
    echo ""
    
    if [[ "$UPDATE_EXISTING" =~ ^[Yy]$ ]]; then
        # Update existing credential
        echo -e "${YELLOW}Updating existing credential...${NC}"
        
        # Escape the SSH key data for JSON
        SSH_KEY_ESCAPED=$(echo "$SSH_KEY_DATA" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
        
        UPDATE_PAYLOAD=$(cat <<EOF
{
    "credential_type": ${CRED_TYPE_ID},
    "name": "${CREDENTIAL_NAME}",
    "inputs": {
        "username": "${AUTOMAN_USER}",
        "ssh_key_data": "${SSH_KEY_ESCAPED}"
    }
}
EOF
)
        
        UPDATE_RESPONSE=$(curl -sk -X PATCH "${AWX_URL}/api/v2/credentials/${EXISTING_ID}/" \
            -H "Authorization: Bearer ${AWX_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_PAYLOAD" || echo "")
        
        if echo "$UPDATE_RESPONSE" | grep -q '"id"'; then
            echo -e "${GREEN}✓ Credential updated successfully${NC}"
            echo "Credential ID: $EXISTING_ID"
            echo "Credential Name: $CREDENTIAL_NAME"
            echo ""
            exit 0
        else
            echo -e "${RED}Error: Failed to update credential${NC}"
            echo "Response: $UPDATE_RESPONSE"
            exit 1
        fi
    else
        echo "Skipping update. Exiting."
        exit 0
    fi
fi

# Step 8: Create new credential
echo -e "${YELLOW}Step 8: Creating new Machine credential...${NC}"

# Escape the SSH key data for JSON
SSH_KEY_ESCAPED=$(echo "$SSH_KEY_DATA" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

CREATE_PAYLOAD=$(cat <<EOF
{
    "user": ${USER_ID},
    "credential_type": ${CRED_TYPE_ID},
    "name": "${CREDENTIAL_NAME}",
    "description": "SSH key for Baker Street Labs automation (automan user)",
    "inputs": {
        "username": "${AUTOMAN_USER}",
        "ssh_key_data": "${SSH_KEY_ESCAPED}"
    }
}
EOF
)

CREATE_RESPONSE=$(curl -sk -X POST "${AWX_URL}/api/v2/credentials/" \
    -H "Authorization: Bearer ${AWX_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$CREATE_PAYLOAD" || echo "")

if [ -z "$CREATE_RESPONSE" ]; then
    echo -e "${RED}Error: Failed to create credential${NC}"
    exit 1
fi

NEW_CRED_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$NEW_CRED_ID" ]; then
    echo -e "${RED}Error: Failed to create credential${NC}"
    echo "Response: $CREATE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Credential created successfully!${NC}"
echo ""
echo "=========================================="
echo "Credential Configuration Complete"
echo "=========================================="
echo "Credential ID: $NEW_CRED_ID"
echo "Credential Name: $CREDENTIAL_NAME"
echo "Username: $AUTOMAN_USER"
echo "SSH Key: $SSH_KEY_PATH"
echo ""
echo "You can now use this credential in AWX job templates."
echo ""

