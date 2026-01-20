#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

SITE=${SITE:-farmstead}
MQTT_PORT=${MQTT_PORT:-8883}
MQTT_TLS=${MQTT_TLS:-true}
MQTT_USERNAME=${MQTT_USERNAME:-}
MQTT_PASSWORD=${MQTT_PASSWORD:-}

if [[ -z "$MQTT_USERNAME" || -z "$MQTT_PASSWORD" ]]; then
  echo "MQTT_USERNAME and MQTT_PASSWORD must be set in .env or environment." >&2
  exit 1
fi

tele_json=$(python - <<'PY'
import json
import os
from datetime import datetime, timezone
from uuid import uuid4

site = os.environ.get("SITE", "farmstead")

payload = {
    "v": 1,
    "id": str(uuid4()),
    "ts": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "site": site,
    "class": "tele",
    "asset": {"id": "tractor-01", "kind": "tractor", "name": "Blue 6410"},
    "src": {"system": "meshtastic", "id": "demo"},
    "loc": {"lat": 43.04523, "lon": -76.12288, "hae_m": 146.2, "ce_m": 4.5, "le_m": 8.0},
    "ttl_s": 120,
    "data": {"stream": "position", "metrics": {"battery_pct": 87, "rssi_dbm": -105}},
}
print(json.dumps(payload))
PY
)

evt_json=$(python - <<'PY'
import json
import os
from datetime import datetime, timezone
from uuid import uuid4

site = os.environ.get("SITE", "farmstead")

payload = {
    "v": 1,
    "id": str(uuid4()),
    "ts": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "site": site,
    "class": "evt",
    "asset": {"id": "gate-east", "kind": "gate", "name": "East Gate"},
    "src": {"system": "ha", "id": "demo"},
    "loc": {"lat": 43.04601, "lon": -76.12111, "hae_m": 145.0, "ce_m": 6.0, "le_m": 12.0},
    "ttl_s": 600,
    "data": {"event_type": "gate.open", "severity": "warning", "message": "After-hours gate open"},
}
print(json.dumps(payload))
PY
)

common_args=(docker compose exec -T mqtt-broker mosquitto_pub -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD")
if [[ "$MQTT_TLS" == "true" ]]; then
  common_args+=(--cafile /mosquitto/certs/ca.crt)
fi

echo "Publishing telemetry to farm/$SITE/tele/tractor-01/position"
"${common_args[@]}" -t "farm/$SITE/tele/tractor-01/position" -m "$tele_json"

echo "Publishing event to farm/$SITE/evt/gate-east/gate.open"
"${common_args[@]}" -t "farm/$SITE/evt/gate-east/gate.open" -m "$evt_json"