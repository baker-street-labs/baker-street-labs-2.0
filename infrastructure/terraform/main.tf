# MIGRATED FROM MONO-REPO – 2026-01-08 – Verified working
# TAG: KEEP_AS_IS
# Battle-tested, working in production
# Original path: E:\projects\baker-street-labs\terraform\main.tf
#
# Baker Street Labs - Terraform Infrastructure Configuration
# Provisions KVM virtual machines using the Packer-built golden image

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Variables
variable "domain_name" {
  type    = string
  default = "ad.bakerstreetlabs.io"
}

variable "dc_vm_name" {
  type    = string
  default = "ad01"
}

variable "dc_vm_ip" {
  type    = string
  default = "192.168.0.65"
}

variable "dc_vm_memory" {
  type    = number
  default = 4096
}

variable "dc_vm_vcpu" {
  type    = number
  default = 2
}

# Base image volume (from Packer output)
resource "libvirt_volume" "base_image" {
  name   = "windows-server-2025-base.qcow2"
  pool   = "default"
  source = "../packer/output-qemu/windows-server-2025-dc.qcow2"
  format = "qcow2"
}

# Domain Controller VM disk (clone of base image)
resource "libvirt_volume" "dc_disk" {
  name           = "${var.dc_vm_name}.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base_image.id
  format         = "qcow2"
}

# Domain Controller VM definition
resource "libvirt_domain" "ad01" {
  name   = var.dc_vm_name
  memory = var.dc_vm_memory
  vcpu   = var.dc_vm_vcpu

  disk {
    volume_id = libvirt_volume.dc_disk.id
  }

  network_interface {
    network_name = "default"
    mac          = "52:54:00:11:22:33" # Unique MAC address
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  # Wait for the VM to boot and AD to be configured
  provisioner "local-exec" {
    command = "echo 'Waiting for AD01 to complete domain controller promotion...' && sleep 300"
  }
}

# Output the VM information
output "dc_ip_address" {
  value = var.dc_vm_ip
}

output "dc_vm_name" {
  value = var.dc_vm_name
}

output "domain_name" {
  value = var.domain_name
}

output "access_info" {
  value = {
    vnc_console = "Connect to VNC to monitor installation progress"
    rdp_access  = "RDP will be available on ${var.dc_vm_ip}:3389 after configuration"
    winrm_access = "WinRM available on ${var.dc_vm_ip}:5985/5986"
    ssh_access   = "SSH available on ${var.dc_vm_ip}:22"
    domain       = var.domain_name
  }
}


