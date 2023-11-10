# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path "WorkFoldersSetup.log" -Value $Message
}

# Validate XML Configuration
Function Validate-XML {
    param (
        [string]$XMLPath
    )
    try {
        [xml]$xmlConfig = Get-Content -Path $XMLPath
        return $xmlConfig
    } catch {
        Log-Message -Message "Failed to read XML Configuration: $_"
        exit 1
    }
}

# Identify OU and Role (for demo purposes, replace with actual logic)
$OU = "PrimeAS"  # Replace with actual OU
$Role = "IT-Administrator"  # Replace with actual Role

# Validate OU and Role
if ([string]::IsNullOrEmpty($OU) -or [string]::IsNullOrEmpty($Role)) {
    Log-Message -Message "OU or Role is empty. Exiting."
    exit 1
}

# Read XML Configuration
[xml]$xmlConfig = Validate-XML -XMLPath "WorkFoldersSettings.xml"

# Get SyncShare based on OU
$SyncShare = ($xmlConfig.WorkFoldersSettings.SyncShare | Where-Object {$_.Condition -eq "OU=$OU"})."#text"
if ($null -eq $SyncShare) {
    Log-Message -Message "No SyncShare found for OU=$OU"
    exit 1
}

# Get FileSync based on Role
$FileSync = ($xmlConfig.WorkFoldersSettings.FileSync | Where-Object {$_.Condition -eq "Role=$Role"})."#text"
if ($null -eq $FileSync) {
    Log-Message -Message "No FileSync found for Role=$Role"
    exit 1
}

# Set up Work Folders
try {
    Log-Message -Message "Setting up Work Folders with SyncShare: $SyncShare"
    # Your code to set up Work Folders with $SyncShare
} catch {
    Log-Message -Message "Failed to set up Work Folders: $_"
    exit 1
}

# Set File Sync
try {
    Log-Message -Message "Setting File Sync: $FileSync"
    # Your code to set File Sync with $FileSync
} catch {
    Log-Message -Message "Failed to set File Sync: $_"
    exit 1
}
