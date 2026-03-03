$ErrorActionPreference = "Stop"

$repoRoot = Join-Path $PSScriptRoot ".."
Set-Location $repoRoot

if (-not (Test-Path ".env.hub")) {
  throw ".env.hub not found. Create it first: Copy-Item .env.hub.example .env.hub"
}

docker compose --env-file .env.hub -f docker-compose.hub.yml down
