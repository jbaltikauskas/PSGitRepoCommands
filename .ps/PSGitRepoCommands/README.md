# PSGitRepoCommands PowerShell module

Branch helpers for list/create/switch/delete/rename/track/clean, ahead/behind compare, and structured branch-to-branch diffs (tip-to-tip + per-commit) as `PSCustomObject` / JSON.

## Import

```powershell
Import-Module .\.ps\PSGitRepoCommands\PSGitRepoCommands.psd1
```

Public cmdlets return `[PSCustomObject]` (lists return arrays of them). Read properties explicitly, for example `(Get-GitCurrentBranch).Name` or `(Test-GitBranch -name main).Exists`.

## Requirements

- PowerShell 7.2+
- `git` on PATH

## Examples

Examples below match the `.EXAMPLE` help on each public cmdlet (`Get-Help <Cmdlet> -Examples`).

### Get-GitBranch

```powershell
PS> Get-GitBranch
```

Lists local branches as PSCustomObject rows (Name, IsCurrent, IsRemote, Upstream, Path).

```powershell
PS> Get-GitBranch -all
```

Lists local and remote-tracking branches.

```powershell
PS> (Get-GitBranch -current).Name
```

Returns only the current branch name string via the -current object.

### Get-GitCurrentBranch

```powershell
PS> Get-GitCurrentBranch
```

Returns a PSCustomObject with Name, Path, and IsCurrent for HEAD.

```powershell
PS> (Get-GitCurrentBranch -path 'C:\repos\app').Name
```

Gets the current branch name for a specific repository path.

### Test-GitBranch

```powershell
PS> (Test-GitBranch -name 'main').Exists
```

Returns `$true` when the local main branch exists.

```powershell
PS> Test-GitBranch -name 'origin/main' -remote
```

Tests a remote-tracking ref under refs/remotes.

### New-GitBranch

```powershell
PS> New-GitBranch -name 'feature/foo'
```

Creates feature/foo from HEAD and returns Name, StartPoint, Path, Switched.

```powershell
PS> New-GitBranch -name 'feature/foo' -startPoint 'main' -switch
```

Creates feature/foo from main and checks it out.

### Switch-GitBranch

```powershell
PS> Switch-GitBranch -name 'main'
```

Checks out main and returns Name, Path, Created, StartPoint.

```powershell
PS> Switch-GitBranch -name 'feature/new' -create -startPoint 'main'
```

Creates and switches to feature/new from main.

### Remove-GitBranch

```powershell
PS> Remove-GitBranch -name 'feature/foo' -force
```

Force-deletes the local branch feature/foo.

```powershell
PS> Remove-GitBranch -name 'feature/foo' -remote -remoteName 'origin'
```

Deletes the local branch and pushes --delete to origin.

### Rename-GitBranch

```powershell
PS> Rename-GitBranch -newName 'feature/bar'
```

Renames the current branch to feature/bar.

```powershell
PS> Rename-GitBranch -oldName 'feature/foo' -newName 'feature/bar'
```

Renames feature/foo to feature/bar and returns OldName, NewName, Path.

### Set-GitBranchUpstream

```powershell
PS> Set-GitBranchUpstream -upstream 'origin/main'
```

Sets the current branch to track origin/main.

```powershell
PS> Set-GitBranchUpstream -name 'feature/foo' -unset
```

Clears upstream tracking for feature/foo.

### Clear-GitBranch

```powershell
PS> Clear-GitBranch
```

Prunes stale remote-tracking refs on origin (fetch --prune).

```powershell
PS> Clear-GitBranch -gone -force
```

Prunes remotes and force-deletes local branches whose upstream is gone.

### Compare-GitBranch

```powershell
PS> Compare-GitBranch -baseBranch 'main' -compareBranch 'feature/foo'
```

Returns Ahead, Behind, and AheadBehindLabel for feature/foo vs main.

```powershell
PS> Compare-GitBranch
```

Compares the current branch to main (or master) using defaults.

### Get-GitBranchFullDiff

```powershell
PS> Get-GitBranchFullDiff -baseBranch main -targetBranch feature/foo
```

Tip-to-tip file changes; inspect `.Files` and `.Summary` on the result.

```powershell
PS> Get-GitBranchFullDiff -baseBranch main -targetBranch qa -direction Both -includePatch
```

