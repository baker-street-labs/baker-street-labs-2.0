# Baker Street Labs - Install Windows Features
# Installs OpenSSH Server, QEMU Guest Agent, and other essential features

$ErrorActionPreference = "Stop"

Write-Host "Installing Windows Features..." -ForegroundColor Green

# Install OpenSSH Server
Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
Write-Host "✅ OpenSSH Server installed and started" -ForegroundColor Green

# Install QEMU Guest Agent (if VirtIO CD is available)
Write-Host "Installing QEMU Guest Agent..." -ForegroundColor Yellow
$qemuAgentPath = "E:\guest-agent\qemu-ga-x86_64.msi"
if (Test-Path $qemuAgentPath) {
    Start-Process msiexec.exe -ArgumentList "/i $qemuAgentPath /qn /norestart" -Wait
    Write-Host "✅ QEMU Guest Agent installed" -ForegroundColor Green
} else {
    Write-Host "⚠️ QEMU Guest Agent not found on VirtIO CD" -ForegroundColor Yellow
}

# Install Windows Features for Active Directory
Write-Host "Installing Active Directory prerequisites..." -ForegroundColor Yellow
$features = @(
    "AD-Domain-Services",
    "DNS", 
    "ADCS-Cert-Authority",
    "RSAT-ADDS",
    "RSAT-DNS-Server"
)

foreach ($feature in $features) {
    try {
        Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
        Write-Host "✅ Installed: $feature" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to install: $feature - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Enable Remote Desktop
Write-Host "Enabling Remote Desktop..." -ForegroundColor Yellow
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "✅ Remote Desktop enabled" -ForegroundColor Green

Write-Host "✅ Windows Features installation completed" -ForegroundColor Green
