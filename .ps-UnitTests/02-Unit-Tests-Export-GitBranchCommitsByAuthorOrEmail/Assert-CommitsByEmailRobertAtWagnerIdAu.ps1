function Assert-CommitsByEmailRobertAtWagnerIdAu () {
    <#
    .SYNOPSIS
        Asserts the email lookup for robert@wagner.id.au matches the author lookup.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER authorTip
        Newest commit from the Robert Wagner author lookup.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $byEmail = Get-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -email 'robert@wagner.id.au' -fetch:$false -includePatch:$false
        $emailTip = @($byEmail.Commits)[0]
        Assert-TestTrue -condition ($byEmail.CommitCount -eq 20) -label 'Get-GitBranchCommitsByAuthorOrEmail -email returns the default limit of 20' -details $byEmail.CommitCount
        Assert-TestTrue -condition ($byEmail.IncludePatch -eq $false) -label 'email lookup omits patch text'
        Assert-TestTrue -condition ($emailTip.Hash -eq $authorTip.Hash) -label 'email lookup newest commit matches the author lookup'
        Assert-TestTrue -condition ($emailTip.Author -eq 'Robert Wagner' -and $emailTip.AuthorEmail -eq 'robert@wagner.id.au' -and $emailTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $emailTip.Committer -eq 'Robert Wagner') -label 'email lookup tip identity matches Robert Wagner'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
