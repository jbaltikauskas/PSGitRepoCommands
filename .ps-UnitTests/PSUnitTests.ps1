#Requires -Version 7.2

$corePath = Join-Path -Path $PSScriptRoot -ChildPath 'Core'
$coreScripts = @(Get-ChildItem -LiteralPath $corePath -Filter '*.ps1' -ErrorAction Stop)

foreach ($scriptFile in $coreScripts) {
    . $scriptFile.FullName
}
