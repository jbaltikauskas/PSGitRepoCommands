function Set-GitBranchUpstream () {
    <#
    .SYNOPSIS
        Sets or clears the upstream tracking branch.

    .DESCRIPTION
        For Name (default current branch), either unsets upstream with
        --unset-upstream when -unset is set, or sets upstream to Upstream
        (e.g. origin/main) via branch --set-upstream-to. Returns a
        PSCustomObject with Name, Path, Upstream, and Unset.

    .NOTES
        1. Resolve and assert the repository path.
        2. Default Name to the current branch when omitted.
        3. Unset or set upstream via Invoke-Git.
        4. Return a PSCustomObject of the tracking result.

    .EXAMPLE
        PS> Set-GitBranchUpstream -upstream 'origin/main'
        Sets the current branch to track origin/main.

        PS> Set-GitBranchUpstream -name 'feature/foo' -unset
        Clears upstream tracking for feature/foo.

    #>
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Local branch to configure. Defaults to the current branch.")]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Set', HelpMessage = "Upstream ref such as origin/main.")]
        [ValidateNotNullOrEmpty()]
        [string]$upstream,

        [Parameter(Mandatory = $true, ParameterSetName = 'Unset', HelpMessage = "Clear the upstream tracking configuration.")]
        [switch]$unset,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Set-GitBranchUpstream ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = (Get-GitCurrentBranch -path $resolvedPath).Name
        }

        [string]$resolvedUpstream = ''

        if ($unset) {
            $null = Invoke-Git -path $resolvedPath -arguments @('branch', '--unset-upstream', $name)
        }
        else {
            $resolvedUpstream = $upstream
            $null = Invoke-Git -path $resolvedPath -arguments @('branch', "--set-upstream-to=$upstream", $name)
        }

        return [PSCustomObject]@{
            Name     = $name
            Path     = $resolvedPath
            Upstream = $resolvedUpstream
            Unset    = $unset.IsPresent
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Set-GitBranchUpstream ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
