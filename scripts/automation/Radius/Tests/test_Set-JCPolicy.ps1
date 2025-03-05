#!ps
$JCScriptRoot = Split-Path -Parent $PSScriptRoot

# Import the Config.ps1 file
. "$JCScriptRoot/Config.ps1"

# Connect to the designated JumpCloud organization
Connect-JCOnline -JumpCloudApiKey $JCAPIKEY -JumpCloudOrgId $JCORGID
Write-Host "[status] Organization: $($JCRConfig.OrganizationName)"

# Variables
Write-Host "[status] JCScriptRoot: `"$JCScriptRoot`""

# Get user objects from JCScriptRoot/users.json
$userObject = Get-Content -Path "$JCScriptRoot/users.json" | ConvertFrom-Json

        foreach ($user in $userObject) {
            Write-Host "[status] User: $($user.userName)"
            Write-Host "[status] systemAssociations: $($user.systemAssociations)"

            $userProfilePath = "$JCScriptRoot/UserProfiles/$($user.username).mobileconfig"
            $userPolicyName = $user.macOSProfile.profilePayloadDisplayName

            if (-Not (Test-Path -Path "$userProfilePath")) {
                Write-Host "[status] No mobileconfig files found for user $($user.userName). Please generate profiles first." -ForegroundColor Red
            } else {
                Write-Host "[status] Mobileconfig file found for user $($user.userName), proceeding with deployment..." -ForegroundColor Green

            # Check for existing JumpCloud macOS Radius Wifi Policies user:
            Write-Host "[status] Getting JumpCloud PolicyID for user $($user.userName)"
            $userPolicyID = $user.macOSProfile.JCPolicyID
            if ($userPolicyID) {
                Write-Host "[status] JumpCloud PolicyID found for user $($user.userName): $userPolicyID"
                $existingPolicy = Get-JCPolicy -ID $userPolicyID
            } else {
                Write-Host "[status] No JumpCloud PolicyID found in users.json for user $($user.userName), checking JumpCloud for matching policy name..."
                $existingPolicy = Get-JCPolicy -Name $userPolicyName
            }

            # Check if an existing JumpCloud policy exists for the user
            if ($existingPolicy) {
                Write-Host "[status] Existing policy found, updating: $($existingPolicy)"
                Set-JCPolicy -profileID $policy.id -Values "$profileBase64" -Notes "Profile updated on $(Get-Date)"
            } else {
                Write-Host "[status] No existing policy found, creating new policy..."
                New-JCPolicy -TemplateName "darwin_MDM_Custom_Configuration_Profile" -name $userPolicyName -payload "$($userProfilePath)" -Notes "Profile updated on $(Get-Date)"
            }

            # Get the updated policy ID
            $userPolicyID = Get-JCPolicy -Name $userPolicyName
            Write-Host "[status] JumpCloud PolicyID for user $($user.userName): $userPolicyID"
        }
    }
