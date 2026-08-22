[CmdletBinding()]
param(
    [string]$Repository = 'kaenozu/aimitsumori_app_spec_v0_1',
    [Alias('ValidateOnly')]
    [switch]$ValidateConfigOnly,
    [switch]$ValidateAppliedProtection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ValidateConfigOnly -and $ValidateAppliedProtection) {
    throw 'Specify only one of -ValidateConfigOnly or -ValidateAppliedProtection.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$rulesetPath = Join-Path $repositoryRoot '.github/rulesets/main-required-checks.json'
$expectedChecks = @(
    'Format, analyze, test, debug build',
    'Android emulator E2E',
    'Release APK compile'
)

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$Message
    )
    if (-not $Condition) { throw $Message }
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
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function Invoke-GhJsonAllowMissing {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )
    $output = & gh @Arguments 2>&1
    return $LASTEXITCODE -eq 0
}

function Assert-AppliedProtection {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        [Parameter(Mandatory)]
        [object]$LocalRuleset
    )

    $repositoryState = Invoke-GhJson @('api', "repos/$RepositoryName")
    Assert-Condition ($repositoryState.full_name -eq $RepositoryName) "Authenticated account cannot access $RepositoryName."
    Assert-Condition ($repositoryState.default_branch -eq 'main') 'GitHub default branch is not main.'

    $branchState = Invoke-GhJson @('api', "repos/$RepositoryName/branches/main")
    Assert-Condition ([bool]$branchState.protected) 'GitHub reports main as unprotected.'

    $rulesets = @(Invoke-GhJson @('api', "repos/$RepositoryName/rulesets") 2>$null)
    $matching = $rulesets |
        Where-Object { $_.name -eq $LocalRuleset.name -and $_.target -eq 'branch' } |
        Select-Object -First 1
    Assert-Condition ($null -ne $matching) "Applied ruleset '$($LocalRuleset.name)' was not found on GitHub."

    $appliedRuleset = Invoke-GhJson @('api', "repos/$RepositoryName/rulesets/$($matching.id)")
    Assert-Condition ($appliedRuleset.enforcement -eq 'active') 'Applied ruleset is not active.'
    Assert-Condition (@($appliedRuleset.conditions.ref_name.include) -contains 'refs/heads/main') 'Applied ruleset does not target refs/heads/main.'

    $appliedStatusRule = @($appliedRuleset.rules | Where-Object { $_.type -eq 'required_status_checks' }) | Select-Object -First 1
    Assert-Condition ($null -ne $appliedStatusRule) 'Applied ruleset is missing required_status_checks.'
    Assert-Condition ([bool]$appliedStatusRule.parameters.strict_required_status_checks_policy) 'Applied required status checks are not strict.'
    $appliedChecks = @($appliedStatusRule.parameters.required_status_checks | ForEach-Object { $_.context })
    foreach ($check in $expectedChecks) {
        Assert-Condition ($appliedChecks -contains $check) "Applied ruleset is missing required status check: $check"
    }

    $pullRequestRule = @($appliedRuleset.rules | Where-Object { $_.type -eq 'pull_request' }) | Select-Object -First 1
    Assert-Condition ($null -ne $pullRequestRule) 'Applied ruleset does not require pull requests.'
    Assert-Condition (@($appliedRuleset.rules | Where-Object { $_.type -eq 'non_fast_forward' }).Count -gt 0) 'Applied ruleset does not block force pushes.'
    Assert-Condition (@($appliedRuleset.rules | Where-Object { $_.type -eq 'deletion' }).Count -gt 0) 'Applied ruleset does not block branch deletion.'

    Write-Host 'GitHub applied protection is active and matches the checked-in contract.'
}

Assert-Condition (Test-Path -LiteralPath $rulesetPath) "Ruleset file not found: $rulesetPath"
$ruleset = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json
Assert-Condition ($ruleset.name -eq 'main-required-checks') 'Unexpected ruleset name.'
Assert-Condition ($ruleset.target -eq 'branch') 'Ruleset target must be branch.'
Assert-Condition ($ruleset.enforcement -eq 'active') 'Ruleset enforcement must be active.'
Assert-Condition (@($ruleset.conditions.ref_name.include) -contains 'refs/heads/main') 'Ruleset must target refs/heads/main.'

