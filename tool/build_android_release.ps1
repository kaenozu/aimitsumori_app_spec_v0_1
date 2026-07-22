[CmdletBinding()]
param(
    [ValidateSet('apk', 'appbundle')]
    [string]$Artifact = 'appbundle'
)

$ErrorActionPreference = 'Stop'

$requiredVariables = @(
    'ADMOB_APP_ID',
    'ADMOB_ANDROID_BANNER_ID',
    'ADMOB_ANDROID_REWARDED_ID',
    'REMOVE_ADS_PRODUCT_ID'
)
foreach ($name in $requiredVariables) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$name is required for an Android release build."
    }
}

if ($env:ADMOB_APP_ID -notmatch '^ca-app-pub-\d{16}~\d{10}$') {
    throw 'ADMOB_APP_ID must be a valid AdMob application ID.'
}
$googleTestIds = @(
    'ca-app-pub-3940256099942544~3347511713',
    'ca-app-pub-3940256099942544/6300978111',
    'ca-app-pub-3940256099942544/5224354917'
)
if ($env:ADMOB_APP_ID -in $googleTestIds) {
    throw 'ADMOB_APP_ID must not use Google''s test application ID in release builds.'
}
foreach ($name in @('ADMOB_ANDROID_BANNER_ID', 'ADMOB_ANDROID_REWARDED_ID')) {
    if ([Environment]::GetEnvironmentVariable($name) -notmatch '^ca-app-pub-\d{16}/\d{10}$') {
        throw "$name must be a valid AdMob ad unit ID."
    }
    if ([Environment]::GetEnvironmentVariable($name) -in $googleTestIds) {
        throw "$name must not use Google''s test ad unit ID in release builds."
    }
}
if ($env:REMOVE_ADS_PRODUCT_ID -notmatch '^[A-Za-z0-9._-]{1,100}$') {
    throw 'REMOVE_ADS_PRODUCT_ID must be a valid Google Play product ID.'
}

$buildTarget = $Artifact
$dartDefines = @(
    "ADMOB_APP_ID=$($env:ADMOB_APP_ID)",
    "ADMOB_ANDROID_BANNER_ID=$($env:ADMOB_ANDROID_BANNER_ID)",
    "ADMOB_ANDROID_REWARDED_ID=$($env:ADMOB_ANDROID_REWARDED_ID)",
    "REMOVE_ADS_PRODUCT_ID=$($env:REMOVE_ADS_PRODUCT_ID)"
)

& flutter build $buildTarget --release --no-pub @(
    foreach ($define in $dartDefines) { "--dart-define=$define" }
)
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
