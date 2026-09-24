function Resolve-GitDiffRange () {
    <#
    .SYNOPSIS
        Builds a git commit range from two refs and a direction.

    .DESCRIPTION
        Returns a PSCustomObject with BaseBranch, TargetBranch, BaseRef,
        TargetRef, Direction, Range, and RangeDescription for TargetAhead,
        BaseAhead, or Both (symmetric).

    .REMARKS
        1. Resolve base and target refs (required).
        2. Map Direction to a git range expression.
        3. Return a PSCustomObject describing the range.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Base branch name.")]
        [ValidateNotNullOrEmpty()]
        [string]$baseBranch,

        [Parameter(Mandatory = $true, HelpMessage = "Target branch name.")]
        [ValidateNotNullOrEmpty()]
        [string]$targetBranch,

        [Parameter(Mandatory = $false, HelpMessage = "Which side of the comparison supplies commits.")]
        [ValidateSet('TargetAhead', 'BaseAhead', 'Both')]
        [string]$direction = 'TargetAhead',

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        $baseResolved = Resolve-GitBranchRef -path $path -branch $baseBranch -require
        $targetResolved = Resolve-GitBranchRef -path $path -branch $targetBranch -require

        [string]$baseRef = $baseResolved.Ref
        [string]$targetRef = $targetResolved.Ref
        [string]$range = ''
        [string]$rangeDescription = ''

        switch ($direction) {
            'TargetAhead' {
                $range = "${baseRef}..${targetRef}"
                $rangeDescription = "commits in $targetBranch not in $baseBranch"
            }
            'BaseAhead' {
                $range = "${targetRef}..${baseRef}"
                $rangeDescription = "commits in $baseBranch not in $targetBranch"
            }
            'Both' {
                $range = "${baseRef}...${targetRef}"
                $rangeDescription = "commits in exactly one of $baseBranch / $targetBranch"
            }
        }

        $result = [ordered]@{
            Path             = $baseResolved.Path
            BaseBranch       = $baseBranch
            BaseRef          = $baseRef
            TargetBranch     = $targetBranch
            TargetRef        = $targetRef
            Direction        = $direction
            Range            = $range
            RangeDescription = $rangeDescription
        }

        return [PSCustomObject]$result
    }
}
