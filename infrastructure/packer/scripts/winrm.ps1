# WinRM Configuration Script
# Baker Street Labs - Windows Server 2025 Base Image
# 
# This script configures WinRM for Packer communication

Write-Host "Configuring WinRM..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Configure WinRM
try {
    # Enable WinRM
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    
    # Configure WinRM service
    winrm quickconfig -q
    
    # Set WinRM to start automatically
    Set-Service -Name "WinRM" -StartupType Automatic
    
    # Configure WinRM listener
    winrm create winrm/config/Listener?Address=*+Transport=HTTP
    
    # Configure WinRM for HTTPS (optional)
    $CertThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*$env:COMPUTERNAME*"} | Select-Object -First 1).Thumbprint
    if ($CertThumbprint) {
        winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$CertThumbprint`"}"
    }
    
    # Configure WinRM settings
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/client '@{AllowUnencrypted="true"}'
    winrm set winrm/config/client '@{TrustedHosts="*"}'
    
    # Configure firewall
    New-NetFirewallRule -DisplayName "WinRM-HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
    
    # Configure PowerShell execution policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    
    Write-Host "WinRM configured successfully" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to configure WinRM: $($_.Exception.Message)"
    exit 1
}

# Test WinRM connectivity
try {
    $TestResult = Test-WSMan -ComputerName localhost
    if ($TestResult) {
        Write-Host "WinRM connectivity test passed" -ForegroundColor Green
    } else {
        Write-Warning "WinRM connectivity test failed"
    }
} catch {
    Write-Warning "WinRM connectivity test failed: $($_.Exception.Message)"
}

Write-Host "WinRM configuration completed" -ForegroundColor Green
