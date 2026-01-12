# Range Template Architecture

**Extracted**: 2026-01-11  
**Source**: vCenter folder template (10.55.250.97)  
**Status**: Template-Based with Affinity Rules & Network Configuration  
**Last Updated**: 2026-01-11

---

## Overview

This document describes the architecture of the range template extracted from vCenter. The template is designed for replicable deployment of cyber range infrastructure with specific requirements for VM placement, storage, networking, and IP addressing.

**Key Requirements**:
- All VMs must stay on the same node (VM affinity rule)
- Storage: liacmain01 datastore
- Folder: Configurable via variable (folder syntax: range<name>)
- Network: Configurable via variables (IP addresses from user/tfvars/agent)
- VLANs: Configurable via variables
- IP Addresses: **NOT hardcoded** - must be provided via variables/tfvars/user input/agent

**IMPORTANT - IP Address Configuration**:
- IP addresses are **NOT hardcoded** in this template
- IP addresses should be provided via:
  - Terraform variables (tfvars file)
  - User input
  - **In agentic situations, the agent should provide IP addresses via tfvars file**
- IP addresses extracted from existing VMs are for reference only

---

## vCenter Configuration

### Connection Details

| Parameter | Value | Notes |
|-----------|-------|-------|
| vCenter Server | 10.55.250.97 | vCenter IP address |
| Authentication | administrator@cortexlabs.local (see .secrets) | Read from .secrets file |
| Folder Path | Configurable (default: rangecomp) | Folder syntax: range<name> |
| Extraction Date | 2026-01-11 | Initial extraction |

### Infrastructure Components

| Component | Value | Notes |
|-----------|-------|-------|
| Datacenter | _TBD from extraction_ | vCenter datacenter name |
| Datastore | **liacmain01** | **Required storage for all template VMs** |
| Compute Cluster/Host | _TBD from extraction_ | Cluster or host name |
| Resource Pool | _TBD from extraction_ | Optional resource pool |
| Folder | Configurable (default: rangecomp) | VM folder path |

---

## VM Affinity Rule

### Requirement

All VMs in the template folder **must stay on the same host** to ensure:
- Network performance optimization
- Shared storage optimization (liacmain01)
- Management consistency
- Reduced network latency between VMs

### Affinity Rule Configuration

| Property | Value | Description |
|----------|-------|-------------|
| Rule Name | `{folder-name}-vm-affinity` | DRS affinity rule name (configurable) |
| Type | VM-VM Affinity | Ensures VMs run together |
| Enabled | Configurable (default: true) | Rule is active |
| Mandatory | Configurable (default: false) | Non-strict enforcement (can be set to true for strict) |
| Scope | All VMs in template folder | All VMs must be included |

### Implementation

**PowerCLI (Extraction)**:
```powershell
Get-DrsRule -Cluster <cluster> -Type VMAffinity | Where-Object { $_.Name -like "*{folder-name}*" }
```

**Terraform**:
```hcl
resource "vsphere_compute_cluster_vm_affinity_rule" "rangecomp_affinity" {
  name                = "${var.vsphere_folder}-vm-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [for vm in vsphere_virtual_machine.rangecomp_vms : vm.id]
  enabled             = var.affinity_rule_enabled
  mandatory           = var.affinity_rule_mandatory
}
```

---

## Network Configuration

### IP Address Assignment

**IMPORTANT**: IP addresses are **NOT hardcoded**. They must be provided via:
- Terraform variables (tfvars file)
- User input
- **In agentic situations, the agent should provide IP addresses via tfvars file**

The template uses configurable network subnets with the following structure (examples only - actual values from variables):

| Network | Subnet Example | Gateway Example | Purpose | VLAN Example | Notes |
|---------|---------------|-----------------|---------|--------------|-------|
| Users | 172.x.2.0/24 | 172.x.2.1 | User Workstations | Configurable | Primary user network |
| Services | 172.x.3.0/24 | 172.x.3.1 | Services/DaaS | Configurable | Service network |
| Infrastructure | 172.x.4.0/24 | 172.x.4.1 | Critical Infrastructure | Configurable | Infrastructure network |

**Note**: The subnet examples above (172.x.2.0/24, etc.) are for illustration only. Actual IP addresses must be provided via Terraform variables (tfvars file) or user input. In agentic situations, the agent should provide IP addresses via tfvars file.

