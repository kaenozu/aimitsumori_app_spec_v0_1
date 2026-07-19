[CmdletBinding()]
param(
    [string]$Artifact = 'build/app/outputs/flutter-apk/app-release.apk',
    [string]$ExpectedSignerSha256,
    [string]$ExpectedAdMobAppId
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Artifact -PathType Leaf)) {
    throw "Android artifact was not found: $Artifact"
}

function Find-AndroidTool([string]$ToolName) {
    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        'C:\Android\sdk'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($sdkRoot in $sdkRoots) {
        $tool = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Filter $ToolName -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($null -ne $tool) { return $tool.FullName }
    }
    throw "$ToolName was not found under an Android SDK build-tools directory."
}

$aapt2 = Find-AndroidTool 'aapt2.exe'
$apksigner = Find-AndroidTool 'apksigner.bat'

$badging = (& $aapt2 dump badging $Artifact 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "aapt2 could not read the Android artifact.`n$badging"
}

$packageMatch = [regex]::Match(
    $badging,
    "package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'"
)
if (-not $packageMatch.Success) {
    throw 'Could not read package name and version from the Android artifact.'
}

$packageName = $packageMatch.Groups[1].Value
$versionCode = $packageMatch.Groups[2].Value
$versionName = $packageMatch.Groups[3].Value
if ($packageName -ne 'com.kaenozu.aimitsumori_app') {
    throw "Unexpected Android applicationId: $packageName"
}

$googleTestIds = @(
    'ca-app-pub-3940256099942544~3347511713',
    'ca-app-pub-3940256099942544/6300978111',
    'ca-app-pub-3940256099942544/5224354917'
)
$manifest = (& $aapt2 dump xmltree --file AndroidManifest.xml $Artifact 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "aapt2 could not read the AndroidManifest from the artifact.`n$manifest"
}
foreach ($testId in $googleTestIds) {
    if ($manifest.Contains($testId)) {
        throw "Google test AdMob ID was found in the Android artifact: $testId"
    }
}
if ($manifest -notmatch 'com\.google\.android\.gms\.ads\.APPLICATION_ID') {
    throw 'AdMob application ID metadata was not found in the Android artifact.'
}
if ($manifest -notmatch 'ca-app-pub-\d{16}~\d{10}') {
    throw 'A valid AdMob application ID was not found in the Android artifact.'
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedAdMobAppId) -and
    -not $manifest.Contains($ExpectedAdMobAppId)) {
    throw 'APK AdMob application ID does not match the expected production value.'
}

$signatureOutput = (& $apksigner verify --verbose --print-certs $Artifact 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $signatureOutput -notmatch 'Verified using v2 scheme \(APK Signature Scheme v2\): true') {
    throw "APK signature verification failed.`n$signatureOutput"
}
if ($signatureOutput -notmatch 'Number of signers: 1') {
    throw "APK must have exactly one signer.`n$signatureOutput"
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedSignerSha256)) {
    $normalizedExpected = $ExpectedSignerSha256.Replace(':', '').ToUpperInvariant()
    $normalizedActual = [regex]::Match($signatureOutput, 'Signer #1 certificate SHA-256 digest: ([0-9A-F:]+)').Groups[1].Value.Replace(':', '').ToUpperInvariant()
    if ($normalizedActual -ne $normalizedExpected) {
        throw 'APK signer digest does not match the expected production signer.'
    }
}

Write-Output "Android Release APK audit passed: $packageName $versionName (versionCode $versionCode)"
Write-Output 'APK signature: v2 verified, one signer'
