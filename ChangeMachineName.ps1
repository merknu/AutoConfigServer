# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    Write-Host $Message
}

# Determine the full path to ServerBase.csv
$serverConfigPath = Join-Path $PSScriptRoot "config\ServerBase.csv"

# Read the ServerBase.csv file and get the configuration
try {
    $serverConfig = Import-Csv -Path $serverConfigPath | Select-Object -First 1
} catch {
    Log-Message -Message "Failed to read ServerBase.csv: $_"
    exit 1
}

# Validate the configuration
if ($null -eq $serverConfig) {
    Log-Message -Message "ServerBase.csv is empty or not formatted correctly."
    exit 1
}

# Extract settings
$NewName = $serverConfig.ServerName

# Validate the new machine name
if ([string]::IsNullOrEmpty($NewName)) {
    Log-Message -Message "New machine name is empty in ServerBase.csv."
    exit 1
}

# Get the existing machine name
$existingName = Get-ComputerInfo | Select-Object -ExpandProperty CsName
$needToReboot = $false  # Flag to indicate if a reboot is needed

# Check if the machine name needs to be changed
if ($existingName -ne $NewName) {
    try {
        Rename-Computer -NewName $NewName
        Log-Message -Message "Successfully changed the machine name to $NewName."
        $needToReboot = $true  # Set the flag to true since a name change occurred
    } catch {
        Log-Message -Message "Failed to change the machine name: $_"
        exit 1
    }
} else {
    Log-Message -Message "The machine name is already set to $NewName. Skipping rename."
}

# Restart the computer only if the name was actually changed
if ($needToReboot) {
    try {
        Restart-Computer -Force
    } catch {
        Log-Message -Message "Failed to restart the computer: $_"
        exit 1
    }
}
