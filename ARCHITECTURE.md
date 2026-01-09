# Infrastructure as Code Architecture

**Last Updated**: 2026-01-08

---

## Overview

The Baker Street Labs Infrastructure as Code platform provides comprehensive automation for infrastructure provisioning, configuration management, golden image creation, and workflow orchestration. It leverages Ansible, Terraform, Packer, and AWX to enable zero-touch deployment and configuration management.

---

## Architecture Components

### Ansible

**Purpose**: Configuration management and orchestration

**Key Features**:
- Configuration management for Windows and Linux
- Active Directory domain controller automation
- AWX integration and secret management
- Dynamic inventory management
- Playbook-based automation

**Components**:
- **Playbooks**: YAML-based automation scripts
  - `configure-ad01.yml` - AD domain controller configuration
  - `awx-secret-and-holmes-token.yml` - AWX secret management
  - `check-holmes-dns-agent.yml` - DNS agent validation
  - `validate-deployment.yml` - Deployment verification
- **Inventory**: Host and group definitions
  - Static inventory files
  - Dynamic inventory scripts
- **Modules**: Built-in and custom modules
  - Windows modules (win_shell, win_feature, win_domain_controller)
  - Linux modules (apt, yum, systemd, service)
- **Roles**: Reusable automation components (future)

**Connection Methods**:
- **Windows**: WinRM (HTTP/HTTPS on ports 5985/5986)
- **Linux**: SSH (port 22)
- **Network**: 192.168.0.0/16 cyber range network

---

### Terraform

**Purpose**: Infrastructure provisioning and lifecycle management

**Key Features**:
- Declarative infrastructure definition
- Multi-provider support (libvirt, AWS, Azure, GCP - planned)
- State management
- Cloud-Init integration
- Resource dependency management

**Components**:
- **Main Configuration**: `terraform/main.tf`
  - Libvirt provider configuration (KVM)
  - VM provisioning definitions
  - Network and storage configuration
- **Variables**: Input variables for customization
- **Outputs**: Output values for integration
- **Cloud-Init**: `terraform/cloud-init/`
  - `user-data.yml` - Windows initialization scripts
  - `meta-data.yml` - VM metadata configuration

**Provider**: Libvirt (dmacvicar/libvirt 0.7.6)
- **Hypervisor**: KVM via qemu:///system
- **Network**: libvirt default network (192.168.100.0/24)
- **Storage**: qcow2 format, libvirt default pool
- **VM Configuration**: Memory, CPU, disk, network interfaces

**Terraform Workflow**:
1. `terraform init` - Initialize provider plugins
2. `terraform plan` - Preview changes
3. `terraform apply` - Apply infrastructure changes
4. `terraform destroy` - Remove infrastructure (if needed)

---

### Packer

**Purpose**: Golden image creation for immutable infrastructure

**Key Features**:
- Multi-platform image building
- Automated image provisioning
- Security baseline application
- Software pre-installation
- Image optimization

**Components**:
- **Templates**: HCL-based image definitions
  - `packer/windows-server-2025.pkr.hcl` - Windows Server 2025 golden image
  - `packer-windows-2025/windows-2025.pkr.hcl` - Alternative template
  - `hyperv-automation/packer/templates/windows-server-2025-core.pkr.hcl` - Hyper-V template
  - `hyperv-automation/packer/templates/windows-11-pro.pkr.hcl` - Windows 11 Pro template
- **Scripts**: Provisioning scripts
  - Windows updates installation
  - Feature installation
  - Security baseline application
  - WinRM and SSH configuration
  - Sysprep and generalization
- **Answer Files**: Windows unattended installation files
  - `packer/answer_files/autounattend.xml`
  - `hyperv-automation/packer/autounattend/autounattend.xml`

**Builders**:
- **QEMU/KVM**: Primary builder for Linux hosts
  - Format: qcow2
  - Accelerator: KVM
  - Communicator: WinRM (Windows) or SSH (Linux)
- **Hyper-V**: Builder for Windows hosts (hyperv-automation)
  - Format: VHDX
  - Hypervisor: Hyper-V
  - Communicator: WinRM

**Packer Workflow**:
1. `packer validate` - Validate template syntax
2. `packer build` - Build golden image
3. Image provisioning (updates, features, security)
4. Sysprep/generalization (Windows)
5. Image output to specified location

---

### AWX (Ansible Automation Platform)

**Purpose**: Centralized automation platform and workflow orchestration

**Key Features**:
- Web-based automation interface
- Job template management
- Workflow orchestration
- Inventory management
- Credential management
- Role-based access control (RBAC)

**Infrastructure**:
- **Location**: rangeawx.bakerstreetlabs.io (192.168.0.75)
- **Platform**: K3s on Ubuntu 22.04 LTS
- **Version**: 24.6.1
- **AWX Operator**: 2.19.1
- **Namespace**: `awx`
- **Access**: HTTPS via Traefik Ingress

**Components**:
- **AWX Web**: Web interface (3 containers: nginx, uwsgi, receptor)
- **AWX Task**: Task execution engine (4 containers: receptor, ansible-runner, etc.)
- **PostgreSQL**: Database backend (version 15)
- **Redis**: Cache and message broker

**Integration**:
- **Holmes AWX Agent**: LLM-powered orchestrator
  - Natural language interface
  - Multi-step workflow orchestration
  - LangGraph state machine
  - AWX API integration

---

### Holmes AWX Agent

**Purpose**: LLM-powered automation orchestrator for AWX

**Key Features**:
- Natural language interface to AWX
- Multi-step workflow orchestration
- LangGraph state machine integration
- Multi-LLM support (Ollama, OpenAI, Anthropic)
- Webhook support for job callbacks
- Token-based authentication (future: StepCA/OIDC)

