param(
    [string]$ServerUrl = 'http://127.0.0.1:5555',
    [string]$Flutter = 'C:\flutter\flutter\bin\flutter.bat'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$mobileRoot = Join-Path $projectRoot 'inventory_manager_flutter'
$branding = Invoke-RestMethod "$($ServerUrl.TrimEnd('/'))/api/branding"
if ($branding.companyLogo -notmatch '^data:image/(png|jpeg|gif);base64,(.+)$') {
    throw 'Save a company logo in Company Details & Branding before building the branded APK.'
}
Add-Type -AssemblyName System.Drawing
$imageBytes = [Convert]::FromBase64String($Matches[2])
$stream = [IO.MemoryStream]::new($imageBytes)
$sourceImage = [Drawing.Image]::FromStream($stream)
try {
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
Push-Location $mobileRoot
try {
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed; existing downloadable APK was not replaced.' }
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination (Join-Path $projectRoot 'server/public/download/app-release.apk')
} finally { Pop-Location }
Write-Output 'Branded APK built and available from /download/app-release.apk. Install it as an update to retain app data.'
