#!ps
$JCScriptRoot = Split-Path -Parent $PSScriptRoot

# Import the Config.ps1 file
. "$JCScriptRoot/Config.ps1"

# Get user object from JCScriptRoot/users.json
$userObject = Get-Content -Path "$JCScriptRoot/users.json" | ConvertFrom-Json

# MARK: Set paths
# JumpCloud Radius Root CA Certificate
$jcCertPath = "$JCScriptRoot/JCRadiusCert/jc-radius-root-ca.crt"
if (Test-Path -Path $jcCertPath) {
        Write-Host "[status] JumpCloud Radius Root CA Certificate confirmed" -ForegroundColor Green
} else {
    if (-Not (Test-Path -Path "$JCScriptRoot/JCRadiusCert/")) {
        Write-Host "[status] JumpCloud Radius Root CA Certificate not found" -ForegroundColor Red
        Write-Host "Creating JCRadiusCert directory..." -ForegroundColor Yellow
        New-Item -Path "$JCScriptRoot/JCRadiusCert" -ItemType Directory
    }
    Write-Host "[status] Downloading JumpCloud Radius Root CA Certificate..." -ForegroundColor Yellow
    if ($JCRadiusCertURL -eq $null) {
        Write-Host "No JCRadiusCertURL found in Config.ps1. Please set the JCRadiusCertURL variable." -ForegroundColor Red
        return 1
    }
    $jcRadiusRootCA = Invoke-WebRequest -Uri "$JCRadiusCertURL" -OutFile $jcCertPath
    # Check if the download was successful
    if ($jcRadiusRootCA.StatusCode -eq 200) {
        Write-Host "[status] JumpCloud Radius Root CA Certificate downloaded successfully" -ForegroundColor Green
    } else {
        Write-Host "[status] JumpCloud Radius Root CA Certificate download failed" -ForegroundColor Red
        return 1
    }
}

# Set userCertType based on CertType
if ($CertType -eq "UsernameCN") {
    $userCertType = "pfx"
} else {
    $userCertType = "crt"
}

# MARK: Loop through the users json array

