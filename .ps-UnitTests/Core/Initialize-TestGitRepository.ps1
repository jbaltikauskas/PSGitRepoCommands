function Initialize-TestGitRepository () {
    <#
    .SYNOPSIS
        Initializes a nested Git repo at RepoPath with main and feature/x.

    .DESCRIPTION
        Ensures RepoPath exists, replaces any prior nested .git at that path,
        then creates main with a.txt and feature/x with b.txt. Returns the
        resolved Git root. Does not delete sibling content such as tests/Github/DbUp.
        Throws when git commands fail or the nested toplevel is wrong.

    .PARAMETER repoPath
        Directory that becomes the Git root for smoke tests (default tests/).

    .NOTES
        1. Create RepoPath when missing; remove a prior nested .git if present.
        2. git init -b main, add a.txt, commit.
        3. Create feature/x with b.txt; switch back to main.
        4. Assert show-toplevel equals RepoPath; return it.

    .EXAMPLE
        PS> Initialize-TestGitRepository -repoPath '.\tests'
        Makes tests/ a nested Git root with main and feature/x.

        PS> $root = Initialize-TestGitRepository -repoPath $repoPath
        Stores the resolved Git root path in $root.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Directory to use as the Git root.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedRepoPath = [System.IO.Path]::GetFullPath($repoPath)

        if (-not (Test-Path -LiteralPath $resolvedRepoPath)) {
            New-Item -ItemType Directory -Path $resolvedRepoPath | Out-Null
        }

        [string]$gitDir = Join-Path -Path $resolvedRepoPath -ChildPath '.git'

        if (Test-Path -LiteralPath $gitDir) {
            Remove-Item -LiteralPath $gitDir -Recurse -Force
        }

        foreach ($fixtureName in @('a.txt', 'b.txt', 'diff-export.json')) {
            [string]$fixturePath = Join-Path -Path $resolvedRepoPath -ChildPath $fixtureName

            if (Test-Path -LiteralPath $fixturePath) {
                Remove-Item -LiteralPath $fixturePath -Force
            }
        }

        Push-Location -LiteralPath $resolvedRepoPath

        try {

            & git init -b main | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git init failed with exit code $LASTEXITCODE"
            }

            'init' | Set-Content -LiteralPath (Join-Path -Path $resolvedRepoPath -ChildPath 'a.txt') -Encoding utf8NoBOM
            & git add a.txt | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git add failed with exit code $LASTEXITCODE"
            }

            & git -c user.email=test@example.com -c user.name=test commit -m 'init' | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git commit failed with exit code $LASTEXITCODE"
            }

            & git branch feature/x | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git branch feature/x failed with exit code $LASTEXITCODE"
            }

            & git switch feature/x | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git switch feature/x failed with exit code $LASTEXITCODE"
            }

            'feature' | Set-Content -LiteralPath (Join-Path -Path $resolvedRepoPath -ChildPath 'b.txt') -Encoding utf8NoBOM
            & git add b.txt | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git add b.txt failed with exit code $LASTEXITCODE"
            }

            & git -c user.email=test@example.com -c user.name=test commit -m 'add b' | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git commit add b failed with exit code $LASTEXITCODE"
            }

            & git switch main | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git switch main failed with exit code $LASTEXITCODE"
            }

            [string]$toplevel = (& git rev-parse --show-toplevel).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw "git rev-parse --show-toplevel failed with exit code $LASTEXITCODE"
            }

            [string]$normalizedToplevel = [System.IO.Path]::GetFullPath($toplevel)
            if ($normalizedToplevel -ne $resolvedRepoPath) {
                throw "Expected Git root '$resolvedRepoPath' but got '$normalizedToplevel'"
            }
        }
        finally {
            Pop-Location
        }

        return $resolvedRepoPath
    }
}
