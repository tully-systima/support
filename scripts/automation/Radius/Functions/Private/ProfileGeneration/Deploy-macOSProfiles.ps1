function Deploy-macOSProfiles {
    [CmdletBinding()]
    param (
        # Input from users.json
        [Parameter(HelpMessage = 'An individual or array of user objects from users.json', Mandatory)]
        [System.Object[]]
        $userObject,
        # prompt assicate profiles to devices
        [Parameter(HelpMessage = 'When specified, the user will be prompted to associate policies to devices after they have been generated')]
        [switch]
        $prompt
    )

    begin {
        $workToBeDone = [PSCustomObject]@{
            remainingMacOSDevices        = $null
            macOSProfileID               = $null
        }

        $status_profileGenerated = $false
        $result_profileDeployed = $false

        switch ($prompt) {
            $true {
                $associateProfilesChoice = Get-ResponsePrompt -message "Would you like to associate policies to devices after they've been generated?"
                switch ($associateProfilesChoice) {
                    $true {
                        $associateProfiles = $true
                    }
                    $false {
                        $associateProfiles = $false
                    }
                }
            }
        }
    }

    process {
        foreach ($user in $userObject) {
            $userProfilePath = "$JCScriptRoot/UserProfiles/$($user.username).mobileconfig"
            if (-Not (Test-Path -Path "$userProfilePath")) {
                Write-Host "No mobileconfig files found for user $($user.userName). Please generate profiles first." -ForegroundColor Red
                return 1
            }

            # Get stored profile identifiers
            $profilePayloadIdentifier = $user.macOSProfile.profilePayloadIdentifier
            $profilePayloadUUID = $user.macOSProfile.profilePayloadUUID

            Write-Host "[status] User: $($user.userName)"
            Write-Host "[status] systemAssociations: $($user.systemAssociations)"

            # Get the JumpCloud PolicyID for this user:
            $userPolicyID = $user.macOSProfile.JCPolicyID

            # Encode the .mobileconfig file as a base64 string
            $profileBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($userProfilePath))

            # Check if an existing JumpCloud policy exists for the user
            $existingPolicy = Get-JCPolicy -ID $userPolicyID
            if ($existingPolicy) {
                Write-Host "[status] Existing policy found, updating: $($existingPolicy.id)"
                $policyCommand = Set-JCPolicy -profileID $policy.id -Values "$profileBase64" -Notes "Profile updated on $(Get-Date)"
            } else {
                Write-Host "[status] No existing policy found"
                $policyCommand = New-JCPolicy -TemplateID "darwin_MDM_Custom_Configuration_Profile" -name $profileName -Values "$profileBase64" -Notes "Profile updated on $(Get-Date)"
            }

            # Write the mobileconfig content to the user profile path
            Write-Host "[status] Writing mobileconfig content to file: `"$userProfilePath`""
            Set-Content -Path $userProfilePath -Value $mobileconfigContent
            Write-Host "[status] Mobileconfig file created for user $($user.userName)"
        }
    }

    end {
        return $deploySuccess
    }
}

function Deploy-ProfileToUser {
    param (
        [string]$username,
        [string]$profilePath,
        [array]$systems
    )
    try {
        # Read profile content
        $profileContent = [System.IO.File]::ReadAllBytes($profilePath)
        $encodedProfile = [Convert]::ToBase64String($profileContent)

        # Check for existing assigned policy
        $profileName = "$($user.username) - $($NETWORKSSID) Radius WIFI"
        $policy = Get-JCPolicy -Name $profileName

        if ($policy) {
            # If the policy exists, update existing policy
            $policyCommand = Set-JCPolicy -profileID $policy.id -Values "$profileBase64" -Notes "Profile updated on $(Get-Date)"
        } else {
            # Create new profile
            $policyCommand = New-JCPolicy -TemplateID "darwin_MDM_Custom_Configuration_Profile" -name $profileName -Values "$profileBase64" -Notes "Profile updated on $(Get-Date)"
        }
        # Apply profile to systems
        foreach ($system in $systems) {
            $policyCommand
            Write-Host "Deployed profile for $username to system $($system.hostname)" -ForegroundColor Green
        }
    } catch {
        Write-Error "Error deploying profile to systems: $($_.Exception.Message)"
    }
}
