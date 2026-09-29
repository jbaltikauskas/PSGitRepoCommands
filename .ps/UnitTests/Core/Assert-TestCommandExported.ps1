function Assert-TestCommandExported () {
    <#
    .SYNOPSIS
        Asserts that named commands are exported by PSGitRepoCommands.

    .DESCRIPTION
        Calls Assert-TestTrue once per name. The module must already be imported.

    .PARAMETER name
        Command names that must be exported.

    .NOTES
        1. Resolve each name with Get-Command -Module PSGitRepoCommands.
        2. Assert the command exists.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Command names that must be exported.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$name
    )

    Process {

        foreach ($commandName in $name) {
            Assert-TestTrue -condition ($null -ne (Get-Command -Module PSGitRepoCommands -Name $commandName -ErrorAction SilentlyContinue)) -label "$commandName is exported"
        }
    }
}
