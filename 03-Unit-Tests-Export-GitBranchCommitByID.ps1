<#
.SYNOPSIS
    Smoke-tests Export-GitBranchCommitByID against the tests/Github/DbUp main tip.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Assert the default list is the latest 20 commits on main, newest first.
    6. Select the tests/Github/DbUp main tip by short hash, number, and full hash.
    7. Assert the tip identity and write each Export-GitBranchCommitByID JSON into that dated folder.
    8. Remove that dated folder when -keepTempRepo:$false is passed.
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
    PS> .\03-Unit-Tests-Export-GitBranchCommitByID.ps1
    Imports PSGitRepoCommands and writes the main-tip commit JSON under tests\yyyyMMdd-HHmm.

    PS> .\03-Unit-Tests-Export-GitBranchCommitByID.ps1 -noPause -keepTempRepo:$false
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
    Assert-TestCommandExported -name 'Get-GitBranchCommitByID', 'Export-GitBranchCommitByID'

    Write-Section -message 'Create dated test folder under tests/'
    $resolvedRepoPath = New-TestRunFolder -parentPath $repoPath
    Write-Host ("resolvedRepoPath = {0}" -f $resolvedRepoPath) -ForegroundColor DarkGray

    Write-Section -message 'Latest commits on main'
    [string]$branchTip = (git -C $libraryPath rev-parse main).Trim()
    $latest = Get-GitBranchCommitByID -path $libraryPath -branch main -fetch:$false -includePatch:$false
    $latestTip = @($latest.Commits)[0]
    $olderLatest = @($latest.Commits)[1]
    Assert-TestTrue -condition ($latest.CommitCount -eq 20) -label 'Get-GitBranchCommitByID returns the default limit of 20' -details $latest.CommitCount
    Assert-TestTrue -condition ($latest.Limit -eq 20) -label 'commit lookup Limit is 20'
    Assert-TestTrue -condition ([datetime]$latestTip.AuthorDate -ge [datetime]$olderLatest.AuthorDate) -label 'branch commits are newest first'
    Assert-TestTrue -condition ($latestTip.Number -eq 1 -and $latestTip.Hash -eq $branchTip) -label 'commit number 1 in the list is the branch tip'
    Assert-TestTrue -condition ($latestTip.Author -eq 'Robert Wagner' -and $latestTip.AuthorEmail -eq 'robert@wagner.id.au' -and $latestTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $latestTip.Committer -eq 'Robert Wagner') -label 'latest tip identity matches Robert Wagner'

    $limited = Get-GitBranchCommitByID -path $libraryPath -branch main -limit 3 -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($limited.CommitCount -eq 3 -and $limited.Limit -eq 3) -label 'Get-GitBranchCommitByID -limit 3 returns three commits'
    Assert-TestTrue -condition (@($limited.Commits)[0].Hash -eq $branchTip) -label '-limit 3 still starts at the branch tip'

    [bool]$numberPastLimit = $false
    try {
        Get-GitBranchCommitByID -path $libraryPath -branch main -number 21 -fetch:$false -includePatch:$false | Out-Null
    }
    catch {
        $numberPastLimit = $true
    }
    Assert-TestTrue -condition $numberPastLimit -label 'commit number 21 is outside the default limit of 20'

    Write-Section -message 'Select the main tip by number, short hash, and full hash'
    $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'
    Assert-TestTrue -condition ($byNumber.Author -eq 'Robert Wagner') -label 'tip Author is Robert Wagner'
    Assert-TestTrue -condition ($byNumber.AuthorEmail -eq 'robert@wagner.id.au') -label 'tip AuthorEmail is robert@wagner.id.au'
    Assert-TestTrue -condition ($byNumber.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'tip AuthorDate is 2026-02-18T13:55:32+10:00'
    Assert-TestTrue -condition ($byNumber.Committer -eq 'Robert Wagner') -label 'tip Committer is Robert Wagner'

    $byShort = Get-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byShort.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -shortHash matches the tip'

    $byFull = Get-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byFull.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -hash matches the tip'

    Write-Section -message 'Export the main tip'
    [string]$shortJsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
    $shortExport = Export-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $shortJsonPath
    Assert-TestTrue -condition ($shortExport.JsonPath.StartsWith($resolvedRepoPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'short-hash export JSON is in the dated test folder' -details $shortExport.JsonPath
    Assert-TestTrue -condition ($shortExport.Commit.Hash -eq $branchTip) -label 'short-hash export commit is the branch tip'

    [string]$numberJsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-commit-by-number.json' -f $byNumber.Short)
    $numberExport = Export-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false -outputPath $numberJsonPath
    Assert-TestTrue -condition ($numberExport.Commit.Hash -eq $branchTip) -label 'number export commit is the branch tip'

    [string]$hashJsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-commit-by-hash.json' -f $byNumber.Short)
    $hashExport = Export-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false -outputPath $hashJsonPath
    Assert-TestTrue -condition ($hashExport.Commit.Hash -eq $branchTip) -label 'full-hash export commit is the branch tip'

    $exportJson = Get-Content -LiteralPath $shortExport.JsonPath -Raw | ConvertFrom-Json
    Assert-TestTrue -condition ($exportJson.Commit.Author -eq 'Robert Wagner' -and $exportJson.Commit.AuthorEmail -eq 'robert@wagner.id.au' -and $exportJson.Commit.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportJson.Commit.Committer -eq 'Robert Wagner') -label 'commit export JSON stores the real DbUp tip identity'

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
