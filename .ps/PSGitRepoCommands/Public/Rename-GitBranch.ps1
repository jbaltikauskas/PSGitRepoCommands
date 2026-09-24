function Rename-GitBranch () {
    <#
    .SYNOPSIS
        Renames a local Git branch.

    .DESCRIPTION
        Renames OldName to NewName using git branch -m. When OldName is omitted,
        renames the current branch. Returns a PSCustomObject with OldName,
        NewName, and Path.

    .NOTES
        1. Resolve and assert the repository path.
        2. Default OldName to the current branch when omitted.
        3. Invoke git branch -m and return a PSCustomObject result.

    .EXAMPLE
        PS> Rename-GitBranch -newName 'feature/bar'
        Renames the current branch to feature/bar.

        PS> Rename-GitBranch -oldName 'feature/foo' -newName 'feature/bar'
        Renames feature/foo to feature/bar and returns OldName, NewName, Path.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "New branch name.")]
        [ValidateNotNullOrEmpty()]
        [string]$newName,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Existing branch name. Defaults to the current branch.")]
        [ValidateNotNullOrEmpty()]
        [string]$oldName,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Rename-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ([string]::IsNullOrWhiteSpace($oldName)) {
            $oldName = (Get-GitCurrentBranch -path $resolvedPath).Name
        }

        $null = Invoke-Git -path $resolvedPath -arguments @('branch', '-m', $oldName, $newName)

        return [PSCustomObject]@{
            OldName = $oldName
            NewName = $newName
            Path    = $resolvedPath
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Rename-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
