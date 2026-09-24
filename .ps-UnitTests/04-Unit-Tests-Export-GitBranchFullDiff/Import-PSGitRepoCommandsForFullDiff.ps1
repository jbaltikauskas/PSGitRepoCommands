function Import-PSGitRepoCommandsForFullDiff () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands and asserts Export-GitBranchFullDiff is exported.

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
        Assert-TestCommandExported -name 'Export-GitBranchFullDiff'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
