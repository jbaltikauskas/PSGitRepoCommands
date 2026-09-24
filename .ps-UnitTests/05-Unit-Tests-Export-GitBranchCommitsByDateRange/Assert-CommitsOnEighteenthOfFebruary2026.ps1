function Assert-CommitsOnEighteenthOfFebruary2026 () {
    <#
    .SYNOPSIS
        Asserts DbUp main commits whose author date falls on 2026-02-18.

    .DESCRIPTION
        Loads the inclusive author-date window for 2026-02-18 on main and throws
        unless the count, limit, tip identity, newest-first order, and each
        commit instant match that day. Returns the window and the newest commit.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .NOTES
        1. Load commits whose author date falls on 2026-02-18.
        2. Assert the default limit, the DbUp tip identity, and newest-first order.
        3. Assert every returned commit is inside the window.
        4. Return the window and the newest commit.

    .EXAMPLE
        PS> Assert-CommitsOnEighteenthOfFebruary2026 -libraryPath 'C:\repo\tests\Github\DbUp'
        Asserts the 2026-02-18 window and returns the newest commit.

        PS> $onDate = Assert-CommitsOnEighteenthOfFebruary2026 -libraryPath $libraryPath
        Stores the window so the filter and export sections can reuse it.
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

        [datetime]$rangeFrom = [datetime]'2026-02-18T00:00:00+10:00'
        [datetime]$rangeTo = [datetime]'2026-02-18T23:59:59+10:00'
        $byDate = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -fetch:$false -includePatch:$false
        $dateTip = @($byDate.Commits)[0]
        Write-Host 'Get-GitBranchCommitsByDateRange returns commits inside the default limit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byDate.CommitCount -ge 1 -and $byDate.CommitCount -le 20) -label 'Get-GitBranchCommitsByDateRange returns commits inside the default limit' -details $byDate.CommitCount
        Write-Host 'date lookup Limit is 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byDate.Limit -eq 20) -label 'date lookup Limit is 20'
        Write-Host 'date range number 1 is the DbUp main tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateTip.Hash -eq '41228ce747979fb52e1a59e3eec5823e6de869c8') -label 'date range number 1 is the DbUp main tip'
        Write-Host 'date range tip identity matches Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateTip.Author -eq 'Robert Wagner' -and $dateTip.AuthorEmail -eq 'robert@wagner.id.au' -and $dateTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $dateTip.Committer -eq 'Robert Wagner') -label 'date range tip identity matches Robert Wagner'

        if ($byDate.CommitCount -gt 1) {
            $olderDateCommit = @($byDate.Commits)[1]
            Write-Host 'date range commits are newest first' -ForegroundColor Cyan
            Assert-TestTrue -condition ([datetime]$dateTip.AuthorDate -ge [datetime]$olderDateCommit.AuthorDate) -label 'date range commits are newest first'
        }

        foreach ($dateCommit in @($byDate.Commits)) {
            [datetimeoffset]$commitInstant = [datetimeoffset]::Parse([string]$dateCommit.AuthorDate, [System.Globalization.CultureInfo]::InvariantCulture)
            [datetimeoffset]$fromOffset = [datetimeoffset]::new($rangeFrom)
            [datetimeoffset]$toOffset = [datetimeoffset]::new($rangeTo)
            Write-Host ("commit {0} is inside 2026-02-18" -f $dateCommit.Short) -ForegroundColor Cyan
            Assert-TestTrue -condition ($commitInstant -ge $fromOffset -and $commitInstant -le $toOffset) -label ("commit {0} is inside 2026-02-18" -f $dateCommit.Short) -details $dateCommit.AuthorDate
        }

        return [pscustomobject]@{
            RangeFrom = $rangeFrom
            RangeTo   = $rangeTo
            DateTip   = $dateTip
        }
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
