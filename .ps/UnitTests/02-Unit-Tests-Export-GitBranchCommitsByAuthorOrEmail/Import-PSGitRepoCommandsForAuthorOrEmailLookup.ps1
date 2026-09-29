function Import-PSGitRepoCommandsForAuthorOrEmailLookup () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the author and email export commands.

    .DESCRIPTION
        Loads the module from ModulePath and throws unless the author-or-email
        get and export commands are exported.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Import the module at ModulePath.
        2. Assert the author-or-email commands are exported.

    .EXAMPLE
        PS> Import-PSGitRepoCommandsForAuthorOrEmailLookup -modulePath 'C:\repo\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'
        Imports the module and asserts the author-or-email commands.

        PS> Import-PSGitRepoCommandsForAuthorOrEmailLookup -modulePath $resolvedModulePath
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
        Assert-TestCommandExported -name 'Get-GitBranchCommitsByAuthorOrEmail', 'Export-GitBranchCommitsByAuthorOrEmail'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
