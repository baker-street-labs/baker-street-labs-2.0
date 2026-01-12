# Range Platform Dynamic Implementation Analysis

**Created**: 2026-01-11  
**Focus**: rangeplatform (172.24.0.0/16)  
**Purpose**: Comprehensive analysis of dynamic implementation for Firewall, Active Directory, and Windows Clients using Terraform, Ansible, and PowerShell  
**Status**: Analysis & Implementation Guide

---

## Executive Summary

This document provides a deep analysis of internal configurations for **rangeplatform** (172.24.0.0/16) and assesses dynamic implementation approaches using Terraform, Ansible, and PowerShell. The analysis covers:

1. **PAN-OS Firewall** configuration (interfaces, zones, security policies, NAT)
2. **Active Directory** structure (OUs, users, groups, GPOs, DNS)
3. **Windows Clients** configuration (domain join, user accounts, group membership)

**Recommendation**: Use a hybrid approach:
- **Terraform**: Infrastructure provisioning (VMs, networks)
- **Ansible**: Configuration management (AD, clients, firewall rules)
- **PowerShell**: AD-specific operations and Windows automation
- **Python panos library**: Firewall configuration (existing pattern)

---

## Current Configuration State

### Range Platform Overview

**Network Assignment**: 172.24.0.0/16  
**Firewall**: 192.168.0.62 (rangeplatform.bakerstreetlabs.io)  
**Storage**: liacmain01 datastore  
**Affinity Rule**: All VMs on same host  
**VLANs**: 2401-2406

| Network | Subnet | Gateway | Purpose | VLAN | Status |
|---------|--------|---------|---------|------|--------|
| Users | 172.24.2.0/24 | 172.24.2.1 | User Workstations | 2402 | Active |
| Services | 172.24.3.0/24 | 172.24.3.1 | Services/DaaS | 2403 | Active |
| Infrastructure | 172.24.4.0/24 | 172.24.4.1 | Critical Infrastructure | 2404 | Active |

### PAN-OS Firewall Configuration

**Firewall IP**: 192.168.0.62 (MGMT)  
**Model**: VM-300  
**Status**: Active

#### Interface Configuration

| Interface | IP Address | Network | Purpose | Zone |
|-----------|------------|---------|---------|------|
| MGMT | 192.168.0.62 | 192.168.0.0/16 | Management | N/A |
| ethernet1/1 | 192.168.255.246/24 | 192.168.0.0/16 | Public Gateway | Public |
| ethernet1/1 (NAT) | 192.168.255.254 | 192.168.0.0/16 | RDP/WinRM NAT | Public |
| ethernet1/2 | 172.24.4.1/24 | 172.24.4.0/24 | Infrastructure Gateway | Infrastructure |
| ethernet1/3 | 172.24.3.1/24 | 172.24.3.0/24 | Services Gateway | Services |
| ethernet1/4 | 172.24.2.1/24 | 172.24.2.0/24 | Users Gateway | Users |

#### Current Firewall Configuration (Inferred)

**Zones Required**:
- Public (ethernet1/1)
- Infrastructure (ethernet1/2)
- Services (ethernet1/3)
- Users (ethernet1/4)

**Security Policies Required**:
- Inter-zone traffic rules (Users → Services, Users → Infrastructure, etc.)
- NAT rules for RDP/WinRM access
- DNS forwarding rules
- AD domain controller access rules

**Address Objects Required**:
- Range platform networks (172.24.2.0/24, 172.24.3.0/24, 172.24.4.0/24)
- Domain Controllers
- DNS servers
- Client subnets

### Active Directory Configuration

**Domain**: ad.bakerstreetlabs.io (or range-specific domain)  
**Domain Controllers**: bakerstreeta.ad.bakerstreetlabs.io (192.168.0.65), bakerstreetb.ad.bakerstreetlabs.io (192.168.0.66)

#### AD Structure Requirements (Range Platform)

**Organizational Units (OUs)**:
- RangePlatform (root OU)
  - Computers
    - Workstations (172.24.2.0/24)
    - Servers (172.24.3.0/24, 172.24.4.0/24)
  - Users
    - Standard Users
    - Administrators
  - Groups
  - Service Accounts

