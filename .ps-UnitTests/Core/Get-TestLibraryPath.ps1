function Get-TestLibraryPath () {
    <#
    .SYNOPSIS
        Resolves the tests/Github/DbUp library path and verifies it exists.

    .DESCRIPTION
        Joins RepoPath with Github\DbUp and throws when that directory is missing.

    .PARAMETER repoPath
        Parent folder that contains Github\DbUp, typically tests/.

    .NOTES
        1. Join RepoPath with Github\DbUp.
        2. Throw when the directory is missing.
        3. Return the full path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Parent folder that contains Github\DbUp.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$libraryPath = Join-Path -Path ([System.IO.Path]::GetFullPath($repoPath)) -ChildPath 'Github\DbUp'

        if (-not (Test-Path -LiteralPath $libraryPath -PathType Container)) {
            throw "DbUp repository not found: $libraryPath"
        }

        return $libraryPath
    }
}