foreach ($user in $userObject) {
    Write-Host "[status] User: $($user.userName)"
    Write-Host "[status] systemAssociations: $($user.systemAssociations)"

    # Payload Display Name (also used for the JumpCloud policy name)
    $profilePayloadDisplayName = "$($user.userName) - $NETWORKSSID Radius WIFI"

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

    # MARK: Identifiers and UUIDs
    # !IMPORTANT! In order to seamlessly update an existing macOS profile, the payloadIdentifier and payloadUUID must be identical to the existing profile.
    if (-not ($user.macOSProfile)) {
        Write-Host "[status] no matching macOSProfile object found for user $($user.userName), creating..." -ForegroundColor Yellow
        $user | Add-Member -MemberType NoteProperty -Name macOSProfile -Value @{ }
    }

    # MARK: JumpCloud Policy ID
    if ($user.macOSProfile.JCPolicyID) {
        Write-Host "[status] JCPolicyID found" -ForegroundColor Green
    } else {
        Write-Host "[status] JCPolicyID not found" -ForegroundColor Yellow
    }

    # MARK: Profile Display Name
    if ($user.macOSProfile.profilePayloadDisplayName) {
        Write-Host "[status] profilePayloadDisplayName found" -ForegroundColor Green
        $profilePayloadDisplayName = $user.macOSProfile.profilePayloadDisplayName
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing mobileconfig profile for the value of <key>PayloadDisplayName</key>
            $profilePayloadDisplayName = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadDisplayName</key>" -Context 0,1).Context.PostContext
            $profilePayloadDisplayName = $profilePayloadDisplayName -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($profilePayloadDisplayName) {
                Write-Host "[status] profilePayloadDisplayName found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] profilePayloadDisplayName not found, creating..." -ForegroundColor Blue
                $profilePayloadDisplayName = "$($user.userName) - $NETWORKSSID Radius WIFI"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadDisplayName -Value "$($profilePayloadDisplayName)"
                return
            }
        } else {
            Write-Host "[status] Creating profilePayloadDisplayName" -ForegroundColor Blue
            $profilePayloadDisplayName = "$($user.userName) - $NETWORKSSID Radius WIFI"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadDisplayName -Value "$($profilePayloadDisplayName)"
        }
    }
    # Update $user object
    $user.macOSProfile.profilePayloadDisplayName = "$($profilePayloadDisplayName)"

    # MARK: Profile Identifier
    if ($user.macOSProfile.profilePayloadIdentifier) {
        Write-Host "[status] profilePayloadIdentifier found" -ForegroundColor Green
        $profilePayloadIdentifier = $user.macOSProfile.profilePayloadIdentifier
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing .mobileconfig profile for the value of <key>PayloadIdentifier</key>
            $profilePayloadIdentifier = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadIdentifier</key>" -Context 0,1).Context.PostContext
            $profilePayloadIdentifier = $profilePayloadIdentifier -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($profilePayloadIdentifier) {
                Write-Host "[status] profilePayloadIdentifier found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] profilePayloadIdentifier not found, creating..." -ForegroundColor Blue
                $profilePayloadIdentifier = "com.jumpcloud.$($user.userName).radius-wifi"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadIdentifier -Value "$($profilePayloadIdentifier)"
                return
            }
        } else {
            Write-Host "[status] Creating profilePayloadIdentifier" -ForegroundColor Blue
            $profilePayloadIdentifier = "com.jumpcloud.$($user.userName).radius-wifi"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadIdentifier -Value "$($profilePayloadIdentifier)"
        }
    }
    # Update $user object
    $user.macOSProfile.profilePayloadIdentifier = "$($profilePayloadIdentifier)"

    # MARK: Profile UUID
    if ($user.macOSProfile.profilePayloadUUID) {
        Write-Host "[status] profilePayloadUUID found" -ForegroundColor Green
        $profilePayloadUUID = $user.macOSProfile.profilePayloadUUID
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing .mobileconfig profile for the value of <key>PayloadUUID</key>
            $profilePayloadUUID = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadUUID</key>" -Context 0,1).Context.PostContext
            $profilePayloadUUID = $profilePayloadUUID -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($profilePayloadUUID) {
                Write-Host "[status] profilePayloadUUID found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] profilePayloadUUID not found, creating..." -ForegroundColor Yellow
                $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadUUID -Value "$($profilePayloadUUID)"
                return
            }
        } else {
            Write-Host "[status] Creating profilePayloadUUID" -ForegroundColor Blue
            $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name profilePayloadUUID -Value "$($profilePayloadUUID)"
        }
    }
    # Update $user object
    $user.macOSProfile.profilePayloadUUID = "$($profilePayloadUUID)"

    # MARK: Other UUIDs
    if ($user.macOSProfile.userCertPayloadUUID) {
        Write-Host "[status] userCertPayloadUUID found" -ForegroundColor Green
        $userCertPayloadUUID = $user.macOSProfile.userCertPayloadUUID
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing .mobileconfig profile for the value of <key>PayloadUUID</key>
            $userCertPayloadUUID = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadUUID</key>" -Context 0,1).Context.PostContext
            $userCertPayloadUUID = $userCertPayloadUUID -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($userCertPayloadUUID) {
                Write-Host "[status] userCertPayloadUUID found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] userCertPayloadUUID not found, creating..." -ForegroundColor Yellow
                $userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name userCertPayloadUUID -Value "$($userCertPayloadUUID)"
                return
            }
        } else {
            Write-Host "[status] Creating userCertPayloadUUID" -ForegroundColor Blue
            $userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name userCertPayloadUUID -Value "$($userCertPayloadUUID)"
        }
    }
    # Update $user object
    $user.macOSProfile.userCertPayloadUUID = "$($userCertPayloadUUID)"

    if ($user.macOSProfile.jcCertPayloadUUID) {
        Write-Host "[status] jcCertPayloadUUID found" -ForegroundColor Green
        $jcCertPayloadUUID = $user.macOSProfile.jcCertPayloadUUID
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing .mobileconfig profile for the value of <key>PayloadUUID</key>
            $jcCertPayloadUUID = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadUUID</key>" -Context 0,1).Context.PostContext
            $jcCertPayloadUUID = $jcCertPayloadUUID -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($jcCertPayloadUUID) {
                Write-Host "[status] jcCertPayloadUUID found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] jcCertPayloadUUID not found, creating..." -ForegroundColor Yellow
                $jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name jcCertPayloadUUID -Value "$($jcCertPayloadUUID)"
                return
            }
        } else {
            Write-Host "[status] Creating jcCertPayloadUUID" -ForegroundColor Blue
            $jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name jcCertPayloadUUID -Value "$($jcCertPayloadUUID)"
        }
    }
    # Update $user object
    $user.macOSProfile.jcCertPayloadUUID = "$($jcCertPayloadUUID)"

    if ($user.macOSProfile.wifiPayloadUUID) {
        Write-Host "[status] wifiPayloadUUID found" -ForegroundColor Green
        $wifiPayloadUUID = $user.macOSProfile.wifiPayloadUUID
    } else {
        if (Test-Path -Path $userProfilePath) {
            # Check the existing .mobileconfig profile for the value of <key>PayloadUUID</key>
            $wifiPayloadUUID = (Get-Content -Path $userProfilePath | Select-String -Pattern "<key>PayloadUUID</key>" -Context 0,1).Context.PostContext
            $wifiPayloadUUID = $wifiPayloadUUID -replace "<string>|</string>|^\s+|\s+$"
            # Check if the value was found
            if ($wifiPayloadUUID) {
                Write-Host "[status] wifiPayloadUUID found in existing mobileconfig file" -ForegroundColor Green
                return
            } else {
                Write-Host "[status] wifiPayloadUUID not found, creating..." -ForegroundColor Yellow
                $wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
                $user.macOSProfile | Add-Member -MemberType NoteProperty -Name wifiPayloadUUID -Value "$($wifiPayloadUUID)"
                return
            }
        } else {
            Write-Host "[status] Creating wifiPayloadUUID" -ForegroundColor Blue
            $wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
            $user.macOSProfile | Add-Member -MemberType NoteProperty -Name wifiPayloadUUID -Value "$($wifiPayloadUUID)"
        }
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

    # JumpCloud root certificate content
    $jcRootCertContent = Get-Content -Path $jcCertPath -Raw
    $jcRootCertContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jcRootCertContent))

    # Assemble the mobileconfig content
    $rootCertPayload = @"
        <dict>
            <key>PayloadCertificateFileName</key>
            <string>radius.jumpcloud.com-2024</string>
            <key>PayloadContent</key>
            <data>
            $jcRootCertContentBase64
            </data>
            <key>PayloadDisplayName</key>
            <string>Certificate (Root)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.root.$jcCertPayloadUUID</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>$jcCertPayloadUUID</string>
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
            $userCertContentBase64
            </data>
            <key>PayloadDisplayName</key>
            <string>$($user.userName)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.pkcs12.$userCertPayloadUUID</string>
            <key>PayloadType</key>
            <string>com.apple.security.pkcs12</string>
            <key>PayloadUUID</key>
            <string>$userCertPayloadUUID</string>
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
                    <string>$userCertPayloadUUID</string>
                    <string>$jcCertPayloadUUID</string>
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
            <string>$userCertPayloadUUID</string>
            <key>PayloadDisplayName</key>
            <string>JumpCloud Wi-Fi</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.wifi.managed.8186183F-7852-4823-BE78-9F18B8060BC2</string>
            <key>PayloadOrganization</key>
            <string></string>
            <key>PayloadType</key>
            <string>com.apple.wifi.managed</string>
            <key>PayloadUUID</key>
            <string>8186183F-7852-4823-BE78-9F18B8060BC2</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>SSID_STR</key>
            <string>$JCR_NETWORKSSID</string>
            <key>TLSCertificateRequired</key>
            <true/>
        </dict>
