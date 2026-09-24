function Resolve-GitBranchRef () {
    <#
    .SYNOPSIS
        Resolves a branch name to a local or origin/ ref.

    .DESCRIPTION
        Tries Branch as a commit-ish, then origin/Branch. Returns a
        PSCustomObject with Branch, Ref, Found, and Path. Throws when -require
        is set and the branch cannot be resolved.

    .REMARKS
        1. Assert the repository path.
        2. Try rev-parse on Branch then origin/Branch.
        3. Return a PSCustomObject; throw when -require and not found.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Branch name to resolve (e.g. main or feature/x).")]
        [ValidateNotNullOrEmpty()]
        [string]$branch,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Throw when the branch cannot be resolved.")]
        [switch]$require
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path
        [string]$ref = ''

        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false

        try {

            $null = & git -C $resolvedPath --no-pager -c color.ui=false rev-parse --verify --quiet "${branch}^{commit}" 2>$null

            if ($LASTEXITCODE -eq 0) {
                $ref = $branch
            }
            else {
                $null = & git -C $resolvedPath --no-pager -c color.ui=false rev-parse --verify --quiet "origin/${branch}^{commit}" 2>$null

                if ($LASTEXITCODE -eq 0) {
                    $ref = "origin/$branch"
                }
            }
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }

        [bool]$found = -not [string]::IsNullOrWhiteSpace($ref)

        if ($require.IsPresent -and (-not $found)) {
            throw "Branch '$branch' not found locally or as origin/$branch."
        }

        $result = [ordered]@{
            Branch = $branch
            Ref    = $ref
            Found  = $found
            Path   = $resolvedPath
        }

        return [PSCustomObject]$result
    }
}
