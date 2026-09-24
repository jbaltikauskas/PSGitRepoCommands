function Assert-GitBranchReadCmdletsOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts current-branch, list, and exists checks on the smoke-test repository.

    .PARAMETER repoPath
        Nested Git root created for this run.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root created for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $current = Get-GitCurrentBranch -path $repoPath
        Assert-TestTrue -condition ($current.Name -eq 'main') -label 'Get-GitCurrentBranch is main'
        Assert-TestTrue -condition ($current.IsCurrent -eq $true) -label 'Get-GitCurrentBranch.IsCurrent'

        $branches = @(Get-GitBranch -path $repoPath)
        Assert-TestTrue -condition ($branches.Count -ge 2) -label 'Get-GitBranch lists local branches'

        $mainExists = Test-GitBranch -path $repoPath -name 'main'
        Assert-TestTrue -condition ($mainExists.Exists -eq $true) -label 'Test-GitBranch main exists'

        $missing = Test-GitBranch -path $repoPath -name 'no-such-branch-xyz'
        Assert-TestTrue -condition ($missing.Exists -eq $false) -label 'Test-GitBranch missing is false'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
