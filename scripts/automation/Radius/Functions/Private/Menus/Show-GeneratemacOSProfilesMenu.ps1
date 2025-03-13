function Show-GeneratemacOSProfilesMenu {
    $title = ' JumpCloud macOS Profile Generation '
    Clear-Host
    Write-Host $(PadCenter -string $Title -char '=')
    Write-Host $(PadCenter -string "Select an option below to generate macOS profiles`n" -char ' ') -ForegroundColor Yellow

    # ==== instructions ====
    Write-Host $(PadCenter -string ' macOS Profile Generation Options ' -char '-')
    # List options:
    Write-Host $(PadCenter -string ' --------- For all users --------- ' -char ' ')
    Write-Host "1: Press '1' to generate macOS Profiles, upload as JumpCloud policies, and associate to each users' macOS devices"
    Write-Host "2: Press '2' to only generate macOS profiles for all users"
    Write-Host "3: Press '3' to only upload profiles to JumpCloud policies for all users"
    Write-Host "4: Press '4' to only update Policy Association to each users' macOS devices"
    Write-Host $(PadCenter -string ' --------- For single users --------- ' -char ' ')
    Write-Host "5: Press '5' to generate macOS Profiles, upload as JumpCloud policies, and associate to a specific user's macOS device"
    Write-Host "6: Press '6' to only generate macOS profiles for a specific user"
    Write-Host "7: Press '7' to only upload profiles to JumpCloud policies for a specific user"
    Write-Host "8: Press '8' to only update Policy Association to a specific user's macOS device"
    Write-Host $(PadCenter -char '-')
    Write-Host "E: Press 'E' to exit."

    Write-Host $(PadCenter -string "-" -char '-')
}
