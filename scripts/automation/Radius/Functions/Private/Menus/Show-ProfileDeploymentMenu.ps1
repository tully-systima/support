function Show-ProfileDeploymentMenu {
    $title = ' JumpCloud macOS Profile Deployment '
    Clear-Host
    Write-Host $(PadCenter -string $Title -char '=')
    Write-Host $(PadCenter -string "Select an option below to view macOS Profile deployment status`n" -char ' ') -ForegroundColor Yellow

    # ==== instructions ====
    Write-Host $(PadCenter -string ' macOS Profile Deployment Result Options ' -char '-')
    # List options:
    Write-Host "1: Press '1' to view all associated macOS Radius policies. `n`t$([char]0x1b)[96mNOTE: This will display every user, their associated devices, and the generated profiles."
    Write-Host "3: Press '2' to view all failed Profile associations. `n`t$([char]0x1b)[96mNOTE: This will display all failed Profile associations and their status messages."
    Write-Host "E: Press 'E' to exit."

    Write-Host $(PadCenter -string "-" -char '-')
}
