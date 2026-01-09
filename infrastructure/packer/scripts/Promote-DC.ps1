# Baker Street Labs - Promote to Domain Controller
# Automatically promotes the server to a domain controller using FirstLogonCommands
# This script is executed during the first logon after Windows installation

param(
    [Parameter(Mandatory=$true)]
    [string]$SafeModePassword
)

$ErrorActionPreference = "Stop"

Write-Host "=== Baker Street Labs Domain Controller Promotion ===" -ForegroundColor Green
Write-Host "Starting at: $(Get-Date)" -ForegroundColor Green

# Convert password to SecureString
$securePassword = ConvertTo-SecureString -String $SafeModePassword -AsPlainText -Force

# Domain Configuration
$domainName = "ad.bakerstreetlabs.io"
$netbiosName = "BAKERSTREET"

Write-Host "Domain Configuration:" -ForegroundColor Yellow
Write-Host "  Domain Name: $domainName" -ForegroundColor Cyan
Write-Host "  NetBIOS Name: $netbiosName" -ForegroundColor Cyan
Write-Host "  Safe Mode Password: [SECURE]" -ForegroundColor Cyan

# Install Active Directory Domain Services (if not already installed)
Write-Host "Installing Active Directory Domain Services..." -ForegroundColor Yellow
try {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Write-Host "✅ AD Domain Services installed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ AD Domain Services may already be installed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Import ADDSDeployment module
Write-Host "Importing ADDSDeployment module..." -ForegroundColor Yellow
Import-Module ADDSDeployment

# Promote to Domain Controller
Write-Host "Promoting server to Domain Controller..." -ForegroundColor Yellow
Write-Host "This will create a new forest: $domainName" -ForegroundColor Cyan

try {
    Install-ADDSForest `
        -CreateDnsDelegation:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -DomainMode "Win2022" `
        -DomainName $domainName `
        -DomainNetbiosName $netbiosName `
        -ForestMode "Win2022" `
        -InstallDns:$true `
        -LogPath "C:\Windows\NTDS" `
        -NoRebootOnCompletion:$false `
        -SysvolPath "C:\Windows\SYSVOL" `
        -Force `
        -SafeModeAdministratorPassword $securePassword

    Write-Host "✅ Domain Controller promotion completed successfully!" -ForegroundColor Green
    Write-Host "  Forest: $domainName" -ForegroundColor Cyan
    Write-Host "  NetBIOS: $netbiosName" -ForegroundColor Cyan
    Write-Host "  DNS: Enabled" -ForegroundColor Cyan
    Write-Host "  Certificate Services: Available" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Domain Controller promotion failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This may require manual intervention" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🎉 Baker Street Labs Domain Controller Setup Complete!" -ForegroundColor Green
Write-Host "The server will now reboot to complete the domain controller configuration." -ForegroundColor Yellow
Write-Host ""
Write-Host "After reboot, the server will be:" -ForegroundColor Cyan
Write-Host "  - Domain Controller for: $domainName" -ForegroundColor White
Write-Host "  - DNS Server: Enabled" -ForegroundColor White
Write-Host "  - WinRM: Available on port 5985/5986" -ForegroundColor White
Write-Host "  - SSH: Available on port 22" -ForegroundColor White
Write-Host "  - RDP: Available on port 3389" -ForegroundColor White
