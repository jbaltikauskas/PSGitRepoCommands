<#
.SYNOPSIS
    Export per-commit diffs and one full branch diff between two Git branches.

.DESCRIPTION
    Compares two branches (default: main and qa) and writes an output folder containing:
      - One numbered subfolder per differing commit, each holding:
          * commit-info.txt    (hash, author, dates, subject, body = the "names")
          * changed-files.txt   (name-status + numstat = the "files")
          * <shorthash>.patch   (full patch for that single commit)
          * files\...           (optional snapshots of each changed file at that commit)
      - _full-diff_<base>_vs_<target>.diff   (tip-to-tip diff between the branches)
      - _full-diff_summary.txt               (git diff --stat)
      - _full-diff_name-status.txt           (changed file list for the full diff)
      - _INDEX.md                            (run metadata + a table of every commit)
      - _INDEX.json                          (same metadata + commits as a JSON collection)

.PARAMETER RepoPath
    Path to the Git repository. Defaults to the current directory.

.PARAMETER BaseBranch
    First branch. Default: main

.PARAMETER TargetBranch
    Second branch. Default: qa

.PARAMETER OutputPath
    Where to write the export. Defaults to
    <RepoPath>\branch-diff_<base>_vs_<target>_<timestamp>.

.PARAMETER Direction
    Which commits count as "the differences":
      TargetAhead  commits in TargetBranch not in BaseBranch  (base..target)   [default]
      BaseAhead    commits in BaseBranch not in TargetBranch  (target..base)
      Both         symmetric difference                        (base...target)

.PARAMETER Fetch
    Run 'git fetch --all --prune' before comparing.

.PARAMETER ExportFileSnapshots
    Also copy each changed file's content at that commit into <subfolder>\files\.
    Intended for text/code files. Deleted files are skipped.

.EXAMPLE
    .\Export-BranchDiff.ps1 -RepoPath 'C:\dev.Docker\Local.MultiProject.SonarCube'

.EXAMPLE
    .\Export-BranchDiff.ps1 -RepoPath 'C:\dev.Docker\Local.MultiProject.SonarCube' -Direction Both -Fetch

.EXAMPLE
    .\Export-BranchDiff.ps1 -BaseBranch main -TargetBranch qa -ExportFileSnapshots
#>

[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [string]$BaseBranch = 'main',
    [string]$TargetBranch = 'demo',
    [string]$OutputPath,
    [ValidateSet('TargetAhead', 'BaseAhead', 'Both')]
    [string]$Direction = 'Both',
    [switch]$Fetch,
    [switch]$ExportFileSnapshots
)

# Probe commands (rev-parse --verify) exit 1 when a ref is missing. This script
# checks $LASTEXITCODE and tries origin/<branch>; do not turn that into a throw.
$PSNativeCommandUseErrorActionPreference = $false

# ---------- helpers ----------

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-TextFile {
    param([string]$Path, [string]$Content)
    if ($null -eq $Content) {
        $Content = ''
    }
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function New-Folder {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Get-SafeName {
    param([string]$Name, [int]$MaxLength = 50)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return 'no-subject'
    }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = '[{0}]' -f [Regex]::Escape($invalid)
    $safe = [Regex]::Replace($Name, $pattern, '_')
    $safe = $safe -replace '\s+', '_'
    $safe = $safe -replace '_+', '_'
    $safe = $safe.Trim('_. ')
    if ($safe.Length -gt $MaxLength) {
        $safe = $safe.Substring(0, $MaxLength).Trim('_. ')
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'no-subject'
    }
    return $safe
}

# ---------- preconditions ----------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH. Install Git or open a shell where 'git' is available."
}

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "RepoPath does not exist: $RepoPath"
}
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

# common git prefix (no pager, no color) so output is clean when redirected to files
$g = @('-C', $RepoPath, '--no-pager', '-c', 'color.ui=false')

$null = git @g rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Not a Git repository: $RepoPath"
}

if ($Fetch) {
    Write-Host "Fetching remotes..." -ForegroundColor Cyan
    git @g fetch --all --prune
}

function Resolve-BranchRef {
    param([string]$Branch)
    git @g rev-parse --verify --quiet "$Branch^{commit}" 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        return $Branch
    }
    git @g rev-parse --verify --quiet "origin/$Branch^{commit}" 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        return "origin/$Branch"
    }
    return $null
}

$baseRef = Resolve-BranchRef -Branch $BaseBranch
$targetRef = Resolve-BranchRef -Branch $TargetBranch

