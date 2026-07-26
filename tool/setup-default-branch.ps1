[CmdletBinding()]
param(
    [string]$Repository = 'kaenozu/aimitsumori_app_spec_v0_1',
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$implementationPath = Join-Path $PSScriptRoot 'configure_github_repository.ps1'
if (-not (Test-Path -LiteralPath $implementationPath -PathType Leaf)) {
    throw "Repository configuration script not found: $implementationPath"
}

$parameters = @{
    Repository = $Repository
}
if ($ValidateOnly) {
    $parameters.ValidateOnly = $true
}

& $implementationPath @parameters
