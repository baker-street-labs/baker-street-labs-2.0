#!/usr/bin/env python3
"""
Configure AWX with test job templates for Holmes AWX Agent.

This script creates:
- Test project
- Test inventory
- Test job templates
- Test playbooks

Usage:
    python3 configure_awx_templates.py <awx-url> <username> <password>
"""

import sys
import json
import httpx
from pathlib import Path

def get_token(base_url: str, username: str, password: str) -> str:
    """Get OAuth2 token from AWX."""
    response = httpx.post(
        f"{base_url}/api/v2/tokens/",
        json={"description": "holmes-awx-agent-setup"},
        auth=(username, password),
        verify=False,  # For self-signed certs
    )
    response.raise_for_status()
    return response.json()["token"]

def make_request(method: str, url: str, token: str, **kwargs) -> dict:
    """Make authenticated request to AWX API."""
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = f"Bearer {token}"
    headers.setdefault("Content-Type", "application/json")
    
    response = httpx.request(method, url, headers=headers, verify=False, **kwargs)
    response.raise_for_status()
    return response.json()

def find_or_create_organization(base_url: str, token: str, name: str = "Default") -> int:
    """Find or create organization."""
    # Try to find existing
    data = make_request("GET", f"{base_url}/api/v2/organizations/?name={name}", token)
    if data.get("results"):
        return data["results"][0]["id"]
    
    # Create new
    data = make_request(
        "POST",
        f"{base_url}/api/v2/organizations/",
        token,
        json={"name": name},
    )
    return data["id"]

def find_or_create_project(base_url: str, token: str, org_id: int, name: str) -> int:
    """Find or create project."""
    # Try to find existing
    data = make_request("GET", f"{base_url}/api/v2/projects/?name={name}", token)
    if data.get("results"):
        return data["results"][0]["id"]
    
    # Create new
    data = make_request(
        "POST",
        f"{base_url}/api/v2/projects/",
        token,
        json={
            "name": name,
            "organization": org_id,
            "scm_type": "manual",
        },
    )
    return data["id"]

def find_or_create_inventory(base_url: str, token: str, org_id: int, name: str) -> int:
    """Find or create inventory."""
    # Try to find existing
    data = make_request("GET", f"{base_url}/api/v2/inventories/?name={name}", token)
    if data.get("results"):
        inv_id = data["results"][0]["id"]
    else:
        # Create new
        data = make_request(
            "POST",
            f"{base_url}/api/v2/inventories/",
            token,
            json={
                "name": name,
                "organization": org_id,
            },
        )
        inv_id = data["id"]
    
    # Add localhost host if not exists
    hosts_data = make_request("GET", f"{base_url}/api/v2/inventories/{inv_id}/hosts/", token)
    if not any(h["name"] == "localhost" for h in hosts_data.get("results", [])):
        make_request(
            "POST",
            f"{base_url}/api/v2/inventories/{inv_id}/hosts/",
            token,
            json={"name": "localhost"},
        )
    
    return inv_id

def create_job_template(
    base_url: str,
    token: str,
    name: str,
    description: str,
    project_id: int,
    inventory_id: int,
    playbook: str,
    extra_vars: dict = None,
) -> int:
    """Create or update job template."""
    # Try to find existing
    data = make_request("GET", f"{base_url}/api/v2/job_templates/?name={name}", token)
    if data.get("results"):
        template_id = data["results"][0]["id"]
        # Update
        make_request(
            "PATCH",
            f"{base_url}/api/v2/job_templates/{template_id}/",
            token,
            json={
                "description": description,
                "playbook": playbook,
                "extra_vars": json.dumps(extra_vars or {}),
            },
        )
        return template_id
    
    # Create new
    data = make_request(
        "POST",
        f"{base_url}/api/v2/job_templates/",
        token,
        json={
            "name": name,
            "description": description,
            "job_type": "run",
            "project": project_id,
            "inventory": inventory_id,
            "playbook": playbook,
            "extra_vars": json.dumps(extra_vars or {}),
        },
    )
    return data["id"]

def main():
    if len(sys.argv) < 4:
        print("Usage: python3 configure_awx_templates.py <awx-url> <username> <password>")
        sys.exit(1)
    
    base_url = sys.argv[1].rstrip("/")
    username = sys.argv[2]
    password = sys.argv[3]
    
    print(f"Connecting to AWX at {base_url}...")
    token = get_token(base_url, username, password)
    print("✓ Token obtained")
    
    # Get or create organization
    org_id = find_or_create_organization(base_url, token)
    print(f"✓ Organization ID: {org_id}")
    
    # Create project
    project_id = find_or_create_project(base_url, token, org_id, "holmes-test-project")
    print(f"✓ Project ID: {project_id}")
    
    # Create inventory
    inv_id = find_or_create_inventory(base_url, token, org_id, "holmes-test-inventory")
    print(f"✓ Inventory ID: {inv_id}")
    
    # Create job templates
    templates = [
        {
            "name": "test-hello-world",
            "description": "Simple hello world test template",
            "playbook": "hello.yml",
            "extra_vars": {},
        },
        {
            "name": "test-system-info",
            "description": "Gather system information",
            "playbook": "system_info.yml",
            "extra_vars": {},
        },
        {
            "name": "test-install-package",
            "description": "Install a package on target hosts",
            "playbook": "install_package.yml",
            "extra_vars": {"package_name": "nginx"},
        },
    ]
    
    print("\nCreating job templates...")
    for template in templates:
        template_id = create_job_template(
            base_url,
            token,
            template["name"],
            template["description"],
            project_id,
            inv_id,
            template["playbook"],
            template["extra_vars"],
        )
        print(f"✓ Created template: {template['name']} (ID: {template_id})")
    
    print("\n✓ Configuration complete!")
    print("\nNote: You still need to:")
    print("1. Upload playbooks to AWX project directory")
    print("2. Sync the project in AWX UI")
    print("3. Assign credentials if needed (for install-package template)")

if __name__ == "__main__":
    main()

