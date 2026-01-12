# EXTRACTED FROM PRODUCTION BAKER STREET LABS vCenter – 2026-01-11
# Range Template VM Extraction Script (Enhanced with Affinity Rules)
# Extracts comprehensive VM configuration from vCenter folder (template-based)
# Includes: VMs, affinity rules, network configuration, storage verification
# Output: JSON file with all VM properties, affinity rules, and network config for Terraform/Template generation
#
# NOTE: This is a TEMPLATE script. The folder name should be provided as a parameter.
# IP addresses are extracted from VMs but should be configured via Terraform variables/tfvars.
# In agentic situations, the agent should provide IP addresses via tfvars file.

<#
.SYNOPSIS
    Extracts VM configuration, affinity rules, and network config from vCenter folder (template-based)

.DESCRIPTION
    Connects to vCenter, extracts all VM properties from the specified folder,
    extracts DRS affinity rules, network configuration (vSwitches, port groups, VLANs),
    verifies storage (liacmain01) and host consistency, and outputs comprehensive JSON data.
    
    NOTE: IP addresses are extracted from existing VMs but should be configured via
    Terraform variables (tfvars file) or user input. In agentic situations, the agent
    should provide IP addresses via tfvars file.

.PARAMETER vCenterServer
    vCenter server FQDN or IP address (default: 10.55.250.97)

.PARAMETER OutputFile
    Output JSON file path (default: rangetemplate_vms.json)

.PARAMETER FolderName
    vCenter folder name to extract from (default: rangetemplate)
    NOTE: This should match the folder name in vCenter (e.g., rangetemplate, rangexdr, etc.)

.EXAMPLE
    .\rangetemplate_extract.ps1
    .\rangetemplate_extract.ps1 -vCenterServer "vcenter.example.com" -OutputFile "output.json" -FolderName "rangetemplate"
    .\rangetemplate_extract.ps1 -FolderName "rangexdr"
#>

[CmdletBinding()]
param(
    [string]$vCenterServer = "10.55.250.97",
    [string]$OutputFile = "rangetemplate_vms.json",
    [string]$FolderName = "rangetemplate",
    [string]$SecretsFile = if ($env:SECRETS_FILE) { $env:SECRETS_FILE } else { "$PSScriptRoot\..\..\..\..\.secrets" }
)

# Error handling
$ErrorActionPreference = "Stop"

# Function to read credentials from .secrets file
function Get-Secrets {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        throw "Secrets file not found: $FilePath"
    }
    
    $secrets = @{}
    Get-Content $FilePath | Where-Object { $_ -match '^\s*([^#=]+)=(.+)$' } | ForEach-Object {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $secrets[$key] = $value
    }
    
    return $secrets
}

