function Clear-TestGitRepository () {
    <#
    .SYNOPSIS
        Removes the nested smoke-test Git metadata and fixture files.

    .DESCRIPTION
        Deletes the dated run folder (RepoPath) created for this smoke test,
        including its .git directory and fixture files. Does not delete the
        parent tests/ folder or siblings such as tests/Github/DbUp.

    .PARAMETER repoPath
        Nested Git root created for smoke tests.

    .NOTES
        1. Resolve RepoPath.
        2. Remove the dated run folder when it exists.

    .EXAMPLE
        PS> Clear-TestGitRepository -repoPath '.\tests\20260921-0013'
        Removes that dated run folder.

        PS> Clear-TestGitRepository -repoPath $resolvedRepoPath
        Cleans the resolved smoke-test Git root.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root to clean.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Process {

        [string]$resolvedRepoPath = [System.IO.Path]::GetFullPath($repoPath)

        if (Test-Path -LiteralPath $resolvedRepoPath) {
            Remove-Item -LiteralPath $resolvedRepoPath -Recurse -Force
        }
    }
}
