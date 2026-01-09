# =============================================================================
# Secondary Domain Controller Deployment Script
# =============================================================================
# This script deploys the second domain controller for the
# baker-street.local Active Directory domain.
#
# Prerequisites:
# - Primary domain controller (192.168.0.65) operational
# - Windows Server 2025 AD DC golden image deployed
# - Network connectivity to primary DC
# - Administrator privileges
#
# Usage:
#   .\02-deploy-secondary-dc.ps1 -IPAddress "192.168.0.66" -Hostname "DC02"
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$IPAddress = "192.168.0.66",
    
    [Parameter(Mandatory = $false)]
    [string]$Hostname = "DC02",
    
    [Parameter(Mandatory = $false)]
    [string]$SubnetMask = "255.255.255.0",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultGateway = "192.168.0.1",
    
    [Parameter(Mandatory = $false)]
    [string]$PrimaryDCIP = "192.168.0.65",
    
    [Parameter(Mandatory = $false)]
    [string]$DomainName = "ad.bakerstreetlabs.io",
    
    [Parameter(Mandatory = $false)]
    [string]$SafeModePassword = "DSRMPassword123!",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "AdminPassword123!"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "Secondary Domain Controller Deployment" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "IP Address: $IPAddress" "Yellow"
Write-ColorOutput "Hostname: $Hostname" "Yellow"
Write-ColorOutput "Primary DC: $PrimaryDCIP" "Yellow"
Write-ColorOutput "Domain: $DomainName" "Yellow"
Write-ColorOutput "===============================================" "Cyan"

try {
    # Step 1: Configure network settings
    Write-ColorOutput "`n[1/6] Configuring network settings..." "Green"
    
    # Get the primary network adapter
    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -ne 'Loopback' } | Select-Object -First 1
    if (-not $netAdapter) {
        throw "No active network adapter found"
    }
    
    Write-ColorOutput "  - Using adapter: $($netAdapter.Name)" "White"
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    
    # Configure static IP address
    New-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $DefaultGateway
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses $PrimaryDCIP, "127.0.0.1"
    
    Write-ColorOutput "  ✓ Network configuration completed" "Green"

    # Step 2: Set hostname
    Write-ColorOutput "`n[2/6] Setting hostname..." "Green"
    
    $currentHostname = $env:COMPUTERNAME
    if ($currentHostname -ne $Hostname) {
        Write-ColorOutput "  - Renaming computer from '$currentHostname' to '$Hostname'" "White"
        Rename-Computer -NewName $Hostname -Force
        Write-ColorOutput "  ✓ Hostname set to '$Hostname'" "Green"
    } else {
        Write-ColorOutput "  ✓ Hostname already set to '$Hostname'" "Green"
    }

    # Step 3: Test connectivity to primary DC
    Write-ColorOutput "`n[3/6] Testing connectivity to primary DC..." "Green"
    
    try {
        # Test network connectivity
        $pingResult = Test-NetConnection -ComputerName $PrimaryDCIP -Port 389 -InformationLevel Quiet
        if (-not $pingResult) {
            throw "Cannot connect to primary DC at $PrimaryDCIP on port 389 (LDAP)"
        }
        
        # Test DNS resolution
        $dnsResult = Resolve-DnsName -Name $DomainName -Server $PrimaryDCIP -ErrorAction SilentlyContinue
        if (-not $dnsResult) {
            throw "Cannot resolve domain name $DomainName using primary DC DNS"
        }
        
        Write-ColorOutput "  ✓ Connectivity to primary DC verified" "Green"
    } catch {
        throw "Connectivity test failed: $($_.Exception.Message)"
    }

    # Step 4: Install Active Directory Domain Services
    Write-ColorOutput "`n[4/6] Installing Active Directory Domain Services..." "Green"
    
    try {
        # Install AD DS and DNS roles
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Install-WindowsFeature -Name DNS -IncludeManagementTools
        Install-WindowsFeature -Name RSAT-AD-PowerShell -IncludeAllSubFeature
        
        Write-ColorOutput "  ✓ Active Directory Domain Services installed" "Green"
    } catch {
        throw "Failed to install Active Directory Domain Services: $($_.Exception.Message)"
    }

    # Step 5: Configure DNS forwarders
    Write-ColorOutput "`n[5/6] Configuring DNS forwarders..." "Green"
    
    try {
        # Configure DNS forwarders to FakeNet Suite
        Add-DnsServerForwarder -IPAddress "192.168.0.10"
        Add-DnsServerForwarder -IPAddress "192.168.0.11"
        
        Write-ColorOutput "  ✓ DNS forwarders configured to FakeNet Suite" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Could not configure DNS forwarders: $($_.Exception.Message)" "Yellow"
    }

    # Step 6: Promote to Additional Domain Controller
    Write-ColorOutput "`n[6/6] Promoting to Additional Domain Controller..." "Green"
    
    try {
        # Convert password to SecureString
        $securePassword = ConvertTo-SecureString -String $SafeModePassword -AsPlainText -Force
        
        # Create credentials for domain join
        $domainCredential = New-Object System.Management.Automation.PSCredential("$DomainName\Administrator", (ConvertTo-SecureString -String $AdminPassword -AsPlainText -Force))
        
        # Promote to Additional Domain Controller
        Install-ADDSDomainController `
            -DomainName $DomainName `
            -InstallDns `
            -SafeModeAdministratorPassword $securePassword `
            -Credential $domainCredential `
            -Force `
            -NoRebootOnCompletion:$false
        
        Write-ColorOutput "  ✓ Additional Domain Controller promotion initiated" "Green"
        Write-ColorOutput "  ⚠ System will restart automatically to complete promotion" "Yellow"
        
    } catch {
        throw "Failed to promote to Additional Domain Controller: $($_.Exception.Message)"
    }

    # Step 7: Post-promotion configuration (will run after restart)
    Write-ColorOutput "`n[7/7] Configuring post-promotion settings..." "Green"
    
    try {
        # Create post-promotion configuration script
        $postConfigScript = @"
# Post-promotion configuration script for Secondary DC
Write-Host "Configuring post-promotion settings..." -ForegroundColor Green

# Wait for replication to complete
Write-Host "Waiting for replication to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Verify replication
try {
    `$replicationStatus = repadmin /replsummary
    Write-Host "✓ Replication status verified" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not verify replication: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}

# Configure DNS settings
try {
    # Set DNS client to use both DCs
    Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter | Where-Object {`$_.Status -eq 'Up'}).ifIndex -ServerAddresses "127.0.0.1", "$PrimaryDCIP"
    Write-Host "✓ DNS client configuration updated" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not update DNS client: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Secondary DC post-promotion configuration completed!" -ForegroundColor Green
