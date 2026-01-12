# Range Template Terraform Variables
# Variables for range template VM Terraform configuration
#
# NOTE: IP addresses should be provided via:
#   - Terraform variables (tfvars file)
#   - User input
#   - In agentic situations, the agent should provide IP addresses via tfvars file
#
# IP addresses are NOT hardcoded. They must be provided via variables/tfvars.

variable "vsphere_server" {
  description = "vCenter server FQDN or IP address"
  type        = string
  default     = "10.55.250.97"
}

variable "vsphere_user" {
  description = "vCenter username (read from .secrets file)"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vCenter password (read from .secrets file)"
  type        = string
  sensitive   = true
}

variable "vsphere_datacenter" {
  description = "vCenter datacenter name"
  type        = string
  # Will be determined from VM extraction
}

variable "vsphere_compute_cluster" {
  description = "vCenter compute cluster name"
  type        = string
  # Will be determined from VM extraction
}

variable "vsphere_folder" {
  description = "vCenter folder path for template VMs (default: rangetemplate)"
  type        = string
  default     = "rangetemplate"
  # Folder syntax: range<name> (e.g., rangetemplate, rangexdr, rangeplatform)
}

# Network configuration variables
# NOTE: Network names and IP addresses should be provided via tfvars file
variable "users_network_name" {
  description = "Port group name for Users network"
  type        = string
  default     = "rangetemplate-users"
}

variable "services_network_name" {
  description = "Port group name for Services network"
  type        = string
  default     = "rangetemplate-services"
}

variable "infrastructure_network_name" {
  description = "Port group name for Infrastructure network"
  type        = string
  default     = "rangetemplate-infrastructure"
}

variable "create_users_network" {
  description = "Whether to create the Users network (set to false if network exists)"
  type        = bool
  default     = false
}

variable "create_services_network" {
  description = "Whether to create the Services network (set to false if network exists)"
  type        = bool
  default     = false
}

variable "create_infrastructure_network" {
  description = "Whether to create the Infrastructure network (set to false if network exists)"
  type        = bool
  default     = false
}

# IP Address Variables
# NOTE: IP addresses should be provided via tfvars file:
#   - In manual deployment: User provides IPs via tfvars
#   - In agentic deployment: Agent provides IPs via tfvars file
# IP addresses are NOT hardcoded. They must be provided via variables/tfvars.

variable "users_network_subnet" {
  description = "Users network subnet (e.g., 172.24.2.0/24) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.2.0/24"
  # Must be provided via tfvars file or user input
}

variable "services_network_subnet" {
  description = "Services network subnet (e.g., 172.24.3.0/24) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.3.0/24"
  # Must be provided via tfvars file or user input
}

variable "infrastructure_network_subnet" {
  description = "Infrastructure network subnet (e.g., 172.24.4.0/24) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.4.0/24"
  # Must be provided via tfvars file or user input
}

variable "users_network_gateway" {
  description = "Users network gateway IP (e.g., 172.24.2.1) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.2.1"
  # Must be provided via tfvars file or user input
}

variable "services_network_gateway" {
  description = "Services network gateway IP (e.g., 172.24.3.1) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.3.1"
  # Must be provided via tfvars file or user input
}

variable "infrastructure_network_gateway" {
  description = "Infrastructure network gateway IP (e.g., 172.24.4.1) - provided via tfvars/user/agent"
  type        = string
  # Example: "172.24.4.1"
  # Must be provided via tfvars file or user input
}

variable "dns_servers" {
  description = "DNS server IP addresses (list) - provided via tfvars/user/agent"
  type        = list(string)
  default     = ["192.168.0.11", "192.168.0.12"]
  # Can be overridden via tfvars file
}

# VM IP Address Mapping (for VM customization)
# NOTE: IP addresses should be provided via tfvars file:
#   - In manual deployment: User provides IPs via tfvars
#   - In agentic deployment: Agent provides IPs via tfvars file
# Format: map of VM names to IP addresses
variable "vm_ip_addresses" {
  description = "Map of VM names to IP addresses - provided via tfvars/user/agent"
  type = map(object({
    users_network_ip        = string
    services_network_ip     = string  # Optional
    infrastructure_network_ip = string  # Optional
  }))
  default = {}
  # Example:
  # vm_ip_addresses = {
  #   "vm-01" = {
  #     users_network_ip        = "172.24.2.100"
  #     services_network_ip     = "172.24.3.100"
  #     infrastructure_network_ip = "172.24.4.100"
  #   }
  # }
  # Must be provided via tfvars file or user input
}

# VM list (populated from extraction script output)
variable "vm_list" {
  description = "List of VM configurations from extraction script"
  type = list(object({
    name             = string
    num_cpus         = number
    memory_mb        = number
    guest_id         = string
    disks            = list(object({
      label = string
      size  = number
    }))
    network_adapters = list(object({
      network_name = string
      adapter_type = string
    }))
  }))
  default = []
}

# Affinity rule configuration
variable "affinity_rule_enabled" {
  description = "Enable VM affinity rule (ensures all VMs on same host)"
  type        = bool
  default     = true
}

variable "affinity_rule_mandatory" {
  description = "Make affinity rule mandatory (strict enforcement)"
  type        = bool
  default     = false
}