**Architecture**:
```
User Request → LLM Orchestrator → LangGraph Workflow → AWX Job Templates → Results
```

**Components**:
- **LLM Orchestrator**: Interprets natural language requests
- **LangGraph Workflow**: State machine for complex workflows
- **AWX Adapter**: API integration with AWX
- **Job Manager**: Job tracking and monitoring
- **Webhook Handler**: Receives callbacks from AWX jobs

**API Endpoints**:
- `GET /health` - Health check
- `GET /v1/job-templates` - List job templates
- `POST /v1/jobs` - Launch job template
- `GET /v1/jobs/{job_id}` - Get job status
- `POST /v1/orchestrate` - Natural language request
- `POST /v1/webhooks/awx` - AWX job completion callback

---

## Workflow Integration

### Zero-Touch AD Deployment Workflow

**Components**: Terraform + Cloud-Init + Ansible

**Process**:
1. **Terraform Provisioning** (5 minutes)
   - Create libvirt network (192.168.100.0/24)
   - Provision AD01 VM with cloud-init
   - Configure VNC access (for debugging only)
   - Set up storage and networking

2. **Cloud-Init Configuration** (10 minutes)
   - Network configuration (static IP)
   - WinRM setup (remote PowerShell)
   - SSH installation (OpenSSH Server)
   - User creation (automation users)
   - SSH key setup (authorized_keys)
   - Service configuration (RDP, WinRM, SSH)

3. **Ansible AD Configuration** (20 minutes)
   - WinRM connection establishment
   - Network setup (static IP configuration)
   - AD DS role installation
   - DNS server installation
   - Certificate Services installation
   - Domain controller promotion
   - OU and user creation
   - Service configuration

4. **Verification** (5 minutes)
   - Service connectivity tests
   - Domain controller verification
   - Final status reporting

**Total Time**: ~40 minutes with zero manual intervention

---

### Golden Image Creation Workflow

**Components**: Packer + Provisioners

**Process**:
1. **Image Building** (Packer)
   - ISO loading (Windows Server 2025 / Windows 11 Pro)
   - VM creation (QEMU/KVM or Hyper-V)
   - Unattended installation (autounattend.xml)

2. **Provisioning** (PowerShell Scripts)
   - Windows updates installation
   - Feature installation (AD DS, DNS, Certificate Services)
   - Security baseline application
   - WinRM configuration
   - SSH configuration
   - Software pre-installation (optional)

3. **Generalization** (Sysprep)
   - System preparation
   - Driver cleanup
   - User account cleanup
   - Registry cleanup

4. **Image Output**
   - qcow2 format (KVM)
   - VHDX format (Hyper-V)
   - Image optimization
   - Metadata tagging

**Build Time**: 30-40 minutes for Windows Server 2025, 25-35 minutes for Windows 11 Pro

---

### AWX Workflow Orchestration

**Components**: AWX + Holmes AWX Agent

**Process**:
1. **Natural Language Request** (Holmes Agent)
   - User submits request: "Deploy nginx on Kubernetes"
   - LLM orchestrator interprets request
   - Identifies required AWX job templates
   - Creates workflow graph

2. **Workflow Execution** (LangGraph)
   - State machine manages workflow steps
   - Parallel execution where possible
   - Dependency resolution
   - Error handling and retry logic

3. **AWX Job Execution**
   - Job template launch via AWX API
   - Ansible playbook execution
   - Real-time job monitoring
   - Status reporting

4. **Results and Callbacks**
   - Job completion webhook
   - Results aggregation
   - User notification
   - Log and artifact collection

---

## Network Architecture

### Cyber Range Network

**Primary Network**: 192.168.0.0/16

**Key Subnets**:
- **192.168.0.0/24**: Core infrastructure (DNS, portal, AWX)
- **192.168.100.0/24**: KVM/libvirt default network (Terraform-provisioned VMs)
- **192.168.255.0/24**: Firewall management networks
- **172.22.0.0/24 - 172.30.0.0/24**: Range-specific subnets

**Services**:
- **AWX**: 192.168.0.75 (rangeawx.bakerstreetlabs.io)
- **Portal**: 192.168.0.10 (portal.labinabox.net)
- **DNS**: 192.168.0.11/12 (ns1/ns2.bakerstreetlabs.io)
- **AD DCs**: 192.168.0.65/66 (ad01/ad02.ad.bakerstreetlabs.io)

---

## Security Architecture

### Credentials Management

**Local Secrets**: `~/.secrets` or `.secrets` in project root
- Ansible Vault passwords
- Terraform variable values
- Packer build secrets
- AWX API tokens

**AWX Secrets**: Kubernetes secrets (namespace: `awx`)
- `awx-admin-password` - AWX admin password
- `awx-postgres-password` - PostgreSQL password
- Custom credentials for playbooks

**Holmes Agent**: Token-based authentication
- Current: Token in `.secrets` (`HOLMES_AWX_TOKEN`)
- Future: StepCA/OIDC integration

### Access Control

**Ansible**:
- SSH key-based authentication (Linux)
- WinRM certificate-based authentication (Windows)
- Ansible Vault for encrypted variables

**Terraform**:
- Provider-specific authentication (libvirt uses Unix socket)
- Remote state backend authentication (if configured)

**AWX**:
- Role-based access control (RBAC)
- Credential management with encryption
- Audit logging

---

## Related Documentation

- **[README.md](README.md)**: Overview and quick start
- **[DESIGN.md](DESIGN.md)**: System design diagrams and automation workflows
- **[STATUS.md](STATUS.md)**: Current operational status
- **[CHANGES.md](CHANGES.md)**: Historical changelog
- **[ROADMAP.md](ROADMAP.md)**: Future plans and enhancements

---

**Maintained By**: Baker Street Labs Infrastructure Team

