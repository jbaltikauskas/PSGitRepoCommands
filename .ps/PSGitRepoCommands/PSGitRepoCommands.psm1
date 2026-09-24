#Requires -Version 7.2

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

$privateScripts = @(Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' -ErrorAction Stop)
$publicScripts = @(Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -ErrorAction Stop)

foreach ($scriptFile in ($privateScripts + $publicScripts)) {

    . $scriptFile.FullName
}

Export-ModuleMember -Function $publicScripts.BaseName
