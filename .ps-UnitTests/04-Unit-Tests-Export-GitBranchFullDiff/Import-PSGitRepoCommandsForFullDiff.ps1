function Import-PSGitRepoCommandsForFullDiff () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts Export-GitBranchFullDiff is exported.

    .DESCRIPTION
        Loads the module from ModulePath and throws unless
        Export-GitBranchFullDiff is exported.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Import the module at ModulePath.
        2. Assert Export-GitBranchFullDiff is exported.

    .EXAMPLE
        PS> Import-PSGitRepoCommandsForFullDiff -modulePath 'C:\repo\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'
        Imports the module and asserts the full-diff export command.

        PS> Import-PSGitRepoCommandsForFullDiff -modulePath $resolvedModulePath
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
        Assert-TestCommandExported -name 'Export-GitBranchFullDiff'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
