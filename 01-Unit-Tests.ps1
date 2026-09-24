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

    Write-Section -message 'Import PSGitRepoCommands'
    Import-TestModule -modulePath $resolvedModulePath

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
    [string]$libraryPath = Get-TestLibraryPath -repoPath $repoPath
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