$statusRule = @($ruleset.rules | Where-Object { $_.type -eq 'required_status_checks' }) | Select-Object -First 1
Assert-Condition ($null -ne $statusRule) 'Ruleset is missing required_status_checks.'
Assert-Condition ([bool]$statusRule.parameters.strict_required_status_checks_policy) 'Required status checks must use strict mode.'

$configuredChecks = @($statusRule.parameters.required_status_checks | ForEach-Object { $_.context })
foreach ($check in $expectedChecks) {
    Assert-Condition ($configuredChecks -contains $check) "Ruleset is missing required status check: $check"
}

if ($ValidateConfigOnly) {
    Write-Host 'Checked-in repository ruleset configuration is valid. GitHub applied protection was not checked.'
    exit 0
}

$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
Assert-Condition ($null -ne $ghCommand) 'GitHub CLI (gh) is required.'

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated. Run gh auth login first.'
}

if ($ValidateAppliedProtection) {
    Assert-AppliedProtection -RepositoryName $Repository -LocalRuleset $ruleset
    exit 0
}

$repositoryState = Invoke-GhJson @('api', "repos/$Repository")
Assert-Condition ($repositoryState.full_name -eq $Repository) "Authenticated account cannot access $Repository."

$null = Invoke-GhJson @('api', "repos/$Repository/branches/main")

if ($repositoryState.default_branch -ne 'main') {
    Write-Host "Changing default branch from $($repositoryState.default_branch) to main..."
    $repositoryState = Invoke-GhJson @(
        'api', '--method', 'PATCH', "repos/$Repository", '-f', 'default_branch=main'
    )
} else {
    Write-Host 'Default branch is already main.'
}

$rulesets = @(Invoke-GhJson @('api', "repos/$Repository/rulesets") 2>$null)
if ($null -eq $rulesets -or $rulesets.Count -eq 0 -or $rulesets[0].GetType().Name -eq 'String') {
    throw 'Rulesets API is unavailable. Repository protection was not applied; do not treat local JSON validation as protection success.'
}

$existingRuleset = $rulesets |
    Where-Object { $_.name -eq $ruleset.name -and $_.target -eq 'branch' } |
    Select-Object -First 1

if ($null -eq $existingRuleset) {
    Write-Host "Creating active ruleset '$($ruleset.name)'..."
    $appliedRuleset = Invoke-GhJson @(
        'api', '--method', 'POST', "repos/$Repository/rulesets", '--input', $rulesetPath
    )
} else {
    Write-Host "Updating active ruleset '$($ruleset.name)' (id: $($existingRuleset.id))..."
    $appliedRuleset = Invoke-GhJson @(
        'api', '--method', 'PUT', "repos/$Repository/rulesets/$($existingRuleset.id)", '--input', $rulesetPath
    )
}

Assert-Condition ($appliedRuleset.enforcement -eq 'active') 'Ruleset enforcement verification failed.'

$envResponse = Invoke-GhJson @(
    'api', '--method', 'PUT', "repos/$Repository/environments/production",
    '-f', 'deployment_branch_policy.protected_branches=false',
    '-f', 'deployment_branch_policy.custom_branch_policies=true'
)
Write-Host "Environment '$($envResponse.name)' ready."

$branchPolicyAdded = Invoke-GhJsonAllowMissing @(
    'api', '--method', 'POST',
    "repos/$Repository/environments/production/deployment-branch-policies",
    '-f', 'name=main'
)
if ($branchPolicyAdded) {
    Write-Host 'Deployment branch policy: main only.'
} else {
    Write-Host 'Deployment branch policy for main already exists.'
}

Assert-AppliedProtection -RepositoryName $Repository -LocalRuleset $ruleset

Write-Host ''
Write-Host "Configured repository: $Repository"
Write-Host 'Default branch: main'
Write-Host "Ruleset '$($ruleset.name)': active and verified on GitHub"
Write-Host 'Production environment: configured (main branch only)'
Write-Host 'Required checks:'
$expectedChecks | ForEach-Object { Write-Host "  - $_" }
