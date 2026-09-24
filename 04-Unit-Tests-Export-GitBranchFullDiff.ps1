<#
.SYNOPSIS
    Smoke-tests Export-GitBranchFullDiff from the last release branch to main.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Resolve the newest release/* branch in tests/Github/DbUp.
    6. Write Export-GitBranchFullDiff JSON for that release versus main into the dated folder.
    7. Remove that dated folder when -keepTempRepo:$false is passed.
       The DbUp submodule under tests/Github/ is left untouched.

.PARAMETER modulePath
    Path to PSGitRepoCommands.psd1. Defaults to .ps\PSGitRepoCommands\PSGitRepoCommands.psd1
    under the script root.

.PARAMETER repoPath
    Parent folder for the JSON export. Defaults to tests/ under the script root.
    Each run creates a child folder named yyyyMMdd-HHmm.

.PARAMETER noPause
    Skip the interactive Read-Host prompts at the end (useful for automation).

.PARAMETER keepTempRepo
    Leave the dated test folder under tests/ after a successful run (default
    $true). Pass -keepTempRepo:$false to delete it.

.INPUTS
    None.

.OUTPUTS
    None. Writes progress to the host; exits 0 on success or 1 on failure.

.NOTES
    Requires PowerShell 7.2+ and git on PATH. Reads tests/Github/DbUp and writes JSON
    only into the dated folder under tests/.

.EXAMPLE
    PS> .\04-Unit-Tests-Export-GitBranchFullDiff.ps1
    Imports PSGitRepoCommands and writes the release-versus-main JSON under tests\yyyyMMdd-HHmm.

    PS> .\04-Unit-Tests-Export-GitBranchFullDiff.ps1 -noPause -keepTempRepo:$false
    Same suite without Read-Host pauses, then removes the dated folder.
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, HelpMessage = "Path to PSGitRepoCommands.psd1.")]
    [ValidateNotNullOrEmpty()]
    [string]$modulePath = (Join-Path -Path $PSScriptRoot -ChildPath '.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'),

    [Parameter(Mandatory = $false, HelpMessage = "Parent folder for the JSON export. Defaults to tests/ under the script root.")]
    [ValidateNotNullOrEmpty()]
    [string]$repoPath = (Join-Path -Path $PSScriptRoot -ChildPath 'tests'),

    [Parameter(Mandatory = $false, HelpMessage = "Skip Read-Host close prompts.")]
    [switch]$noPause,

    [Parameter(Mandatory = $false, HelpMessage = "Keep the dated test folder under tests/ after success. Pass -keepTempRepo:`$false to delete.")]
    [bool]$keepTempRepo = $true
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

. (Join-Path -Path $PSScriptRoot -ChildPath '.ps-UnitTests\PSUnitTests.ps1')

[string]$resolvedModulePath = [System.IO.Path]::GetFullPath($modulePath)
[string]$resolvedRepoPath = $null
[string]$libraryPath = $null

try {

    $libraryPath = Get-TestLibraryPath -repoPath $repoPath

    Write-TestSettings -values ([ordered]@{
            modulePath         = $modulePath
            resolvedModulePath = $resolvedModulePath
            repoPath           = $repoPath
            libraryPath        = $libraryPath
            noPause            = $noPause.IsPresent
            keepTempRepo       = $keepTempRepo
        }) -boundParameters $PSBoundParameters

    Write-Section -message 'Import PSGitRepoCommands'
    Import-TestModule -modulePath $resolvedModulePath
    Assert-TestCommandExported -name 'Export-GitBranchFullDiff'

    Write-Section -message 'Create dated test folder under tests/'
    $resolvedRepoPath = New-TestRunFolder -parentPath $repoPath
    Write-Host ("resolvedRepoPath = {0}" -f $resolvedRepoPath) -ForegroundColor DarkGray

    Write-Section -message 'Export last release versus main'
    [string]$releaseBranch = Get-LastReleaseBranch -path $libraryPath
    [string]$tipShort = (git -C $libraryPath rev-parse --short main).Trim()
    Write-Host ("lastReleaseBranch = {0}" -f $releaseBranch) -ForegroundColor DarkGray
    [string]$jsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-diff-export.json' -f $tipShort)
    $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch main -direction TargetAhead -outputPath $jsonPath
    Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON' -details $export.JsonPath
    Assert-TestTrue -condition ($export.JsonPath.StartsWith($resolvedRepoPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'diff export JSON is in the dated test folder' -details $export.JsonPath
    Assert-TestTrue -condition ($export.BaseBranch -eq $releaseBranch) -label 'diff export base is the last release branch' -details $releaseBranch
    Assert-TestTrue -condition ($export.TargetBranch -eq 'main') -label 'diff export target is main'
    Assert-TestTrue -condition ($export.TipDiff.FileCount -ge 1) -label 'diff export tip has at least one changed file' -details $export.TipDiff.FileCount
    Assert-TestTrue -condition ($export.CommitDiff.CommitCount -ge 1) -label 'diff export has commits since the last release' -details $export.CommitDiff.CommitCount
    $exportJson = Get-Content -LiteralPath $export.JsonPath -Raw | ConvertFrom-Json
    Assert-TestTrue -condition ($exportJson.BaseBranch -eq $releaseBranch -and $exportJson.TargetBranch -eq 'main' -and $exportJson.TipDiff.FileCount -ge 1) -label 'diff export JSON stores the release-versus-main result'

    Write-Section -message 'Cleanup'
    Complete-TestRunFolder -repoPath $resolvedRepoPath -keep $keepTempRepo
    if (-not $keepTempRepo) {
        $resolvedRepoPath = $null
    }
}
catch {

    Write-TestScriptFailure -errorRecord $_ -leftPath $resolvedRepoPath -pause (-not $noPause.IsPresent)
    exit 1
}

Write-Host ''
Write-Host 'Script executed successfully.' -ForegroundColor Green
