#!/usr/bin/env bash
set -euo pipefail

ALT_NAMES=${1:-"mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"}
FORCE=${2:-""}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$SCRIPT_DIR/ptak-ca.sh"

if [[ ! -x "$TOOL" ]]; then
  echo "Missing PKI tool: $TOOL" >&2
  exit 1
fi

SERVER_CRT="$REPO_ROOT/mqtt-certs/server.crt"
if [[ -f "$SERVER_CRT" && "$FORCE" != "--force" ]]; then
  echo "Existing MQTT certs found. Re-run with --force to overwrite." >&2
  exit 1
fi

"$TOOL" provision --skip-fts --skip-wintak --mqtt-san "$ALT_NAMES"
