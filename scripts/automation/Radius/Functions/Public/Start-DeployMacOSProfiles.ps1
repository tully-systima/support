Function Start-DeployMacOSProfiles {
    [CmdletBinding(DefaultParameterSetName = 'gui')]
    param (
        # Type of profile deployment, All, New or byUsername
        [Parameter(HelpMessage = 'Type of deployment. To deploy all profiles, specify "all", To deploy only new profiles, specify "new". To deploy by username, specify "ByUsername" and populate the "username" parameter.', ParameterSetName = 'cli', Mandatory)]
        [ValidateSet("All", "New", "ByUsername")]
        [system.String]
        $type,
        # username
        [Parameter(HelpMessage = 'The JumpCloud username of an individual user', ParameterSetName = 'cli')]
        [System.String]
        $username,
        # Force overwrite existing policies
        [Parameter(HelpMessage = 'When specified, this parameter will replace existing policies', ParameterSetName = 'cli')]
        [switch]
        $forceReplace
    )

    # Get userArray or initialize
    $userArray = Get-UserJsonData

    Do {
        # Show menu in GUI mode
        if ($PSCmdlet.ParameterSetName -eq 'gui') {
            $title = ' JumpCloud macOS Profile Deployment '
            Clear-Host
            Write-Host $(PadCenter -string $Title -char '=')
            Write-Host $(PadCenter -string "Select an option below to deploy macOS profiles`n" -char ' ') -ForegroundColor Yellow

            # ==== instructions ====
            Write-Host $(PadCenter -string ' macOS Profile Deployment Options ' -char '-')
            # List options:
            Write-Host "1: Press '1' to deploy profiles for users who haven't had profiles deployed yet."
            Write-Host "2: Press '2' to deploy a profile for a specific username."
            Write-Host "3: Press '3' to deploy profiles for all users with macOS systems."
            Write-Host "E: Press 'E' to exit."

            Write-Host $(PadCenter -string "-" -char '-')
            $confirmation = Read-Host "Please make a selection"
        } else {
            # Map CLI parameters to menu options
            $confirmationMap = @{
                'New'        = '1';
                "ByUsername" = '2';
                'All'        = '3';
            }
            $confirmation = $confirmationMap[$type]
        }

        switch ($confirmation) {
            '1' {
                # Deploy profiles for users who don't have a deployed profile yet
                $usersToDeploy = $userArray | Where-Object {
                    ($_.mobileconfigKeys -and -not $_.policyAssociations) -and
                    ($_.systemAssociations.osFamily -contains 'Mac OS X')
                }

                if ($usersToDeploy.Count -eq 0) {
                    Write-Host "No users found with undeploy profiles" -ForegroundColor Yellow
                } else {
                    for ($i = 0; $i -lt $usersToDeploy.count; $i++) {
                        $result = Deploy-macOSProfiles -user $usersToDeploy[$i]
                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersToDeploy.count -ActionText "Deploying macOS Profiles" -previousOperationResult $result
                    }

                    if ($PSCmdlet.ParameterSetName -eq 'gui') {
                        Show-StatusMessage -Message "Finished Deploying macOS Profiles"
                    } else {
                        return
                    }
                }
            }
            '2' {
                # Deploy profile by username
                if ($PSCmdlet.ParameterSetName -eq 'gui') {
                    try {
                        Clear-Variable -Name "ConfirmUser" -ErrorAction Ignore
                    } catch {
                        New-Variable -Name "ConfirmUser" -Value $null
                    }
                    while (-not $confirmUser) {
                        $confirmationUser = Read-Host "Enter the Username of the user (or '@exit' to return to menu)"
                        if ($confirmationUser -eq '@exit') {
                            break
                        }
                        try {
                            $confirmUser = Test-UserFromHash -username $confirmationUser -debug
                        } catch {
                            Write-Warning "User specified $confirmationUser was not found within the Radius Server Membership Lists"
                        }
                    }
                } else {
                    $confirmUser = Test-UserFromHash -username $username -debug
                }

                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Check if the user has a generated profile
                    if (-not $userObject.mobileconfigKeys) {
                        Write-Host "$($userObject.username) has no generated profiles. Generate a profile first." -ForegroundColor Yellow
                    } else {
                        $deployOptions = @{}
                        if ($PSCmdlet.ParameterSetName -eq 'cli' -and $forceReplace) {
                            $deployOptions.forceReplace = $true
                        }

                        $result = Deploy-macOSProfiles -user $userObject @deployOptions
                        Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Deploying macOS Profile" -previousOperationResult $result
                    }
                }

                if ($PSCmdlet.ParameterSetName -eq 'gui') {
                    Show-StatusMessage -Message "Finished Deploying macOS Profiles"
                } else {
                    return
                }
            }
            '3' {
                # Deploy profiles for all users with generated profiles
                $usersToDeploy = $userArray | Where-Object {
                    $_.mobileconfigKeys -and
                    ($_.systemAssociations.osFamily -contains 'Mac OS X')
                }

                if ($usersToDeploy.Count -eq 0) {
                    Write-Host "No users found with generated profiles" -ForegroundColor Yellow
                } else {
                    if ($PSCmdlet.ParameterSetName -eq 'gui') {
                        $deployAllConfirm = Get-ResponsePrompt -message "Are you sure you want to deploy profiles for all users? This may replace existing policies."
                        if (-not $deployAllConfirm) {
                            return
                        }
                    }

                    $deployOptions = @{}
                    if ($PSCmdlet.ParameterSetName -eq 'cli' -and $forceReplace) {
                        $deployOptions.forceReplace = $true
                    }

                    for ($i = 0; $i -lt $usersToDeploy.count; $i++) {
                        $result = Deploy-macOSProfiles -user $usersToDeploy[$i] @deployOptions
                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersToDeploy.count -ActionText "Deploying macOS Profiles" -previousOperationResult $result
                    }

                    if ($PSCmdlet.ParameterSetName -eq 'gui') {
                        Show-StatusMessage -Message "Finished Deploying macOS Profiles"
                    } else {
                        return
                    }
                }
            }
            'E' {
                Write-Host "Returning to main menu"
            }
            default {
                Write-Host "Invalid Choice. Please try again"
            }
        }
    } while ($confirmation -ne 'E')

    # Save the updated user data back to users.json
    $userArray | ConvertTo-Json -Depth 6 | Out-File "$JCScriptRoot\users.json"
}
