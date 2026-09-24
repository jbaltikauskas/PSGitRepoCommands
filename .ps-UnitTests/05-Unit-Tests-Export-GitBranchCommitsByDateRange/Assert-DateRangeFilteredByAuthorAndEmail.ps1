function Assert-DateRangeFilteredByAuthorAndEmail () {
    <#
    .SYNOPSIS
        Asserts the 2026-02-18 window filtered by Robert Wagner's name and email.

    .DESCRIPTION
        Filters the author-date window by name and by email, and throws unless
        both keep DateTip and a future window returns no commits. Returns the
        author-filtered lookup so the export section can compare counts.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER rangeFrom
        Inclusive start of the author-date window.

    .PARAMETER rangeTo
        Inclusive end of the author-date window.

    .PARAMETER dateTip
        Newest commit from the unfiltered date window.

    .NOTES
        1. Filter the window by author name and assert the newest commit.
        2. Filter the window by email and assert the newest commit.
        3. Assert a future window returns no commits.
        4. Return the author-filtered lookup.

    .EXAMPLE
        PS> Assert-DateRangeFilteredByAuthorAndEmail -libraryPath 'C:\repo\tests\Github\DbUp' -rangeFrom $from -rangeTo $to -dateTip $tip
        Asserts the author and email filters and returns the author lookup.

        PS> $byAuthor = Assert-DateRangeFilteredByAuthorAndEmail -libraryPath $libraryPath -rangeFrom $onDate.RangeFrom -rangeTo $onDate.RangeTo -dateTip $onDate.DateTip
        Stores the author-filtered lookup for the export section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Inclusive start of the author-date window.")]
        [datetime]$rangeFrom,

        [Parameter(Mandatory = $true, HelpMessage = "Inclusive end of the author-date window.")]
        [datetime]$rangeTo,

        [Parameter(Mandatory = $true, HelpMessage = "Newest commit from the unfiltered date window.")]
        [ValidateNotNull()]
        [psobject]$dateTip
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $byAuthor = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -author 'Robert Wagner' -fetch:$false -includePatch:$false
        $authorTip = @($byAuthor.Commits)[0]
        Write-Host 'author filter keeps the same newest commit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorTip.Hash -eq $dateTip.Hash) -label 'author filter keeps the same newest commit'
        Write-Host 'date lookup stores the author filter' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byAuthor.Author -eq 'Robert Wagner') -label 'date lookup stores the author filter'

        $byEmail = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -email 'robert@wagner.id.au' -fetch:$false -includePatch:$false
        $emailTip = @($byEmail.Commits)[0]
        Write-Host 'email filter keeps the same newest commit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($emailTip.Hash -eq $dateTip.Hash) -label 'email filter keeps the same newest commit'
        Write-Host 'date lookup stores the email filter' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byEmail.Email -eq 'robert@wagner.id.au') -label 'date lookup stores the email filter'

        $empty = Get-GitBranchCommitsByDateRange -path $libraryPath -branch main -from ([datetime]'2099-01-01') -to ([datetime]'2099-01-02') -fetch:$false -includePatch:$false
        Write-Host 'a future date range returns no commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($empty.CommitCount -eq 0) -label 'a future date range returns no commits'

        return $byAuthor
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
