function Get-GitBranch () {
    <#
    .SYNOPSIS
        Lists Git branches or returns the current branch as a PSCustomObject.

    .DESCRIPTION
        By default lists local branches as objects with Name, IsCurrent,
        IsRemote, Upstream, and Path. Use -remote or -all for remote-tracking or
        combined lists. When -current is set, returns a single PSCustomObject
        with Name, Path, and IsCurrent (throws on detached HEAD).

    .NOTES
        1. Resolve and assert the repository path.
        2. If -current, return a PSCustomObject for the symbolic-ref short name.
        3. Otherwise list refs via for-each-ref for local and/or remotes.
        4. Emit PSCustomObject rows for each branch.

    .EXAMPLE
        PS> Get-GitBranch
        Lists local branches as PSCustomObject rows (Name, IsCurrent, IsRemote, Upstream, Path).

        PS> Get-GitBranch -all
        Lists local and remote-tracking branches.

        PS> (Get-GitBranch -current).Name
        Returns only the current branch name string via the -current object.

    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'List', HelpMessage = "Include remote-tracking branches only.")]
        [switch]$remote,

        [Parameter(Mandatory = $false, ParameterSetName = 'List', HelpMessage = "Include both local and remote-tracking branches.")]
        [switch]$all,

        [Parameter(Mandatory = $false, ParameterSetName = 'Current', HelpMessage = "Return only the current branch as a PSCustomObject.")]
        [switch]$current
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ($current) {
            [string]$name = Invoke-Git -path $resolvedPath -arguments @('symbolic-ref', '--short', 'HEAD')

            return [PSCustomObject]@{
                Name      = $name.Trim()
                Path      = $resolvedPath
                IsCurrent = $true
            }
        }

        [string]$headName = ''
        $headRaw = Invoke-Git -path $resolvedPath -arguments @('symbolic-ref', '--short', 'HEAD') -allowNonZeroExit

        if (-not [string]::IsNullOrWhiteSpace($headRaw)) {
            $headName = $headRaw.Trim()
        }

        [System.Collections.Generic.List[object]]$results = [System.Collections.Generic.List[object]]::new()

        if ((-not $remote) -or $all) {
            [string]$localRaw = Invoke-Git -path $resolvedPath -arguments @(
                'for-each-ref',
                '--format=%(refname:short)|%(upstream:short)',
                'refs/heads'
            )

            if (-not [string]::IsNullOrWhiteSpace($localRaw)) {
                foreach ($line in ($localRaw -split "`n")) {
                    if ([string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }

                    [string[]]$parts = $line -split '\|', 2
                    [string]$branchName = $parts[0]
                    [string]$upstream = ''

                    if ($parts.Count -gt 1) {
                        $upstream = $parts[1]
                    }

                    $results.Add([PSCustomObject]@{
                            Name      = $branchName
                            IsCurrent = ($branchName -eq $headName)
                            IsRemote  = $false
                            Upstream  = $upstream
                            Path      = $resolvedPath
                        })
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($headName)) {
                # Unborn branch (repo with no commits yet): HEAD name exists but refs/heads is empty.
                $results.Add([PSCustomObject]@{
                        Name      = $headName
                        IsCurrent = $true
                        IsRemote  = $false
                        Upstream  = ''
                        Path      = $resolvedPath
                    })
            }
        }

        if ($remote -or $all) {
            [string]$remoteRaw = Invoke-Git -path $resolvedPath -arguments @(
                'for-each-ref',
                '--format=%(refname:short)',
                'refs/remotes'
            )

            if (-not [string]::IsNullOrWhiteSpace($remoteRaw)) {
                foreach ($line in ($remoteRaw -split "`n")) {
                    if ([string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }

                    [string]$branchName = $line.Trim()

                    if ($branchName -match '/HEAD$') {
                        continue
                    }

                    $results.Add([PSCustomObject]@{
                            Name      = $branchName
                            IsCurrent = $false
                            IsRemote  = $true
                            Upstream  = ''
                            Path      = $resolvedPath
                        })
                }
            }
        }

        return $results.ToArray()
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
