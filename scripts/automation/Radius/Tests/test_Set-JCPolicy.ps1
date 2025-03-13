#!ps
$JCScriptRoot = Split-Path -Parent $PSScriptRoot

# Import the Config.ps1 file
. "$JCScriptRoot/Config.ps1"

# Import the Json functions
. "$JCScriptRoot/Functions/Private/UserJson/Get-UserJsonData.ps1"
. "$JCScriptRoot/Functions/Private/UserJson/Set-UserJsonData.ps1"

# Get the userObject
$userObject = Get-UserJsonData

# Connect to the designated JumpCloud organization
Connect-JCOnline -JumpCloudApiKey $JCAPIKEY -JumpCloudOrgId $JCORGID
Write-Host "[status] Organization: $($JCRConfig.OrganizationName)"

# Variables
Write-Host "[status] JCScriptRoot: `"$JCScriptRoot`""

        foreach ($user in $userObject) {
            Write-Host "[status] User: $($user.userName)"

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
                    $existingPolicy = $null
                }

                # Check if an existing JumpCloud policy exists for the user
                if ($existingPolicy) {
                    Write-Host "[status] Existing policy found, updating: $($existingPolicy.name)" -ForegroundColor Green
                    $policyResult = Set-JCPolicy -PolicyID ($existingPolicy.id) -NewName "$($userPolicyName)" -payload "$($userProfilePath)" -Notes "Profile updated on $(Get-Date)"
                } else {
                    Write-Host "[status] No existing policy found, creating new policy..." -ForegroundColor Blue
                    $policyResult = New-JCPolicy -TemplateName "darwin_MDM_Custom_Configuration_Profile" -Name "$($userPolicyName)" -payload "$($userProfilePath)" -Notes "Profile updated on $(Get-Date)"
                }

                # Get the policy ID from the created policy
                Write-Host "[status] JumpCloud PolicyID for user $($user.userName): $($policyResult.id)"
                # Update user object with policy ID
                if (-not $user.macOSProfile.PSObject.Properties.Name.Contains('JCPolicyID')) {
                    $user.macOSProfile | Add-Member -MemberType NoteProperty -Name JCPolicyID -Value $policyResult.id
                } else {
                    $user.macOSProfile.JCPolicyID = $policyResult.id
                }
            }

            # Get the system associations for this user
            $systemAssociations = Get-JCAssociation -Type:user -Id "$($user.userId)" -TargetType:system
            $macOSSystems = Get-JCSystem -SystemID "$($systemAssociations.targetId)" | Where-Object os -like *Mac*

            # Associate policy to user's macOS devices
            if ($user.macOSProfile.JCPolicyID) {
                Write-Host "[status] macOS systems associated with user $($user.userName):"
                Write-Host " - $($macOSSystems.displayName)"
                foreach ($macOSSystem in $macOSSystems) {
                    Write-Host "[status] Associating policy to $($macOSSystem.hostname)" -ForegroundColor Blue
                    Add-JCAssociation -Id "$($userPolicyID)" -Type:policy -TargetType:system -TargetId: "$($macOSSystem.id)" -Force
                }
            }

            # Update entry $user in users.json using the Set-UserJsonData function
            Set-UserJsonData -userArray $userObject
        }