Symmetric range metadata plus full patch text in `.Patch`.

### Get-GitBranchCommitDiff

```powershell
PS> Get-GitBranchCommitDiff -baseBranch main -targetBranch feature/foo
```

Lists commits in main..feature/foo with Files and metadata per commit.

```powershell
PS> (Get-GitBranchCommitDiff -baseBranch main -targetBranch qa -direction Both -includePatch:$true).Commits
```

Symmetric differing commits including Patch text on each entry.

### Get-GitBranchCommitByID

```powershell
PS> Get-GitBranchCommitByID -branch main
```

Returns the latest 20 commits on main. Number 1 is the newest.

```powershell
PS> Get-GitBranchCommitByID -branch main -limit 5 -includePatch:$false
```

Returns the latest 5 commits on main, without patch text.

```powershell
PS> Get-GitBranchCommitByID -branch main -shortHash a1b2c3d
```

Returns the one commit on main whose short hash is a1b2c3d.

```powershell
PS> Get-GitBranchCommitByID -branch main -number 1
```

Returns the latest commit on main.

```powershell
PS> Get-GitBranchCommitByID -branch main -hash 0123456789abcdef0123456789abcdef01234567
```

Returns the commit with that full hash when it is on main.

### Export-GitBranchCommitByID

```powershell
PS> Export-GitBranchCommitByID -branch main -shortHash a1b2c3d
```

Writes a timestamped JSON file under the repo and returns `.JsonPath`.

```powershell
PS> Export-GitBranchCommitByID -branch main -number 1 -outputPath '.\reports\commit.json'
```

Writes the latest commit on main to the chosen JSON path.

```powershell
PS> Export-GitBranchCommitByID -branch feature/foo -hash 0123456789abcdef0123456789abcdef01234567 -includePatch:$false
```

Writes that full-hash commit, without patch text.

### Get-GitBranchCommitsByAuthorOrEmail

```powershell
PS> Get-GitBranchCommitsByAuthorOrEmail -branch main -author 'Jane'
```

Returns the latest 20 commits on main whose author name contains Jane. Number 1 is the newest.

```powershell
PS> Get-GitBranchCommitsByAuthorOrEmail -branch main -email jane@example.com -limit 5 -includePatch:$false
```

Returns the latest 5 commits on main authored by that email, without patch text.

### Export-GitBranchCommitsByAuthorOrEmail

```powershell
PS> Export-GitBranchCommitsByAuthorOrEmail -branch main -author 'Jane'
```

Writes a timestamped JSON file under the repo and returns `.JsonPath`.

```powershell
PS> Export-GitBranchCommitsByAuthorOrEmail -branch main -email jane@example.com -limit 5 -outputPath .\reports\commits.json -includePatch:$false
```

Writes the latest 5 commits, without patch text, to the chosen JSON path.

### Get-GitBranchCommitsByDateRange

```powershell
PS> Get-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18'
```

Returns the latest 20 commits on main in that inclusive author-date range. Number 1 is the newest.

```powershell
PS> Get-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18' -author 'Jane' -includePatch:$false
```

Returns commits in that range whose author name contains Jane, without patch text.

```powershell
PS> Get-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18' -email jane@example.com -limit 5
```

Returns the latest 5 commits in that range with that author email.

### Export-GitBranchCommitsByDateRange

```powershell
PS> Export-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18'
```

Writes a timestamped JSON file under the repo and returns `.JsonPath`.

```powershell
PS> Export-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18' -author 'Jane' -outputPath '.\reports\commits.json' -includePatch:$false
```

Writes the matching commits, without patch text, to the chosen JSON path.

```powershell
PS> Export-GitBranchCommitsByDateRange -branch main -from '2026-02-01' -to '2026-02-18' -email jane@example.com -limit 5
```

Writes the latest 5 commits in that range with that author email.

### Export-GitBranchFullDiff

```powershell
PS> Export-GitBranchFullDiff -baseBranch main -targetBranch feature/foo
```

Writes a timestamped JSON file under the repo and returns `.JsonPath`.

```powershell
PS> Export-GitBranchFullDiff -baseBranch main -targetBranch qa -direction Both -outputPath '.\reports\diff.json' -includePatch
```

Exports tip + commits (with patches) to a chosen JSON path.
