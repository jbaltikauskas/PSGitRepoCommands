function Compare-GitBranch () {
    <#
    .SYNOPSIS
        Compares two branch refs and reports ahead/behind counts.

    .DESCRIPTION
        Resolves BaseBranch and CompareBranch (defaults: BaseBranch = main when
        present else master; CompareBranch = current branch). Returns a
        PSCustomObject with Path, BaseBranch, CompareBranch, Ahead, Behind, and
        AheadBehindLabel (e.g. "3	1"). Throws when either ref is missing.

    .NOTES
        1. Resolve and assert the repository path.
        2. Default compare branch to current; default base to main or master.
        3. Verify both refs exist via rev-parse.
        4. Run rev-list --left-right --count base...compare.
        5. Return ahead/behind PSCustomObject.

    .EXAMPLE
        PS> Compare-GitBranch -baseBranch 'main' -compareBranch 'feature/foo'
        Returns Ahead, Behind, and AheadBehindLabel for feature/foo vs main.

        PS> Compare-GitBranch
        Compares the current branch to main (or master) using defaults.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Base ref (left side). Defaults to main or master.")]
        [ValidateNotNullOrEmpty()]
        [string]$baseBranch,

        [Parameter(Mandatory = $false, HelpMessage = "Compare ref (right side). Defaults to the current branch.")]
        [ValidateNotNullOrEmpty()]
        [string]$compareBranch,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Compare-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ([string]::IsNullOrWhiteSpace($compareBranch)) {
            $compareBranch = (Get-GitCurrentBranch -path $resolvedPath).Name
        }

        if ([string]::IsNullOrWhiteSpace($baseBranch)) {
            if ((Test-GitBranch -path $resolvedPath -name 'main').Exists) {
                $baseBranch = 'main'
            }
            elseif ((Test-GitBranch -path $resolvedPath -name 'master').Exists) {
                $baseBranch = 'master'
            }
            else {
                throw "Could not default BaseBranch: neither 'main' nor 'master' exists. Pass -baseBranch explicitly."
            }
        }

        $null = Invoke-Git -path $resolvedPath -arguments @('rev-parse', '--verify', $baseBranch)
        $null = Invoke-Git -path $resolvedPath -arguments @('rev-parse', '--verify', $compareBranch)

        [string]$countsRaw = Invoke-Git -path $resolvedPath -arguments @(
            'rev-list',
            '--left-right',
            '--count',
            "$baseBranch...$compareBranch"
        )

        [string[]]$parts = ($countsRaw.Trim() -split '\s+')

        if ($parts.Count -lt 2) {
            throw "Unexpected rev-list output: '$countsRaw'"
        }

        [int]$behind = [int]$parts[0]
        [int]$ahead = [int]$parts[1]

        return [PSCustomObject]@{
            Path             = $resolvedPath
            BaseBranch       = $baseBranch
            CompareBranch    = $compareBranch
            Ahead            = $ahead
            Behind           = $behind
            AheadBehindLabel = "$ahead	$behind"
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Compare-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
