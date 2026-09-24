function Export-LastReleaseBranchVersusMainFullDiff () {
    <#
    .SYNOPSIS
        Writes the newest release-versus-main full diff JSON into the dated folder.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON file.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$releaseBranch = Get-LastReleaseBranch -path $libraryPath
        [string]$tipShort = (git -C $libraryPath rev-parse --short main).Trim()
        Write-Host ("lastReleaseBranch = {0}" -f $releaseBranch) -ForegroundColor DarkGray
        [string]$jsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-diff-export.json' -f $tipShort)
        $export = Export-GitBranchFullDiff -path $libraryPath -baseBranch $releaseBranch -targetBranch main -direction TargetAhead -outputPath $jsonPath
        Assert-TestTrue -condition (Test-Path -LiteralPath $export.JsonPath) -label 'Export-GitBranchFullDiff wrote JSON' -details $export.JsonPath
        Assert-TestTrue -condition ($export.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'diff export JSON is in the dated test folder' -details $export.JsonPath
        Assert-TestTrue -condition ($export.BaseBranch -eq $releaseBranch) -label 'diff export base is the last release branch' -details $releaseBranch
        Assert-TestTrue -condition ($export.TargetBranch -eq 'main') -label 'diff export target is main'
        Assert-TestTrue -condition ($export.TipDiff.FileCount -ge 1) -label 'diff export tip has at least one changed file' -details $export.TipDiff.FileCount
        Assert-TestTrue -condition ($export.CommitDiff.CommitCount -ge 1) -label 'diff export has commits since the last release' -details $export.CommitDiff.CommitCount
        $exportJson = Get-Content -LiteralPath $export.JsonPath -Raw | ConvertFrom-Json
        Assert-TestTrue -condition ($exportJson.BaseBranch -eq $releaseBranch -and $exportJson.TargetBranch -eq 'main' -and $exportJson.TipDiff.FileCount -ge 1) -label 'diff export JSON stores the release-versus-main result'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
