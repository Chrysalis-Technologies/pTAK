#!/usr/bin/env pwsh
param(
    [string]$EdgeProfile = ${env:EDGE_PROFILE_DIR} ? ${env:EDGE_PROFILE_DIR} : "Default",
    [string]$WinTakPath = ${env:WINTAK_EXE} ? ${env:WINTAK_EXE} : "C:\Program Files\WinTAK\WinTAK.exe",
    [string]$PtakWorkspaceUrl = ${env:PTAK_WORKSPACE_URL} ? ${env:PTAK_WORKSPACE_URL} : "https://aka.ms/edgeworkspaces/join?type=2&id=aHR0cHM6Ly9wbWFyem9jY2hpLW15LnNoYXJlcG9pbnQuY29tLzp1Oi9nL3BlcnNvbmFsL3BhdWxfbWFyem9jY2hpX3RlY2gvSVFCSVM1TUc0MklHVHI1ZTdYUFdZUFZtQVhhc3hkYndfOXp6TkJIaFF6T2kxak0%3D&store=3&source=Workspaces",
    [string]$FarmOsUrl = ${env:FARMOS_URL} ? ${env:FARMOS_URL} : "http://marzocchi-tech.ewe-mulley.ts.net:8082",
    [string]$HaosSprintUrl = ${env:HAOS_SPRINT_URL} ? ${env:HAOS_SPRINT_URL} : "http://homeassistant.local:8123/lovelace/sprint"
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host "Bringing up docker-compose stack..." -ForegroundColor Cyan
docker compose up -d

function Start-EdgeWindow {
    param(
        [string]$Profile,
        [string[]]$Urls
    )

    $edgePath = "msedge.exe"
    $edge = Get-Command $edgePath -ErrorAction SilentlyContinue
    if (-not $edge) {
        Write-Warning "Microsoft Edge not found on PATH. Skipping browser launch."
        return
    }

    $args = @("--profile-directory=$Profile", "--new-window") + $Urls
    Start-Process $edgePath -ArgumentList $args
}

if (Test-Path $WinTakPath) {
    Write-Host "Launching WinTAK from $WinTakPath" -ForegroundColor Cyan
    Start-Process $WinTakPath
} else {
    Write-Warning "WinTAK path not found ($WinTakPath). Set WINTAK_EXE to the correct path."
}

$edgeTabs = @()
if ($PtakWorkspaceUrl) { $edgeTabs += $PtakWorkspaceUrl }
if ($FarmOsUrl) { $edgeTabs += $FarmOsUrl }
if ($HaosSprintUrl) { $edgeTabs += $HaosSprintUrl }

if ($edgeTabs.Count -gt 0) {
    Write-Host "Opening Edge workspace with $(($edgeTabs -join ', '))" -ForegroundColor Cyan
    Start-EdgeWindow -Profile $EdgeProfile -Urls $edgeTabs
}

Write-Host "Launcher complete." -ForegroundColor Green
