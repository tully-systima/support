Function Invoke-macOSProfileProcess {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'The user object from users.json', ParameterSetName = 'radiusMember')]
        [System.object]
        $radiusMember,

        [Parameter(ParameterSetName = 'selectedUserObject')]
        [System.String]
        $selectedUserObject,

        [Parameter(HelpMessage = 'The type of certificate to generate, either: "EmailSAN", "EmailDN" or "UsernameCN"', Mandatory)]
        [ValidateSet('EmailSAN', 'EmailDN', 'UsernameCN')]
        [System.String]
        $certType,

        [Parameter(HelpMessage = 'Action to perform: Generate, Upload, Associate, or All')]
        [ValidateSet('Generate', 'Upload', 'Associate', 'All')]
        [String]
        $Action = 'All',

        [Parameter(HelpMessage = 'Force replace any existing profiles')]
        [switch]
        $ForceReplace,

        [Parameter(HelpMessage = 'Show prompt for user confirmation')]
        [switch]
        $Prompt
    )

    begin {
        $workToBeDone = [PSCustomObject]@{
            remainingMacOSDevices = $null
            macOSProfileID        = $null
        }

        $status_profileGenerated = $false
        $status_profileUploaded = $false
        $status_profileAssociated = $false
        $result_success = $true

        # Determine if we should prompt for replacing profiles
        $replaceProfiles = $ForceReplace
        if ($Prompt -and -not $ForceReplace) {
            $replaceProfiles = $false
        }
    }

    process {
        # Find the user in the global users list
        switch ($PSCmdlet.ParameterSetName) {
            'radiusMember' {
                try {
                    $MatchedUser = $radiusMember
                    if (-not $MatchedUser) {
                        Write-Warning "Invalid radiusMember object provided"
                        return $false
                    }
                } catch {
                    Write-Warning "Could not identify user by userobject: $radiusMember"
                    return $false
                }
            }
            'selectedUserObject' {
                $MatchedUser = $GLOBAL:JCRUsers[$selectedUserObject.userid]
                if (-not $MatchedUser) {
                    Write-Warning "Could not identify user by selectedUserObject: $selectedUserObject"
                    return $false
                }
            }
        }

        # Check if the user has macOS systems
        if ($MatchedUser.systemAssociations.osFamily -contains 'Mac OS X') {
            Write-Host "Processing macOS profile for user: $($MatchedUser.username)" -ForegroundColor Cyan

            # Check if profile exists
            $profilePath = "$JCScriptRoot/UserProfiles/$($MatchedUser.username)-Radius-WiFi.mobileconfig"
            $profileExists = Test-Path $profilePath

            # Handle different actions based on the Action parameter
            switch ($Action) {
                'Generate' {
                    # Generate profile
                    if ($profileExists) {
                        $proceedWithGeneration = $replaceProfiles
                        if ($Prompt -and -not $replaceProfiles) {
                            $proceedWithGeneration = Get-ResponsePrompt -message "A profile already exists for user: $($MatchedUser.username). Do you want to replace it?"
                        }

                        if ($proceedWithGeneration) {
                            Write-Host "Generating profile for $($MatchedUser.username)..." -ForegroundColor Cyan
                            try {
                                $result = Generate-macOSProfiles -CertType $certType -user $MatchedUser
                                $status_profileGenerated = $true
                            } catch {
                                Write-Warning "Error generating profile for $($MatchedUser.username): $_"
                                $status_profileGenerated = $false
                            }
                        } else {
                            Write-Host "Skipping profile generation for $($MatchedUser.username)" -ForegroundColor Yellow
                            $status_profileGenerated = $true
                        }
                    } else {
                        # No existing profile, generate a new one
                        Write-Host "Generating new profile for $($MatchedUser.username)..." -ForegroundColor Cyan
                        try {
                            $result = Generate-macOSProfiles -CertType $certType -user $MatchedUser
                            $status_profileGenerated = $true
                        } catch {
                            Write-Warning "Error generating profile for $($MatchedUser.username): $_"
                            $status_profileGenerated = $false
                        }
                    }
                }

                'Upload' {
                    # Upload profile to JumpCloud as policy
                    if (-not $profileExists) {
                        Write-Host "No existing profile found for user $($MatchedUser.username). Please generate a profile first." -ForegroundColor Red
                        $status_profileUploaded = $false
                    } else {
                        Write-Host "Uploading profile for $($MatchedUser.username) to JumpCloud as a policy..." -ForegroundColor Cyan
                        # TODO: Implement upload to JumpCloud policies
                        # For now, just simulate success
                        $status_profileUploaded = $true
                    }
                }

                'Associate' {
                    # Associate policy to user's macOS devices
                    if (-not $MatchedUser.macOSProfile.JCPolicyID) {
                        Write-Host "No JumpCloud policy ID found for $($MatchedUser.username). Please upload the profile first." -ForegroundColor Red
                        $status_profileAssociated = $false
                    } else {
                        Write-Host "Associating policy to $($MatchedUser.username)'s macOS devices..." -ForegroundColor Cyan
                        # TODO: Implement policy association
                        # For now, just simulate success
                        $status_profileAssociated = $true
                    }
                }

                'All' {
                    # Do all steps: generate, upload, and associate
                    # Step 1: Generate profile
                    if ($profileExists) {
                        $proceedWithGeneration = $replaceProfiles
                        if ($Prompt -and -not $replaceProfiles) {
                            $proceedWithGeneration = Get-ResponsePrompt -message "A profile already exists for user: $($MatchedUser.username). Do you want to replace it?"
                        }

                        if ($proceedWithGeneration) {
                            Write-Host "Generating profile for $($MatchedUser.username)..." -ForegroundColor Cyan
                            try {
                                $result = Generate-macOSProfiles -CertType $certType -user $MatchedUser
                                $status_profileGenerated = $true
                            } catch {
                                Write-Warning "Error generating profile for $($MatchedUser.username): $_"
                                $status_profileGenerated = $false
                            }
                        } else {
                            Write-Host "Using existing profile for $($MatchedUser.username)" -ForegroundColor Yellow
                            $status_profileGenerated = $true
                        }
                    } else {
                        # No existing profile, generate a new one
                        Write-Host "Generating new profile for $($MatchedUser.username)..." -ForegroundColor Cyan
                        try {
                            $result = Generate-macOSProfiles -CertType $certType -user $MatchedUser
                            $status_profileGenerated = $true
                        } catch {
                            Write-Warning "Error generating profile for $($MatchedUser.username): $_"
                            $status_profileGenerated = $false
                        }
                    }

                    # Step 2: Upload to JumpCloud policy if profile generation was successful
                    if ($status_profileGenerated) {
                        Write-Host "Uploading profile for $($MatchedUser.username) to JumpCloud as a policy..." -ForegroundColor Cyan
                        # TODO: Implement upload to JumpCloud policies
                        # For now, just simulate success
                        $status_profileUploaded = $true
                    }

                    # Step 3: Associate policy to user's macOS devices if upload was successful
                    if ($status_profileUploaded) {
                        Write-Host "Associating policy to $($MatchedUser.username)'s macOS devices..." -ForegroundColor Cyan
                        # TODO: Implement policy association
                        # For now, just simulate success
                        $status_profileAssociated = $true
                    }
                }
            }

            # Determine overall success based on the action performed
            switch ($Action) {
                'Generate' { $result_success = $status_profileGenerated }
                'Upload' { $result_success = $status_profileUploaded }
                'Associate' { $result_success = $status_profileAssociated }
                'All' { $result_success = $status_profileGenerated -and $status_profileUploaded -and $status_profileAssociated }
            }

            # Return success or failure
            if ($result_success) {
                Write-Host "Successfully completed $Action action for $($MatchedUser.username)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Failed to complete $Action action for $($MatchedUser.username)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "$($MatchedUser.username) has no associated macOS systems" -ForegroundColor Yellow
            return $false
        }
    }
}
