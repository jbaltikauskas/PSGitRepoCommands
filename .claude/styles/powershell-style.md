---
name: powershell-script-style
description: Authoritative structure and style for new PowerShell scripts (.ps1) in this workspace. Use when writing a new PS script from scratch, refactoring an existing PS script to match house style, or reviewing a PS script for consistency. Triggers on requests like "write a PS script", "refactor this PowerShell", "use my PS style", "use the standard PS template", or whenever a .ps1 file is being created or edited.
---

# PowerShell Script Style

Every new `.ps1` file in this workspace follows the same five-block layout. Keep the order. Do not skip blocks even when they feel small.

## File layout (top to bottom)

1. Comment-based help block (`<# ... #>`) with `.SYNOPSIS`, `.DESCRIPTION`, one `.PARAMETER` per parameter, `.INPUTS`, `.OUTPUTS`, `.NOTES`, two or more `.EXAMPLE` blocks.
2. `#Requires -Version 7.2` (or whatever minimum the script needs).
3. `[CmdletBinding()] Param ( ... )` block with one `[Parameter(...)]` attribute per parameter.
4. Function definitions, each as an advanced function with its own `[CmdletBinding()] Param ( ... )`. After **`Param`**, use **`Begin` + `Process`** (helpers/scripts) or **`Begin` + `Process` + `End`** (public PSGitRepoCommands cmdlets with yellow Begin/END banners). A plain **`{ ... }`** body or **`Process`** only is also allowed for helpers.
5. `try { ... } catch { ... }` wrapper that runs the orchestration. The catch prints the exception, prompts the user to close the window, and exits with code 1. After the wrapper, print a success line and prompt to close.

## Block 1: Comment-based help

`.DESCRIPTION` must contain a numbered top-down flow walkthrough so any reader knows what the script does step by step before reading code. Example shape:

```powershell
<#
.SYNOPSIS
    One-sentence summary of what this script does.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Verify prerequisites (CLI on PATH, daemon responding).
        2. Resolve required paths or interactive inputs.
        3. Validate inputs (folder must exist, port in 1..65535, etc).
        4. Print a Settings block so logs make the run reproducible.
        5. Call the main worker function(s).
        6. Print a summary.

    Mention any companion scripts you should know about.

.PARAMETER FirstParam
    What it is, why it matters, default behavior, and what happens when it is omitted.

.INPUTS
    None. All values come from parameters.

.OUTPUTS
    Host messages and any files produced. Exit code 0 on success, 1 on failure.

.NOTES
    Required PowerShell version, runtime prerequisites, where the script lives,
    and any matching .bat shortcut.

.EXAMPLE
    PS> .\Your-Script.ps1 -FirstParam "value"
    Short note about what this example does.

.EXAMPLE
    PS> .\Your-Script.ps1 -FirstParam "value" -Switch
#>
```

Every parameter you declare must have a matching `.PARAMETER` block. If they drift, the help is wrong.

## Block 2: Requires and error settings

```powershell
#Requires -Version 7.2

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
```

The `$PSNativeCommandUseErrorActionPreference` line makes native commands (docker, git, icacls) throw on non-zero exit under `Stop`. Keep it.

## Block 3: Param block

```powershell
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Short hint shown when value is missing.")]
    [ValidateNotNullOrEmpty()]
    [string]$buildSourcesDirectory,

    [Parameter(Mandatory = $false, HelpMessage = "Optional. Default value supplied below.")]
    [ValidateNotNullOrEmpty()]
    [string]$dockerSourceImageHelpPage = "https://example.com/docs"
)
```

Rules for the param block:

- One `[Parameter(...)]` attribute per parameter, with `Mandatory`, `Position` when meaningful, and `HelpMessage`.
- `[ValidateNotNullOrEmpty()]` on every required string. Use `[ValidateSet(...)]`, `[ValidateRange(...)]`, or `[ValidatePattern(...)]` when applicable.
- Camel case parameter names match the reference script. Pick one casing and stick with it across the repo so diffs stay clean.
- Default values go on the parameter line, not in the body.
- `[switch]` for boolean opt-in flags. `[bool]$Foo = $true` when you need a default-true that the caller can flip with `-Foo:$false`.
- `[SecureString]` for any secret a user enters. Decode with a small helper, zero the plaintext after use.

