function Assert-GitBranchReadCmdletsOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts current-branch, list, and exists checks on the smoke-test repository.

    .DESCRIPTION
        Reads the nested Git root and throws unless main is current, at least
        two local branches are listed, main exists, and a missing name does not.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .NOTES
        1. Assert the current branch is main.
        2. Assert the local branch list has at least two entries.
        3. Assert main exists and a missing name does not.

    .EXAMPLE
        PS> Assert-GitBranchReadCmdletsOnSmokeRepository -repoPath 'C:\repo\tests\20260923-2300'
        Checks current branch, list, and exists on that root.

        PS> Assert-GitBranchReadCmdletsOnSmokeRepository -repoPath $resolvedRepoPath
        Same checks using the root from the smoke runner.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root created for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $current = Get-GitCurrentBranch -path $repoPath
        Write-Host 'Get-GitCurrentBranch is main' -ForegroundColor Cyan
        Assert-TestTrue -condition ($current.Name -eq 'main') -label 'Get-GitCurrentBranch is main'
        Write-Host 'Get-GitCurrentBranch.IsCurrent' -ForegroundColor Cyan
        Assert-TestTrue -condition ($current.IsCurrent -eq $true) -label 'Get-GitCurrentBranch.IsCurrent'

        $branches = @(Get-GitBranch -path $repoPath)
        Write-Host 'Get-GitBranch lists local branches' -ForegroundColor Cyan
        Assert-TestTrue -condition ($branches.Count -ge 2) -label 'Get-GitBranch lists local branches'

        $mainExists = Test-GitBranch -path $repoPath -name 'main'
        Write-Host 'Test-GitBranch main exists' -ForegroundColor Cyan
        Assert-TestTrue -condition ($mainExists.Exists -eq $true) -label 'Test-GitBranch main exists'

        $missing = Test-GitBranch -path $repoPath -name 'no-such-branch-xyz'
        Write-Host 'Test-GitBranch missing is false' -ForegroundColor Cyan
        Assert-TestTrue -condition ($missing.Exists -eq $false) -label 'Test-GitBranch missing is false'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
