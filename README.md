This repository is one of the Nine Laboratories of Baker Street.
It shall remain focused, independent, and well-documented.
We do not rebuild Frankenstein.
— The Baker Street Compact, 2026

# baker-street-labs-2.0

**Infrastructure as Code** - Ansible, Terraform, Packer, and AWX automation platform

**Last Updated**: 2026-01-08

---

## Overview

The Baker Street Labs Infrastructure as Code repository provides comprehensive automation for the cyber range infrastructure using Ansible, Terraform, Packer, and AWX (Ansible Automation Platform). This repository enables zero-touch deployment, configuration management, and golden image creation for Windows Server 2025, Windows 11 Pro, and Linux systems.

---

## Components

### **Ansible**
- Configuration management playbooks
- Active Directory domain controller automation
- AWX integration and secret management
- DNS agent validation and deployment verification
- Dynamic inventory management

### **Terraform**
- Infrastructure provisioning with libvirt provider (KVM)
- Cloud-Init integration for Windows and Linux
- Network and storage automation
- VM lifecycle management

### **Packer**
- Golden image creation for Windows Server 2025
- Windows 11 Pro image templates
- Active Directory Domain Controller pre-configured images
- Immutable image factory

### **AWX (Ansible Automation Platform)**
- **Location**: rangeawx.bakerstreetlabs.io (192.168.0.75)
- **Version**: 24.6.1 (AWX Operator 2.19.1)
- **Platform**: K3s on Ubuntu 22.04 LTS
- **Access**: https://rangeawx.bakerstreetlabs.io

### **Holmes AWX Agent**
- LLM-powered automation orchestrator
- Natural language interface to AWX
- Multi-step workflow orchestration
- LangGraph state machine integration

---

## Quick Start

### Ansible

```bash
# Run AD domain controller configuration
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/configure-ad01.yml

# Validate deployment
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/validate-deployment.yml

# Configure AWX secrets
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/awx-secret-and-holmes-token.yml
```

### Terraform

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan infrastructure changes
terraform plan

# Apply infrastructure
terraform apply
```

### Packer

```bash
# Build Windows Server 2025 golden image
cd packer
packer build windows-server-2025.pkr.hcl

# Build Windows 11 Pro image
cd hyperv-automation/packer/templates
packer build windows-11-pro.pkr.hcl
```

### AWX Access

```bash
# Access AWX web interface
https://rangeawx.bakerstreetlabs.io

# Default username: admin
# Password: Stored in Kubernetes secret `awx-admin-password` (namespace: awx)
```

---

## Project Structure

```
baker-street-labs-2.0/
├── ansible/                      # Ansible playbooks and inventory
│   ├── inventory/                # Dynamic inventory files
│   └── playbooks/                # Configuration playbooks
├── infrastructure/               # Infrastructure as Code definitions
│   ├── ansible/                  # Ansible playbooks and inventory
│   ├── terraform/                # Terraform configurations
│   │   ├── cloud-init/           # Cloud-Init configuration files
│   │   ├── main.tf               # Main Terraform configuration (libvirt/KVM)
│   │   └── range-templates/      # Range VM templates
│   │       └── rangetemplate/    # Range template (vSphere)
│   ├── packer/                   # Packer image templates
│   │   ├── scripts/              # Provisioning scripts
│   │   ├── answer_files/         # Windows autounattend files
│   │   └── *.pkr.hcl             # Packer template files
│   └── hyperv/                   # Hyper-V automation platform
│       ├── packer/               # Packer templates for Hyper-V
│       └── scripts/              # Host configuration and provisioning
├── agents/                       # Automation agents
│   └── holmes_awx_agent/         # Holmes AWX Agent (LLM orchestrator)
│       ├── main.py               # FastAPI service
│       ├── awx_adapter.py        # AWX API client
│       ├── llm_orchestrator.py   # LLM workflow orchestrator
│       └── graph.py              # LangGraph state machine
└── scripts/                      # Utility scripts
    ├── awx/                      # AWX configuration scripts
    ├── range/                    # Range provisioning scripts
    └── range-templates/          # Range template extraction scripts
        └── rangetemplate/        # Range template vCenter extraction
```

---

## Key Features

### Zero-Touch Automation
- Complete headless Windows AD deployment
- Automated golden image creation
- Infrastructure provisioning without manual intervention
- Cloud-Init integration for initial configuration

### Multi-Platform Support
- **Hypervisors**: KVM (libvirt), Hyper-V
- **Operating Systems**: Windows Server 2025, Windows 11 Pro, Linux
- **Infrastructure**: Bare metal, VMs, containers (K3s/K8s)

### AWX Integration
- Centralized automation platform
- Job template management
- Workflow orchestration
- Holmes agent for natural language automation

---

## Component Details

### Holmes AWX Agent

**Location**: `agents/holmes_awx_agent/`  
**Purpose**: LLM-powered automation orchestrator for AWX

**Features**:
- Natural language interface to AWX
- Multi-step workflow orchestration via LangGraph
- AWX API integration for job templates and execution
- Multi-LLM support (Ollama, OpenAI, Anthropic)
- Webhook support for job callbacks

**Quick Start**:
```bash
# Install dependencies
cd agents/holmes_awx_agent
pip install -r requirements.txt

