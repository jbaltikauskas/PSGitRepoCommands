function Switch-GitBranch () {
    <#
    .SYNOPSIS
        Switches the working tree to another branch.

    .DESCRIPTION
        Runs git switch to Name. When -create is set, creates and switches to
        Name (optionally from StartPoint). Throws when the switch fails. Returns
        a PSCustomObject with Name, Path, Created, and StartPoint.

    .NOTES
        1. Resolve and assert the repository path.
        2. Build git switch arguments (-c when Create).
        3. Invoke git switch and return a PSCustomObject result.

    .EXAMPLE
        PS> Switch-GitBranch -name 'main'
        Checks out main and returns Name, Path, Created, StartPoint.

        PS> Switch-GitBranch -name 'feature/new' -create -startPoint 'main'
        Creates and switches to feature/new from main.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Branch name to switch to.")]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Create the branch if it does not exist, then switch.")]
        [switch]$create,

        [Parameter(Mandatory = $false, HelpMessage = "Start point when using -create.")]
        [ValidateNotNullOrEmpty()]
        [string]$startPoint
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Switch-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        [string]$resolvedStartPoint = if ([string]::IsNullOrWhiteSpace($startPoint)) {
            ''
        }
        else {
            $startPoint
        }

        [System.Collections.Generic.List[string]]$argsList = [System.Collections.Generic.List[string]]::new()
        $argsList.Add('switch')

        if ($create) {
            $argsList.Add('-c')
            $argsList.Add($name)

            if (-not [string]::IsNullOrWhiteSpace($startPoint)) {
                $argsList.Add($startPoint)
            }
        }
        else {
            $argsList.Add($name)
        }

        $null = Invoke-Git -path $resolvedPath -arguments $argsList.ToArray()

        return [PSCustomObject]@{
            Name       = $name
            Path       = $resolvedPath
            Created    = $create.IsPresent
            StartPoint = $resolvedStartPoint
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Switch-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
