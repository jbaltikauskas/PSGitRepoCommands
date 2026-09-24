function Import-PSGitRepoCommandsForCommitByID () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts the commit-by-id commands.

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
        Assert-TestCommandExported -name 'Get-GitBranchCommitByID', 'Export-GitBranchCommitByID'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
