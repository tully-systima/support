# InvokePester.ps1 is intended to be called directly as a file-function
# There are two parameter sets
Param(
    [Parameter(ParameterSetName = 'SingleOrgTests', Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)][ValidateNotNullOrEmpty()][System.String]$JumpCloudApiKey
    , [Parameter(ParameterSetName = 'SingleOrgTests', Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2)][System.String[]]$ExcludeTagList
    , [Parameter(ParameterSetName = 'SingleOrgTests', Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 3)][System.String[]]$IncludeTagList
)

# Get list of tags and validate that tags have been applied
$PesterTests = Get-ChildItem -Path:($PSScriptRoot + '/*.Tests.ps1') -Recurse
$Tags = ForEach ($PesterTest In $PesterTests) {
    $PesterTestFullName = $PesterTest.FullName
    $FileContent = Get-Content -Path:($PesterTestFullName)
    $DescribeLines = $FileContent | Select-String -Pattern:([RegEx]'(Describe)')#.Matches.Value
    ForEach ($DescribeLine In $DescribeLines) {
        If ($DescribeLine.Line -match 'Tag') {
            $TagParameterValue = ($DescribeLine.Line | Select-String -Pattern:([RegEx]'(?<=-Tag)(.*?)(?=\s)')).Matches.Value
            @(":", "(", ")", "'") | ForEach-Object { If ($TagParameterValue -like ('*' + $_ + '*')) {
                    $TagParameterValue = $TagParameterValue.Replace($_, '')
                } }
            $TagParameterValue
        } Else {
            Write-Error ('Tag missing in "' + $PesterTestFullName + '" on line number "' + $DescribeLine.LineNumber + '" value "' + ($DescribeLine.Line).Trim() + '"')
        }
    }
}
# Filters on tags
$IncludeTags = If ($IncludeTagList) {
    $IncludeTagList
} Else {
    $Tags | Where-Object { $_ -notin $ExcludeTags } | Select-Object -Unique
}
# locally, clear pester run paths if it exists before run:
If ($PesterRunPaths) {
    Clear-Variable -Name PesterRunPaths
}
# Determine the parameter set path

if ($env:CI) {
    If ($env:job_group) {
        # split tests by job group:
        $PesterTestsPaths = Get-ChildItem -Path $PSScriptRoot -Filter *.Tests.ps1 -Recurse | Where-Object size -GT 0 | Sort-Object -Property Name
        Write-Host "[Status] $($PesterTestsPaths.count) tests found"
        $CIindex = @()
        $numItems = $($PesterTestsPaths.count)
        $numBuckets = 3
        $itemsPerBucket = [math]::Floor(($numItems / $numBuckets))
        $remainder = ($numItems % $numBuckets)
        $extra = 0
        for ($i = 0; $i -lt $numBuckets; $i++) {
            <# Action that will repeat until the condition is met #>
            if ($i -eq ($numBuckets - 1)) {
                $extra = $remainder
            }
            $indexList = ($itemsPerBucket + $extra)
            # Write-Host "Container $i contains $indexList items:"
            $CIIndexList = @()
            $CIIndexList += for ($k = 0; $k -lt $indexList; $k++) {
                <# Action that will repeat until the condition is met #>
                $bucketIndex = $i * $itemsPerBucket
                # write-host "`$tags[$($bucketIndex + $k)] ="$tags[($bucketIndex + $k)]
                $PesterTestsPaths[$bucketIndex + $k]
            }
            # add to ciIndex Array
            $CIindex += , ($CIIndexList)
        }
        $PesterRunPaths = $CIindex[[int]$($env:job_group)]
        Write-Host "[status] The following $($($CIindex[[int]$($env:job_group)]).count) tests will be run:"
        $($CIindex[[int]$($env:job_group)]) | ForEach-Object { Write-Host "$_" }
    }
} else {
    # run setup org locally and set variables
}
$env:JCAPIKEY = $JumpCloudApiKey
Connect-JCOnline -JumpCloudApiKey:($env:JCAPIKEY) -force

if (-Not $PesterRunPaths) {
    $PesterRunPaths = @(
        "$PSScriptRoot"
    )
}
# Load private functions
Write-Host ('[status]Load private functions: ' + "$PSScriptRoot/../Functions/Private/*.ps1")
Write-Host ('[status]Load public functions: ' + "$PSScriptRoot/../Functions/Public/*.ps1")
Get-ChildItem -Path:("$PSScriptRoot/../Functions/Private/*.ps1") -Recurse | ForEach-Object { . $_.FullName }


# Set the test result directory:
$PesterResultsFileXmldir = "$PSScriptRoot/test_results/"
# create the directory if it does not exist:
if (-not (Test-Path $PesterResultsFileXmldir)) {
    New-Item -Path $PesterResultsFileXmldir -ItemType Directory
}

# define pester configuration
$configuration = New-PesterConfiguration
$configuration.Run.Path = $PesterRunPaths
$configuration.Should.ErrorAction = 'Continue'
$configuration.CodeCoverage.Enabled = $true
$configuration.testresult.Enabled = $true
$configuration.testresult.OutputFormat = 'JUnitXml'
$configuration.Filter.Tag = $IncludeTags
$configuration.Filter.ExcludeTag = $ExcludeTagList
$configuration.CodeCoverage.OutputPath = ($PesterResultsFileXmldir + 'coverage.xml')
$configuration.testresult.OutputPath = ($PesterResultsFileXmldir + 'results.xml')

Write-Host "Begin Org Setup Before Tests:"
. "$PSScriptRoot/SetupRadiusOrg.ps1"

Write-Host ("[RUN COMMAND] Invoke-Pester -Path:('$PesterRunPaths') -TagFilter:('$($IncludeTags -join "','")') -ExcludeTagFilter:('$($ExcludeTagList -join "','")') -PassThru") -BackgroundColor:('Black') -ForegroundColor:('Magenta')
# Run Pester tests
Invoke-Pester -Configuration $configuration

$PesterTestResultPath = (Get-ChildItem -Path:("$($PesterResultsFileXmldir)")).FullName | Where-Object { $_ -match "results.xml" }
If (Test-Path -Path:($PesterTestResultPath)) {
    [xml]$PesterResults = Get-Content -Path:($PesterTestResultPath)
    If ($PesterResults.ChildNodes.failures -gt 0) {
        Write-Error ("Test Failures: $($PesterResults.ChildNodes.failures)")
    }
    If ($PesterResults.ChildNodes.errors -gt 0) {
        Write-Error ("Test Errors: $($PesterResults.ChildNodes.errors)")
    }
} Else {
    Write-Error ("Unable to find file path: $PesterTestResultPath")
}
Write-Host -ForegroundColor Green '-------------Done-------------'