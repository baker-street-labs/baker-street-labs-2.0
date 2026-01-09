# Windows Server 2025 Standard Base Image for KVM

This directory contains Packer configuration and scripts to build a Windows Server 2025 Standard base image optimized for KVM virtualization.

## 📋 Prerequisites

### **Required Software**
- **Packer** (>= 1.8.0) - [Download](https://www.packer.io/downloads)
- **QEMU/KVM** - For virtualization
- **Windows Server 2025 ISO** - Available in `../image_assets/`
- **VirtIO Drivers ISO** - Download from [Fedora Project](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)

### **System Requirements**
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 50GB free space
- **CPU**: 4+ cores recommended
- **OS**: Linux with KVM support or Windows with QEMU

## 🏗️ Architecture

### **Base Image Features**
- **OS**: Windows Server 2025 Standard (Server Core)
- **Virtualization**: KVM with VirtIO drivers
- **Optimization**: Minimal footprint, security hardened
- **Communication**: WinRM enabled for automation
- **Updates**: Latest Windows updates applied

### **Included Components**
- VirtIO network, storage, and balloon drivers
- WinRM configuration for remote management
- Windows Defender optimized settings
- Unnecessary services disabled
- Power management optimized for servers

## 🚀 Quick Start

### **1. Download VirtIO Drivers**
```bash
# Download VirtIO drivers ISO
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
mv virtio-win.iso ../image_assets/
```

### **2. Build the Image**
```powershell
# Windows PowerShell
.\build.ps1

# Or with custom parameters
.\build.ps1 -IsoPath "C:\path\to\windows.iso" -VirtioIsoPath "C:\path\to\virtio.iso" -Headless
```

### **3. Build with Packer Directly**
```bash
# Set environment variables
export PKR_VAR_win_iso_path="../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso"
export PKR_VAR_virtio_win_iso_path="../image_assets/virtio-win.iso"
export PKR_VAR_product_key="3NPK2-7TDCT-7KP99-3VHFX-V26D3"
export PKR_VAR_admin_password="BakerStreet2025!"

# Build the image
packer build windows-server-2025-standard.pkr.hcl
```

## 📁 File Structure

```
packer/windows-server-2025/
├── README.md                           # This file
├── windows-server-2025-standard.pkr.hcl # Main Packer configuration
├── build.ps1                          # Build automation script
└── scripts/
    ├── Autounattend.xml               # Windows unattended installation
    ├── virtio-drivers.ps1            # VirtIO drivers installation
    ├── winrm.ps1                     # WinRM configuration
    └── optimize.ps1                  # System optimization
```

## ⚙️ Configuration

### **Packer Variables**
| Variable | Description | Default |
|----------|-------------|---------|
| `win_iso_path` | Path to Windows Server 2025 ISO | `../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso` |
| `virtio_win_iso_path` | Path to VirtIO drivers ISO | `../image_assets/virtio-win.iso` |
| `product_key` | Windows Server 2025 Standard key | `3NPK2-7TDCT-7KP99-3VHFX-V26D3` |
| `admin_password` | Administrator password | `BakerStreet2025!` |
| `vm_name` | Virtual machine name | `windows-server-2025-standard-base` |
| `disk_size` | Disk size in GB | `40` |
| `memory` | Memory in MB | `4096` |
| `cpus` | Number of CPUs | `2` |

### **Build Options**
- **Headless**: Run without GUI (`-Headless`)
- **Clean**: Remove previous builds (`-Clean`)
- **Custom ISO**: Specify different ISO path
- **Custom VirtIO**: Specify different VirtIO drivers path

## 🔧 Customization

### **Adding Software**
Edit `scripts/optimize.ps1` to add additional software or configurations:

```powershell
# Example: Install additional software
Write-Host "Installing additional software..." -ForegroundColor Cyan
# Add your installation commands here
```

### **Security Hardening**
The base image includes:
- Windows Defender optimized settings
- Unnecessary services disabled
- Windows Update configured
- Error reporting disabled
- Cortana disabled

### **Network Configuration**
- VirtIO network drivers installed
- WinRM configured for remote management
- Firewall rules configured
- Network adapters optimized

## 📊 Output

### **Generated Files**
- **`windows-server-2025-standard.qcow2`** - Main disk image
- **`windows-server-2025-standard.ovf`** - OVF descriptor (if applicable)
- **`windows-server-2025-standard.mf`** - Manifest file

### **Image Specifications**
- **Format**: QCOW2 (KVM native)
- **Size**: ~8-12GB (compressed)
- **Architecture**: x86_64
- **Boot**: UEFI compatible
- **Drivers**: VirtIO optimized

## 🚀 Deployment

### **Using with Terraform**
```hcl
resource "libvirt_volume" "windows_server" {
  name   = "windows-server-2025"
  source = "path/to/windows-server-2025-standard.qcow2"
  pool   = "default"
}
```

### **Using with KVM**
```bash
# Create VM from base image
virt-install \
  --name windows-server-2025 \
  --memory 4096 \
  --vcpus 2 \
  --disk path=windows-server-2025-standard.qcow2 \
  --network network=default \
  --graphics vnc \
  --import
```

## 🔍 Troubleshooting

### **Common Issues**

1. **VirtIO drivers not installing**
   - Ensure VirtIO ISO is properly mounted
   - Check driver paths in `virtio-drivers.ps1`

2. **WinRM connection failed**
   - Verify WinRM configuration in `winrm.ps1`
   - Check firewall rules
   - Ensure port 5986 is accessible

3. **Build timeout**
   - Increase `winrm_timeout` in Packer config
   - Check system resources (RAM/CPU)
   - Verify ISO file integrity

4. **QEMU not found**
   - Install QEMU/KVM on your system
   - Add QEMU to PATH
   - Verify KVM support: `kvm-ok`

### **Debug Mode**
```bash
# Enable Packer debug logging
export PACKER_LOG=1
export PACKER_LOG_PATH=packer.log
packer build windows-server-2025-standard.pkr.hcl
```

## 📚 References

- [Packer Documentation](https://www.packer.io/docs)
- [QEMU Documentation](https://qemu.readthedocs.io/)
- [VirtIO Drivers](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)
- [Windows Server 2025](https://docs.microsoft.com/en-us/windows-server/)

## 🔐 Security Notes

- Product keys are stored in variables (not in code)
- Administrator password is configurable
- Base image is security hardened
- WinRM is configured for automation
- Windows Defender is optimized

## 📝 License

This configuration is part of the Baker Street Labs infrastructure project.
