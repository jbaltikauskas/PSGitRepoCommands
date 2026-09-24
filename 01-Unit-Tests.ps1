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
       The DbUp submodule under tests/ is left untouched.

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

function Initialize-TestGitRepository () {
    <#
    .SYNOPSIS
        Initializes a nested Git repo at RepoPath with main and feature/x.

    .DESCRIPTION
        Ensures RepoPath exists, replaces any prior nested .git at that path,
        then creates main with a.txt and feature/x with b.txt. Returns the
        resolved Git root. Does not delete sibling content such as DbUp.
        Throws when git commands fail or the nested toplevel is wrong.

    .PARAMETER repoPath
        Directory that becomes the Git root for smoke tests (default tests/).

    .NOTES
        1. Create RepoPath when missing; remove a prior nested .git if present.
        2. git init -b main, add a.txt, commit.
        3. Create feature/x with b.txt; switch back to main.
        4. Assert show-toplevel equals RepoPath; return it.

    .EXAMPLE
        PS> Initialize-TestGitRepository -repoPath '.\tests'
        Makes tests/ a nested Git root with main and feature/x.

        PS> $root = Initialize-TestGitRepository -repoPath $repoPath
        Stores the resolved Git root path in $root.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Directory to use as the Git root.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedRepoPath = [System.IO.Path]::GetFullPath($repoPath)

        if (-not (Test-Path -LiteralPath $resolvedRepoPath)) {
            New-Item -ItemType Directory -Path $resolvedRepoPath | Out-Null
        }

        [string]$gitDir = Join-Path -Path $resolvedRepoPath -ChildPath '.git'

        if (Test-Path -LiteralPath $gitDir) {
            Remove-Item -LiteralPath $gitDir -Recurse -Force
        }

        foreach ($fixtureName in @('a.txt', 'b.txt', 'diff-export.json')) {
            [string]$fixturePath = Join-Path -Path $resolvedRepoPath -ChildPath $fixtureName

            if (Test-Path -LiteralPath $fixturePath) {
                Remove-Item -LiteralPath $fixturePath -Force
            }
        }

        Push-Location -LiteralPath $resolvedRepoPath

        try {

            & git init -b main | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git init failed with exit code $LASTEXITCODE"
            }

            'init' | Set-Content -LiteralPath (Join-Path -Path $resolvedRepoPath -ChildPath 'a.txt') -Encoding utf8NoBOM
            & git add a.txt | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git add failed with exit code $LASTEXITCODE"
            }

            & git -c user.email=test@example.com -c user.name=test commit -m 'init' | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git commit failed with exit code $LASTEXITCODE"
            }

            & git branch feature/x | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git branch feature/x failed with exit code $LASTEXITCODE"
            }

            & git switch feature/x | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git switch feature/x failed with exit code $LASTEXITCODE"
            }

            'feature' | Set-Content -LiteralPath (Join-Path -Path $resolvedRepoPath -ChildPath 'b.txt') -Encoding utf8NoBOM
            & git add b.txt | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git add b.txt failed with exit code $LASTEXITCODE"
            }

            & git -c user.email=test@example.com -c user.name=test commit -m 'add b' | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git commit add b failed with exit code $LASTEXITCODE"
            }

            & git switch main | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git switch main failed with exit code $LASTEXITCODE"
            }

            [string]$toplevel = (& git rev-parse --show-toplevel).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw "git rev-parse --show-toplevel failed with exit code $LASTEXITCODE"
            }

            [string]$normalizedToplevel = [System.IO.Path]::GetFullPath($toplevel)
            if ($normalizedToplevel -ne $resolvedRepoPath) {
                throw "Expected Git root '$resolvedRepoPath' but got '$normalizedToplevel'"
            }
        }
        finally {
            Pop-Location
        }

        return $resolvedRepoPath
    }
}

