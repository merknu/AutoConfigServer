# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    Write-Host $Message
}

# Import the CSV file
$csvFilePath = Join-Path $PSScriptRoot "config\GPOConfiguration.csv"  # Portable path
if (-not (Test-Path -Path $csvFilePath -PathType Leaf)) {
    Log-Message -Message "CSV file does not exist. Exiting."
    exit 1
}

# Read CSV data
$csvData = Import-Csv -Path $csvFilePath

# Loop through each row
foreach ($row in $csvData) {
    $gpoName = $row.PolicyName
    $linkedOU = $row.LinkedOU
    $settingsFile = $row.SettingsFile
    $isEnabled = $row.Enabled -eq "TRUE"

    if ($isEnabled) {
        # Check if GPO exists
        $existingGPO = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue

        # Create GPO if it doesn't exist
        if ($null -eq $existingGPO) {
            try {
                New-GPO -Name $gpoName
                Log-Message -Message "Created GPO $gpoName"
            } catch {
                Log-Message -Message "Failed to create GPO $gpoName: $_"
                continue
            }
        } else {
            Log-Message -Message "GPO $gpoName already exists. Skipping creation."
        }

        # Link GPO
        try {
            # Check if already linked
            $existingLink = Get-GPLink -Target $linkedOU -ErrorAction SilentlyContinue | Where-Object {$_.GpoName -eq $gpoName}
            if ($null -eq $existingLink) {
                New-GPLink -Name $gpoName -Target $linkedOU
                Log-Message -Message "Linked GPO $gpoName to $linkedOU"
            } else {
                Log-Message -Message "GPO $gpoName is already linked to $linkedOU. Skipping linking."
            }
        } catch {
            Log-Message -Message "Failed to link GPO $gpoName to $linkedOU: $_"
        }

        # Import settings if specified
        if (-not [string]::IsNullOrEmpty($settingsFile)) {
            try {
                Import-GPO -Path $settingsFile -BackupId (Get-GPO -Name $gpoName).Id
                Log-Message -Message "Imported settings for $gpoName from $settingsFile"
            } catch {
                Log-Message -Message "Failed to import settings for $gpoName from $settingsFile: $_"
            }
        }
    } else {
        Log-Message -Message "GPO $gpoName is disabled. Skipping."
    }
}
