function Initialize-NestedGitRepositoryForSmokeTest () {
    <#
    .SYNOPSIS
        Initializes the dated folder as a nested Git root with main and feature/x.

    .PARAMETER repoPath
        Dated folder that becomes the Git root.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that becomes the Git root.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$root = Initialize-TestGitRepository -repoPath $repoPath
        Write-Host ("resolvedRepoPath = {0}" -f $root) -ForegroundColor DarkGray
        return $root
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
