$ErrorActionPreference = "Stop"
$hostName = "localhost"
$apiPort  = 19023
$ports    = 19023,8087,8089,8080,8443,9000
$timeout  = [TimeSpan]::FromSeconds(120)
$start    = Get-Date

Write-Host "Waiting for FTS API on $hostName:$apiPort ..."
do {
  $ok = (Test-NetConnection -ComputerName $hostName -Port $apiPort -WarningAction SilentlyContinue).TcpTestSucceeded
  if (-not $ok) { Start-Sleep -Seconds 2 }
} until ($ok -or (Get-Date) - $start -ge $timeout)

if (-not $ok) { Write-Error "FTS API didn't open within $($timeout.TotalSeconds)s"; exit 1 }

try {
  $r = Invoke-WebRequest -UseBasicParsing -Uri "http://$hostName:$apiPort" -Method GET -TimeoutSec 5
  Write-Host "FTS API HTTP status: $($r.StatusCode)"
} catch {
  Write-Host "FTS API responded (likely 401/403). Connectivity OK: $($_.Exception.Message)"
}

foreach ($p in $ports) {
  $portOk = (Test-NetConnection -ComputerName $hostName -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded
  Write-Host ("Port {0}: {1}" -f $p, ($(if ($portOk) { "OPEN" } else { "closed" })))
}
