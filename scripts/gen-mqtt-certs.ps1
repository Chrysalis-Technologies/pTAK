param(
  [string]$AltNames = "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot "..\mqtt-certs"
$serverCrt = Join-Path $certDir "server.crt"
$tool = Join-Path $PSScriptRoot "ptak-ca.ps1"

if (-not (Test-Path -LiteralPath $tool)) {
  throw "Missing PKI wrapper: $tool"
}

if (-not $Force -and (Test-Path -LiteralPath $serverCrt)) {
  throw "Existing MQTT certs found. Re-run with -Force to overwrite."
}

$args = @(
  "provision",
  "--skip-fts",
  "--skip-wintak",
  "--mqtt-san", $AltNames
)

& $tool @args
exit $LASTEXITCODE
