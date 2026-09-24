function Export-DbUpMainTipCommitByID () {
    <#
    .SYNOPSIS
        Exports the DbUp main tip by short hash, number, and full hash.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON files.

    .PARAMETER branchTip
        Full hash of main.

    .PARAMETER byNumber
        Commit selected as number 1 on main.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$shortJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-export.json' -f $byNumber.Short)
        $shortExport = Export-GitBranchCommitByID -path $libraryPath -branch main -shortHash $byNumber.Short -fetch:$false -includePatch:$false -outputPath $shortJsonPath
        Assert-TestTrue -condition ($shortExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'short-hash export JSON is in the dated test folder' -details $shortExport.JsonPath
        Assert-TestTrue -condition ($shortExport.Commit.Hash -eq $branchTip) -label 'short-hash export commit is the branch tip'

        [string]$numberJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-by-number.json' -f $byNumber.Short)
        $numberExport = Export-GitBranchCommitByID -path $libraryPath -branch main -number 1 -fetch:$false -includePatch:$false -outputPath $numberJsonPath
        Assert-TestTrue -condition ($numberExport.Commit.Hash -eq $branchTip) -label 'number export commit is the branch tip'

        [string]$hashJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-commit-by-hash.json' -f $byNumber.Short)
        $hashExport = Export-GitBranchCommitByID -path $libraryPath -branch main -hash $byNumber.Hash -fetch:$false -includePatch:$false -outputPath $hashJsonPath
        Assert-TestTrue -condition ($hashExport.Commit.Hash -eq $branchTip) -label 'full-hash export commit is the branch tip'

        $exportJson = Get-Content -LiteralPath $shortExport.JsonPath -Raw | ConvertFrom-Json
        Assert-TestTrue -condition ($exportJson.Commit.Author -eq 'Robert Wagner' -and $exportJson.Commit.AuthorEmail -eq 'robert@wagner.id.au' -and $exportJson.Commit.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportJson.Commit.Committer -eq 'Robert Wagner') -label 'commit export JSON stores the real DbUp tip identity'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
