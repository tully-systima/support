function Show-RadiusMainMenu {
    param (
        [string]$Title = ' JumpCloud Radius Cert Deployment '
    )
    # Get cert information
    $rootCAInfo = Get-CertInfo -rootCa
    $userCertInfo = Get-CertInfo -UserCerts

    # Find all certs that will expire between current date and cut off date
    try {
        $Global:expiringCerts = Get-ExpiringCertInfo -certInfo $userCertInfo -cutoffDate $Global:JCR_USER_CERT_EXPIRE_WARNING_DAYS
    } catch {
        Write-Debug "No user certs exist, there are no user certs which will expire soon"
    }

    # Get UserGroup information from Config.ps1
    $radiusUserGroup = Get-JcSdkUserGroup -Id $Global:JCR_USER_GROUP | Select-Object Name
    $radiusUserGroupMemberCount = (Get-JcSdkUserGroupMember -GroupId $Global:JCR_USER_GROUP).Count

    # Get SSID information from Config.ps1
    $radiusSSID = $Global:JCR_NETWORKSSID.replace(';', ' ')

    # Output for Users
    Clear-Host

    # ==== TITLE ====
    Write-Host $(PadCenter -string $Title -char '=')
    Write-Host $(PadCenter -string "Edit the variables in Config.ps1 before continuing this script `n" -char ' ') -ForegroundColor Yellow
    # /==== TITLE ====

    # ==== ROOT CA ====
    Write-Host $(PadCenter -string ' Root CA ' -char '-')
    if ($rootCAInfo -eq $null) {
        Write-Host $(PadCenter -string "No Root CA detected`n" -char ' ') -ForegroundColor Yellow
    } else {
        Write-Host $(PadCenter -string "Root CA Serial Number: $($rootCAInfo.serial)" -char ' ') -ForegroundColor Green
        Write-Host $(PadCenter -string "Root CA Expiration: $($rootCAInfo.notAfter)`n" -char ' ') -ForegroundColor Green
    }
    if ($Global:expiringCerts) {
        Write-Host $(PadCenter -string "$($Global:expiringCerts.Count) user certs will expire in 15 days `n" -char ' ') -ForegroundColor Red
    }
    Write-Host $(PadCenter -string " Details " -char '-')
    # /==== ROOT CA ====

    # ==== GROUP/SSID/Global Variables  ====
    Write-Host $(PadCenter -string "Organization: $($Global:JCR_ORGANIZATION)" -char " ") -ForegroundColor Green
    Write-Host $(PadCenter -string "Radius User Group: $($radiusUserGroup.Name)" -char " ") -ForegroundColor Green
    Write-Host $(PadCenter -string "Total Radius Users: $($radiusUserGroupMemberCount)" -char " ") -ForegroundColor Green
    Write-Host $(PadCenter -string "Radius SSID(s): $radiusSSID" -char " ") -ForegroundColor Green
    if ($IsMacOS) {
        Write-Host $(PadCenter -string "Last Updated User/System Data: $($Global:JCRConfig.globalVars.lastupdate)" -char " ") -ForegroundColor Green
    } If ($isWindows) {
        Write-Host $(PadCenter -string "Last Updated User/System Data: $($Global:JCRConfig.globalVars.lastupdate.value)" -char " ") -ForegroundColor Green
    }

    Write-Host $(PadCenter -string ' Certificate Management ' -char '-')
    Write-Host " 1: Press '1' to Generate Root CA Certificate"
    Write-Host " 2: Press '2' to Generate User Certificates
    "

    Write-Host $(PadCenter -string ' Profile Management ' -char '-')
    Write-Host " 3: Press '3' to Generate macOS Profiles
    "

    Write-Host $(PadCenter -string ' Deployment ' -char '-')
    Write-Host " 4: Press '4' to Deploy User Certificates as commands"
    Write-Host " 5: Press '5' to Deploy macOS combined Certificate and Wi-Fi Profiles
    "

    Write-Host $(PadCenter -string ' Monitoring ' -char '-')
    Write-Host " 6: Press '6' to Monitor macOS Profile Deployment"
    Write-Host " 7: Press '7' to Monitor Command driven Certificate Deployment
    "

    Write-Host $(PadCenter -string ' Configuration ' -char '-')
    Write-Host " 8: Press '8' to get/update global variables
    "

    Write-Host $(PadCenter -string "-" -char '-')
    Write-Host " Q: Press 'Q' to quit
    "
}
