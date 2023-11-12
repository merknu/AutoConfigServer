#--------------------------------------------------------------------------
#- Created by: Knut Ingmar Merødningen                                              -
#- Linkedin: [https://www.linkedin.com/in/knut-ingmar-mer%C3%B8dningen-289b3789/]   -
#--------------------------------------------------------------------------

#-------------
#- Functions -
#-------------

# Function to log messages
Function Log-Message {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Level = "INFO"
    )

    switch ($Level) {
        "INFO"    { Write-Output $Message }
        "WARNING" { Write-Warning $Message }
        "ERROR"   { Write-Error $Message }
    }
}

# Function to set IP and DNS
Function Set-IPandDNS {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $InterfaceAlias,

        [Parameter(Mandatory)]
        $IPAddress,

        [Parameter(Mandatory)]
        $PrefixLength,

        [Parameter(Mandatory)]
        $DefaultGateway,

        [Parameter(Mandatory)]
        $DNSServers
    )

    try {
        New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers -ErrorAction Stop
        Log-Message -Message "Network settings applied to $InterfaceAlias: IP $IPAddress, Gateway $DefaultGateway, DNS $DNSServers"
    } catch {
        Log-Message -Message "Failed to apply network settings: $_" -Level "ERROR"
        throw
    }
}

#-------------
#- Main Logic -
#-------------

try {
    # Check for administrative privileges
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Log-Message -Message "You need to run this script as an Administrator." -Level "ERROR"
        exit 1
    }

    # Check for CSV existence
    $csvPath = Join-Path $PSScriptRoot "config\ServerBase.csv"
    if (-Not (Test-Path $csvPath)) {
        Log-Message -Message "CSV file not found at $csvPath. Exiting." -Level "ERROR"
        exit 1
    }

    # Read the CSV to get new settings
    $serverConfig = Import-Csv -Path $csvPath | Select-Object -First 1
    if ($null -eq $serverConfig) {
        Log-Message -Message "No configuration found in CSV. Exiting." -Level "ERROR"
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
        Log-Message -Message "Failed to get valid DHCP address. Exiting." -Level "ERROR"
        exit 1
    }

    # Flush DNS cache
    Invoke-Expression -Command "ipconfig /flushdns"
    if ($LASTEXITCODE -ne 0) {
        Log-Message -Message "Failed to flush DNS. Exiting." -Level "ERROR"
        exit 1
    }
    Start-Sleep -Seconds 5  # Allow some time for DNS flush

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
        Log-Message -Message "An error occurred: $_. Rolling back to previous settings." -Level "ERROR"
        # Use $selectedInterface here as well
        Set-NetIPInterface -InterfaceAlias $selectedInterface -DHCP Enabled
        Log-Message -Message "Rolled back to DHCP settings."
        exit 1
    }

    # Ytterligere logikk for å håndtere RDP, IE Enhanced Security Configuration, etc.
    # Set RDP
    Try {
        IF ($serverConfig.EnableRDP -eq "yes") {
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0 -ErrorAction Stop
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
            Log-Message -Message "RDP Successfully enabled"
        } ELSE {
            Log-Message -Message "RDP remains disabled"
        }
    } Catch {
        Log-Message -Message "Failed to enable/disable RDP. Error: $_" -Level "ERROR"
    }

    # Disable IE Enhanced Security Configuration 
    Try {
        IF ($serverConfig.DisableIESec -eq "yes") {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0 -ErrorAction Stop
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0 -ErrorAction Stop
            Log-Message -Message "IE Enhanced Security Configuration successfully disabled for Admin and User"
        } ELSE {
            Log-Message -Message "IE Enhanced Security Configuration remains enabled"
        }
    } Catch {
        Log-Message -Message "Failed to disable/enable IE Security Configuration. Error: $_" -Level "ERROR"
    }

    # Set Hostname
    Try {
        Rename-Computer -ComputerName $env:computername -NewName $serverConfig.ComputerName -ErrorAction Stop
        Log-Message -Message "Computer name set to $($serverConfig.ComputerName)"
    } Catch {
        Log-Message -Message "Failed to set new computer name. Error: $_" -Level "ERROR"
    }

    # Reboot Computer to apply settings
    Log-Message -Message "Save all your work, computer rebooting in 30 seconds"
    Sleep 30

    Try {
        Restart-Computer -ComputerName $env:computername -ErrorAction Stop
        Log-Message -Message "Rebooting Now!!"
    } Catch {
        Log-Message -Message "Failed to restart computer $($env:computername). Error: $_" -Level "ERROR"
    }

} catch {
    Log-Message -Message "En feil oppstod: $_" -Level "ERROR"
    # Eventuell rollback-logikk eller exit
}
