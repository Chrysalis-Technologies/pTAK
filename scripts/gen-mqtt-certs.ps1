param(
  [string]$AltNames = "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net",
  [switch]$Force
)

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
  throw "OpenSSL is required on PATH. Install OpenSSL and try again."
}

$certDir = Join-Path $PSScriptRoot "..\mqtt-certs"
New-Item -ItemType Directory -Force $certDir | Out-Null

$caKey = Join-Path $certDir "ca.key"
$caCrt = Join-Path $certDir "ca.crt"
$serverKey = Join-Path $certDir "server.key"
$serverCsr = Join-Path $certDir "server.csr"
$serverCrt = Join-Path $certDir "server.crt"

if (-not $Force -and (Test-Path $serverCrt)) {
  throw "Existing MQTT certs found. Re-run with -Force to overwrite."
}

$names = $AltNames -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$sanParts = @()
foreach ($name in $names) {
  if ($name -match "^\d+\.\d+\.\d+\.\d+$") {
    $sanParts += "IP:$name"
  } else {
    $sanParts += "DNS:$name"
  }
}
$san = $sanParts -join ","

$extFile = Join-Path $certDir "server.ext"
@" 
subjectAltName=$san
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
"@ | Set-Content -NoNewline $extFile

& $openssl req -x509 -new -nodes -keyout $caKey -out $caCrt -days 825 -subj "/CN=farm-mqtt-ca" | Out-Null
& $openssl req -new -nodes -keyout $serverKey -out $serverCsr -subj "/CN=mqtt-broker" | Out-Null
& $openssl x509 -req -in $serverCsr -CA $caCrt -CAkey $caKey -CAcreateserial -out $serverCrt -days 825 -extfile $extFile | Out-Null

Remove-Item -Force $serverCsr, $extFile
Write-Host "Generated MQTT CA and server certs in $certDir"
