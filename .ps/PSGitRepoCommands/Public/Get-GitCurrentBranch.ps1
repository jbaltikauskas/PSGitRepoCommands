function Get-GitCurrentBranch () {
    <#
    .SYNOPSIS
        Returns the currently checked-out branch as a PSCustomObject.

    .DESCRIPTION
        Resolves the repository at Path and returns a PSCustomObject with Name
        and Path for HEAD's short symbolic-ref. Throws when HEAD is detached or
        the path is not a Git repository.

    .NOTES
        1. Resolve and assert the repository path.
        2. Call Get-GitBranch -current and return its PSCustomObject.

    .EXAMPLE
        PS> Get-GitCurrentBranch
        Returns a PSCustomObject with Name, Path, and IsCurrent for HEAD.

        PS> (Get-GitCurrentBranch -path 'C:\repos\app').Name
        Gets the current branch name for a specific repository path.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitCurrentBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        return (Get-GitBranch -path $path -current)
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitCurrentBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
