# EXTRACTED FROM PRODUCTION BAKER STREET LABS vCenter – 2026-01-11
# Range Template Terraform Configuration (Enhanced with Affinity Rules)
# Template-based Terraform configuration for vCenter VM deployment
# Provider: vsphere (VMware vCenter)
# 
# Key Requirements:
# - All VMs on same node (affinity rule)
# - Storage: liacmain01 datastore
# - Folder: rangecomp (configurable via variable)
# - Network: Configurable via variables (IP addresses from user/tfvars/agent)
# - VLANs: Configurable via variables
#
# NOTE: IP addresses should be provided via:
#   - Terraform variables (tfvars file)
#   - User input
#   - In agentic situations, the agent should provide IP addresses via tfvars file
#
# IP addresses are NOT hardcoded. They must be provided via variables/tfvars.

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.0"
    }
  }
}

# vSphere Provider Configuration
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true  # For lab environments
  
  # Timeouts
  timeout = 30
}

# Data sources for existing vSphere infrastructure
data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "liacmain01" {
  name          = "liacmain01"  # Required storage for all template VMs
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Network data sources for template networks
# NOTE: Network names should be provided via variables
# IP addresses should be provided via variables/tfvars/user input/agent
data "vsphere_network" "users" {
  count         = var.create_users_network ? 0 : 1
  name          = var.users_network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "services" {
  count         = var.create_services_network ? 0 : 1
  name          = var.services_network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "infrastructure" {
  count         = var.create_infrastructure_network ? 0 : 1
  name          = var.infrastructure_network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Folder for template VMs (configurable)
data "vsphere_folder" "rangecomp" {
  path          = var.vsphere_folder  # Folder syntax: range<name> (e.g., rangecomp, rangexdr)
  datacenter_id = data.vsphere_datacenter.dc.id
}

# NOTE: VM resources should be generated from extracted VM data
# Each VM in the folder will have its own resource block
# Example structure below (to be populated from extraction script output)
#
# IP addresses must be provided via variables/tfvars file:
#   - In manual deployment: User provides IPs via tfvars
#   - In agentic deployment: Agent provides IPs via tfvars file

# Local values for VM configuration (to be populated from extraction)
locals {
  # Example VM list (replace with actual extracted VM data)
  vms = var.vm_list  # List of VM configurations from extraction
  
  # VM IDs for affinity rule
  # NOTE: Populated from rangecomp_vms.tf (generated from rangeplatform extraction)
  # These will be automatically populated when VM resources are created
  vm_ids = [
    # VM IDs are defined in rangecomp_vms.tf
    # This list will be populated when that file is processed
  ]
}

# VM Affinity Rule - Ensures all template VMs stay on the same host
resource "vsphere_compute_cluster_vm_affinity_rule" "rangecomp_affinity" {
  name                = "${var.vsphere_folder}-vm-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = local.vm_ids
  enabled             = var.affinity_rule_enabled
  mandatory           = var.affinity_rule_mandatory
  
  # Description
  # This rule ensures all VMs in the template folder stay on the same host
  # Required for: Network performance, shared storage optimization, management consistency
}

# Example VM Resource Template
# This should be duplicated for each VM extracted from the folder
# Each VM should be configured with:
# - Storage on liacmain01 datastore
# - Folder: rangecomp (configurable)
# - Network adapters for Users/Services/Infrastructure networks
# - IP addresses from variables/tfvars (NOT hardcoded)
#
# NOTE: IP addresses are provided via variables:
#   - users_network_ip (from tfvars)
#   - services_network_ip (from tfvars)
#   - infrastructure_network_ip (from tfvars)
# In agentic situations, the agent should provide these via tfvars file.

# resource "vsphere_virtual_machine" "example_vm" {
#   name             = "example-vm"
#   resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
#   datastore_id     = data.vsphere_datastore.liacmain01.id
#   folder           = data.vsphere_folder.rangecomp.path
# 
#   num_cpus               = 2
#   memory                 = 4096
#   guest_id               = "windows9Server64Guest"  # or other guest OS
#   scsi_type              = "pvscsi"
#   scsi_bus_sharing       = "noSharing"
#   scsi_controller_count  = 1
# 
#   # Network adapters
#   # Users network (IP from variable/tfvars)
#   network_interface {
#     network_id   = data.vsphere_network.users[0].id
#     adapter_type = "vmxnet3"
#   }
# 
#   # Services network (IP from variable/tfvars) - optional
#   # network_interface {
#   #   network_id   = data.vsphere_network.services[0].id
#   #   adapter_type = "vmxnet3"
#   # }
# 
#   # Infrastructure network (IP from variable/tfvars) - optional
#   # network_interface {
#   #   network_id   = data.vsphere_network.infrastructure[0].id
#   #   adapter_type = "vmxnet3"
#   # }
# 
#   # Hard disks
#   disk {
#     label            = "disk0"
#     size             = 40
#     eagerly_scrub    = false
#     thin_provisioned = true
#   }
# 
#   # Cloning from template (if applicable)
#   # clone {
#   #   template_uuid = data.vsphere_virtual_machine.template.id
#   #
#   #   customize {
#   #     windows_options {
#   #       computer_name  = "example-vm"
#   #       workgroup      = "WORKGROUP"
#   #       # admin_password = "..."  # Set via environment variable
#   #     }
#   #
#   #     network_interface {
#   #       # IP address from variable/tfvars (NOT hardcoded)
#   #       # In agentic situations, the agent should provide IP via tfvars
#   #       ipv4_address = var.users_network_ip  # From tfvars file
#   #       ipv4_netmask = 24
#   #     }
#   #
#   #     ipv4_gateway    = var.users_network_gateway  # From tfvars file
#   #     dns_server_list = var.dns_servers  # From tfvars file
#   #   }
#   # }
# }

# Outputs
output "affinity_rule_id" {
  description = "ID of the VM affinity rule"
  value       = vsphere_compute_cluster_vm_affinity_rule.rangecomp_affinity.id
}

output "vm_ids" {
  description = "List of VM IDs included in affinity rule"
  value       = local.vm_ids
}

output "datastore_info" {
  description = "Information about the liacmain01 datastore"
  value = {
    name     = data.vsphere_datastore.liacmain01.name
    id       = data.vsphere_datastore.liacmain01.id
    capacity = data.vsphere_datastore.liacmain01.capacity
  }
}