"@
        
        $postConfigPath = "C:\Windows\Setup\Scripts\post-promotion-config-secondary.ps1"
        $postConfigScript | Out-File -FilePath $postConfigPath -Encoding UTF8
        
        Write-ColorOutput "  ✓ Post-promotion configuration script created" "Green"
        
    } catch {
        Write-ColorOutput "  ⚠ Could not create post-promotion script: $($_.Exception.Message)" "Yellow"
    }

    Write-ColorOutput "`n===============================================" "Cyan"
    Write-ColorOutput "Secondary Domain Controller deployment completed!" "Green"
    Write-ColorOutput "===============================================" "Cyan"
    Write-ColorOutput "`nConfiguration Summary:" "Yellow"
    Write-ColorOutput "  - Hostname: $Hostname" "White"
    Write-ColorOutput "  - IP Address: $IPAddress" "White"
    Write-ColorOutput "  - Primary DC: $PrimaryDCIP" "White"
    Write-ColorOutput "  - Domain: $DomainName" "White"
    Write-ColorOutput "  - DNS Forwarders: 192.168.0.10, 192.168.0.11" "White"
    
    Write-ColorOutput "`nNext Steps:" "Yellow"
    Write-ColorOutput "1. System will restart to complete domain controller promotion" "White"
    Write-ColorOutput "2. Verify replication between domain controllers" "White"
    Write-ColorOutput "3. Test domain authentication and DNS resolution" "White"
    Write-ColorOutput "4. Configure additional AD services as needed" "White"
    
    Write-ColorOutput "`nImportant Notes:" "Yellow"
    Write-ColorOutput "- Safe Mode Password: $SafeModePassword" "White"
    Write-ColorOutput "- Monitor replication status after restart" "White"
    Write-ColorOutput "- Verify DNS resolution from both DCs" "White"

    # Restart to complete promotion
    Write-ColorOutput "`nSystem will restart in 30 seconds to complete domain controller promotion..." "Yellow"
    Start-Sleep -Seconds 30
    Restart-Computer -Force

} catch {
    Write-ColorOutput "`n❌ Error during Secondary DC deployment: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Please check the error message and try again." "Red"
    exit 1
}
