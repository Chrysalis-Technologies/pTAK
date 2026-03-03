#!/usr/bin/env pwsh
param(
  [string]$WinTakPath = ${env:WINTAK_EXE} ? ${env:WINTAK_EXE} : "C:\Program Files\WinTAK\WinTAK.exe",
  [string]$ClientCommonName = ${env:WINTAK_CLIENT_CN} ? ${env:WINTAK_CLIENT_CN} : "WinTAK-Paul",
  [string]$ServerHost = ${env:FTS_HOST} ? ${env:FTS_HOST} : "127.0.0.1",
  [int]$ServerPort = ${env:FTS_PORT} ? [int]${env:FTS_PORT} : 8089,
  [int]$WaitSeconds = ${env:FTS_WAIT_SECONDS} ? [int]${env:FTS_WAIT_SECONDS} : 60,
  [switch]$RestartWinTak
)
$ErrorActionPreference = "Stop"

function Resolve-FirstExistingPath {
  param(
    [string[]]$Candidates,
    [string]$Description
  )
  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  if ($Description) {
    Write-Warning "$Description not found. Checked: $($Candidates -join ', ')"
  }
  return $null
}

function Ensure-PemCopies {
  param([string]$CertDir)
  $restartNeeded = $false

  $caCrt = Join-Path $CertDir "ca.crt"
  $serverCrt = Join-Path $CertDir "server.crt"
  $caPem = Join-Path $CertDir "ca.pem"
  $serverPem = Join-Path $CertDir "server.pem"

  if (-not (Test-Path -LiteralPath $caCrt)) {
    throw "Missing $caCrt. Run pwsh ./scripts/gen-fts-certs.ps1 -ClientCommonName $ClientCommonName"
  }
  if (-not (Test-Path -LiteralPath $serverCrt)) {
    throw "Missing $serverCrt. Run pwsh ./scripts/gen-fts-certs.ps1 -ClientCommonName $ClientCommonName"
  }

  if (-not (Test-Path -LiteralPath $caPem)) {
    Copy-Item -LiteralPath $caCrt -Destination $caPem -Force
    $restartNeeded = $true
  }
  if (-not (Test-Path -LiteralPath $serverPem)) {
    Copy-Item -LiteralPath $serverCrt -Destination $serverPem -Force
    $restartNeeded = $true
  }

  return $restartNeeded
}

function Ensure-WinTakConfigStream {
  param(
    [string]$ConfigPath,
    [string]$TemplatePath,
    [string]$TargetUri,
    [string]$ClientCertPath,
    [string]$TrustPath
  )
  $changed = $false

  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    if ($TemplatePath -and (Test-Path -LiteralPath $TemplatePath)) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ConfigPath) | Out-Null
      Copy-Item -LiteralPath $TemplatePath -Destination $ConfigPath -Force
      $changed = $true
    } else {
      throw "WinTAK Config.xml not found at $ConfigPath."
    }
  }

  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.bak" -Force
  [xml]$config = Get-Content -LiteralPath $ConfigPath

  if (-not $config.Config) {
    throw "Unexpected WinTAK Config.xml format."
  }

  $cursor = $config.Config.CursorOnTarget
  if (-not $cursor) {
    $cursor = $config.CreateElement("CursorOnTarget")
    $null = $config.Config.AppendChild($cursor)
  }

  $streams = $cursor.Streams
  if (-not $streams) {
    $streams = $config.CreateElement("Streams")
    $null = $cursor.AppendChild($streams)
  }

  $existing = @($streams.Stream)
  $stream = $existing | Where-Object {
    $_.uri -eq $TargetUri -or $_.desc -eq "P_TAK-local" -or $_.desc -eq "pTAK-local"
  } | Select-Object -First 1

  if (-not $stream) {
    $stream = $config.CreateElement("Stream")
    $null = $streams.AppendChild($stream)
    $changed = $true
  }

  $before = $stream.OuterXml
  $stream.SetAttribute("desc", "pTAK-local")
  $stream.SetAttribute("uri", $TargetUri)
  $stream.SetAttribute("clientCertPath", $ClientCertPath)
  $stream.SetAttribute("certAuthorityPath", $TrustPath)
  $stream.SetAttribute("enabled", "True")
  $stream.SetAttribute("enrollForCertificateWithTrust", "True")
  if (-not $stream.GetAttribute("username")) { $stream.SetAttribute("username", "admin") }
  if (-not $stream.GetAttribute("useLdapAuth")) { $stream.SetAttribute("useLdapAuth", "True") }

  $after = $stream.OuterXml
  if ($before -ne $after) {
    $changed = $true
  }

  if ($changed) {
    $config.Save($ConfigPath)
  }
  return $changed
}