"@

        # Create the mobileconfig content
        $mobileconfigContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
$userCertPayload
$wifiPayload
$rootCertPayload
    </array>
    <key>PayloadDisplayName</key>
    <string>$profilePayloadDisplayName</string>
    <key>PayloadIdentifier</key>
    <string>$profilePayloadIdentifier</string>
    <key>PayloadOrganization</key>
    <string>$($JCR_SUBJECT_HEADERS.Organization)</string>
    <key>PayloadScope</key>
    <string>$payloadScope</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$profilePayloadUUID</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"@

    # Write the mobileconfig content to the user profile path
    Write-Host "[status] Writing mobileconfig content to file: `"$userProfilePath`""
    Set-Content -Path $userProfilePath -Value $mobileconfigContent
    Write-Host "[status] Mobileconfig file created for user $($user.userName)" -ForegroundColor Green

    # Write all values down to the users object in users.json
    $user.macOSProfile.profilePayloadDisplayName = $profilePayloadDisplayName
    $user.macOSProfile.profilePayloadIdentifier = $profilePayloadIdentifier
    $user.macOSProfile.profilePayloadUUID = $profilePayloadUUID
    $user.macOSProfile.userCertPayloadUUID = $userCertPayloadUUID
    $user.macOSProfile.jcCertPayloadUUID = $jcCertPayloadUUID

    # Update the users.json file with the modified userObject
    $userObject | ConvertTo-Json | Set-Content -Path "$JCScriptRoot/users.json"
}
