<#
.SYNOPSIS
    Smoke-tests commit lookup by author-date range against tests/Github/DbUp.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Read commits on tests/Github/DbUp main for 2026-02-18, then again with author and email filters.
    6. Assert the newest commit identity and write the date-range export JSON into that dated folder.
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
    PS> .\05-Unit-Tests-Export-GitBranchCommitsByDateRange.ps1
    Imports PSGitRepoCommands and writes the 2026-02-18 export under tests\yyyyMMdd-HHmm.

    PS> .\05-Unit-Tests-Export-GitBranchCommitsByDateRange.ps1 -noPause -keepTempRepo:$false
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
    Assert-TestCommandExported -name 'Get-GitBranchCommitsByDateRange', 'Export-GitBranchCommitsByDateRange'

    Write-Section -message 'Create dated test folder under tests/'
    $resolvedRepoPath = New-TestRunFolder -parentPath $repoPath
    Write-Host ("resolvedRepoPath = {0}" -f $resolvedRepoPath) -ForegroundColor DarkGray

    Write-Section -message 'Commits on 2026-02-18'
    [datetime]$rangeFrom = [datetime]'2026-02-18T00:00:00+10:00'
    [datetime]$rangeTo = [datetime]'2026-02-18T23:59:59+10:00'
    $byDate = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -fetch:$false -includePatch:$false
    $dateTip = @($byDate.Commits)[0]
    Assert-TestTrue -condition ($byDate.CommitCount -ge 1 -and $byDate.CommitCount -le 20) -label 'Get-GitBranchCommitsByDateRange returns commits inside the default limit' -details $byDate.CommitCount
    Assert-TestTrue -condition ($byDate.Limit -eq 20) -label 'date lookup Limit is 20'
    Assert-TestTrue -condition ($dateTip.Hash -eq '41228ce747979fb52e1a59e3eec5823e6de869c8') -label 'date range number 1 is the DbUp main tip'
    Assert-TestTrue -condition ($dateTip.Author -eq 'Robert Wagner' -and $dateTip.AuthorEmail -eq 'robert@wagner.id.au' -and $dateTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $dateTip.Committer -eq 'Robert Wagner') -label 'date range tip identity matches Robert Wagner'
    if ($byDate.CommitCount -gt 1) {
        $olderDateCommit = @($byDate.Commits)[1]
        Assert-TestTrue -condition ([datetime]$dateTip.AuthorDate -ge [datetime]$olderDateCommit.AuthorDate) -label 'date range commits are newest first'
    }

    foreach ($dateCommit in @($byDate.Commits)) {
        [datetimeoffset]$commitInstant = [datetimeoffset]::Parse([string]$dateCommit.AuthorDate, [System.Globalization.CultureInfo]::InvariantCulture)
        [datetimeoffset]$fromOffset = [datetimeoffset]::new($rangeFrom)
        [datetimeoffset]$toOffset = [datetimeoffset]::new($rangeTo)
        Assert-TestTrue -condition ($commitInstant -ge $fromOffset -and $commitInstant -le $toOffset) -label ("commit {0} is inside 2026-02-18" -f $dateCommit.Short) -details $dateCommit.AuthorDate
    }

    Write-Section -message 'Date range filtered by author and email'
    $byAuthor = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -author 'Robert Wagner' -fetch:$false -includePatch:$false
    $authorTip = @($byAuthor.Commits)[0]
    Assert-TestTrue -condition ($authorTip.Hash -eq $dateTip.Hash) -label 'author filter keeps the same newest commit'
    Assert-TestTrue -condition ($byAuthor.Author -eq 'Robert Wagner') -label 'date lookup stores the author filter'

    $byEmail = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -email 'robert@wagner.id.au' -fetch:$false -includePatch:$false
    $emailTip = @($byEmail.Commits)[0]
    Assert-TestTrue -condition ($emailTip.Hash -eq $dateTip.Hash) -label 'email filter keeps the same newest commit'
    Assert-TestTrue -condition ($byEmail.Email -eq 'robert@wagner.id.au') -label 'date lookup stores the email filter'

    $empty = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from ([datetime]'2099-01-01') -to ([datetime]'2099-01-02') -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($empty.CommitCount -eq 0) -label 'a future date range returns no commits'

    Write-Section -message 'Export commits for 2026-02-18 by author'
    [string]$dateJsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-date-commits.json' -f $dateTip.Short)
    $dateExport = Export-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -author 'Robert Wagner' -fetch:$false -includePatch:$false -outputPath $dateJsonPath
    Assert-TestTrue -condition (Test-Path -LiteralPath $dateExport.JsonPath) -label 'Export-GitBranchCommitsByDateRange wrote JSON' -details $dateExport.JsonPath
    Assert-TestTrue -condition ($dateExport.JsonPath.StartsWith($resolvedRepoPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'date export JSON is in the dated test folder' -details $dateExport.JsonPath
    Assert-TestTrue -condition ($dateExport.CommitCount -eq $byAuthor.CommitCount) -label 'date export CommitCount matches the author filter'
    $exportJson = Get-Content -LiteralPath $dateExport.JsonPath -Raw | ConvertFrom-Json
    $exportTip = @($exportJson.Commits)[0]
    Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'date export JSON stores the real DbUp tip identity'

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