# Function to extract VM configuration
function Get-VMConfiguration {
    param([VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM)
    
    Write-Verbose "Extracting configuration for VM: $($VM.Name)"
    
    try {
        # Get VM View for detailed properties
        $vmView = $VM | Get-View
        
        # Get Guest Info
        $guestInfo = $null
        try {
            $guestInfo = $VM.Guest
        } catch {
            Write-Verbose "Guest info not available for $($VM.Name)"
        }
        
        # Get Network Adapters with detailed network info
        $networkAdapters = @()
        $VM | Get-NetworkAdapter | ForEach-Object {
            $adapterView = $_ | Get-View
            $portGroup = $_.NetworkName
            $vSwitch = $null
            $vlanId = $null
            
            # Try to get vSwitch and VLAN info
            try {
                $networkView = $adapterView.Network | Get-View
                if ($networkView) {
                    $portGroupObj = Get-VirtualPortGroup -VMHost $VM.VMHost -Name $portGroup -ErrorAction SilentlyContinue
                    if ($portGroupObj) {
                        $vSwitch = $portGroupObj.VirtualSwitch.Name
                        $vlanId = $portGroupObj.VLanId
                    }
                }
            } catch {
                Write-Verbose "Could not get network details for adapter $($_.Name)"
            }
            
            $networkAdapters += @{
                Name = $_.Name
                NetworkName = $_.NetworkName
                Type = $_.Type
                MacAddress = $_.MacAddress
                WakeOnLan = $_.WakeOnLanEnabled
                ConnectionState = $_.ConnectionState.Connected
                StartConnected = $_.ConnectionState.StartConnected
                VirtualSwitch = $vSwitch
                VLANId = $vlanId
            }
        }
        
        # Get Guest Network Info (IPs)
        # NOTE: IP addresses are extracted for reference but should be configured via
        # Terraform variables (tfvars file) or user input. In agentic situations,
        # the agent should provide IP addresses via tfvars file.
        $guestNetworks = @()
        if ($guestInfo -and $guestInfo.Net) {
            foreach ($net in $guestInfo.Net) {
                $guestNetworks += @{
                    NetworkName = $net.NetworkName
                    IpAddress = $net.IpAddress
                    IpConfig = $net.IpConfig
                }
            }
        }
        
        # Get Hard Disks
        $hardDisks = @()
        $VM | Get-HardDisk | ForEach-Object {
            $hardDisks += @{
                Name = $_.Name
                CapacityGB = [math]::Round($_.CapacityGB, 2)
                StorageFormat = $_.StorageFormat
                DiskType = $_.DiskType
                Persistence = $_.Persistence
                Filename = $_.Filename
            }
        }
        
        # Get Snapshots
        $snapshots = @()
        $VM | Get-Snapshot | ForEach-Object {
            $snapshots += @{
                Name = $_.Name
                Description = $_.Description
                Created = $_.Created.ToString("yyyy-MM-ddTHH:mm:ssZ")
                SizeGB = [math]::Round($_.SizeGB, 2)
                IsCurrent = $_.IsCurrent
                ParentSnapshotName = $_.ParentSnapshotName
            }
        }
        
        # Get Tags
        $tags = @()
        $VM | Get-TagAssignment | ForEach-Object {
            $tags += $_.Tag.Name
        }
        
        # Get Custom Attributes
        $customAttributes = @{}
        $VM | Get-Annotation | Where-Object { $_.Name -notlike "*.Sysprep*" } | ForEach-Object {
            $customAttributes[$_.Name] = $_.Value
        }
        
        # Get Resource Pool
        $resourcePool = $null
        if ($VM.ResourcePool) {
            $resourcePool = $VM.ResourcePool.Name
        }
        
        # Get Datastore (verify liacmain01)
        $datastores = @()
        $VM | Get-Datastore | ForEach-Object {
            $datastores += @{
                Name = $_.Name
                Type = $_.Type
                FreeSpaceGB = [math]::Round($_.FreeSpaceGB, 2)
                CapacityGB = [math]::Round($_.CapacityGB, 2)
            }
        }
        
        # Verify storage is on liacmain01
        $primaryDatastore = ($datastores | Where-Object { $_.Name -like "*liacmain01*" })
        if (-not $primaryDatastore) {
            Write-Warning "VM $($VM.Name) is not using liacmain01 datastore. Current datastores: $($datastores.Name -join ', ')"
        }
        
        # Get Host (for affinity verification)
        $hostInfo = $null
        if ($VM.VMHost) {
            $hostInfo = @{
                Name = $VM.VMHost.Name
                Id = $VM.VMHost.Id
                ConnectionState = $VM.VMHost.ConnectionState
                PowerState = $VM.VMHost.PowerState
            }
        }
        
        # Get Cluster
        $clusterInfo = $null
        if ($VM.VMHost) {
            $cluster = $VM.VMHost | Get-Cluster -ErrorAction SilentlyContinue
            if ($cluster) {
                $clusterInfo = @{
                    Name = $cluster.Name
                    Id = $cluster.Id
                }
            }
        }
        
        # Build VM configuration object
        $guestObj = @{
            OSFullName = if ($guestInfo) { $guestInfo.OSFullName } else { $null }
            ToolsVersion = if ($guestInfo) { $guestInfo.ToolsVersion } else { $null }
            ToolsStatus = if ($guestInfo) { $guestInfo.ToolsStatus.ToString() } else { "NotAvailable" }
            State = if ($guestInfo) { $guestInfo.State.ToString() } else { "Unknown" }
            HostName = if ($guestInfo) { $guestInfo.HostName } else { $null }
            IpAddress = if ($guestInfo) { $guestInfo.IpAddress } else { $null }
        }
        
        $vmConfig = @{
            Name = $VM.Name
            PowerState = $VM.PowerState.ToString()
            NumCpu = $VM.NumCpu
            MemoryGB = [math]::Round($VM.MemoryGB, 2)
            MemoryMB = $VM.MemoryMB
            Guest = $guestObj
            HardwareVersion = $VM.HardwareVersion
            Version = $VM.Version
            Folder = ($VM.Folder.Name -join '/')
            ResourcePool = $resourcePool
            NetworkAdapters = $networkAdapters
            GuestNetworks = $guestNetworks
            HardDisks = $hardDisks
            Snapshots = $snapshots
            Tags = $tags
            CustomAttributes = $customAttributes
            Datastores = $datastores
            PrimaryDatastore = if ($primaryDatastore) { $primaryDatastore.Name } else { $null }
            Host = $hostInfo
            Cluster = $clusterInfo
            Notes = $VM.Notes
            ProvisionedSpaceGB = [math]::Round($VM.ProvisionedSpaceGB, 2)
            UsedSpaceGB = [math]::Round($VM.UsedSpaceGB, 2)
            Id = $VM.Id
            Uid = $VM.Uid
        }
        
        return $vmConfig
    }
    catch {
        Write-Error "Error extracting configuration for VM $($VM.Name): $_"
        return $null
    }
}

# Function to extract DRS affinity rules
function Get-AffinityRules {
    param(
        [string[]]$VMIds,
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeClusterImpl]$Cluster
    )
    
    Write-Verbose "Extracting affinity rules for cluster: $($Cluster.Name)"
    
    $affinityRules = @()
    
    try {
        # Get all DRS rules for the cluster
        $drsRules = Get-DrsRule -Cluster $Cluster -ErrorAction SilentlyContinue
        
        foreach ($rule in $drsRules) {
            # Check if this rule applies to any of our VMs
            $ruleVMIds = @()
            if ($rule.VMIds) {
                $ruleVMIds = $rule.VMIds
            }
            
            $appliesToVMs = $false
            $matchingVMs = @()
            foreach ($vmId in $VMIds) {
                if ($ruleVMIds -contains $vmId) {
                    $appliesToVMs = $true
                    $matchingVMs += $vmId
                }
            }
            
            if ($appliesToVMs) {
                $affinityRules += @{
                    Name = $rule.Name
                    Type = $rule.Type.ToString()
                    Enabled = $rule.Enabled
                    Mandatory = $rule.Mandatory
                    VMIds = $ruleVMIds
                    MatchingVMIds = $matchingVMs
                }
            }
        }
        
        # If no affinity rules found, check if all VMs are on the same host
        if ($affinityRules.Count -eq 0) {
            Write-Warning "No DRS affinity rules found for folder VMs. Check if all VMs are on the same host."
        }
    }
    catch {
        Write-Warning "Could not extract affinity rules: $_"
    }
    
    return $affinityRules
}

