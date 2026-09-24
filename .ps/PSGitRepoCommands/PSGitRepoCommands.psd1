@{
    RootModule        = 'PSGitRepoCommands.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'a7c3e9f1-4b2d-4e8a-9c1f-6d5e8a2b3c4d'
    Author            = 'PSGitRepoCommands'
    Description       = 'PowerShell helpers for Git branch operations and structured branch-to-branch diffs (PSCustomObject / JSON).'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Get-GitBranch'
        'Get-GitCurrentBranch'
        'Test-GitBranch'
        'New-GitBranch'
        'Switch-GitBranch'
        'Remove-GitBranch'
        'Rename-GitBranch'
        'Set-GitBranchUpstream'
        'Clear-GitBranch'
        'Compare-GitBranch'
        'Get-GitBranchFullDiff'
        'Get-GitBranchCommitDiff'
        'Get-GitBranchCommitByID'
        'Export-GitBranchCommitByID'
        'Get-GitBranchCommitsByAuthorOrEmail'
        'Export-GitBranchCommitsByAuthorOrEmail'
        'Get-GitBranchCommitsByDateRange'
        'Export-GitBranchCommitsByDateRange'
        'Export-GitBranchFullDiff'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
