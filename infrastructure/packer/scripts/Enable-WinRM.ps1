# Baker Street Labs - Enable WinRM for Ansible
# Based on community standard ConfigureRemotingForAnsible.ps1
# Configures WinRM HTTPS, creates self-signed cert, and opens firewall ports

$ErrorActionPreference = "Stop"

Write-Host "Configuring WinRM for Ansible compatibility..." -ForegroundColor Green

# Create self-signed certificate for WinRM HTTPS
$cert = New-SelfSignedCertificate -DnsName "packer" -CertStoreLocation "cert:\LocalMachine\My"
Write-Host "Created self-signed certificate: $($cert.Thumbprint)" -ForegroundColor Yellow

# Create HTTPS listener
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force
Write-Host "Created WinRM HTTPS listener" -ForegroundColor Yellow

# Configure WinRM service for Ansible compatibility
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false

# Open firewall ports
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "Windows Remote Management (HTTPS-In)" -Profile Any -LocalPort 5986 -Protocol TCP
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Name "Windows Remote Management (HTTP-In)" -Profile Any -LocalPort 5985 -Protocol TCP

Write-Host "✅ WinRM configured successfully" -ForegroundColor Green
Write-Host "  - HTTPS: Port 5986" -ForegroundColor Cyan
Write-Host "  - HTTP: Port 5985" -ForegroundColor Cyan
Write-Host "  - Basic Auth: Enabled" -ForegroundColor Cyan
Write-Host "  - Self-signed cert: $($cert.Thumbprint)" -ForegroundColor Cyan
