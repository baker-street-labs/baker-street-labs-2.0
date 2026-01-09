# =============================================================================
# Packer Variables for Windows Server 2025 Core Golden Image
# =============================================================================
# This file contains the variable values for the Packer build.
# Customize these values according to your environment.
# =============================================================================

# ISO Configuration
iso_path      = "C:/Projects/ISO/windows_server_2025.iso"
iso_checksum  = "auto"  # Set to "auto" for automatic checksum calculation

# VM Configuration
vm_name   = "packer-windows-server-2025-core"
switch_name = "ExternalSwitch"  # Must exist on the Hyper-V host

# Hardware Configuration
memory    = 4096  # MB
cpus      = 2
disk_size = 60    # GB

# Output Configuration
output_directory = "output-vmss"

# WinRM Configuration
winrm_username = "Administrator"
winrm_password = "PackerPassword123!"  # Change this for production use