## Block 4: Functions

Every function is an advanced function. Use approved verbs (`Get-`, `Set-`, `New-`, `Read-`, `Write-`, `Invoke-`, `Test-`, `Assert-`, `Resolve-`, `Update-`, `Convert-`, `Start-`, `Stop-`). Pascal case for function names.

```powershell
function New-Thing () {
    <#
    .SYNOPSIS
        One sentence on what this function does.

    .DESCRIPTION
        What the function does in plain language: purpose, return value or
        output contract, important branches, errors thrown, and non-obvious
        side effects (disk, network, environment). Keep this separate from `.REMARKS`.

    .REMARKS
        1. Validate that Path exists; throw if not.
        2. Invoke the native command with Name and Path.
        3. If exit code is non-zero, throw with the code in the message.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "What goes here.")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "What goes here.")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        # The actual work goes here.
        # Throw on any error condition. The top-level try/catch will format it.
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Path not found: '$Path'"
        }

        & some-native-command --arg "$Name" --path "$Path"
        if ($LASTEXITCODE -ne 0) {
            throw "some-native-command failed with exit code $LASTEXITCODE."
        }
    }
}
```

### Function comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.NOTES`, and `.EXAMPLE`

Put the `<# ... #>` block **inside** the function, before `[CmdletBinding()]` and `Param`.

**Every function** must include these sections **in this order** (top to bottom):

- **`.SYNOPSIS`** — Single sentence on what it does.

- **`.DESCRIPTION`** — Summarize purpose, return value or observable outcome, what each important branch does, what is thrown on failure, and side effects callers care about. For tiny helpers, one short paragraph is enough. Do not duplicate the step list; that belongs in `.NOTES`.

- **`.NOTES`** — A numbered list describing what the function does **in order** from a control-flow perspective (validate → branch → call → return). Omit trace-only plumbing (for example the standard **`Begin`** block that runs **`$PSBoundParameters | Write-Debug`**), unless emitting that trace **is** the function's sole job. For helpers whose output **is** host formatting (**`Write-Section`**), FLOW lists the cyan banner **`Write-Host`** sequence. Use **`.NOTES`**, not **`.REMARKS`** (`.REMARKS` is not a valid help keyword and breaks `Get-Help`).

- **`.EXAMPLE`** — **Always last. Exactly one `.EXAMPLE` section** at the bottom of the help comment. Put two or more sample invocations inside it (each `PS>` line plus a short note). Do **not** repeat the `.EXAMPLE` keyword.

**Blank lines:** Exactly **one** empty line between help sections (and before `#>`). Inside the single `.EXAMPLE` section, put **exactly one** blank line between consecutive samples (`PS>` + note, then one blank line, then the next `PS>`). Never use two blank lines between samples. Do not leave two or more consecutive blank lines anywhere inside `<# ... #>` — that confuses the editor comment parser and can show a false "terminator `#>` is missing" error.

Helpers that touch secrets stay minimal per workspace secret rules: `.DESCRIPTION` and `.NOTES` can be one line each; do not echo parameters in help text; still put **one `.EXAMPLE` section last**.

### `Begin`, `Process`, and `End`

- **Public PSGitRepoCommands cmdlets** (`.ps/PSGitRepoCommands/Public/*.ps1`) use **`Begin` + `Process` + `End`** with yellow dashed banners (same style as **`Get-GitBranchFullDiff`** / **`Step - AddT4EmptyCsFiles.ps1`**). Use the actual function name in both banners.

    ```powershell
    Begin {

        Write-Host ""
        Write-Host "--------------------------------- Begin: Get-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }

    Process {

        # implementation
    }

    End {

        Write-Host ""
        Write-Host "--------------------------------- END: Get-GitBranchFullDiff ---------------------------------------------" -ForegroundColor "Yellow"
        Write-Host ""
    }
    ```

