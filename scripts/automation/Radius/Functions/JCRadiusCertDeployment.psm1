# Load all functions from public and private folders
#TODO: why define both?
$Private = @( Get-ChildItem -Path "$JCScriptRoot/Functions/Private/*.ps1" -Recurse)
$Private = @( Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -Recurse)
Foreach ($Import in $Private) {
    Try {
        . $Import.FullName
    } Catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

$global:JCRConfig = Get-JCRSettingsFile

# Get global variables or update if necessary
Get-JCRGlobalVars
# Update Users Json if there's a change
Update-JCRUsersJson
