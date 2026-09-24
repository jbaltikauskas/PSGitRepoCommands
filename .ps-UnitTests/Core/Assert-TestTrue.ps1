function Assert-TestTrue () {
    <#
    .SYNOPSIS
        Throws when a test condition is false.

    .DESCRIPTION
        Evaluates Condition; on failure throws with Label (and optional Details)
        so the top-level catch can report which assertion failed. On success
        writes a green PASS line and optional Details in DarkGray.

    .PARAMETER condition
        Boolean result that must be true.

    .PARAMETER label
        Short name of the assertion for error messages.

    .PARAMETER details
        Optional extra context shown on pass and included in the throw message.

    .NOTES
        1. Throw when Condition is false (include Details when provided).
        2. Write a green pass line when Condition is true; echo Details if set.

    .EXAMPLE
        PS> Assert-TestTrue -condition $true -label 'sanity'
        Writes a green pass line.

        PS> Assert-TestTrue -condition $true -label 'has b.txt' -details 'Files=a.txt, b.txt'
        Writes PASS plus the details line.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Value that must be true.")]
        [bool]$condition,

        [Parameter(Mandatory = $true, HelpMessage = "Assertion label.")]
        [ValidateNotNullOrEmpty()]
        [string]$label,

        [Parameter(Mandatory = $false, HelpMessage = "Optional context for pass/fail output.")]
        [string]$details
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if (-not $condition) {
            if ([string]::IsNullOrWhiteSpace($details)) {
                throw "Assertion failed: $label"
            }

            throw "Assertion failed: $label | $details"
        }

        Write-Host "PASS: $label" -ForegroundColor Green

        if (-not [string]::IsNullOrWhiteSpace($details)) {
            Write-Host ("  {0}" -f $details) -ForegroundColor DarkGray
        }
    }
}