- **`$PSBoundParameters | Out-String | Write-Host`** in **`Begin`** is **optional**. Add it only when bound-parameter tracing is useful for that function (debugging, CI reproducibility). Omit it when it is just noise. Never dump **`[SecureString]`** / secret parameters.

- Helpers and scripts **do not** use **`End { }`** or per-function yellow Begin/END banners. They may dump **`$PSBoundParameters`** in **`Begin`** when needed, plus script-level **`BEGIN: Settings`**.

- An advanced function that **declares one or more parameters** uses **`Begin`** then **`Process`**. The bound-parameter dump is not required. Omit **`Begin`** entirely when **`Param`** is empty, or when any parameter is **`[SecureString]`** / secret material.

- **Parameterless** functions need no **`Begin`** trace above.

- **`Process {`**: Put one empty line after the opening brace before the first statement inside the block (same spacing as **`Begin`** / **`Process`** separation). Do not put the first statement on the same line as `Process {`.

- **`try {`**: Same as **`Process {`** — one empty line after the opening brace before the first statement inside **`try`**. Do not put the first statement on the same line as `try {`.

Function rules:

- Tiny host-output helpers (for example `Write-Section`) use **`Begin`** + **`Process`** when they declare parameters.

- String encryption/decryption helpers: **`Process`** only; the **`Begin { $PSBoundParameters | Write-Debug }`** pattern **is omitted** so secrets never hit **`Write-Debug`**.

- Prefer `throw` over `Write-Error` + `return` so the top-level catch handles it.
- For native commands, check `$LASTEXITCODE` and throw with the exit code in the message.
- Name patterns to follow:
  - `Assert-Foo`: validates a precondition and throws on failure.
  - `Resolve-Foo`: returns a value (path, config, choice) and throws on ambiguity.
  - `Get-Foo`: returns data, never throws on "not found" unless that is a true error.
  - `Test-Foo`: returns `$true` or `$false`, never throws.
  - `New-Foo`: creates something on disk or in memory and returns it.
  - `Write-Foo`: writes to disk or to the host. Returns void or the path.
  - `Read-FooInteractive`: prompts the user and validates the input in a loop.

## Block 5: Try/catch wrapper

The whole orchestration goes in `try { }`. The catch prints diagnostics, asks the user to press Enter, and exits 1. Two `Read-Host` close prompts (one in catch, one after) so the console window stays open whether the run failed or succeeded.

Nested **`try`** blocks (anywhere in the script) follow the same rule as **`Process`**: one empty line after **`try {`** before the first inner statement.

```powershell
try {

    # ---- 1. Prerequisites --------------------------------------------------
    if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Required: Install Docker and ensure 'docker' is available in PATH."
    }

    # ---- 2. Resolve / validate inputs --------------------------------------
    [string]$resolvedContext = [System.IO.Path]::GetFullPath($buildSourcesDirectory)
    if (-not (Test-Path -LiteralPath $resolvedContext -PathType Container)) {
        throw "Build context directory not found: '$resolvedContext'"
    }

    # ---- 3. Settings printout ----------------------------------------------
    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Resolved context directory:"
    Write-Output "    $resolvedContext"
    Write-Output ""
    $PSBoundParameters | Out-String | Write-Output
    Write-Output "--------------------------- END: Settings ---------------------------"
    Write-Output ""

    # ---- 4. Do the work ----------------------------------------------------
    New-Thing -Name "example" -Path $resolvedContext

}
catch {

    Write-Host ""
    Write-Error "Caught an exception:" -ErrorAction Continue
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)" -ErrorAction Continue
    Write-Error "Exception Message: $($_.Exception.Message)" -ErrorAction Continue
    Write-Host ""

    Write-Host "Script failed to execute." -ForegroundColor "Red"

    Read-Host "Press Enter to close the window ..."

    EXIT 1
}

Write-Host ""
Write-Host "Script executed successfully." -ForegroundColor "Green"

Read-Host "Press Enter to close the window ..."
```

