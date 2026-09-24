function Assert-LibraryMainTipCommitByNumberShortHashAndFullHash () {
    <#
    .SYNOPSIS
        Asserts the DbUp main tip can be selected by number, short hash, and full hash.

    .DESCRIPTION
        Selects commit number 1 on DiffTargetBranch, then selects the same commit
        by short hash and by full hash. Throws unless all three hashes match the
        branch tip. Returns the tip hash and the number-1 commit.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER diffTargetBranch
        Branch whose tip is selected. Typically main.

    .NOTES
        1. Select commit number 1 and assert it is the branch tip.
        2. Select the same commit by short hash and by full hash.
        3. Return the tip hash and the number-1 commit.

    .EXAMPLE
        PS> Assert-LibraryMainTipCommitByNumberShortHashAndFullHash -libraryPath 'C:\repo\tests\Github\DbUp' -diffTargetBranch 'main'
        Asserts number, short-hash, and full-hash selection of the main tip.

        PS> $selectedTip = Assert-LibraryMainTipCommitByNumberShortHashAndFullHash -libraryPath $fullDiff.LibraryPath -diffTargetBranch $fullDiff.DiffTargetBranch
        Stores the tip for the export section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Branch whose tip is selected.")]
        [ValidateNotNullOrEmpty()]
        [string]$diffTargetBranch
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$branchTip = (git -C $libraryPath rev-parse $diffTargetBranch).Trim()
        $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -number 1 -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID uses the requested branch' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.Branch -eq $diffTargetBranch) -label 'Get-GitBranchCommitByID uses the requested branch'
        Write-Host 'Get-GitBranchCommitByID -number 1 is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'

        $byShort = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -shortHash matches the same commit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byShort.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -shortHash matches the same commit'

        $byFull = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -hash $byNumber.Hash -fetch:$false -includePatch:$false
        Write-Host 'Get-GitBranchCommitByID -hash full hash matches the same commit' -ForegroundColor Cyan
        Assert-TestTrue -condition ($byFull.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -hash full hash matches the same commit'

        return [pscustomobject]@{
            BranchTip = $branchTip
            ByNumber  = $byNumber
        }
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
