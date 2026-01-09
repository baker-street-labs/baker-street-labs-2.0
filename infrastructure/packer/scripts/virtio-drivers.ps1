# VirtIO Drivers Installation Script
# Baker Street Labs - Windows Server 2025 Base Image
# 
# This script installs VirtIO drivers for optimal KVM performance

Write-Host "Starting VirtIO drivers installation..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Create temporary directory
$TempDir = "C:\Windows\Temp\VirtIO"
if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force
}

# Mount VirtIO ISO (assuming it's available as D: drive)
$VirtIODrive = "D:"
if (Test-Path "$VirtIODrive\") {
    Write-Host "VirtIO ISO found at $VirtIODrive" -ForegroundColor Yellow
    
    # Copy drivers to temp directory
    Copy-Item "$VirtIODrive\*" -Destination $TempDir -Recurse -Force
    
    # Install VirtIO drivers
    $Drivers = @(
        "balloon",
        "netkvm", 
        "viorng",
        "vioscsi",
        "vioserial",
        "viostor"
    )
    
    foreach ($Driver in $Drivers) {
        $DriverPath = "$TempDir\$Driver"
        if (Test-Path $DriverPath) {
            Write-Host "Installing $Driver driver..." -ForegroundColor Cyan
            
            # Use pnputil to install driver
            try {
                $DriverInf = Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse | Select-Object -First 1
                if ($DriverInf) {
                    & pnputil.exe /add-driver $DriverInf.FullName /install
                    Write-Host "$Driver driver installed successfully" -ForegroundColor Green
                } else {
                    Write-Warning "No .inf file found for $Driver"
                }
            } catch {
                Write-Warning "Failed to install $Driver driver: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Driver path not found: $DriverPath"
        }
    }
    
    # Configure network adapter for VirtIO
    Write-Host "Configuring network adapter..." -ForegroundColor Cyan
    try {
        # Enable network adapter
        Get-NetAdapter | Where-Object {$_.Name -like "*VirtIO*"} | Enable-NetAdapter
        Write-Host "Network adapter configured" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to configure network adapter: $($_.Exception.Message)"
    }
    
} else {
    Write-Warning "VirtIO ISO not found at $VirtIODrive"
    Write-Host "Please ensure VirtIO drivers ISO is mounted" -ForegroundColor Red
}

# Clean up
if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force
}

Write-Host "VirtIO drivers installation completed" -ForegroundColor Green