function Ensure-NoPwdP12 {
  param(
    [string]$CertDir,
    [string]$ClientCommonName
  )

  $noPwdPath = Join-Path $CertDir "$ClientCommonName-NoPwd.p12"
  if (Test-Path -LiteralPath $noPwdPath) {
    return $noPwdPath
  }

  $keyPath = Join-Path $CertDir "$ClientCommonName.key"
  $crtPath = Join-Path $CertDir "$ClientCommonName.crt"
  $caPath = Join-Path $CertDir "ca.crt"

  if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $crtPath)) {
    return $null
  }

  $openssl = "openssl"
  try {
    & $openssl version *> $null
    if ($LASTEXITCODE -ne 0) { throw "OpenSSL not found." }
  } catch {
    Write-Warning "OpenSSL not available; cannot generate passwordless .p12."
    return $null
  }

  try {
    $certfileArgs = @()
    if (Test-Path -LiteralPath $caPath) {
      $certfileArgs = @("-certfile", $caPath)
    }
    & $openssl pkcs12 -export -legacy -name $ClientCommonName `
      -out $noPwdPath -inkey $keyPath -in $crtPath @certfileArgs -passout pass:
    if (Test-Path -LiteralPath $noPwdPath) {
      return (Resolve-Path -LiteralPath $noPwdPath).Path
    }
  } catch {
    Write-Warning "Failed to generate $noPwdPath."
  }
  return $null
}

function Wait-ForPort {
  param(
    [string]$TargetHost,
    [int]$Port,
    [int]$TimeoutSec
  )
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
  do {
    try {
      $ok = (Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue).TcpTestSucceeded
    } catch {
      $ok = $false
    }
    if ($ok) { return $true }
    Start-Sleep -Seconds 2
  } while ([DateTime]::UtcNow -lt $deadline)
  return $false
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
Set-Location $repoRoot
$certDir = Join-Path $repoRoot "fts-certs"
$restartRequested = $RestartWinTak.IsPresent
if (-not $restartRequested -and $env:WINTAK_RESTART) {
  $restartRequested = $env:WINTAK_RESTART -match "^(1|true|yes)$"
}

$dockerOk = $true
try {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) { $dockerOk = $false }
} catch {
  $dockerOk = $false
}

if ($dockerOk) {
  Write-Host "Starting docker compose stack..." -ForegroundColor Cyan
  docker compose up -d
  if ($LASTEXITCODE -ne 0) { $dockerOk = $false }
} else {
  Write-Warning "Docker engine is not available. Start Docker Desktop and rerun this launcher."
}

if ($dockerOk) {
  $restartFts = Ensure-PemCopies -CertDir $certDir
  if ($restartFts) {
    Write-Host "Restarting freetakserver to load new PEMs..." -ForegroundColor Cyan
    docker compose restart freetakserver
  }
}

if (-not $env:APPDATA) {
  throw "APPDATA is not set. Run this script from Windows PowerShell/pwsh."
}

$targetUri = "ssl://$ServerHost`:$ServerPort"
$configPath = Join-Path $env:APPDATA "WinTAK\Config.xml"

$existingClientLeaf = $null
$existingTrustLeaf = $null
if (Test-Path -LiteralPath $configPath) {
  try {
    [xml]$existingConfig = Get-Content -LiteralPath $configPath
    $existingStreams = @($existingConfig.Config.CursorOnTarget.Streams.Stream)
    $existingStream = $existingStreams | Where-Object {
      $_.uri -eq $targetUri -or $_.desc -eq "P_TAK-local" -or $_.desc -eq "pTAK-local"
    } | Select-Object -First 1
    if ($existingStream) {
      if ($existingStream.clientCertPath) { $existingClientLeaf = Split-Path -Leaf $existingStream.clientCertPath }
      if ($existingStream.certAuthorityPath) { $existingTrustLeaf = Split-Path -Leaf $existingStream.certAuthorityPath }
    }
  } catch {
    Write-Warning "Unable to read existing WinTAK Config.xml to preserve cert choices."
  }
}

$noPwdPath = Ensure-NoPwdP12 -CertDir $certDir -ClientCommonName $ClientCommonName

$clientCandidates = @()
if ($noPwdPath) { $clientCandidates += $noPwdPath }
if ($existingClientLeaf) { $clientCandidates += (Join-Path $certDir $existingClientLeaf) }
$clientCandidates += @(
  (Join-Path $certDir "$ClientCommonName-NoPwd.p12"),
  (Join-Path $certDir "$ClientCommonName.p12")
)
$clientP12 = Resolve-FirstExistingPath -Candidates $clientCandidates -Description "Client cert (.p12)"

$trustCandidates = @()
$trustCrt = Join-Path $certDir "ca.crt"
$existingTrustPath = $null
if ($existingTrustLeaf) { $existingTrustPath = (Join-Path $certDir $existingTrustLeaf) }

if ($existingTrustPath -and ($existingTrustPath -match "\\.crt$|\\.pem$|\\.cer$")) {
  $trustCandidates += $existingTrustPath
}
if ($trustCrt) { $trustCandidates += $trustCrt }
if ($existingTrustPath -and -not ($existingTrustPath -match "\\.crt$|\\.pem$|\\.cer$")) {
  $trustCandidates += $existingTrustPath
}
$trustCandidates += @(
  (Join-Path $certDir "FTS-CA.p12")
)
$trustStore = Resolve-FirstExistingPath -Candidates $trustCandidates -Description "Trust store"

if (-not $clientP12) {
  throw "Client .p12 not found. Run pwsh ./scripts/gen-fts-certs.ps1 -ClientCommonName $ClientCommonName"
}
if (-not $trustStore) {
  throw "Trust store not found. Ensure fts-certs/ca.crt or fts-certs/FTS-CA.p12 exists."
}

$sslDir = Join-Path $env:APPDATA "WinTAK\SslCerts"
New-Item -ItemType Directory -Force -Path $sslDir | Out-Null

$clientP12Dest = Join-Path $sslDir (Split-Path -Leaf $clientP12)
Copy-Item -LiteralPath $clientP12 -Destination $clientP12Dest -Force
$clientP12Dest = (Resolve-Path -LiteralPath $clientP12Dest).Path

$trustDest = Join-Path $sslDir (Split-Path -Leaf $trustStore)
Copy-Item -LiteralPath $trustStore -Destination $trustDest -Force
$trustDest = (Resolve-Path -LiteralPath $trustDest).Path

Write-Host "Updating WinTAK stream config..." -ForegroundColor Cyan
$templatePath = Join-Path $repoRoot "Config.xml"
$streamChanged = Ensure-WinTakConfigStream -ConfigPath $configPath -TemplatePath $templatePath -TargetUri $targetUri `
  -ClientCertPath $clientP12Dest -TrustPath $trustDest

if ($dockerOk) {
  Write-Host "Waiting for FreeTAKServer TLS port $ServerPort..." -ForegroundColor Cyan
  if (-not (Wait-ForPort -TargetHost $ServerHost -Port $ServerPort -TimeoutSec $WaitSeconds)) {
    Write-Warning "Port $ServerPort did not open within $WaitSeconds seconds. WinTAK may fail to connect."
  }
}

if (Test-Path -LiteralPath $WinTakPath) {
  $existing = Get-Process -Name "WinTAK" -ErrorAction SilentlyContinue
  if ($existing) {
    if ($restartRequested -and $streamChanged) {
      Write-Host "Restarting WinTAK to apply stream changes..." -ForegroundColor Cyan
      $existing | Stop-Process -Force
      Start-Sleep -Seconds 2
      Start-Process $WinTakPath
    } else {
      Write-Warning "WinTAK is already running. Toggle the stream or restart WinTAK to connect."
    }
  } else {
    Write-Host "Launching WinTAK from $WinTakPath" -ForegroundColor Cyan
    Start-Process $WinTakPath
  }
} else {
  Write-Warning "WinTAK path not found ($WinTakPath). Set WINTAK_EXE to the correct path."
}

Write-Host "WinTAK + FreeTAKServer launcher complete." -ForegroundColor Green
