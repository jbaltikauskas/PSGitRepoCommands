function Export-LibraryCommitPatchAndFullDiffFiles () {
    <#
    .SYNOPSIS
        Writes the library commit JSON, commit patch, diff JSON, and diff patch.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportTempPath
        Dated folder that receives the export files.

    .PARAMETER releaseBranch
        Base branch for the full diff.

    .PARAMETER diffTargetBranch
        Target branch for the full diff.

    .PARAMETER branchTip
        Full hash of the target branch tip.

    .PARAMETER byNumber
        Commit selected as number 1 on the target branch.

    .PARAMETER tip
        Full diff object that supplies the patch text.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the export files.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportTempPath,

        [Parameter(Mandatory = $true, HelpMessage = "Base branch for the full diff.")]
        [ValidateNotNullOrEmpty()]
        [string]$releaseBranch,

        [Parameter(Mandatory = $true, HelpMessage = "Target branch for the full diff.")]
        [ValidateNotNullOrEmpty()]
        [string]$diffTargetBranch,

        [Parameter(Mandatory = $true, HelpMessage = "Full hash of the target branch tip.")]
        [ValidateNotNullOrEmpty()]
        [string]$branchTip,

        [Parameter(Mandatory = $true, HelpMessage = "Commit selected as number 1 on the target branch.")]
        [ValidateNotNull()]
        [psobject]$byNumber,

        [Parameter(Mandatory = $true, HelpMessage = "Full diff object that supplies the patch text.")]
        [ValidateNotNull()]
        [psobject]$tip
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

        [string]$commitJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
        $commitExport = Export-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $commitJsonPath
        Assert-TestTrue -condition (Test-Path -LiteralPath $commitExport.JsonPath) -label 'Export-GitBranchCommitByID wrote JSON'
        Assert-TestTrue -condition ($commitExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID JSON is in the dated test folder' -details $commitExport.JsonPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitExport.JsonPath) -eq ('{0}-commit-export.json' -f $byNumber.Short)) -label 'commit export JSON name starts with the commit short hash' -details $commitExport.JsonPath
        Assert-TestTrue -condition ($commitExport.Commit.Hash -eq $branchTip) -label 'Export-GitBranchCommitByID commit is the branch tip'

        $commitPatch = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false
        [string]$commitPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.patch' -f $byNumber.Short)
        [System.IO.File]::WriteAllText($commitPatchPath, ([string]$commitPatch.Patch + "`n"), $utf8NoBom)
        Assert-TestTrue -condition (Test-Path -LiteralPath $commitPatchPath) -label 'commit patch file is in the dated test folder' -details $commitPatchPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitPatchPath) -eq ('{0}-commit-export.patch' -f $byNumber.Short)) -label 'commit patch name starts with the commit short hash' -details $commitPatchPath
        Assert-TestTrue -condition ((Get-Content -LiteralPath $commitPatchPath -Raw).Contains($byNumber.Hash)) -label 'commit patch contains the commit hash'

        [string]$jsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.json' -f $byNumber.Short)
        $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch $diffTargetBranch -direction TargetAhead -outputPath $jsonPath
        Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON'
        Assert-TestTrue -condition ($export.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchFullDiff JSON is in the dated test folder' -details $export.JsonPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($export.JsonPath) -eq ('{0}-diff-export.json' -f $byNumber.Short)) -label 'diff export JSON name starts with the target tip short hash' -details $export.JsonPath

        [string]$diffPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.patch' -f $byNumber.Short)
        [System.IO.File]::WriteAllText($diffPatchPath, ([string]$tip.Patch + "`n"), $utf8NoBom)
        Assert-TestTrue -condition (Test-Path -LiteralPath $diffPatchPath) -label 'diff patch file is in the dated test folder' -details $diffPatchPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($diffPatchPath) -eq ('{0}-diff-export.patch' -f $byNumber.Short)) -label 'diff patch name starts with the target tip short hash' -details $diffPatchPath
        Assert-TestTrue -condition ((Get-Item -LiteralPath $diffPatchPath).Length -gt 0) -label 'diff patch file is not empty'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
