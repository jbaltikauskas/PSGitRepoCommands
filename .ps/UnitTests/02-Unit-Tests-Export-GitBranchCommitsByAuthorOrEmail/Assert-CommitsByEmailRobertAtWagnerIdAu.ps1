function Assert-CommitsByEmailRobertAtWagnerIdAu () {
    <#
    .SYNOPSIS
        Asserts the email lookup for robert@wagner.id.au matches the author lookup.

    .DESCRIPTION
        Looks up commits by email on main and throws unless the default limit,
        omitted patch text, newest hash, and tip identity match AuthorTip.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER authorTip
        Newest commit from the Robert Wagner author lookup.

    .NOTES
        1. Look up commits for robert@wagner.id.au.
        2. Assert the default limit and that patch text is omitted.
        3. Assert the newest commit matches AuthorTip.

    .EXAMPLE
        PS> Assert-CommitsByEmailRobertAtWagnerIdAu -libraryPath 'C:\repo\tests\Github\DbUp' -authorTip $tip
        Asserts the email lookup matches the author tip.

        PS> Assert-CommitsByEmailRobertAtWagnerIdAu -libraryPath $libraryPath -authorTip $authorTip
        Same check using the tip from the author section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Newest commit from the Robert Wagner author lookup.")]
        [ValidateNotNull()]
        [psobject]$authorTip
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -email 'robert@wagner.id.au' -fetch:$false -includePatch:$false
        $emailTip = @($byEmail.Commits)[0]
        Write-Host 'Get-GitBranchCommitsByAuthorOrEmail -email returns the default limit of 20' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byEmail.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -email returns the default limit of 20' -details $byEmail.CommitCount
        Write-Host 'email lookup omits patch text' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byEmail.IncludePatch -eq $false) -label 'email lookup omits patch text'
        Write-Host 'email lookup newest commit matches the author lookup' -ForegroundColor Cyan
        Assert-TestTrue -condition ($emailTip.Hash -eq $authorTip.Hash) -label 'email lookup newest commit matches the author lookup'
        Write-Host 'email lookup tip identity matches Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($emailTip.Author -eq 'Robert Wagner' -and $emailTip.AuthorEmail -eq 'robert@wagner.id.au' -and $emailTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $emailTip.Committer -eq 'Robert Wagner') -label 'email lookup tip identity matches Robert Wagner'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
