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
├── terraform/                    # Terraform infrastructure definitions
│   ├── cloud-init/               # Cloud-Init configuration files
│   └── main.tf                   # Main Terraform configuration
├── packer/                       # Packer image templates
│   ├── scripts/                  # Provisioning scripts
│   ├── answer_files/             # Windows autounattend files
│   └── windows-server-2025/      # Windows Server 2025 templates
├── hyperv-automation/            # Hyper-V zero-touch automation platform
│   ├── docs/                     # Documentation and blueprints
│   ├── packer/                   # Packer templates for Hyper-V
│   ├── scripts/                  # Host configuration and provisioning
│   └── terraform/                # Terraform configurations (if present)
├── agents/                       # Automation agents
│   └── holmes_awx_agent/         # Holmes AWX Agent (LLM orchestrator)
└── scripts/                      # Utility scripts
    ├── awx/                      # AWX configuration scripts
    └── range/                    # Range provisioning scripts
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
