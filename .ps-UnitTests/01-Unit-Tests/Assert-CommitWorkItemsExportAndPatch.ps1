function Assert-CommitWorkItemsExportAndPatch () {
    <#
    .SYNOPSIS
        Commits a work-item message and asserts the JSON export and patch file.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .PARAMETER exportTempPath
        Dated folder that receives the JSON and patch files.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Nested Git root created for this run.")]
        [ValidateNotNullOrEmpty()]
        [string]$repoPath,

        [Parameter(Mandatory = $true, HelpMessage = "Dated folder that receives the JSON and patch files.")]
        [ValidateNotNullOrEmpty()]
        [string]$exportTempPath
    )

    Begin {
        Write-Host ''
        Write-Host ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        & git -C $repoPath -c user.email=test@example.com -c user.name=test commit --allow-empty -m 'Fix login button alignment #12345 and #56985 #12345' -m 'Fix login validation bug AB#12345 and AB#77 and AB#12345' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "git commit for work items failed with exit code $LASTEXITCODE"
        }

        $workCommit = Get-GitBranchCommitByID -path $repoPath -branch main -number 1 -fetch:$false -includePatch:$false
        [string]$workItemList = (@($workCommit.WorkItems) -join ',')
        Assert-TestTrue -condition ($workItemList -eq '#12345,#56985,AB#12345,AB#77') -label 'WorkItems keeps unique original keys #id and AB#id' -details $workItemList

        [string]$workJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.json' -f $workCommit.Short)
        $workExport = Export-GitBranchCommitByID -path $repoPath -branch main -shortHash $workCommit.Short -fetch:$false -includePatch:$false -outputPath $workJsonPath
        Assert-TestTrue -condition ($workExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID work-item JSON is in the dated test folder' -details $workExport.JsonPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workExport.JsonPath) -eq ('{0}-work-items.json' -f $workCommit.Short)) -label 'work-item JSON name starts with the commit short hash' -details $workExport.JsonPath
        $workJson = Get-Content -LiteralPath $workExport.JsonPath -Raw | ConvertFrom-Json
        [string]$exportedWorkItems = (@($workJson.Commit.WorkItems) -join ',')
        Assert-TestTrue -condition ($exportedWorkItems -eq $workItemList) -label 'Export JSON includes the WorkItems array' -details $exportedWorkItems

        $workPatchCommit = Get-GitBranchCommitByID -path $repoPath -branch main -shortHash $workCommit.Short -fetch:$false
        [string]$workPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.patch' -f $workCommit.Short)
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($workPatchPath, ([string]$workPatchCommit.Patch + "`n"), $utf8NoBom)
        Assert-TestTrue -condition (Test-Path -LiteralPath $workPatchPath) -label 'work-item patch file is in the dated test folder' -details $workPatchPath
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workPatchPath) -eq ('{0}-work-items.patch' -f $workCommit.Short)) -label 'work-item patch name starts with the commit short hash' -details $workPatchPath
        Assert-TestTrue -condition ((Get-Content -LiteralPath $workPatchPath -Raw).Contains($workCommit.Hash)) -label 'work-item patch contains the commit hash'
    }

    End {
        Write-Host ("END: {0}" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
    }
}
