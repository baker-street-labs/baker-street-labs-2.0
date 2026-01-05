# AWX Configuration Guide for Holmes AWX Agent

This guide helps you configure AWX with test job templates for Holmes AWX Agent testing.

## Prerequisites

- AWX instance accessible at `https://rangeawx.bakerstreetlabs.io`
- Admin credentials
- Basic understanding of AWX concepts (projects, inventories, credentials)

## Quick Setup Steps

### 1. Create a Test Project

1. Log into AWX UI
2. Navigate to **Projects**
3. Click **Add** → **Project**
4. Configure:
   - **Name**: `holmes-test-project`
   - **Organization**: Default
   - **SCM Type**: Manual (or Git if you have a repo)
   - **Playbook Directory**: `/var/lib/awx/projects/holmes-test-project`

### 2. Upload Playbooks

Upload the test playbooks from `examples/test_playbooks/`:

```bash
# SSH to AWX server
ssh automan@rangeawx.bakerstreetlabs.io

# Create project directory
sudo mkdir -p /var/lib/awx/projects/holmes-test-project
sudo chown awx:awx /var/lib/awx/projects/holmes-test-project

# Copy playbooks
sudo cp hello.yml /var/lib/awx/projects/holmes-test-project/
sudo cp system_info.yml /var/lib/awx/projects/holmes-test-project/
sudo cp install_package.yml /var/lib/awx/projects/holmes-test-project/

# Set permissions
sudo chown -R awx:awx /var/lib/awx/projects/holmes-test-project
```

### 3. Create Test Inventory

1. Navigate to **Inventories**
2. Click **Add** → **Inventory**
3. Configure:
   - **Name**: `holmes-test-inventory`
   - **Organization**: Default
4. Add hosts:
   - Click **Hosts** tab
   - Add host: `localhost` (for testing)

### 4. Create Job Templates via API

Use the provided script or create manually:

```bash
# Using the script
cd services/holmes_awx_agent/scripts
chmod +x create_test_templates.sh
./create_test_templates.sh https://rangeawx.bakerstreetlabs.io admin <password>
```

Or create manually via AWX UI:

#### Template 1: Hello World
- **Name**: `test-hello-world`
- **Job Type**: Run
- **Inventory**: `holmes-test-inventory`
- **Project**: `holmes-test-project`
- **Playbook**: `hello.yml`
- **Credentials**: None needed (runs on localhost)

#### Template 2: System Info
- **Name**: `test-system-info`
- **Job Type**: Run
- **Inventory**: `holmes-test-inventory`
- **Project**: `holmes-test-project`
- **Playbook**: `system_info.yml`
- **Credentials**: None needed

#### Template 3: Install Package
- **Name**: `test-install-package`
- **Job Type**: Run
- **Inventory**: `holmes-test-inventory`
- **Project**: `holmes-test-project`
- **Playbook**: `install_package.yml`
- **Credentials**: Machine credential (for sudo)
- **Extra Variables**: `{"package_name": "nginx"}`

### 5. Test via Holmes AWX Agent

Once templates are created, test with:

```bash
# List templates
curl -H "X-Holmes-AWX-Token: <token>" \
  https://localhost:9001/v1/job-templates

# Launch a job
curl -X POST \
  -H "X-Holmes-AWX-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "job_template_name": "test-hello-world"
  }' \
  https://localhost:9001/v1/jobs

# Test orchestration
curl -X POST \
  -H "X-Holmes-AWX-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "Run the hello world test template"
  }' \
  https://localhost:9001/v1/orchestrate
```

## Advanced Configuration

### Create More Complex Templates

For multi-step workflows, create templates that can be chained:

1. **provision-server**: Provision a new server
2. **configure-nginx**: Configure nginx
3. **deploy-application**: Deploy application

The LLM orchestrator can chain these together based on natural language requests.

### Webhook Integration (Phase 4)

For webhook callbacks, configure job templates to POST to:
```
https://holmes-awx-agent:9001/v1/webhooks/awx
```

Add to playbook:
```yaml
- name: Notify Holmes Agent
  uri:
    url: "https://holmes-awx-agent:9001/v1/webhooks/awx"
    method: POST
    body_format: json
    body:
      job_id: "{{ ansible_job_id }}"
      status: "{{ job_status }}"
```

## Troubleshooting

### Templates Not Found
- Verify project is synced
- Check playbook paths are correct
- Ensure inventory is assigned

### Jobs Fail
- Check credentials are assigned
- Verify hosts are reachable
- Review job output in AWX UI

### LLM Can't Find Templates
- Ensure template names match exactly (case-sensitive)
- Use `list_awx_job_templates` tool to see available templates
- Check AWX API connectivity

