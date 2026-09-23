param(
    [string]$ServerUrl = 'http://127.0.0.1:3000',
    [string]$LogoPath = '',
    [switch]$IconsOnly,
    [string]$Flutter = 'C:\flutter\flutter\bin\flutter.bat'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$mobileRoot = Join-Path $projectRoot 'inventory_manager_flutter'
$savedLogo = Join-Path $mobileRoot 'assets/images/launcher_logo.png'
Add-Type -AssemblyName System.Drawing
if ($LogoPath) {
    $imageBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $LogoPath))
} else {
    $branding = Invoke-RestMethod "$($ServerUrl.TrimEnd('/'))/api/branding"
    if ($branding.companyLogo -match '^data:image/(png|jpeg|gif);base64,(.+)$') {
        $imageBytes = [Convert]::FromBase64String($Matches[2])
    } elseif (Test-Path -LiteralPath $savedLogo) {
        $imageBytes = [IO.File]::ReadAllBytes($savedLogo)
    } else {
        throw 'Save the uploaded application logo in Settings, or pass -LogoPath. No default icon will be substituted.'
    }
}
$stream = [IO.MemoryStream]::new($imageBytes)
$sourceImage = [Drawing.Image]::FromStream($stream)
try {
    $sourceImage.Save($savedLogo, [Drawing.Imaging.ImageFormat]::Png)
    foreach ($entry in @{ mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192 }.GetEnumerator()) {
        $size = $entry.Value
        $bitmap = [Drawing.Bitmap]::new($size, $size)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::White)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $scale = ($size * 0.8) / [Math]::Max($sourceImage.Width, $sourceImage.Height)
            $width = [int]($sourceImage.Width * $scale)
            $height = [int]($sourceImage.Height * $scale)
            $graphics.DrawImage($sourceImage, [int](($size-$width)/2), [int](($size-$height)/2), $width, $height)
            $iconPath = Join-Path $mobileRoot "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png"
            $bitmap.Save($iconPath, [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $sourceImage.Dispose(); $stream.Dispose() }
if ($IconsOnly) { Write-Output 'Launcher icon source and all Android icon densities updated.'; return }
$socketDir = Join-Path $projectRoot '.build-tools/java-temp'
New-Item -ItemType Directory -Force -Path $socketDir | Out-Null
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' -Djdk.net.unixdomain.tmpdir="' + $socketDir + '"').Trim()
Push-Location $mobileRoot
try {
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed; existing downloadable APK was not replaced.' }
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination (Join-Path $projectRoot 'server/public/download/app-release.apk')
} finally { Pop-Location; $env:JAVA_TOOL_OPTIONS = $previousJavaOptions }
Write-Output 'Branded APK built and available from /download/app-release.apk. Install it as an update to retain app data.'
