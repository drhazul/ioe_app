param(
  [int]$Port = 8088,
  [string]$ApiBaseUrlWeb = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
$webOut = Join-Path $projectRoot 'build\web'

$buildScript = Join-Path $scriptDir 'build-web-release-safe.ps1'
if ($ApiBaseUrlWeb.Trim().Length -gt 0) {
  & $buildScript -ApiBaseUrlWeb $ApiBaseUrlWeb
}
else {
  & $buildScript
}

if (-not (Test-Path -LiteralPath $webOut)) {
  throw "No existe build/web en $webOut"
}

Push-Location $webOut
try {
  Write-Host "Sirviendo release local en http://127.0.0.1:$Port"
  Write-Host 'Presiona Ctrl+C para detener.'
  python -m http.server $Port
}
finally {
  Pop-Location
}
