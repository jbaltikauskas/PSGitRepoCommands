function Export-GitBranchFullDiff () {
    <#
    .SYNOPSIS
        Builds tip-to-tip and per-commit branch diffs and writes them as JSON.

    .DESCRIPTION
        Combines Get-GitBranchFullDiff and Get-GitBranchCommitDiff into one
        PSCustomObject (ready for reporting), writes it with ConvertTo-Json to
        OutputPath (default under the repo), and returns the object including
        JsonPath. Diff.ps1 folder/patch export is intentionally not replicated;
        JSON is the durable artifact.

    .NOTES
        1. Resolve output path (default timestamped file under the repo).
        2. Collect tip-to-tip diff and per-commit details as PSCustomObjects.
        3. Merge into an export root object.
        4. Write UTF-8 JSON (no BOM) and return the object with JsonPath.

    .EXAMPLE
        PS> Export-GitBranchFullDiff -baseBranch main -targetBranch feature/foo
        Writes a timestamped JSON file under the repo and returns .JsonPath.

        PS> Export-GitBranchFullDiff -baseBranch main -targetBranch qa -direction Both -outputPath '.\reports\diff.json' -includePatch
        Exports tip + commits (with patches) to a chosen JSON path.

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
        [string]$direction = 'TargetAhead',

        [Parameter(Mandatory = $false, HelpMessage = "Optional explicit JSON file path.")]
        [ValidateNotNullOrEmpty()]
        [string]$outputPath,

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before comparing.")]
        [switch]$fetch,

        [Parameter(Mandatory = $false, HelpMessage = "Include tip-to-tip and per-commit patch text in JSON.")]
        [switch]$includePatch
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Export-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        $tipDiff = Get-GitBranchFullDiff `
            -path $resolvedPath `
            -baseBranch $baseBranch `
            -targetBranch $targetBranch `
            -direction $direction `
            -fetch:$fetch.IsPresent `
            -includePatch:$includePatch.IsPresent

        $commitDiff = Get-GitBranchCommitDiff `
            -path $resolvedPath `
            -baseBranch $baseBranch `
            -targetBranch $targetBranch `
            -direction $direction `
            -includePatch:$includePatch.IsPresent

        [string]$safeBase = ($baseBranch -replace '[\\/]', '-')
        [string]$safeTarget = ($targetBranch -replace '[\\/]', '-')
        [string]$jsonPath = $outputPath

        if ([string]::IsNullOrWhiteSpace($jsonPath)) {
            [string]$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            [string]$fileName = 'branch-diff_{0}_vs_{1}_{2}.json' -f $safeBase, $safeTarget, $stamp
            $jsonPath = Join-Path -Path $resolvedPath -ChildPath $fileName
        }
        else {
            $jsonPath = [System.IO.Path]::GetFullPath($jsonPath)
        }

        [string]$jsonDirectory = [System.IO.Path]::GetDirectoryName($jsonPath)

        if (-not (Test-Path -LiteralPath $jsonDirectory -PathType Container)) {
            $null = New-Item -ItemType Directory -Force -Path $jsonDirectory
        }

        $export = [ordered]@{
            Title            = 'Branch diff export'
            Path             = $resolvedPath
            BaseBranch       = $tipDiff.BaseBranch
            BaseRef          = $tipDiff.BaseRef
            TargetBranch     = $tipDiff.TargetBranch
            TargetRef        = $tipDiff.TargetRef
            Direction        = $tipDiff.Direction
            Range            = $tipDiff.Range
            RangeDescription = $tipDiff.RangeDescription
            GeneratedAt      = (Get-Date).ToString('o')
            IncludePatch     = $includePatch.IsPresent
            TipDiff          = $tipDiff
            CommitDiff       = $commitDiff
            JsonPath         = $jsonPath
        }

        $exportObject = [PSCustomObject]$export
        [string]$jsonText = $exportObject | ConvertTo-Json -Depth 12
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($jsonPath, ($jsonText + "`n"), $utf8NoBom)

        return $exportObject
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Export-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
