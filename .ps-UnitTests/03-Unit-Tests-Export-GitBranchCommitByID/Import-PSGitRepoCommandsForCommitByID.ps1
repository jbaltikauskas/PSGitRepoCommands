function Import-PSGitRepoCommandsForCommitByID () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the commit-by-id commands.

    .DESCRIPTION
        Loads the module from ModulePath and throws unless the commit-by-id
        get and export commands are exported.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Import the module at ModulePath.
        2. Assert the commit-by-id commands are exported.

    .EXAMPLE
        PS> Import-PSGitRepoCommandsForCommitByID -modulePath 'C:\repo\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'
        Imports the module and asserts the commit-by-id commands.

        PS> Import-PSGitRepoCommandsForCommitByID -modulePath $resolvedModulePath
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
        Assert-TestCommandExported -name 'Get-GitBranchCommitByID', 'Export-GitBranchCommitByID'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