**Users Required**:
- Standard user accounts for workstations
- Service accounts for applications
- Administrator accounts

**Groups Required**:
- RangePlatform-Users (standard users)
- RangePlatform-Admins (administrators)
- RangePlatform-ServiceAccounts (service accounts)
- RangePlatform-Workstations (computer group)
- RangePlatform-Servers (computer group)

**GPOs Required**:
- Workstation GPO (Windows Update, security settings)
- Server GPO (security hardening, service configuration)
- User GPO (desktop, profile, security settings)

**DNS Zones/Records**:
- Range-specific DNS zone (if separate domain)
- A records for all VMs
- PTR records for reverse DNS
- SRV records for AD services

### Windows Client Configuration

**Client Requirements**:
- Domain join to ad.bakerstreetlabs.io
- User account assignment
- Group membership
- GPO application
- Network configuration (IP, DNS, gateway)
- Software installation (optional)

---

## Dynamic Implementation Approaches

### 1. PAN-OS Firewall Configuration

#### Option A: Python panos Library (Recommended - Current Pattern)

**Pros**:
- Already in use in codebase
- Full PAN-OS API coverage
- Python ecosystem integration
- Flexible and programmatic

**Cons**:
- Not declarative (imperative)
- State management manual
- No infrastructure-as-code integration

**Implementation Pattern**:

```python
from panos.firewall import Firewall
from panos.policies import SecurityRule, Rulebase
from panos.objects import AddressObject, AddressGroup
from panos.network import Interface, VirtualRouter, Zone

# Connect to firewall
fw = Firewall('192.168.0.62', 'admin', 'password')
fw.refresh_children()

# Create zones
public_zone = Zone('Public', 'public-zone')
infra_zone = Zone('Infrastructure', 'infra-zone')
services_zone = Zone('Services', 'services-zone')
users_zone = Zone('Users', 'users-zone')

fw.add([public_zone, infra_zone, services_zone, users_zone])
fw.apply()

# Create address objects
users_network = AddressObject('rangeplatform-users-net', '172.24.2.0/24')
services_network = AddressObject('rangeplatform-services-net', '172.24.3.0/24')
infra_network = AddressObject('rangeplatform-infra-net', '172.24.4.0/24')

fw.add([users_network, services_network, infra_network])
fw.apply()

# Create security rule
rule = SecurityRule(
    name='Allow-Users-to-Services',
    fromzone=['Users'],
    source=['rangeplatform-users-net'],
    tozone=['Services'],
    destination=['rangeplatform-services-net'],
    application=['any'],
    service=['application-default'],
    action='allow',
    log_start=True
)
fw.add(rule)
fw.apply()

# Commit
fw.commit()
```

**Integration with Terraform**:
- Use `local-exec` provisioner to run Python script
- Or use `null_resource` with Python script as dependency
- Pass Terraform variables to Python script

#### Option B: Ansible panos Collection

**Pros**:
- Declarative (Idempotent)
- Integration with Ansible playbooks
- State management handled

**Cons**:
- Additional dependency
- Learning curve
- May have limitations vs. Python library

**Implementation Pattern**:

```yaml
---
- name: Configure Range Platform Firewall
  hosts: localhost
  vars:
    panos_hostname: 192.168.0.62
    panos_username: admin
    panos_password: "{{ vault_panos_password }}"
    
  tasks:
    - name: Create zones
      panos_zone:
        provider: "{{ panos_auth }}"
        name: "{{ item.name }}"
        mode: layer3
      loop:
        - { name: "Public" }
        - { name: "Infrastructure" }
        - { name: "Services" }
        - { name: "Users" }
    
    - name: Create address objects
      panos_address_object:
        provider: "{{ panos_auth }}"
        name: "{{ item.name }}"
        value: "{{ item.value }}"
      loop:
        - { name: "rangeplatform-users-net", value: "172.24.2.0/24" }
        - { name: "rangeplatform-services-net", value: "172.24.3.0/24" }
        - { name: "rangeplatform-infra-net", value: "172.24.4.0/24" }
    
    - name: Create security rule
      panos_security_rule:
        provider: "{{ panos_auth }}"
        rule_name: "Allow-Users-to-Services"
        fromzone: ["Users"]
        source: ["rangeplatform-users-net"]
        tozone: ["Services"]
        destination: ["rangeplatform-services-net"]
        application: ["any"]
        action: allow
        log_start: true
```

