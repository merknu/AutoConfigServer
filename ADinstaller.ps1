# Function to log messages
Function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Level - $Message"
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
    }
    Add-Content -Path "error.log" -Value $logMessage
}

# Check for administrative privileges
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Log-Message -Message "You need to run this script as an Administrator." -Level "ERROR"
    exit 1
}

# Check prerequisites
if ([Environment]::OSVersion.Version.Major -lt 10) {
    Log-Message -Message "Windows 10 or higher is required." -Level "WARNING"
    exit 1
}

# Import configurations from ServerBase.csv
$csvPath = Join-Path $PSScriptRoot "config\ServerBase.csv"
if (-Not (Test-Path $csvPath)) {
    Log-Message -Message "CSV file not found at $csvPath. Exiting." -Level "ERROR"
    exit 1
}

$serverConfig = Import-Csv -Path $csvPath | Select-Object -First 1
if ($null -eq $serverConfig) {
    Log-Message -Message "No configuration found in CSV. Exiting." -Level "ERROR"
    exit 1
}

# Apply domain settings
$domainName = $serverConfig.DomainName

# Check if AD role is already installed
$existingADRole = Get-WindowsFeature -Name 'AD-Domain-Services' | Where-Object {$_.InstallState -eq 'Installed'}
if ($existingADRole) {
    Log-Message -Message "AD role is already installed. Skipping installation."
} else {
    # Install AD Domain Services
    Try {
        Install-WindowsFeature -Name 'AD-Domain-Services' -IncludeManagementTools -ErrorAction Stop
        Log-Message -Message "AD Domain Services installed successfully."
    } Catch {
        Log-Message -Message "Failed to install AD Domain Services. Error: $_" -Level "ERROR"
        exit 1
    }
}

# Verify role installation
$verifyRole = Get-WindowsFeature -Name 'AD-Domain-Services' | Where-Object {$_.InstallState -eq 'Installed'}
if ($null -eq $verifyRole) {
    Log-Message -Message "AD role installation verification failed." -Level "ERROR"
    exit 1
}

# Check if Domain Controller is already configured
try {
    $existingDC = Get-ADDomainController -Filter {Name -eq $domainName}
    if ($existingDC) {
        Log-Message -Message "Domain Controller for $domainName already exists. Skipping configuration."
        exit 0
    }
} catch {
    # Ignore the error, as it likely means the DC doesn't exist
}

# Ask user for Safe Mode Password
$securePassword = Read-Host "Enter the Safe Mode password" -AsSecureString

# Install and Configure Domain Controller
try {
    Install-ADDSDomainController `
        -DomainName $domainName `
        -SafeModeAdministratorPassword $securePassword `
        -ErrorAction Stop
    Log-Message -Message "AD installation completed successfully."
} catch {
    Log-Message -Message "Failed to install and configure Domain Controller: $_" -Level "ERROR"
    exit 1
}

# DNS Reverse Record og Scavenging
Try {
    Add-DnsServerPrimaryZone -NetworkId $serverConfig.GlobalSubnet -DynamicUpdate Secure -ReplicationScope Domain -ErrorAction Stop
    Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 -Verbose
    Set-DnsServerZoneAging $serverConfig.DomainName -Aging $true -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00 -Verbose
    Set-DnsServerZoneAging "$($serverConfig.GlobalSubnet).in-addr.arpa" -Aging $true -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00 -Verbose
    Log-Message -Message "DNS configuration completed successfully" -Level "INFO"
} Catch {
    Log-Message -Message "Failed to configure DNS. Error: $_" -Level "ERROR"
}

# Active Directory Sites and Services
Try {
    New-ADReplicationSubnet -Name $serverConfig.GlobalSubnet -Site "Default-First-Site-Name" -Location $serverConfig.SubnetLocation -ErrorAction Stop
    Log-Message -Message "AD Sites and Services configuration completed successfully" -Level "INFO"
} Catch {
    Log-Message -Message "Failed to configure AD Sites and Services. Error: $_" -Level "ERROR"
}

# NTP-konfigurasjon
Try {
    $serverPDC = Get-AdDomainController -Filter * | Where {$_.OperationMasterRoles -contains "PDCEmulator"}
    if ($serverPDC) {
        Start-Process -FilePath "C:\Windows\System32\w32tm.exe" -ArgumentList "/config /manualpeerlist:$($serverConfig.NTPServer1),$($serverConfig.NTPServer2) /syncfromflags:MANUAL /reliable:yes /update" -ErrorAction Stop
        Stop-Service w32time -ErrorAction Stop
        Start-Sleep -Seconds 2
        Start-Service w32time -ErrorAction Stop
        Log-Message -Message "Successfully set NTP Servers: $($serverConfig.NTPServer1) and $($serverConfig.NTPServer2)" -Level "INFO"
    }
} Catch {
    Log-Message -Message "Failed to configure NTP. Error: $_" -Level "ERROR"
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
