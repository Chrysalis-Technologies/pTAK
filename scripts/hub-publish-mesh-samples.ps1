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

function Publish-MqttJson {
  param(
    [string]$Topic,
    [string]$Payload,
    [string]$BrokerHost,
    [string]$BrokerPort,
    [string]$CaFile,
    [string]$Username,
    [string]$Password
  )

  & docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client `
    mosquitto_pub -h $BrokerHost -p $BrokerPort --cafile $CaFile -u $Username -P $Password -q 1 -r -t $Topic -m $Payload

  if ($LASTEXITCODE -ne 0) {
    throw "mosquitto_pub failed for topic $Topic"
  }
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

$telemetryTopic = "hub/mesh/$NodeId/telemetry"
$linkTopic = "hub/mesh/$NodeId/link"
$positionTopic = "hub/mesh/$NodeId/position"

$telemetry = [ordered]@{
  v            = 1
  contract     = "hub.mesh.v1"
  node_id      = $NodeId
  uid          = "meshtastic-$NodeId"
  callsign     = $NodeId
  ts           = "2026-02-24T12:00:00Z"
  last_seen    = "2026-02-24T12:00:00Z"
  source_topic = "meshtastic/$NodeId/telemetry"
  temperature_c = [double]12.3
  humidity_pct  = [double]58.1
  pressure_hpa  = [double]1016.4
}

$link = [ordered]@{
  v                        = 1
  contract                 = "hub.mesh.v1"
  node_id                  = $NodeId
  uid                      = "meshtastic-$NodeId"
  callsign                 = $NodeId
  ts                       = "2026-02-24T12:00:00Z"
  last_seen                = "2026-02-24T12:00:00Z"
  source_topic             = "meshtastic/$NodeId/telemetry"
  status                   = "online"
  rssi_dbm                 = [double]-105
  snr_db                   = [double]7.5
  hops_away                = 1
  hop_limit                = 3
  channel_utilization_pct  = [double]16.2
  air_util_tx_pct          = [double]2.4
}

$position = [ordered]@{
  v                    = 1
  contract             = "hub.mesh.v1"
  node_id              = $NodeId
  uid                  = "meshtastic-$NodeId"
  callsign             = $NodeId
  ts                   = "2026-02-24T12:00:05Z"
  last_seen            = "2026-02-24T12:00:05Z"
  source_topic         = "meshtastic/$NodeId/position"
  lat                  = [double]43.04531
  lon                  = [double]-76.12270
  speed_mps            = [double]3.4
  course_deg           = [double]182.0
  position_from_cache  = $false
}

Publish-MqttJson -Topic $telemetryTopic -Payload ($telemetry | ConvertTo-Json -Compress) -BrokerHost $brokerHost -BrokerPort $brokerPort -CaFile $mqttCa -Username $mqttUser -Password $mqttPass
Publish-MqttJson -Topic $linkTopic -Payload ($link | ConvertTo-Json -Compress) -BrokerHost $brokerHost -BrokerPort $brokerPort -CaFile $mqttCa -Username $mqttUser -Password $mqttPass
Publish-MqttJson -Topic $positionTopic -Payload ($position | ConvertTo-Json -Compress) -BrokerHost $brokerHost -BrokerPort $brokerPort -CaFile $mqttCa -Username $mqttUser -Password $mqttPass

Write-Host "Published retained QoS1 contract samples for node $NodeId." -ForegroundColor Green
