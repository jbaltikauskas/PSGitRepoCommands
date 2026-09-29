function Export-LibraryCommitPatchAndFullDiffFiles () {
    <#
    .SYNOPSIS
        Writes the library commit JSON, commit patch, diff JSON, and diff patch.

    .DESCRIPTION
        Exports the tip commit and the release-to-target full diff into
        ExportTempPath, then writes both patch files with a UTF-8 encoding that
        has no BOM. Throws unless each file lands in that folder, is named from
        the short hash, and the commit patch contains the tip hash.

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

    .NOTES
        1. Export the tip commit JSON and assert its path and hash.
        2. Write the commit patch and assert the hash is inside it.
        3. Export the full-diff JSON and write the diff patch.
        4. Assert the diff patch name and that the file is not empty.

    .EXAMPLE
        PS> Export-LibraryCommitPatchAndFullDiffFiles -libraryPath 'C:\repo\tests\Github\DbUp' -exportTempPath 'C:\repo\tests\20260923-2300' -releaseBranch 'release/1.0' -diffTargetBranch 'main' -branchTip $tipHash -byNumber $commit -tip $diff
        Writes the commit and diff JSON and patch files into the dated folder.

        PS> Export-LibraryCommitPatchAndFullDiffFiles -libraryPath $fullDiff.LibraryPath -exportTempPath $exportTempPath -releaseBranch $fullDiff.ReleaseBranch -diffTargetBranch $fullDiff.DiffTargetBranch -branchTip $selectedTip.BranchTip -byNumber $selectedTip.ByNumber -tip $fullDiff.Tip
        Same export using the objects returned by the earlier smoke sections.
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

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

        [string]$commitJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
        $commitExport = Export-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $commitJsonPath
        Write-Host 'Export-GitBranchCommitByID wrote JSON' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $commitExport.JsonPath) -label 'Export-GitBranchCommitByID wrote JSON'
        Write-Host 'Export-GitBranchCommitByID JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($commitExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID JSON is in the dated test folder' -details $commitExport.JsonPath
        Write-Host 'commit export JSON name starts with the commit short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitExport.JsonPath) -eq ('{0}-commit-export.json' -f $byNumber.Short)) -label 'commit export JSON name starts with the commit short hash' -details $commitExport.JsonPath
        Write-Host 'Export-GitBranchCommitByID commit is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($commitExport.Commit.Hash -eq $branchTip) -label 'Export-GitBranchCommitByID commit is the branch tip'

        $commitPatch = Get-GitBranchCommitByID -path $libraryPath -branch $diffTargetBranch -shortHash $byNumber.Short -fetch:$false
        [string]$commitPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-commit-export.patch' -f $byNumber.Short)
        [System.IO.File]::WriteAllText($commitPatchPath, ([string]$commitPatch.Patch + "`n"), $utf8NoBom)
        Write-Host 'commit patch file is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $commitPatchPath) -label 'commit patch file is in the dated test folder' -details $commitPatchPath
        Write-Host 'commit patch name starts with the commit short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($commitPatchPath) -eq ('{0}-commit-export.patch' -f $byNumber.Short)) -label 'commit patch name starts with the commit short hash' -details $commitPatchPath
        Write-Host 'commit patch contains the commit hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ((Get-Content -LiteralPath $commitPatchPath -Raw).Contains($byNumber.Hash)) -label 'commit patch contains the commit hash'

        [string]$jsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.json' -f $byNumber.Short)
        $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch $diffTargetBranch -direction TargetAhead -outputPath $jsonPath
        Write-Host 'Export-GitBranchFullDiff wrote JSON' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON'
        Write-Host 'Export-GitBranchFullDiff JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchFullDiff JSON is in the dated test folder' -details $export.JsonPath
        Write-Host 'diff export JSON name starts with the target tip short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($export.JsonPath) -eq ('{0}-diff-export.json' -f $byNumber.Short)) -label 'diff export JSON name starts with the target tip short hash' -details $export.JsonPath

        [string]$diffPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-diff-export.patch' -f $byNumber.Short)
        [System.IO.File]::WriteAllText($diffPatchPath, ([string]$tip.Patch + "`n"), $utf8NoBom)
        Write-Host 'diff patch file is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $diffPatchPath) -label 'diff patch file is in the dated test folder' -details $diffPatchPath
        Write-Host 'diff patch name starts with the target tip short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($diffPatchPath) -eq ('{0}-diff-export.patch' -f $byNumber.Short)) -label 'diff patch name starts with the target tip short hash' -details $diffPatchPath
        Write-Host 'diff patch file is not empty' -ForegroundColor Cyan
        Assert-TestTrue -condition ((Get-Item -LiteralPath $diffPatchPath).Length -gt 0) -label 'diff patch file is not empty'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
