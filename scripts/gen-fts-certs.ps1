param(
  [string]$ClientCommonName = "WinTAK-Paul",
  [string]$P12Password,
  [switch]$Force
)
$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot "..\fts-certs"
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

function ShouldGenerate {
  param([string[]]$Paths)

  $exists = $false
  foreach ($path in $Paths) {
    if (Test-Path -Path $path) {
      $exists = $true
    }
  }

  if ($exists -and -not $Force) {
    return $false
  }

  if ($Force) {
    foreach ($path in $Paths) {
      if (Test-Path -Path $path) {
        Remove-Item -Path $path -Force
      }
    }
  }

  return $true
}

function New-ConfigFile {
  param([string]$Content)
  $tmp = New-TemporaryFile
  Set-Content -LiteralPath $tmp.FullName -Value $Content -Encoding ASCII
  return $tmp
}

$tempFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

try {
  # Ensure OpenSSL
  $openssl = "openssl"
  & $openssl version *> $null
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL not found in PATH." }

  $caPaths = @("ca.crt", "ca.key", "ca.srl")
  $serverPaths = @("server.crt", "server.key", "server.csr")
  $clientPaths = @(
    "$ClientCommonName.crt",
    "$ClientCommonName.key",
    "$ClientCommonName.csr"
  )

  Push-Location $certDir
  try {
    if (ShouldGenerate -Paths $caPaths) {
      $caConfig = New-ConfigFile @"
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[ req_distinguished_name ]
CN = FTS-CA

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
"@
      $tempFiles.Add($caConfig) | Out-Null

      & $openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes `
        -keyout ca.key -out ca.crt -config $caConfig.FullName
    }

    if (ShouldGenerate -Paths $serverPaths) {
      $serverReqConfig = New-ConfigFile @"
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = freetakserver

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = freetakserver
DNS.2 = localhost
IP.1 = 127.0.0.1
"@
      $tempFiles.Add($serverReqConfig) | Out-Null

      & $openssl req -newkey rsa:4096 -nodes `
        -keyout server.key -out server.csr -config $serverReqConfig.FullName

      $serverExtConfig = New-ConfigFile @"
[ v3_server ]
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = freetakserver
DNS.2 = localhost
IP.1 = 127.0.0.1
"@
      $tempFiles.Add($serverExtConfig) | Out-Null

      & $openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial `
        -out server.crt -days 825 -sha256 -extfile $serverExtConfig.FullName -extensions v3_server
    }
    else {
      # Ensure existing server certificate has SAN/usage by regenerating if CSR missing
      if (-not (Test-Path -Path "server.crt")) {
        throw "server.crt missing. Rerun with -Force to regenerate."
      }
    }

    $clientGenerated = $false
    if (ShouldGenerate -Paths $clientPaths) {
      $clientReqConfig = New-ConfigFile @"
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $ClientCommonName

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $ClientCommonName
"@
      $tempFiles.Add($clientReqConfig) | Out-Null

      & $openssl req -newkey rsa:4096 -nodes `
        -keyout "$ClientCommonName.key" -out "$ClientCommonName.csr" -config $clientReqConfig.FullName

      $clientExtConfig = New-ConfigFile @"
[ v3_client ]
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $ClientCommonName
"@
      $tempFiles.Add($clientExtConfig) | Out-Null

      & $openssl x509 -req -in "$ClientCommonName.csr" -CA ca.crt -CAkey ca.key -CAcreateserial `
        -out "$ClientCommonName.crt" -days 825 -sha256 -extfile $clientExtConfig.FullName -extensions v3_client
      $clientGenerated = $true
    }

    if (-not $P12Password) {
      $securePassword = Read-Host -AsSecureString "Enter export password for $ClientCommonName.p12"
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

    $clientP12Path = "$ClientCommonName.p12"
    if ($Force -or $clientGenerated -or -not (Test-Path -Path $clientP12Path)) {
      if ($Force -and (Test-Path -Path $clientP12Path)) {
        Remove-Item -Path $clientP12Path -Force
      }
      & $openssl pkcs12 -export -legacy -name $ClientCommonName `
        -out $clientP12Path -inkey "$ClientCommonName.key" `
        -in "$ClientCommonName.crt" -certfile ca.crt -password pass:$P12Password
    }

    Write-Host "CA:      $(Join-Path $certDir 'ca.crt')"
    Write-Host "Server:  $(Join-Path $certDir 'server.crt') + server.key"
    Write-Host "Client:  $(Join-Path $certDir "$ClientCommonName.p12")"
  }
  finally {
    Pop-Location
  }
}
finally {
  foreach ($tmp in $tempFiles) {
    if ($tmp -and (Test-Path -LiteralPath $tmp.FullName)) {
      Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
  }
}
