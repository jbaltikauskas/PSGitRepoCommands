function Import-PSGitRepoCommandsForDateRangeLookup () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the date-range commands.

    .DESCRIPTION
        Loads the module from ModulePath and throws unless the date-range
        get and export commands are exported.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Import the module at ModulePath.
        2. Assert the date-range commands are exported.

    .EXAMPLE
        PS> Import-PSGitRepoCommandsForDateRangeLookup -modulePath 'C:\repo\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1'
        Imports the module and asserts the date-range commands.

        PS> Import-PSGitRepoCommandsForDateRangeLookup -modulePath $resolvedModulePath
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
        Assert-TestCommandExported -name 'Get-GitBranchCommitsByDateRange', 'Export-GitBranchCommitsByDateRange'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
