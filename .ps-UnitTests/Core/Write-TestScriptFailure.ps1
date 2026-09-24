function Write-TestScriptFailure () {
    <#
    .SYNOPSIS
        Prints the unit-test catch banner and optional leftover path.

    .DESCRIPTION
        Writes the exception type and message in red. When LeftPath is set,
        writes it in yellow. Pauses for Enter when Pause is true.

    .PARAMETER errorRecord
        The error record from the calling catch block.

    .PARAMETER leftPath
        Folder left behind after a failure. Omitted when empty.

    .PARAMETER leftLabel
        Label printed before LeftPath.

    .PARAMETER pause
        When true, waits for Enter before the caller exits.

    .NOTES
        1. Write the exception type and message.
        2. Write LeftPath when it is set.
        3. Read-Host when Pause is true.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Error record from the calling catch block.")]
        [System.Management.Automation.ErrorRecord]$errorRecord,

        [Parameter(Mandatory = $false, HelpMessage = "Folder left behind after a failure.")]
        [string]$leftPath,

        [Parameter(Mandatory = $false, HelpMessage = "Label printed before LeftPath.")]
        [string]$leftLabel = 'Nested test folder left at',

        [Parameter(Mandatory = $false, HelpMessage = "Wait for Enter before the caller exits.")]
        [bool]$pause = $true
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Write-Host ''
        Write-Host 'Script failed to execute.' -ForegroundColor Red
        Write-Host ("Exception: {0}" -f $errorRecord.Exception.GetType().FullName) -ForegroundColor Red
        Write-Host ("Message:   {0}" -f $errorRecord.Exception.Message) -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($leftPath)) {
            Write-Host ("{0}: {1}" -f $leftLabel, $leftPath) -ForegroundColor Yellow
        }

        if ($pause) {
            Read-Host 'Press Enter to close'
        }
    }
}
