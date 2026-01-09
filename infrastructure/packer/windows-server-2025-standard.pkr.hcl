# Windows Server 2025 Standard Base Image for KVM
# Baker Street Labs Infrastructure
# 
# This Packer configuration creates a Windows Server 2025 Standard base image
# optimized for KVM virtualization with VirtIO drivers and minimal footprint.

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# Variables
variable "win_iso_path" {
  type        = string
  description = "Path to Windows Server 2025 ISO"
  default     = "../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso"
}

variable "virtio_win_iso_path" {
  type        = string
  description = "Path to VirtIO Windows drivers ISO"
  default     = "../image_assets/virtio-win.iso"
}

variable "product_key" {
  type        = string
  description = "Windows Server 2025 Standard product key"
  default     = "3NPK2-7TDCT-7KP99-3VHFX-V26D3"
  sensitive   = true
}

variable "admin_password" {
  type        = string
  description = "Administrator password"
  default     = "BakerStreet2025!"
  sensitive   = true
}

variable "vm_name" {
  type        = string
  description = "Virtual machine name"
  default     = "windows-server-2025-standard-base"
}

variable "disk_size" {
  type        = string
  description = "Disk size in GB"
  default     = "40"
}

variable "memory" {
  type        = string
  description = "Memory in MB"
  default     = "4096"
}

variable "cpus" {
  type        = string
  description = "Number of CPUs"
  default     = "2"
}

# QEMU Builder Configuration
source "qemu" "windows-server-2025-standard" {
  # Basic Configuration
  vm_name           = var.vm_name
  iso_url           = var.win_iso_path
  iso_checksum      = "none"  # TODO: Add actual checksum
  output_directory  = "output/windows-server-2025-standard"
  
  # Communication Settings
  communicator      = "winrm"
  winrm_username    = "Administrator"
  winrm_password    = var.admin_password
  winrm_timeout     = "4h"
  winrm_use_ssl     = true
  winrm_insecure    = true
  
  # Boot Configuration
  boot_wait         = "2m"
  boot_command = [
    "<enter><wait><enter><wait><enter>"
  ]
  
  # Hardware Configuration
  disk_size         = "${var.disk_size}G"
  format            = "qcow2"
  accelerator       = "kvm"
  headless          = false  # Set to true for CI/CD
  
  # QEMU Arguments for KVM Optimization
  qemuargs = [
    ["-m", var.memory],
    ["-smp", "cores=${var.cpus},threads=1,sockets=1"],
    ["-device", "virtio-net-pci,netdev=user.0"],
    ["-netdev", "user,id=user.0,hostfwd=tcp::5986-:5986"],
    ["-device", "virtio-scsi-pci,id=scsi0"],
    ["-device", "scsi-hd,bus=scsi0.0,drive=drive0"],
    ["-drive", "if=none,file=${var.vm_name}.qcow2,id=drive0,cache=writeback,discard=unmap,detect-zeroes=unmap"],
    ["-device", "virtio-balloon-pci,id=balloon0"],
    ["-machine", "type=pc,accel=kvm"]
  ]
  
  # CD-ROM Files (Autounattend.xml and scripts)
  cd_files = [
    "./scripts/Autounattend.xml",
    "./scripts/virtio-drivers.ps1",
    "./scripts/winrm.ps1"
  ]
  cd_label = "packer"
  
  # Floppy Files (additional scripts)
  floppy_files = [
    "./scripts/optimize.ps1"
  ]
  
  # Shutdown Configuration
  shutdown_command = "shutdown /s /t 10 /c \"Packer Shutdown\""
  shutdown_timeout = "5m"
}

# Build Configuration
build {
  sources = ["source.qemu.windows-server-2025-standard"]
  
  # Provisioner 1: Install VirtIO Drivers
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing VirtIO drivers...'",
      "& C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\virtio-drivers.ps1"
    ]
  }
  
  # Provisioner 2: Restart for driver installation
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }
  
  # Provisioner 3: Windows Updates
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Beta*'"
    ]
    update_timeout = "2h"
  }
  
  # Provisioner 4: System Optimization
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running system optimization...'",
      "& C:\\Windows\\Temp\\optimize.ps1"
    ]
  }
  
  # Provisioner 5: Final Configuration
  provisioner "powershell" {
    inline = [
      "Write-Host 'Finalizing base image configuration...'",
      "Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Available' -and $_.Name -like '*Server-Gui*'} | Remove-WindowsFeature -Remove",
      "Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Available' -and $_.Name -like '*Server-Gui-Mgmt*'} | Remove-WindowsFeature -Remove",
      "Write-Host 'Base image configuration complete.'"
    ]
  }
  
  # Provisioner 6: Sysprep
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running Sysprep...'",
      "& C:\\Windows\\System32\\sysprep\\sysprep.exe /generalize /oobe /shutdown /unattend:C:\\Windows\\Temp\\Autounattend.xml"
    ]
  }
}
