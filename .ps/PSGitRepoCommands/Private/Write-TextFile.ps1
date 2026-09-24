function Write-TextFile () {
    <#
    .SYNOPSIS
        Writes text to a file as UTF-8 without a BOM.

    .DESCRIPTION
        Creates or overwrites Path with Content using UTF-8 encoding and no BOM.
        Null Content is treated as an empty string. Returns nothing.

    .PARAMETER path
        Destination file path (created or overwritten).

    .PARAMETER content
        Text to write. Null becomes an empty string.

    .NOTES
        1. Coerce null Content to empty string.
        2. Write UTF-8 without BOM via File.WriteAllText.

    .EXAMPLE
        PS> Write-TextFile -path '.\out.txt' -content "hello`n"
        Writes hello plus a newline to out.txt without a BOM.

        PS> Write-TextFile -path $jsonPath -content $jsonText
        Overwrites the JSON path with the given text.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Destination file path.")]
        [ValidateNotNullOrEmpty()]
        [string]$path,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Text to write. Null becomes empty.")]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$content
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if ($null -eq $content) {
            $content = ''
        }

        [System.Text.UTF8Encoding]$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    }
}
