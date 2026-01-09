# Baker Street Labs - Install Windows Updates
# Installs all available Windows Updates using PSWindowsUpdate module

$ErrorActionPreference = "Stop"

Write-Host "Installing Windows Updates..." -ForegroundColor Green

# Install PSWindowsUpdate module
Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Yellow
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
    Write-Host "✅ PSWindowsUpdate module installed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Failed to install PSWindowsUpdate module: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Continuing with manual update check..." -ForegroundColor Yellow
}

# Search for and install updates
Write-Host "Searching for Windows Updates..." -ForegroundColor Yellow
try {
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
    
    if (Get-Module PSWindowsUpdate) {
        Write-Host "Using PSWindowsUpdate module for updates..." -ForegroundColor Yellow
        $updateResult = Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
        if ($updateResult.RebootRequired) {
            Write-Host "✅ Updates installed, reboot required" -ForegroundColor Green
        } else {
            Write-Host "✅ No updates found or reboot not required" -ForegroundColor Green
        }
    } else {
        Write-Host "Using built-in Windows Update..." -ForegroundColor Yellow
        # Fallback to built-in Windows Update
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0")
        
        if ($searchResult.Updates.Count -gt 0) {
            Write-Host "Found $($searchResult.Updates.Count) updates to install" -ForegroundColor Yellow
            $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($update in $searchResult.Updates) {
                $updatesToDownload.Add($update)
            }
            
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updatesToDownload
            $downloader.Download()
            
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updatesToDownload
            $installResult = $installer.Install()
            
            Write-Host "✅ Updates installed successfully" -ForegroundColor Green
        } else {
            Write-Host "✅ No updates found" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "⚠️ Update installation encountered issues: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Continuing with image creation..." -ForegroundColor Yellow
}

Write-Host "✅ Windows Updates process completed" -ForegroundColor Green
