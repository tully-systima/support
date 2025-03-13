function Start-GeneratemacOSProfiles {
    [CmdletBinding(DefaultParameterSetName = 'gui')]
    param (
        # Type of action to perform
        [Parameter(HelpMessage = 'Type of action to perform on profiles. Options: AllActionsAllUsers, GenerateAllUsers, UploadPoliciesAllUsers, AssociatePoliciesAllUsers, AllActionsSingleUser, GenerateSingleUser, UploadPoliciesSingleUser, AssociatePoliciesSingleUser', ParameterSetName = 'cli', Mandatory)]
        [ValidateSet("AllActionsAllUsers", "GenerateAllUsers", "UploadPoliciesAllUsers", "AssociatePoliciesAllUsers",
                     "AllActionsSingleUser", "GenerateSingleUser", "UploadPoliciesSingleUser", "AssociatePoliciesSingleUser")]
        [system.String]
        $Action,

        # username for single user operations
        [Parameter(HelpMessage = 'The JumpCloud username of an individual user', ParameterSetName = 'cli')]
        [System.String]
        $Username,

        # Force replace existing profiles
        [Parameter(HelpMessage = 'Force replace existing profiles without prompting', ParameterSetName = 'cli')]
        [switch]
        $ForceReplace
    )

    # Check if CA-Key is saved in env
    if ($env:certKeyPassword) {
        Write-Host "Found CA-Key password in env"
        # Check if the key.pem works with the password
        $foundKeyPem = Resolve-Path -Path "$JCScriptRoot/Cert/*key.pem"
        $checkKey = openssl rsa -in $foundKeyPem -check -passin pass:$($env:certKeyPassword) 2>&1
        if ($checkKey -match "RSA key ok") {
            Write-Debug "ENV CA-Key password works with the current key"
        } else {
            Write-Host "CA-Key password is incorrect"
            Get-CertKeyPass
        }
    } else {
        # Get CA-Key password
        Write-Host "CA-Key password not found in the ENV"
        Get-CertKeyPass
    }

    # Get userArray or initialize
    $userArray = Get-UserJsonData

    # Create UserProfiles directory if it doesn't exist
    if (Test-Path "$JCScriptRoot/UserProfiles") {
        Write-Host "[status] User Profiles Directory Exists"
    } else {
        Write-Host "[status] Creating User Profiles Directory"
        New-Item -ItemType Directory -Path "$JCScriptRoot/UserProfiles"
    }

    # Create JCRadiusCert directory if it doesn't exist
    if (-Not (Test-Path "$JCScriptRoot/JCRadiusCert")) {
        Write-Host "[status] Creating JC Radius Cert Directory"
        New-Item -ItemType Directory -Path "$JCScriptRoot/JCRadiusCert" -Force | Out-Null
    }

    # Download JumpCloud Radius Root CA Certificate if needed
    if (-Not (Test-Path -Path "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt")) {
        Write-Host "Downloading JumpCloud Radius Root CA Certificate..."
        $jcRadiusRootCA = Invoke-WebRequest -Uri "$JCRadiusCertURL" -OutFile "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt"
    }

    # Check if files required for profile generation exist
    if (-Not (Test-Path -Path "$JCScriptRoot/UserCerts")) {
        Throw "UserCerts directory not found, have you run Generate-UserCert.ps1?"
        exit 1
    }

    #### end function setup

    Do {
        switch ($PSCmdlet.ParameterSetName) {
            'gui' {
                Show-GeneratemacOSProfilesMenu
                $confirmation = Read-Host "Please make a selection"
            }
            'cli' {
                $confirmationMap = @{
                    'AllActionsAllUsers'          = '1';
                    'GenerateAllUsers'            = '2';
                    'UploadPoliciesAllUsers'      = '3';
                    'AssociatePoliciesAllUsers'   = '4';
                    'AllActionsSingleUser'        = '5';
                    'GenerateSingleUser'          = '6';
                    'UploadPoliciesSingleUser'    = '7';
                    'AssociatePoliciesSingleUser' = '8';
                }
                $confirmation = $confirmationMap[$Action]
            }
        }

        switch ($confirmation) {
            '1' {
                # Generate macOS Profiles, upload as JumpCloud policies, and associate to each users' macOS devices (All users)
                Write-Host "Generating macOS Profiles, uploading as JumpCloud policies, and associating to each users' macOS devices..." -ForegroundColor Cyan

                $usersWithMacOS = $userArray | Where-Object { $_.systemAssociations.osFamily -contains 'Mac OS X' }

                if ($usersWithMacOS.Count -eq 0) {
                    Write-Host "No users found with macOS systems" -ForegroundColor Yellow
                } else {
                    $overwriteExistingProfiles = $ForceReplace
                    if ($PSCmdlet.ParameterSetName -eq 'gui') {
                        $overwriteExistingProfiles = Get-ResponsePrompt -message "Are you sure you want to generate profiles for all users? This may replace existing profiles."
                    }

                    if ($overwriteExistingProfiles -or $PSCmdlet.ParameterSetName -eq 'cli') {
                        for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                            # Use Invoke-macOSProfileProcess for consistent processing
                            $result = Invoke-macOSProfileProcess -radiusMember $usersWithMacOS[$i] -certType $JCR_CERT_TYPE -Action 'All' -ForceReplace:$ForceReplace
                            Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Processing macOS Profiles" -previousOperationResult $result
                        }

                        Show-StatusMessage -Message "Finished generating profiles, uploading to JumpCloud, and associating policies"
                    }
                }
            }
            '2' {
                # Only generate macOS profiles for all users
                Write-Host "Generating macOS profiles for all users..." -ForegroundColor Cyan

                $usersWithMacOS = $userArray | Where-Object { $_.systemAssociations.osFamily -contains 'Mac OS X' }

                if ($usersWithMacOS.Count -eq 0) {
                    Write-Host "No users found with macOS systems" -ForegroundColor Yellow
                } else {
                    $overwriteExistingProfiles = $ForceReplace
                    if ($PSCmdlet.ParameterSetName -eq 'gui') {
                        $overwriteExistingProfiles = Get-ResponsePrompt -message "Are you sure you want to generate profiles for all users? This may replace existing profiles."
                    }

                    if ($overwriteExistingProfiles -or $PSCmdlet.ParameterSetName -eq 'cli') {
                        for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                            # Use Invoke-macOSProfileProcess with 'Generate' action
                            $result = Invoke-macOSProfileProcess -radiusMember $usersWithMacOS[$i] -certType $JCR_CERT_TYPE -Action 'Generate' -ForceReplace:$ForceReplace
                            Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Generating macOS Profiles" -previousOperationResult $result
                        }

                        Show-StatusMessage -Message "Finished generating macOS profiles for all users"
                    }
                }
            }
            '3' {
                # Only upload profiles to JumpCloud policies for all users
                Write-Host "Uploading profiles to JumpCloud policies for all users..." -ForegroundColor Cyan

                $usersWithMacOS = $userArray | Where-Object {
                    ($_.systemAssociations.osFamily -contains 'Mac OS X') -and
                    (Test-Path -Path "$JCScriptRoot/UserProfiles/$($_.username)-Radius-WiFi.mobileconfig")
                }

                if ($usersWithMacOS.Count -eq 0) {
                    Write-Host "No users found with macOS systems and existing profiles" -ForegroundColor Yellow
                } else {
                    for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                        # Use Invoke-macOSProfileProcess with 'Upload' action
                        $result = Invoke-macOSProfileProcess -radiusMember $usersWithMacOS[$i] -certType $JCR_CERT_TYPE -Action 'Upload'
                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Uploading profiles to JumpCloud" -previousOperationResult $result
                    }

                    Show-StatusMessage -Message "Finished uploading profiles to JumpCloud for all users"
                }
            }
            '4' {
                # Only update Policy Association to each users' macOS devices
                Write-Host "Updating Policy Association to each users' macOS devices..." -ForegroundColor Cyan

                $usersWithMacOS = $userArray | Where-Object {
                    ($_.systemAssociations.osFamily -contains 'Mac OS X') -and
                    ($_.macOSProfile.JCPolicyID -ne $null)
                }

                if ($usersWithMacOS.Count -eq 0) {
                    Write-Host "No users found with macOS systems and JumpCloud policies" -ForegroundColor Yellow
                } else {
                    for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                        # Use Invoke-macOSProfileProcess with 'Associate' action
                        $result = Invoke-macOSProfileProcess -radiusMember $usersWithMacOS[$i] -certType $JCR_CERT_TYPE -Action 'Associate'
                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Associating policies to devices" -previousOperationResult $result
                    }

                    Show-StatusMessage -Message "Finished updating policy associations for all users"
                }
            }
            '5' {
                # Generate macOS Profiles, upload as JumpCloud policies, and associate to a specific user's macOS device
                $confirmUser = $null
                if ($PSCmdlet.ParameterSetName -eq 'cli') {
                    $confirmUser = Test-UserFromHash -username $Username -debug
                } else {
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
                }

                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Use Invoke-macOSProfileProcess with 'All' action for the specific user
                    $result = Invoke-macOSProfileProcess -radiusMember $userObject -certType $JCR_CERT_TYPE -Action 'All' -ForceReplace:$ForceReplace -Prompt:($PSCmdlet.ParameterSetName -eq 'gui')
                    Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Processing macOS Profile" -previousOperationResult $result

                    Show-StatusMessage -Message "Finished processing macOS profile for $($userObject.username)"
                }
            }
            '6' {
                # Only generate macOS profiles for a specific user
                $confirmUser = $null
                if ($PSCmdlet.ParameterSetName -eq 'cli') {
                    $confirmUser = Test-UserFromHash -username $Username -debug
                } else {
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
                }

                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Use Invoke-macOSProfileProcess with 'Generate' action for the specific user
                    $result = Invoke-macOSProfileProcess -radiusMember $userObject -certType $JCR_CERT_TYPE -Action 'Generate' -ForceReplace:$ForceReplace -Prompt:($PSCmdlet.ParameterSetName -eq 'gui')
                    Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Generating macOS Profile" -previousOperationResult $result

                    Show-StatusMessage -Message "Finished generating macOS profile for $($userObject.username)"
                }
            }
            '7' {
                # Only upload profiles to JumpCloud policies for a specific user
                $confirmUser = $null
                if ($PSCmdlet.ParameterSetName -eq 'cli') {
                    $confirmUser = Test-UserFromHash -username $Username -debug
                } else {
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
                }

                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Use Invoke-macOSProfileProcess with 'Upload' action for the specific user
                    $result = Invoke-macOSProfileProcess -radiusMember $userObject -certType $JCR_CERT_TYPE -Action 'Upload'
                    Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Uploading macOS Profile" -previousOperationResult $result

                    Show-StatusMessage -Message "Finished uploading macOS profile for $($userObject.username)"
                }
            }
            '8' {
                # Only update Policy Association to a specific user's macOS device
                $confirmUser = $null
                if ($PSCmdlet.ParameterSetName -eq 'cli') {
                    $confirmUser = Test-UserFromHash -username $Username -debug
                } else {
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
                }

                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Use Invoke-macOSProfileProcess with 'Associate' action for the specific user
                    $result = Invoke-macOSProfileProcess -radiusMember $userObject -certType $JCR_CERT_TYPE -Action 'Associate'
                    Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Associating macOS Profile" -previousOperationResult $result

                    Show-StatusMessage -Message "Finished associating macOS profile for $($userObject.username)"
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

    # Update entry $user in users.json using the Set-UserJsonData function
    Set-UserJsonData -userArray $userObject
}
