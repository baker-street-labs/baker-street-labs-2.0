# Windows Server 2025 Optimization Script
# Baker Street Labs - Base Image Optimization
# 
# This script optimizes the Windows Server 2025 base image for KVM deployment

Write-Host "Starting Windows Server 2025 optimization..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Disable Windows Update automatic restart
Write-Host "Configuring Windows Update..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 2 -Type DWord
    Write-Host "Windows Update configured" -ForegroundColor Green
} catch {
    Write-Warning "Failed to configure Windows Update: $($_.Exception.Message)"
}

# Disable Windows Defender real-time protection (for base image)
Write-Host "Configuring Windows Defender..." -ForegroundColor Cyan
try {
    Set-MpPreference -DisableRealtimeMonitoring $true
    Set-MpPreference -DisableBehaviorMonitoring $true
    Set-MpPreference -DisableBlockAtFirstSeen $true
    Set-MpPreference -DisableIOAVProtection $true
    Set-MpPreference -DisablePrivacyMode $true
    Set-MpPreference -DisableScriptScanning $true
    Set-MpPreference -DisableArchiveScanning $true
    Write-Host "Windows Defender configured" -ForegroundColor Green
} catch {
    Write-Warning "Failed to configure Windows Defender: $($_.Exception.Message)"
}

# Disable Windows Error Reporting
Write-Host "Disabling Windows Error Reporting..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord
    Set-Service -Name "WerSvc" -StartupType Disabled
    Write-Host "Windows Error Reporting disabled" -ForegroundColor Green
} catch {
    Write-Warning "Failed to disable Windows Error Reporting: $($_.Exception.Message)"
}

# Disable Windows Search indexing
Write-Host "Disabling Windows Search indexing..." -ForegroundColor Cyan
try {
    Set-Service -Name "WSearch" -StartupType Disabled
    Write-Host "Windows Search indexing disabled" -ForegroundColor Green
} catch {
    Write-Warning "Failed to disable Windows Search: $($_.Exception.Message)"
}

# Configure power settings for server
Write-Host "Configuring power settings..." -ForegroundColor Cyan
try {
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    powercfg /change monitor-timeout-ac 0
    powercfg /change disk-timeout-ac 0
    Write-Host "Power settings configured" -ForegroundColor Green
} catch {
    Write-Warning "Failed to configure power settings: $($_.Exception.Message)"
}

# Disable unnecessary services
Write-Host "Disabling unnecessary services..." -ForegroundColor Cyan
$ServicesToDisable = @(
    "Fax",
    "XblAuthManager",
    "XblGameSave", 
    "XboxGipSvc",
    "XboxNetApiSvc",
    "XboxLiveAuthManager",
    "XboxNetApiSvc",
    "XblGameSave",
    "XboxGipSvc",
    "XboxLiveAuthManager",
    "XboxNetApiSvc"
)

foreach ($Service in $ServicesToDisable) {
    try {
        Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Disabled service: $Service" -ForegroundColor Yellow
    } catch {
        # Service might not exist, which is fine
    }
}

# Configure network settings
Write-Host "Configuring network settings..." -ForegroundColor Cyan
try {
    # Disable IPv6 (optional)
    # Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6
    
    # Configure network adapter settings
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
        $Adapter = $_
        Write-Host "Configuring adapter: $($Adapter.Name)" -ForegroundColor Yellow
        
        # Disable power management
        Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName "Power Management" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
    }
    
    Write-Host "Network settings configured" -ForegroundColor Green
} catch {
    Write-Warning "Failed to configure network settings: $($_.Exception.Message)"
}

# Clean up Windows
Write-Host "Cleaning up Windows..." -ForegroundColor Cyan
try {
    # Clean temporary files
    Get-ChildItem -Path "C:\Windows\Temp" -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Get-ChildItem -Path "C:\Temp" -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    
    # Clean Windows Update cache
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    
    # Clean event logs
    Get-EventLog -LogName Application, System, Security | Clear-EventLog -ErrorAction SilentlyContinue
    
    Write-Host "Windows cleanup completed" -ForegroundColor Green
} catch {
    Write-Warning "Failed to clean up Windows: $($_.Exception.Message)"
}

# Configure time zone
Write-Host "Configuring time zone..." -ForegroundColor Cyan
try {
    Set-TimeZone -Id "UTC"
    Write-Host "Time zone set to UTC" -ForegroundColor Green
} catch {
    Write-Warning "Failed to set time zone: $($_.Exception.Message)"
}

# Final system optimization
Write-Host "Running final system optimization..." -ForegroundColor Cyan
try {
    # Defragment registry
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_ShowMyGames" /t REG_DWORD /d 0 /f
    
    # Disable Windows tips and tricks
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f
    
    # Disable Cortana
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f
    
    Write-Host "Final system optimization completed" -ForegroundColor Green
} catch {
    Write-Warning "Failed to run final system optimization: $($_.Exception.Message)"
}

Write-Host "Windows Server 2025 optimization completed successfully!" -ForegroundColor Green
