function Import-PSGitRepoCommandsAndAssertExportedCommands () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the smoke-test command set is exported.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to PSGitRepoCommands.psd1.")]
        [ValidateNotNullOrEmpty()]
        [string]$modulePath
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Import-TestModule -modulePath $modulePath

        [string[]]$exported = @(Get-Command -Module PSGitRepoCommands | Select-Object -ExpandProperty Name | Sort-Object)
        Write-Host ("Exported commands ({0}): {1}" -f $exported.Count, ($exported -join ', ')) -ForegroundColor DarkGray
        Assert-TestTrue -condition ($exported.Count -ge 19) -label 'module exports at least 19 commands'
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitByID') -label 'Get-GitBranchCommitByID is exported'
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitByID') -label 'Export-GitBranchCommitByID is exported'
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByAuthorOrEmail') -label 'Get-GitBranchCommitsByAuthorOrEmail is exported'
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByAuthorOrEmail') -label 'Export-GitBranchCommitsByAuthorOrEmail is exported'
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByDateRange') -label 'Get-GitBranchCommitsByDateRange is exported'
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByDateRange') -label 'Export-GitBranchCommitsByDateRange is exported'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
