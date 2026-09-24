<#
.SYNOPSIS
    Smoke-tests commit lookup by author-date range against tests/DbUp.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Read commits on tests/DbUp main for 2026-02-18, then again with author and email filters.
    6. Assert the newest commit identity and write the date-range export JSON into that dated folder.
    7. Remove that dated folder when -keepTempRepo:$false is passed.
       The DbUp submodule under tests/ is left untouched.

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
    Requires PowerShell 7.2+ and git on PATH. Reads tests/DbUp and writes JSON
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
        Does not touch sibling content such as DbUp.

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
[string]$libraryPath = Join-Path -Path ([System.IO.Path]::GetFullPath($repoPath)) -ChildPath 'DbUp'

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

    Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name 'Get-GitBranchCommitsByDateRange' -ErrorAction SilentlyContinue)) -label 'Get-GitBranchCommitsByDateRange is exported'
    Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name 'Export-GitBranchCommitsByDateRange' -ErrorAction SilentlyContinue)) -label 'Export-GitBranchCommitsByDateRange is exported'

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
