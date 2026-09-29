function Write-TestSettings () {
    <#
    .SYNOPSIS
        Prints the BEGIN/END settings banner for a unit-test script.

    .DESCRIPTION
        Writes each name/value pair in Values, then the caller's bound
        parameters, between yellow BEGIN and END markers.

    .PARAMETER values
        Ordered settings to print. Keys are padded to 18 characters.

    .PARAMETER boundParameters
        The calling script's $PSBoundParameters.

    .NOTES
        1. Write BEGIN, each value, the bound parameters, then END.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Ordered settings to print.")]
        [System.Collections.Specialized.OrderedDictionary]$values,

        [Parameter(Mandatory = $false, HelpMessage = "Calling script bound parameters.")]
        [System.Collections.IDictionary]$boundParameters
    )

    Process {

        Write-Host 'BEGIN: Settings' -ForegroundColor Yellow

        foreach ($key in $values.Keys) {
            Write-Host ("{0,-18} = {1}" -f $key, $values[$key]) -ForegroundColor DarkGray
        }

        if ($null -ne $boundParameters) {
            $boundParameters | Out-String | Write-Host
        }

        Write-Host 'END: Settings' -ForegroundColor Yellow
    }
}
