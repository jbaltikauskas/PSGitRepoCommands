function Test-GitBranch () {
    <#
    .SYNOPSIS
        Tests whether a branch ref exists in the repository.

    .DESCRIPTION
        Checks for refs/heads/Name by default, or refs/remotes/Name when -remote
        is set. Returns a PSCustomObject with Name, Path, Remote, RefName, and
        Exists. Does not throw when the branch is missing. Still throws when
        Path is not a Git repository or git is missing.

    .NOTES
        1. Resolve and assert the repository path.
        2. Build the ref path for local or remote.
        3. Run show-ref --verify --quiet.
        4. Fall back to unborn HEAD name match for local branches.
        5. Return a PSCustomObject with Exists set accordingly.

    .EXAMPLE
        PS> (Test-GitBranch -name 'main').Exists
        Returns $true when the local main branch exists.

        PS> Test-GitBranch -name 'origin/main' -remote
        Tests a remote-tracking ref under refs/remotes.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Branch name to test (e.g. main or origin/main).")]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Treat Name as a remote-tracking branch under refs/remotes.")]
        [switch]$remote
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Test-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        [string]$refName = if ($remote) {
            "refs/remotes/$name"
        }
        else {
            "refs/heads/$name"
        }

        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false

        try {

            $null = & git -C $resolvedPath show-ref --verify --quiet $refName 2>&1
            [int]$exitCode = $LASTEXITCODE
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }

        [bool]$exists = ($exitCode -eq 0)

        if ((-not $exists) -and (-not $remote)) {
            [string]$headName = Invoke-Git -path $resolvedPath -arguments @('symbolic-ref', '--short', 'HEAD') -allowNonZeroExit

            if ((-not [string]::IsNullOrWhiteSpace($headName)) -and ($headName.Trim() -eq $name)) {
                $exists = $true
            }
        }

        return [PSCustomObject]@{
            Name    = $name
            Path    = $resolvedPath
            Remote  = $remote.IsPresent
            RefName = $refName
            Exists  = $exists
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Test-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
