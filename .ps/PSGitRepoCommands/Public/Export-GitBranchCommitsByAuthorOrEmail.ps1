function Export-GitBranchCommitsByAuthorOrEmail () {
    <#
    .SYNOPSIS
        Writes commits on one branch, selected by author name or email, as JSON.

    .DESCRIPTION
        Calls Get-GitBranchCommitsByAuthorOrEmail and writes that result with
        ConvertTo-Json to OutputPath (default a timestamped file under the repo).
        The default input is -author. -email is the other choice. Matches are
        newest first and -limit defaults to 20. Returns the export object
        including JsonPath. UTF-8, no BOM.

    .NOTES
        1. Resolve the output path.
        2. Load the matching commits from the branch.
        3. Write UTF-8 JSON (no BOM) and return the object with JsonPath.

    .EXAMPLE
        PS> Export-GitBranchCommitsByAuthorOrEmail -branch main -author 'Jane'
        Writes a timestamped JSON file under the repo and returns .JsonPath.

        PS> Export-GitBranchCommitsByAuthorOrEmail -branch main -email jane@example.com -limit 5 -outputPath .\reports\commits.json -includePatch:$false
        Writes the latest 5 commits, without patch text, to the chosen JSON path.

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

        [Parameter(Mandatory = $false, HelpMessage = "Optional explicit JSON file path.")]
        [ValidateNotNullOrEmpty()]
        [string]$outputPath,

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
        Write-Host "--------------------------------- Begin: Export-GitBranchCommitsByAuthorOrEmail ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path
        $result = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByEmail') {
            $result = Get-GitBranchCommitsByAuthorOrEmail `
                -path $resolvedPath `
                -branch $branch `
                -email $email `
                -fetch:$fetch `
                -includePatch:$includePatch `
                -limit $limit
        }
        else {
            $result = Get-GitBranchCommitsByAuthorOrEmail `
                -path $resolvedPath `
                -branch $branch `
                -author $author `
                -fetch:$fetch `
                -includePatch:$includePatch `
                -limit $limit
        }

        [string]$jsonPath = $outputPath

        if ([string]::IsNullOrWhiteSpace($jsonPath)) {
            [string]$safeBranch = ($branch -replace '[\\/]', '-')
            [string]$selectorSource = if ($PSCmdlet.ParameterSetName -eq 'ByEmail') { $email } else { $author }
            [string]$safeSelector = Get-SafeName -name $selectorSource -maxLength 40
            [string]$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            [string]$fileName = 'branch-commits_{0}_{1}_{2}.json' -f $safeBranch, $safeSelector, $stamp
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
            Title        = 'Branch commits export'
            GeneratedAt  = (Get-Date).ToString('o')
            Path         = $result.Path
            Branch       = $result.Branch
            Ref          = $result.Ref
            Author       = $result.Author
            Email        = $result.Email
            CommitCount  = $result.CommitCount
            Limit        = $result.Limit
            IncludePatch = $result.IncludePatch
            Commits      = $result.Commits
            JsonPath     = $jsonPath
        }

        $exportObject = [PSCustomObject]$export
        [string]$jsonText = $exportObject | ConvertTo-Json -Depth 8
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($jsonPath, ($jsonText + "`n"), $utf8NoBom)

        return $exportObject
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Export-GitBranchCommitsByAuthorOrEmail ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
