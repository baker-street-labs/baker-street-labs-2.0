# Baker Street Labs - Configure SSH with Public Key
# Adds the provided SSH public key to the Administrator's authorized_keys

$ErrorActionPreference = "Stop"

Write-Host "Configuring SSH with public key..." -ForegroundColor Green

# Get the SSH public key from environment variable
$sshPublicKey = $env:SSH_PUBLIC_KEY

if (-not $sshPublicKey) {
    Write-Host "❌ SSH_PUBLIC_KEY environment variable not set" -ForegroundColor Red
    exit 1
}

Write-Host "SSH Public Key: $($sshPublicKey.Substring(0, 50))..." -ForegroundColor Yellow

# Create .ssh directory for Administrator
$sshDir = "C:\Users\Administrator\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -Path $sshDir -ItemType Directory -Force
    Write-Host "Created SSH directory: $sshDir" -ForegroundColor Yellow
}

# Add public key to authorized_keys
$authorizedKeysPath = "$sshDir\authorized_keys"

# Check if key already exists
$existingKeys = @()
if (Test-Path $authorizedKeysPath) {
    $existingKeys = Get-Content $authorizedKeysPath
}

$keyExists = $false
foreach ($key in $existingKeys) {
    if ($key.Trim() -eq $sshPublicKey.Trim()) {
        $keyExists = $true
        break
    }
}

if (-not $keyExists) {
    Add-Content -Path $authorizedKeysPath -Value $sshPublicKey
    Write-Host "✅ Added SSH public key to authorized_keys" -ForegroundColor Green
} else {
    Write-Host "✅ SSH public key already exists in authorized_keys" -ForegroundColor Green
}

# Set proper permissions on SSH directory and files
$acl = Get-Acl $sshDir
$acl.SetAccessRuleProtection($true, $false)
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrator", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl -Path $sshDir -AclObject $acl

if (Test-Path $authorizedKeysPath) {
    $acl = Get-Acl $authorizedKeysPath
    $acl.SetAccessRuleProtection($true, $false)
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrator", "FullControl", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $authorizedKeysPath -AclObject $acl
}

Write-Host "✅ SSH directory permissions configured" -ForegroundColor Green

# Configure SSH daemon
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
$sshdConfig = @"
# Baker Street Labs SSH Configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
LoginGraceTime 120
PermitRootLogin yes
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
"@

Set-Content -Path $sshdConfigPath -Value $sshdConfig -Encoding ASCII
Write-Host "✅ SSH daemon configuration updated" -ForegroundColor Green

# Restart SSH service
Restart-Service sshd
Write-Host "✅ SSH service restarted" -ForegroundColor Green

Write-Host "🎉 SSH configuration completed successfully!" -ForegroundColor Green
Write-Host "  - Public key added to Administrator's authorized_keys" -ForegroundColor Cyan
Write-Host "  - SSH daemon configured and restarted" -ForegroundColor Cyan
Write-Host "  - Permissions set correctly" -ForegroundColor Cyan
