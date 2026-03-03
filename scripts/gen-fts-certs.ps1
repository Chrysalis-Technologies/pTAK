param(
  [string]$ClientCommonName = "WinTAK-Paul",
  [string]$P12Password,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot "..\fts-certs"
$tool = Join-Path $PSScriptRoot "ptak-ca.ps1"

if (-not (Test-Path -LiteralPath $tool)) {
  throw "Missing PKI wrapper: $tool"
}

if (-not $Force) {
  $expected = @(
    (Join-Path $certDir "ca.crt"),
    (Join-Path $certDir "server.crt"),
    (Join-Path $certDir "server.key"),
    (Join-Path $certDir "$ClientCommonName.p12")
  )

  $allPresent = $true
  foreach ($path in $expected) {
    if (-not (Test-Path -LiteralPath $path)) {
      $allPresent = $false
      break
    }
  }

  if ($allPresent) {
    Write-Host "Existing FTS cert artifacts already present in $certDir. Re-run with -Force to rotate certs."
    exit 0
  }
}

$args = @(
  "provision",
  "--skip-mqtt",
  "--wintak-client-name", $ClientCommonName,
  "--wintak-client-cn", $ClientCommonName
)

if ($P12Password) {
  $args += @("--wintak-p12-password", $P12Password)
}

& $tool @args
exit $LASTEXITCODE
