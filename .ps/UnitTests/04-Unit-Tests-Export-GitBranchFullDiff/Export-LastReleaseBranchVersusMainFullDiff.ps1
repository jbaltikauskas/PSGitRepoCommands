function Export-LastReleaseBranchVersusMainFullDiff () {
    <#
    .SYNOPSIS
        Writes the newest release-versus-main full diff JSON into the dated folder.

    .DESCRIPTION
        Resolves the newest release branch, exports the TargetAhead diff to main
        into ExportFolder, and throws unless the file, branches, file count, and
        commit count match that range.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON file.

    .NOTES
        1. Resolve the newest release branch and the main short hash.
        2. Export the full diff into the dated folder.
        3. Assert the file path, branches, file count, and commit count.
        4. Assert the JSON stores the same release-versus-main result.

    .EXAMPLE
        PS> Export-LastReleaseBranchVersusMainFullDiff -libraryPath 'C:\repo\tests\Github\DbUp' -exportFolder 'C:\repo\tests\20260923-2300'
        Writes the release-versus-main diff JSON and asserts the range.

        PS> Export-LastReleaseBranchVersusMainFullDiff -libraryPath $libraryPath -exportFolder $exportFolder
        Same export using the paths from the runner.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the JSON file.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportFolder
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$releaseBranch = Get-LastReleaseBranch -path $libraryPath
        [string]$tipShort = (git -C $libraryPath rev-parse --short main).Trim()
        Write-Host ("lastReleaseBranch = {0}" -f $releaseBranch) -ForegroundColor DarkGray
        [string]$jsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-diff-export.json' -f $tipShort)
        $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch main -direction TargetAhead -outputPath $jsonPath
        Write-Host 'Export-GitBranchFullDiff wrote JSON' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON' -details $export.JsonPath
        Write-Host 'diff export JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'diff export JSON is in the dated test folder' -details $export.JsonPath
        Write-Host 'diff export base is the last release branch' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.BaseBranch -eq $releaseBranch) -label 'diff export base is the last release branch' -details $releaseBranch
        Write-Host 'diff export target is main' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.TargetBranch -eq 'main') -label 'diff export target is main'
        Write-Host 'diff export tip has at least one changed file' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.TipDiff.FileCount -ge 1) -label 'diff export tip has at least one changed file' -details $export.TipDiff.FileCount
        Write-Host 'diff export has commits since the last release' -ForegroundColor Cyan
        Assert-TestTrue -condition ($export.CommitDiff.CommitCount -ge 1) -label 'diff export has commits since the last release' -details $export.CommitDiff.CommitCount
        $exportJson = Get-Content -LiteralPath $export.JsonPath -Raw | ConvertFrom-Json
        Write-Host 'diff export JSON stores the release-versus-main result' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exportJson.BaseBranch -eq $releaseBranch -and $exportJson.TargetBranch -eq 'main' -and $exportJson.TipDiff.FileCount -ge 1) -label 'diff export JSON stores the release-versus-main result'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
