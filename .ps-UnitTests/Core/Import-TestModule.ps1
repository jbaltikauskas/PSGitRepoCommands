function Import-TestModule () {
    <#
    .SYNOPSIS
        Imports PSGitRepoCommands from a manifest path.

    .DESCRIPTION
        Throws when the manifest is missing, then imports it with -Force.

    .PARAMETER modulePath
        Full path to PSGitRepoCommands.psd1.

    .NOTES
        1. Throw when the manifest file is missing.
        2. Import the module with -Force.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to PSGitRepoCommands.psd1.")]
        [ValidateNotNullOrEmpty()]
        [string]$modulePath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if (-not (Test-Path -LiteralPath $modulePath)) {
            throw "PSGitRepoCommands manifest not found: $modulePath"
        }

        Import-Module -Name $modulePath -Force
    }
}
