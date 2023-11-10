# Main Orchestrator Script

# Function to validate that the CSV file exists
Function Validate-CSVFile {
    param (
        [string]$Path
    )
    $FullPath = Join-Path $PSScriptRoot "config\$Path"
    if (-not (Test-Path -Path $FullPath -PathType Leaf)) {
        Write-Host "Warning: CSV file does not exist at path $FullPath. Skipping step."
        Add-Content -Path (Join-Path $PSScriptRoot "MainOrchestrator.log") -Value "Warning: CSV file does not exist at path $FullPath. Skipping step."
        return $false
    }
    return $true
}

Function Execute-Step {
    param (
        [string]$ScriptName,
        [string]$ConfigFile,
        [int]$Retries = 5
    )
    
    $success = $false
    $ScriptFullPath = Join-Path $PSScriptRoot $ScriptName
    $ConfigFullPath = Join-Path $PSScriptRoot "config\$ConfigFile"
    
    for ($i=1; $i -le $Retries; $i++) {
        & $ScriptFullPath -ConfigFile $ConfigFullPath  # Use the full path
        if ($?) {
            $success = $true
            break
        }
        Write-Host "Attempt $i failed for $ScriptFullPath. Retrying..."
        Add-Content -Path (Join-Path $PSScriptRoot "MainOrchestrator.log") -Value "Attempt $i failed for $ScriptFullPath. Retrying..."
        Start-Sleep -Seconds 5
    }
    
    if (-not $success) {
        Write-Host "Failed to execute $ScriptFullPath after $Retries attempts."
        Add-Content -Path (Join-Path $PSScriptRoot "MainOrchestrator.log") -Value "Failed to execute $ScriptFullPath after $Retries attempts."
    }
}

# Initialize log file
Set-Content -Path (Join-Path $PSScriptRoot "MainOrchestrator.log") -Value "MainOrchestrator script started on $(Get-Date)"

# Steps
if (Validate-CSVFile -Path "ServerBase.csv") {
    Execute-Step -ScriptName "ChangeMachineName.ps1" -ConfigFile "ServerBase.csv"
    Execute-Step -ScriptName "BaseInstallation.ps1" -ConfigFile "ServerBase.csv"
}
if (Validate-CSVFile -Path "ADConfiguration.csv") {
    Execute-Step -ScriptName "ActiveDirectorySetup.ps1" -ConfigFile "ADConfiguration.csv"
}
if (Validate-CSVFile -Path "OUConfiguration.csv") {
    Execute-Step -ScriptName "OrganizationalUnitsSetup.ps1" -ConfigFile "OUConfiguration.csv"
}
if (Validate-CSVFile -Path "SecurityGroupsConfiguration.csv") {
    Execute-Step -ScriptName "SecurityGroupsSetup.ps1" -ConfigFile "SecurityGroupsConfiguration.csv"
}
if (Validate-CSVFile -Path "TemplateUsersConfiguration.csv") {
    Execute-Step -ScriptName "TemplateUsersSetup.ps1" -ConfigFile "TemplateUsersConfiguration.csv"
}
if (Validate-CSVFile -Path "WorkFoldersConfiguration.csv") {
    Execute-Step -ScriptName "WorkFoldersSetup.ps1" -ConfigFile "WorkFoldersConfiguration.csv"
}
if (Validate-CSVFile -Path "DNSConfiguration.csv") {
    Execute-Step -ScriptName "DNSSetup.ps1" -ConfigFile "DNSConfiguration.csv"
}
if (Validate-CSVFile -Path "GPOConfiguration.csv") {
    Execute-Step -ScriptName "GroupPolicySetup.ps1" -ConfigFile "GPOConfiguration.csv"
}

Write-Host "All steps completed. Check MainOrchestrator.log for details."
