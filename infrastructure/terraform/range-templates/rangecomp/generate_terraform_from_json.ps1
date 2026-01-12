# Generate Terraform VM Resources from JSON Extraction
# Converts rangeplatform_vms.json to Terraform vsphere_virtual_machine resources for rangecomp
# 
# Usage: .\generate_terraform_from_json.ps1 -InputJson "rangeplatform_vms.json" -OutputTf "rangecomp_vms.tf"
#
# NOTE: IP addresses are NOT hardcoded - they must be provided via tfvars file
# In agentic situations, the agent should provide IP addresses via tfvars file

[CmdletBinding()]
param(
    [string]$InputJson = "rangeplatform_vms.json",
    [string]$OutputTf = "rangecomp_vms.tf",
    [string]$RangeName = "rangecomp",
    [string]$NetworkBase = "172.24"
)

Write-Host "=== Generating Terraform VM Resources ===" -ForegroundColor Cyan
Write-Host "Input: $InputJson" -ForegroundColor Yellow
Write-Host "Output: $OutputTf" -ForegroundColor Yellow
Write-Host "Range: $RangeName" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $InputJson)) {
    Write-Error "Input JSON file not found: $InputJson"
    exit 1
}

$json = Get-Content $InputJson -Raw | ConvertFrom-Json
$vms = $json.VMs

Write-Host "Found $($vms.Count) VM(s) to process" -ForegroundColor Green
Write-Host ""

$terraformContent = @"
# Auto-generated Terraform VM resources for $RangeName
# Generated from: $InputJson
# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 
# NOTE: IP addresses are provided via variables/tfvars file (NOT hardcoded)
# In agentic situations, the agent should provide IP addresses via tfvars file

"@

$vmIds = @()

foreach ($vm in $vms) {
    $vmName = $vm.Name -replace "rangeplatform", $RangeName
    $resourceName = $vmName -replace "-", "_" -replace "\.", "_"
    
    Write-Host "Processing: $($vm.Name) -> $vmName" -ForegroundColor Cyan
    
    # Determine guest OS type (simplified mapping)
    $guestId = "windows9Server64Guest"  # Default
    if ($vm.Guest.OSFullName) {
        if ($vm.Guest.OSFullName -like "*Windows Server 2022*") {
            $guestId = "windows9Server64Guest"
        } elseif ($vm.Guest.OSFullName -like "*Windows Server 2019*") {
            $guestId = "windows9Server64Guest"
        } elseif ($vm.Guest.OSFullName -like "*Windows 10*" -or $vm.Guest.OSFullName -like "*Windows 11*") {
            $guestId = "windows9_64Guest"
        } elseif ($vm.Guest.OSFullName -like "*Linux*") {
            $guestId = "ubuntu64Guest"
        }
    }
    
    # Build network interfaces
    $networkInterfaces = @()
    $networkCount = 0
    foreach ($adapter in $vm.NetworkAdapters) {
        $networkCount++
        $networkVar = "users"
        if ($adapter.NetworkName -like "*services*") {
            $networkVar = "services"
        } elseif ($adapter.NetworkName -like "*infrastructure*" -or $adapter.NetworkName -like "*infra*") {
            $networkVar = "infrastructure"
        }
        
        $networkInterfaces += @"
  # Network adapter $networkCount - $($adapter.NetworkName)
  network_interface {
    network_id   = data.vsphere_network.$networkVar[0].id
    adapter_type = "$($adapter.Type)"
  }

"@
    }
    
    # Build disks
    $disks = @()
    $diskIndex = 0
    foreach ($disk in $vm.HardDisks) {
        $disks += @"
  disk {
    label            = "$($disk.Name)"
    size             = $([math]::Round($disk.CapacityGB))
    eagerly_scrub    = false
    thin_provisioned = true
  }

"@
        $diskIndex++
    }
    
    # Build Terraform resource
    $terraformContent += @"
# VM: $($vm.Name) -> $vmName
resource "vsphere_virtual_machine" "$resourceName" {
  name             = "$vmName"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.liacmain01.id
  folder           = data.vsphere_folder.$RangeName.path

  num_cpus               = $($vm.NumCpu)
  memory                 = $($vm.MemoryMB)
  guest_id               = "$guestId"
  scsi_type              = "pvscsi"
  scsi_bus_sharing       = "noSharing"
  scsi_controller_count   = 1

$($networkInterfaces -join "")
$($disks -join "")
  # IP addresses are provided via variables/tfvars file
  # Example customization (uncomment and configure):
  # clone {
  #   template_uuid = data.vsphere_virtual_machine.template.id
  #
  #   customize {
  #     windows_options {
  #       computer_name  = "$vmName"
  #       workgroup      = "WORKGROUP"
  #       # admin_password = var.windows_admin_password  # From tfvars
  #     }
  #
  #     network_interface {
  #       # IP from variable/tfvars (NOT hardcoded)
  #       # In agentic situations, the agent should provide IP via tfvars
  #       ipv4_address = var.vm_ip_addresses["$vmName"].users_network_ip  # From tfvars
  #       ipv4_netmask = 24
  #     }
  #
  #     ipv4_gateway    = var.users_network_gateway  # From tfvars
  #     dns_server_list = var.dns_servers  # From tfvars
  #   }
  # }
}

"@
    
    $vmIds += "vsphere_virtual_machine.$resourceName.id"
}

# Update locals block with VM IDs
$terraformContent += @"
# Update locals block in rangecomp.tf with:
# vm_ids = [$($vmIds -join ", ")]

"@

$terraformContent | Out-File -FilePath $OutputTf -Encoding UTF8
Write-Host ""
Write-Host "✅ Terraform resources generated: $OutputTf" -ForegroundColor Green
Write-Host "   Resources created: $($vms.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review $OutputTf" -ForegroundColor White
Write-Host "2. Update rangecomp.tf locals.vm_ids with the generated VM IDs" -ForegroundColor White
Write-Host "3. Create terraform.tfvars with IP addresses" -ForegroundColor White
Write-Host "4. Run terraform init, plan, apply" -ForegroundColor White
