function Assert-LatestCommitsOnDbUpMain () {
    <#
    .SYNOPSIS
        Asserts the default latest-20 list on DbUp main, plus limit and out-of-range number.

    .DESCRIPTION
        Loads the default latest commits on main and throws unless the count,
        newest-first order, tip identity, a limit of 3, and number 21 behave as
        expected. Returns the full hash of the main tip.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .NOTES
        1. Load the default latest commits and assert count, order, and tip identity.
        2. Assert a limit of 3 still starts at the branch tip.
        3. Assert commit number 21 throws because it is outside the default limit.
        4. Return the full hash of main.

    .EXAMPLE
        PS> Assert-LatestCommitsOnDbUpMain -libraryPath 'C:\repo\tests\Github\DbUp'
        Asserts the latest-20 list and returns the main tip hash.

        PS> $branchTip = Assert-LatestCommitsOnDbUpMain -libraryPath $libraryPath
        Stores the tip hash for the selection section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$branchTip = (git -C $libraryPath rev-parse main).Trim()
        $latest = Get-GitBranchCommitByID -path $libraryPath -branch main -fetch:$false -includePatch:$false
        $latestTip = @($latest.Commits)[0]
        $olderLatest = @($latest.Commits)[1]
        Write-Host 'Get-GitBranchCommitByID returns the default limit of 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($latest.CommitCount -eq 20) -label 'Get-GitBranchCommitByID returns the default limit of 20' -details $latest.CommitCount
        Write-Host 'commit lookup Limit is 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($latest.Limit -eq 20) -label 'commit lookup Limit is 20'
        Write-Host 'branch commits are newest first' -ForegroundColor Cyan
        Assert-TestTrue -condition ([datetime]$latestTip.AuthorDate -ge [datetime]$olderLatest.AuthorDate) -label 'branch commits are newest first'
        Write-Host 'commit number 1 in the list is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($latestTip.Number -eq 1 -and $latestTip.Hash -eq $branchTip) -label 'commit number 1 in the list is the branch tip'
        Write-Host 'latest tip identity matches Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($latestTip.Author -eq 'Robert Wagner' -and $latestTip.AuthorEmail -eq 'robert@wagner.id.au' -and $latestTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $latestTip.Committer -eq 'Robert Wagner') -label 'latest tip identity matches Robert Wagner'

        $limited = Get-GitBranchCommitByID -path $libraryPath -branch main -limit 3 -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -limit 3 returns three commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($limited.CommitCount -eq 3 -and $limited.Limit -eq 3) -label 'Get-GitBranchCommitByID -limit 3 returns three commits'
        Write-Host '-limit 3 still starts at the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition (@($limited.Commits)[0].Hash -eq $branchTip) -label '-limit 3 still starts at the branch tip'

        [bool]$numberPastLimit = $false

        try {

            Get-GitBranchCommitByID -path $libraryPath -branch main -number 21 -fetch:$false -includePatch:$false | Out-Null
        }
        catch {
            $numberPastLimit = $true
        }

        Write-Host 'commit number 21 is outside the default limit of 20' -ForegroundColor Cyan
        Assert-TestTrue -condition $numberPastLimit -label 'commit number 21 is outside the default limit of 20'

        return $branchTip
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
