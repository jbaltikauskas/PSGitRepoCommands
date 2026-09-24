function Get-LastReleaseBranch () {
    <#
    .SYNOPSIS
        Returns the highest-version release/* branch in a repository.

    .DESCRIPTION
        Lists local refs/heads/release and origin/release refs, strips a remote
        prefix, and returns the release/name with the highest version (git
        version:refname order). Throws when no release branch exists.

    .PARAMETER path
        Repository that contains release branches (for example tests/Github/DbUp).

    .NOTES
        1. List release refs sorted by version descending.
        2. Normalize origin/release/x to release/x.
        3. Return the first unique name, or throw.

    .EXAMPLE
        PS> Get-LastReleaseBranch -path '.\tests\Github\DbUp'
        Returns release/6.0.0 when that is the newest release branch.

        PS> $name = Get-LastReleaseBranch -path $libraryPath
        Stores the last release branch name in $name.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Repository path to search for release/* branches.")]
        [ValidateNotNullOrEmpty()]
        [string]$path
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = [System.IO.Path]::GetFullPath($path)

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
            throw "Directory not found: '$resolvedPath'"
        }

        [string[]]$raw = @(& git -C $resolvedPath for-each-ref --sort=-version:refname --format='%(refname:short)' 'refs/heads/release' 'refs/remotes/origin/release')
        if ($LASTEXITCODE -ne 0) {
            throw "git for-each-ref failed with exit code $LASTEXITCODE"
        }

        [System.Collections.Generic.List[string]]$names = [System.Collections.Generic.List[string]]::new()

        foreach ($line in $raw) {
            [string]$name = $line.Trim()

            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            if ($name -match '^(?:[^/]+/)?(release/.+)$') {
                $name = $Matches[1]
            }

            if (-not $names.Contains($name)) {
                $names.Add($name)
            }
        }

        if ($names.Count -lt 1) {
            throw "No release/* branch found under '$resolvedPath'."
        }

        return $names[0]
    }
}
