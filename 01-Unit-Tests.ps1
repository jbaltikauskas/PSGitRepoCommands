<#
.SYNOPSIS
    Smoke-tests the PSGitRepoCommands module against a Git repository under tests/.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm and use it as the Git root.
    5. Exercise list/create/switch/rename/remove/compare and branch-diff cmdlets.
    6. Assert expected PSCustomObject shapes and counts; throw on failure.
    7. Write every Export-* JSON file into that same dated folder, and a
       patch file beside each one. Each file name starts with a commit
       short hash and a dash (<short>-work-items.json/.patch,
       <short>-commit-export.json/.patch, <target tip short>-diff-export.json/.patch).
    8. Remove that dated folder when -keepTempRepo:$false is passed.
       The DbUp submodule under tests/Github/ is left untouched.

.PARAMETER modulePath
    Path to PSGitRepoCommands.psd1. Defaults to .ps\PSGitRepoCommands\PSGitRepoCommands.psd1
    under the script root.

.PARAMETER repoPath
    Parent folder for dated test runs. Defaults to tests/ under the script root.
    Each run creates a child folder named yyyyMMdd-HHmm and uses that as the Git root.

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
    Requires PowerShell 7.2+ and git on PATH. Mutating cmdlets run against a
    dated folder under tests/ (yyyyMMdd-HHmm), not the parent PSGitRepoCommands repo.

.EXAMPLE
    PS> .\Unit-Tests.ps1
    Imports PSGitRepoCommands and runs the suite in tests\yyyyMMdd-HHmm.

    PS> .\Unit-Tests.ps1 -noPause
    Same suite without Read-Host pauses (CI / agent friendly).
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, HelpMessage = "Path to PSGitRepoCommands.psd1.")]
    [ValidateNotNullOrEmpty()]
    [string]$modulePath = (Join-Path -Path $PSScriptRoot -ChildPath '.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'),

    [Parameter(Mandatory = $false, HelpMessage = "Parent folder for dated test runs. Defaults to tests/ under the script root.")]
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
foreach ($sectionScript in @(Get-ChildItem -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '.ps-UnitTests\01-Unit-Tests') -Filter '*.ps1')) {
    . $sectionScript.FullName
}

[string]$resolvedModulePath = [System.IO.Path]::GetFullPath($modulePath)
[string]$resolvedRepoPath = $null
[string]$exportTempPath = $null

try {

    Write-TestSettings -values ([ordered]@{
            modulePath         = $modulePath
            resolvedModulePath = $resolvedModulePath
            repoPath           = $repoPath
            noPause            = $noPause.IsPresent
            keepTempRepo       = $keepTempRepo
        }) -boundParameters $PSBoundParameters

    Import-PSGitRepoCommandsAndAssertExportedCommands -modulePath $resolvedModulePath
    [string]$runFolder = New-DatedTestFolderUnderTests -parentPath $repoPath
    $resolvedRepoPath = Initialize-NestedGitRepositoryForSmokeTest -repoPath $runFolder
    Assert-GitBranchReadCmdletsOnSmokeRepository -repoPath $resolvedRepoPath
    Assert-GitBranchMutateCmdletsOnSmokeRepository -repoPath $resolvedRepoPath

    $exportTempPath = $resolvedRepoPath
    Write-Host ("exportTempPath = {0}" -f $exportTempPath) -ForegroundColor DarkGray

    Assert-CommitWorkItemsExportAndPatch -repoPath $resolvedRepoPath -exportTempPath $exportTempPath
    $newestAuthorCommit = Assert-CommitsByAuthorOrEmailOnSmokeRepository -repoPath $resolvedRepoPath -exportTempPath $exportTempPath
    Assert-CommitsByDateRangeOnSmokeRepository -repoPath $resolvedRepoPath -exportTempPath $exportTempPath -newestAuthorCommit $newestAuthorCommit

    $fullDiff = Assert-GitBranchFullDiffFromLastReleaseToMain -repoPath $repoPath
    $selectedTip = Assert-LibraryMainTipCommitByNumberShortHashAndFullHash -libraryPath $fullDiff.LibraryPath -diffTargetBranch $fullDiff.DiffTargetBranch
    Export-LibraryCommitPatchAndFullDiffFiles -libraryPath $fullDiff.LibraryPath -exportTempPath $exportTempPath -releaseBranch $fullDiff.ReleaseBranch -diffTargetBranch $fullDiff.DiffTargetBranch -branchTip $selectedTip.BranchTip -byNumber $selectedTip.ByNumber -tip $fullDiff.Tip

    Complete-TestRunFolder -repoPath $resolvedRepoPath -keep $keepTempRepo
    if (-not $keepTempRepo) {
        $resolvedRepoPath = $null
        $exportTempPath = $null
    }
}
catch {

    Write-TestScriptFailure -errorRecord $_ -leftPath $resolvedRepoPath -leftLabel 'Nested Git root left at' -pause (-not $noPause.IsPresent)
    exit 1
}

Write-Host ''
Write-Host 'Script executed successfully.' -ForegroundColor Green
