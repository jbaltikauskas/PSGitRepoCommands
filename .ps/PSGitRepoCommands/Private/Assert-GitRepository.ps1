function Assert-GitRepository () {
    <#
    .SYNOPSIS
        Throws when the given path is not inside a Git work tree.

    .DESCRIPTION
        Resolves Path to a full path, verifies the directory exists, then runs
        git rev-parse --is-inside-work-tree via Invoke-Git. Throws when the path
        is missing or not a repository. Returns the resolved full path string.

    .REMARKS
        1. Resolve Path with GetFullPath and require an existing directory.
        2. Assert git is installed.
        3. Invoke git rev-parse --is-inside-work-tree; throw if not true.
        4. Return the resolved path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Assert-GitInstalled

        [string]$resolvedPath = [System.IO.Path]::GetFullPath($path)

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
            throw "Directory not found: '$resolvedPath'"
        }

        [string]$inside = Invoke-Git -path $resolvedPath -arguments @('rev-parse', '--is-inside-work-tree')

        if ($inside.Trim() -ne 'true') {
            throw "Path is not inside a Git work tree: '$resolvedPath'"
        }

        return $resolvedPath
    }
}
