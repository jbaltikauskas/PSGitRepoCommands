function Export-GitBranchCommitByID () {
    <#
    .SYNOPSIS
        Writes one branch commit, selected by short hash, number, or full hash, as JSON.

    .DESCRIPTION
        Calls Get-GitBranchCommitByID and writes that PSCustomObject
        with ConvertTo-Json to OutputPath (default a timestamped file under the
        repo). The default input is -shortHash. -number and -hash (full hash)
        are the other choices. Returns the export object including JsonPath.
        UTF-8, no BOM.

    .NOTES
        1. Resolve the output path.
        2. Load the one commit from the branch.
        3. Write UTF-8 JSON (no BOM) and return the object with JsonPath.

    .EXAMPLE
        PS> Export-GitBranchCommitByID -branch main -shortHash a1b2c3d
        Writes a timestamped JSON file under the repo and returns .JsonPath.

        PS> Export-GitBranchCommitByID -branch main -number 1 -outputPath '.\reports\commit.json'
        Writes the latest commit on main to the chosen JSON path.

        PS> Export-GitBranchCommitByID -branch feature/foo -hash 0123456789abcdef0123456789abcdef01234567 -includePatch:$false
        Writes that full-hash commit, without patch text.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByShortHash')]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Branch that contains the commit (e.g. main).")]
        [ValidateNotNullOrEmpty()]
        [string]$branch,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByShortHash', HelpMessage = "Short hash or unique hash prefix. This is the default commit input.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[0-9a-fA-F]{4,40}$')]
        [string]$shortHash,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNumber', HelpMessage = "1-based position from the branch tip. 1 is the latest commit.")]
        [ValidateRange(1, 2147483647)]
        [int]$number,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByHash', HelpMessage = "Full 40-character commit hash.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string]$hash,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Optional explicit JSON file path.")]
        [ValidateNotNullOrEmpty()]
        [string]$outputPath,

        [Parameter(Mandatory = $false, HelpMessage = "Run git fetch --all --prune before resolving the branch. Turn off with -fetch:`$false.")]
        [bool]$fetch = $true,

        [Parameter(Mandatory = $false, HelpMessage = "Include the commit's full patch text. Turn off with -includePatch:`$false.")]
        [bool]$includePatch = $true
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Export-GitBranchCommitByID ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        $commit = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByNumber') {
            $commit = Get-GitBranchCommitByID `
                -path $resolvedPath `
                -branch $branch `
                -number $number `
                -fetch:$fetch `
                -includePatch:$includePatch
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByHash') {
            $commit = Get-GitBranchCommitByID `
                -path $resolvedPath `
                -branch $branch `
                -hash $hash `
                -fetch:$fetch `
                -includePatch:$includePatch
        }
        else {
            $commit = Get-GitBranchCommitByID `
                -path $resolvedPath `
                -branch $branch `
                -shortHash $shortHash `
                -fetch:$fetch `
                -includePatch:$includePatch
        }

        [string]$jsonPath = $outputPath

        if ([string]::IsNullOrWhiteSpace($jsonPath)) {
            [string]$safeBranch = ($branch -replace '[\\/]', '-')
            [string]$selector = switch ($PSCmdlet.ParameterSetName) {
                'ByNumber' { "n$number" }
                'ByHash' { $hash }
                default { $shortHash }
            }
            [string]$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            [string]$fileName = 'branch-commit_{0}_{1}_{2}.json' -f $safeBranch, $selector, $stamp
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
            Title       = 'Branch commit export'
            GeneratedAt = (Get-Date).ToString('o')
            Commit      = $commit
            JsonPath    = $jsonPath
        }

        $exportObject = [PSCustomObject]$export
        [string]$jsonText = $exportObject | ConvertTo-Json -Depth 8
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($jsonPath, ($jsonText + "`n"), $utf8NoBom)

        return $exportObject
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Export-GitBranchCommitByID ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