### Network Configuration Variables

IP addresses and network configuration are provided via Terraform variables:

- `users_network_subnet` - Users network subnet (e.g., "172.24.2.0/24") - provided via tfvars/user/agent
- `services_network_subnet` - Services network subnet (e.g., "172.24.3.0/24") - provided via tfvars/user/agent
- `infrastructure_network_subnet` - Infrastructure network subnet (e.g., "172.24.4.0/24") - provided via tfvars/user/agent
- `users_network_gateway` - Users network gateway IP (e.g., "172.24.2.1") - provided via tfvars/user/agent
- `services_network_gateway` - Services network gateway IP (e.g., "172.24.3.1") - provided via tfvars/user/agent
- `infrastructure_network_gateway` - Infrastructure network gateway IP (e.g., "172.24.4.1") - provided via tfvars/user/agent
- `vm_ip_addresses` - Map of VM names to IP addresses - provided via tfvars/user/agent

### VLAN Configuration

VLANs are configurable via variables. Following the pattern from ARCHITECTURE.md (Range XDR: 1001-1006, Range XSIAM: 2001-2006, Range L&E: 2201-2206, Range Agentix: 2301-2306), each range typically uses:

| VLAN Pattern | Network Pattern | Gateway Pattern | Purpose | Notes |
|--------------|-----------------|-----------------|---------|-------|
| x01 | 172.x.1.0/24 | 172.x.1.1 | Public/External | Available |
| x02 | 172.x.2.0/24 | 172.x.2.1 | User Workstations | Active |
| x03 | 172.x.3.0/24 | 172.x.3.1 | Services/DaaS | Active |
| x04 | 172.x.4.0/24 | 172.x.4.1 | Critical Infrastructure | Active |
| x05 | 172.x.5.0/24 | 172.x.5.1 | IoT Devices | Available |
| x06 | 172.x.6.0/24 | 172.x.6.1 | Transit/Routing | Available |

**Note**: Actual VLAN IDs and network ranges must be provided via Terraform variables (tfvars file) or user input. The pattern above is for reference only.

### Virtual Switches and Port Groups

Each range uses unique vSwitches/VLANs per-range pattern (configurable via variables):

- **vSwitch**: Per-range vSwitch (e.g., `{folder-name}-vSwitch`)
- **Port Groups**: 
  - `{folder-name}-users` (VLAN configurable)
  - `{folder-name}-services` (VLAN configurable)
  - `{folder-name}-infrastructure` (VLAN configurable)

### Network Extraction

The enhanced extraction script (`rangecomp_extract.ps1`) extracts:
- Virtual Switch names
- Port Group names
- VLAN IDs
- Network adapter configurations
- Guest IP addresses (for reference only - NOT used in Terraform)

**Note**: IP addresses extracted from existing VMs are for reference only. Actual IP addresses must be provided via Terraform variables (tfvars file) or user input.

---

## Storage Configuration

### Datastore Requirement

**All template VMs must use the liacmain01 datastore**.

| Property | Value | Notes |
|----------|-------|-------|
| Datastore Name | liacmain01 | Required storage |
| Verification | Per-VM datastore check | Extraction script verifies storage |
| Failure Action | Warning if not on liacmain01 | Script logs warning |

### Storage Verification

The extraction script verifies that each VM's primary datastore is liacmain01:

```powershell
$primaryDatastore = ($datastores | Where-Object { $_.Name -like "*liacmain01*" })
if (-not $primaryDatastore) {
    Write-Warning "VM $($VM.Name) is not using liacmain01 datastore"
}
```

---

## VM Configuration Template

The following table represents the template structure for VMs in the template folder. Actual values will be populated from extraction.

### VM Properties Template

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| Name | string | VM name | vm-01 |
| PowerState | string | Current power state | PoweredOn/PoweredOff |
| NumCpu | integer | Number of vCPUs | 2 |
| MemoryGB | float | Memory in GB | 4.0 |
| MemoryMB | integer | Memory in MB | 4096 |
| Guest OS | string | Guest OS type | windows9Server64Guest |
| HardwareVersion | string | VM hardware version | vmx-XX |
| Folder | string | Folder path | rangecomp (configurable) |
| ResourcePool | string | Resource pool name | _optional_ |
| Host | string | ESXi host name | _TBD_ |
| Cluster | string | Compute cluster name | _TBD_ |
| Tags | array | VM tags | ["tag1", "tag2"] |
| Notes | string | VM notes/description | _optional_ |

