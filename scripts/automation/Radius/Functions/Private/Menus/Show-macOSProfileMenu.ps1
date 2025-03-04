function Show-macOSProfileMenu {
    $title = ' JumpCloud macOS Profile Generation '
    Clear-Host
    Write-Host $(PadCenter -string $Title -char '=')
    Write-Host $(PadCenter -string "Select an option below to generate macOS profiles`n" -char ' ') -ForegroundColor Yellow

    # ==== instructions ====
    Write-Host $(PadCenter -string ' macOS Profile Generation Options ' -char '-')
    # List options:
    Write-Host "1: Press '1' to generate profiles for users without existing profiles."
    Write-Host "2: Press '2' to generate a profile for a specific username."
    Write-Host "3: Press '3' to generate profiles for all users with macOS systems."
    Write-Host "E: Press 'E' to exit."

    Write-Host $(PadCenter -string "-" -char '-')
}
