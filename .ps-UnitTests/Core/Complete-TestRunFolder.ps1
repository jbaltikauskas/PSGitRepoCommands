function Complete-TestRunFolder () {
    <#
    .SYNOPSIS
        Keeps or removes the dated smoke-test folder.

    .DESCRIPTION
        When Keep is true, prints the folder path and leaves it in place.
        Otherwise deletes the folder with Clear-TestGitRepository.

    .PARAMETER repoPath
        Dated test folder created for this run.

    .PARAMETER keep
        Leave the folder when true.

    .NOTES
        1. Print and return when Keep is true.
        2. Otherwise delete the folder and print that it was removed.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Dated test folder for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath,

        [Parameter(Mandatory = $true, HelpMessage = "Leave the dated folder in place when true.")]
        [bool]$keep
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if ($keep) {
            Write-Host ("Keeping dated test folder: {0}" -f $repoPath) -ForegroundColor Yellow
            return
        }

        Clear-TestGitRepository -repoPath $repoPath
        Write-Host 'Removed dated test folder under tests/.' -ForegroundColor Green
    }
}
