# Function to log messages
Function Log-Message {
    param (
        [string]$Message,
        [string]$LogPath = "DHCPServerSetup.log"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

# Function to install DHCP Server role if not already installed
Function Install-DHCPServerRole {
    $existingDHCP = Get-WindowsFeature -Name 'DHCP' | Where-Object {$_.InstallState -eq 'Installed'}
    if ($null -eq $existingDHCP) {
        try {
            Install-WindowsFeature -Name 'DHCP' -IncludeManagementTools
            Log-Message -Message "DHCP Server role installed successfully. Waiting 30 seconds."
            Start-Sleep -Seconds 30
        } catch {
            Log-Message -Message "Error: Failed to install DHCP Server role."
            exit 1
        }
    } else {
        Log-Message -Message "DHCP Server role is already installed."
    }
}

# Initialize log file
if (Test-Path "DHCPServerSetup.log") {
    Remove-Item -Path "DHCPServerSetup.log"
}
Log-Message -Message "DHCPServerSetup script started on $(Get-Date)"

# Step 1: Install DHCP Server Role
Install-DHCPServerRole

# Step 2: Import Configuration from CSV and Configure DHCP Scope and Options
$csvPath = Join-Path $PSScriptRoot "config\DHCPConfiguration.csv"
$backupCsvPath = Join-Path $PSScriptRoot "config\BackupDHCPConfiguration.csv"

Function Configure-DHCP {
    param (
        [string]$CsvPath
    )
    if (Test-Path -Path $CsvPath) {
        $dhcpConfig = Import-Csv -Path $CsvPath
        foreach ($config in $dhcpConfig) {
            try {
                Add-DhcpServerv4Scope -Name $config.ScopeName -StartRange $config.StartRange -EndRange $config.EndRange -SubnetMask $config.SubnetMask
                Log-Message -Message "Configured DHCP scope $($config.ScopeName). Waiting for 10 seconds for changes to apply."
                Start-Sleep -Seconds 10
            } catch {
                Log-Message -Message "Failed to configure DHCP scope $($config.ScopeName). Rolling back."
                Configure-DHCP -CsvPath $backupCsvPath
                exit 1
            }
        }
    } else {
        Log-Message -Message "No DHCP Configuration CSV found at $CsvPath. Exiting."
        exit 1
    }
}

Configure-DHCP -CsvPath $csvPath

# Step 3: Authorize DHCP Server
$dhcpServer = Get-DhcpServerInDC
if (-not $dhcpServer) {
    try {
        Add-DhcpServerInDC
        Log-Message -Message "DHCP Server authorized. Waiting 10 seconds for changes to apply."
        Start-Sleep -Seconds 10
    } catch {
        Log-Message -Message "Failed to authorize DHCP Server."
        exit 1
    }
} else {
    Log-Message -Message "DHCP Server is already authorized."
}

# Verification Step: Check if DHCP Server Service is running
$service = Get-Service -Name 'DHCPServer'
if ($service.Status -eq 'Running') {
    Log-Message -Message "DHCP Server is running."
} else {
    Log-Message -Message "DHCP Server is not running. Please check the service manually."
    exit 1
}

Log-Message -Message "DHCPServerSetup script completed."
