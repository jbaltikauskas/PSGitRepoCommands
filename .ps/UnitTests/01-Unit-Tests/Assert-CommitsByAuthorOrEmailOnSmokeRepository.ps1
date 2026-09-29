function Assert-CommitsByAuthorOrEmailOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts author and email lookup, then writes the author export JSON.

    .DESCRIPTION
        Looks up commits by author name and by email on main, asserts the newest
        match, an unknown email, and the dated-folder export. Returns the newest
        matching commit so the date-range section can reuse it.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .PARAMETER exportTempPath
        Dated folder that receives the author export JSON.

    .NOTES
        1. Look up commits by author name and assert the newest match.
        2. Assert the email lookup matches and an unknown email returns none.
        3. Export the author JSON into the dated folder.
        4. Return the newest matching commit.

    .EXAMPLE
        PS> Assert-CommitsByAuthorOrEmailOnSmokeRepository -repoPath 'C:\repo\tests\20260923-2300' -exportTempPath 'C:\repo\tests\20260923-2300'
        Asserts author and email lookup and returns the newest commit.

        PS> $newest = Assert-CommitsByAuthorOrEmailOnSmokeRepository -repoPath $resolvedRepoPath -exportTempPath $exportTempPath
        Stores the newest author commit for the date-range section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root created for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the author export JSON.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportTempPath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -author 'test' -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitsByAuthorOrEmail -author finds commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byAuthor.CommitCount -ge 2) -label 'Get-GitBranchCommitsByAuthorOrEmail -author finds commits' -details $byAuthor.CommitCount
        $newestAuthorCommit = @($byAuthor.Commits)[0]
        Write-Host 'author commit 1 is the newest match' -ForegroundColor Cyan
        Assert-TestTrue -condition ($newestAuthorCommit.Number -eq 1) -label 'author commit 1 is the newest match'
        Write-Host 'author commit Author is test' -ForegroundColor Cyan
        Assert-TestTrue -condition ($newestAuthorCommit.Author -eq 'test') -label 'author commit Author is test'
        Write-Host 'author commit email is test@example.com' -ForegroundColor Cyan
        Assert-TestTrue -condition ($newestAuthorCommit.AuthorEmail -eq 'test@example.com') -label 'author commit email is test@example.com'

        $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -email 'TEST@example.com' -fetch:$false -includePatch:$false
        Write-Host 'email lookup returns the same commits as the author name' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byEmail.CommitCount -eq $byAuthor.CommitCount) -label 'email lookup returns the same commits as the author name' -details $byEmail.CommitCount

        $unknownEmail = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -email 'nobody@example.com' -fetch:$false -includePatch:$false
        Write-Host 'unknown email returns no commits' -ForegroundColor Cyan
        Assert-TestTrue -condition ($unknownEmail.CommitCount -eq 0) -label 'unknown email returns no commits'

        [string]$authorJsonPath = Join-Path -Path $exportTempPath -ChildPath 'author-commits.json'
        $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -author 'test' -fetch:$false -includePatch:$false -outputPath $authorJsonPath
        Write-Host 'Export-GitBranchCommitsByAuthorOrEmail JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitsByAuthorOrEmail JSON is in the dated test folder' -details $authorExport.JsonPath
        Write-Host 'author export CommitCount matches the lookup' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorExport.CommitCount -eq $byAuthor.CommitCount) -label 'author export CommitCount matches the lookup'

        return $newestAuthorCommit
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
