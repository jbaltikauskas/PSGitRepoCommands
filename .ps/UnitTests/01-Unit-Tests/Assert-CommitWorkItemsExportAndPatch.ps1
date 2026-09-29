function Assert-CommitWorkItemsExportAndPatch () {
    <#
    .SYNOPSIS
        Commits a work-item message and asserts the JSON export and patch file.

    .DESCRIPTION
        Creates an empty commit whose message contains #id and AB#id keys, then
        asserts unique WorkItems, the dated-folder JSON export, and a patch file
        that contains the commit hash. Throws when git commit exits non-zero.

    .PARAMETER repoPath
        Nested Git root created for this run.

    .PARAMETER exportTempPath
        Dated folder that receives the JSON and patch files.

    .NOTES
        1. Commit an empty work-item message and throw when git fails.
        2. Assert unique WorkItems on commit number 1.
        3. Export JSON into the dated folder and assert the WorkItems array.
        4. Write the patch beside the JSON and assert the commit hash is present.

    .EXAMPLE
        PS> Assert-CommitWorkItemsExportAndPatch -repoPath 'C:\repo\tests\20260923-2300' -exportTempPath 'C:\repo\tests\20260923-2300'
        Commits the work-item message and checks the JSON and patch files.

        PS> Assert-CommitWorkItemsExportAndPatch -repoPath $resolvedRepoPath -exportTempPath $exportTempPath
        Same checks using the paths from the smoke runner.
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

        Write-Host ""
        Write-Host ("--------------------------------- BEGIN: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }

    Process {

        & git -C $repoPath -c user.email=test@example.com -c user.name=test commit --allow-empty -m 'Fix login button alignment #12345 and #56985 #12345' -m 'Fix login validation bug AB#12345 and AB#77 and AB#12345' | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "git commit for work items failed with exit code $LASTEXITCODE"
        }

        $workCommit = Get-GitBranchCommitByID -path $repoPath -branch main -number 1 -fetch:$false -includePatch:$false
        [string]$workItemList = (@($workCommit.WorkItems) -join ',')
        Write-Host 'WorkItems keeps unique original keys #id and AB#id' -ForegroundColor Cyan
        Assert-TestTrue -condition ($workItemList -eq '#12345,#56985,AB#12345,AB#77') -label 'WorkItems keeps unique original keys #id and AB#id' -details $workItemList

        [string]$workJsonPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.json' -f $workCommit.Short)
        $workExport = Export-GitBranchCommitByID -path $repoPath -branch main -shortHash $workCommit.Short -fetch:$false -includePatch:$false -outputPath $workJsonPath
        Write-Host 'Export-GitBranchCommitByID work-item JSON is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition ($workExport.JsonPath.StartsWith($exportTempPath, [System.StringComparison]::OrdinalIgnoreCase)) -label 'Export-GitBranchCommitByID work-item JSON is in the dated test folder' -details $workExport.JsonPath
        Write-Host 'work-item JSON name starts with the commit short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workExport.JsonPath) -eq ('{0}-work-items.json' -f $workCommit.Short)) -label 'work-item JSON name starts with the commit short hash' -details $workExport.JsonPath
        $workJson = Get-Content -LiteralPath $workExport.JsonPath -Raw | ConvertFrom-Json
        [string]$exportedWorkItems = (@($workJson.Commit.WorkItems) -join ',')
        Write-Host 'Export JSON includes the WorkItems array' -ForegroundColor Cyan
        Assert-TestTrue -condition ($exportedWorkItems -eq $workItemList) -label 'Export JSON includes the WorkItems array' -details $exportedWorkItems

        $workPatchCommit = Get-GitBranchCommitByID -path $repoPath -branch main -shortHash $workCommit.Short -fetch:$false
        [string]$workPatchPath = Join-Path -Path $exportTempPath -ChildPath ('{0}-work-items.patch' -f $workCommit.Short)
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($workPatchPath, ([string]$workPatchCommit.Patch + "`n"), $utf8NoBom)
        Write-Host 'work-item patch file is in the dated test folder' -ForegroundColor Cyan
        Assert-TestTrue -condition (Test-Path -LiteralPath $workPatchPath) -label 'work-item patch file is in the dated test folder' -details $workPatchPath
        Write-Host 'work-item patch name starts with the commit short hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ([System.IO.Path]::GetFileName($workPatchPath) -eq ('{0}-work-items.patch' -f $workCommit.Short)) -label 'work-item patch name starts with the commit short hash' -details $workPatchPath
        Write-Host 'work-item patch contains the commit hash' -ForegroundColor Cyan
        Assert-TestTrue -condition ((Get-Content -LiteralPath $workPatchPath -Raw).Contains($workCommit.Hash)) -label 'work-item patch contains the commit hash'
    }

    End {

        Write-Host ""
        Write-Host ("--------------------------------- END: {0} ---------------------------------------------" -f $MyInvocation.MyCommand.Name) -ForegroundColor Yellow
        Write-Host ""
    }
}
