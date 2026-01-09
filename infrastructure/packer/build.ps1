# Windows Server 2025 Base Image Build Script
# Baker Street Labs Infrastructure
# 
# This script automates the Packer build process for Windows Server 2025 Standard base image

param(
    [string]$IsoPath = "../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso",
    [string]$VirtioIsoPath = "../image_assets/virtio-win.iso",
    [string]$ProductKey = "3NPK2-7TDCT-7KP99-3VHFX-V26D3",
    [string]$AdminPassword = "BakerStreet2025!",
    [switch]$Headless = $false,
    [switch]$Clean = $false
)

Write-Host "Windows Server 2025 Base Image Build Script" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check if Packer is installed
Write-Host "Checking Packer installation..." -ForegroundColor Cyan
try {
    $PackerVersion = & packer version
    Write-Host "Packer found: $PackerVersion" -ForegroundColor Green
} catch {
    Write-Error "Packer is not installed or not in PATH. Please install Packer first."
    exit 1
}

# Check if QEMU is available
Write-Host "Checking QEMU availability..." -ForegroundColor Cyan
try {
    $QemuVersion = & qemu-system-x86_64 --version
    Write-Host "QEMU found: $QemuVersion" -ForegroundColor Green
} catch {
    Write-Warning "QEMU not found. Make sure QEMU is installed and in PATH."
}

# Validate ISO files
Write-Host "Validating ISO files..." -ForegroundColor Cyan
if (!(Test-Path $IsoPath)) {
    Write-Error "Windows Server 2025 ISO not found at: $IsoPath"
    exit 1
}
Write-Host "Windows Server 2025 ISO found: $IsoPath" -ForegroundColor Green

if (!(Test-Path $VirtioIsoPath)) {
    Write-Warning "VirtIO ISO not found at: $VirtioIsoPath"
    Write-Host "Please download VirtIO drivers ISO from: https://fedoraproject.org/wiki/Windows_Virtio_Drivers"
    Write-Host "Or set -VirtioIsoPath parameter to correct path"
}

# Clean previous builds if requested
if ($Clean) {
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    if (Test-Path "output") {
        Remove-Item -Path "output" -Recurse -Force
        Write-Host "Previous builds cleaned" -ForegroundColor Green
    }
}

# Create output directory
if (!(Test-Path "output")) {
    New-Item -ItemType Directory -Path "output" -Force
    Write-Host "Output directory created" -ForegroundColor Green
}

# Set environment variables for Packer
$env:PKR_VAR_win_iso_path = $IsoPath
$env:PKR_VAR_virtio_win_iso_path = $VirtioIsoPath
$env:PKR_VAR_product_key = $ProductKey
$env:PKR_VAR_admin_password = $AdminPassword
$env:PKR_VAR_headless = $Headless.ToString().ToLower()

Write-Host "Build configuration:" -ForegroundColor Cyan
Write-Host "  ISO Path: $IsoPath" -ForegroundColor White
Write-Host "  VirtIO ISO: $VirtioIsoPath" -ForegroundColor White
Write-Host "  Product Key: $($ProductKey.Substring(0,5))****" -ForegroundColor White
Write-Host "  Headless: $Headless" -ForegroundColor White

# Start Packer build
Write-Host "Starting Packer build..." -ForegroundColor Green
Write-Host "This process may take 30-60 minutes depending on your system..." -ForegroundColor Yellow

try {
    $BuildStartTime = Get-Date
    
    if ($Headless) {
        & packer build -var "headless=true" windows-server-2025-standard.pkr.hcl
    } else {
        & packer build windows-server-2025-standard.pkr.hcl
    }
    
    $BuildEndTime = Get-Date
    $BuildDuration = $BuildEndTime - $BuildStartTime
    
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Build duration: $($BuildDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    
    # Display output information
    $OutputFiles = Get-ChildItem -Path "output" -Recurse -File
    Write-Host "Output files:" -ForegroundColor Cyan
    foreach ($File in $OutputFiles) {
        $FileSize = [math]::Round($File.Length / 1GB, 2)
        Write-Host "  $($File.FullName) ($FileSize GB)" -ForegroundColor White
    }
    
} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}

Write-Host "Windows Server 2025 base image build completed!" -ForegroundColor Green
Write-Host "Output location: output/windows-server-2025-standard/" -ForegroundColor Cyan
