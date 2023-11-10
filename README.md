# AutoConfigServer

## Overview
AutoConfigServer automates Windows Server 2022 setup using PowerShell, XML, and CSV.

## Features
- Active Directory setup.
- Network configuration (DNS, DHCP).
- Group Policy and Security Group management.
- User account automation.
- File synchronization with Work Folders.

## Status
:warning: In Development - some features are not fully functional.

## Installation & Usage
```powershell
# Add installation steps here


## Components
# PowerShell Scripts:

ADinstaller.ps1: Sets up the Active Directory environment.
BaseInstallation.ps1: Manages basic server configuration.
ChangeMachineName.ps1: Updates server name based on configuration.
CreateAndLinkGPO.ps1: Manages Group Policy Objects.
DNSSetup.ps1: Configures DNS server roles.
GroupPolicySetup.ps1: Applies GPO settings from CSV data.
MainOrchestrator.ps1: Central script coordinating the setup process.
OrganizationalUnitsSetup.ps1: Establishes Organizational Units in Active Directory.
SecurityGroupsSetup.ps1: Manages security group configurations.
TemplateUsersSetup.ps1: Automates user account creation.
WorkFoldersSetup.ps1: Sets up Work Folders for file synchronization.
Configuration Files:

CSV Files: Configure various aspects like DHCP, DNS, GPOs, security groups, and user account templates.
XML Files: Include settings for Firewall and Work Folders, as well as Password Policies.
ServerBase.csv: Central configuration file defining key server settings.
malbrukere.csv: (Norwegian for 'bad users') Potentially lists restricted or monitored user accounts.


## License

# Apache-2.0 License.

## Contributing
# Open for contributions following the project guidelines.
Please see CONTRIBUTING.md.

This README offers a detailed view of each component in your project, highlighting the modular and comprehensive nature of AutoConfigServer. You can further detail each section with specific installation steps, usage examples, or prerequisites as the project evolves.​