if (-not $baseRef) {
    throw "Base branch '$BaseBranch' not found locally or as origin/$BaseBranch."
}
if (-not $targetRef) {
    throw "Target branch '$TargetBranch' not found locally or as origin/$TargetBranch."
}

# ---------- resolve range ----------

switch ($Direction) {
    'TargetAhead' { $range = "$baseRef..$targetRef"; $rangeDesc = "commits in $TargetBranch not in $BaseBranch" }
    'BaseAhead' { $range = "$targetRef..$baseRef"; $rangeDesc = "commits in $BaseBranch not in $TargetBranch" }
    'Both' { $range = "$baseRef...$targetRef"; $rangeDesc = "commits in exactly one of $BaseBranch / $TargetBranch" }
}

# ---------- output folder ----------

$safeBase = ($BaseBranch -replace '[\\/]', '-')
$safeTarget = ($TargetBranch -replace '[\\/]', '-')

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = Join-Path $RepoPath ("branch-diff_{0}_vs_{1}_{2}" -f $safeBase, $safeTarget, $stamp)
}
New-Folder -Path $OutputPath
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

Write-Host "Repo:      $RepoPath"       -ForegroundColor Green
Write-Host "Base:      $BaseBranch ($baseRef)"   -ForegroundColor Green
Write-Host "Target:    $TargetBranch ($targetRef)" -ForegroundColor Green
Write-Host "Direction: $Direction  ->  $rangeDesc" -ForegroundColor Green
Write-Host "Output:    $OutputPath"     -ForegroundColor Green
Write-Host ""

# ---------- full diff (tip to tip) ----------

$fullDiffPath = Join-Path $OutputPath ("_full-diff_{0}_vs_{1}.diff" -f $safeBase, $safeTarget)
$fullDiff = (git @g diff $baseRef $targetRef) -join "`n"
Write-TextFile -Path $fullDiffPath -Content ($fullDiff + "`n")

$fullStat = (git @g diff --stat $baseRef $targetRef) -join "`n"
Write-TextFile -Path (Join-Path $OutputPath '_full-diff_summary.txt') -Content ($fullStat + "`n")

$fullNameStatus = (git @g diff --name-status $baseRef $targetRef) -join "`n"
Write-TextFile -Path (Join-Path $OutputPath '_full-diff_name-status.txt') -Content ($fullNameStatus + "`n")

Write-Host "Wrote full branch diff." -ForegroundColor Cyan

# ---------- per-commit export ----------

$commits = @(git @g log --reverse --format=%H $range | Where-Object { $_ })
$total = $commits.Count

$indexRows = New-Object System.Collections.Generic.List[string]
$commitEntries = New-Object System.Collections.Generic.List[PSCustomObject]

