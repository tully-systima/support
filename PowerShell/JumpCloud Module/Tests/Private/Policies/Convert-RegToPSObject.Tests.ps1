Describe -Tag:('JCPolicy') 'Registry File Tests' {
    Context 'Test Reg File Conversion' {
        $regFile = Convert-RegToPSObject -regFilePath $PesterParams_RegistryFilePath
        It 'Convert-RegToPSObject should return object with values' {
            foreach ($regKey in $regFile) {
                $regKey.customLocation | Should -Not -BeNullOrEmpty
                $regKey.customValueName | Should -Not -BeNullOrEmpty
                $regKey.customRegType | Should -Not -BeNullOrEmpty
                $regKey.customData | Should -Not -BeNullOrEmpty
            }
        }
    }
}