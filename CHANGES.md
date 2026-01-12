# Changelog

All notable changes to the Baker Street Labs Infrastructure as Code repository will be documented in this file.

---

## [Unreleased]

### Added
- ✅ Range Platform dynamic implementation analysis (2026-01-11)
  - Comprehensive analysis document for rangeplatform (172.24.0.0/16) covering Firewall (PAN-OS), Active Directory, and Windows Clients
  - Dynamic implementation approaches using Terraform, Ansible, and PowerShell
  - Code examples and templates for PAN-OS firewall configuration (Python panos library, Ansible panos collection)
  - Code examples for Active Directory configuration (Ansible microsoft.ad collection, PowerShell AD cmdlets)
  - Code examples for Windows client configuration (Ansible windows collection, PowerShell DSC)
  - Integration patterns and workflows (Terraform → Ansible, AWX/Tower orchestration)
  - Context7 documentation references (Ansible collections, PowerShell documentation)
  - Best practices and recommendations for state management, credential management, testing
  - Document location: `infrastructure/terraform/range-templates/rangecomp/rangeplatform_dynamic_implementation.md`
- ✅ Range Comp (rangecomp) template with 172.24.0.0/16 network assignment (2026-01-11)
  - Created from rangetemplate base (`infrastructure/terraform/range-templates/rangecomp/`)
  - Network assignment: 172.24.0.0/16 (Users: .2.0/24, Services: .3.0/24, Infrastructure: .4.0/24)
  - VLAN assignments: 2401-2406 (per-range vSwitches/VLANs pattern)
  - Storage requirement: liacmain01 datastore for all VMs
  - VM affinity rule: All VMs on same host (rangecomp-vm-affinity)
  - IP addresses configured via Terraform variables (tfvars file) or user input
  - Architecture documentation updated with rangecomp assignment
- ✅ Range template extraction from vCenter with affinity rules (2026-01-11)
  - Enhanced PowerCLI extraction script with affinity rules and network config (`scripts/range-templates/rangetemplate/rangetemplate_extract.ps1`)
  - Terraform template configuration with VM affinity rules (`infrastructure/terraform/range-templates/rangetemplate/`)
  - Architecture documentation with affinity rules, network topology, and IP/VLAN configuration (`rangetemplate_architecture.md`)
  - Design documentation with Mermaid diagrams for affinity rules and network topology (`rangetemplate_design.md`)
  - Storage requirement: liacmain01 datastore for all VMs
  - Network configuration: Configurable via variables (IP addresses from user/tfvars/agent)
  - VLAN assignments: Configurable via variables (per-range vSwitches/VLANs pattern)
  - VM affinity rule: All VMs on same host (configurable name based on folder)
  - IP address configuration: NOT hardcoded - provided via Terraform variables (tfvars file) or user input
  - Agentic support: In agentic situations, the agent should provide IP addresses via tfvars file
  - Security audit completed - all files secure (no hardcoded credentials)

---

## [2026-01-08] - Documentation Migration

### Added
- ✅ Complete documentation migration from monorepo
- ✅ Repository structure established with 6 root files
- ✅ All IaC content consolidated into baker-street-labs-2.0

### Changed
- ✅ Project structure reorganized for clarity
- ✅ Documentation refactored following anti-bloat guidelines

---

## [2025-11-18] - AWX Deployment

### Added
- ✅ AWX (Ansible Automation Platform) deployed on K3s
- ✅ AWX Operator 2.19.1 installed
- ✅ AWX Web and Task containers configured
- ✅ PostgreSQL 15 backend for AWX
- ✅ Redis cache and message broker
- ✅ HTTPS access via Traefik Ingress
- ✅ Holmes AWX Agent (LLM orchestrator) integrated

### Configuration
- ✅ Primary IP: 192.168.0.75
- ✅ FQDN: rangeawx.bakerstreetlabs.io
- ✅ HTTPS URL: https://rangeawx.bakerstreetlabs.io
- ✅ Wildcard SSL certificate (*.bakerstreetlabs.io)
- ✅ Namespace: `awx`

---

## [2025-09-24] - Truly Headless AD Deployment

### Added
- ✅ Terraform + Cloud-Init + Ansible integration for zero-touch AD deployment
- ✅ WinRM and SSH automation for Windows
- ✅ Complete headless Windows AD deployment (40 minutes, zero manual intervention)
- ✅ Cloud-Init Windows configuration support
- ✅ Ansible playbook for AD domain controller configuration

### Changed
- ✅ Eliminated VNC dependency for AD deployment
- ✅ Automated all AD configuration steps

---

## [2025-09-XX] - Hyper-V Zero-Touch Automation Platform

### Added
- ✅ Comprehensive Hyper-V automation platform
- ✅ Packer templates for Windows Server 2025
- ✅ Packer templates for Windows 11 Pro
- ✅ Golden image creation pipeline
- ✅ Host configuration automation scripts
- ✅ VM provisioning and hardening scripts
- ✅ Active Directory deployment automation

### Configuration
- ✅ Windows Server 2025 Core support
- ✅ Hyper-V host automation
- ✅ Virtual switch configuration
- ✅ Remote management enablement

---

## [2025-XX-XX] - Terraform Infrastructure Provisioning

### Added
- ✅ Terraform configuration for libvirt provider (KVM)
- ✅ VM provisioning with cloud-init
- ✅ Network and storage automation
- ✅ Cloud-Init integration for Windows and Linux

### Configuration
- ✅ Provider: libvirt (dmacvicar/libvirt 0.7.6)
- ✅ Hypervisor: KVM via qemu:///system
- ✅ Network: libvirt default network
- ✅ Storage: qcow2 format

---

## [2025-XX-XX] - Packer Golden Image Creation

### Added
- ✅ Packer templates for Windows Server 2025
- ✅ Packer templates for Windows 11 Pro
- ✅ Immutable golden image factory
- ✅ Automated image building with WinRM and SSH
- ✅ Security baseline application
- ✅ Software pre-installation support

### Configuration
- ✅ Builder: QEMU (KVM)
- ✅ Output Format: qcow2
- ✅ Communicator: WinRM
- ✅ Provisioners: PowerShell scripts
- ✅ Post-processors: Image optimization

---

## [2025-XX-XX] - Ansible Playbooks

### Added
- ✅ AD domain controller configuration playbook
- ✅ AWX secret and token management playbook
- ✅ DNS agent validation playbook
- ✅ Deployment validation playbook

### Configuration
- ✅ Inventory: Static and dynamic inventories
- ✅ Connection: WinRM for Windows, SSH for Linux
- ✅ Modules: win_shell, win_feature, win_domain_controller

---

**Note**: This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

