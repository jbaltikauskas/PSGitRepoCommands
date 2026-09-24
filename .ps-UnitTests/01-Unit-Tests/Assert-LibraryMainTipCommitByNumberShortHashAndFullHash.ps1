function Assert-LibraryMainTipCommitByNumberShortHashAndFullHash () {
    <#
    .SYNOPSIS
        Asserts the DbUp main tip can be selected by number, short hash, and full hash.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER diffTargetBranch
        Branch whose tip is selected. Typically main.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$branchTip = (git -C $libraryPath rev-parse $diffTargetBranch).Trim()
        $byNumber = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -number 1 -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byNumber.Branch -eq $diffTargetBranch) -label 'Get-GitBranchCommitByID uses the requested branch'
        Assert-TestTrue -condition ($byNumber.Hash -eq $branchTip) -label 'Get-GitBranchCommitByID -number 1 is the branch tip'

        $byShort = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byShort.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -shortHash matches the same commit'

        $byFull = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -hash $byNumber.Hash -fetch:$false -includePatch:$false
        Assert-TestTrue -condition ($byFull.Hash -eq $byNumber.Hash) -label 'Get-GitBranchCommitByID -hash full hash matches the same commit'

        return [pscustomobject]@{
            BranchTip = $branchTip
            ByNumber  = $byNumber
        }
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
