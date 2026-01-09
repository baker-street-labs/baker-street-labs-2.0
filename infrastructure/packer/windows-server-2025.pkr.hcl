# MIGRATED FROM MONO-REPO – 2026-01-08 – Verified working
# TAG: KEEP_AS_IS
# Battle-tested, working in production
# Original path: E:\projects\baker-street-labs\packer\windows-server-2025.pkr.hcl
#
# Baker Street Labs - Windows Server 2025 Packer Configuration
# Based on KVM Windows Server Automation Blueprint
# Creates immutable golden image with WinRM, SSH, and AD promotion capability

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
  type    = string
  default = "/opt/baker-street-labs/baseline-images/windows-server-2025.iso"
}

variable "virtio_iso_path" {
  type    = string
  default = "/opt/baker-street-labs/baseline-images/virtio-win.iso"
}

variable "vm_admin_user" {
  type      = string
  default   = "Administrator"
  sensitive = true
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

variable "safe_mode_admin_pass" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "output_image_name" {
  type    = string
  default = "windows-server-2025-dc.qcow2"
}

# QEMU Builder Configuration
source "qemu" "windows-server-2025" {
  # ISO Configuration
  iso_url              = "file://${var.win_iso_path}"
  iso_checksum         = "none" # Set to actual checksum in production
  
  # Output Configuration
  output_directory     = "output-qemu"
  vm_name              = var.output_image_name
  headless             = true

  # Hardware Configuration
  accelerator          = "kvm"
  machine_type         = "q35"
  cpu_model            = "host"
  memory               = 4096
  cpus                 = 2
    
  # Disk Configuration
  disk_interface       = "virtio-scsi"
  disk_size            = "60G"
  disk_image           = true
  format               = "qcow2"

  # Network Configuration
  net_device           = "virtio-net"
    
  # Boot Configuration
  boot_wait            = "2s"
  boot_command         = ["<enter><wait10><enter>"]
  
  # Floppy for autounattend.xml and scripts
  floppy_files         = [
    "answer_files/autounattend.xml",
    "scripts/Enable-WinRM.ps1",
    "scripts/Install-Features.ps1", 
    "scripts/Install-Updates.ps1",
    "scripts/Configure-SSH.ps1",
    "scripts/Promote-DC.ps1",
    "scripts/Invoke-Sysprep.ps1"
  ]
  
  # CD-ROM for VirtIO Drivers
  cd_files             = [var.virtio_iso_path]
  cd_label             = "VIRTIO"

  # WinRM Communicator
  communicator         = "winrm"
  winrm_username       = var.vm_admin_user
  winrm_password       = var.vm_admin_password
  winrm_use_ssl        = true
  winrm_insecure       = true
  winrm_timeout        = "12h"
}

# Build Configuration
build {
  sources = ["source.qemu.windows-server-2025"]

  # Enable WinRM for Packer communication
  provisioner "powershell" {
    inline = ["winrm quickconfig -q"]
  }

  # Configure WinRM for Ansible
  provisioner "powershell" {
    script = "./scripts/Enable-WinRM.ps1"
  }

  # Install Windows Features (SSH, etc.)
  provisioner "powershell" {
    script = "./scripts/Install-Features.ps1"
  }

  # Configure SSH with public key
  provisioner "powershell" {
    script = "./scripts/Configure-SSH.ps1"
    environment_vars = [
      "SSH_PUBLIC_KEY=${var.ssh_public_key}"
    ]
  }

  # Install Windows Updates
  provisioner "powershell" {
    script = "./scripts/Install-Updates.ps1"
  }

  # Generalize image for deployment
  provisioner "powershell" {
    script = "./scripts/Invoke-Sysprep.ps1"
  }
}
