param(
  [string]$ClientCommonName = "WinTAK-Paul",
  [string]$P12Password,
  [switch]$Force
)
$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot "..\fts-certs"
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

function New-IfMissing($path) {
  if ((Test-Path -Path $path) -and (-not $Force)) {
    return $false
  }
  return $true
}

# Ensure OpenSSL
$openssl = "openssl"
& $openssl version *> $null
if ($LASTEXITCODE -ne 0) { throw "OpenSSL not found in PATH." }

Push-Location $certDir
try {
  if (New-IfMissing "ca.crt") {
    & $openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ca.key -out ca.crt -subj "/CN=FTS-CA"
  }

  if (New-IfMissing "server.crt") {
    & $openssl req -newkey rsa:4096 -nodes -keyout server.key -out server.csr -subj "/CN=freetakserver"
    & $openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 825 -sha256
  }

  $clientKey = "$ClientCommonName.key"
  $clientCsr = "$ClientCommonName.csr"
  $clientCrt = "$ClientCommonName.crt"
  $clientP12 = "$ClientCommonName.p12"

  if (New-IfMissing $clientCrt) {
    & $openssl req -newkey rsa:4096 -nodes -keyout $clientKey -out $clientCsr -subj "/CN=$ClientCommonName"
    & $openssl x509 -req -in $clientCsr -CA ca.crt -CAkey ca.key -CAcreateserial -out $clientCrt -days 825 -sha256
  }

  if (-not $P12Password) {
    $securePassword = Read-Host -AsSecureString "Enter export password for $clientP12"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
      $P12Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    finally {
      if ($BSTR -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
      }
    }
  }

  if (New-IfMissing $clientP12) {
    & $openssl pkcs12 -export -legacy -name $ClientCommonName -out $clientP12 -inkey $clientKey -in $clientCrt -certfile ca.crt -password pass:$P12Password
  }

  Write-Host "CA:      $(Join-Path $certDir 'ca.crt')"
  Write-Host "Server:  $(Join-Path $certDir 'server.crt') + server.key"
  Write-Host "Client:  $(Join-Path $certDir $clientP12)"
}
finally { Pop-Location }
