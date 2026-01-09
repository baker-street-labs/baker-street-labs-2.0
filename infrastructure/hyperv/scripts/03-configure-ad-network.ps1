# =============================================================================
# Active Directory Network Configuration Script
# =============================================================================
# This script configures network settings specifically for Active Directory
# domain controllers including DNS, time synchronization, and connectivity.
#
# Prerequisites:
# - Windows Server 2025 with AD DS role installed
# - Administrator privileges
# - Network connectivity
#
# Usage:
#   .\03-configure-ad-network.ps1 -IPAddress "192.168.0.65" -IsPrimary $true
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$IPAddress,
    
    [Parameter(Mandatory = $true)]
    [bool]$IsPrimary,
    
    [Parameter(Mandatory = $false)]
    [string]$SecondaryIP = "192.168.0.66",
    
    [Parameter(Mandatory = $false)]
    [string]$SubnetMask = "255.255.255.0",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultGateway = "192.168.0.1",
    
    [Parameter(Mandatory = $false)]
    [string[]]$DNSForwarders = @("192.168.0.10", "192.168.0.11"),
    
    [Parameter(Mandatory = $false)]
    [string]$DomainName = "ad.bakerstreetlabs.io"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "Active Directory Network Configuration" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "IP Address: $IPAddress" "Yellow"
Write-ColorOutput "Role: $(if ($IsPrimary) { 'Primary DC' } else { 'Secondary DC' })" "Yellow"
Write-ColorOutput "Gateway: $DefaultGateway" "Yellow"
Write-ColorOutput "===============================================" "Cyan"

