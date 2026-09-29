function Assert-DbUpMainTipByNumberShortHashAndFullHash () {
    <#
    .SYNOPSIS
        Selects the DbUp main tip by number, short hash, and full hash.

    .DESCRIPTION
        Selects commit number 1 on main, then the same commit by short hash and
        by full hash. Throws unless each hash is BranchTip and the tip identity
        matches the DbUp fixture. Returns the commit selected by number so the
        export section can name files.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER branchTip
        Full hash of main.

    .NOTES
        1. Select commit number 1 and assert the tip identity.
        2. Select the same commit by short hash and by full hash.
        3. Return the commit selected by number.

    .EXAMPLE
        PS> Assert-DbUpMainTipByNumberShortHashAndFullHash -libraryPath 'C:\repo\tests\Github\DbUp' -branchTip $hash
        Asserts number, short-hash, and full-hash selection of the main tip.

        PS> $byNumber = Assert-DbUpMainTipByNumberShortHashAndFullHash -libraryPath $libraryPath -branchTip $branchTip
        Stores the number-1 commit for the export section.
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

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -number 1 is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'
        Write-Host 'tip Author is Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.Author -eq 'Robert Wagner') -label 'tip Author is Robert Wagner'
        Write-Host 'tip AuthorEmail is robert@wagner.id.au' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.AuthorEmail -eq 'robert@wagner.id.au') -label 'tip AuthorEmail is robert@wagner.id.au'
        Write-Host 'tip AuthorDate is 2026-02-18T13:55:32+10:00' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.AuthorDate -eq '2026-02-18T13:55:32+10:00') -label 'tip AuthorDate is 2026-02-18T13:55:32+10:00'
        Write-Host 'tip Committer is Robert Wagner' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.Committer -eq 'Robert Wagner') -label 'tip Committer is Robert Wagner'

        $byShort = Get-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -shortHash matches the tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byShort.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -shortHash matches the tip'

        $byFull = Get-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -hash matches the tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byFull.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -hash matches the tip'

        return $byNumber
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
