function Invoke-Git () {
    <#
    .SYNOPSIS
        Runs git -C Path with the given arguments and returns stdout.

    .DESCRIPTION
        Executes the native git CLI with -C targeting Path, captures standard
        output as a single string, and throws when the exit code is non-zero
        (including stderr text when present) unless AllowNonZeroExit is set.
        Empty stdout returns an empty string. Temporarily disables
        PSNativeCommandUseErrorActionPreference so exit codes are handled here.

    .REMARKS
        1. Disable PSNativeCommandUseErrorActionPreference for the git call.
        2. Build the argument list with -C Path plus caller arguments.
        3. Write the full git command line to the host.
        4. Invoke git and capture stdout/stderr.
        5. Throw when LASTEXITCODE is non-zero unless AllowNonZeroExit.
        6. Restore the previous preference and return trimmed stdout.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Resolved repository directory for git -C.")]
        [ValidateNotNullOrEmpty()]
        [string]$path,

        [Parameter(Mandatory = $true, HelpMessage = "Git command arguments after -C Path.")]
        [ValidateNotNull()]
        [string[]]$arguments,

        [Parameter(Mandatory = $false, HelpMessage = "When set, return stdout even if git exits non-zero.")]
        [switch]$allowNonZeroExit
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Assert-GitInstalled

        [string[]]$gitArgs = @('-C', $path, '--no-pager', '-c', 'color.ui=false') + $arguments
        [string[]]$displayArgs = foreach ($arg in $gitArgs) {
            if ($arg -match '[\s"]') {
                '"' + ($arg -replace '"', '\"') + '"'
            }
            else {
                $arg
            }
        }

        Write-Host ("git {0}" -f ($displayArgs -join ' ')) -ForegroundColor Green

        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false

        try {

            $stdout = & git @gitArgs 2>&1
            [int]$exitCode = $LASTEXITCODE
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }

        if (($exitCode -ne 0) -and (-not $allowNonZeroExit)) {
            [string]$detail = ($stdout | Out-String).Trim()

            if ([string]::IsNullOrWhiteSpace($detail)) {
                throw "git $($arguments -join ' ') failed with exit code $exitCode."
            }

            throw "git $($arguments -join ' ') failed with exit code $exitCode. $detail"
        }

        if ($null -eq $stdout) {
            return ''
        }

        return (($stdout | ForEach-Object { "$_" }) -join "`n").TrimEnd()
    }
}
