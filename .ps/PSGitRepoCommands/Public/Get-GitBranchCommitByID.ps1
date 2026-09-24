function Get-GitBranchCommitByID () {
    <#
    .SYNOPSIS
        Returns the latest commits on one branch, or one commit selected by id.

    .DESCRIPTION
        The default is the latest commits on Branch (local name, or origin/Branch),
        newest first. Number 1 is the latest commit. -limit defaults to 20 and
        stops after that many commits. -shortHash, -number, and -hash still
        return one commit; -number is counted from the tip and must be within
        -limit. Each commit is a PSCustomObject with metadata, Files, Patch when
        requested, and WorkItems parsed from the subject and body (#id Azure,
        AB#id Azure Boards). No files are written; use Export-GitBranchCommitByID
        for JSON output. Throws when the commit is missing, is not on the branch,
        or the prefix is ambiguous.

    .NOTES
        1. Optionally fetch, then resolve Branch to a local or origin ref.
        2. For the default set, take the newest commits up to Limit.
        3. For an id, select that one commit with rev-parse or rev-list.
        4. Reject a hash that is not contained in the branch, or a number past Limit.
        5. Return the commit collection, or that one commit.

    .EXAMPLE
        PS> Get-GitBranchCommitByID -branch main
        Returns the latest 20 commits on main. Number 1 is the newest.

        PS> Get-GitBranchCommitByID -branch main -limit 5 -includePatch:$false
        Returns the latest 5 commits on main, without patch text.

        PS> Get-GitBranchCommitByID -branch main -shortHash a1b2c3d
        Returns the one commit on main whose short hash is a1b2c3d.

        PS> Get-GitBranchCommitByID -branch main -number 1
        Returns the latest commit on main.

        PS> Get-GitBranchCommitByID -branch main -hash 0123456789abcdef0123456789abcdef01234567
        Returns the commit with that full hash when it is on main.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Latest')]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Branch that contains the commit (e.g. main).")]
        [ValidateNotNullOrEmpty()]
        [string]$branch,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByShortHash', HelpMessage = "Short hash or unique hash prefix. Selects one commit.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[0-9a-fA-F]{4,40}$')]
        [string]$shortHash,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNumber', HelpMessage = "1-based position from the branch tip, within -limit. 1 is the latest commit.")]
        [ValidateRange(1, 2147483647)]
        [int]$number,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByHash', HelpMessage = "Full 40-character commit hash.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string]$hash,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before resolving the branch. Turn off with -fetch:`$false.")]
        [bool]$fetch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Include the commit's full patch text. Turn off with -includePatch:`$false.")]
        [bool]$includePatch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Maximum commits to return, newest first. Default is 20. -number must be within this window.")]
        [ValidateRange(1, 2147483647)]
        [int]$limit = 20
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranchCommitByID ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ($fetch) {
            $null = Invoke-Git -path $resolvedPath -arguments @('fetch', '--all', '--prune')
        }

        $branchRef = Resolve-GitBranchRef -path $resolvedPath -branch $branch -require
        [bool]$latest = $PSCmdlet.ParameterSetName -eq 'Latest'
        [System.Collections.Generic.List[string]]$selectedHashes = [System.Collections.Generic.List[string]]::new()
        [int]$singleNumber = 0

        if ($latest) {
            [string]$hashRaw = Invoke-Git -path $resolvedPath -arguments @(
                'rev-list',
                "--max-count=$limit",
                $branchRef.Ref
            )

            if (-not [string]::IsNullOrWhiteSpace($hashRaw)) {
                foreach ($line in ($hashRaw -split "`n")) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                        $selectedHashes.Add($line.Trim())
                    }
                }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByNumber') {
            if ($number -gt $limit) {
                throw "Commit number $number is outside the latest $limit commits on branch '$branch'. Raise -limit to include it."
            }

            [string]$numberedHash = Invoke-Git -path $resolvedPath -arguments @(
                'rev-list',
                '--max-count=1',
                '--skip',
                ($number - 1),
                $branchRef.Ref
            )

            if ([string]::IsNullOrWhiteSpace($numberedHash)) {
                [string]$commitCount = Invoke-Git -path $resolvedPath -arguments @('rev-list', '--count', $branchRef.Ref)
                throw "Commit number $number was not found on branch '$branch' ($($branchRef.Ref)). CommitCount=$commitCount."
            }

            $selectedHashes.Add($numberedHash.Trim())
            $singleNumber = $number
        }
        else {
            [string]$commitId = if ($PSCmdlet.ParameterSetName -eq 'ByShortHash') { $shortHash } else { $hash }

            [string]$selectedHash = Invoke-Git -path $resolvedPath -arguments @(
                'rev-parse',
                '--verify',
                "${commitId}^{commit}"
            )

            [string]$mergeBase = ''

            try {
                $mergeBase = Invoke-Git -path $resolvedPath -arguments @('merge-base', $selectedHash, $branchRef.Ref)
            }
            catch {
                throw "Commit '$commitId' was not found on branch '$branch' ($($branchRef.Ref))."
            }

            if ($mergeBase.Trim().ToLowerInvariant() -ne $selectedHash.ToLowerInvariant()) {
                throw "Commit '$commitId' is not on branch '$branch' ($($branchRef.Ref))."
            }

            [string]$afterCount = Invoke-Git -path $resolvedPath -arguments @(
                'rev-list',
                '--count',
                "$selectedHash..$($branchRef.Ref)"
            )
            $singleNumber = ([int]$afterCount) + 1
            $selectedHashes.Add($selectedHash.Trim())
        }

        [System.Collections.Generic.List[object]]$commits = [System.Collections.Generic.List[object]]::new()
        [int]$index = 0

        foreach ($selectedHash in $selectedHashes) {
            $index++
            [int]$commitNumber = if ($latest) { $index } else { $singleNumber }

            [string]$metaRaw = Invoke-Git -path $resolvedPath -arguments @(
                'show',
                '-s',
                '--format=%H%n%h%n%an%n%ae%n%aI%n%cn%n%cI%n%s',
                $selectedHash
            )

            [string[]]$parts = @($metaRaw -split "`n")
            [string]$fullHash = if ($parts.Count -gt 0) { $parts[0] } else { $selectedHash }
            [string]$short = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            [string]$author = if ($parts.Count -gt 2) { $parts[2] } else { '' }
            [string]$authorEmail = if ($parts.Count -gt 3) { $parts[3] } else { '' }
            [string]$authorDate = if ($parts.Count -gt 4) { $parts[4] } else { '' }
            [string]$committer = if ($parts.Count -gt 5) { $parts[5] } else { '' }
            [string]$commitDate = if ($parts.Count -gt 6) { $parts[6] } else { '' }
            [string]$subject = if ($parts.Count -gt 7) { $parts[7] } else { '' }

            [string]$body = Invoke-Git -path $resolvedPath -arguments @(
                'show',
                '-s',
                '--format=%b',
                $selectedHash
            )

            [string]$nameStatusRaw = Invoke-Git -path $resolvedPath -arguments @(
                'diff-tree',
                '--no-commit-id',
                '--name-status',
                '-r',
                '--root',
                $selectedHash
            )

            [string]$numStatRaw = Invoke-Git -path $resolvedPath -arguments @(
                'diff-tree',
                '--no-commit-id',
                '--numstat',
                '-r',
                '--root',
                $selectedHash
            )

            $numStatByPath = @{}

            if (-not [string]::IsNullOrWhiteSpace($numStatRaw)) {
                foreach ($line in ($numStatRaw -split "`n")) {
                    $num = Convert-GitNumStatLine -line $line

                    if ($null -ne $num) {
                        $numStatByPath[$num.Path] = $num
                    }
                }
            }

            [System.Collections.Generic.List[object]]$files = [System.Collections.Generic.List[object]]::new()

            if (-not [string]::IsNullOrWhiteSpace($nameStatusRaw)) {
                foreach ($line in ($nameStatusRaw -split "`n")) {
                    $ns = Convert-GitNameStatusLine -line $line

                    if ($null -eq $ns) {
                        continue
                    }

                    [int]$additions = -1
                    [int]$deletions = -1

                    if ($numStatByPath.ContainsKey($ns.Path)) {
                        $additions = $numStatByPath[$ns.Path].Additions
                        $deletions = $numStatByPath[$ns.Path].Deletions
                    }

                    $files.Add([PSCustomObject]@{
                            Status    = $ns.Status
                            Path      = $ns.Path
                            OldPath   = $ns.OldPath
                            Additions = $additions
                            Deletions = $deletions
                        })
                }
            }

            [string]$patch = ''

            if ($includePatch) {
                $patch = Invoke-Git -path $resolvedPath -arguments @(
                    'show',
                    '--stat',
                    '-p',
                    $selectedHash
                )
            }

            $commits.Add([PSCustomObject][ordered]@{
                    Path         = $resolvedPath
                    Branch       = $branchRef.Branch
                    Ref          = $branchRef.Ref
                    Number       = $commitNumber
                    Hash         = $fullHash
                    Short        = $short
                    Author       = $author
                    AuthorEmail  = $authorEmail
                    AuthorDate   = $authorDate
                    Committer    = $committer
                    CommitDate   = $commitDate
                    Subject      = $subject
                    Body         = $body
                    WorkItems    = @(Get-GitCommitWorkItems -subject $subject -body $body)
                    Files        = $files.ToArray()
                    FileCount    = $files.Count
                    Patch        = $patch
                    IncludePatch = $includePatch
                })
        }

        if (-not $latest) {
            return $commits[0]
        }

        return [PSCustomObject][ordered]@{
            Path         = $resolvedPath
            Branch       = $branchRef.Branch
            Ref          = $branchRef.Ref
            CommitCount  = $commits.Count
            Limit        = $limit
            IncludePatch = $includePatch
            Commits      = $commits.ToArray()
            GeneratedAt  = (Get-Date).ToString('o')
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranchCommitByID ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
