function Get-GitCommitWorkItems () {
    <#
    .SYNOPSIS
        Parses Azure and Azure Boards work item ids from a commit message.

    .DESCRIPTION
        Scans Subject and Body. Each hit is the original token, such as
        #56985 or AB#12345. The # inside AB# is not also stored as #12345.
        Returns those tokens in mention order. A repeated token is kept once,
        ignoring case. An empty message returns no rows.

    .REMARKS
        1. Combine subject and body.
        2. Match AB#id, then a #id that is not part of AB#.
        3. Emit each original token once.

    .EXAMPLE
        PS> Get-GitCommitWorkItems -subject 'Fix login button alignment #12345 and #56985'
        Returns #12345 and #56985.

        PS> Get-GitCommitWorkItems -subject 'Fix login validation bug AB#12345 and AB#56985'
        Returns AB#12345 and AB#56985.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Commit subject line.")]
        [AllowEmptyString()]
        [string]$subject = '',

        [Parameter(Mandatory = $false, HelpMessage = "Commit body.")]
        [AllowEmptyString()]
        [string]$body = ''
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$text = ((@($subject, $body) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n")
        [System.Collections.Generic.List[string]]$items = [System.Collections.Generic.List[string]]::new()
        [System.Collections.Generic.HashSet[string]]$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        if ([string]::IsNullOrWhiteSpace($text)) {
            return
        }

        [regex]$pattern = [regex]::new('(?<boards>AB)#(?<id>\d+)|(?<![A-Za-z])#(?<id>\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        foreach ($match in $pattern.Matches($text)) {
            [string]$key = $match.Value

            if (-not $seen.Add($key)) {
                continue
            }

            $items.Add($key)
        }

        foreach ($item in $items) {
            Write-Output $item
        }
    }
}
