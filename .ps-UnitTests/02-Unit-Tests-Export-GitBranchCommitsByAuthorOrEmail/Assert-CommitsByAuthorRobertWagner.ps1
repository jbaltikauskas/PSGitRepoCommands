function Assert-CommitsByAuthorRobertWagner () {
    <#
    .SYNOPSIS
        Asserts the newest DbUp commits authored by Robert Wagner.

    .DESCRIPTION
        Returns the author lookup result, including the newest commit.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false
        $authorTip = @($byAuthor.Commits)[0]
        Assert-TestTrue -condition ($byAuthor.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -author returns the default limit of 20' -details $byAuthor.CommitCount
        Assert-TestTrue -condition ($byAuthor.Limit -eq 20) -label 'author lookup Limit is 20'
        $olderAuthorCommit = @($byAuthor.Commits)[1]
        Assert-TestTrue -condition ([datetime]$authorTip.AuthorDate -ge [datetime]$olderAuthorCommit.AuthorDate) -label 'author commits are newest first'
        Assert-TestTrue -condition ($authorTip.Author -eq 'Robert Wagner') -label 'author lookup Author is Robert Wagner'
        Assert-TestTrue -condition ($authorTip.AuthorEmail -eq 'robert@wagner.id.au') -label 'author lookup AuthorEmail is robert@wagner.id.au'
        Assert-TestTrue -condition ($authorTip.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'author lookup AuthorDate is 2026-02-18T13:55:32+10:00'
        Assert-TestTrue -condition ($authorTip.Committer -eq 'Robert Wagner') -label 'author lookup Committer is Robert Wagner'
        Assert-TestTrue -condition ($byAuthor.IncludePatch -eq $true) -label 'author lookup includes patch text'

        return $byAuthor
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
