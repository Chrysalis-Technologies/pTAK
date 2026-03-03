$ErrorActionPreference = "Stop"

$repoRoot = Join-Path $PSScriptRoot ".."
Set-Location $repoRoot

$envHubPath = ".env.hub"
$envTemplatePath = ".env.hub.example"

if (-not (Test-Path $envHubPath)) {
  if (-not (Test-Path $envTemplatePath)) {
    throw ".env.hub.example not found. Cannot auto-create .env.hub."
  }

  Copy-Item $envTemplatePath $envHubPath
  Write-Host "Created .env.hub from .env.hub.example." -ForegroundColor Yellow
  Write-Host "Update TAK_COT_UDP_HOST if WinTAK/TAK receiver is on another machine." -ForegroundColor Yellow
  Write-Host "If WinTAK is on the Windows host and hub runs in Docker, set TAK_COT_UDP_HOST=host.docker.internal." -ForegroundColor Yellow
}

$requiredFiles = @(
  "mqtt-certs/ca.crt",
  "mqtt-certs/server.crt",
  "mqtt-certs/server.key",
  "secrets/mosquitto.passwd"
)

$missing = @()
foreach ($path in $requiredFiles) {
  if (-not (Test-Path $path)) {
    $missing += $path
  }
}

if ($missing.Count -gt 0) {
  Write-Host "Hub TLS/auth preflight failed. Missing required files:" -ForegroundColor Red
  foreach ($path in $missing) {
    Write-Host "  - $path" -ForegroundColor Red
  }
  Write-Host ""
  Write-Host "Remediation commands:" -ForegroundColor Yellow
  Write-Host '  pwsh ./scripts/gen-mqtt-certs.ps1 -AltNames "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net" -Force' -ForegroundColor Yellow
  Write-Host "  pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm -Force" -ForegroundColor Yellow
  throw "Missing MQTT TLS/auth files. Resolve and rerun."
}

$passwdPath = "secrets/mosquitto.passwd"
$passwdIssues = @()

if (Test-Path $passwdPath) {
  $passwdItem = Get-Item $passwdPath
  if ($passwdItem.PSIsContainer) {
    $passwdIssues += "$passwdPath exists but is a directory. It must be a file."
  } elseif ($passwdItem.Length -le 0) {
    $passwdIssues += "$passwdPath is empty. It must contain at least one credential line."
  } else {
    try {
      $nonEmptyLines = @(Get-Content $passwdPath -ErrorAction Stop | Where-Object { $_.Trim().Length -gt 0 }).Count
      if ($nonEmptyLines -lt 1) {
        $passwdIssues += "$passwdPath has no non-empty credential lines."
      }
    } catch {
      $passwdIssues += "$passwdPath could not be read. Check file permissions."
    }
  }
}

if ($passwdIssues.Count -gt 0) {
  Write-Host "Hub TLS/auth preflight failed for secrets/mosquitto.passwd:" -ForegroundColor Red
  foreach ($issue in $passwdIssues) {
    Write-Host "  - $issue" -ForegroundColor Red
  }
  Write-Host "  pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm -Force" -ForegroundColor Yellow
  throw "Invalid mosquitto password file. Resolve and rerun."
}

Write-Host "Optional firewall helper (run in elevated PowerShell on Windows host if LAN clients cannot connect):" -ForegroundColor Yellow
Write-Host '  New-NetFirewallRule -DisplayName "Hub Mosquitto 8883" -Direction Inbound -Protocol TCP -LocalPort 8883 -Action Allow' -ForegroundColor Yellow

docker compose --env-file .env.hub -f docker-compose.hub.yml up -d --build
