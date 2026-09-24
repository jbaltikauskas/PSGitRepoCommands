function Get-GitBranchFullDiff () {
    <#
    .SYNOPSIS
        Returns the tip-to-tip file diff between two branches as a PSCustomObject.

    .DESCRIPTION
        Resolves BaseBranch and TargetBranch (local or origin/), builds the
        comparison context, and returns Summary text, structured Files
        (name-status + numstat), and optionally the full Patch. Inspired by
        Diff.ps1 tip-to-tip export; no files are written.

    .NOTES
        1. Optionally fetch all remotes.
        2. Resolve refs and range metadata.
        3. Collect diff --stat, --name-status, --numstat, and optional patch.
        4. Merge file rows into PSCustomObject entries.
        5. Return a PSCustomObject suitable for ConvertTo-Json.

    .EXAMPLE
        PS> Get-GitBranchFullDiff -baseBranch main -targetBranch feature/foo
        Tip-to-tip file changes; inspect .Files and .Summary on the result.

        PS> Get-GitBranchFullDiff -baseBranch main -targetBranch qa -direction Both -includePatch
        Symmetric range metadata plus full patch text in .Patch.

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

        [Parameter(Mandatory = $false, HelpMessage = "Which commits define the range metadata (does not change tip-to-tip file diff).")]
        [ValidateSet('TargetAhead', 'BaseAhead', 'Both')]
        [string]$direction = 'TargetAhead',

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before comparing.")]
        [switch]$fetch,

        [Parameter(Mandatory = $false, HelpMessage = "Include the full unified patch text.")]
        [switch]$includePatch
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ($fetch.IsPresent) {
            $null = Invoke-Git -path $resolvedPath -arguments @('fetch', '--all', '--prune')
        }

        $rangeInfo = Resolve-GitDiffRange -path $resolvedPath -baseBranch $baseBranch -targetBranch $targetBranch -direction $direction

        [string]$summary = Invoke-Git -path $resolvedPath -arguments @(
            'diff',
            '--stat',
            $rangeInfo.BaseRef,
            $rangeInfo.TargetRef
        )

        [string]$nameStatusRaw = Invoke-Git -path $resolvedPath -arguments @(
            'diff',
            '--name-status',
            $rangeInfo.BaseRef,
            $rangeInfo.TargetRef
        )

        [string]$numStatRaw = Invoke-Git -path $resolvedPath -arguments @(
            'diff',
            '--numstat',
            $rangeInfo.BaseRef,
            $rangeInfo.TargetRef
        )

        [string]$patch = ''

        if ($includePatch.IsPresent) {
            $patch = Invoke-Git -path $resolvedPath -arguments @(
                'diff',
                $rangeInfo.BaseRef,
                $rangeInfo.TargetRef
            )
        }

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

        $result = [ordered]@{
            Path             = $resolvedPath
            BaseBranch       = $rangeInfo.BaseBranch
            BaseRef          = $rangeInfo.BaseRef
            TargetBranch     = $rangeInfo.TargetBranch
            TargetRef        = $rangeInfo.TargetRef
            Direction        = $rangeInfo.Direction
            Range            = $rangeInfo.Range
            RangeDescription = $rangeInfo.RangeDescription
            Summary          = $summary
            Files            = $files.ToArray()
            FileCount        = $files.Count
            Patch            = $patch
            IncludePatch     = $includePatch.IsPresent
            GeneratedAt      = (Get-Date).ToString('o')
        }

        return [PSCustomObject]$result
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
