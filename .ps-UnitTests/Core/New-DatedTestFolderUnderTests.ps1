function New-DatedTestFolderUnderTests () {
    <#
    .SYNOPSIS
        Creates the dated tests folder for one smoke-test run.

    .DESCRIPTION
        Calls New-TestRunFolder and prints the resolved path.

    .PARAMETER parentPath
        Parent folder, typically tests/.

    .NOTES
        1. Create the dated folder.
        2. Print and return its full path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Parent folder, typically tests/.")]
        [ValidateNotNullOrEmpty()]
        [string]$parentPath
    )

    Process {

        [string]$runFolder = New-TestRunFolder -parentPath $parentPath
        Write-Host ("datedTestFolder = {0}" -f $runFolder) -ForegroundColor DarkGray
        return $runFolder
    }
}
