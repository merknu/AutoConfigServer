# Function to log messages
Function Log-Message {
    param (
        [string]$Message,
        [string]$LogPath = "DNSSetup.log"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

# Function to install DNS Server role if not already installed
Function Install-DNSServerRole {
    $dnsFeature = Get-WindowsFeature -Name 'DNS' | Where-Object {$_.InstallState -eq 'Installed'}
    if ($null -eq $dnsFeature) {
        try {
            Install-WindowsFeature -Name 'DNS' -IncludeManagementTools
            Log-Message -Message "DNS Server role installed successfully. Waiting for 30 seconds for the installation to complete."
            Start-Sleep -Seconds 30
        } catch {
            Log-Message -Message "Error occurred while installing DNS Server role: $_"
            exit 1
        }
    } else {
        Log-Message -Message "DNS Server role is already installed."
    }
}

# Function to test DNS Resolution
Function Test-DNSResolution {
    param (
        [string]$Domain,
        [string]$ExpectedIP
    )
    $resolvedIP = Resolve-DnsName $Domain | Select-Object -ExpandProperty IPAddress
    return $resolvedIP -eq $ExpectedIP
}

# Function to rollback DNS settings if needed
Function Rollback-DNS {
    param (
        [string]$BackupDNS
    )
    Set-DnsClientServerAddress -InterfaceIndex 1 -ServerAddresses $BackupDNS
    Log-Message -Message "Rolled back to backup DNS settings."
}

# Function to add DNS records
Function Add-DNSRecords {
    param (
        [string]$CsvPath,
        [string]$BackupDNS
    )
    try {
        $csvData = Import-Csv -Path $CsvPath -Delimiter ';'
        foreach ($row in $csvData) {
            if ([string]::IsNullOrEmpty($row.ZoneName) -or [string]::IsNullOrEmpty($row.RecordType)) {
                Log-Message -Message "Validation failed. ZoneName and RecordType cannot be empty. Skipping row."
                continue
            }
            switch ($row.RecordType) {
                'A' {
                    Add-DnsServerResourceRecordA -ZoneName $row.ZoneName -Name $row.HostName -IPv4Address $row.IPAddress
                    if (-not (Test-DNSResolution -Domain "$($row.HostName).$($row.ZoneName)" -ExpectedIP $row.IPAddress)) {
                        throw "DNS resolution test failed for $($row.HostName).$($row.ZoneName)."
                    }
                }
                'CNAME' {
                    Add-DnsServerResourceRecordCName -ZoneName $row.ZoneName -Name $row.HostName -HostNameAlias $row.TargetHost
                }
            }
            Log-Message -Message "Successfully added $($row.RecordType) record for $($row.HostName) in $($row.ZoneName)."
        }
    } catch {
        Log-Message -Message "Error occurred while adding DNS records: $_"
        Rollback-DNS -BackupDNS $BackupDNS
        exit 1
    }
}

# Initialize log file
$logPath = "DNSSetup.log"
if (Test-Path $logPath) {
    Remove-Item -Path $logPath
}
Log-Message -Message "DNSSetup script started on $(Get-Date)" -LogPath $logPath

# Backup DNS settings (assuming InterfaceIndex 1 for simplicity; this should be determined dynamically in a real-world scenario)
$backupDNS = (Get-DnsClientServerAddress -InterfaceIndex 1).ServerAddresses
Log-Message -Message "Backup DNS settings recorded." -LogPath $logPath

# Step 1: Ensure DNS Server role is installed
Install-DNSServerRole

# Step 2: Add DNS records
$csvFilePath = "config\DNSConfiguration.csv"  # Assume the CSV is in the "config" folder
if (Test-Path -Path $csvFilePath -PathType Leaf) {
    Add-DNSRecords -CsvPath $csvFilePath -BackupDNS $backupDNS
} else {
    Log-Message -Message "CSV file does not exist at path $csvFilePath. Exiting." -LogPath $logPath
    exit 1
}