#### Option C: Terraform Community Provider (panos)

**Note**: There is a Terraform provider for PAN-OS, but it's community-maintained. Check availability and stability.

**Pros**:
- Full Terraform integration
- State management
- Declarative

**Cons**:
- Community-maintained (may be less stable)
- May have limitations
- Additional provider to manage

### 2. Active Directory Configuration

#### Option A: Ansible microsoft.ad Collection (Recommended)

**Pros**:
- Native Ansible integration
- Declarative and idempotent
- Comprehensive AD module support
- Well-documented (Context7: /ansible-collections/microsoft.ad)

**Cons**:
- Requires WinRM or domain-joined Ansible controller
- AD module dependency

**Implementation Pattern**:

```yaml
---
- name: Configure Range Platform Active Directory
  hosts: domain_controllers
  vars:
    ad_domain: ad.bakerstreetlabs.io
    ad_dc: 192.168.0.65
    range_network: 172.24.0.0/16
    
  tasks:
    - name: Create RangePlatform OU structure
      microsoft.ad.object:
        name: "{{ item.name }}"
        path: "{{ item.path }}"
        type: "{{ item.type }}"
        state: present
      loop:
        - { name: "RangePlatform", path: "DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
        - { name: "Computers", path: "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
        - { name: "Workstations", path: "OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
        - { name: "Servers", path: "OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
        - { name: "Users", path: "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
        - { name: "Groups", path: "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io", type: "organizationalUnit" }
    
    - name: Create security groups
      microsoft.ad.group:
        name: "{{ item.name }}"
        path: "OU=Groups,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
        scope: security
        category: security
        state: present
      loop:
        - { name: "RangePlatform-Users" }
        - { name: "RangePlatform-Admins" }
        - { name: "RangePlatform-ServiceAccounts" }
        - { name: "RangePlatform-Workstations" }
        - { name: "RangePlatform-Servers" }
    
    - name: Create user accounts
      microsoft.ad.user:
        name: "{{ item.name }}"
        path: "OU=Users,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
        password: "{{ item.password | default(vault_user_password) }}"
        state: present
        groups: "{{ item.groups | default([]) }}"
      loop:
        - { name: "rp-user01", groups: ["RangePlatform-Users"] }
        - { name: "rp-admin01", groups: ["RangePlatform-Admins"] }
      no_log: true
    
    - name: Configure DNS zone (if range-specific)
      win_dns_record:
        name: "{{ item.name }}"
        zone: "{{ ad_domain }}"
        type: "{{ item.type }}"
        value: "{{ item.value }}"
        state: present
      loop:
        - { name: "rangeplatform-dc01", type: "A", value: "172.24.4.10" }
        - { name: "rangeplatform-ws01", type: "A", value: "172.24.2.10" }
```

#### Option B: PowerShell AD Cmdlets (Alternative)

**Pros**:
- Native Windows/AD support
- Comprehensive cmdlet library
- Well-documented (Context7: /microsoftdocs/powershell-docs)

**Cons**:
- Imperative (not declarative)
- State management manual
- Windows-only execution

**Implementation Pattern**:

```powershell
# Connect to domain
$domain = "ad.bakerstreetlabs.io"
$dc = "192.168.0.65"

# Import AD module
Import-Module ActiveDirectory

# Create OU structure
New-ADOrganizationalUnit -Name "RangePlatform" -Path "DC=ad,DC=bakerstreetlabs,DC=io"
New-ADOrganizationalUnit -Name "Computers" -Path "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
New-ADOrganizationalUnit -Name "Servers" -Path "OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
New-ADOrganizationalUnit -Name "Users" -Path "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"

# Create security groups
New-ADGroup -Name "RangePlatform-Users" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
New-ADGroup -Name "RangePlatform-Admins" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"

# Create users
$password = ConvertTo-SecureString "SecurePassword123!" -AsPlainText -Force
New-ADUser -Name "rp-user01" -Path "OU=Users,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io" -AccountPassword $password -Enabled $true
Add-ADGroupMember -Identity "RangePlatform-Users" -Members "rp-user01"
```

