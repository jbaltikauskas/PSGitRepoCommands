function Assert-GitInstalled () {
    <#
    .SYNOPSIS
        Throws when the git CLI is not available on PATH.

    .DESCRIPTION
        Verifies that Get-Command can resolve git. Used by public GitBranch
        cmdlets before any repository work. Throws on failure; returns nothing
        on success.

    .REMARKS
        1. Call Get-Command for git.
        2. Throw if the command is missing.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        if ($null -eq (Get-Command -Name git -ErrorAction SilentlyContinue)) {
            throw "Required: Install Git and ensure 'git' is available in PATH."
        }
    }
}
