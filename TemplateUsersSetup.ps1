# Import required modules
Import-Module ActiveDirectory

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

# Function to create a template user if it doesn't exist
Function Create-TemplateUserIfNotExist {
    param(
        [string]$Username,
        [string]$OUPath,
        [string]$Password,
        [string]$LogPath
    )
    if (-Not $Username -or -Not $OUPath -or -Not $Password) {
        Log-Message -Message "Missing parameters. Username, OUPath, and Password are required." -LogPath $LogPath
        return
    }
    
    try {
        $userExists = Get-ADUser -Filter { SamAccountName -eq $Username } -SearchBase $OUPath -ErrorAction SilentlyContinue
        if ($null -eq $userExists) {
            $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            New-ADUser -SamAccountName $Username -UserPrincipalName "$Username@yourdomain.com" -Name $Username -GivenName $Username -Surname "Template" -Path $OUPath -AccountPassword $securePassword -Enabled $true
            Log-Message -Message "Created template user: $Username under $OUPath" -LogPath $LogPath
        } else {
            Log-Message -Message "Template user $Username already exists under $OUPath" -LogPath $LogPath
        }
    } catch {
        Log-Message -Message "An error occurred while creating template user: $_" -LogPath $LogPath
    }
}

# Initialize variables
$scriptDir = $PSScriptRoot
$logPath = Join-Path -Path $scriptDir -ChildPath "TemplateUsersSetup.log"
$csvPath = Join-Path -Path $scriptDir -ChildPath "TemplateUsersConfiguration.csv"

# Check for CSV file
if (-Not (Test-Path $csvPath)) {
    Log-Message -Message "CSV file not found. Exiting." -LogPath $logPath
    exit 1
}

# Load data from .csv
$csvData = Import-Csv -Path $csvPath -Delimiter ';'

# Loop through each row to create template users
foreach ($row in $csvData) {
    if ($row.TemplateUser -and $row.OUName) {
        Create-TemplateUserIfNotExist -Username $row.TemplateUser -OUPath $row.OUName -Password "DefaultPasswordHere" -LogPath $logPath
    } else {
        Log-Message -Message "Invalid row in CSV. Both TemplateUser and OUName are required." -LogPath $logPath
    }
}