**Integration with Terraform/Ansible**:
- Use `local-exec` provisioner in Terraform
- Use `win_shell` or `script` module in Ansible
- Or create PowerShell DSC configuration

### 3. Windows Client Configuration

#### Option A: Ansible windows Collection (Recommended)

**Pros**:
- Native Ansible integration
- Declarative and idempotent
- Comprehensive Windows module support
- Well-documented (Context7: /ansible-collections/ansible.windows)

**Cons**:
- Requires WinRM on clients
- Windows-specific

**Implementation Pattern**:

```yaml
---
- name: Configure Range Platform Windows Clients
  hosts: rangeplatform_clients
  vars:
    ad_domain: ad.bakerstreetlabs.io
    ad_username: administrator
    ad_password: "{{ vault_ad_password }}"
    dns_servers:
      - 192.168.0.11
      - 192.168.0.12
    
  tasks:
    - name: Configure network adapter (Users network)
      win_network:
        name: "Ethernet"
        ip: "172.24.2.{{ item }}"
        netmask: "255.255.255.0"
        gateway: "172.24.2.1"
        dns_servers: "{{ dns_servers }}"
      loop: "{{ range(10, 50) | list }}"
      when: inventory_hostname == "rangeplatform-ws{{ item | string | regex_replace('^0', '') }}"
    
    - name: Join domain
      win_domain_membership:
        dns_domain_name: "{{ ad_domain }}"
        domain_admin_user: "{{ ad_username }}"
        domain_admin_password: "{{ ad_password }}"
        hostname: "{{ inventory_hostname }}"
        domain_ou_path: "OU=Workstations,OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
        state: domain
    
    - name: Move computer to OU (if already joined)
      win_shell: |
        Move-ADObject -Identity "CN={{ inventory_hostname }},CN=Computers,DC=ad,DC=bakerstreetlabs,DC=io" `
          -TargetPath "OU=Workstations,OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
      when: ansible_domain == ad_domain
    
    - name: Add user to local group (if needed)
      win_group_membership:
        name: "Remote Desktop Users"
        members: "{{ item }}"
        state: present
      loop:
        - "{{ ad_domain }}\\RangePlatform-Users"
    
    - name: Wait for GPO application
      pause:
        seconds: 120
      when: ansible_domain == ad_domain
    
    - name: Verify domain join
      win_shell: |
        (Get-WmiObject Win32_ComputerSystem).Domain
      register: domain_check
      failed_when: domain_check.stdout != "{{ ad_domain.upper() }}"
```

#### Option B: PowerShell DSC (Alternative)

**Pros**:
- Native Windows DSC support
- Declarative configuration
- State management

**Cons**:
- DSC learning curve
- Requires DSC infrastructure (pull server or push)
- More complex setup

**Implementation Pattern**:

```powershell
Configuration RangePlatformClientConfig {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    
    Node "rangeplatform-ws01" {
        Computer JoinDomain {
            Name = "rangeplatform-ws01"
            DomainName = "ad.bakerstreetlabs.io"
            Credential = $DomainCredential
            OrganizationalUnitPath = "OU=Workstations,OU=Computers,OU=RangePlatform,DC=ad,DC=bakerstreetlabs,DC=io"
        }
        
        Group AddToRemoteDesktopUsers {
            GroupName = "Remote Desktop Users"
            MembersToInclude = @("ad\RangePlatform-Users")
            DependsOn = "[Computer]JoinDomain"
        }
    }
}
```

---

## Integration Patterns & Workflows

### Recommended Workflow: Terraform + Ansible

**Phase 1: Infrastructure Provisioning (Terraform)**
1. Provision VMs via Terraform
2. Configure network adapters (IP addresses from variables)
3. Create VM affinity rules
4. Output VM IPs and names

**Phase 2: Firewall Configuration (Ansible + Python)**
1. Run Ansible playbook to configure PAN-OS firewall
2. Use Python panos library or Ansible panos collection
3. Create zones, address objects, security rules
4. Commit firewall configuration

**Phase 3: Active Directory Configuration (Ansible)**
1. Run Ansible playbook on domain controllers
2. Create OU structure (if not exists)
3. Create security groups
4. Create user accounts
5. Configure DNS records (if needed)

**Phase 4: Client Configuration (Ansible)**
1. Run Ansible playbook on clients
2. Configure network (if not done in Terraform)
3. Join domain
4. Apply GPOs (via group membership)
5. Configure users/groups

### Terraform → Ansible Integration

**Terraform Output Example**:

```hcl
output "vm_ips" {
  value = {
    for vm in vsphere_virtual_machine.rangeplatform_vms : vm.name => vm.default_ip_address
  }
}

