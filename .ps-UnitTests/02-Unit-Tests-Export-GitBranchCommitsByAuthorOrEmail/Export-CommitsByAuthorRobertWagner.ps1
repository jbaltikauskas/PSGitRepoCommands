function Export-CommitsByAuthorRobertWagner () {
    <#
    .SYNOPSIS
        Writes the Robert Wagner author export JSON into the dated test folder.

    .PARAMETER libraryPath
        tests/Github/DbUp repository path.

    .PARAMETER exportFolder
        Dated folder that receives the JSON file.

    .PARAMETER authorTip
        Newest commit from the author lookup. Its short hash names the file.

    .PARAMETER authorCommitCount
        Commit count from the author lookup.
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
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$authorJsonPath = Join-Path -Path $exportFolder -ChildPath ('{0}-author-commits.json' -f $authorTip.Short)
        $authorExport = Export-GitBranchCommitsByAuthorOrEmail -path $libraryPath -branch main -author 'Robert Wagner' -fetch:$false -outputPath $authorJsonPath
        Assert-TestTrue -condition (Test-Path -LiteralPath $authorExport.JsonPath) -label 'Export-GitBranchCommitsByAuthorOrEmail wrote JSON' -details $authorExport.JsonPath
        Assert-TestTrue -condition ($authorExport.JsonPath.StartsWith($exportFolder, [System.StringComparison]::OrdinalIgnoreCase)) -label 'author export JSON is in the dated test folder' -details $authorExport.JsonPath
        Assert-TestTrue -condition ($authorExport.CommitCount -eq $authorCommitCount) -label 'author export CommitCount matches the author lookup'
        $exportJson = Get-Content -LiteralPath $authorExport.JsonPath -Raw | ConvertFrom-Json
        $exportTip = @($exportJson.Commits)[0]
        Assert-TestTrue -condition ($exportTip.Author -eq 'Robert Wagner' -and $exportTip.AuthorEmail -eq 'robert@wagner.id.au' -and $exportTip.AuthorDate -eq '2026-02-18T13:55:32+10:00' -and $exportTip.Committer -eq 'Robert Wagner') -label 'author export JSON stores the real DbUp tip identity'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