function Clear-TestGitRepository () {
    <#
    .SYNOPSIS
        Removes the nested smoke-test Git metadata and fixture files.

    .DESCRIPTION
        Deletes the dated run folder (RepoPath) created for this smoke test,
        including its .git directory and fixture files. Does not delete the
        parent tests/ folder or siblings such as DbUp.

    .PARAMETER repoPath
        Nested Git root created for smoke tests.

    .NOTES
        1. Resolve RepoPath.
        2. Remove the dated run folder when it exists.

    .EXAMPLE
        PS> Clear-TestGitRepository -repoPath '.\tests\20260921-0013'
        Removes that dated run folder.

        PS> Clear-TestGitRepository -repoPath $resolvedRepoPath
        Cleans the resolved smoke-test Git root.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root to clean.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedRepoPath = [System.IO.Path]::GetFullPath($repoPath)

        if (Test-Path -LiteralPath $resolvedRepoPath) {
            Remove-Item -LiteralPath $resolvedRepoPath -Recurse -Force
        }
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
[string]$exportTempPath = $null

try {

    Write-Host 'BEGIN: Settings' -ForegroundColor Yellow
    Write-Host ("modulePath         = {0}" -f $modulePath) -ForegroundColor DarkGray
    Write-Host ("resolvedModulePath = {0}" -f $resolvedModulePath) -ForegroundColor DarkGray
    Write-Host ("repoPath           = {0}" -f $repoPath) -ForegroundColor DarkGray
    Write-Host ("noPause            = {0}" -f $noPause.IsPresent) -ForegroundColor DarkGray
    Write-Host ("keepTempRepo       = {0}" -f $keepTempRepo) -ForegroundColor DarkGray
    $PSBoundParameters | Out-String | Write-Host
    Write-Host 'END: Settings' -ForegroundColor Yellow

    if (-not (Test-Path -LiteralPath $resolvedModulePath)) {
        throw "PSGitRepoCommands manifest not found: $resolvedModulePath"
    }

    Write-Section -message 'Import PSGitRepoCommands'
    Import-Module -Name $resolvedModulePath -Force

    [string[]]$exported = @(Get-Command -Module PSGitRepoCommands | Select-Object -ExpandProperty Name | Sort-Object)
    Write-Host ("Exported commands ({0}): {1}" -f $exported.Count, ($exported -join ', ')) -ForegroundColor DarkGray
    Assert-TestTrue -condition ($exported.Count -ge 19) -label 'module exports at least 19 commands'
    Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitByID') -label 'Get-GitBranchCommitByID is exported'
    Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitByID') -label 'Export-GitBranchCommitByID is exported'
    Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByAuthorOrEmail') -label 'Get-GitBranchCommitsByAuthorOrEmail is exported'
    Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByAuthorOrEmail') -label 'Export-GitBranchCommitsByAuthorOrEmail is exported'
    Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByDateRange') -label 'Get-GitBranchCommitsByDateRange is exported'
    Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByDateRange') -label 'Export-GitBranchCommitsByDateRange is exported'

    Write-Section -message 'Create dated test folder under tests/'
    [string]$runFolder = New-TestRunFolder -parentPath $repoPath
    Write-Host ("runFolder = {0}" -f $runFolder) -ForegroundColor DarkGray

    Write-Section -message 'Initialize Git root'
    $resolvedRepoPath = Initialize-TestGitRepository -repoPath $runFolder
    Write-Host ("resolvedRepoPath = {0}" -f $resolvedRepoPath) -ForegroundColor DarkGray

    Write-Section -message 'Branch read cmdlets'
    $current = Get-GitCurrentBranch -path $resolvedRepoPath
    Assert-TestTrue -condition ($current.Name -eq 'main') -label 'Get-GitCurrentBranch is main'
    Assert-TestTrue -condition ($current.IsCurrent -eq $true) -label 'Get-GitCurrentBranch.IsCurrent'

    $branches = @(Get-GitBranch -path $resolvedRepoPath)
    Assert-TestTrue -condition ($branches.Count -ge 2) -label 'Get-GitBranch lists local branches'

    $mainExists = Test-GitBranch -path $resolvedRepoPath -name 'main'
    Assert-TestTrue -condition ($mainExists.Exists -eq $true) -label 'Test-GitBranch main exists'

    $missing = Test-GitBranch -path $resolvedRepoPath -name 'no-such-branch-xyz'
    Assert-TestTrue -condition ($missing.Exists -eq $false) -label 'Test-GitBranch missing is false'

    Write-Section -message 'Branch mutate cmdlets'
    $created = New-GitBranch -path $resolvedRepoPath -name 'feature/y' -startPoint 'main'
    Assert-TestTrue -condition ($created.Name -eq 'feature/y') -label 'New-GitBranch feature/y'
    Assert-TestTrue -condition ($created.Switched -eq $false) -label 'New-GitBranch did not switch'

    $switched = Switch-GitBranch -path $resolvedRepoPath -name 'feature/y'
    Assert-TestTrue -condition ($switched.Name -eq 'feature/y') -label 'Switch-GitBranch feature/y'

    $renamed = Rename-GitBranch -path $resolvedRepoPath -newName 'feature/z'
    Assert-TestTrue -condition ($renamed.NewName -eq 'feature/z') -label 'Rename-GitBranch to feature/z'

    $compare = Compare-GitBranch -path $resolvedRepoPath -baseBranch 'main' -compareBranch 'feature/x'
    Assert-TestTrue -condition ($null -ne $compare.Ahead) -label 'Compare-GitBranch returns Ahead'
    Assert-TestTrue -condition ($null -ne $compare.Behind) -label 'Compare-GitBranch returns Behind'

    Switch-GitBranch -path $resolvedRepoPath -name 'main' | Out-Null
    $removed = Remove-GitBranch -path $resolvedRepoPath -name 'feature/z' -force
    Assert-TestTrue -condition ($removed.LocalDeleted -eq $true) -label 'Remove-GitBranch feature/z'

    Write-Section -message 'Export JSON folder'
    $exportTempPath = $resolvedRepoPath
    Write-Host ("exportTempPath = {0}" -f $exportTempPath) -ForegroundColor DarkGray

    Write-Section -message 'Commit work items'
    & git -C $resolvedRepoPath -c user.email=test@example.com -c user.name=test commit --allow-empty -m 'Fix login button alignment #12345 and #56985 #12345' -m 'Fix login validation bug AB#12345 and AB#77 and AB#12345' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git commit for work items failed with exit code $LASTEXITCODE"
    }

    $workCommit = Get-GitBranchCommitByID -path $resolvedRepoPath -branch main -number 1 -fetch:$false -includePatch:$false
    [string]$workItemList = (@($workCommit.WorkItems) -join ',')
    Assert-TestTrue -condition ($workItemList -eq '#12345,#56985,AB#12345,AB#77') -label 'WorkItems keeps unique original keys #id and AB#id' -details $workItemList

    [string]$workJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.json' -f $workCommit.Short)
    $workExport = Export-GitBranchCommitByID -path $resolvedRepoPath -branch main -shortHash $workCommit.Short -fetch:$false -includePatch:$false -outputPath $workJsonPath
    Assert-TestTrue -condition ($workExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID work-item JSON is in the dated test folder' -details $workExport.JsonPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workExport.JsonPath) -eq ('{0}-work-items.json' -f $workCommit.Short)) -label 'work-item JSON name starts with the commit short hash' -details $workExport.JsonPath
    $workJson = Get-Content -LiteralPath $workExport.JsonPath -Raw | ConvertFrom-Json
    [string]$exportedWorkItems = (@($workJson.Commit.WorkItems) -join ',')
    Assert-TestTrue -condition ($exportedWorkItems -eq $workItemList) -label 'Export JSON includes the WorkItems array' -details $exportedWorkItems

    $workPatchCommit = Get-GitBranchCommitByID -path $resolvedRepoPath -branch main -shortHash $workCommit.Short -fetch:$false
    [string]$workPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.patch' -f $workCommit.Short)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($workPatchPath, ([string]$workPatchCommit.Patch + "`n"), $utf8NoBom)
    Assert-TestTrue -condition (Test-Path -LiteralPath $workPatchPath) -label 'work-item patch file is in the dated test folder' -details $workPatchPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workPatchPath) -eq ('{0}-work-items.patch' -f $workCommit.Short)) -label 'work-item patch name starts with the commit short hash' -details $workPatchPath
    Assert-TestTrue -condition ((Get-Content -LiteralPath $workPatchPath -Raw).Contains($workCommit.Hash)) -label 'work-item patch contains the commit hash'

    Write-Section -message 'Commits by author or email'
    $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $resolvedRepoPath -branch main -author 'test' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byAuthor.CommitCount -ge 2) -label 'Get-GitBranchCommitsByAuthorOrEmail -author finds commits' -details $byAuthor.CommitCount
    $newestAuthorCommit = @($byAuthor.Commits)[0]
    Assert-TestTrue -condition ($newestAuthorCommit.Number -eq 1) -label 'author commit 1 is the newest match'
    Assert-TestTrue -condition ($newestAuthorCommit.Author -eq 'test') -label 'author commit Author is test'
    Assert-TestTrue -condition ($newestAuthorCommit.AuthorEmail -eq 'test@example.com') -label 'author commit email is test@example.com'

    $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $resolvedRepoPath -branch main -email 'TEST@example.com' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byEmail.CommitCount -eq $byAuthor.CommitCount) -label 'email lookup returns the same commits as the author name' -details $byEmail.CommitCount

    $unknownEmail = Get-GitBranchCommitsByAuthorOrEmail -path $resolvedRepoPath -branch main -email 'nobody@example.com' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($unknownEmail.CommitCount -eq 0) -label 'unknown email returns no commits'

    [string]$authorJsonPath = Join-Path -Path $exportTempPath -ChildPath 'author-commits.json'
    $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $resolvedRepoPath -branch main -author 'test' -fetch:$false -includePatch:$false -outputPath $authorJsonPath
    Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitsByAuthorOrEmail JSON is in the dated test folder' -details $authorExport.JsonPath
    Assert-TestTrue -condition ($authorExport.CommitCount -eq $byAuthor.CommitCount) -label 'author export CommitCount matches the lookup'

    Write-Section -message 'Commits by date range'
    [datetime]$rangeFrom = ([datetime]$newestAuthorCommit.AuthorDate).AddDays(-1)
    [datetime]$rangeTo = ([datetime]$newestAuthorCommit.AuthorDate).AddDays(1)
    $byDate = Get-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeFrom -to $rangeTo -fetch:$false -includePatch:$false
    $newestDateCommit = @($byDate.Commits)[0]
    Assert-TestTrue -condition ($byDate.CommitCount -ge 1) -label 'Get-GitBranchCommitsByDateRange finds commits in the range' -details $byDate.CommitCount
    Assert-TestTrue -condition ($newestDateCommit.Hash -eq $newestAuthorCommit.Hash) -label 'date range number 1 is the newest author commit'
    Assert-TestTrue -condition ([datetime]$newestDateCommit.AuthorDate -ge $rangeFrom -and [datetime]$newestDateCommit.AuthorDate -le $rangeTo) -label 'newest date-range commit is inside the inclusive bounds'

    $byDateAuthor = Get-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeFrom -to $rangeTo -author 'test' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byDateAuthor.CommitCount -eq $byDate.CommitCount) -label 'date range with -author test matches the unfiltered range' -details $byDateAuthor.CommitCount

    $byDateEmail = Get-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeFrom -to $rangeTo -email 'TEST@example.com' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition (@($byDateEmail.Commits)[0].Hash -eq $newestDateCommit.Hash) -label 'date range with -email matches the newest commit'

    $byDateNobody = Get-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeFrom -to $rangeTo -email 'nobody@example.com' -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byDateNobody.CommitCount -eq 0) -label 'date range with an unknown email returns no commits'

    $future = Get-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeTo.AddDays(1) -to $rangeTo.AddDays(2) -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($future.CommitCount -eq 0) -label 'a future date range returns no commits'

    [string]$dateJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-date-commits.json' -f $newestDateCommit.Short)
    $dateExport = Export-GitBranchCommitsByDateRange -path $resolvedRepoPath -branch main -from $rangeFrom -to $rangeTo -author 'test' -fetch:$false -includePatch:$false -outputPath $dateJsonPath
    Assert-TestTrue -condition ($dateExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitsByDateRange JSON is in the dated test folder' -details $dateExport.JsonPath
    Assert-TestTrue -condition ($dateExport.CommitCount -eq $byDateAuthor.CommitCount) -label 'date export CommitCount matches the date lookup'

    Write-Section -message 'Branch diff cmdlets'
    [string]$libraryPath = Join-Path -Path ([System.IO.Path]::GetFullPath($repoPath)) -ChildPath 'DbUp'
    [string]$releaseBranch = Get-LastReleaseBranch -path $libraryPath
    [string]$diffBaseBranch = $releaseBranch
    [string]$diffTargetBranch = 'main'
    Write-Host ("libraryPath       = {0}" -f $libraryPath) -ForegroundColor DarkGray
    Write-Host ("lastReleaseBranch = {0}" -f $releaseBranch) -ForegroundColor DarkGray

    $tip = Get-GitBranchFullDiff -path $libraryPath -baseBranch $diffBaseBranch -targetBranch $diffTargetBranch -direction TargetAhead -includePatch

    Write-Host ("Tip diff range: {0} ({1})" -f $tip.Range, $tip.RangeDescription) -ForegroundColor DarkGray
    Write-Host ("Tip FileCount:  {0}" -f $tip.FileCount) -ForegroundColor DarkGray

    if (-not [string]::IsNullOrWhiteSpace([string]$tip.Summary)) {
        Write-Host 'Tip Summary:' -ForegroundColor DarkGray
        Write-Host ([string]$tip.Summary) -ForegroundColor DarkGray
    }

    if ($null -ne $tip.Files -and $tip.Files.Count -gt 0) {
        Write-Host 'Tip Files:' -ForegroundColor DarkGray
        $tip.Files | Select-Object -First 20 | Format-Table -Property Status, Path, OldPath, Additions, Deletions -AutoSize | Out-String | Write-Host -ForegroundColor DarkGray
    }

    [string[]]$tipPaths = @($tip.Files | Select-Object -ExpandProperty Path)
    [string]$tipPathList = if ($tipPaths.Count -gt 0) { $tipPaths -join ', ' } else { '(none)' }
    if ($tipPathList.Length -gt 240) {
        $tipPathList = $tipPathList.Substring(0, 240) + '...'
    }

    Assert-TestTrue `
        -condition ($tip.BaseBranch -eq $releaseBranch) `
        -label ("Get-GitBranchFullDiff base is last release branch {0}" -f $releaseBranch) `
        -details ("Range={0}" -f $tip.Range)

    Assert-TestTrue `
        -condition ($tip.FileCount -ge 1) `
        -label ("Get-GitBranchFullDiff returns at least one changed file for {0}..{1}" -f $releaseBranch, $diffTargetBranch) `
        -details ("FileCount={0}; Paths=[{1}]" -f $tip.FileCount, $tipPathList)

    $commits = Get-GitBranchCommitDiff -path $libraryPath -baseBranch $diffBaseBranch -targetBranch $diffTargetBranch -direction TargetAhead
    Assert-TestTrue -condition ($commits.CommitCount -ge 1) -label ("Get-GitBranchCommitDiff has commits since {0}" -f $releaseBranch)

    [string]$branchTip = (git -C $libraryPath rev-parse $diffTargetBranch).Trim()
    $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -number 1 -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byNumber.Branch -eq $diffTargetBranch) -label 'Get-GitBranchCommitByID uses the requested branch'
    Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'

    $byShort = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byShort.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -shortHash matches the same commit'

    $byFull = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -hash $byNumber.Hash -fetch:$false -includePatch:$false
    Assert-TestTrue -condition ($byFull.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -hash full hash matches the same commit'

    [string]$commitJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
    $commitExport = Export-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $commitJsonPath
    Assert-TestTrue -condition (Test-Path -LiteralPath $commitExport.JsonPath) -label 'Export-GitBranchCommitByID wrote JSON'
    Assert-TestTrue -condition ($commitExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID JSON is in the dated test folder' -details $commitExport.JsonPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitExport.JsonPath) -eq ('{0}-commit-export.json' -f $byNumber.Short)) -label 'commit export JSON name starts with the commit short hash' -details $commitExport.JsonPath
    Assert-TestTrue -condition ($commitExport.Commit.Hash -eq $branchTip) -label 'Export-GitBranchCommitByID commit is the branch tip'

    $commitPatch = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false
    [string]$commitPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.patch' -f $byNumber.Short)
    [System.IO.File]::WriteAllText($commitPatchPath, ([string]$commitPatch.Patch + "`n"), $utf8NoBom)
    Assert-TestTrue -condition (Test-Path -LiteralPath $commitPatchPath) -label 'commit patch file is in the dated test folder' -details $commitPatchPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitPatchPath) -eq ('{0}-commit-export.patch' -f $byNumber.Short)) -label 'commit patch name starts with the commit short hash' -details $commitPatchPath
    Assert-TestTrue -condition ((Get-Content -LiteralPath $commitPatchPath -Raw).Contains($byNumber.Hash)) -label 'commit patch contains the commit hash'

    [string]$jsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.json' -f $byNumber.Short)
    $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $diffBaseBranch -targetBranch $diffTargetBranch -direction TargetAhead -outputPath $jsonPath
    Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON'
    Assert-TestTrue -condition ($export.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchFullDiff JSON is in the dated test folder' -details $export.JsonPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($export.JsonPath) -eq ('{0}-diff-export.json' -f $byNumber.Short)) -label 'diff export JSON name starts with the target tip short hash' -details $export.JsonPath

    [string]$diffPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.patch' -f $byNumber.Short)
    [System.IO.File]::WriteAllText($diffPatchPath, ([string]$tip.Patch + "`n"), $utf8NoBom)
    Assert-TestTrue -condition (Test-Path -LiteralPath $diffPatchPath) -label 'diff patch file is in the dated test folder' -details $diffPatchPath
    Assert-TestTrue -condition ([System.IO.Path]::GetFileName($diffPatchPath) -eq ('{0}-diff-export.patch' -f $byNumber.Short)) -label 'diff patch name starts with the target tip short hash' -details $diffPatchPath
    Assert-TestTrue -condition ((Get-Item -LiteralPath $diffPatchPath).Length -gt 0) -label 'diff patch file is not empty'

    Write-Section -message 'Cleanup'
    if ($keepTempRepo) {
        Write-Host ("Keeping dated test folder: {0}" -f $resolvedRepoPath) -ForegroundColor Yellow
    }
    else {
        Clear-TestGitRepository -repoPath $resolvedRepoPath
        Write-Host 'Removed dated test folder under tests/.' -ForegroundColor Green
        $resolvedRepoPath = $null
        $exportTempPath = $null
    }
}
catch {

    Write-Host ''
    Write-Host 'Script failed to execute.' -ForegroundColor Red
    Write-Host ("Exception: {0}" -f $_.Exception.GetType().FullName) -ForegroundColor Red
    Write-Host ("Message:   {0}" -f $_.Exception.Message) -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($resolvedRepoPath)) {
        Write-Host ("Nested Git root left at: {0}" -f $resolvedRepoPath) -ForegroundColor Yellow
    }

    if (-not $noPause.IsPresent) {
        Read-Host 'Press Enter to close'
    }

    exit 1
}

Write-Host ''
Write-Host 'Script executed successfully.' -ForegroundColor Green
