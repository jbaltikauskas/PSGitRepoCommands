<#
.SYNOPSIS
    Smoke-tests commit lookup by author name and email against tests/Github/DbUp.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Read commits on tests/Github/DbUp main for author Robert Wagner and email robert@wagner.id.au.
    6. Assert the newest commit identity and write the author export JSON into that dated folder.
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
    PS> .\Unit-Tests-Export-GitBranchCommitsByAuthorOrEmail.ps1
    Imports PSGitRepoCommands and writes the Robert Wagner export under tests\yyyyMMdd-HHmm.

    PS> .\Unit-Tests-Export-GitBranchCommitsByAuthorOrEmail.ps1 -noPause -keepTempRepo:$false
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
    Assert-TestCommandExported -name 'Get-GitBranchCommitsByAuthorOrEmail', 'Export-GitBranchCommitsByAuthorOrEmail'

    Write-Section -message 'Create dated test folder under tests/'
    $resolvedRepoPath = New-TestRunFolder -parentPath $repoPath
    Write-Host ("resolvedRepoPath = {0}" -f $resolvedRepoPath) -ForegroundColor DarkGray

    Write-Section -message 'Commits by author Robert Wagner'
    $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false
    $authorTip = @($byAuthor.Commits)[0]
    Assert-TestTrue -condition ($byAuthor.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -author returns the default limit of 20' -details $byAuthor.CommitCount
    Assert-TestTrue -condition ($byAuthor.Limit -eq 20) -label 'author lookup Limit is 20'
    $olderAuthorCommit = @($byAuthor.Commits)[1]
    Assert-TestTrue -condition ([datetime]$authorTip.AuthorDate -ge [datetime]$olderAuthorCommit.AuthorDate) -label 'author commits are newest first'
    Assert-TestTrue -condition ($authorTip.Author -eq 'Robert Wagner') -label 'author lookup Author is Robert Wagner'
    Assert-TestTrue -condition ($authorTip.AuthorEmail -eq 'robert@wagner.id.au') -label 'author lookup AuthorEmail is robert@wagner.id.au'
    Assert-TestTrue -condition ($authorTip.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'author lookup AuthorDate is 2026-02-18T13:55:32+10:00'
    Assert-TestTrue -condition ($authorTip.Committer -eq 'Robert Wagner') -label 'author lookup Committer is Robert Wagner'
    Assert-TestTrue -condition ($byAuthor.IncludePatch -eq $true) -label 'author lookup includes patch text'

    Write-Section -message 'Commits by email robert@wagner.id.au'
    $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -email 'robert@wagner.id.au' -fetch:$false -includePatch:$false
    $emailTip = @($byEmail.Commits)[0]
    Assert-TestTrue -condition ($byEmail.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -email returns the default limit of 20' -details $byEmail.CommitCount
    Assert-TestTrue -condition ($byEmail.IncludePatch -eq $false) -label 'email lookup omits patch text'
    Assert-TestTrue -condition ($emailTip.Hash -eq $authorTip.Hash) -label 'email lookup newest commit matches the author lookup'
    Assert-TestTrue -condition ($emailTip.Author -eq 'Robert Wagner' -and $emailTip.AuthorEmail -eq 'robert@wagner.id.au' -and $emailTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $emailTip.Committer -eq 'Robert Wagner') -label 'email lookup tip identity matches Robert Wagner'

    Write-Section -message 'Export commits by author Robert Wagner'
    [string]$authorJsonPath = Join-Path -Path $resolvedRepoPath -ChildPath ('{0}-author-commits.json' -f $authorTip.Short)
    $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false -outputPath $authorJsonPath
    Assert-TestTrue -condition (Test-Path -LiteralPath $authorExport.JsonPath) -label 'Export-GitBranchCommitsByAuthorOrEmail wrote JSON' -details $authorExport.JsonPath
    Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($resolvedRepoPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'author export JSON is in the dated test folder' -details $authorExport.JsonPath
    Assert-TestTrue -condition ($authorExport.CommitCount -eq $byAuthor.CommitCount) -label 'author export CommitCount matches the author lookup'
    $exportJson = Get-Content -LiteralPath $authorExport.JsonPath -Raw | ConvertFrom-Json
    $exportTip = @($exportJson.Commits)[0]
    Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'author export JSON stores the real DbUp tip identity'

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