## Settings block

Always print a `BEGIN: Settings` / `END: Settings` block before the work starts. The dump of `$PSBoundParameters` makes a CI run reproducible from the log alone. Include any values you computed (resolved paths, picked port) above the dump so the reader sees them too.

## Section banners (multi-step scripts)

When the script has many steps, use a small `Write-Section` helper and call it before each phase. Keep banners short and informative.

```powershell
function Write-Section () {
    <#
    .SYNOPSIS
        Prints a cyan section header bordered by gray rule lines.

    .DESCRIPTION
        Host-only formatting; emits four Write-Host lines (spacing, borders, title).

    .REMARKS
        1. Write blank line, gray horizontal rules, and cyan titled message.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host " $Message" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor DarkGray
    }
}
```

## File and IO conventions

- Always `[System.IO.Path]::GetFullPath(...)` user-supplied paths before validating, so error messages show the resolved path.
- Always use `-LiteralPath` with `Test-Path`, `Get-Content`, and `Set-Content`. Wildcards in user-supplied paths are bugs, not features.
- Use `Set-Content -Encoding utf8NoBOM -NoNewline` when you write env files, YAML, or anything where a leading BOM would break the consumer.
- Native commands (docker, icacls, git): use call operator `& docker ...`, then check `$LASTEXITCODE` and throw.

## Secrets

- Never echo a SecureString. Decode just before you need the plaintext, and null the variable right after.
- String encryption/decryption helper functions must not echo parameters; keep them to a small body or only `Process`.
- Use this helper unchanged when you need to decode (body and **`Process`** semantics stay as shown; no **`Begin`** trace — **`Secret`** must never reach **`Write-Debug`**):

```powershell
function Convert-SecureStringToPlain () {
    <#
    .SYNOPSIS
        Converts a SecureString to a plain string for brief use.

    .DESCRIPTION
        Marshal-based decode; caller must zero sensitive plaintext promptly. Never log the result.

    .REMARKS
        1. Return $null when Secret is missing.
        2. Decode via BSTR, return plaintext, zero the BSTR in finally.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [SecureString]$Secret
    )

    Process {

        if (-not $Secret) { return $null }
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
        try {

            return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}
```

- Lock the ACL on any file containing plaintext secrets to the current user:

```powershell
icacls $secretsPath /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
```

## Interactive prompts

When you prompt the user for a value with a default, show the default and validate the input in a loop:

```powershell
function Read-PortInteractive () {
    <#
    .SYNOPSIS
        Prompts until the user enters a valid TCP port or accepts the default.

    .DESCRIPTION
        Loops on Read-Host; empty input returns Default; validates 1–65535.

    .REMARKS
        1. Loop: read raw input.
        2. If whitespace, return Default.
        3. If numeric and in range, return value; else warn and retry.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [int]$Default = 9621
    )

    Begin {
        $PSBoundParameters | Out-String | Write-Host
    }

    Process {

        while ($true) {
            $raw = Read-Host "Web UI host port [default: $Default]"
            if ([string]::IsNullOrWhiteSpace($raw)) {
                return $Default
            }

            if ($raw -match '^\d+$') {
                $val = [int]$raw
                if ($val -ge 1 -and $val -le 65535) {
                    return $val
                }
            }

            Write-Host "  Not a valid port (1-65535). Try again." -ForegroundColor Yellow
        }
    }
}
```

## Braces and multiline statements

- Always use `{ }` for `if`, `else`, loops, `try`, `catch`, `finally`, and any other block. Even a single statement must live inside a brace-delimited block.
- Avoid compact inline forms like `if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }`.
- Prefer the multiline style so the script is easier to read, consistent, and easier to format after edits.
- Put one empty line before and after conditional and error-handling blocks such as `if`, `try`, `catch`, and `finally`, unless the block is the first or last statement in its parent block. Keep attached block clauses together: do not insert a blank line between `}` and `elseif`, `else`, `catch`, or `finally`.
- Put one empty line after `Process {` before the first statement inside **`Process`** (see **`Begin`, `Process`, and `End`**).
- Put one empty line after `try {` before the first statement inside **`try`** (see **Block 5: Try/catch wrapper**).
- After any PowerShell script modification, reformat the file so indentation and block structure remain clean.