# Configure (~/.secrets)
AWX_API_URL=https://rangeawx.bakerstreetlabs.io
AWX_USERNAME=admin
AWX_PASSWORD=<password>
HOLMES_AWX_TOKEN=<agent-token>
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://macmini.bakerstreetlabs.io:11434
OLLAMA_MODEL=llama3.1:70b

# Start service
uvicorn main:app --host 0.0.0.0 --port 9001 --reload
```

**API Endpoints**:
- `GET /health` - Health check
- `GET /v1/job-templates` - List all templates
- `POST /v1/orchestrate` - Natural language request
- `POST /v1/webhooks/awx` - AWX job completion callback

**See**: [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture

### Packer Image Templates

**Location**: `infrastructure/packer/`  
**Purpose**: Golden image creation for Windows Server 2025

**Features**:
- Windows Server 2025 Standard base image for KVM
- VirtIO drivers integration
- Security hardening
- WinRM configuration for automation
- Optimized for virtualization

**Quick Start**:
```bash
# Build Windows Server 2025 image
cd infrastructure/packer
packer build windows-server-2025-standard.pkr.hcl

# Or use build script
.\build.ps1 -IsoPath "path/to/windows.iso" -VirtioIsoPath "path/to/virtio.iso"
```

**Prerequisites**:
- Packer >= 1.8.0
- QEMU/KVM
- Windows Server 2025 ISO
- VirtIO drivers ISO

**Configuration**:
- Product keys via Packer variables
- Admin password configurable
- Disk size, memory, CPU configurable
- Output: QCOW2 format for KVM

**See**: [ARCHITECTURE.md](ARCHITECTURE.md) for detailed build process

### Range Template Extraction

**Location**: `scripts/range-templates/rangetemplate/`  
**Purpose**: Extract VM configurations from vCenter for Terraform templates (template-based)

**Features**:
- PowerCLI script for comprehensive VM extraction
- JSON output with all VM properties
- Terraform template generation (planned)
- vSphere provider integration

**Quick Start**:
```powershell
# Extract VM configurations (template-based)
cd scripts/range-templates/rangetemplate
.\rangetemplate_extract.ps1 -FolderName "rangetemplate" -OutputFile "rangetemplate_vms.json"

# NOTE: IP addresses are NOT hardcoded - must be provided via Terraform variables (tfvars file) or user input
# In agentic situations, the agent should provide IP addresses via tfvars file

# Terraform configuration generated in:
# infrastructure/terraform/range-templates/rangetemplate/
#
# NOTE: IP addresses are NOT hardcoded - must be provided via Terraform variables (tfvars file) or user input
# In agentic situations, the agent should provide IP addresses via tfvars file
```

**Requirements**:
- VMware PowerCLI module
- vCenter access (10.55.250.97)
- Credentials in `.secrets` file

**Output**: JSON file with VM configurations (CPU, memory, disks, networks, etc.)

**Status**: Script created, syntax error needs debugging (see STATUS.md)

---

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Complete technical architecture and infrastructure design
- **[DESIGN.md](DESIGN.md)**: System design diagrams and automation workflows
- **[STATUS.md](STATUS.md)**: Current operational status and recent changes
- **[CHANGES.md](CHANGES.md)**: Historical changelog
- **[ROADMAP.md](ROADMAP.md)**: Future plans and enhancements

---

## Related Repositories

- **[baker-street-dns](../baker-street-dns/)**: DNS automation and management
- **[baker-street-portal](../baker-street-portal/)**: Portal server configuration
- **[baker-street-integrations](../baker-street-integrations/)**: PKI and certificate automation
- **[baker-street-scenarios](../baker-street-scenarios/)**: Attack scenario automation

---

## Prerequisites

- **Ansible**: 2.15+ (with Windows modules)
- **Terraform**: 1.8+
- **Packer**: 1.10+
- **Python**: 3.11+ (for Holmes AWX Agent)
- **PowerShell**: 5.1+ (for Windows automation)
- **KVM/libvirt**: For Linux-based infrastructure
- **Hyper-V**: For Windows-based infrastructure (optional)

---

## Security Notes

⚠️ **IMPORTANT**: All credentials and secrets are stored in `.secrets` files and Kubernetes secrets. Never commit passwords or API keys to version control.

**Secrets Management**:
- Local: `~/.secrets` or `.secrets` in project root
- AWX: Kubernetes secrets (namespace: `awx`)
- Ansible Vault: For encrypted playbook variables

---

**Maintained By**: Baker Street Labs Infrastructure Team  
**Documentation Rule**: All IaC information goes into ARCHITECTURE.md unless it is a status update (→ STATUS.md) or a README.md item.
