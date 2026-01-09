# =============================================================================
# Primary Domain Controller Deployment Script
# =============================================================================
# This script deploys the first domain controller (Forest Root) for the
# baker-street.local Active Directory forest.
#
# Prerequisites:
# - Windows Server 2025 AD DC golden image deployed
# - Network connectivity configured
# - Administrator privileges
#
# Usage:
#   .\01-deploy-primary-dc.ps1 -IPAddress "192.168.0.65" -Hostname "DC01"
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$IPAddress = "192.168.0.65",
    
    [Parameter(Mandatory = $false)]
    [string]$Hostname = "DC01",
    
    [Parameter(Mandatory = $false)]
    [string]$SubnetMask = "255.255.255.0",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultGateway = "192.168.0.1",
    
    [Parameter(Mandatory = $false)]
    [string[]]$DNSServers = @("127.0.0.1"),
    
    [Parameter(Mandatory = $false)]
    [string]$DomainName = "ad.bakerstreetlabs.io",
    
    [Parameter(Mandatory = $false)]
    [string]$DomainNetbiosName = "BAKERSTREETLABS",
    
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
Write-ColorOutput "Primary Domain Controller Deployment" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "IP Address: $IPAddress" "Yellow"
Write-ColorOutput "Hostname: $Hostname" "Yellow"
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
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses $DNSServers
    
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

    # Step 3: Install Active Directory Domain Services
    Write-ColorOutput "`n[3/6] Installing Active Directory Domain Services..." "Green"
    
    try {
        # Install AD DS and DNS roles
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Install-WindowsFeature -Name DNS -IncludeManagementTools
        Install-WindowsFeature -Name RSAT-AD-PowerShell -IncludeAllSubFeature
        
        Write-ColorOutput "  ✓ Active Directory Domain Services installed" "Green"
    } catch {
        throw "Failed to install Active Directory Domain Services: $($_.Exception.Message)"
    }

    # Step 4: Configure DNS forwarders
    Write-ColorOutput "`n[4/6] Configuring DNS forwarders..." "Green"
    
    try {
        # Configure DNS forwarders to FakeNet Suite
        Add-DnsServerForwarder -IPAddress "192.168.0.10"
        Add-DnsServerForwarder -IPAddress "192.168.0.11"
        
        Write-ColorOutput "  ✓ DNS forwarders configured to FakeNet Suite" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Could not configure DNS forwarders: $($_.Exception.Message)" "Yellow"
    }

    # Step 5: Promote to Domain Controller (Forest Root)
    Write-ColorOutput "`n[5/6] Promoting to Domain Controller..." "Green"
    
    try {
        # Convert password to SecureString
        $securePassword = ConvertTo-SecureString -String $SafeModePassword -AsPlainText -Force
        
        # Promote to Domain Controller
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $DomainNetbiosName `
            -DomainMode "Win2016" `
            -ForestMode "Win2016" `
            -InstallDns `
            -SafeModeAdministratorPassword $securePassword `
            -Force `
            -CreateDnsDelegation:$false
        
        Write-ColorOutput "  ✓ Domain Controller promotion initiated" "Green"
        Write-ColorOutput "  ⚠ System will restart automatically to complete promotion" "Yellow"
        
    } catch {
        throw "Failed to promote to Domain Controller: $($_.Exception.Message)"
    }

    # Step 6: Post-promotion configuration (will run after restart)
    Write-ColorOutput "`n[6/6] Configuring post-promotion settings..." "Green"
    
    try {
        # Create post-promotion configuration script
        $postConfigScript = @"
# Post-promotion configuration script
Write-Host "Configuring post-promotion settings..." -ForegroundColor Green

# Configure additional DNS settings
try {
    # Create reverse lookup zone
    Add-DnsServerPrimaryZone -NetworkID "192.168.0.0/24" -ReplicationScope "Domain"
    Write-Host "✓ Reverse lookup zone created" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not create reverse lookup zone: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}

# Configure AD security settings
try {
    # Set password policy
    Set-ADDefaultDomainPasswordPolicy -Identity `$DomainName -MinPasswordLength 14 -PasswordHistoryCount 24 -LockoutDuration "00:30:00" -LockoutThreshold 5
    Write-Host "✓ Password policy configured" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not configure password policy: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Post-promotion configuration completed!" -ForegroundColor Green
"@
        
        $postConfigPath = "C:\Windows\Setup\Scripts\post-promotion-config.ps1"
        $postConfigScript | Out-File -FilePath $postConfigPath -Encoding UTF8
        
        Write-ColorOutput "  ✓ Post-promotion configuration script created" "Green"
        
    } catch {
        Write-ColorOutput "  ⚠ Could not create post-promotion script: $($_.Exception.Message)" "Yellow"
    }

    Write-ColorOutput "`n===============================================" "Cyan"
    Write-ColorOutput "Primary Domain Controller deployment completed!" "Green"
    Write-ColorOutput "===============================================" "Cyan"
    Write-ColorOutput "`nConfiguration Summary:" "Yellow"
    Write-ColorOutput "  - Hostname: $Hostname" "White"
    Write-ColorOutput "  - IP Address: $IPAddress" "White"
    Write-ColorOutput "  - Domain: $DomainName" "White"
    Write-ColorOutput "  - NetBIOS: $DomainNetbiosName" "White"
    Write-ColorOutput "  - DNS Forwarders: 192.168.0.10, 192.168.0.11" "White"
    
    Write-ColorOutput "`nNext Steps:" "Yellow"
    Write-ColorOutput "1. System will restart to complete domain controller promotion" "White"
    Write-ColorOutput "2. Verify domain controller functionality after restart" "White"
    Write-ColorOutput "3. Deploy secondary domain controller (192.168.0.66)" "White"
    Write-ColorOutput "4. Test replication between domain controllers" "White"
    
    Write-ColorOutput "`nImportant Notes:" "Yellow"
    Write-ColorOutput "- Safe Mode Password: $SafeModePassword" "White"
    Write-ColorOutput "- Change default passwords in production" "White"
    Write-ColorOutput "- Monitor event logs for any issues" "White"

    # Restart to complete promotion
    Write-ColorOutput "`nSystem will restart in 30 seconds to complete domain controller promotion..." "Yellow"
    Start-Sleep -Seconds 30
    Restart-Computer -Force

} catch {
    Write-ColorOutput "`n❌ Error during Primary DC deployment: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Please check the error message and try again." "Red"
    exit 1
}
