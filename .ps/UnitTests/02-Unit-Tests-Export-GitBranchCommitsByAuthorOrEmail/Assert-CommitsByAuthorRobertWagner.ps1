function Assert-CommitsByAuthorRobertWagner () {
    <#
    .SYNOPSIS
        Asserts the newest DbUp commits authored by Robert Wagner.

    .DESCRIPTION
        Looks up commits by author name on main and throws unless the default
        limit, newest-first order, tip identity, and patch text match the DbUp
        fixture. Returns the author lookup result, including the newest commit.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .NOTES
        1. Look up commits authored by Robert Wagner.
        2. Assert the default limit, newest-first order, and tip identity.
        3. Return the lookup result.

    .EXAMPLE
        PS> Assert-CommitsByAuthorRobertWagner -libraryPath 'C:\repo\tests\Github\DbUp'
        Asserts the Robert Wagner author lookup and returns it.

        PS> $byAuthor = Assert-CommitsByAuthorRobertWagner -libraryPath $libraryPath
        Stores the lookup so the email and export sections can reuse the tip.
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

        $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false
        $authorTip = @($byAuthor.Commits)[0]
        Write-Host 'Get-GitBranchCommitsByAuthorOrEmail -author returns the default limit of 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byAuthor.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -author returns the default limit of 20' -details $byAuthor.CommitCount
        Write-Host 'author lookup Limit is 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byAuthor.Limit -eq 20) -label 'author lookup Limit is 20'
        $olderAuthorCommit = @($byAuthor.Commits)[1]
        Write-Host 'author commits are newest first' -ForegroundColor Cyan
        Assert-TestTrue -condition ([datetime]$authorTip.AuthorDate -ge [datetime]$olderAuthorCommit.AuthorDate) -label 'author commits are newest first'
        Write-Host 'author lookup Author is Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorTip.Author -eq 'Robert Wagner') -label 'author lookup Author is Robert Wagner'
        Write-Host 'author lookup AuthorEmail is robert@wagner.id.au' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorTip.AuthorEmail -eq 'robert@wagner.id.au') -label 'author lookup AuthorEmail is robert@wagner.id.au'
        Write-Host 'author lookup AuthorDate is 2026-02-18T13:55:32+10:00' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorTip.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'author lookup AuthorDate is 2026-02-18T13:55:32+10:00'
        Write-Host 'author lookup Committer is Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorTip.Committer -eq 'Robert Wagner') -label 'author lookup Committer is Robert Wagner'
        Write-Host 'author lookup includes patch text' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byAuthor.IncludePatch -eq $true) -label 'author lookup includes patch text'

        return $byAuthor
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
