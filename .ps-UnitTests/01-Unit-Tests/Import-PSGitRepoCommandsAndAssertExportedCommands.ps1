function Import-PSGitRepoCommandsAndAssertExportedCommands () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the smoke-test command set is exported.

    .DESCRIPTION
        Loads the module from ModulePath, lists exported command names, and
        throws unless the smoke-test set is present (at least 19 commands,
        including the commit, author, and date-range cmdlets).

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Import the module at ModulePath.
        2. Collect exported command names.
        3. Assert the minimum count and the smoke-test command names.

    .EXAMPLE
        PS> Import-PSGitRepoCommandsAndAssertExportedCommands -modulePath 'C:\repo\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'
        Imports the module and asserts the smoke-test exports.

        PS> Import-PSGitRepoCommandsAndAssertExportedCommands -modulePath $resolvedModulePath
        Same check using the path resolved by the runner.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to PSGitRepoCommands.psd1.")]
        [ValidateNotNullOrEmpty()]
        [string]$modulePath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        Import-TestModule -modulePath $modulePath

        [string[]]$exported = @(Get-Command -Module PSGitRepoCommands | Select-Object -ExpandProperty Name | Sort-Object)
        Write-Host ("Exported commands ({0}): {1}" -f $exported.Count, ($exported -join ', ')) -ForegroundColor DarkGray
        Write-Host 'module exports at least 19 commands' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported.Count -ge 19) -label 'module exports at least 19 commands'
        Write-Host 'Get-GitBranchCommitByID is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitByID') -label 'Get-GitBranchCommitByID is exported'
        Write-Host 'Export-GitBranchCommitByID is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitByID') -label 'Export-GitBranchCommitByID is exported'
        Write-Host 'Get-GitBranchCommitsByAuthorOrEmail is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByAuthorOrEmail') -label 'Get-GitBranchCommitsByAuthorOrEmail is exported'
        Write-Host 'Export-GitBranchCommitsByAuthorOrEmail is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByAuthorOrEmail') -label 'Export-GitBranchCommitsByAuthorOrEmail is exported'
        Write-Host 'Get-GitBranchCommitsByDateRange is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Get-GitBranchCommitsByDateRange') -label 'Get-GitBranchCommitsByDateRange is exported'
        Write-Host 'Export-GitBranchCommitsByDateRange is exported' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exported -contains 'Export-GitBranchCommitsByDateRange') -label 'Export-GitBranchCommitsByDateRange is exported'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
