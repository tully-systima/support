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
        $prompt,
        # Associate profiles to devices
        [Parameter(HelpMessage = 'When specified, profiles will be automatically associated to devices')]
        [switch]
        $associateProfiles
    )

    begin {
        $workToBeDone = [PSCustomObject]@{
            remainingMacOSDevices        = $null
            macOSProfileID               = $null
        }

        $status_profileGenerated = $false
        $result_profileDeployed = $false
        $deploySuccess = @()
        $deployErrors = @()

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
                    Write-Host "[status] No JumpCloud PolicyID found in users.json for user $($user.userName), checking JumpCloud for matching policy name..."
                    $existingPolicy = Get-JCPolicy -Name $userPolicyName
                }

                # Check if an existing JumpCloud policy exists for the user
                if ($existingPolicy) {
                    Write-Host "[status] Existing policy found, updating: $($existingPolicy)"
                    try {
                        Set-JCPolicy -profileID $existingPolicy.id -payload "$($userProfilePath)" -Notes "Profile updated on $(Get-Date)" | Out-Null
                        Write-Host "[success] Successfully updated policy for user $($user.userName)" -ForegroundColor Green
                        $deploySuccess += $user.userName
                    } catch {
                        Write-Host "[error] Failed to update policy for user $($user.userName): $($_.Exception.Message)" -ForegroundColor Red
                        $deployErrors += $user.userName
                    }
                } else {
                    Write-Host "[status] No existing policy found, creating new policy..."
                    try {
                        $userPolicyID = (New-JCPolicy -TemplateName "darwin_MDM_Custom_Configuration_Profile" -name $userPolicyName -payload "$($userProfilePath)" -Notes "Profile updated on $(Get-Date)").id
                        Write-Host "[success] Successfully created policy for user $($user.userName)" -ForegroundColor Green
                        $deploySuccess += $user.userName

                        # Get the updated policy ID
                        $existingPolicy = Get-JCPolicy -ID $userPolicyID
                        Write-Host "[status] JumpCloud PolicyID for user $($user.userName): $userPolicyID"
                    } catch {
                        Write-Host "[error] Failed to create policy for user $($user.userName): $($_.Exception.Message)" -ForegroundColor Red
                        $deployErrors += $user.userName
                    }
                }
            }
        }
    }

    end {
        Write-Host "[summary] Successfully deployed profiles for users: $($deploySuccess -join ', ')" -ForegroundColor Green
        if ($deployErrors.Count -gt 0) {
            Write-Host "[summary] Failed to deploy profiles for users: $($deployErrors -join ', ')" -ForegroundColor Red
        }
        return @{
            Success = $deploySuccess
            Errors = $deployErrors
        }
    }
}

function Associate-ProfileToSystems {
    param (
        [Parameter(HelpMessage = 'An individual or array of user objects from users.json', Mandatory)]
        [System.Object[]]
        $userObject,
        [Parameter(HelpMessage = 'An individual or array of system objects from systems.json', Mandatory)]
        [System.Object[]]
        $systemObject
    )
    try {
        foreach ($user in $userObject) {
            Write-Host "[status] User: $($user.userName)" -ForegroundColor Blue
            Write-Host "[status] systemAssociations: $($user.systemAssociations)" -ForegroundColor Blue
            foreach ($system in $user.systemAssociations) {
            }
        }
    }
}
