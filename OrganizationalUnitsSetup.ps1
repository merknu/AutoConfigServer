# Function to ensure the ActiveDirectory module is loaded
Function Ensure-ActiveDirectoryModule {
    if (-Not (Get-Module -Name "ActiveDirectory")) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            try {
                Install-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction Stop
                Import-Module ActiveDirectory -ErrorAction Stop
            } catch {
                Write-Host "Failed to install or import the ActiveDirectory module. Exiting."
                exit 1
            }
        }
    }
}

# Function to log messages
Function Log-Message {
    param (
        [string]$Message,
        [string]$LogPath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

# Function to create an OU if it doesn't exist
Function Create-OUIfNotExist {
    param(
        [string]$OUName,
        [string]$ParentPath
    )
    try {
        $ouExists = Get-ADOrganizationalUnit -Filter { Name -eq $OUName } -SearchBase $ParentPath -ErrorAction SilentlyContinue
        if ($null -eq $ouExists) {
            New-ADOrganizationalUnit -Name $OUName -Path $ParentPath
            Log-Message -Message "Created OU: $OUName under $ParentPath" -LogPath $logPath
        } else {
            Log-Message -Message "OU $OUName already exists under $ParentPath" -LogPath $logPath
        }
    } catch {
        Log-Message -Message "An error occurred: $_" -LogPath $logPath
    }
}

# Initialize variables
$scriptDir = $PSScriptRoot
$logPath = Join-Path -Path $scriptDir -ChildPath "script.log"
$csvPath = Join-Path -Path $scriptDir -ChildPath "config\OUConfiguration.csv"  # Portable path

# Ensure ActiveDirectory module is loaded
Ensure-ActiveDirectoryModule

# Check for CSV file
if (-Not (Test-Path $csvPath)) {
    Log-Message -Message "CSV file not found. Exiting." -LogPath $logPath
    exit 1
}

# Load data from .csv
$csvData = Import-Csv -Path $csvPath -Delimiter ';'
$totalRows = $csvData.Count
$currentRow = 0
$autoConfirm = $false

foreach ($row in $csvData) {
    $currentRow++
    Write-Progress -PercentComplete (($currentRow / $totalRows) * 100) -Status "Processing row $currentRow of $totalRows" -Activity "Creating OUs..."

    $ouExists = Get-ADOrganizationalUnit -Filter { Name -eq $row.OUName } -SearchBase $row.ParentPath -ErrorAction SilentlyContinue
    
    if ($null -eq $ouExists) {
        if ($autoConfirm -eq $false) {
            $confirmation = Read-Host "Are you sure you want to create OU $($row.OUName) under $($row.ParentPath)? (y/n/a for yes to all)"
            if ($confirmation -eq 'a') {
                $autoConfirm = $true
            }
        }
        
        if ($autoConfirm -or $confirmation -eq 'y') {
            Create-OUIfNotExist -OUName $row.OUName -ParentPath $row.ParentPath
        }
    } else {
        Log-Message -Message "OU $($row.OUName) already exists under $($row.ParentPath). Skipping." -LogPath $logPath
    }
}

Write-Host "Script execution completed."