try {
    # Step 1: Configure network adapter
    Write-ColorOutput "`n[1/6] Configuring network adapter..." "Green"
    
    # Get the primary network adapter
    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -ne 'Loopback' } | Select-Object -First 1
    if (-not $netAdapter) {
        throw "No active network adapter found"
    }
    
    Write-ColorOutput "  - Using adapter: $($netAdapter.Name)" "White"
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    
    # Configure static IP address
    New-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $DefaultGateway
    Write-ColorOutput "  ✓ IP address configured: $IPAddress" "Green"

    # Step 2: Configure DNS client settings
    Write-ColorOutput "`n[2/6] Configuring DNS client settings..." "Green"
    
    if ($IsPrimary) {
        # Primary DC should use itself as primary DNS
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses "127.0.0.1", $SecondaryIP
        Write-ColorOutput "  ✓ Primary DC DNS configured: 127.0.0.1, $SecondaryIP" "Green"
    } else {
        # Secondary DC should use primary DC as primary DNS
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses $SecondaryIP, "127.0.0.1"
        Write-ColorOutput "  ✓ Secondary DC DNS configured: $SecondaryIP, 127.0.0.1" "Green"
    }

    # Step 3: Configure DNS Server forwarders
    Write-ColorOutput "`n[3/6] Configuring DNS forwarders..." "Green"
    
    try {
        # Remove existing forwarders
        $existingForwarders = Get-DnsServerForwarder -ErrorAction SilentlyContinue
        if ($existingForwarders) {
            Remove-DnsServerForwarder -IPAddress $existingForwarders.IPAddress -Force -ErrorAction SilentlyContinue
        }
        
        # Add new forwarders to FakeNet Suite
        foreach ($forwarder in $DNSForwarders) {
            Add-DnsServerForwarder -IPAddress $forwarder
            Write-ColorOutput "  - Added DNS forwarder: $forwarder" "White"
        }
        
        Write-ColorOutput "  ✓ DNS forwarders configured to FakeNet Suite" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Could not configure DNS forwarders: $($_.Exception.Message)" "Yellow"
    }

    # Step 4: Configure time synchronization
    Write-ColorOutput "`n[4/6] Configuring time synchronization..." "Green"
    
    try {
        # Stop Windows Time service
        Stop-Service -Name w32time -Force -ErrorAction SilentlyContinue
        
        # Configure time synchronization
        if ($IsPrimary) {
            # Primary DC should sync with external time source
            w32tm /config /manualpeerlist:"time.windows.com,0x8 pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update
            Write-ColorOutput "  ✓ Primary DC configured to sync with external time sources" "Green"
        } else {
            # Secondary DC should sync with primary DC
            w32tm /config /manualpeerlist:"$SecondaryIP,0x8" /syncfromflags:manual /reliable:yes /update
            Write-ColorOutput "  ✓ Secondary DC configured to sync with primary DC" "Green"
        }
        
        # Start Windows Time service
        Start-Service -Name w32time
        Set-Service -Name w32time -StartupType Automatic
        
        # Force time synchronization
        w32tm /resync /force
        
        Write-ColorOutput "  ✓ Time synchronization configured and started" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Error configuring time synchronization: $($_.Exception.Message)" "Yellow"
    }

    # Step 5: Configure DNS zones and records
    Write-ColorOutput "`n[5/6] Configuring DNS zones..." "Green"
    
    try {
        if ($IsPrimary) {
            # Primary DC creates the domain zone
            $zoneExists = Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue
            if (-not $zoneExists) {
                Add-DnsServerPrimaryZone -Name $DomainName -ReplicationScope "Domain"
                Write-ColorOutput "  ✓ Primary DNS zone created: $DomainName" "Green"
            } else {
                Write-ColorOutput "  ✓ Primary DNS zone already exists: $DomainName" "Green"
            }
            
            # Create reverse lookup zone
            $reverseZoneExists = Get-DnsServerZone -Name "0.168.192.in-addr.arpa" -ErrorAction SilentlyContinue
            if (-not $reverseZoneExists) {
                Add-DnsServerPrimaryZone -NetworkID "192.168.0.0/24" -ReplicationScope "Domain"
                Write-ColorOutput "  ✓ Reverse lookup zone created: 192.168.0.0/24" "Green"
            } else {
                Write-ColorOutput "  ✓ Reverse lookup zone already exists" "Green"
            }
        }
        
        # Add DNS records for both DCs
        $dnsRecords = @(
            @{Name="dc01"; IP="192.168.0.65"},
            @{Name="dc02"; IP="192.168.0.66"},
            @{Name="$DomainName"; IP=$IPAddress}
        )
        
        foreach ($record in $dnsRecords) {
            try {
                $existingRecord = Get-DnsServerResourceRecord -ZoneName $DomainName -Name $record.Name -ErrorAction SilentlyContinue
                if (-not $existingRecord) {
                    Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $record.Name -IPv4Address $record.IP
                    Write-ColorOutput "  - Added DNS record: $($record.Name) -> $($record.IP)" "White"
                }
            } catch {
                Write-ColorOutput "  ⚠ Could not add DNS record $($record.Name): $($_.Exception.Message)" "Yellow"
            }
        }
        
        Write-ColorOutput "  ✓ DNS zones and records configured" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Error configuring DNS zones: $($_.Exception.Message)" "Yellow"
    }

    # Step 6: Configure network security and firewall
    Write-ColorOutput "`n[6/6] Configuring network security..." "Green"
    
    try {
        # Configure Windows Firewall for Active Directory
        Enable-NetFirewallRule -DisplayGroup "Active Directory Domain Services"
        Enable-NetFirewallRule -DisplayGroup "DNS"
        Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
        
        # Configure ICMP for network troubleshooting
        Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"
        
        Write-ColorOutput "  ✓ Network security configured" "Green"
    } catch {
        Write-ColorOutput "  ⚠ Error configuring network security: $($_.Exception.Message)" "Yellow"
    }

    # Display configuration summary
    Write-ColorOutput "`n===============================================" "Cyan"
    Write-ColorOutput "Network configuration completed!" "Green"
    Write-ColorOutput "===============================================" "Cyan"
    
    Write-ColorOutput "`nConfiguration Summary:" "Yellow"
    Write-ColorOutput "  - IP Address: $IPAddress" "White"
    Write-ColorOutput "  - Subnet Mask: $SubnetMask" "White"
    Write-ColorOutput "  - Default Gateway: $DefaultGateway" "White"
    Write-ColorOutput "  - DNS Forwarders: $($DNSForwarders -join ', ')" "White"
    Write-ColorOutput "  - Time Sync: $(if ($IsPrimary) { 'External sources' } else { 'Primary DC' })" "White"
    
    # Test network connectivity
    Write-ColorOutput "`nTesting network connectivity..." "Yellow"
    
    try {
        # Test gateway connectivity
        $gatewayTest = Test-NetConnection -ComputerName $DefaultGateway -InformationLevel Quiet
        if ($gatewayTest) {
            Write-ColorOutput "  ✓ Gateway connectivity: PASS" "Green"
        } else {
            Write-ColorOutput "  ✗ Gateway connectivity: FAIL" "Red"
        }
        
        # Test DNS resolution
        $dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
        if ($dnsTest) {
            Write-ColorOutput "  ✓ DNS resolution: PASS" "Green"
        } else {
            Write-ColorOutput "  ✗ DNS resolution: FAIL" "Red"
        }
        
        # Test time synchronization
        $timeTest = w32tm /query /status | Select-String "Source:"
        if ($timeTest) {
            Write-ColorOutput "  ✓ Time synchronization: CONFIGURED" "Green"
        } else {
            Write-ColorOutput "  ⚠ Time synchronization: NOT VERIFIED" "Yellow"
        }
        
    } catch {
        Write-ColorOutput "  ⚠ Could not complete connectivity tests: $($_.Exception.Message)" "Yellow"
    }

    Write-ColorOutput "`nNext Steps:" "Yellow"
    Write-ColorOutput "1. Verify network connectivity to other domain controllers" "White"
    Write-ColorOutput "2. Test DNS resolution and forwarders" "White"
    Write-ColorOutput "3. Monitor time synchronization status" "White"
    Write-ColorOutput "4. Configure additional network services as needed" "White"

} catch {
    Write-ColorOutput "`n❌ Error during network configuration: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Please check the error message and try again." "Red"
    exit 1
}
