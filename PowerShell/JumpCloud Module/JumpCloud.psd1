#
# Module manifest for module 'JumpCloud'
#
# Generated by: JumpCloud Solutions Architect Team
#
# Generated on: 8/1/2022
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'JumpCloud.psm1'

# Version number of this module.
ModuleVersion = '2.0.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '31c023d1-a901-48c4-90a3-082f91b31646'

# Author of this module
Author = 'JumpCloud Solutions Architect Team'

# Company or vendor of this module
CompanyName = 'JumpCloud'

# Copyright statement for this module
Copyright = '(c) JumpCloud. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell functions to manage a JumpCloud Directory-as-a-Service'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('JumpCloud.SDK.DirectoryInsights', 
               'JumpCloud.SDK.V1', 
               'JumpCloud.SDK.V2')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Add-JCAssociation', 'Add-JCCommandTarget', 
               'Add-JCRadiusReplyAttribute', 'Add-JCSystemGroupMember', 
               'Add-JCSystemUser', 'Add-JCUserGroupMember', 'Backup-JCOrganization', 
               'Connect-JCOnline', 'Copy-JCAssociation', 'Get-JCAssociation', 
               'Get-JCBackup', 'Get-JCCommand', 'Get-JCCommandResult', 
               'Get-JCCommandTarget', 'Get-JCEvent', 'Get-JCEventCount', 'Get-JCGroup', 
               'Get-JCOrganization', 'Get-JCPolicy', 'Get-JCPolicyResult', 
               'Get-JCPolicyTargetGroup', 'Get-JCPolicyTargetSystem', 
               'Get-JCRadiusReplyAttribute', 'Get-JCRadiusServer', 'Get-JCSystem', 
               'Get-JCSystemGroupMember', 'Get-JCSystemInsights', 'Get-JCSystemUser', 
               'Get-JCUser', 'Get-JCUserGroupMember', 'Import-JCCommand', 
               'Import-JCUsersFromCSV', 'Invoke-JCCommand', 'Invoke-JCDeployment', 
               'New-JCCommand', 'New-JCDeploymentTemplate', 'New-JCImportTemplate', 
               'New-JCRadiusServer', 'New-JCSystemGroup', 'New-JCUser', 
               'New-JCUserGroup', 'Remove-JCAssociation', 'Remove-JCCommand', 
               'Remove-JCCommandResult', 'Remove-JCCommandTarget', 
               'Remove-JCRadiusReplyAttribute', 'Remove-JCRadiusServer', 
               'Remove-JCSystem', 'Remove-JCSystemGroup', 
               'Remove-JCSystemGroupMember', 'Remove-JCSystemUser', 'Remove-JCUser', 
               'Remove-JCUserGroup', 'Remove-JCUserGroupMember', 
               'Send-JCPasswordReset', 'Set-JCCommand', 'Set-JCOrganization', 
               'Set-JCRadiusReplyAttribute', 'Set-JCRadiusServer', 
               'Set-JCSettingsFile', 'Set-JCSystem', 'Set-JCSystemUser', 'Set-JCUser', 
               'Set-JCUserGroupLDAP', 'Update-JCModule', 'Update-JCUsersFromCSV', 
               'Get-JCEvent', 'Get-JCEventCount'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = 'New-JCAssociation'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'JumpCloud','DaaS','Jump','Cloud','Directory'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/TheJumpCloud/support/blob/master/PowerShell/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/TheJumpCloud/support/wiki'

        # A URL to an icon representing this module.
        IconUri = 'https://avatars1.githubusercontent.com/u/4927461?s=200&v=4'

        # ReleaseNotes of this module
        ReleaseNotes = 'https://git.io/jc-pwsh-releasenotes'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/TheJumpCloud/support/wiki'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

