function Assert-GitBranchMutateCmdletsOnSmokeRepository () {
    <#
    .SYNOPSIS
        Asserts create, switch, rename, compare, and remove on the smoke-test repository.

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

        $created = New-GitBranch -path $repoPath -name 'feature/y' -startPoint 'main'
        Assert-TestTrue -condition ($created.Name -eq 'feature/y') -label 'New-GitBranch feature/y'
        Assert-TestTrue -condition ($created.Switched -eq $false) -label 'New-GitBranch did not switch'

        $switched = Switch-GitBranch -path $repoPath -name 'feature/y'
        Assert-TestTrue -condition ($switched.Name -eq 'feature/y') -label 'Switch-GitBranch feature/y'

        $renamed = Rename-GitBranch -path $repoPath -newName 'feature/z'
        Assert-TestTrue -condition ($renamed.NewName -eq 'feature/z') -label 'Rename-GitBranch to feature/z'

        $compare = Compare-GitBranch -path $repoPath -baseBranch 'main' -compareBranch 'feature/x'
        Assert-TestTrue -condition ($null -ne $compare.Ahead) -label 'Compare-GitBranch returns Ahead'
        Assert-TestTrue -condition ($null -ne $compare.Behind) -label 'Compare-GitBranch returns Behind'

        Switch-GitBranch -path $repoPath -name 'main' | Out-Null
        $removed = Remove-GitBranch -path $repoPath -name 'feature/z' -force
        Assert-TestTrue -condition ($removed.LocalDeleted -eq $true) -label 'Remove-GitBranch feature/z'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