### Guest OS Configuration

| Property | Type | Description |
|----------|------|-------------|
| OSFullName | string | Full OS name |
| ToolsVersion | string | VMware Tools version |
| ToolsStatus | string | Tools status (toolsOk, toolsOld, etc.) |
| State | string | Guest state (running, notRunning, etc.) |
| HostName | string | Guest hostname |
| IpAddress | string | Primary IP address (for reference only - NOT used in Terraform) |

### Network Adapters Template

| Property | Type | Description | Notes |
|----------|------|-------------|-------|
| Name | string | Adapter name | e.g., Network adapter 1 |
| NetworkName | string | Network/port group name | e.g., rangecomp-users (configurable) |
| Type | string | Adapter type | vmxnet3, e1000, etc. |
| MacAddress | string | MAC address | |
| ConnectionState | boolean | Connected status | |
| StartConnected | boolean | Start connected setting | |
| VirtualSwitch | string | vSwitch name | Extracted from port group |
| VLANId | integer | VLAN ID | Configurable via variables |

### Hard Disks Template

| Property | Type | Description |
|----------|------|-------------|
| Name | string | Disk name |
| CapacityGB | float | Disk size in GB |
| StorageFormat | string | Format (Thin, Thick, EagerZeroedThick) |
| DiskType | string | Disk type |
| Persistence | string | Persistence setting |
| Filename | string | VMDK filename |
| Datastore | string | Datastore name (must be liacmain01) |

### Snapshots

| Property | Type | Description |
|----------|------|-------------|
| Name | string | Snapshot name |
| Description | string | Snapshot description |
| Created | datetime | Creation timestamp |
| SizeGB | float | Snapshot size in GB |
| IsCurrent | boolean | Current snapshot flag |

---

## Terraform Integration

### Provider Configuration

```hcl
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}
```

### Data Sources

- `vsphere_datacenter` - Datacenter reference
- `vsphere_datastore` - liacmain01 datastore reference
- `vsphere_compute_cluster` - Compute cluster/host reference
- `vsphere_network` - Network/port group references (users, services, infrastructure)
- `vsphere_folder` - Template folder reference (configurable)

### Key Resources

1. **vsphere_virtual_machine** - Individual VM resources (generated from extraction)
2. **vsphere_compute_cluster_vm_affinity_rule** - VM affinity rule (ensures all VMs on same host)
3. **vsphere_folder** - Folder resource (if not using data source)

### Affinity Rule Resource

```hcl
resource "vsphere_compute_cluster_vm_affinity_rule" "rangecomp_affinity" {
  name                = "${var.vsphere_folder}-vm-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [for vm in vsphere_virtual_machine.rangecomp_vms : vm.id]
  enabled             = var.affinity_rule_enabled
  mandatory           = var.affinity_rule_mandatory
}
```

### VM Resource Template

Each VM will be defined as a `vsphere_virtual_machine` resource with:
- CPU and memory configuration
- Disk definitions (multiple disks supported, on liacmain01 datastore)
- Network interface definitions (users/services/infrastructure networks)
- Guest OS customization (if cloning)
- **IP addresses from variables/tfvars** (NOT hardcoded)
- Tags and annotations
- Folder placement (configurable)

### IP Address Configuration in Terraform

**IMPORTANT**: IP addresses are provided via Terraform variables:

```hcl
# Example VM customization with IP from variable
clone {
  template_uuid = data.vsphere_virtual_machine.template.id

  customize {
    windows_options {
      computer_name  = "example-vm"
      workgroup      = "WORKGROUP"
    }

    network_interface {
      # IP address from variable/tfvars (NOT hardcoded)
      # In agentic situations, the agent should provide IP via tfvars
      ipv4_address = var.vm_ip_addresses["vm-01"].users_network_ip  # From tfvars file
      ipv4_netmask = 24
    }

    ipv4_gateway    = var.users_network_gateway  # From tfvars file
    dns_server_list = var.dns_servers  # From tfvars file
  }
}
```

---

## IPAM Integration

### Network Topology

**IMPORTANT**: Network topology is configurable via variables. IP addresses are **NOT hardcoded**.