## Coloring rules

Match the reference exactly so logs look the same across scripts:

- `Yellow` for section banners and warnings.
- `Cyan` for headers inside a section, URLs, and generated keys you want the user to copy.
- `Green` for "this command/check passed".
- `Red` for the final "Script failed to execute." line.
- `DarkGray` for hint text under a header.

## What NOT to do

- Do not skip the help block "because the script is small". Future readers count on it.
- Do **not** add **`End { }`** to helpers or scripts. Public PSGitRepoCommands cmdlets **do** use **`End { }`** with yellow **`END: FunctionName`** banners.

- Do **not** use per-function **`Write-Host`** "**Begin: Func**" / "**END: Func**" banners on helpers or scripts (**`BEGIN: Settings`** / **`END: Settings`** at script level stay fine). Public PSGitRepoCommands cmdlets are the exception.
- Do not mix Pascal case and camel case inside one script. Pick one (this workspace uses camel case for parameters, Pascal for functions) and stick to it.
- Do not call `exit` or `return` from inside a function as the failure path. `throw` and let the top-level catch format the error.
- Do not use `Write-Error` for control flow. It is for diagnostics inside the catch.
- Do not use legacy aliases (`gci`, `?`, `%`, `select`, `where`). Spell out the cmdlet.
- Always use `{ }` for `if`, `else`, loops, `try`, `catch`, `finally`, and any other block, even for a single statement.
- Avoid compact inline forms like `if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }`.
- Do not crowd conditional or error-handling blocks against surrounding statements; keep one empty line before and after `if`, `try`, `catch`, and `finally` blocks, except at the start or end of the parent block and before attached `elseif`, `else`, `catch`, or `finally`.
- Do not crowd **`Process`** or **`try`** — keep one empty line after `Process {` or `try {` before the first inner statement.
- Prefer the multiline block style so the script is easier to read and easier to format after edits.
- Do not put logic outside the `try { }` wrapper at the bottom of the script. The only things below the catch are the success message and the final `Read-Host`.

## Quick checklist before you ship a new PS script

1. Help block has `.SYNOPSIS`, `.DESCRIPTION` (with numbered flow), one `.PARAMETER` per parameter, `.INPUTS`, `.OUTPUTS`, `.NOTES`, two or more `.EXAMPLE`.
2. `#Requires -Version`, `$ErrorActionPreference = 'Stop'`, `$PSNativeCommandUseErrorActionPreference = $true` are set.
3. Every parameter has `[Parameter(...)]` with `HelpMessage` and an appropriate `Validate*` attribute.
4. Every function is an advanced function. Public PSGitRepoCommands cmdlets use **`Begin` + `Process` + `End`** with yellow **`Begin: Name` / `END: Name`** banners. **`$PSBoundParameters | Out-String | Write-Host`** in **`Begin`** is optional (use only when tracing is needed). Helpers/scripts use **`Begin` + `Process`** with no **`End`**; secret-only helpers **`Process`** only. After **`Process {`**, one empty line before the first inner statement.
5. Every function has comment-based help with **`.SYNOPSIS`**, **`.DESCRIPTION`**, **`.NOTES`**, and **one `.EXAMPLE` section last** containing multiple samples (see **Function comment-based help**). Use exactly one blank line between help sections. Do not use `.REMARKS`. In `.NOTES`, skip printing-only steps unless that is the function's contract.
6. The orchestration lives in one `try { ... }` block. After every **`try {`**, one empty line before the first inner statement (including nested **`try`**).
7. The catch prints exception type and message, then `Read-Host`, then `EXIT 1`.
8. After the wrapper, you print "Script executed successfully." in Green and a final `Read-Host`.
9. Native command exit codes are checked and thrown.
10. Secrets are SecureString end-to-end, decoded only at the point of use.
