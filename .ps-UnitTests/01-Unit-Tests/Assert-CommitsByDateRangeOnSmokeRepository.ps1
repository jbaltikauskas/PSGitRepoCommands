function Assert-CommitsByDateRangeOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts an inclusive author-date window around the newest author commit.

    .DESCRIPTION
        Builds a one-day window around NewestAuthorCommit, then asserts the
        unfiltered range, author and email filters, an unknown email, a future
        window, and the dated-folder export. Throws when a check fails.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .PARAMETER exportTempPath
        Dated folder that receives the date-range export JSON.

    .PARAMETER newestAuthorCommit
        Newest commit returned by the author lookup section.

    .NOTES
        1. Query the inclusive window around the newest author commit.
        2. Assert author and email filters, an unknown email, and a future window.
        3. Export the author-filtered range into the dated folder.

    .EXAMPLE
        PS> Assert-CommitsByDateRangeOnSmokeRepository -repoPath 'C:\repo\tests\20260923-2300' -exportTempPath 'C:\repo\tests\20260923-2300' -newestAuthorCommit $commit
        Asserts the date window and writes the export JSON.

        PS> Assert-CommitsByDateRangeOnSmokeRepository -repoPath $resolvedRepoPath -exportTempPath $exportTempPath -newestAuthorCommit $newestAuthorCommit
        Same checks using the commit returned by the author section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root created for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the date-range export JSON.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportTempPath,

        [Parameter(Mandatory = $true, HelpMessage = "Newest commit returned by the author lookup section.")]
        [ValidateNotNull()]
        [psobject]$newestAuthorCommit
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [datetime]$rangeFrom = ([datetime]$newestAuthorCommit.AuthorDate).AddDays(-1)
        [datetime]$rangeTo = ([datetime]$newestAuthorCommit.AuthorDate).AddDays(1)
        $byDate = Get-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeFrom -to $rangeTo -fetch:$false -includePatch:$false
        $newestDateCommit = @($byDate.Commits)[0]
        Write-Host 'Get-GitBranchCommitsByDateRange finds commits in the range' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byDate.CommitCount -ge 1) -label 'Get-GitBranchCommitsByDateRange finds commits in the range' -details $byDate.CommitCount
        Write-Host 'date range number 1 is the newest author commit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($newestDateCommit.Hash -eq $newestAuthorCommit.Hash) -label 'date range number 1 is the newest author commit'
        Write-Host 'newest date-range commit is inside the inclusive bounds' -ForegroundColor Cyan
        Assert-TestTrue -condition ([datetime]$newestDateCommit.AuthorDate -ge $rangeFrom -and [datetime]$newestDateCommit.AuthorDate -le $rangeTo) -label 'newest date-range commit is inside the inclusive bounds'

        $byDateAuthor = Get-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeFrom -to $rangeTo -author 'test' -fetch:$false -includePatch:$false
        Write-Host 'date range with -author test matches the unfiltered range' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byDateAuthor.CommitCount -eq $byDate.CommitCount) -label 'date range with -author test matches the unfiltered range' -details $byDateAuthor.CommitCount

        $byDateEmail = Get-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeFrom -to $rangeTo -email 'TEST@example.com' -fetch:$false -includePatch:$false
        Write-Host 'date range with -email matches the newest commit' -ForegroundColor Cyan
        Assert-TestTrue -condition (@($byDateEmail.Commits)[0].Hash -eq $newestDateCommit.Hash) -label 'date range with -email matches the newest commit'

        $byDateNobody = Get-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeFrom -to $rangeTo -email 'nobody@example.com' -fetch:$false -includePatch:$false
        Write-Host 'date range with an unknown email returns no commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byDateNobody.CommitCount -eq 0) -label 'date range with an unknown email returns no commits'

        $future = Get-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeTo.AddDays(1) -to $rangeTo.AddDays(2) -fetch:$false -includePatch:$false
        Write-Host 'a future date range returns no commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($future.CommitCount -eq 0) -label 'a future date range returns no commits'

        [string]$dateJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-date-commits.json' -f $newestDateCommit.Short)
        $dateExport = Export-GitBranchCommitsByDateRange -path $repoPath -branch main -from $rangeFrom -to $rangeTo -author 'test' -fetch:$false -includePatch:$false -outputPath $dateJsonPath
        Write-Host 'Export-GitBranchCommitsByDateRange JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitsByDateRange JSON is in the dated test folder' -details $dateExport.JsonPath
        Write-Host 'date export CommitCount matches the date lookup' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateExport.CommitCount -eq $byDateAuthor.CommitCount) -label 'date export CommitCount matches the date lookup'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
