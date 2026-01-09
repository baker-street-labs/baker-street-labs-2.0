# =============================================================================
# Packer Variables for Windows Server 2025 Active Directory Domain Controller
# =============================================================================
# This file contains the variable values for the AD DC Packer build.
# Customize these values according to your environment.
# =============================================================================

# ISO Configuration
iso_path      = "C:/Projects/ISO/windows_server_2025.iso"
iso_checksum  = "auto"  # Set to "auto" for automatic checksum calculation

# VM Configuration
vm_name   = "packer-windows-server-2025-ad-dc"
switch_name = "ExternalSwitch"  # Must exist on the Hyper-V host

# Hardware Configuration
memory    = 4096  # MB
cpus      = 2
disk_size = 80    # GB (AD DCs need more space for logs and databases)

# Output Configuration
output_directory = "output-ad-dc"

# WinRM Configuration
winrm_username = "Administrator"
winrm_password = "PackerPassword123!"  # Change this for production use

# Active Directory Configuration
domain_name = "ad.bakerstreetlabs.io"
domain_netbios = "BAKERSTREETLABS"
safe_mode_password = "DSRMPassword123!"  # Change this for production use
