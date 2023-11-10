# Import the ActiveDirectory module
Import-Module ActiveDirectory -ErrorAction Stop

# Function to log messages
Function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message"
}

# Search for the CSV file in the current directory and subdirectories
$csvFile = Get-ChildItem -Recurse -Filter "*.csv" | Select-Object -First 1

if ($null -eq $csvFile) {
    Log-Message -Message "CSV file not found. Exiting."
    exit 1
}

# Import data from the found CSV file
$csvData = Import-Csv -Path $csvFile.FullName

foreach ($row in $csvData) {
    $OUName = $row.OUName
    $SecurityGroupName = $row.SecurityGroupName
    
    # Check if OU exists
    $ouExists = Get-ADOrganizationalUnit -Filter {Name -eq $OUName} -ErrorAction SilentlyContinue
    
    if ($ouExists) {
        Log-Message -Message "OU $OUName exists. Proceeding with Security Group creation."
        
        # Check if Security Group exists within the OU
        $sgExists = Get-ADGroup -Filter {Name -eq $SecurityGroupName} -SearchBase $ouExists.DistinguishedName -ErrorAction SilentlyContinue

        if (!$sgExists) {
            # Create the Security Group
            New-ADGroup -Name $SecurityGroupName -Path $ouExists.DistinguishedName -GroupScope Global
            Log-Message -Message "Created Security Group: $SecurityGroupName under $OUName"
        } else {
            Log-Message -Message "Security Group $SecurityGroupName already exists under $OUName."
        }
    } else {
        Log-Message -Message "OU $OUName does not exist. Skipping row."
    }
}
