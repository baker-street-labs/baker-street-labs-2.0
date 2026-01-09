# Simple script to create virtual switches
Write-Host "Creating virtual switches..." -ForegroundColor Green

# Get the first physical network adapter
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1

if ($adapter) {
    Write-Host "Using adapter: $($adapter.Name)" -ForegroundColor Yellow
    
    # Create External Switch
    try {
        New-VMSwitch -Name "ExternalSwitch" -NetAdapterName $adapter.Name -AllowManagementOS $true
        Write-Host "✓ Created ExternalSwitch" -ForegroundColor Green
    } catch {
        Write-Host "ExternalSwitch may already exist" -ForegroundColor Yellow
    }
    
    # Create Internal Switch
    try {
        New-VMSwitch -Name "InternalSwitch" -SwitchType Internal
        Write-Host "✓ Created InternalSwitch" -ForegroundColor Green
    } catch {
        Write-Host "InternalSwitch may already exist" -ForegroundColor Yellow
    }
} else {
    Write-Host "No physical network adapter found" -ForegroundColor Red
}

Write-Host "Virtual switch setup completed" -ForegroundColor Green
