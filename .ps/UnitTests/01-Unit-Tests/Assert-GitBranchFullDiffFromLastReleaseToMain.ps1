function Assert-GitBranchFullDiffFromLastReleaseToMain () {
    <#
    .SYNOPSIS
        Asserts the DbUp full diff from the newest release branch to main.

    .DESCRIPTION
        Resolves tests/Github/DbUp, loads the full diff and commit diff from the
        newest release branch to main, and throws unless that range has files and
        commits. Returns the library path, release branch, target branch, and tip
        diff so later sections can export the same range.

    .PARAMETER repoPath
        Parent tests folder that contains Github\DbUp.

    .NOTES
        1. Resolve the library path and the newest release branch.
        2. Load the full diff and print its range, summary, and files.
        3. Assert the base branch, file count, and commit count.
        4. Return the library path, branches, and tip diff.

    .EXAMPLE
        PS> Assert-GitBranchFullDiffFromLastReleaseToMain -repoPath 'C:\repo\tests'
        Asserts the DbUp release-to-main diff and returns the tip object.

        PS> $fullDiff = Assert-GitBranchFullDiffFromLastReleaseToMain -repoPath $repoPath
        Stores the tip so the export section can reuse the same range.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Parent tests folder that contains Github\DbUp.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$libraryPath = Get-TestLibraryPath -repoPath $repoPath
        [string]$releaseBranch = Get-LastReleaseBranch -path $libraryPath
        [string]$diffTargetBranch = 'main'
        Write-Host ("libraryPath       = {0}" -f $libraryPath) -ForegroundColor DarkGray
        Write-Host ("lastReleaseBranch = {0}" -f $releaseBranch) -ForegroundColor DarkGray

        $tip = Get-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch $diffTargetBranch -direction TargetAhead -includePatch

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
        [string]$tipPathList = '(none)'

        if ($tipPaths.Count -gt 0) {
            $tipPathList = $tipPaths -join ', '
        }

        if ($tipPathList.Length -gt 240) {
            $tipPathList = $tipPathList.Substring(0, 240) + '...'
        }

        Write-Host ("Get-GitBranchFullDiff base is last release branch {0}" -f $releaseBranch) -ForegroundColor Cyan
        Assert-TestTrue -condition ($tip.BaseBranch -eq $releaseBranch) -label ("Get-GitBranchFullDiff base is last release branch {0}" -f $releaseBranch) -details ("Range={0}" -f $tip.Range)
        Write-Host ("Get-GitBranchFullDiff returns at least one changed file for {0}..{1}" -f $releaseBranch, $diffTargetBranch) -ForegroundColor Cyan
        Assert-TestTrue -condition ($tip.FileCount -ge 1) -label ("Get-GitBranchFullDiff returns at least one changed file for {0}..{1}" -f $releaseBranch, $diffTargetBranch) -details ("FileCount={0}; Paths=[{1}]" -f $tip.FileCount, $tipPathList)

        $commits = Get-GitBranchCommitDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch $diffTargetBranch -direction TargetAhead
        Write-Host ("Get-GitBranchCommitDiff has commits since {0}" -f $releaseBranch) -ForegroundColor Cyan
        Assert-TestTrue -condition ($commits.CommitCount -ge 1) -label ("Get-GitBranchCommitDiff has commits since {0}" -f $releaseBranch)

        return [pscustomobject]@{
            LibraryPath      = $libraryPath
            ReleaseBranch    = $releaseBranch
            DiffTargetBranch = $diffTargetBranch
            Tip              = $tip
        }
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
