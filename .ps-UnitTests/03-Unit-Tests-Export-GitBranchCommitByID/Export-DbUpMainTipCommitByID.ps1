function Export-DbUpMainTipCommitByID () {
    <#
    .SYNOPSIS
        Exports the DbUp main tip by short hash, number, and full hash.

    .DESCRIPTION
        Writes three JSON files into ExportFolder, one for each selector, and
        throws unless each exported commit is BranchTip and the short-hash JSON
        stores the real DbUp tip identity.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON files.

    .PARAMETER branchTip
        Full hash of main.

    .PARAMETER byNumber
        Commit selected as number 1 on main.

    .NOTES
        1. Export the tip by short hash and assert the path and hash.
        2. Export the tip by number and by full hash.
        3. Assert the short-hash JSON stores the real DbUp tip identity.

    .EXAMPLE
        PS> Export-DbUpMainTipCommitByID -libraryPath 'C:\repo\tests\Github\DbUp' -exportFolder 'C:\repo\tests\20260923-2300' -branchTip $hash -byNumber $commit
        Writes the three tip JSON files and asserts the tip identity.

        PS> Export-DbUpMainTipCommitByID -libraryPath $libraryPath -exportFolder $exportFolder -branchTip $branchTip -byNumber $byNumber
        Same export using the commit from the selection section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the JSON files.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportFolder,

        [Parameter(Mandatory = $true, HelpMessage = "Full hash of main.")]
        [ValidateNotNullOrEmpty()]
        [string]$branchTip,

        [Parameter(Mandatory = $true, HelpMessage = "Commit selected as number 1 on main.")]
        [ValidateNotNull()]
        [psobject]$byNumber
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$shortJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
        $shortExport = Export-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $shortJsonPath
        Write-Host 'short-hash export JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($shortExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'short-hash export JSON is in the dated test folder' -details $shortExport.JsonPath
        Write-Host 'short-hash export commit is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($shortExport.Commit.Hash -eq $branchTip) -label 'short-hash export commit is the branch tip'

        [string]$numberJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-by-number.json' -f $byNumber.Short)
        $numberExport = Export-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false -outputPath $numberJsonPath
        Write-Host 'number export commit is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($numberExport.Commit.Hash -eq $branchTip) -label 'number export commit is the branch tip'

        [string]$hashJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-by-hash.json' -f $byNumber.Short)
        $hashExport = Export-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false -outputPath $hashJsonPath
        Write-Host 'full-hash export commit is the branch tip' -ForegroundColor Cyan
        Assert-TestTrue -condition ($hashExport.Commit.Hash -eq $branchTip) -label 'full-hash export commit is the branch tip'

        $exportJson = Get-Content -LiteralPath $shortExport.JsonPath -Raw | ConvertFrom-Json
        Write-Host 'commit export JSON stores the real DbUp tip identity' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exportJson.Commit.Author -eq 'Robert Wagner' -and $exportJson.Commit.AuthorEmail -eq 'robert@wagner.id.au' -and $exportJson.Commit.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportJson.Commit.Committer -eq 'Robert Wagner') -label 'commit export JSON stores the real DbUp tip identity'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
