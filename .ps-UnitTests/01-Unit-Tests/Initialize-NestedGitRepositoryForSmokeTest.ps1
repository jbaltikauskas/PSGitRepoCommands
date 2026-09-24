function Initialize-NestedGitRepositoryForSmokeTest () {
    <#
    .SYNOPSIS
        Initializes the dated folder as a nested Git root with main and feature/x.

    .DESCRIPTION
        Turns RepoPath into a throwaway Git repository for the smoke test and
        returns the resolved root. Later sections use that root for read and
        mutate checks.

    .PARAMETER repoPath
        Dated folder that becomes the Git root.

    .NOTES
        1. Initialize the dated folder as a Git repository.
        2. Print the resolved root and return it.

    .EXAMPLE
        PS> Initialize-NestedGitRepositoryForSmokeTest -repoPath 'C:\repo\tests\20260923-2300'
        Creates the nested Git root and returns its full path.

        PS> $resolvedRepoPath = Initialize-NestedGitRepositoryForSmokeTest -repoPath $runFolder
        Stores the resolved root for the rest of the smoke run.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that becomes the Git root.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$root = Initialize-TestGitRepository -repoPath $repoPath
        Write-Host ("resolvedRepoPath = {0}" -f $root) -ForegroundColor DarkGray
        return $root
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
