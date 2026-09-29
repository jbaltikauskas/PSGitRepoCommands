function Export-CommitsByAuthorRobertWagner () {
    <#
    .SYNOPSIS
        Writes the Robert Wagner author export JSON into the dated test folder.

    .DESCRIPTION
        Exports the author lookup into ExportFolder and throws unless the file
        is in that folder, the commit count matches AuthorCommitCount, and the
        JSON stores the real DbUp tip identity.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON file.

    .PARAMETER authorTip
        Newest commit from the author lookup. Its short hash names the file.

    .PARAMETER authorCommitCount
        Commit count from the author lookup.

    .NOTES
        1. Export the Robert Wagner author lookup into the dated folder.
        2. Assert the file path and that CommitCount matches the lookup.
        3. Assert the JSON stores the real DbUp tip identity.

    .EXAMPLE
        PS> Export-CommitsByAuthorRobertWagner -libraryPath 'C:\repo\tests\Github\DbUp' -exportFolder 'C:\repo\tests\20260923-2300' -authorTip $tip -authorCommitCount 20
        Writes the author JSON and asserts the tip identity.

        PS> Export-CommitsByAuthorRobertWagner -libraryPath $libraryPath -exportFolder $exportFolder -authorTip $authorTip -authorCommitCount $byAuthor.CommitCount
        Same export using the objects from the author section.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "tests/Github/DbUp repository path.")]
        [ValidateNotNullOrEmpty()]
        [string]$libraryPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the JSON file.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportFolder,

        [Parameter(Mandatory = $true, HelpMessage = "Newest commit from the author lookup.")]
        [ValidateNotNull()]
        [psobject]$authorTip,

        [Parameter(Mandatory = $true, HelpMessage = "Commit count from the author lookup.")]
        [int]$authorCommitCount
    )

    Begin {

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        [string]$authorJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-author-commits.json' -f $authorTip.Short)
        $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false -outputPath $authorJsonPath
        Write-Host 'Export-GitBranchCommitsByAuthorOrEmail wrote JSON' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $authorExport.JsonPath) -label 'Export-GitBranchCommitsByAuthorOrEmail wrote JSON' -details $authorExport.JsonPath
        Write-Host 'author export JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'author export JSON is in the dated test folder' -details $authorExport.JsonPath
        Write-Host 'author export CommitCount matches the author lookup' -ForegroundColor Cyan
        Assert-TestTrue -condition ($authorExport.CommitCount -eq $authorCommitCount) -label 'author export CommitCount matches the author lookup'
        $exportJson = Get-Content -LiteralPath $authorExport.JsonPath -Raw | ConvertFrom-Json
        $exportTip = @($exportJson.Commits)[0]
        Write-Host 'author export JSON stores the real DbUp tip identity' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'author export JSON stores the real DbUp tip identity'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
