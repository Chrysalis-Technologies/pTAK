param(
  [string]$Site = $(if ($env:SITE) { $env:SITE } else { "farmstead" })
)

$envFile = Join-Path $PSScriptRoot "..\.env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $parts = $line -split "=", 2
    if ($parts.Count -ne 2) { return }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"')
    if (-not (Get-Item -Path "Env:$key" -ErrorAction SilentlyContinue)) {
      Set-Item -Path "Env:$key" -Value $value
    }
  }
}

$mqttPort = if ($env:MQTT_PORT) { $env:MQTT_PORT } else { "8883" }
$mqttUser = $env:MQTT_USERNAME
$mqttPass = $env:MQTT_PASSWORD
$mqttTls = ($env:MQTT_TLS -eq "true")

if (-not $mqttUser -or -not $mqttPass) {
  throw "MQTT_USERNAME and MQTT_PASSWORD must be set in .env or environment."
}

$tsTele = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$tsEvt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$tele = @{
  v = 1
  id = [guid]::NewGuid().ToString()
  ts = $tsTele
  site = $Site
  class = "tele"
  asset = @{ id = "tractor-01"; kind = "tractor"; name = "Blue 6410" }
  src = @{ system = "meshtastic"; id = "demo" }
  loc = @{ lat = 43.04523; lon = -76.12288; hae_m = 146.2; ce_m = 4.5; le_m = 8.0 }
  ttl_s = 120
  data = @{ stream = "position"; metrics = @{ battery_pct = 87; rssi_dbm = -105 } }
}

$evt = @{
  v = 1
  id = [guid]::NewGuid().ToString()
  ts = $tsEvt
  site = $Site
  class = "evt"
  asset = @{ id = "gate-east"; kind = "gate"; name = "East Gate" }
  src = @{ system = "ha"; id = "demo" }
  loc = @{ lat = 43.04601; lon = -76.12111; hae_m = 145.0; ce_m = 6.0; le_m = 12.0 }
  ttl_s = 600
  data = @{ event_type = "gate.open"; severity = "warning"; message = "After-hours gate open" }
}

$teleJson = $tele | ConvertTo-Json -Depth 8 -Compress
$evtJson = $evt | ConvertTo-Json -Depth 8 -Compress

$commonArgs = @("compose", "exec", "-T", "mqtt-broker", "mosquitto_pub", "-p", $mqttPort, "-u", $mqttUser, "-P", $mqttPass)
if ($mqttTls) {
  $commonArgs += @("--cafile", "/mosquitto/certs/ca.crt")
}

Write-Host "Publishing telemetry to farm/$Site/tele/tractor-01/position"
& docker @commonArgs -t "farm/$Site/tele/tractor-01/position" -m $teleJson

Write-Host "Publishing event to farm/$Site/evt/gate-east/gate.open"
& docker @commonArgs -t "farm/$Site/evt/gate-east/gate.open" -m $evtJson