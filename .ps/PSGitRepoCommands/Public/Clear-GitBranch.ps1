function Clear-GitBranch () {
    <#
    .SYNOPSIS
        Prunes stale remote-tracking refs and optionally deletes gone locals.

    .DESCRIPTION
        Runs fetch --prune against RemoteName (default origin). When -gone is
        set, deletes local branches whose upstream is marked gone after prune.
        Never deletes the current branch. Returns a PSCustomObject with Path,
        RemoteName, Gone, Force, and DeletedBranches.

    .NOTES
        1. Resolve and assert the repository path.
        2. Fetch --prune from the remote.
        3. When -gone, parse branch -vv for gone upstreams and delete those locals.
        4. Return a PSCustomObject of the clear result.

    .EXAMPLE
        PS> Clear-GitBranch
        Prunes stale remote-tracking refs on origin (fetch --prune).

        PS> Clear-GitBranch -gone -force
        Prunes remotes and force-deletes local branches whose upstream is gone.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Remote to prune. Default origin.")]
        [ValidateNotNullOrEmpty()]
        [string]$remoteName = 'origin',

        [Parameter(Mandatory = $false, HelpMessage = "Also delete local branches whose upstream is gone.")]
        [switch]$gone,

        [Parameter(Mandatory = $false, HelpMessage = "Force-delete gone local branches (-D).")]
        [switch]$force
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Clear-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        $null = Invoke-Git -path $resolvedPath -arguments @('fetch', '--prune', $remoteName)

        [System.Collections.Generic.List[string]]$deleted = [System.Collections.Generic.List[string]]::new()

        if ($gone) {
            [string]$current = (Get-GitCurrentBranch -path $resolvedPath).Name
            [string]$vvRaw = Invoke-Git -path $resolvedPath -arguments @('branch', '-vv')

            if (-not [string]::IsNullOrWhiteSpace($vvRaw)) {
                [string]$deleteFlag = if ($force) { '-D' } else { '-d' }

                foreach ($line in ($vvRaw -split "`n")) {
                    if ($line -notmatch '\[gone\]') {
                        continue
                    }

                    [string]$withoutMarker = $line.Trim() -replace '^\*\s+', ''
                    [string]$branchName = ($withoutMarker -split '\s+')[0]

                    if ([string]::IsNullOrWhiteSpace($branchName)) {
                        continue
                    }

                    if ($branchName -eq $current) {
                        continue
                    }

                    $null = Invoke-Git -path $resolvedPath -arguments @('branch', $deleteFlag, $branchName)
                    $deleted.Add($branchName)
                }
            }
        }

        $result = [ordered]@{
            Path            = $resolvedPath
            RemoteName      = $remoteName
            Gone            = $gone.IsPresent
            Force           = $force.IsPresent
            DeletedBranches = $deleted.ToArray()
        }

        return [PSCustomObject]$result
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Clear-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
