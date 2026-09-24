function Assert-CommitsByAuthorOrEmailOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts author and email lookup, then writes the author export JSON.

    .DESCRIPTION
        Returns the newest matching commit so the date-range section can reuse it.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .PARAMETER exportTempPath
        Dated folder that receives the author export JSON.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $byAuthor = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -author 'test' -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byAuthor.CommitCount -ge 2) -label 'Get-GitBranchCommitsByAuthorOrEmail -author finds commits' -details $byAuthor.CommitCount
        $newestAuthorCommit = @($byAuthor.Commits)[0]
        Assert-TestTrue -condition ($newestAuthorCommit.Number -eq 1) -label 'author commit 1 is the newest match'
        Assert-TestTrue -condition ($newestAuthorCommit.Author -eq 'test') -label 'author commit Author is test'
        Assert-TestTrue -condition ($newestAuthorCommit.AuthorEmail -eq 'test@example.com') -label 'author commit email is test@example.com'

        $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -email 'TEST@example.com' -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byEmail.CommitCount -eq $byAuthor.CommitCount) -label 'email lookup returns the same commits as the author name' -details $byEmail.CommitCount

        $unknownEmail = Get-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -email 'nobody@example.com' -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($unknownEmail.CommitCount -eq 0) -label 'unknown email returns no commits'

        [string]$authorJsonPath = Join-Path -Path $exportTempPath -ChildPath 'author-commits.json'
        $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $repoPath -branch main -author 'test' -fetch:$false -includePatch:$false -outputPath $authorJsonPath
        Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitsByAuthorOrEmail JSON is in the dated test folder' -details $authorExport.JsonPath
        Assert-TestTrue -condition ($authorExport.CommitCount -eq $byAuthor.CommitCount) -label 'author export CommitCount matches the lookup'

        return $newestAuthorCommit
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
