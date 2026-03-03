$ErrorActionPreference = "Stop"

$repoRoot = Join-Path $PSScriptRoot ".."
$repoRoot = (Resolve-Path $repoRoot).Path
$caSourcePath = Join-Path $repoRoot "mqtt-certs/ca.crt"

$privateIPv4Pattern = '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'
$excludeAliasPattern = '(?i)(loopback|vethernet|docker|wsl|hyper-v|teredo|isatap|default switch)'

$allCandidates = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.IPAddress -match $privateIPv4Pattern -and
  $_.IPAddress -notmatch '^127\.' -and
  $_.IPAddress -notmatch '^169\.254\.' -and
  $_.InterfaceAlias -notmatch $excludeAliasPattern
}

if (-not $allCandidates) {
  throw "No RFC1918 LAN IPv4 address found. Check host networking and rerun."
}

$defaultRoute = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" |
  Sort-Object -Property RouteMetric, ifMetric |
  Select-Object -First 1

$selectedIp = $null
if ($defaultRoute) {
  $selectedIp = $allCandidates |
    Where-Object { $_.InterfaceIndex -eq $defaultRoute.InterfaceIndex } |
    Sort-Object -Property SkipAsSource |
    Select-Object -First 1
}

if (-not $selectedIp) {
  $selectedIp = $allCandidates |
    Sort-Object -Property InterfaceIndex, SkipAsSource |
    Select-Object -First 1
}

$phase1Endpoint = "mqtts://$($selectedIp.IPAddress):8883"
$phase2Endpoint = "mqtts://marzocchi-tech.ewe-mulley.ts.net:8883"

Write-Host "Hub MQTT Endpoints"
Write-Host "------------------"
Write-Host ("Phase 1 LAN:      {0}" -f $phase1Endpoint)
Write-Host ("Phase 2 Tailscale:{0}" -f $phase2Endpoint)
Write-Host ""
Write-Host "HAOS CA path:     /config/ssl/mqtt/ca.crt"
Write-Host ("Hub CA source:    {0}" -f $caSourcePath)
Write-Host ""
Write-Host "MQTT username:    farm"
Write-Host "MQTT password:    8a64691f37634abdb084a3a6143a4b8b"
