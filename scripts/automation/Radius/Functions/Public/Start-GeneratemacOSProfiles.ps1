function Start-GeneratemacOSProfiles {
    [CmdletBinding(DefaultParameterSetName = 'gui')]
    param (
        # Type of profiles to generate, All, New or byUsername
        [Parameter(HelpMessage = 'Type of profile to generate. To generate all new profiles for existing users, specify "all", To generate profiles for users who have not yet had profiles generated, specify "new". To generate profiles by an individual, speficy "ByUsername" and populate the "username" parameter.', ParameterSetName = 'cli', Mandatory)]
        [ValidateSet("All", "New", "ByUsername")]
        [system.String]
        $type,
        # username
        [Parameter(HelpMessage = 'The JumpCloud username of an individual user', ParameterSetName = 'cli')]
        [System.String]
        $username,
        # Force overwrite existing profiles
        [Parameter(HelpMessage = 'When specified, this parameter will replace profiles if they already exist on the filesystem', ParameterSetName = 'cli')]
        [switch]
        $forceReplaceProfiles
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
                Show-macOSProfileMenu
                $confirmation = Read-Host "Please make a selection"
            }
            'cli' {
                $confirmationMap = @{
                    'New'        = '1';
                    "ByUsername" = '2';
                    'All'        = '3';
                }
                $confirmation = $confirmationMap[$type]
                # if force replace is set, replace profiles:
                switch ($forceReplaceProfiles) {
                    $true {
                        $replaceProfiles = $true
                    }
                    $false {
                        $replaceProfiles = $false
                    }
                }
            }
        }

        switch ($confirmation) {
            '1' {
                # Generate profiles for users who don't have a profile yet
                $usersWithoutProfiles = $userArray | Where-Object {
                    (-Not (Test-Path -Path "$JCScriptRoot/UserProfiles/$($_.username)-Radius-WiFi.mobileconfig")) -and
                    ($_.systemAssociations.osFamily -contains 'Mac OS X')
                }

                if ($usersWithoutProfiles.Count -eq 0) {
                    Write-Host "No users found without existing profiles" -ForegroundColor Yellow
                } else {
                    for ($i = 0; $i -lt $usersWithoutProfiles.count; $i++) {
                        $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $usersWithoutProfiles[$i]
                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithoutProfiles.count -ActionText "Generating macOS Profiles" -previousOperationResult $result
                    }

                    switch ($PSCmdlet.ParameterSetName) {
                        'gui' {
                            Show-StatusMessage -Message "Finished Generating macOS Profiles"
                        }
                        'cli' {
                            return
                        }
                    }
                }
            }
            '2' {
                switch ($PSCmdlet.ParameterSetName) {
                    'gui' {
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
                    'cli' {
                        $confirmUser = Test-UserFromHash -username $username -debug
                    }
                }
                if ($confirmUser) {
                    # Get the userobject + index from users.json
                    $userObject, $userIndex = Get-UserFromTable -userID $confirmUser.id

                    # Check if the user has macOS systems
                    if ($userObject.systemAssociations.osFamily -contains 'Mac OS X') {
                        $profilePath = "$JCScriptRoot/UserProfiles/$($userObject.username)-Radius-WiFi.mobileconfig"
                        $profileExists = Test-Path -Path $profilePath

                        switch ($replaceProfiles) {
                            $true {
                                $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $userObject
                            }
                            $false {
                                if ($profileExists -and $PSCmdlet.ParameterSetName -eq 'gui') {
                                    $replaceChoice = Get-ResponsePrompt -message "Profile already exists for $($userObject.username). Would you like to replace it?"
                                    if ($replaceChoice) {
                                        $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $userObject
                                    } else {
                                        Write-Host "Skipping profile generation for $($userObject.username)" -ForegroundColor Yellow
                                        $result = $true
                                    }
                                } else {
                                    $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $userObject
                                }
                            }
                        }

                        Show-RadiusProgress -completedItems 1 -totalItems 1 -ActionText "Generating macOS Profile" -previousOperationResult $result
                    } else {
                        Write-Host "$($userObject.username) has no associated macOS systems" -ForegroundColor Yellow
                    }
                }

                switch ($PSCmdlet.ParameterSetName) {
                    'gui' {
                        Show-StatusMessage -Message "Finished Generating macOS Profiles"
                    }
                    'cli' {
                        return
                    }
                }
            }
            '3' {
                # Generate profiles for all users with macOS systems
                $usersWithMacOS = $userArray | Where-Object { $_.systemAssociations.osFamily -contains 'Mac OS X' }

                if ($usersWithMacOS.Count -eq 0) {
                    Write-Host "No users found with macOS systems" -ForegroundColor Yellow
                } else {
                    switch ($PSCmdlet.ParameterSetName) {
                        'gui' {
                            $overwriteExistingProfiles = Get-ResponsePrompt -message "Are you sure you want to generate profiles for all users? This may replace existing profiles."
                            switch ($overwriteExistingProfiles) {
                                $true {
                                    for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                                        $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $usersWithMacOS[$i]
                                        Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Generating macOS Profiles" -previousOperationResult $result
                                    }
                                }
                                $false {
                                    return
                                }
                                'exit' {
                                    return
                                }
                            }
                        }
                        'cli' {
                            for ($i = 0; $i -lt $usersWithMacOS.count; $i++) {
                                $result = Generate-macOSProfiles -CertType $JCR_CERT_TYPE -user $usersWithMacOS[$i]
                                Show-RadiusProgress -completedItems ($i + 1) -totalItems $usersWithMacOS.count -ActionText "Generating macOS Profiles" -previousOperationResult $result
                            }
                        }
                    }

                    switch ($PSCmdlet.ParameterSetName) {
                        'gui' {
                            Show-StatusMessage -Message "Finished Generating macOS Profiles"
                        }
                        'cli' {
                            return
                        }
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
