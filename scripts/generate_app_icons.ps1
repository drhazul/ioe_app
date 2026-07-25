Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'assets\ioe_logo.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)

function Save-IconPng {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][int]$Size
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Size, $Size
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($source, 0, 0, $Size, $Size)
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

$pngTargets = @{
  'web\favicon.png' = 64
  'web\icons\Icon-192.png' = 192
  'web\icons\Icon-512.png' = 512
  'web\icons\Icon-maskable-192.png' = 192
  'web\icons\Icon-maskable-512.png' = 512
  'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
  'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
  'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
  'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
  'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png' = 16
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png' = 32
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png' = 64
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png' = 128
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png' = 256
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png' = 512
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png' = 1024
}

foreach ($relativePath in $pngTargets.Keys) {
  Save-IconPng (Join-Path $projectRoot $relativePath) $pngTargets[$relativePath]
}

$temporaryPng = Join-Path $env:TEMP 'ioe_app_icon_256.png'
Save-IconPng $temporaryPng 256
$pngBytes = [System.IO.File]::ReadAllBytes($temporaryPng)
$stream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter -ArgumentList $stream
try {
  $writer.Write([UInt16]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]1)
  $writer.Write([Byte]0)
  $writer.Write([Byte]0)
  $writer.Write([Byte]0)
  $writer.Write([Byte]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]32)
  $writer.Write([UInt32]$pngBytes.Length)
  $writer.Write([UInt32]22)
  $writer.Write($pngBytes)
  [System.IO.File]::WriteAllBytes(
    (Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'),
    $stream.ToArray()
  )
} finally {
  $writer.Dispose()
  $stream.Dispose()
  Remove-Item -LiteralPath $temporaryPng -Force -ErrorAction SilentlyContinue
  $source.Dispose()
}
