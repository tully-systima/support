function Get-JCRGlobalVars {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "Force update all cached users, systems, associations, radius group members")]
        [switch]
        $force,
        [Parameter(HelpMessage = "Skips the user to system association cache, which may take a long time on larger organizations")]
        [switch]
        $skipAssociation,
        [Parameter(HelpMessage = "Updates the system to user association cache manually using the graph api")]
        [switch]
        $associateManually,
        [Parameter(HelpMessage = "Updates just a single user's associations manually using the graph api")]
        [System.String]
        $associationUsername
    )
    begin {
        # ensure the data directory exists to cache the json files:
        if (-not (Test-Path "$JCScriptRoot/data")) {
            Write-Host "[status] Creating Data Directory"
            New-Item -ItemType Directory -Path "$JCScriptRoot/data"
        }

        if (-Not $global:JCRConfig) {
            $global:JCRConfig = Get-JCRSettingsFile
        }

        # get settings file
        if ($IsMacOS) {
            $lastUpdateTimespan = New-TimeSpan -Start $global:JCRConfig.globalvars.lastupdate -end (Get-Date)
        }
        if ($ifWindows) {
            $lastUpdateTimespan = New-TimeSpan -Start $global:JCRConfig.globalvars.lastupdate.value -end (Get-Date)
        }
        if ($lastUpdateTimespan.TotalHours -gt 24) {
            $update = $true
            $updateAssociation = $true
        } else {
            $update = $false
            $updateAssociation = $false
        }
        if ($force) {
            $update = $true
            switch ($skipAssociation) {
                $true {
                    $updateAssociation = $false
                }
                $false {
                    $updateAssociation = $true
                }
            }
            switch ($associateManually) {
                $true {
                    $updateAssociation = $false
                    $setAssociations = $true
                }
                $false {
                    $updateAssociation = $true
                    $setAssociations = $false
                }
            }
        }

        # also validate that the data files are non-null, if they are, force update]
        $requiredHashFiles = @('radiusMembers.json', 'systemHash.json', 'userHash.json')
        foreach ($file in $requiredHashFiles) {
            if (Test-Path -Path "$JCScriptRoot/data/$file") {
                $fileContents = Get-Content "$JCScriptRoot/data/$file"
            } else {
                Write-Host "[status] $JCScriptRoot/data/$file file does not exist, updating global variables"
                $update = $true
            }
            # if the file is null force update
            if ([string]::IsNullOrEmpty($fileContents)) {
                Write-Host "[status] $JCScriptRoot/data/$file file is null, updating global variables"
                $update = $true
            }
        }

        $requiredAssociationHashFiles = @('associationHash.json')
        foreach ($file in $requiredAssociationHashFiles) {
            if (Test-Path -Path "$JCScriptRoot/data/$file") {
                $fileContents = Get-Content "$JCScriptRoot/data/$file"
                switch ($skipAssociation) {
                    $true {
                        # Write-Host "[status] $JCScriptRoot/data/$file will be skipped"
                        $updateAssociation = $false
                    }
                }
            } else {
                Write-Host "[status] $JCScriptRoot/data/$file file does not exist, updating global variables"
                $update = $true
                $updateAssociation = $true
            }
            # if the file is null force update
            if ([string]::IsNullOrEmpty($fileContents)) {
                Write-Host "[status] $JCScriptRoot/data/$file file is null, updating global variables"
                $update = $true
                $updateAssociation = $true
            } else {
                switch ($skipAssociation) {
                    $true {
                        # Write-Host "[status] $JCScriptRoot/data/$file will be skipped"
                        $updateAssociation = $false
                    }
                }
            }
        }
    }
    process {
        switch ($update) {
            $true {
                # update the global variables
                $systems = Get-DynamicHash -Object System -returnProperties hostname, os, osFamily, version, fde, lastContact
                $users = Get-DynamicHash -Object User -returnProperties email, employeeIdentifier, department, suspended, location, Addresses, manager, sudo, Displayname, username, systemUsername
                # $users | ForEach-Object { $_ | Add-Member -name "userId" -value $_ -Type NoteProperty -force }
                # Get Radius membership list:
                $radiusMembers = Get-JcSdkUserGroupMember -GroupId $Global:JCR_USER_GROUP
                # add the username to the membership hash
                $radiusMemberList = New-Object System.Collections.ArrayList
                foreach ($member in $radiusMembers) {
                    $radiusMemberList.Add(
                        [PSCustomObject]@{
                            'userID'   = $member.toID
                            'username' = $users[$member.toID].username
                        }
                    ) | Out-Null
                }
                if ($updateAssociation) {
                    # Get Report Hash:
                    $headers = @{
                        "accept"    = "application/json";
                        "x-api-key" = $Env:JCApiKey;
                        "x-org-id"  = $Env:JCOrgId
                    }
                    # request new user to device report:
                    $reportRequest = Invoke-RestMethod -Uri 'https://api.jumpcloud.com/insights/directory/v1/reports/users-to-devices' -Method POST -Headers $headers
                    # now fetch available reports:
                    do {
                        $reportList = Invoke-RestMethod -Uri 'https://api.jumpcloud.com/insights/directory/v1/reports?sort=CREATED_AT' -Method GET -Headers $headers
                        $lastReport = $reportList | Where-Object { $_.id -eq $reportRequest.id }
                        if ($lastReport.status -eq 'PENDING') {
                            Write-Warning "[status] waiting 20s for jumpcloud report to complete"
                            start-sleep -Seconds 20
                        }
                    } until ($lastReport.status -eq 'COMPLETED')
                    # download json
                    $artifactID = ($lastReport.artifacts | Where-Object { $_.format -eq 'json' }).id
                    $reportID = $lastReport.id
                    $reportContent = Invoke-RestMethod -Uri "https://api.jumpcloud.com/insights/directory/v1/reports/$reportID/artifacts/$artifactID/content" -Method GET -Headers $headers
                    # create the hashtable:
                    $userAssociationList = New-Object System.Collections.Hashtable
                    foreach ($item in $reportContent) {
                        if ($item.user_object_id -And $item.resource_object_id) {
                            if (-not $userAssociationList[$item.user_object_id]) {
                                $userAssociationList.add(
                                    $item.user_object_id, @{
                                        'systemAssociations' = @($item | Select-Object -Property @{Name = 'systemId'; Expression = { $_.resource_object_id } }, hostname, @{Name = 'osFamily'; Expression = { $_.device_os } });
                                        'userData'           = @($item | Select-Object -Property email, username)
                                    }) | Out-Null
                            } else {
                                $userAssociationList[$item.user_object_id].systemAssociations += @($item | Select-Object -Property @{Name = 'systemId'; Expression = { $_.resource_object_id } }, hostname, @{Name = 'osFamily'; Expression = { $_.device_os } })
                            }
                        }
                    }
                    # write out the association hash
                    $userAssociationList | ConvertTo-Json -Depth 10 |  Out-File "$JCScriptRoot/data/associationHash.json"
                } else {
                    $userAssociationList = Get-Content -Raw -Path "$JCScriptRoot/data/associationHash.json" | ConvertFrom-Json -Depth 6 -AsHashtable

                }
                if ($setAssociations) {
                    # create the hashtable:
                    $userAssociationList = New-Object System.Collections.Hashtable
                    foreach ($user in $radiusMemberList) {
                        $userSystemMembership = Get-JcSdkUserTraverseSystem -UserId $user.userID
                        if ($userSystemMembership) {
                            $userAssociationList.add(
                                $user.userID, @{
                                    'systemAssociations' = @($userSystemMembership | Select-Object -Property @{Name = 'systemId'; Expression = { $_.id } }, @{Name = 'hostname'; Expression = { $systems[$_.id].hostname } }, @{Name = 'osFamily'; Expression = {
                                                $osFamilyValue = $systems[$_.id].osFamily
                                                if ($osFamilyValue -eq 'darwin') {
                                                    "macOS"
                                                } elseif ($osFamilyValue -eq 'Windows') {
                                                    "Windows"
                                                } else {
                                                    $osFamilyValue
                                                }
                                            }
                                        });
                                    'userData'           = @($user | Select-Object -Property @{Name = 'email'; Expression = { $users[$user.userID].email } }, @{Name = 'username'; Expression = { $users[$user.userID].username } })
                                }) | Out-Null
                        }

                    }
                    # write out the association hash
                    $userAssociationList | ConvertTo-Json -Depth 10 |  Out-File "$JCScriptRoot/data/associationHash.json"
                }
                if ($associationUsername) {
                    $userAssociationList = Get-Content -Raw -Path "$JCScriptRoot/data/associationHash.json" | ConvertFrom-Json -Depth 6 -AsHashtable
                    $matchedUser = $radiusMemberList | Where-Object { $_.username -eq $associationUsername }
                    if (-Not $matchedUser) {
                        Write-Warning "user not found"
                    } else {
                        $userSystemMembership = Get-JcSdkUserTraverseSystem -UserId $matchedUser.userID
                        if ($userSystemMembership) {
                            # check if the user exists
                            if ($userAssociationList[$matchedUser.userID]) {
                                $userAssociationList[$matchedUser.userID].'systemAssociations' = @($userSystemMembership | Select-Object -Property @{Name = 'systemId'; Expression = { $_.id } }, @{Name = 'hostname'; Expression = { $systems[$_.id].hostname } }, @{Name = 'osFamily'; Expression = {
                                            $osFamilyValue = $systems[$_.id].osFamily
                                            if ($osFamilyValue -eq 'darwin') {
                                                "macOS"
                                            } elseif ($osFamilyValue -eq 'Windows') {
                                                "Windows"
                                            } else {
                                                $osFamilyValue
                                            }
                                        }
                                    });
                            }
                        }
                        #
                    }
                    # write out the association hash
                    $userAssociationList | ConvertTo-Json -Depth 10 |  Out-File "$JCScriptRoot/data/associationHash.json"
                }
                # finally write out the data to file:
                $users | ConvertTo-Json -Depth 100 -Compress |  Out-File "$JCScriptRoot/data/userHash.json"
                $systems | ConvertTo-Json -Depth 10 |  Out-File "$JCScriptRoot/data/systemHash.json"
                $radiusMemberList | ConvertTo-Json |  Out-File "$JCScriptRoot/data/radiusMembers.json"
            }
            $false {
                # write-host "It's been $($lastUpdateTimespan.hours) hours since we last pulled user, system and association data, no need to update"
                $userAssociationList = Get-Content -Raw -Path "$JCScriptRoot/data/associationHash.json" | ConvertFrom-Json -Depth 6 -AsHashtable
            }
        }
    }
    end {
        switch ($update) {
            $true {
                # set global vars
                $Global:JCRUsers = $users
                $Global:JCRSystems = $systems
                $Global:JCRAssociations = $userAssociationList
                $Global:JCRRadiusMembers = $radiusMemberList
                # update the settings date
                Set-JCRSettingsFile -globalVarslastUpdate (Get-Date)
                # update users.json
                Update-JCRUsersJson
            }
            $false {
                # set global vars from local cache
                $Global:JCRUsers = Get-Content -path "$JCScriptRoot/data/userHash.json" | ConvertFrom-Json -AsHashtable
                $Global:JCRSystems = Get-Content -path "$JCScriptRoot/data/systemHash.json" | ConvertFrom-Json -AsHashtable
                $Global:JCRAssociations = Get-Content -path "$JCScriptRoot/data/associationHash.json" | ConvertFrom-Json -AsHashtable
                $Global:JCRRadiusMembers = Get-Content -path "$JCScriptRoot/data/radiusMembers.json" | ConvertFrom-Json -AsHashtable
                # update users.json
                Update-JCRUsersJson
            }
        }
    }
}