Describe 'User Cert Report' {
    BeforeAll {
        # Load all functions from private folders
        $Private = @( Get-ChildItem -Path "$JCScriptRoot/Functions/Private/*.ps1" -Recurse)
        Foreach ($Import in $Private) {
            Try {
                . $Import.FullName
            } Catch {
                Write-Error -Message "Failed to import function $($Import.FullName): $_"
            }
        }
        # import helper functions:
        . "$PSScriptRoot/../HelperFunctions.ps1"
        # Manually update user associations for radius members, cache won't pick them up before:
        foreach ($user in $global:JCRRadiusMembers) {
            Set-JCRAssociationHash -UserID $user.userID
        }
        Get-JCRGlobalVars -Force -associateManually
        Start-GenerateRootCert -certKeyPassword "TestCertificate123!@#" -generateType "new" -force
        Start-GenerateUserCerts -type All -forceReplaceCerts
        Start-DeployUserCerts -type All -forceInvokeCommands
    }
    Context "Report Generation" {
        It "Generates the Report" {
            # Export the report
            Get-JCRCertReport -ExportFilePath "$JCScriptRoot/testReport.csv"
            $report = Import-Csv -Path "$JCScriptRoot/testReport.csv"
            $report | Should -Not -BeNullOrEmpty
        }
        It "Checks for invalid Path" {
            # Export the report
            { Get-JCRCertReport -ExportFilePath "$JCScriptRoot/testReport" } | Should -Throw
            { Get-JCRCertReport -ExportFilePath "testReport" } | Should -Throw
            { Get-JCRCertReport -ExportFilePath "$JCScriptRoot/testReport.csv" } | Should -Not -Throw
        }
    }
}