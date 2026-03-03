param(
  [Parameter(Mandatory = $false)]
  [string]$NodeId = "WinTAK-Paul"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
  param([string]$Path)

  $map = @{}
  foreach ($line in Get-Content $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) {
      continue
    }
    $idx = $trimmed.IndexOf("=")
    if ($idx -lt 0) {
      continue
    }
    $key = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    if ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    $map[$key] = $value
  }
  return $map
}

$repoRoot = Join-Path $PSScriptRoot ".."
Set-Location $repoRoot

$envFile = ".env.hub"
if (-not (Test-Path $envFile)) {
  throw ".env.hub not found. Run: pwsh ./scripts/hub-up.ps1"
}

$envVars = Read-DotEnv -Path $envFile

$brokerHost = if ($envVars.ContainsKey("MQTT_BROKER_HOST")) { $envVars["MQTT_BROKER_HOST"] } else { "mosquitto" }
$brokerPort = if ($envVars.ContainsKey("MQTT_BROKER_PORT")) { $envVars["MQTT_BROKER_PORT"] } else { "8883" }
$mqttUser = $envVars["MQTT_USERNAME"]
$mqttPass = $envVars["MQTT_PASSWORD"]
$mqttCa = if ($envVars.ContainsKey("MQTT_TLS_CA")) { $envVars["MQTT_TLS_CA"] } else { "/mqtt-certs/ca.crt" }

if (-not $mqttUser -or -not $mqttPass) {
  throw "MQTT_USERNAME and MQTT_PASSWORD must be set in .env.hub"
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$payload = [ordered]@{
  timestamp     = $timestamp
  callsign      = $NodeId
  temperature_c = [double]12.3
  humidity_pct  = [double]58.1
  pressure_hpa  = [double]1016.4
  lat           = [double][Math]::Round([double]43.04523, 6)
  lon           = [double][Math]::Round([double]-76.12288, 6)
}

$json = $payload | ConvertTo-Json -Compress
$topic = "meshtastic/$NodeId/telemetry"

Write-Host "Publishing telemetry to $topic" -ForegroundColor Cyan

& docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client `
  mosquitto_pub -h $brokerHost -p $brokerPort --cafile $mqttCa -u $mqttUser -P $mqttPass -q 1 -t $topic -m $json

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
  Write-Error "mosquitto_pub failed for topic $topic"
  exit $exitCode
}

Write-Host "Published telemetry payload." -ForegroundColor Green
