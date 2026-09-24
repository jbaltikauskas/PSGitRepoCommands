function Get-GitBranchCommitsByAuthorOrEmail () {
    <#
    .SYNOPSIS
        Returns commits on one branch whose author name or author email matches.

    .DESCRIPTION
        Looks up commits that are on Branch (local name, or origin/Branch).
        The default input is -author, a case-insensitive substring of the author
        name. -email is an exact, case-insensitive author email address. Matches
        are newest first: Number 1 is the latest commit. -limit defaults to 20
        and stops after that many matches. Each commit is a PSCustomObject with
        metadata, Files, Patch when requested, and WorkItems. No files are written;
        use Export-GitBranchCommitsByAuthorOrEmail for JSON. An unknown author or
        email returns CommitCount 0. Throws when the branch is missing.

    .NOTES
        1. Optionally fetch, then resolve Branch to a local or origin ref.
        2. List commit hash, author name, and author email from the branch tip, newest first.
        3. Keep rows whose author name contains -author, or whose email equals -email, until Limit.
        4. Load each kept match and return the collection.

    .EXAMPLE
        PS> Get-GitBranchCommitsByAuthorOrEmail -branch main -author 'Jane'
        Returns the latest 20 commits on main whose author name contains Jane. Number 1 is the newest.

        PS> Get-GitBranchCommitsByAuthorOrEmail -branch main -email jane@example.com -limit 5 -includePatch:$false
        Returns the latest 5 commits on main authored by that email, without patch text.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByAuthor')]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Branch that contains the commits (e.g. main).")]
        [ValidateNotNullOrEmpty()]
        [string]$branch,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByAuthor', HelpMessage = "Case-insensitive substring of the author name. This is the default input.")]
        [ValidateNotNullOrEmpty()]
        [string]$author,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByEmail', HelpMessage = "Author email address. Match is exact and case-insensitive.")]
        [ValidateNotNullOrEmpty()]
        [string]$email,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before resolving the branch. Turn off with -fetch:`$false.")]
        [bool]$fetch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Include each commit's full patch text. Turn off with -includePatch:`$false.")]
        [bool]$includePatch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Maximum matching commits to return, newest first. Default is 20.")]
        [ValidateRange(1, 2147483647)]
        [int]$limit = 20
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranchCommitsByAuthorOrEmail ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ($fetch) {
            $null = Invoke-Git -path $resolvedPath -arguments @('fetch', '--all', '--prune')
        }

        $branchRef = Resolve-GitBranchRef -path $resolvedPath -branch $branch -require
        [bool]$byEmail = $PSCmdlet.ParameterSetName -eq 'ByEmail'
        [string]$authorFilter = ''
        [string]$emailFilter = ''

        if ($byEmail) {
            $emailFilter = $email.Trim()

            if ([string]::IsNullOrWhiteSpace($emailFilter)) {
                throw 'Email is empty.'
            }
        }
        else {
            $authorFilter = $author.Trim()

            if ([string]::IsNullOrWhiteSpace($authorFilter)) {
                throw 'Author is empty.'
            }
        }

        [string]$logRaw = Invoke-Git -path $resolvedPath -arguments @(
            'log',
            '--format=%H%x1f%an%x1f%ae',
            $branchRef.Ref
        )

        [System.Collections.Generic.List[string]]$matchedHashes = [System.Collections.Generic.List[string]]::new()

        if (-not [string]::IsNullOrWhiteSpace($logRaw)) {
            foreach ($line in ($logRaw -split "`n")) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }

                [string[]]$bits = @($line -split [char]0x1f, 3)
                [string]$hash = if ($bits.Count -gt 0) { $bits[0].Trim() } else { '' }
                [string]$authorName = if ($bits.Count -gt 1) { $bits[1] } else { '' }
                [string]$authorEmail = if ($bits.Count -gt 2) { $bits[2].Trim() } else { '' }

                if ([string]::IsNullOrWhiteSpace($hash)) {
                    continue
                }

                [bool]$match = $false

                if ($byEmail) {
                    $match = $authorEmail.Equals($emailFilter, [System.StringComparison]::OrdinalIgnoreCase)
                }
                else {
                    $match = $authorName.IndexOf($authorFilter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
                }

                if ($match) {
                    $matchedHashes.Add($hash)

                    if ($matchedHashes.Count -ge $limit) {
                        break
                    }
                }
            }
        }

        [System.Collections.Generic.List[object]]$commits = [System.Collections.Generic.List[object]]::new()
        [int]$number = 0

        foreach ($hash in $matchedHashes) {
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
            [string]$authorName = if ($parts.Count -gt 2) { $parts[2] } else { '' }
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
                foreach ($numLine in ($numStatRaw -split "`n")) {
                    $num = Convert-GitNumStatLine -line $numLine

                    if ($null -ne $num) {
                        $numStatByPath[$num.Path] = $num
                    }
                }
            }

            [System.Collections.Generic.List[object]]$files = [System.Collections.Generic.List[object]]::new()

            if (-not [string]::IsNullOrWhiteSpace($nameStatusRaw)) {
                foreach ($statusLine in ($nameStatusRaw -split "`n")) {
                    $ns = Convert-GitNameStatusLine -line $statusLine

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
                    $hash
                )
            }

            $commits.Add([PSCustomObject]@{
                    Number      = $number
                    Hash        = $fullHash
                    Short       = $short
                    Author      = $authorName
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
                })
        }

        $result = [ordered]@{
            Path         = $resolvedPath
            Branch       = $branchRef.Branch
            Ref          = $branchRef.Ref
            Author       = $authorFilter
            Email        = $emailFilter
            CommitCount  = $commits.Count
            Limit        = $limit
            IncludePatch = $includePatch
            Commits      = $commits.ToArray()
            GeneratedAt  = (Get-Date).ToString('o')
        }

        return [PSCustomObject]$result
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranchCommitsByAuthorOrEmail ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
