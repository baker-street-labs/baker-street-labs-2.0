# Windows Server 2025 Base Image Deployment Plan

## 🎯 **Objective**
Create a Windows Server 2025 Standard base image optimized for KVM virtualization using Packer, with VirtIO drivers and security hardening.

## 📋 **Prerequisites Checklist**

### **Required Assets**
- [x] **Windows Server 2025 ISO**: `en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso` (7.0GB)
- [x] **Product Key**: `3NPK2-7TDCT-7KP99-3VHFX-V26D3` (Windows Server 2025 Standard)
- [ ] **VirtIO Drivers ISO**: Download from [Fedora Project](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)
- [ ] **Packer**: Install from [packer.io](https://www.packer.io/downloads)
- [ ] **QEMU/KVM**: Install virtualization tools

### **System Requirements**
- **RAM**: 16GB+ recommended (8GB minimum)
- **Storage**: 50GB+ free space
- **CPU**: 4+ cores recommended
- **OS**: Linux with KVM or Windows with QEMU

## 🏗️ **Build Process**

### **Phase 1: Preparation**
1. **Download VirtIO Drivers**
   ```bash
   wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
   mv virtio-win.iso ../image_assets/
   ```

2. **Install Packer**
   ```bash
   # Linux
   wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
   unzip packer_1.9.4_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   
   # Windows
   # Download from packer.io and add to PATH
   ```

3. **Install QEMU/KVM**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   
   # CentOS/RHEL
   sudo yum install qemu-kvm libvirt
   ```

### **Phase 2: Build Execution**
1. **Quick Build (Windows)**
   ```powershell
   cd packer/windows-server-2025
   .\build.ps1
   ```

2. **Quick Build (Linux)**
   ```bash
   cd packer/windows-server-2025
   ./build.sh
   ```

3. **Custom Build**
   ```bash
   # Set environment variables
   export PKR_VAR_win_iso_path="../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso"
   export PKR_VAR_virtio_win_iso_path="../image_assets/virtio-win.iso"
   export PKR_VAR_product_key="3NPK2-7TDCT-7KP99-3VHFX-V26D3"
   export PKR_VAR_admin_password="BakerStreet2025!"
   
   # Build
   packer build windows-server-2025-standard.pkr.hcl
   ```

### **Phase 3: Validation**
1. **Test Image**
   ```bash
   # Create test VM
   virt-install \
     --name windows-test \
     --memory 4096 \
     --vcpus 2 \
     --disk path=output/windows-server-2025-standard/windows-server-2025-standard.qcow2 \
     --network network=default \
     --graphics vnc \
     --import
   ```

2. **Verify Components**
   - [ ] VirtIO drivers installed
   - [ ] WinRM accessible
   - [ ] Windows updates applied
   - [ ] Security hardening applied

## 🔧 **Configuration Details**

### **Base Image Specifications**
- **OS**: Windows Server 2025 Standard (Server Core)
- **Architecture**: x86_64
- **Format**: QCOW2
- **Size**: ~8-12GB (compressed)
- **Boot**: UEFI compatible
- **Drivers**: VirtIO optimized

### **Included Optimizations**
- **VirtIO Drivers**: Network, storage, balloon, RNG, serial
- **WinRM**: Configured for remote management
- **Security**: Defender optimized, unnecessary services disabled
- **Performance**: Power management optimized, indexing disabled
- **Updates**: Latest Windows updates applied

### **Network Configuration**
- **WinRM Ports**: 5985 (HTTP), 5986 (HTTPS)
- **Firewall**: Configured for WinRM access
- **VirtIO Network**: Optimized for KVM

## 🚀 **Deployment Options**

### **Option 1: Direct KVM Deployment**
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

### **Option 2: Terraform Integration**
```hcl
resource "libvirt_volume" "windows_server" {
  name   = "windows-server-2025"
  source = "path/to/windows-server-2025-standard.qcow2"
  pool   = "default"
}

resource "libvirt_domain" "windows_server" {
  name   = "windows-server-2025"
  memory = "4096"
  vcpu   = 2
  
  disk {
    volume_id = libvirt_volume.windows_server.id
  }
  
  network_interface {
    network_name = "default"
  }
}
```

### **Option 3: OpenStack Integration**
```yaml
# Upload image to OpenStack
openstack image create \
  --file windows-server-2025-standard.qcow2 \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  windows-server-2025-standard
```

## 📊 **Expected Results**

### **Build Output**
- **Image File**: `windows-server-2025-standard.qcow2`
- **Size**: 8-12GB (compressed)
- **Format**: QCOW2 (KVM native)
- **Boot Time**: ~2-3 minutes
- **Memory Usage**: ~2-3GB base

### **Performance Characteristics**
- **CPU**: VirtIO optimized
- **Network**: VirtIO network drivers
- **Storage**: VirtIO SCSI drivers
- **Memory**: Balloon driver for dynamic allocation

## 🔍 **Troubleshooting**

### **Common Issues**

1. **Build Timeout**
   - Increase `winrm_timeout` in Packer config
   - Check system resources
   - Verify ISO integrity

2. **VirtIO Drivers Not Installing**
   - Ensure VirtIO ISO is properly mounted
   - Check driver paths in scripts
   - Verify ISO download integrity

3. **WinRM Connection Failed**
   - Check firewall rules
   - Verify port 5986 accessibility
   - Check WinRM configuration

4. **QEMU Not Found**
   - Install QEMU/KVM
   - Add to PATH
   - Verify KVM support

### **Debug Commands**
```bash
# Enable Packer debug logging
export PACKER_LOG=1
export PACKER_LOG_PATH=packer.log
packer build windows-server-2025-standard.pkr.hcl

# Check QEMU KVM support
kvm-ok

# Test VirtIO drivers
qemu-system-x86_64 -device help | grep virtio
```

## 📈 **Success Metrics**

### **Build Success Criteria**
- [ ] Packer build completes without errors
- [ ] Image file created successfully
- [ ] Image boots in KVM
- [ ] VirtIO drivers installed
- [ ] WinRM accessible
- [ ] Windows updates applied

### **Performance Benchmarks**
- **Boot Time**: < 3 minutes
- **Memory Usage**: < 3GB base
- **Disk I/O**: VirtIO optimized
- **Network**: VirtIO performance

## 🔐 **Security Considerations**

### **Base Image Security**
- Windows Defender optimized
- Unnecessary services disabled
- Error reporting disabled
- Cortana disabled
- Windows tips disabled

### **Access Control**
- Administrator password configurable
- WinRM access controlled
- Firewall rules configured
- Remote access secured

## 📝 **Next Steps**

1. **Build the Image**: Execute build process
2. **Test the Image**: Validate in test environment
3. **Deploy to Production**: Use in Baker Street Labs infrastructure
4. **Monitor Performance**: Track resource usage
5. **Update Regularly**: Keep base image current

## 🎯 **Expected Timeline**

- **Preparation**: 30 minutes
- **Build Process**: 30-60 minutes
- **Validation**: 15 minutes
- **Total**: 1.5-2 hours

## 📚 **References**

- [Packer Documentation](https://www.packer.io/docs)
- [QEMU Documentation](https://qemu.readthedocs.io/)
- [VirtIO Drivers](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)
- [Windows Server 2025](https://docs.microsoft.com/en-us/windows-server/)
- [KVM Documentation](https://www.linux-kvm.org/page/Documents)
