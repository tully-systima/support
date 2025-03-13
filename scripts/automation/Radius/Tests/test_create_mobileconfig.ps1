#!ps
$JCScriptRoot = Split-Path -Parent $PSScriptRoot

# Import the Config.ps1 file
. "$JCScriptRoot/Config.ps1"

# Import the Json functions
. "$JCScriptRoot/Functions/Private/UserJson/Get-UserJsonData.ps1"
. "$JCScriptRoot/Functions/Private/UserJson/Set-UserJsonData.ps1"

# Get the userObject
$userObject = Get-UserJsonData

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
    if ($null -eq $JCRadiusCertURL) {
        Write-Host "No JCRadiusCertURL found in Config.ps1. Please set the JCRadiusCertURL variable." -ForegroundColor Red
        return 1
    }
    try {
        Invoke-WebRequest -Uri "$JCRadiusCertURL" -OutFile $jcCertPath
        if (Test-Path -Path $jcCertPath) {
            Write-Host "[status] JumpCloud Radius Root CA Certificate downloaded successfully" -ForegroundColor Green
        } else {
            Write-Host "[status] JumpCloud Radius Root CA Certificate download failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "[status] JumpCloud Radius Root CA Certificate download failed: $($_.Exception.Message)" -ForegroundColor Red
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
        # Create a new object inside $user
        $user | Add-Member -MemberType NoteProperty -Name macOSProfile -Value @{
            'profilePayloadDisplayName' = "$($user.userName) - $($JCR_NETWORKSSID)";
            'profilePayloadIdentifier' = "com.jumpcloud.$([guid]::NewGuid().ToString())";
            'profilePayloadUUID' = "$([guid]::NewGuid().ToString())";
            'userCertPayloadUUID' = "$([guid]::NewGuid().ToString())";
            'jcCertPayloadUUID' = "$([guid]::NewGuid().ToString())";
            'wifiPayloadUUID' = "$([guid]::NewGuid().ToString())";
        } -Force
        Set-UserJsonData -userArray $userObject
    }

    # Ensure macOSProfile values are not missing or empty
    if (-not $user.macOSProfile.profilePayloadIdentifier) {
        $user.macOSProfile.profilePayloadIdentifier = "com.jumpcloud.$([guid]::NewGuid().ToString())"
    }
    if (-not $user.macOSProfile.profilePayloadUUID) {
        $user.macOSProfile.profilePayloadUUID = "$([guid]::NewGuid().ToString())"
    }
    if (-not $user.macOSProfile.userCertPayloadUUID) {
        $user.macOSProfile.userCertPayloadUUID = "$([guid]::NewGuid().ToString())"
    }
    if (-not $user.macOSProfile.jcCertPayloadUUID) {
        $user.macOSProfile.jcCertPayloadUUID = "$([guid]::NewGuid().ToString())"
    }
    if (-not $user.macOSProfile.wifiPayloadUUID) {
        $user.macOSProfile.wifiPayloadUUID = "$([guid]::NewGuid().ToString())"
    }
    Set-UserJsonData -userArray $userObject

    # MARK: Payload Display Name (always update)
    Write-Host "[status] Setting profilePayloadDisplayName" -ForegroundColor Blue
    $user.macOSProfile.profilePayloadDisplayName = "$($user.userName) - $($JCR_NETWORKSSID)"

    # MARK: JumpCloud Policy ID
    if ($null -ne $user.macOSProfile.JCPolicyID) {
        Write-Host "[status] JCPolicyID found" -ForegroundColor Green
    } else {
        Write-Host "[status] JCPolicyID not found" -ForegroundColor Yellow
    }



    Write-Host "[status] Profile identifiers and UUIDs:" -ForegroundColor Blue
    Write-Host " - profilePayloadDisplayName:  `"$($user.macOSProfile.profilePayloadDisplayName)`"" -ForegroundColor Blue
    Write-Host " - profilePayloadIdentifier:   `"$($user.macOSProfile.profilePayloadIdentifier)`"" -ForegroundColor Blue
    Write-Host " - profilePayloadUUID:         `"$($user.macOSProfile.profilePayloadUUID)`"" -ForegroundColor Blue
    Write-Host " - userCertPayloadUUID:        `"$($user.macOSProfile.userCertPayloadUUID)`"" -ForegroundColor Blue
    Write-Host " - jcCertPayloadUUID:          `"$($user.macOSProfile.jcCertPayloadUUID)`"" -ForegroundColor Blue
    Write-Host " - wifiPayloadUUID:            `"$($user.macOSProfile.wifiPayloadUUID)`"" -ForegroundColor Blue

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


    # MARK: Root Cert Payload
    $rootCertPayload = @"
        <dict>
            <key>PayloadCertificateFileName</key>
            <string>radius.jumpcloud.com-2024</string>
            <key>PayloadContent</key>
            <data>$($jcRootCertContentBase64)</data>
            <key>PayloadDisplayName</key>
            <string>Certificate (Root)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.root.$($user.macOSProfile.jcCertPayloadUUID)</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>$($user.macOSProfile.jcCertPayloadUUID)</string>
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
            <data>$($userCertContentBase64)</data>
            <key>PayloadDisplayName</key>
            <string>$($user.userName)</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.security.pkcs12.$($user.macOSProfile.userCertPayloadUUID)</string>
            <key>PayloadType</key>
            <string>com.apple.security.pkcs12</string>
            <key>PayloadUUID</key>
            <string>$($user.macOSProfile.userCertPayloadUUID)</string>
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
                    <string>$($user.macOSProfile.userCertPayloadUUID)</string>
                    <string>$($user.macOSProfile.jcCertPayloadUUID)</string>
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
            <string>$($user.macOSProfile.userCertPayloadUUID)</string>
            <key>PayloadDisplayName</key>
            <string>JumpCloud Wi-Fi</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.wifi.managed.$($user.macOSProfile.wifiPayloadUUID)</string>
            <key>PayloadOrganization</key>
            <string></string>
            <key>PayloadType</key>
            <string>com.apple.wifi.managed</string>
            <key>PayloadUUID</key>
            <string>$($user.macOSProfile.wifiPayloadUUID)</string>
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
$($wifiPayload)
$($userCertPayload)
$($rootCertPayload)
    </array>
    <key>PayloadDisplayName</key>
    <string>$($user.macOSProfile.profilePayloadDisplayName)</string>
    <key>PayloadIdentifier</key>
    <string>$($user.macOSProfile.profilePayloadIdentifier)</string>
    <key>PayloadOrganization</key>
    <string>$($JCR_SUBJECT_HEADERS.Organization)</string>
    <key>PayloadScope</key>
    <string>$($payloadScope)</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$($user.macOSProfile.profilePayloadUUID)</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"@

    # Write the mobileconfig content to the user profile path
    Write-Host "[status] Writing mobileconfig content to file: `"$userProfilePath`""
    Set-Content -Path $userProfilePath -Value $mobileconfigContent
    Write-Host "[status] Mobileconfig file created for user $($user.userName)" -ForegroundColor Green

    # Update entry $user in users.json using the Set-UserJsonData function
    Set-UserJsonData -userArray $userObject
}
