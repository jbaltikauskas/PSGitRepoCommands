function Remove-GitBranch () {
    <#
    .SYNOPSIS
        Deletes a local and/or remote Git branch.

    .DESCRIPTION
        Deletes local branch Name with git branch -d (or -D when -force). When
        -remote is set, also deletes the remote branch on RemoteName (default
        origin) via git push RemoteName --delete Name. Returns a PSCustomObject
        with Name, Path, Force, LocalDeleted, RemoteDeleted, and RemoteName.

    .NOTES
        1. Resolve and assert the repository path.
        2. Delete the local branch unless -remoteOnly.
        3. When -remote, push --delete to the remote.
        4. Return a PSCustomObject of the delete result.

    .EXAMPLE
        PS> Remove-GitBranch -name 'feature/foo' -force
        Force-deletes the local branch feature/foo.

        PS> Remove-GitBranch -name 'feature/foo' -remote -remoteName 'origin'
        Deletes the local branch and pushes --delete to origin.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Local branch name to delete.")]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Force delete an unmerged local branch (-D).")]
        [switch]$force,

        [Parameter(Mandatory = $false, HelpMessage = "Also delete the branch on the remote.")]
        [switch]$remote,

        [Parameter(Mandatory = $false, HelpMessage = "Delete only on the remote; skip local delete.")]
        [switch]$remoteOnly,

        [Parameter(Mandatory = $false, HelpMessage = "Remote name used with -remote / -remoteOnly. Default origin.")]
        [ValidateNotNullOrEmpty()]
        [string]$remoteName = 'origin'
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Remove-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path
        [bool]$localDeleted = $false
        [bool]$remoteDeleted = $false

        if (-not $remoteOnly) {
            [string]$deleteFlag = if ($force) { '-D' } else { '-d' }
            $null = Invoke-Git -path $resolvedPath -arguments @('branch', $deleteFlag, $name)
            $localDeleted = $true
        }

        if ($remote -or $remoteOnly) {
            $null = Invoke-Git -path $resolvedPath -arguments @('push', $remoteName, '--delete', $name)
            $remoteDeleted = $true
        }

        return [PSCustomObject]@{
            Name          = $name
            Path          = $resolvedPath
            Force         = $force.IsPresent
            LocalDeleted  = $localDeleted
            RemoteDeleted = $remoteDeleted
            RemoteName    = $remoteName
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Remove-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