# Function to extract network configuration
function Get-NetworkConfiguration {
    param(
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]]$VMs
    )
    
    Write-Verbose "Extracting network configuration"
    
    $networkConfig = @{
        VirtualSwitches = @()
        PortGroups = @()
        VLANs = @()
    }
    
    try {
        # Get unique hosts from VMs
        $hosts = $VMs | Select-Object -ExpandProperty VMHost -Unique
        
        foreach ($host in $hosts) {
            # Get virtual switches
            $vSwitches = Get-VirtualSwitch -VMHost $host -ErrorAction SilentlyContinue
            foreach ($vSwitch in $vSwitches) {
                $networkConfig.VirtualSwitches += @{
                    Name = $vSwitch.Name
                    Host = $host.Name
                    NumPorts = $vSwitch.NumPorts
                    Mtu = $vSwitch.Mtu
                }
            }
            
            # Get port groups
            $portGroups = Get-VirtualPortGroup -VMHost $host -ErrorAction SilentlyContinue
            foreach ($pg in $portGroups) {
                $vlanId = $null
                if ($pg.VLanId) {
                    $vlanId = $pg.VLanId
                }
                
                $networkConfig.PortGroups += @{
                    Name = $pg.Name
                    Host = $host.Name
                    VirtualSwitch = $pg.VirtualSwitch.Name
                    VLANId = $vlanId
                }
                
                # Track unique VLANs
                if ($vlanId -and $networkConfig.VLANs | Where-Object { $_.Id -eq $vlanId }) {
                    # Already tracked
                } elseif ($vlanId) {
                    $networkConfig.VLANs += @{
                        Id = $vlanId
                        PortGroup = $pg.Name
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Could not extract network configuration: $_"
    }
    
    return $networkConfig
}

# Main script
try {
    Write-Host "=== Range Template VM Extraction Script (Enhanced) ===" -ForegroundColor Cyan
    Write-Host "vCenter Server: $vCenterServer" -ForegroundColor Yellow
    Write-Host "Folder Name: $FolderName" -ForegroundColor Yellow
    Write-Host ""
    
    # Read credentials
    Write-Host "Reading credentials from: $SecretsFile" -ForegroundColor Yellow
    $secrets = Get-Secrets -FilePath $SecretsFile
    
    $username = $secrets['VCENTER_USERNAME']
    $password = $secrets['VCENTER_PASSWORD']
    
    if (-not $username -or -not $password) {
        throw "VCENTER_USERNAME or VCENTER_PASSWORD not found in secrets file"
    }
    
    Write-Host "Credentials loaded successfully" -ForegroundColor Green
    Write-Host ""
    
    # Check if PowerCLI is installed
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Warning "VMware.PowerCLI module not found. Attempting to install..."
        Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
    }
    
    # Import PowerCLI module
    Import-Module VMware.PowerCLI -ErrorAction Stop
    
    # Suppress certificate warnings (for lab environments)
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
    
    # Connect to vCenter
    Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
    $connection = Connect-VIServer -Server $vCenterServer -User $username -Password $password -ErrorAction Stop
    Write-Host "Connected successfully" -ForegroundColor Green
    Write-Host ""
    
    # Get VMs from specified folder
    Write-Host "Searching for VMs in '$FolderName' folder..." -ForegroundColor Yellow
    
    # Find the folder
    $folder = Get-Folder -Name $FolderName -ErrorAction SilentlyContinue
    if (-not $folder) {
        # Try to find it recursively
        $allFolders = Get-Folder | Where-Object { $_.Name -eq $FolderName }
        if ($allFolders) {
            $folder = $allFolders[0]
        }
    }
    
    if ($folder) {
        Write-Host "Found folder: $($folder.FullPath)" -ForegroundColor Green
        $vms = Get-VM -Location $folder
    }
    else {
        Write-Warning "Folder '$FolderName' not found. Searching for VMs with '$FolderName' in name or path..."
        $vms = Get-VM | Where-Object { 
            $_.Folder.Name -like "*$FolderName*" -or 
            $_.Name -like "*$FolderName*" -or
            $_.Folder.FullPath -like "*$FolderName*"
        }
    }
    
    if (-not $vms -or $vms.Count -eq 0) {
        Write-Warning "No VMs found in $FolderName folder"
        Write-Host "Available folders:" -ForegroundColor Yellow
        Get-Folder | Select-Object Name, FullPath | Format-Table -AutoSize
        Disconnect-VIServer -Server $vCenterServer -Confirm:$false
        exit 1
    }
    
    Write-Host "Found $($vms.Count) VM(s)" -ForegroundColor Green
    Write-Host ""
    
    # Verify all VMs are on the same host (affinity check)
    $hosts = $vms | Select-Object -ExpandProperty VMHost -Unique
    if ($hosts.Count -gt 1) {
        Write-Warning "VMs are on multiple hosts: $($hosts.Name -join ', ')"
        Write-Warning "Affinity rule may be needed to ensure all VMs stay on the same host"
    } else {
        Write-Host "All VMs are on the same host: $($hosts[0].Name)" -ForegroundColor Green
    }
    Write-Host ""
    
    # Extract configuration for each VM
    $vmConfigurations = @()
    $vmIds = @()
    $count = 0
    $cluster = $null
    
    foreach ($vm in $vms) {
        $count++
        Write-Host "[$count/$($vms.Count)] Processing: $($vm.Name)" -ForegroundColor Cyan
        $config = Get-VMConfiguration -VM $vm
        if ($config) {
            $vmConfigurations += $config
            $vmIds += $vm.Id
            if ($config.Cluster -and -not $cluster) {
                $cluster = Get-Cluster -Id $config.Cluster.Id -ErrorAction SilentlyContinue
            }
            Write-Host "  ✓ Configuration extracted" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ Failed to extract configuration" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Extract affinity rules
    Write-Host "Extracting affinity rules..." -ForegroundColor Yellow
    $affinityRules = @()
    if ($cluster) {
        $affinityRules = Get-AffinityRules -VMIds $vmIds -Cluster $cluster
        Write-Host "Found $($affinityRules.Count) affinity rule(s)" -ForegroundColor Green
    } else {
        Write-Warning "Could not determine cluster for affinity rules"
    }
    Write-Host ""
    
    # Extract network configuration
    Write-Host "Extracting network configuration..." -ForegroundColor Yellow
    $networkConfig = Get-NetworkConfiguration -VMs $vms
    Write-Host "Found $($networkConfig.VirtualSwitches.Count) virtual switch(es), $($networkConfig.PortGroups.Count) port group(s), $($networkConfig.VLANs.Count) VLAN(s)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "=== Extraction Summary ===" -ForegroundColor Cyan
    Write-Host "Total VMs processed: $($vmConfigurations.Count)" -ForegroundColor Yellow
    Write-Host "Affinity rules found: $($affinityRules.Count)" -ForegroundColor Yellow
    Write-Host "Network configuration extracted: Yes" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "NOTE: IP addresses are extracted for reference only." -ForegroundColor Yellow
    Write-Host "      IP addresses should be configured via Terraform variables (tfvars file) or user input." -ForegroundColor Yellow
    Write-Host "      In agentic situations, the agent should provide IP addresses via tfvars file." -ForegroundColor Yellow
    Write-Host ""
    
    # Create output object
    $output = @{
        ExtractionDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        vCenterServer = $vCenterServer
        FolderPath = if ($folder) { $folder.FullPath } else { "Not found - searched by name/path" }
        FolderName = $FolderName
        VMs = $vmConfigurations
        AffinityRules = $affinityRules
        NetworkConfiguration = $networkConfig
        HostConsistency = @{
            AllOnSameHost = ($hosts.Count -eq 1)
            Hosts = $hosts | ForEach-Object { $_.Name }
            HostCount = $hosts.Count
        }
        StorageRequirement = @{
            ExpectedDatastore = "liacmain01"
            VMsUsingExpectedDatastore = ($vmConfigurations | Where-Object { $_.PrimaryDatastore -like "*liacmain01*" }).Count
            TotalVMs = $vmConfigurations.Count
        }
        Notes = @{
            IPAddressSource = "IP addresses are extracted for reference only. Configure via Terraform variables (tfvars file) or user input. In agentic situations, the agent should provide IP addresses via tfvars file."
        }
    }
    
    # Convert to JSON and save
    $jsonOutput = $output | ConvertTo-Json -Depth 20
    $jsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Output saved to: $OutputFile" -ForegroundColor Green
    Write-Host "File size: $([math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor Yellow
    Write-Host ""
    
    # Disconnect from vCenter
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false
    Write-Host "Disconnected from vCenter" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Extraction Complete ===" -ForegroundColor Cyan
    
    return $output
}
catch {
    Write-Error "Script failed: $_"
    Write-Warning "Stack trace:"
    Write-Warning $_.ScriptStackTrace
    
    # Try to disconnect if connected
    try {
        Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        # Ignore disconnect errors
    }
    
    exit 1
}
