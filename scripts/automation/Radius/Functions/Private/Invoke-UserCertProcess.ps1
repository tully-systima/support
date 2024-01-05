Function Invoke-UserCertProcess {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'radiusMember')]
        [System.object]
        $radiusMember,
        [Parameter(ParameterSetName = 'selectedUserObject')]
        [System.String]
        $selectedUserObject,
        [Parameter(Mandatory)]
        [ValidateSet('EmailSAN', 'EmailDN', 'UsernameCN')]
        [System.String]
        $certType,
        # force replace existing certificate
        [Parameter()]
        [switch]
        $forceReplaceCert,
        # prompt replace existing certificate
        [Parameter()]
        [switch]
        $prompt
    )
    begin {

        switch ($PSCmdlet.ParameterSetName) {
            'radiusMember' {
                try {

                    $MatchedUser = $GLOBAL:JCRUsers[$radiusMember.userID]
                } catch {
                    exit
                }
            }
            'userObject' {
                $MatchedUser = $GLOBAL:JCRUsers[$selectedUserObject.userid]
            }
        }

        # get the user from user.json
        $userObject, $userIndex = Get-UserFromTable -jsonFilePath "$JCScriptRoot/users.json" -userID $MatchedUser.id
        # Test if the file exists:
        switch (Test-Path "$JCScriptRoot/UserCerts/$($matchedUser.username)-client-signed.pfx") {
            $true {
                switch ($forceReplaceCert) {
                    $true {
                        $writeCert = $true
                        $cert_action = "Overwritten"
                    }
                    $false {
                        $writeCert = $false
                        $cert_action = "Skip Generation"

                    }
                }
                if ($prompt) {

                    $writeCert = Get-ResponsePrompt -message "A certifcate already exists for user: $($matchedUser.username) do you want to re-generate this certificate?"
                    switch ($writeCert) {
                        $true {
                            $cert_action = "Overwritten"

                        }
                        $false {
                            $cert_action = "Skip Generation"
                        }
                    }

                }
            }
            $false {
                $writeCert = $true
                $cert_action = "New Cert Generated"
            }
            Default {
                $writeCert = $false
                $cert_action = "Unknown Action"
            }
        }

    }
    process {
        # if writeCert, generate the cert
        if ($writeCert) {
            Generate-UserCert -CertType $CertType -user $MatchedUser -rootCAKey "$JCScriptRoot/Cert/radius_ca_key.pem" -rootCA "$JCScriptRoot/Cert/radius_ca_cert.pem" *> /dev/null
            # validate that the cert was written correctly:
            #TODO: validate and return as variable
        }

        # generate the cert depending if -force or if new
        if ($userIndex -ge 0) {
            # update the new certificate info & set commandAssociation to $null
            # TODO: commandAssociation not being set to null
            $certInfo = Get-CertInfo -UserCerts -username $MatchedUser.username
            # Add the cert info tracking to the object
            $certInfo | Add-Member -Name 'deployed' -Type NoteProperty -Value $false
            $certInfo | Add-Member -Name 'deploymentDate' -Type NoteProperty -Value $null
            Set-UserTable -index $userIndex -certInfoObject $certInfo -commandAssociationsObject $null
        } else {
            # Create a new table entry
            New-UserTable -id $MatchedUser.id -username $MatchedUser.username -localUsername $MatchedUser.systemUsername
        }

    }
    end {
        #TODO: eventually add message if we fail to generate a command
        $resultTable = [ordered]@{
            'Username'       = $MatchedUser.username;
            'Cert Action'    = $cert_action;
            'Generated Date' = $certInfo.generated;
        }

        return $resultTable
    }
}