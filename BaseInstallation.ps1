# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    Write-Host $Message
}

# Function to set IP and DNS
Function Set-IPandDNS {
    param (
        $InterfaceAlias,
        $IPAddress,
        $PrefixLength,
        $DefaultGateway,
        $DNSServers
    )
    if ([string]::IsNullOrEmpty($InterfaceAlias)) {
        $availableInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        if ($availableInterfaces.Count -gt 0) {
            $InterfaceAlias = $availableInterfaces[0].Name
        } else {
            throw "No available network interfaces. Exiting."
        }
    }
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers
    return $InterfaceAlias  # Return the interface alias
}

# Check for administrative privileges
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Log-Message -Message "You need to run this script as an Administrator."
    exit 1
}

# Check for CSV existence
$csvPath = Join-Path $PSScriptRoot "config\ServerBase.csv"
if (-Not (Test-Path $csvPath)) {
    Log-Message -Message "CSV file not found at $csvPath. Exiting."
    exit 1
}

# Read the CSV to get new settings
$serverConfig = Import-Csv -Path $csvPath | Select-Object -First 1
if ($null -eq $serverConfig) {
    Log-Message -Message "No configuration found in CSV. Exiting."
    exit 1
}

# Initialize $selectedInterface; This should be set based on your specific logic
$selectedInterface = $serverConfig.InterfaceAlias
if ([string]::IsNullOrEmpty($selectedInterface)) {
    Log-Message -Message "Interface alias is empty in CSV. Auto-selecting..."
}

# Initiate IP renewal
Invoke-Expression -Command "ipconfig /renew"
Start-Sleep -Seconds 15  # Allow some time for IP renewal

# Get new network settings from DHCP
$dhcpInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '0.0.0.0' -and $_.IPAddress -notmatch "^169\.254\." } | Select-Object -First 1
if ($null -eq $dhcpInfo) {
    Log-Message -Message "Failed to get valid DHCP address. Exiting."
    exit 1
}

# Flush DNS cache
Invoke-Expression -Command "ipconfig /flushdns"
if ($LASTEXITCODE -ne 0) {
    Log-Message -Message "Failed to flush DNS. Exiting."
    exit 1
}
Start-Sleep -Seconds 5  # Allow some time for DNS flush

# Additional logic for your new IP and Gateway goes here

# Attempt to set new IP and DNS
try {
    $selectedInterface = Set-IPandDNS -InterfaceAlias $selectedInterface -IPAddress $newIP -PrefixLength $serverConfig.SubnetMask -DefaultGateway $newGateway -DNSServers ($serverConfig.DNSServers -split ';')
    Log-Message -Message "Successfully set the new IP and DNS settings."
    Start-Sleep -Seconds 10  # Allow some time for settings to apply
    
    # Ping test
    $ping = Test-Connection -ComputerName $newGateway -Count 2 -ErrorAction SilentlyContinue
    if ($null -eq $ping) {
        throw "Ping test failed. Rolling back to previous settings."
    }
    Log-Message -Message "Ping test succeeded."
} catch {
    Log-Message -Message "An error occurred: $_. Rolling back to previous settings."
    # Use $selectedInterface here as well
    Set-NetIPInterface -InterfaceAlias $selectedInterface -DHCP Enabled
    Log-Message -Message "Rolled back to DHCP settings."
    exit 1
}
