function Export-CommitsForEighteenthOfFebruaryByAuthor () {
    <#
    .SYNOPSIS
        Writes the 2026-02-18 Robert Wagner date-range JSON into the dated folder.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON file.

    .PARAMETER rangeFrom
        Inclusive start of the author-date window.

    .PARAMETER rangeTo
        Inclusive end of the author-date window.

    .PARAMETER dateTip
        Newest commit from the unfiltered date window.

    .PARAMETER authorCommitCount
        Commit count from the author-filtered date lookup.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the JSON file.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportFolder,

        [Parameter(Mandatory = $true, HelpMessage = "Inclusive start of the author-date window.")]
        [datetime]$rangeFrom,

        [Parameter(Mandatory = $true, HelpMessage = "Inclusive end of the author-date window.")]
        [datetime]$rangeTo,

        [Parameter(Mandatory = $true, HelpMessage = "Newest commit from the unfiltered date window.")]
        [ValidateNotNull()]
        [psobject]$dateTip,

        [Parameter(Mandatory = $true, HelpMessage = "Commit count from the author-filtered date lookup.")]
        [int]$authorCommitCount
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$dateJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-date-commits.json' -f $dateTip.Short)
        $dateExport = Export-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -author 'Robert Wagner' -fetch:$false -includePatch:$false -outputPath $dateJsonPath
        Assert-TestTrue -condition (Test-Path -LiteralPath $dateExport.JsonPath) -label 'Export-GitBranchCommitsByDateRange wrote JSON' -details $dateExport.JsonPath
        Assert-TestTrue -condition ($dateExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'date export JSON is in the dated test folder' -details $dateExport.JsonPath
        Assert-TestTrue -condition ($dateExport.CommitCount -eq $authorCommitCount) -label 'date export CommitCount matches the author filter'
        $exportJson = Get-Content -LiteralPath $dateExport.JsonPath -Raw | ConvertFrom-Json
        $exportTip = @($exportJson.Commits)[0]
        Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'date export JSON stores the real DbUp tip identity'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
