function New-GitBranch () {
    <#
    .SYNOPSIS
        Creates a new local Git branch.

    .DESCRIPTION
        Creates Name from StartPoint (default HEAD). When -switch is set, checks
        out the new branch after creation. Throws if the branch already exists
        or git fails. Returns a PSCustomObject with Name, StartPoint, Path, and
        Switched.

    .NOTES
        1. Resolve and assert the repository path.
        2. Build git branch arguments with optional start point.
        3. Create the branch via Invoke-Git.
        4. Optionally switch to the new branch.
        5. Return a PSCustomObject of the create result.

    .EXAMPLE
        PS> New-GitBranch -name 'feature/foo'
        Creates feature/foo from HEAD and returns Name, StartPoint, Path, Switched.

        PS> New-GitBranch -name 'feature/foo' -startPoint 'main' -switch
        Creates feature/foo from main and checks it out.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the branch to create.")]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $false, HelpMessage = "Start point commit or ref. Defaults to HEAD.")]
        [ValidateNotNullOrEmpty()]
        [string]$startPoint,

        [Parameter(Mandatory = $false, HelpMessage = "Repository path. Defaults to the current location.")]
        [ValidateNotNullOrEmpty()]
        [string]$path = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Check out the new branch after creating it.")]
        [switch]$switch
    )

    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: New-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        [string]$resolvedPath = Assert-GitRepository -path $path

        if ((Test-GitBranch -path $resolvedPath -name $name).Exists) {
            throw "Branch already exists: '$name'"
        }

        [string]$resolvedStartPoint = if ([string]::IsNullOrWhiteSpace($startPoint)) {
            'HEAD'
        }
        else {
            $startPoint
        }

        [System.Collections.Generic.List[string]]$argsList = [System.Collections.Generic.List[string]]::new()
        $argsList.Add('branch')
        $argsList.Add($name)

        if (-not [string]::IsNullOrWhiteSpace($startPoint)) {
            $argsList.Add($startPoint)
        }

        $null = Invoke-Git -path $resolvedPath -arguments $argsList.ToArray()

        if ($switch) {
            $null = Switch-GitBranch -path $resolvedPath -name $name
        }

        return [PSCustomObject]@{
            Name       = $name
            StartPoint = $resolvedStartPoint
            Path       = $resolvedPath
            Switched   = $switch.IsPresent
        }
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: New-GitBranch ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
}
