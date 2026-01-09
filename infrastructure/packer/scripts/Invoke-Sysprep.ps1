# Baker Street Labs - Sysprep the Image
# Generalizes the Windows image for deployment

$ErrorActionPreference = "Stop"

Write-Host "Generalizing Windows image with Sysprep..." -ForegroundColor Green

# Sysprep the image for deployment
$sysprepPath = "$env:windir\System32\Sysprep\sysprep.exe"

if (Test-Path $sysprepPath) {
    Write-Host "Running Sysprep to generalize the image..." -ForegroundColor Yellow
    Write-Host "This will shut down the VM after completion" -ForegroundColor Yellow
    
    try {
        & $sysprepPath /generalize /oobe /shutdown /unattend:A:\autounattend.xml
        Write-Host "✅ Sysprep completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Sysprep failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Sysprep executable not found at: $sysprepPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Image generalization completed" -ForegroundColor Green
Write-Host "The VM will now shut down and the image is ready for deployment." -ForegroundColor Cyan
