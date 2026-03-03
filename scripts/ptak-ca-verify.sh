#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CA_DIR="${PTAK_CA_DIR:-$HOME/.ptak/internal-ca}"
if [[ "$CA_DIR" == ~* ]]; then
  CA_DIR="$HOME${CA_DIR:1}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ca-dir)
      CA_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Required command not found: $1" >&2; exit 1; }
}

assert_file() {
  [[ -f "$1" ]] || { echo "Missing file: $1" >&2; exit 1; }
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Eq "$pattern" "$file"; then
    echo "Expected pattern '$pattern' not found in $file" >&2
    exit 1
  fi
}

need openssl

CHAIN="$CA_DIR/public/ca-chain.crt"
MQTT_CERT="$REPO_ROOT/mqtt-certs/server.crt"
FTS_CERT="$REPO_ROOT/fts-certs/server.crt"
FTS_CLIENT_CERT="$REPO_ROOT/fts-certs/client.pem"

assert_file "$CHAIN"
assert_file "$MQTT_CERT"
assert_file "$FTS_CERT"
assert_file "$FTS_CLIENT_CERT"

echo "Verifying certificate chain trust..."
openssl verify -CAfile "$CHAIN" "$MQTT_CERT"
openssl verify -CAfile "$CHAIN" "$FTS_CERT"
openssl verify -CAfile "$CHAIN" "$FTS_CLIENT_CERT"

mqtt_txt="$(mktemp)"
fts_txt="$(mktemp)"
client_txt="$(mktemp)"
trap 'rm -f "$mqtt_txt" "$fts_txt" "$client_txt"' EXIT

openssl x509 -in "$MQTT_CERT" -noout -text >"$mqtt_txt"
openssl x509 -in "$FTS_CERT" -noout -text >"$fts_txt"
openssl x509 -in "$FTS_CLIENT_CERT" -noout -text >"$client_txt"

echo "Checking MQTT server EKU/KU/SAN..."
assert_contains "$mqtt_txt" "TLS Web Server Authentication"
assert_contains "$mqtt_txt" "Digital Signature"
assert_contains "$mqtt_txt" "Key Encipherment"
assert_contains "$mqtt_txt" "Subject Alternative Name"

echo "Checking FTS server EKU/KU/SAN..."
assert_contains "$fts_txt" "TLS Web Server Authentication"
assert_contains "$fts_txt" "Digital Signature"
assert_contains "$fts_txt" "Key Encipherment"
assert_contains "$fts_txt" "Subject Alternative Name"

echo "Checking client EKU/KU..."
assert_contains "$client_txt" "TLS Web Client Authentication"
assert_contains "$client_txt" "Digital Signature"
assert_contains "$client_txt" "Key Encipherment"

echo "PKI verification checks passed."
