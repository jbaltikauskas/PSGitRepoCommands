function Get-GitBranchCommitDiff () {
    <#
    .SYNOPSIS
        Returns per-commit details for the differing commits between two branches.

    .DESCRIPTION
        Lists commits in the selected Direction range (TargetAhead, BaseAhead,
        or Both) oldest-first. Each commit is a PSCustomObject with metadata,
        structured Files (name-status + numstat), optionally Patch text, and
        WorkItems parsed from the subject and body (#id Azure, AB#id Azure Boards).
        No files are written; use Export-GitBranchFullDiff for JSON output.

    .NOTES
        1. Optionally fetch all remotes.
        2. Resolve the commit range from Direction.
        3. Enumerate commit hashes with git log --reverse.
        4. For each hash, collect show metadata, diff-tree files, optional patch.
        5. Return a PSCustomObject with a Commits array.

    .EXAMPLE
        PS> Get-GitBranchCommitDiff -baseBranch main -targetBranch feature/foo
        Lists commits in main..feature/foo with Files and metadata per commit.

        PS> (Get-GitBranchCommitDiff -baseBranch main -targetBranch qa -direction Both -includePatch:$true).Commits
        Symmetric differing commits including Patch text on each entry.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Base branch name (e.g. main).")]
        [ValidateNotNullOrEmpty()]
        [string]$baseBranch,

        [Parameter(Mandatory = $true, HelpMessage = "Target branch name (e.g. qa).")]
        [ValidateNotNullOrEmpty()]
        [string]$targetBranch,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Which commits count as differences.")]
        [ValidateSet('TargetAhead', 'BaseAhead', 'Both')]
        [string]$direction = 'Both',

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before comparing. Turn off with -fetch:`$false.")]
        [bool]$fetch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Include each commit's full patch text. Turn off with -includePatch:`$false.")]
        [bool]$includePatch = $true
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranchCommitDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ($fetch) {
            $null = Invoke-Git -path $resolvedPath -arguments @('fetch', '--all', '--prune')
        }

        $rangeInfo = Resolve-GitDiffRange -path $resolvedPath -baseBranch $baseBranch -targetBranch $targetBranch -direction $direction

        [string]$hashRaw = Invoke-Git -path $resolvedPath -arguments @(
            'log',
            '--reverse',
            '--format=%H',
            $rangeInfo.Range
        )

        [string[]]$hashes = @()

        if (-not [string]::IsNullOrWhiteSpace($hashRaw)) {
            $hashes = @(
                $hashRaw -split "`n" |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }

        [System.Collections.Generic.List[object]]$commits = [System.Collections.Generic.List[object]]::new()
        [int]$number = 0

        foreach ($hash in $hashes) {
            $number++

            [string]$metaRaw = Invoke-Git -path $resolvedPath -arguments @(
                'show',
                '-s',
                '--format=%H%n%h%n%an%n%ae%n%aI%n%cn%n%cI%n%s',
                $hash
            )

            [string[]]$parts = @($metaRaw -split "`n")
            [string]$fullHash = if ($parts.Count -gt 0) { $parts[0] } else { $hash }
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
                $hash
            )

            [string]$nameStatusRaw = Invoke-Git -path $resolvedPath -arguments @(
                'diff-tree',
                '--no-commit-id',
                '--name-status',
                '-r',
                '--root',
                $hash
            )

            [string]$numStatRaw = Invoke-Git -path $resolvedPath -arguments @(
                'diff-tree',
                '--no-commit-id',
                '--numstat',
                '-r',
                '--root',
                $hash
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

                    $fileResult = [ordered]@{
                        Status    = $ns.Status
                        Path      = $ns.Path
                        OldPath   = $ns.OldPath
                        Additions = $additions
                        Deletions = $deletions
                    }

                    $files.Add([PSCustomObject]$fileResult)
                }
            }

            [string]$patch = ''

            if ($includePatch) {
                $patch = Invoke-Git -path $resolvedPath -arguments @(
                    'show',
                    '--stat',
                    '-p',
                    $hash
                )
            }

            $commitResult = [ordered]@{
                Number      = $number
                Hash        = $fullHash
                Short       = $short
                Author      = $author
                AuthorEmail = $authorEmail
                AuthorDate  = $authorDate
                Committer   = $committer
                CommitDate  = $commitDate
                Subject     = $subject
                Body        = $body
                WorkItems   = @(Get-GitCommitWorkItems -subject $subject -body $body)
                Files       = $files.ToArray()
                FileCount   = $files.Count
                Patch       = $patch
            }

            $commits.Add([PSCustomObject]$commitResult)
        }

        $result = [ordered]@{
            Path             = $resolvedPath
            BaseBranch       = $rangeInfo.BaseBranch
            BaseRef          = $rangeInfo.BaseRef
            TargetBranch     = $rangeInfo.TargetBranch
            TargetRef        = $rangeInfo.TargetRef
            Direction        = $rangeInfo.Direction
            Range            = $rangeInfo.Range
            RangeDescription = $rangeInfo.RangeDescription
            CommitCount      = $commits.Count
            IncludePatch     = $includePatch
            Commits          = $commits.ToArray()
            GeneratedAt      = (Get-Date).ToString('o')
        }

        return [PSCustomObject]$result
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranchCommitDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
