function Generate-macOSProfiles {
    [CmdletBinding()]
    param (
        # Input from users.json
        [Parameter(HelpMessage = 'An individual or array of user objects from users.json', Mandatory)]
        [System.Object[]]
        $userObject,
        [Parameter(Mandatory = $true)]
        [ValidateSet("EmailSAN", "EmailDn", "UsernameCN")]
        [system.String]
        $CertType
    )

    begin {
        . "$JCScriptRoot/Config.ps1"

        # MARK: Set paths
        if (-Not (Test-Path -Path "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt")) {
            if (-Not (Test-Path -Path "$JCScriptRoot/JCRadiusCert/")) {
                Write-Host "[status] Creating JCRadiusCert directory..."
                New-Item -Path "$JCScriptRoot/JCRadiusCert" -ItemType Directory
            }
            Write-Host "[status] Downloading JumpCloud Radius Root CA Certificate..."
            $jcRadiusRootCA = Invoke-WebRequest -Uri "$JCRadiusCertURL" -OutFile "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt"
        } else {
            Write-Host "[status] JumpCloud Radius Root CA Certificate confirmed"
        }
        $jcCertPath = "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt"

        # Set userCertType based on CertType
        if ($CertType -eq "UsernameCN") {
            $userCertType = "pfx"
        } else {
            $userCertType = "crt"
        }

        # Check if an existing mobileconfig file exists for the user
        $userProfilePath = "$JCScriptRoot/UserProfiles/$($user.username)-Radius-WiFi.mobileconfig"
        if (Test-Path -Path "$userProfilePath") {
            # If so, set critical global variables to match the existing file
            # !IMPORTANT! In order to update an existing profile, the payloadIdentifier and payloadUUID must be identical to the existing profile
            $globalPayloadIdentifier = (Get-Content -Path $userProfilePath -Raw) -replace ".*<string>(.*)</string>.*", '$1'
            $globalPayloadUUID = (Get-Content -Path $userProfilePath -Raw) -replace ".*<string>(.*)</string>.*", '$1'
        } else {
            # If not, create and store new PayloadIdentifier and PayloadUUID
            $globalPayloadIdentifier = "$([guid]::NewGuid().ToString())"
            $globalPayloadUUID = "$([guid]::NewGuid().ToString())"
        }
    }

    process {
        foreach ($user in $userObject) {
                Write-Host "[status] User: $($user.userName)"
                Write-Host "[status] systemAssociations: $($user.systemAssociations)"

                # Check if a certificate has been generated for the user
                $userCertFiles = Get-ChildItem -Path "$JCScriptRoot/UserCerts" -Filter "$($user.userName)*"
                $userCertPath = ($userCertFiles | Where-Object { $_.Name -match "pfx" }).FullName
                if (-not $userCertPath) {
                    $userCertPath = ($userCertFiles | Where-Object { $_.Name -match "crt" }).FullName
                }
                Write-Host "[status] User Certificate Path: `"$userCertPath`""
                # Check if user certificate exists
                if (-not $userCertPath) {
                    Write-Host "No certificate found for user $($user.userName). Please generate certificates first." -ForegroundColor Red
                    return 1
                }

                # Check if an existing mobileconfig file exists for the user
                $userProfilePath = "$JCScriptRoot/UserProfiles/$($user.username).mobileconfig"
                if (Test-Path -Path $userProfilePath) {
                    $userProfileXML = [xml](Get-Content -Path $userProfilePath)
                    Write-Host "[status] Existing mobileconfig file found for user $($user.userName)" -ForegroundColor Green
                }

                # MARK: Identifiers and UUIDs
                # !IMPORTANT! In order to seamlessly update an existing macOS profile, the payloadIdentifier and payloadUUID must be identical to the existing profile.
                if (-not $user.PSObject.Properties['macOSProfile']) {
                    Write-Host "[status] no matching macOSProfile object found for user $($user.userName), creating..." -ForegroundColor Yellow
                    $user | Add-Member -MemberType NoteProperty -Name macOSProfile -Value @{ } -Force
                }

                # MARK: JumpCloud Policy ID
                if ($user.macOSProfile.JCPolicyID) {
                    Write-Host "[status] JCPolicyID found" -ForegroundColor Green
                } else {
                    Write-Host "[status] JCPolicyID not found" -ForegroundColor Yellow
                }

                # MARK: Payload Display Name (enforce to current name)
                Write-Host "[status] Setting profilePayloadDisplayName" -ForegroundColor Blue
                $profilePayloadDisplayName = "$($user.userName) - $($JCR_NETWORKSSID)"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadDisplayName -Value "$($profilePayloadDisplayName)" -Force
                $user.macOSProfile.profilePayloadDisplayName = "$($profilePayloadDisplayName)"
                # Update $user object

                # MARK: Profile Identifier
                if ($user.macOSProfile.profilePayloadIdentifier -ne $null) {
                    Write-Host "[status] profilePayloadIdentifier found" -ForegroundColor Green
                    $profilePayloadIdentifier = $user.macOSProfile.profilePayloadIdentifier
                } else {
                    if (Test-Path -Path $userProfilePath) {
                        # Check userProfileXML for the value of PayloadIdentifier
                        $profilePayloadIdentifier = $userProfileXML.plist.dict.array.dict.string | Where-Object { $_.Name -eq "PayloadIdentifier" } | Select-Object -ExpandProperty '#text'
                        # Check if the value was found
                        if ($profilePayloadIdentifier) {
                            Write-Host "[status] profilePayloadIdentifier found in existing mobileconfig file" -ForegroundColor Green
                            Write-Host " - profilePayloadIdentifier: `"$profilePayloadIdentifier`"" -ForegroundColor Green
                        } else {
                            Write-Host "[status] profilePayloadIdentifier not found, creating..." -ForegroundColor Blue
                            $profilePayloadIdentifier = "com.jumpcloud.$($user.userName).radius-wifi"
                            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadIdentifier -Value "$($profilePayloadIdentifier)" -Force
                        }
                    } else {
                        Write-Host "[status] Creating profilePayloadIdentifier" -ForegroundColor Blue
                        $profilePayloadIdentifier = "com.jumpcloud.$($user.userName).radius-wifi"
                        $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadIdentifier -Value "$($profilePayloadIdentifier)" -Force
                    }
                }
                # Update $user object
                $user.macOSProfile.profilePayloadIdentifier = "$($profilePayloadIdentifier)"

                # MARK: Profile UUID
                if ($user.macOSProfile.profilePayloadUUID -ne $null) {
                    Write-Host "[status] profilePayloadUUID found" -ForegroundColor Green
                    $profilePayloadUUID = $user.macOSProfile.profilePayloadUUID
                } else {
                    if (Test-Path -Path $userProfilePath) {
                        # Check userProfileXML for the value of PayloadUUID
                        $profilePayloadUUID = $userProfileXML.plist.dict.array.dict.string | Where-Object { $_.Name -eq "PayloadUUID" } | Select-Object -ExpandProperty '#text'
                        # Check if the value was found
                        if ($profilePayloadUUID) {
                            Write-Host "[status] profilePayloadUUID found in existing mobileconfig file" -ForegroundColor Green
                        } else {
                            Write-Host "[status] profilePayloadUUID not found, creating..." -ForegroundColor Yellow
                            $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
                            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadUUID -Value "$($profilePayloadUUID)" -Force
                        }
                    } else {
                        Write-Host "[status] Creating profilePayloadUUID" -ForegroundColor Blue
                        $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
                        $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadUUID -Value "$($profilePayloadUUID)" -Force
                    }
                }
                # Update $user object
                $user.macOSProfile.profilePayloadUUID = "$($profilePayloadUUID)"

                # MARK: Other UUIDs
                # User Cert Payload UUID
                if ($user.macOSProfile.userCertPayloadUUID -ne $null) {
                    Write-Host "[status] userCertPayloadUUID found" -ForegroundColor Green
                    $userCertPayloadUUID = $user.macOSProfile.userCertPayloadUUID
                } else {
                    Write-Host "[status] Creating userCertPayloadUUID" -ForegroundColor Blue
                    $userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                    $user.macOSProfile | Add-Member -MemberType NoteProperty -Name userCertPayloadUUID -Value "$($userCertPayloadUUID)" -Force
                }
                # Update $user object
                $user.macOSProfile.userCertPayloadUUID = "$($userCertPayloadUUID)"

                # JC Cert Payload UUID
                if ($user.macOSProfile.jcCertPayloadUUID -ne $null) {
                    Write-Host "[status] jcCertPayloadUUID found" -ForegroundColor Green
                    $jcCertPayloadUUID = $user.macOSProfile.jcCertPayloadUUID
                } else {
                    Write-Host "[status] Creating jcCertPayloadUUID" -ForegroundColor Blue
                    $jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                    $user.macOSProfile | Add-Member -MemberType NoteProperty -Name jcCertPayloadUUID -Value "$($jcCertPayloadUUID)" -Force
                }
                # Update $user object
                $user.macOSProfile.jcCertPayloadUUID = "$($jcCertPayloadUUID)"

                # WiFi Payload UUID
                if ($user.macOSProfile.wifiPayloadUUID -ne $null) {
                    Write-Host "[status] wifiPayloadUUID found" -ForegroundColor Green
                    $wifiPayloadUUID = $user.macOSProfile.wifiPayloadUUID
                } else {
                    Write-Host "[status] Creating wifiPayloadUUID" -ForegroundColor Blue
                    $wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
                    $user.macOSProfile | Add-Member -MemberType NoteProperty -Name wifiPayloadUUID -Value "$($wifiPayloadUUID)" -Force
                }
                # Update $user object
                $user.macOSProfile.wifiPayloadUUID = "$($wifiPayloadUUID)"

                Write-Host "[status] Profile identifiers and UUIDs:" -ForegroundColor Blue
                Write-Host " - profilePayloadDisplayName:  `"$profilePayloadDisplayName`"" -ForegroundColor Blue
                Write-Host " - profilePayloadIdentifier:   `"$profilePayloadIdentifier`"" -ForegroundColor Blue
                Write-Host " - profilePayloadUUID:         `"$profilePayloadUUID`"" -ForegroundColor Blue
                Write-Host " - userCertPayloadUUID:        `"$userCertPayloadUUID`"" -ForegroundColor Blue
                Write-Host " - jcCertPayloadUUID:          `"$jcCertPayloadUUID`"" -ForegroundColor Blue
                Write-Host " - wifiPayloadUUID:            `"$wifiPayloadUUID`"" -ForegroundColor Blue

                if (-not (Test-Path -Path "$JCScriptRoot/UserProfiles/")) {
                    Write-Host "[status] Creating UserProfiles directory..."
                    New-Item -Path "$JCScriptRoot/UserProfiles" -ItemType Directory
                }

                # User certificate content
                $userCertContent = Get-Content -Path $userCertPath -Raw
                $userCertContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userCertContent))
                $userCertContentBase64 = [regex]::Replace($userCertContentBase64, "(.{52})", "$1`n")
                # JumpCloud root certificate content
                $jcRootCertContent = Get-Content -Path $jcCertPath -Raw
                $jcRootCertContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jcRootCertContent))
                $jcRootCertContentBase64 = [regex]::Replace($jcRootCertContentBase64, "(.{52})", "$1`n")

                # MARK: Root Cert Payload
                $rootCertPayload = @"
        <dict>
            <key>PayloadCertificateFileName</key>
            <string>radius.jumpcloud.com-2024</string>
            <key>PayloadContent</key>
            <data>
            $($jcRootCertContentBase64)
            </data>
            <key>PayloadDisplayName</key>
            <string>Certificate (Root)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.root.$($jcCertPayloadUUID)</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>$($jcCertPayloadUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
"@

                    # MARK: User PFX Payload
                    $userCertPayload = @"
        <dict>
            <key>Password</key>
            <string>$($JCR_USER_CERT_PASS)</string>
            <key>PayloadCertificateFileName</key>
            <string>$($user.userName)-client-signed</string>
            <key>PayloadContent</key>
            <data>
            $($userCertContentBase64)
            </data>
            <key>PayloadDisplayName</key>
            <string>$($user.userName)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.pkcs12.$($userCertPayloadUUID)</string>
            <key>PayloadType</key>
            <string>com.apple.security.pkcs12</string>
            <key>PayloadUUID</key>
            <string>$($userCertPayloadUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
"@

                    # MARK: WiFi Payload
                    $wifiPayload = @"
        <dict>
            <key>AutoJoin</key>
            <true/>
            <key>DisableAssociationMACRandomization</key>
            <true/>
            <key>EAPClientConfiguration</key>
            <dict>
                <key>AcceptEAPTypes</key>
                <array>
                    <integer>13</integer>
                </array>
                <key>PayloadCertificateAnchorUUID</key>
                <array>
                    <string>$($userCertPayloadUUID)</string>
                    <string>$($jcCertPayloadUUID)</string>
                </array>
                <key>TLSTrustedServerNames</key>
                <array>
                    <string>$($JCR_SUBJECT_HEADERS.CommonName)</string>
                    <string>radius.jumpcloud.com</string>
                </array>
            </dict>
            <key>EncryptionType</key>
            <string>WPA2</string>
            <key>Interface</key>
            <string>BuiltInWireless</string>
            <key>IsHotspot</key>
            <false/>
            <key>PayloadCertificateUUID</key>
            <string>$($userCertPayloadUUID)</string>
            <key>PayloadDisplayName</key>
            <string>JumpCloud Wi-Fi</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.wifi.managed.$($wifiPayloadUUID)</string>
            <key>PayloadOrganization</key>
            <string></string>
            <key>PayloadType</key>
            <string>com.apple.wifi.managed</string>
            <key>PayloadUUID</key>
            <string>$($wifiPayloadUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>SSID_STR</key>
            <string>$($JCR_NETWORKSSID)</string>
            <key>TLSCertificateRequired</key>
            <true/>
        </dict>
"@

                    # MARK: Assemble profile
                    $mobileconfigContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
$($userCertPayload)
$($wifiPayload)
$($rootCertPayload)
    </array>
    <key>PayloadDisplayName</key>
    <string>$($profilePayloadDisplayName)</string>
    <key>PayloadIdentifier</key>
    <string>$($profilePayloadIdentifier)</string>
    <key>PayloadOrganization</key>
    <string>$($JCR_SUBJECT_HEADERS.Organization)</string>
    <key>PayloadScope</key>
    <string>$($payloadScope)</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$($profilePayloadUUID)</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"@

                # Write the mobileconfig content to the user profile path
                Write-Host "[status] Writing mobileconfig content to file: `"$userProfilePath`""
                Set-Content -Path $userProfilePath -Value $mobileconfigContent
                Write-Host "[status] Mobileconfig file created for user $($user.userName)" -ForegroundColor Green
        }
    }

    end {
        Write-Host "Generated $($userObject.count) profiles" -ForegroundColor Green
    }
}