| Network | Subnet Variable | Gateway Variable | Purpose | Notes |
|---------|----------------|------------------|---------|-------|
| Users | `users_network_subnet` | `users_network_gateway` | User Workstations | Provided via tfvars/user/agent |
| Services | `services_network_subnet` | `services_network_gateway` | Services/DaaS | Provided via tfvars/user/agent |
| Infrastructure | `infrastructure_network_subnet` | `infrastructure_network_gateway` | Critical Infrastructure | Provided via tfvars/user/agent |

**Reference**: See `baker-street-docs/ARCHITECTURE.md` for IPAM standards and network patterns.

### IP Address Allocation

**IMPORTANT**: IP addresses are provided via Terraform variables (tfvars file) or user input. In agentic situations, the agent should provide IP addresses via tfvars file.

| VM Name | IP Address Variable | Network | Purpose | Status |
|---------|---------------------|---------|---------|--------|
| _TBD_ | `vm_ip_addresses["vm-name"]` | Configurable | _TBD_ | _TBD_ |

_Note: IP addresses are provided via `vm_ip_addresses` map variable (tfvars file). Cross-reference with organization ARCHITECTURE.md for IPAM standards._

---

## Deployment Flow

1. **Extraction**: Run enhanced `rangecomp_extract.ps1` to extract:
   - VM configurations
   - Affinity rules
   - Network configuration (vSwitches, port groups, VLANs)
   - Storage verification (liacmain01)
   - Host consistency check
   - **IP addresses (for reference only - NOT used in Terraform)**

2. **IP Address Configuration**: Provide IP addresses via:
   - Terraform variables (tfvars file)
   - User input
   - **In agentic situations, the agent should provide IP addresses via tfvars file**

3. **Generation**: Generate Terraform configuration from JSON extraction output

4. **Validation**: Review Terraform plan:
   - Verify affinity rule includes all VMs
   - Verify storage is liacmain01
   - Verify network configurations match requirements
   - Verify IP addresses are provided via variables/tfvars

5. **Deployment**: Apply Terraform configuration:
   ```bash
   terraform init
   terraform plan -var-file="terraform.tfvars"
   terraform apply -var-file="terraform.tfvars"
   ```

6. **Verification**: Verify VM creation and configuration:
   - All VMs on same host (affinity rule)
   - All VMs on liacmain01 datastore
   - Network adapters configured correctly
   - IP addresses assigned per tfvars file

---

## Dependencies

- vCenter access (10.55.250.97)
- VMware PowerCLI for extraction
- Terraform >= 1.0
- vsphere provider (hashicorp/vsphere ~> 2.0)
- Credentials in .secrets file (VCENTER_USERNAME, VCENTER_PASSWORD)
- **IP addresses provided via tfvars file or user input**

---

## Related Documentation

- `rangecomp_design.md` - Mermaid diagrams for VM affinity, network topology, and deployment flow
- `rangecomp.tf` - Terraform configuration with affinity rules
- `variables.tf` - Terraform variable definitions
- `../../../../ARCHITECTURE.md` - Organization architecture reference (IPAM, network topology)
- `baker-street-docs/ARCHITECTURE.md` - Master IPAM inventory (IP assignments, VLANs)

---

## Notes

- **Storage Requirement**: All VMs must use liacmain01 datastore
- **Affinity Rule**: All VMs must stay on the same host (enforced via DRS rule)
- **Folder Syntax**: Configurable (default: rangecomp) - following range<name> pattern
- **Network Assignment**: Configurable via variables - IP addresses from user/tfvars/agent
- **VLAN Assignment**: Configurable via variables - per-range vSwitches/VLANs pattern
- **IP Address Source**: **NOT hardcoded** - must be provided via variables/tfvars/user input
- **Agentic Deployment**: In agentic situations, the agent should provide IP addresses via tfvars file
- **IPAM Reference**: Cross-reference with `baker-street-docs/ARCHITECTURE.md` for IPAM standards
- **Credentials**: Must be managed securely (use .secrets file, not hardcoded)
- **State Files**: Should be excluded from git (.gitignore)

---

**Last Updated**: 2026-01-11  
**Status**: Template-Based with Affinity Rules & Network Configuration  
**IP Address Configuration**: Variables/tfvars/user input/agent (NOT hardcoded)
