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
foreach ($sectionScript in @(Get-ChildItem -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '.ps-UnitTests\03-Unit-Tests-Export-GitBranchCommitByID') -Filter '*.ps1')) {
    . $sectionScript.FullName
}

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

    Import-PSGitRepoCommandsForCommitByID -modulePath $resolvedModulePath
    $resolvedRepoPath = New-DatedTestFolderUnderTests -parentPath $repoPath
    [string]$branchTip = Assert-LatestCommitsOnDbUpMain -libraryPath $libraryPath
    $byNumber = Assert-DbUpMainTipByNumberShortHashAndFullHash -libraryPath $libraryPath -branchTip $branchTip
    Export-DbUpMainTipCommitByID -libraryPath $libraryPath -exportFolder $resolvedRepoPath -branchTip $branchTip -byNumber $byNumber

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
