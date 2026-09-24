function Get-SafeName () {
    <#
    .SYNOPSIS
        Sanitizes a string for use as a file or folder name.

    .DESCRIPTION
        Replaces invalid filename characters and runs of whitespace/underscores,
        trims edge punctuation, and truncates to MaxLength. Returns 'no-subject'
        when Name is blank or becomes blank after sanitizing.

    .PARAMETER name
        Raw display string (for example a commit subject).

    .PARAMETER maxLength
        Maximum length of the returned name. Defaults to 50.

    .NOTES
        1. Return 'no-subject' when Name is null or whitespace.
        2. Replace invalid filename chars and collapse whitespace/underscores.
        3. Trim and truncate to MaxLength; return 'no-subject' if still empty.

    .EXAMPLE
        PS> Get-SafeName -name 'Fix: path/to file?'
        Returns a filesystem-safe name such as Fix_path_to_file.

        PS> Get-SafeName -name $subject -maxLength 40
        Truncates the sanitized subject to at most 40 characters.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Raw string to sanitize for a file or folder name.")]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$name,

        [Parameter(Mandatory = $false, HelpMessage = "Maximum length of the returned name. Defaults to 50.")]
        [ValidateRange(1, 255)]
        [int]$maxLength = 50
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        if ([string]::IsNullOrWhiteSpace($name)) {
            return 'no-subject'
        }

        [string]$invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
        [string]$pattern = '[{0}]' -f [Regex]::Escape($invalid)
        [string]$safe = [Regex]::Replace($name, $pattern, '_')
        $safe = $safe -replace '\s+', '_'
        $safe = $safe -replace '_+', '_'
        $safe = $safe.Trim('_. ')

        if ($safe.Length -gt $maxLength) {
            $safe = $safe.Substring(0, $maxLength).Trim('_. ')
        }

        if ([string]::IsNullOrWhiteSpace($safe)) {
            return 'no-subject'
        }

        return $safe
    }
}
