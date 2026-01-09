# =============================================================================
# Packer Variables for Windows 11 Pro Golden Image
# =============================================================================
# This file contains the variable values for the Windows 11 Packer build.
# Customize these values according to your environment.
# =============================================================================

# ISO Configuration
iso_path      = "C:/Projects/ISO/windows_11_pro.iso"
iso_checksum  = "auto"  # Set to "auto" for automatic checksum calculation

# VM Configuration
vm_name   = "packer-windows-11-pro"
switch_name = "192.168.0.0/16-Bridge"  # Bridge directly to 192.168.0.0/16 subnet

# Hardware Configuration
memory    = 4096  # MB
cpus      = 2
disk_size = 80    # GB (Windows 11 requires more space than Windows Server)

# Output Configuration
output_directory = "output-windows11"

# WinRM Configuration
winrm_username = "Administrator"
winrm_password = "PackerPassword123!"  # Change this for production use
