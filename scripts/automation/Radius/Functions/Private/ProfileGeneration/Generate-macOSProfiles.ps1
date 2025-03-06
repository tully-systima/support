function Generate-macOSProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("EmailSAN", "EmailDn", "UsernameCN")]
        [system.String]
        $CertType,
        # Input from users.json
        [Parameter(HelpMessage = 'An individual or array of user objects from users.json', Mandatory)]
        [System.Object[]]
        $userObject,
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

        # Check if the user json object has a macOSProfile object
        if (-not $user.macOSProfile) {
            Write-Host "[status] no matching macOSProfile object found for user $($user.userName), creating..."
            # Create a macOSProfile object in the user object
            $user | Add-Member -MemberType NoteProperty -Name macOSProfile -Value @{ }
            $user | Add-Member -MemberType NoteProperty -Name .macOSProfile.profilePayloadIdentifier -Value ""
            $user | Add-Member -MemberType NoteProperty -Name .macOSProfile.profilePayloadUUID -Value ""
            $user.macOSProfile.profilePayloadIdentifier = ""
            $user.macOSProfile.profilePayloadUUID = ""
        }

        # Generate new or parse existing profile payload keys and UUID values
        if (Test-Path -Path "$userProfilePath") {
            # !IMPORTANT! In order to update an existing profile, the payloadIdentifier and payloadUUID must be identical to the existing profile
            if ($user.macOSProfile -eq $null) {
                Write-Host "[status] no matching macOSProfile object found for user $($user.userName), creating..."
                $user | Add-Member -MemberType NoteProperty -Name macOSProfile -Value @{ }
                Write-Host "[status] Existing mobileconfig file found for user $($user.userName)"
                if (-not $user.macOSProfile.profilePayloadDisplayName) {
                    Write-Host "[status] profilePayloadDisplayName not found, creating..."
                    $profilePayloadDisplayName = "$($user.userName) - $NETWORKSSID Radius WIFI"
                } else {
                    $profilePayloadDisplayName = $user.macOSProfile.profilePayloadDisplayName
                }
                if ($user.macOSProfile.profilePayloadIdentifier -eq $null) {
                    Write-Host "[status] PayloadIdentifier not found, creating..."
                    $profilePayloadIdentifier = "com.$($JCR_SUBJECT_HEADERS.Organization).$([guid]::NewGuid().ToString())"
                } else {
                    $profilePayloadIdentifier = $user.macOSProfile.profilePayloadIdentifier
                }
                if ($user.macOSProfile.profilePayloadUUID -eq $null) {
                    Write-Host "[status] PayloadUUID not found, creating..."
                    $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
                } else {
                    $profilePayloadUUID = $user.macOSProfile.profilePayloadUUID
                }
                if ($user.macOSProfile.userCertPayloadUUID -eq $null) {
                    Write-Host "[status] userCertPayloadUUID not found, creating..."
                    $userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                } else {
                    $userCertPayloadUUID = $user.macOSProfile.userCertPayloadUUID
                }
                if ($user.macOSProfile.jcCertPayloadUUID -eq $null) {
                    Write-Host "[status] jcCertPayloadUUID not found, creating..."
                    $jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
                } else {
                    $jcCertPayloadUUID = $user.macOSProfile.jcCertPayloadUUID
                }
                if ($user.macOSProfile.wifiPayloadUUID -eq $null) {
                    Write-Host "[status] wifiPayloadUUID not found, creating..."
                    $wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
                } else {
                    $wifiPayloadUUID = $user.macOSProfile.wifiPayloadUUID
                }
            }
            # Write all values down to the users object in users.json
            $user.macOSProfile.profilePayloadIdentifier = $profilePayloadIdentifier
            $user.macOSProfile.profilePayloadUUID = $profilePayloadUUID
            $user.macOSProfile.userCertPayloadUUID = $userCertPayloadUUID
            $user.macOSProfile.jcCertPayloadUUID = $jcCertPayloadUUID
            $user.macOSProfile.wifiPayloadUUID = $wifiPayloadUUID
            # Update the users.json file with the modified userObject
            $userObject | ConvertTo-Json | Set-Content -Path "$JCScriptRoot/users.json"
        } else {
            # If not, create and store new PayloadIdentifier and PayloadUUID
            Write-Host "[status] No existing mobileconfig file found for user $($user.userName), creating new..."
            $profilePayloadIdentifier = "com.$($JCR_SUBJECT_HEADERS.Organization).$([guid]::NewGuid().ToString())"
            $profilePayloadUUID = "$([guid]::NewGuid().ToString())"
            $userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
            $jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
            $wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
        }

        Write-Host "[status] profilePayloadIdentifier: `"$profilePayloadIdentifier`""
        Write-Host "[status] profilePayloadUUID: `"$profilePayloadUUID`""

        if (-Not (Test-Path -Path "$JCScriptRoot/UserProfiles/")) {
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
        Write-Host "[status] Mobileconfig file created for user $($user.userName)"
        }
    }
    end {
        Write-Host "Mobileconfig file created at: $userProfilePath"
        return $true
    }
}
