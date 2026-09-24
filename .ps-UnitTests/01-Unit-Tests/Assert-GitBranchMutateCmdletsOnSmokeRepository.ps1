function Assert-GitBranchMutateCmdletsOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts create, switch, rename, compare, and remove on the smoke-test repository.

    .DESCRIPTION
        Mutates the nested Git root: creates feature/y without switching, switches
        to it, renames it to feature/z, compares main with feature/x, then
        switches back to main and force-deletes feature/z. Throws on a failed check.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .NOTES
        1. Create feature/y and assert it did not switch.
        2. Switch to feature/y and rename it to feature/z.
        3. Compare main with feature/x.
        4. Switch back to main and remove feature/z.

    .EXAMPLE
        PS> Assert-GitBranchMutateCmdletsOnSmokeRepository -repoPath 'C:\repo\tests\20260923-2300'
        Creates, switches, renames, compares, and removes branches on that root.

        PS> Assert-GitBranchMutateCmdletsOnSmokeRepository -repoPath $resolvedRepoPath
        Same mutation checks using the root from the smoke runner.
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

        $created = New-GitBranch -path $repoPath -name 'feature/y' -startPoint 'main'
        Write-Host 'New-GitBranch feature/y' -ForegroundColor Cyan
        Assert-TestTrue -condition ($created.Name -eq 'feature/y') -label 'New-GitBranch feature/y'
        Write-Host 'New-GitBranch did not switch' -ForegroundColor Cyan
        Assert-TestTrue -condition ($created.Switched -eq $false) -label 'New-GitBranch did not switch'

        $switched = Switch-GitBranch -path $repoPath -name 'feature/y'
        Write-Host 'Switch-GitBranch feature/y' -ForegroundColor Cyan
        Assert-TestTrue -condition ($switched.Name -eq 'feature/y') -label 'Switch-GitBranch feature/y'

        $renamed = Rename-GitBranch -path $repoPath -newName 'feature/z'
        Write-Host 'Rename-GitBranch to feature/z' -ForegroundColor Cyan
        Assert-TestTrue -condition ($renamed.NewName -eq 'feature/z') -label 'Rename-GitBranch to feature/z'

        $compare = Compare-GitBranch -path $repoPath -baseBranch 'main' -compareBranch 'feature/x'
        Write-Host 'Compare-GitBranch returns Ahead' -ForegroundColor Cyan
        Assert-TestTrue -condition ($null -ne $compare.Ahead) -label 'Compare-GitBranch returns Ahead'
        Write-Host 'Compare-GitBranch returns Behind' -ForegroundColor Cyan
        Assert-TestTrue -condition ($null -ne $compare.Behind) -label 'Compare-GitBranch returns Behind'

        Switch-GitBranch -path $repoPath -name 'main' | Out-Null
        $removed = Remove-GitBranch -path $repoPath -name 'feature/z' -force
        Write-Host 'Remove-GitBranch feature/z' -ForegroundColor Cyan
        Assert-TestTrue -condition ($removed.LocalDeleted -eq $true) -label 'Remove-GitBranch feature/z'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
