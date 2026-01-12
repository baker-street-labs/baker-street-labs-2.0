# Range Comp Terraform Variables Example
# Copy this file to terraform.tfvars and fill in actual values
# NEVER commit terraform.tfvars to git (contains sensitive data)

# vSphere Connection
vsphere_server       = "10.55.250.97"
vsphere_user         = "administrator@cortexlabs.local"  # Read from .secrets file
vsphere_password     = ""  # Read from .secrets file - DO NOT HARDCODE
vsphere_datacenter   = "Datacenter"  # Update with actual datacenter name
vsphere_compute_cluster = "Cluster"  # Update with actual cluster name
vsphere_folder       = "rangecomp"

# Network Configuration
# NOTE: IP addresses are provided via tfvars file
# In agentic situations, the agent should provide IP addresses via tfvars file

users_network_subnet        = "172.24.2.0/24"
services_network_subnet     = "172.24.3.0/24"
infrastructure_network_subnet = "172.24.4.0/24"

users_network_gateway        = "172.24.2.1"
services_network_gateway     = "172.24.3.1"
infrastructure_network_gateway = "172.24.4.1"

dns_servers = ["192.168.0.11", "192.168.0.12"]

# Network Names
users_network_name        = "rangecomp-users"
services_network_name     = "rangecomp-services"
infrastructure_network_name = "rangecomp-infrastructure"

create_users_network        = false
create_services_network     = false
create_infrastructure_network = false

# VM IP Address Mapping
# Format: map of VM names to IP addresses
# In agentic situations, the agent should provide IP addresses via tfvars file
vm_ip_addresses = {
  "rangecomp-ws01" = {
    users_network_ip        = "172.24.2.10"
    services_network_ip     = "172.24.3.10"
    infrastructure_network_ip = "172.24.4.10"
  }
  "rangecomp-ws02" = {
    users_network_ip        = "172.24.2.11"
    services_network_ip     = "172.24.3.11"
    infrastructure_network_ip = "172.24.4.11"
  }
  # Add more VMs as needed
}

# VM List (populated from extraction script)
# This should be generated from rangeplatform_vms.json
vm_list = []

# Affinity Rule Configuration
affinity_rule_enabled  = true
affinity_rule_mandatory = false

# Windows Admin Password (read from .secrets file)
windows_admin_password = ""  # Read from .secrets file - DO NOT HARDCODE
