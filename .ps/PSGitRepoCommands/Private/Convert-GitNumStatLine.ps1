function Convert-GitNumStatLine () {
    <#
    .SYNOPSIS
        Parses a git numstat line into a PSCustomObject.

    .DESCRIPTION
        Returns Additions, Deletions, and Path. Binary files (dashes) use -1
        for counts. Returns $null for blank lines.

    .REMARKS
        1. Skip blank lines.
        2. Split on tabs into additions, deletions, path.
        3. Return a PSCustomObject.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "One numstat line from git.")]
        [AllowEmptyString()]
        [string]$line
    )

    Process {

        if ([string]::IsNullOrWhiteSpace($line)) {
            return $null
        }

        [string[]]$tokens = $line -split "`t"
        [int]$additions = -1
        [int]$deletions = -1
        [string]$path = ''

        if ($tokens.Count -ge 3) {
            if ($tokens[0] -ne '-') {
                $additions = [int]$tokens[0]
            }

            if ($tokens[1] -ne '-') {
                $deletions = [int]$tokens[1]
            }

            $path = $tokens[2]
        }
        else {
            $path = $tokens[-1]
        }

        $result = [ordered]@{
            Additions = $additions
            Deletions = $deletions
            Path      = $path
        }

        return [PSCustomObject]$result
    }
}
