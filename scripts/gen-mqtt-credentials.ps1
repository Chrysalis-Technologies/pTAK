param(
  [string]$Username = "farm",
  [switch]$Force
)

$secretsDir = Join-Path $PSScriptRoot "..\secrets"
New-Item -ItemType Directory -Force $secretsDir | Out-Null
$passwdPath = Join-Path $secretsDir "mosquitto.passwd"

if (-not $Force -and (Test-Path $passwdPath)) {
  throw "Existing mosquitto.passwd found. Re-run with -Force to overwrite."
}

Write-Host "Generating mosquitto.passwd for user '$Username'..."
Write-Host "You'll be prompted to enter the password twice."

& docker run --rm -it -v "${secretsDir}:/secrets" eclipse-mosquitto:2 mosquitto_passwd /secrets/mosquitto.passwd $Username

Write-Host "Credential file created at $passwdPath"