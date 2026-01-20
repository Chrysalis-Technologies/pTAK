#!/usr/bin/env bash
set -euo pipefail

ALT_NAMES=${1:-"mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"}
FORCE=${2:-""}

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required on PATH." >&2
  exit 1
fi

cert_dir="$(cd "$(dirname "$0")/../mqtt-certs" && pwd)"
mkdir -p "$cert_dir"

ca_key="$cert_dir/ca.key"
ca_crt="$cert_dir/ca.crt"
server_key="$cert_dir/server.key"
server_csr="$cert_dir/server.csr"
server_crt="$cert_dir/server.crt"

if [[ -f "$server_crt" && "$FORCE" != "--force" ]]; then
  echo "Existing MQTT certs found. Re-run with --force to overwrite." >&2
  exit 1
fi

IFS=',' read -ra names <<< "$ALT_NAMES"

san_parts=()
for name in "${names[@]}"; do
  trimmed="$(echo "$name" | xargs)"
  if [[ -z "$trimmed" ]]; then
    continue
  fi
  if [[ "$trimmed" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    san_parts+=("IP:$trimmed")
  else
    san_parts+=("DNS:$trimmed")
  fi
done

san=$(IFS=, ; echo "${san_parts[*]}")

ext_file="$cert_dir/server.ext"
cat > "$ext_file" <<EOF
subjectAltName=$san
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF

openssl req -x509 -new -nodes -keyout "$ca_key" -out "$ca_crt" -days 825 -subj "/CN=farm-mqtt-ca" >/dev/null 2>&1
openssl req -new -nodes -keyout "$server_key" -out "$server_csr" -subj "/CN=mqtt-broker" >/dev/null 2>&1
openssl x509 -req -in "$server_csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$server_crt" -days 825 -extfile "$ext_file" >/dev/null 2>&1

rm -f "$server_csr" "$ext_file"

echo "Generated MQTT CA and server certs in $cert_dir"
