function Convert-GitNameStatusLine () {
    <#
    .SYNOPSIS
        Parses a git name-status line into a PSCustomObject.

    .DESCRIPTION
        Handles status codes including renames (R###). Returns Status, Path,
        and OldPath (when renamed). Returns $null for blank lines.

    .REMARKS
        1. Skip blank lines.
        2. Split on tabs and map status/path fields.
        3. Return a PSCustomObject.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "One name-status line from git.")]
        [AllowEmptyString()]
        [string]$line
    )

    Process {

        if ([string]::IsNullOrWhiteSpace($line)) {
            return $null
        }

        [string[]]$tokens = $line -split "`t"
        [string]$status = $tokens[0]
        [string]$oldPath = ''
        [string]$path = ''

        if ($status.StartsWith('R') -or $status.StartsWith('C')) {
            if ($tokens.Count -ge 3) {
                $oldPath = $tokens[1]
                $path = $tokens[2]
            }
            else {
                $path = $tokens[-1]
            }
        }
        else {
            $path = $tokens[-1]
        }

        $result = [ordered]@{
            Status  = $status
            Path    = $path
            OldPath = $oldPath
        }

        return [PSCustomObject]$result
    }
}