if ($total -eq 0) {
    Write-Host "No differing commits for the selected direction." -ForegroundColor Yellow
}
else {
    Write-Host "Exporting $total commit(s)..." -ForegroundColor Cyan
    $n = 0
    foreach ($hash in $commits) {
        $n++

        $fmt = '%H%n%h%n%an%n%ae%n%aI%n%cn%n%cI%n%s'
        $parts = @(git @g show -s --format=$fmt $hash)
        $short = $parts[1]
        $author = $parts[2]
        $authorEmail = $parts[3]
        $authorDate = $parts[4]
        $committer = $parts[5]
        $commitDate = $parts[6]
        $subject = $parts[7]
        $body = (git @g show -s --format=%b $hash) -join "`n"

        $folderName = '{0:D3}_{1}_{2}' -f $n, $short, (Get-SafeName -Name $subject)
        $commitDir = Join-Path $OutputPath $folderName
        New-Folder -Path $commitDir

        # commit-info.txt
        $info = @(
            "Commit:        $hash"
            "Short:         $short"
            "Author:        $author <$authorEmail>"
            "Author date:   $authorDate"
            "Committer:     $committer"
            "Commit date:   $commitDate"
            ""
            "Subject:"
            "  $subject"
            ""
            "Body:"
            $body
        ) -join "`n"
        Write-TextFile -Path (Join-Path $commitDir 'commit-info.txt') -Content ($info + "`n")

        # changed-files.txt  (name-status + numstat)
        $nameStatus = @(git @g diff-tree --no-commit-id --name-status -r --root $hash)
        $numStat = @(git @g diff-tree --no-commit-id --numstat   -r --root $hash)
        $filesText = @(
            "Files changed in $short  ($subject)"
            ""
            "name-status (A=added, M=modified, D=deleted, R=renamed):"
            ($nameStatus -join "`n")
            ""
            "numstat (added  deleted  path):"
            ($numStat -join "`n")
        ) -join "`n"
        Write-TextFile -Path (Join-Path $commitDir 'changed-files.txt') -Content ($filesText + "`n")

        # <short>.patch  (full patch for this single commit)
        $patch = (git @g show --stat -p $hash) -join "`n"
        Write-TextFile -Path (Join-Path $commitDir ("{0}.patch" -f $short)) -Content ($patch + "`n")

        # optional: snapshot each changed file at this commit
        if ($ExportFileSnapshots) {
            $filesRoot = Join-Path $commitDir 'files'
            foreach ($line in $nameStatus) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                $tokens = $line -split "`t"
                $status = $tokens[0]
                # deleted, nothing to snapshot
                if ($status.StartsWith('D')) {
                    continue
                }
                $path = $tokens[-1]
                $dest = Join-Path $filesRoot ($path -replace '/', '\')
                New-Folder -Path (Split-Path -Parent $dest)
                $content = (git @g show ("{0}:{1}" -f $hash, $path)) -join "`n"
                Write-TextFile -Path $dest -Content $content
            }
        }

        $fileCount = @($nameStatus | Where-Object { $_ }).Count
        $indexRows.Add(('| {0} | `{1}` | {2} | {3} | {4} | {5} | {6} |' -f `
                    $n, $short, $commitDate, $author, $fileCount, ($subject -replace '\|', '\|'), $folderName))

        $commitEntries.Add([PSCustomObject]@{
                number       = $n
                hash         = $hash
                short        = $short
                author       = $author
                authorEmail  = $authorEmail
                authorDate   = $authorDate
                committer    = $committer
                commitDate   = $commitDate
                subject      = $subject
                body         = $body
                filesChanged = $fileCount
                folder       = $folderName
            })

        Write-Host ("  [{0}/{1}] {2}  {3}" -f $n, $total, $short, $subject)
    }
}

# ---------- index ----------

$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$fullDiffFileName = [System.IO.Path]::GetFileName($fullDiffPath)

$indexHeader = @(
    "# Branch diff export"
    ""
    "- Repository: ``$RepoPath``"
    "- Base branch: ``$BaseBranch`` ($baseRef)"
    "- Target branch: ``$TargetBranch`` ($targetRef)"
    "- Direction: ``$Direction`` ($rangeDesc)"
    "- Range: ``$range``"
    "- Generated: $generatedAt"
    "- Commits exported: $total"
    "- File snapshots: $([bool]$ExportFileSnapshots)"
    ""
    "## Full diff"
    ""
    "- [$fullDiffFileName]($fullDiffFileName)"
    "- [_full-diff_summary.txt](_full-diff_summary.txt)"
    "- [_full-diff_name-status.txt](_full-diff_name-status.txt)"
    ""
    "## Commits"
    ""
) -join "`n"

if ($total -gt 0) {
    $tableHead = @(
        "| # | Short | Date | Author | Files | Subject | Folder |"
        "|---|-------|------|--------|-------|---------|--------|"
    ) -join "`n"
    $indexContent = $indexHeader + $tableHead + "`n" + ($indexRows -join "`n") + "`n"
}
else {
    $indexContent = $indexHeader + "_No differing commits for the selected direction._`n"
}

Write-TextFile -Path (Join-Path $OutputPath '_INDEX.md') -Content $indexContent

$indexJson = [PSCustomObject]@{
    title            = 'Branch diff export'
    repository       = $RepoPath
    baseBranch       = $BaseBranch
    baseRef          = $baseRef
    targetBranch     = $TargetBranch
    targetRef        = $targetRef
    direction        = $Direction
    rangeDescription = $rangeDesc
    range            = $range
    generated        = $generatedAt
    commitsExported  = $total
    fileSnapshots    = [bool]$ExportFileSnapshots
    fullDiff         = @{
        diff       = $fullDiffFileName
        summary    = '_full-diff_summary.txt'
        nameStatus = '_full-diff_name-status.txt'
    }
    commits          = $commitEntries
}

$jsonText = $indexJson | ConvertTo-Json -Depth 10
Write-TextFile -Path (Join-Path $OutputPath '_INDEX.json') -Content ($jsonText + "`n")

Write-Host ""
Write-Host "Done. Output: $OutputPath" -ForegroundColor Green