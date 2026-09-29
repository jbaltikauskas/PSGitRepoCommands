function Export-CommitsForEighteenthOfFebruaryByAuthor () {
    <#
    .SYNOPSIS
        Writes the 2026-02-18 Robert Wagner date-range JSON into the dated folder.

    .DESCRIPTION
        Exports the author-filtered date window into ExportFolder and throws
        unless the file is in that folder, the commit count matches
        AuthorCommitCount, and the JSON stores the real DbUp tip identity.

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

    .NOTES
        1. Export the author-filtered 2026-02-18 window into the dated folder.
        2. Assert the file path and that CommitCount matches the filter.
        3. Assert the JSON stores the real DbUp tip identity.

    .EXAMPLE
        PS> Export-CommitsForEighteenthOfFebruaryByAuthor -libraryPath 'C:\repo\tests\Github\DbUp' -exportFolder 'C:\repo\tests\20260923-2300' -rangeFrom $from -rangeTo $to -dateTip $tip -authorCommitCount 1
        Writes the date-range JSON and asserts the tip identity.

        PS> Export-CommitsForEighteenthOfFebruaryByAuthor -libraryPath $libraryPath -exportFolder $exportFolder -rangeFrom $onDate.RangeFrom -rangeTo $onDate.RangeTo -dateTip $onDate.DateTip -authorCommitCount $byAuthor.CommitCount
        Same export using the window from the earlier sections.
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

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$dateJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-date-commits.json' -f $dateTip.Short)
        $dateExport = Export-GitBranchCommitsByDateRange -path $libraryPath -branch main -from $rangeFrom -to $rangeTo -author 'Robert Wagner' -fetch:$false -includePatch:$false -outputPath $dateJsonPath
        Write-Host 'Export-GitBranchCommitsByDateRange wrote JSON' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $dateExport.JsonPath) -label 'Export-GitBranchCommitsByDateRange wrote JSON' -details $dateExport.JsonPath
        Write-Host 'date export JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'date export JSON is in the dated test folder' -details $dateExport.JsonPath
        Write-Host 'date export CommitCount matches the author filter' -ForegroundColor Cyan
        Assert-TestTrue -condition ($dateExport.CommitCount -eq $authorCommitCount) -label 'date export CommitCount matches the author filter'
        $exportJson = Get-Content -LiteralPath $dateExport.JsonPath -Raw | ConvertFrom-Json
        $exportTip = @($exportJson.Commits)[0]
        Write-Host 'date export JSON stores the real DbUp tip identity' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'date export JSON stores the real DbUp tip identity'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
