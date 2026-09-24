function Assert-DbUpMainTipByNumberShortHashAndFullHash () {
    <#
    .SYNOPSIS
        Selects the DbUp main tip by number, short hash, and full hash.

    .DESCRIPTION
        Returns the commit selected by number so the export section can name files.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER branchTip
        Full hash of main.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Full hash of main.")]
        [ValidateNotNullOrEmpty()]
        [string]$branchTip
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'
        Assert-TestTrue -condition ($byNumber.Author -eq 'Robert Wagner') -label 'tip Author is Robert Wagner'
        Assert-TestTrue -condition ($byNumber.AuthorEmail -eq 'robert@wagner.id.au') -label 'tip AuthorEmail is robert@wagner.id.au'
        Assert-TestTrue -condition ($byNumber.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'tip AuthorDate is 2026-02-18T13:55:32+10:00'
        Assert-TestTrue -condition ($byNumber.Committer -eq 'Robert Wagner') -label 'tip Committer is Robert Wagner'

        $byShort = Get-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byShort.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -shortHash matches the tip'

        $byFull = Get-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byFull.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -hash matches the tip'

        return $byNumber
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
