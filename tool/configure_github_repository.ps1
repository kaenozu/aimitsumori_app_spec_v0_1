[CmdletBinding()]
param(
    [string]$Repository = 'kaenozu/aimitsumori_app_spec_v0_1',
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$rulesetPath = Join-Path $repositoryRoot '.github/rulesets/main-required-checks.json'
$expectedChecks = @(
    'Format, analyze, test, debug build',
    'Android emulator E2E',
    'Release APK compile'
)
$expectedRuleTypes = @(
    'deletion',
    'non_fast_forward',
    'pull_request',
    'required_status_checks'
)

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }

    $text = $output -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

Assert-Condition (Test-Path -LiteralPath $rulesetPath) "Ruleset file not found: $rulesetPath"
$ruleset = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json

Assert-Condition ($ruleset.name -eq 'main-required-checks') 'Unexpected ruleset name.'
Assert-Condition ($ruleset.target -eq 'branch') 'Ruleset target must be branch.'
Assert-Condition ($ruleset.enforcement -eq 'active') 'Ruleset enforcement must be active.'
Assert-Condition (@($ruleset.conditions.ref_name.include) -contains 'refs/heads/main') 'Ruleset must target refs/heads/main.'

$ruleTypes = @($ruleset.rules | ForEach-Object { $_.type })
foreach ($ruleType in $expectedRuleTypes) {
    Assert-Condition ($ruleTypes -contains $ruleType) "Ruleset is missing required rule: $ruleType"
}

$statusRule = @($ruleset.rules | Where-Object { $_.type -eq 'required_status_checks' }) | Select-Object -First 1
Assert-Condition ($null -ne $statusRule) 'Ruleset is missing required_status_checks.'
Assert-Condition ([bool]$statusRule.parameters.strict_required_status_checks_policy) 'Required status checks must use strict mode.'

$configuredChecks = @($statusRule.parameters.required_status_checks | ForEach-Object { $_.context })
foreach ($check in $expectedChecks) {
    Assert-Condition ($configuredChecks -contains $check) "Ruleset is missing required status check: $check"
}

if ($ValidateOnly) {
    Write-Host 'Repository ruleset configuration is valid.'
    exit 0
}

$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
Assert-Condition ($null -ne $ghCommand) 'GitHub CLI (gh) is required.'

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated. Run gh auth login first.'
}

$repositoryState = Invoke-GhJson @('api', "repos/$Repository")
Assert-Condition ($repositoryState.full_name -eq $Repository) "Authenticated account cannot access $Repository."

$null = Invoke-GhJson @('api', "repos/$Repository/branches/main")

if ($repositoryState.default_branch -ne 'main') {
    Write-Host "Changing default branch from $($repositoryState.default_branch) to main..."
    $repositoryState = Invoke-GhJson @(
        'api',
        '--method', 'PATCH',
        "repos/$Repository",
        '-f', 'default_branch=main'
    )
}
else {
    Write-Host 'Default branch is already main.'
}

$rulesets = @(Invoke-GhJson @('api', "repos/$Repository/rulesets"))
$existingRuleset = $rulesets |
    Where-Object { $_.name -eq $ruleset.name -and $_.target -eq 'branch' } |
    Select-Object -First 1

if ($null -eq $existingRuleset) {
    Write-Host "Creating active ruleset '$($ruleset.name)'..."
    $appliedRuleset = Invoke-GhJson @(
        'api',
        '--method', 'POST',
        "repos/$Repository/rulesets",
        '--input', $rulesetPath
    )
}
else {
    Write-Host "Updating active ruleset '$($ruleset.name)' (id: $($existingRuleset.id))..."
    $appliedRuleset = Invoke-GhJson @(
        'api',
        '--method', 'PUT',
        "repos/$Repository/rulesets/$($existingRuleset.id)",
        '--input', $rulesetPath
    )
}

$verifiedRepository = Invoke-GhJson @('api', "repos/$Repository")
Assert-Condition ($verifiedRepository.default_branch -eq 'main') 'Default branch verification failed.'
Assert-Condition ($appliedRuleset.enforcement -eq 'active') 'Ruleset enforcement verification failed.'

$appliedStatusRule = @($appliedRuleset.rules | Where-Object { $_.type -eq 'required_status_checks' }) | Select-Object -First 1
$appliedChecks = @($appliedStatusRule.parameters.required_status_checks | ForEach-Object { $_.context })
foreach ($check in $expectedChecks) {
    Assert-Condition ($appliedChecks -contains $check) "Applied ruleset is missing required status check: $check"
}

Write-Host ''
Write-Host "Configured repository: $Repository"
Write-Host 'Default branch: main'
Write-Host "Ruleset: $($appliedRuleset.name) (active)"
Write-Host 'Required checks:'
$expectedChecks | ForEach-Object { Write-Host "  - $_" }