output "vm_names" {
  value = [for vm in vsphere_virtual_machine.rangeplatform_vms : vm.name]
}
```

**Ansible Dynamic Inventory from Terraform**:

```yaml
# inventory/rangeplatform.yml (generated from Terraform output)
all:
  children:
    rangeplatform_firewall:
      hosts:
        rangeplatform-fw:
          ansible_host: 192.168.0.62
          ansible_user: admin
    
    rangeplatform_clients:
      hosts:
        rangeplatform-ws01:
          ansible_host: 172.24.2.10
          ansible_user: Administrator
        rangeplatform-ws02:
          ansible_host: 172.24.2.11
          ansible_user: Administrator
    
    domain_controllers:
      hosts:
        ad01:
          ansible_host: 192.168.0.65
          ansible_user: administrator
```

**Ansible Playbook Execution**:

```bash
# Generate inventory from Terraform
terraform output -json | python scripts/generate_ansible_inventory.py > inventory/rangeplatform.yml

# Run playbooks
ansible-playbook -i inventory/rangeplatform.yml playbooks/configure-firewall.yml
ansible-playbook -i inventory/rangeplatform.yml playbooks/configure-ad.yml
ansible-playbook -i inventory/rangeplatform.yml playbooks/configure-clients.yml
```

### AWX/Tower Integration (Recommended)

**AWX Workflow**:
1. **Template 1**: Terraform Apply (infrastructure)
2. **Template 2**: Generate Inventory (from Terraform output)
3. **Template 3**: Configure Firewall (Ansible)
4. **Template 4**: Configure AD (Ansible)
5. **Template 5**: Configure Clients (Ansible)

**Benefits**:
- Centralized orchestration
- Job templates reusable
- Audit trail
- Error handling
- Retry logic

---

## Code Examples & Templates

### Terraform: VM Provisioning with Domain Join Preparation

```hcl
# rangecomp.tf (excerpt)
resource "vsphere_virtual_machine" "rangeplatform_ws01" {
  name             = "rangeplatform-ws01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.liacmain01.id
  folder           = data.vsphere_folder.rangecomp.path
  
  num_cpus = 2
  memory   = 4096
  guest_id = "windows9Server64Guest"
  
  network_interface {
    network_id   = data.vsphere_network.users[0].id
    adapter_type = "vmxnet3"
  }
  
  disk {
    label            = "disk0"
    size             = 60
    eagerly_scrub    = false
    thin_provisioned = true
  }
  
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    
    customize {
      windows_options {
        computer_name  = "rangeplatform-ws01"
        workgroup      = "WORKGROUP"
        admin_password = var.windows_admin_password  # From tfvars
      }
      
      network_interface {
        ipv4_address = "172.24.2.10"  # From variable/tfvars
        ipv4_netmask = 24
      }
      
      ipv4_gateway    = var.users_network_gateway  # 172.24.2.1
      dns_server_list = var.dns_servers  # [192.168.0.11, 192.168.0.12]
    }
  }
  
  # Provisioner to enable WinRM (if needed)
  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = "172.24.2.10"
      user     = "Administrator"
      password = var.windows_admin_password
      https    = false
      insecure = true
    }
    
    inline = [
      "winrm quickconfig -force",
      "winrm set winrm/config/service/auth @{Basic=\"true\"}"
    ]
  }
}
```

### Ansible: Complete Range Platform Configuration Playbook

```yaml
---
- name: Configure Range Platform Complete
  hosts: localhost
  vars:
    range_name: rangeplatform
    range_network: 172.24.0.0/16
    ad_domain: ad.bakerstreetlabs.io
    
  tasks:
    - name: Include firewall configuration
      include: tasks/configure-firewall.yml
      vars:
        firewall_ip: 192.168.0.62
    
    - name: Include AD configuration
      include: tasks/configure-ad.yml
      vars:
        dc_ip: 192.168.0.65
    
    - name: Include client configuration
      include: tasks/configure-clients.yml
