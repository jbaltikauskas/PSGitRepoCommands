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

function Write-Section () {
    <#
    .SYNOPSIS
        Writes a yellow section banner to the host.

    .DESCRIPTION
        Prints blank lines, gray rules, and a cyan titled message for multi-step scripts.

    .PARAMETER message
        Section title text.

    .NOTES
        1. Write blank line, gray horizontal rules, and cyan titled message.

    .EXAMPLE
        PS> Write-Section -message 'Import module'
        Prints a titled banner for the import phase.

        PS> Write-Section -message 'Cleanup'
        Prints a titled banner for cleanup.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Section title.")]
        [ValidateNotNullOrEmpty()]
        [string]$message
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Write-Host ''
        Write-Host ('=' * 60) -ForegroundColor DarkGray
        Write-Host $message -ForegroundColor Cyan
        Write-Host ('=' * 60) -ForegroundColor DarkGray
    }
}

function Assert-TestTrue () {
    <#
    .SYNOPSIS
        Throws when a test condition is false.

    .DESCRIPTION
        Evaluates Condition; on failure throws with Label (and optional Details)
        so the top-level catch can report which assertion failed. On success
        writes a green PASS line and optional Details in DarkGray.

    .PARAMETER condition
        Boolean result that must be true.

    .PARAMETER label
        Short name of the assertion for error messages.

    .PARAMETER details
        Optional extra context shown on pass and included in the throw message.

    .NOTES
        1. Throw when Condition is false (include Details when provided).
        2. Write a green pass line when Condition is true; echo Details if set.

    .EXAMPLE
        PS> Assert-TestTrue -condition $true -label 'sanity'
        Writes a green pass line.

        PS> Assert-TestTrue -condition $true -label 'has b.txt' -details 'Files=a.txt, b.txt'
        Writes PASS plus the details line.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Value that must be true.")]
        [bool]$condition,

        [Parameter(Mandatory = $true, HelpMessage = "Assertion label.")]
        [ValidateNotNullOrEmpty()]
        [string]$label,

        [Parameter(Mandatory = $false, HelpMessage = "Optional context for pass/fail output.")]
        [string]$details
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if (-not $condition) {
            if ([string]::IsNullOrWhiteSpace($details)) {
                throw "Assertion failed: $label"
            }

            throw "Assertion failed: $label | $details"
        }

        Write-Host "PASS: $label" -ForegroundColor Green

        if (-not [string]::IsNullOrWhiteSpace($details)) {
            Write-Host ("  {0}" -f $details) -ForegroundColor DarkGray
        }
    }
}

function New-TestRunFolder () {
    <#
    .SYNOPSIS
        Creates a dated folder under ParentPath for one smoke-test run.

    .DESCRIPTION
        Ensures ParentPath exists, then creates a child directory named
        yyyyMMdd-HHmm (local time). If that name already exists, appends
        seconds as yyyyMMdd-HHmmss. Returns the resolved folder path.
        Does not touch sibling content such as tests/Github/DbUp.

    .PARAMETER parentPath
        Parent directory, typically tests/.

    .NOTES
        1. Resolve ParentPath and create it when missing.
        2. Build yyyyMMdd-HHmm; fall back to yyyyMMdd-HHmmss on collision.
        3. Create the folder and return its full path.

    .EXAMPLE
        PS> New-TestRunFolder -parentPath '.\tests'
        Creates tests\20260921-0013 (or similar) and returns that path.

        PS> $run = New-TestRunFolder -parentPath $repoPath
        Stores the dated run folder path in $run.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Parent folder, typically tests/.")]
        [ValidateNotNullOrEmpty()]
        [string]$parentPath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedParent = [System.IO.Path]::GetFullPath($parentPath)

        if (-not (Test-Path -LiteralPath $resolvedParent)) {
            New-Item -ItemType Directory -Path $resolvedParent | Out-Null
        }

        [string]$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
        [string]$runPath = Join-Path -Path $resolvedParent -ChildPath $stamp

        if (Test-Path -LiteralPath $runPath) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $runPath = Join-Path -Path $resolvedParent -ChildPath $stamp
        }

        if (Test-Path -LiteralPath $runPath) {
            throw "Test run folder already exists: $runPath"
        }

        New-Item -ItemType Directory -Path $runPath | Out-Null
        return [System.IO.Path]::GetFullPath($runPath)
    }
}

[string]$resolvedModulePath = [System.IO.Path]::GetFullPath($modulePath)
[string]$resolvedRepoPath = $null
[string]$libraryPath = Join-Path -Path ([System.IO.Path]::GetFullPath($repoPath)) -ChildPath 'Github\DbUp'

try {

    Write-Host 'BEGIN: Settings' -ForegroundColor Yellow
    Write-Host ("modulePath         = {0}" -f $modulePath) -ForegroundColor DarkGray
    Write-Host ("resolvedModulePath = {0}" -f $resolvedModulePath) -ForegroundColor DarkGray
    Write-Host ("repoPath           = {0}" -f $repoPath) -ForegroundColor DarkGray
    Write-Host ("libraryPath        = {0}" -f $libraryPath) -ForegroundColor DarkGray
    Write-Host ("noPause            = {0}" -f $noPause.IsPresent) -ForegroundColor DarkGray
    Write-Host ("keepTempRepo       = {0}" -f $keepTempRepo) -ForegroundColor DarkGray
    $PSBoundParameters | Out-String | Write-Host
    Write-Host 'END: Settings' -ForegroundColor Yellow

    if (-not (Test-Path -LiteralPath $resolvedModulePath)) {
        throw "PSGitRepoCommands manifest not found: $resolvedModulePath"
    }

    if (-not (Test-Path -LiteralPath $libraryPath -PathType Container)) {
        throw "DbUp repository not found: $libraryPath"
    }

    Write-Section -message 'Import PSGitRepoCommands'
    Import-Module -Name $resolvedModulePath -Force

    Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name 'Get-GitBranchCommitByID' -ErrorAction SilentlyContinue)) -label 'Get-GitBranchCommitByID is exported'
    Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name 'Export-GitBranchCommitByID' -ErrorAction SilentlyContinue)) -label 'Export-GitBranchCommitByID is exported'

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
    if ($keepTempRepo) {
        Write-Host ("Keeping dated test folder: {0}" -f $resolvedRepoPath) -ForegroundColor Yellow
    }
    else {
        Remove-Item -LiteralPath $resolvedRepoPath -Recurse -Force
        Write-Host 'Removed dated test folder under tests/.' -ForegroundColor Green
        $resolvedRepoPath = $null
    }
}
catch {

    Write-Host ''
    Write-Host 'Script failed to execute.' -ForegroundColor Red
    Write-Host ("Exception: {0}" -f $_.Exception.GetType().FullName) -ForegroundColor Red
    Write-Host ("Message:   {0}" -f $_.Exception.Message) -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($resolvedRepoPath)) {
        Write-Host ("Nested test folder left at: {0}" -f $resolvedRepoPath) -ForegroundColor Yellow
    }

    if (-not $noPause.IsPresent) {
        Read-Host 'Press Enter to close'
    }

    exit 1
}

Write-Host ''
Write-Host 'Script executed successfully.' -ForegroundColor Green
