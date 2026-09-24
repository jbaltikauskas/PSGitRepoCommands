<#
.SYNOPSIS
    Smoke-tests Export-GitBranchFullDiff from the last release branch to main.

.DESCRIPTION
    1. Resolve the PSGitRepoCommands manifest path (default under this repo).
    2. Print BEGIN/END Settings including bound parameters and resolved paths.
    3. Import the module with -Force.
    4. Create a dated folder under tests/ named yyyyMMdd-HHmm for the JSON export.
    5. Resolve the newest release/* branch in tests/DbUp.
    6. Write Export-GitBranchFullDiff JSON for that release versus main into the dated folder.
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

function Get-LastReleaseBranch () {
    <#
    .SYNOPSIS
        Returns the highest-version release/* branch in a repository.

    .DESCRIPTION
        Lists local refs/heads/release and origin/release refs, strips a remote
        prefix, and returns the release/name with the highest version (git
        version:refname order). Throws when no release branch exists.

    .PARAMETER path
        Repository that contains release branches (for example tests/DbUp).

    .NOTES
        1. List release refs sorted by version descending.
        2. Normalize origin/release/x to release/x.
        3. Return the first unique name, or throw.

    .EXAMPLE
        PS> Get-LastReleaseBranch -path '.\tests\DbUp'
        Returns release/6.0.0 when that is the newest release branch.

        PS> $name = Get-LastReleaseBranch -path $libraryPath
        Stores the last release branch name in $name.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Repository path to search for release/* branches.")]
        [ValidateNotNullOrEmpty()]
        [string]$path
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = [System.IO.Path]::GetFullPath($path)

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
            throw "Directory not found: '$resolvedPath'"
        }

        [string[]]$raw = @(& git -C $resolvedPath for-each-ref --sort=-version:refname --format='%(refname:short)' 'refs/heads/release' 'refs/remotes/origin/release')
        if ($LASTEXITCODE -ne 0) {
            throw "git for-each-ref failed with exit code $LASTEXITCODE"
        }

        [System.Collections.Generic.List[string]]$names = [System.Collections.Generic.List[string]]::new()

        foreach ($line in $raw) {
            [string]$name = $line.Trim()

            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            if ($name -match '^(?:[^/]+/)?(release/.+)$') {
                $name = $Matches[1]
            }

            if (-not $names.Contains($name)) {
                $names.Add($name)
            }
        }

        if ($names.Count -lt 1) {
            throw "No release/* branch found under '$resolvedPath'."
        }

        return $names[0]
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

    Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name 'Export-GitBranchFullDiff' -ErrorAction SilentlyContinue)) -label 'Export-GitBranchFullDiff is exported'

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
