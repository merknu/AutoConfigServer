# Function to check for required features
Function Check-Requirements {
    $requiredFeatures = @("RSAT-AD-PowerShell", "FS-SyncShareService")  # Add any other required features
    $missingFeatures = @()

    foreach ($feature in $requiredFeatures) {
        if ((Get-WindowsFeature -Name $feature).InstallState -ne "Installed") {
            $missingFeatures += $feature
        }
    }

    if ($missingFeatures.Count -gt 0) {
        Write-Host "Missing required features: $($missingFeatures -join ', ')"
        return $false
    }

    return $true
}

# Function to log messages
Function Log-Message {
    param(
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
        [string]$ParentPath,
        [string]$LogPath
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

# Check for requirements
if (-Not (Check-Requirements)) {
    Write-Host "Exiting due to missing requirements."
    Exit
}

# Initialize variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csvPath = Join-Path $scriptPath "CSVtoOU.csv"
$logPath = Join-Path $scriptPath "log.txt"

# Import required modules
Import-Module ActiveDirectory
Import-Module FS-SyncShareService

# Read the CSV file
if (Test-Path $csvPath -PathType Leaf) {
    $csvData = Import-Csv -Path $csvPath -Delimiter "`t"  # Tab-delimited

    foreach ($row in $csvData) {
        Create-OUIfNotExist -OUName $row.OUName -ParentPath $row.ParentPath -LogPath $logPath

        # Add more logic here for creating and linking GPOs
        # You would typically use the GroupPolicy cmdlets here, which are part of the RSAT tools.
    }
} else {
    Log-Message -Message "CSV file not found at $csvPath" -LogPath $logPath
}
