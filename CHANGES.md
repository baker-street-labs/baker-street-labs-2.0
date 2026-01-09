# Changelog

All notable changes to the Baker Street Labs Infrastructure as Code repository will be documented in this file.

---

## [Unreleased]

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

