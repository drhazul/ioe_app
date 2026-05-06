param(
  [string]$ApiBaseUrlWeb = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-FlutterCommand {
  if ($env:FLUTTER_BIN -and (Test-Path -LiteralPath $env:FLUTTER_BIN)) {
    return $env:FLUTTER_BIN
  }

  $candidates = @(
    'flutter',
    'C:\Users\PCDESARROLLO\SDK_flutter\flutter\bin\flutter.bat'
  )

  foreach ($candidate in $candidates) {
    try {
      $cmd = Get-Command $candidate -ErrorAction Stop
      return $cmd.Source
    }
    catch {
      # try next
    }
  }

  throw 'No se encontró Flutter. Define FLUTTER_BIN con ruta a flutter.bat.'
}

$flutterCmd = Resolve-FlutterCommand

Write-Host '== IOE web release build =='
$buildArgs = @('build', 'web', '--release', '--pwa-strategy=none')
if ($ApiBaseUrlWeb.Trim().Length -gt 0) {
  $buildArgs += "--dart-define=API_BASE_URL_WEB=$ApiBaseUrlWeb"
  Write-Host "API_BASE_URL_WEB: $ApiBaseUrlWeb"
}

& $flutterCmd @buildArgs

$webOut = Join-Path $PSScriptRoot '..\build\web'
$webOut = [System.IO.Path]::GetFullPath($webOut)

if (-not (Test-Path -LiteralPath $webOut)) {
  throw "No existe salida de build: $webOut"
}

$mustExist = @(
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js'
)

foreach ($file in $mustExist) {
  $path = Join-Path $webOut $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Falta artefacto requerido de release: $file"
  }
}

$debugArtifacts = @(
  'ddc_module_loader.js',
  'dart_sdk.js',
  'main_module.bootstrap.js',
  'stack_trace_mapper.js'
)

$foundDebugArtifacts = @()
foreach ($artifact in $debugArtifacts) {
  $path = Join-Path $webOut $artifact
  if (Test-Path -LiteralPath $path) {
    $foundDebugArtifacts += $artifact
  }
}

if ($foundDebugArtifacts.Count -gt 0) {
  throw ("Build parece debug/profile (artefactos DDC detectados): " + ($foundDebugArtifacts -join ', '))
}

Write-Host 'OK: build web release validado sin artefactos DDC.'
Write-Host "Salida: $webOut"
