# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path "error.log" -Value $logMessage
}

# Check for administrative privileges
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Log-Message -Message "You need to run this script as an Administrator."
    exit 1
}

# Check prerequisites
if ([Environment]::OSVersion.Version.Major -lt 10) {
    Log-Message -Message "Windows 10 or higher is required."
    exit 1
}

# Import configurations from ServerBase.csv
$csvPath = Join-Path $PSScriptRoot "config\ServerBase.csv"
if (-Not (Test-Path $csvPath)) {
    Log-Message -Message "CSV file not found at $csvPath. Exiting."
    exit 1
}

$serverConfig = Import-Csv -Path $csvPath | Select-Object -First 1
if ($null -eq $serverConfig) {
    Log-Message -Message "No configuration found in CSV. Exiting."
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
    Install-WindowsFeature -Name 'AD-Domain-Services' -IncludeManagementTools
    if ($LASTEXITCODE -ne 0) {
        Log-Message -Message "Failed to install AD Domain Services."
        exit 1
    }
    # Adding delay after installing the AD role
    Log-Message -Message "Waiting for 30 seconds to let the AD role installation complete."
    Start-Sleep -Seconds 30
}

# Verify role installation
$verifyRole = Get-WindowsFeature -Name 'AD-Domain-Services' | Where-Object {$_.InstallState -eq 'Installed'}
if ($null -eq $verifyRole) {
    Log-Message -Message "AD role installation verification failed."
    exit 1
}

# Adding delay after verifying the AD role
Log-Message -Message "Waiting for 15 seconds to let the system recognize the installed role."
Start-Sleep -Seconds 15

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
    # Adding delay before configuring the Domain Controller
    Log-Message -Message "Waiting for 15 seconds before configuring the Domain Controller."
    Start-Sleep -Seconds 15

    Install-ADDSDomainController `
        -DomainName $domainName `
        -SafeModeAdministratorPassword $securePassword
} catch {
    Log-Message -Message "Failed to install and configure Domain Controller: $_"
    exit 1
}

Log-Message -Message "AD installation completed successfully."