```

---

## Best Practices & Recommendations

### 1. State Management

**Terraform**:
- Use remote state (S3, Terraform Cloud, etc.)
- Version state files
- Use state locking

**Ansible**:
- Use idempotent modules
- Check mode (`--check`) before applying
- Use tags for selective execution

**PowerShell**:
- Use `Test-Path`, `Get-ADObject` for idempotency
- Document state checks
- Implement rollback procedures

### 2. Credential Management

**Recommendation**: Use Ansible Vault for all secrets

```yaml
# group_vars/all/vault.yml (encrypted)
vault_panos_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...

vault_ad_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...
```

**Terraform**:
- Use `.tfvars` files (gitignored)
- Or use environment variables
- Or use secret management (HashiCorp Vault)

### 3. Testing & Validation

**Terraform**:
- Use `terraform plan` before apply
- Validate syntax: `terraform validate`
- Use Terraform Cloud for CI/CD

**Ansible**:
- Use `ansible-playbook --check --diff`
- Use Molecule for role testing
- Use AWX for testing workflows

**PowerShell**:
- Use Pester for testing
- Test on non-production first
- Implement dry-run mode

### 4. Documentation

- Document all configuration changes
- Keep architecture diagrams updated
- Document IP addresses and credentials (encrypted)
- Version control all code

---

## References

### Context7 Documentation

1. **Ansible Microsoft.AD Collection**: `/ansible-collections/microsoft.ad`
   - OU, user, group management
   - Domain controller operations

2. **Ansible Windows Collection**: `/ansible-collections/ansible.windows`
   - Domain join
   - User/group management
   - Windows configuration

3. **PowerShell Documentation**: `/microsoftdocs/powershell-docs`
   - Active Directory cmdlets
   - Windows automation

### Existing Codebase References

1. **Firewall Configuration**:
   - `baker-street-dns/scripts/panos/configure-firewall-rules.py`
   - Uses `panos` Python library

2. **AD Configuration**:
   - `baker-street-dns/scripts/setup/setup-ad-dns.ps1`
   - `baker-street-labs-2.0/infrastructure/ansible/playbooks/configure-ad01.yml`

3. **VM Configuration**:
   - `baker-street-labs-2.0/infrastructure/terraform/range-templates/rangecomp/`

---

## Conclusion

For **rangeplatform** (172.24.0.0/16) dynamic implementation, the recommended approach is:

1. **Terraform**: Provision infrastructure (VMs, networks, storage)
2. **Ansible**: Configure firewall, AD, and clients (declarative, idempotent)
3. **Python panos library**: Alternative for firewall (if Ansible limitations)
4. **PowerShell**: AD-specific operations (if needed)

**Integration**: Use AWX/Tower for orchestration, with Terraform outputs feeding Ansible inventory.

**Benefits**:
- Infrastructure as Code (Terraform)
- Configuration as Code (Ansible)
- Idempotent operations
- Version control
- Repeatable deployments
- Audit trail (AWX)

---

**Last Updated**: 2026-01-11  
**Status**: Analysis Complete - Implementation Guide Ready  
**Next Steps**: Create playbook templates and test implementation
