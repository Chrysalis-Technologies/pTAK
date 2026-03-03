# Session Record - 2026-02-24 - Hub->HAOS `hub.mesh.v1`

## Executive Summary
- Implemented Hub-side MQTT integration contract `hub.mesh.v1` for HAOS consumption.
- Switched Hub Mosquitto to TLS+auth on `8883`.
- Added stable retained QoS1 contract topics under `hub/mesh/#`.
- Added retained QoS1 bridge availability topic with LWT offline semantics.
- Preserved legacy publish paths (`hub/normalized/#`, `ha/hub/#`) for transition compatibility.
- Added operational scripts for deterministic contract sample publishing and endpoint handoff output.

## Scope Completed
- Broker policy:
  - TLS+auth on `8883`.
  - Credentials fixed to:
    - username: `farm`
    - password: `8a64691f37634abdb084a3a6143a4b8b`
- Contract topics implemented:
  - `hub/mesh/<node_id>/telemetry`
  - `hub/mesh/<node_id>/link`
  - `hub/mesh/<node_id>/position`
  - `hub/mesh/_bridge/availability`
- Topic semantics:
  - contract topics use `retain=true`, `qos=1`
  - telemetry published only when telemetry fields exist
  - link published on every inbound telemetry/position event
  - position published only when lat/lon available (current or cached) with `position_from_cache`
  - availability uses online publish and LWT offline publish

## Files Changed
- `docker-compose.hub.yml`
- `hub/mqtt/mosquitto.conf`
- `.env.hub.example`
- `hub/bridge/app/config.py`
- `hub/bridge/app/mqtt_client.py`
- `hub/bridge/app/normalize.py`
- `hub/bridge/app/ha_publish.py`
- `scripts/hub-up.ps1`
- `scripts/hub-publish-env.ps1`
- `scripts/hub-publish-pos.ps1`
- `hub/contracts/mqtt_topics.md`
- `hub/bridge/README.md`

## New Files Added
- `scripts/hub-publish-mesh-samples.ps1`
- `scripts/hub-endpoints.ps1`
- `docs/session-2026-02-24-hub-haos-hubmeshv1.md`

## Detailed Implementation Record

### 1) Hub compose and broker wiring
- Updated `docker-compose.hub.yml`:
  - `mosquitto` now exposes `8883:8883`.
  - Mounted TLS/auth assets:
    - `./mqtt-certs:/mosquitto/certs:ro`
    - `./secrets/mosquitto.passwd:/mosquitto/config/mosquitto.passwd:ro`
  - `hub-bridge` now mounts `./mqtt-certs:/mqtt-certs:ro` so `MQTT_TLS_CA=/mqtt-certs/ca.crt` resolves.
  - `mqtt-client` debug container now includes:
    - `env_file: .env.hub`
    - `./mqtt-certs:/mqtt-certs:ro`

### 2) Broker policy enforcement
- Replaced `hub/mqtt/mosquitto.conf` listener config with TLS+auth:
  - `per_listener_settings true`
  - `listener 8883`
  - `allow_anonymous false`
  - `password_file /mosquitto/config/mosquitto.passwd`
  - `cafile /mosquitto/certs/ca.crt`
  - `certfile /mosquitto/certs/server.crt`
  - `keyfile /mosquitto/certs/server.key`
  - `require_certificate false`
  - `tls_version tlsv1.2`
  - persistence/logging retained

### 3) Hub env defaults
- Updated `.env.hub.example` with fixed secure defaults:
  - `MQTT_BROKER_HOST=mosquitto`
  - `MQTT_BROKER_PORT=8883`
  - `MQTT_USERNAME=farm`
  - `MQTT_PASSWORD=8a64691f37634abdb084a3a6143a4b8b`
  - `MQTT_TLS=true`
  - `MQTT_TLS_CA=/mqtt-certs/ca.crt`
  - `MQTT_TLS_CERT=`
  - `MQTT_TLS_KEY=`
  - `MQTT_TLS_INSECURE=false`
  - `MQTT_SUB_TOPICS=meshtastic/+/telemetry,meshtastic/+/position`

### 4) Bridge config model and validation
- Extended `hub/bridge/app/config.py`:
  - Added typed fields:
    - `mqtt_username`, `mqtt_password`
    - `mqtt_tls`, `mqtt_tls_ca`, `mqtt_tls_cert`, `mqtt_tls_key`, `mqtt_tls_insecure`
  - Added strict bool parser for TLS flags.
  - Validation rules:
    - username requires password and vice versa
    - `MQTT_TLS=true` requires `MQTT_TLS_CA`
    - client cert/key must both be set or both be empty

### 5) MQTT client auth, TLS, and availability LWT
- Updated `hub/bridge/app/mqtt_client.py`:
  - Applies `username_pw_set` when credentials are configured.
  - Applies `tls_set` and `tls_insecure_set` when TLS is enabled.
  - Configures LWT:
    - topic: `hub/mesh/_bridge/availability`
    - payload: `{"v":1,"contract":"hub.mesh.v1","service":"hub-bridge","status":"offline"}`
    - `qos=1`, `retain=true`
  - On successful connect, publishes retained online payload:
    - `{"v":1,"contract":"hub.mesh.v1","service":"hub-bridge","status":"online","ts":"<utc>"}`

### 6) Normalization enhancements
- Updated `hub/bridge/app/normalize.py`:
  - Added always-updated `last_seen` field for every inbound message.
  - Preserved cached position behavior and `position_from_cache`.
  - Added optional link metric parsing:
    - `rssi_dbm` (alias `rssi`)
    - `snr_db` (alias `snr`)
    - `hops_away`, `hop_limit`
    - `channel_utilization_pct`, `air_util_tx_pct`
  - Link metrics stored under normalized `link` object.

### 7) Contract publishing (with dual publish retained)
- Updated `hub/bridge/app/ha_publish.py`:
  - Kept legacy publishes:
    - `hub/normalized/<node_id>/<message_type>`
    - `ha/hub/<node_id>/state|telemetry|position`
  - Added contract publishes (`retain=true`, `qos=1`):
    - `hub/mesh/<node_id>/telemetry` (when telemetry exists)
    - `hub/mesh/<node_id>/link` (every inbound msg, includes `status=online`, `last_seen`, link metrics when present)
    - `hub/mesh/<node_id>/position` (when lat/lon available, includes `position_from_cache`, `speed_mps`, `course_deg`)
  - Contract payloads include `v=1`, `contract=hub.mesh.v1`.

### 8) Hub startup preflight hardening
- Updated `scripts/hub-up.ps1`:
  - Preflight checks required files:
    - `mqtt-certs/ca.crt`
    - `mqtt-certs/server.crt`
    - `mqtt-certs/server.key`
    - `secrets/mosquitto.passwd`
  - Fails fast with remediation commands:
    - `pwsh ./scripts/gen-mqtt-certs.ps1 -AltNames "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net" -Force`
    - `pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm -Force`
  - Prints optional Windows firewall helper:
    - `New-NetFirewallRule -DisplayName "Hub Mosquitto 8883" -Direction Inbound -Protocol TCP -LocalPort 8883 -Action Allow`

### 9) Bridge-input publisher scripts switched to TLS+auth
- Updated `scripts/hub-publish-env.ps1`
- Updated `scripts/hub-publish-pos.ps1`
- Both now:
  - parse `.env.hub` values
  - publish via `mosquitto_pub` on `8883`
  - use `--cafile`, `-u`, `-P`
  - set `-q 1`

### 10) Deterministic contract sample publisher
- Added `scripts/hub-publish-mesh-samples.ps1`:
  - publishes direct contract samples for node `WinTAK-Paul` to:
    - `hub/mesh/WinTAK-Paul/telemetry`
    - `hub/mesh/WinTAK-Paul/link`
    - `hub/mesh/WinTAK-Paul/position`
  - uses fixed timestamps/payload values for repeatable HAOS validation
  - uses `retain (-r)` and `qos 1 (-q 1)` with TLS+auth

### 11) Endpoint handoff script
- Added `scripts/hub-endpoints.ps1`:
  - detects best RFC1918 LAN IPv4 on host (excluding loopback/APIPA/docker/vEthernet/WSL-style adapters when possible)
  - prints:
    - Phase 1 endpoint: `mqtts://<detected_lan_ip>:8883`
    - Phase 2 endpoint: `mqtts://marzocchi-tech.ewe-mulley.ts.net:8883`
    - HAOS CA destination path: `/config/ssl/mqtt/ca.crt`
    - repo CA source path
    - fixed username/password values

### 12) Contract/docs updates
- Replaced `hub/contracts/mqtt_topics.md` with `hub.mesh.v1` contract documentation:
  - required fields by topic
  - retain/qos semantics
  - availability topic semantics
  - legacy dual-publish note
- Updated `hub/bridge/README.md`:
  - TLS+auth bring-up
  - verification commands for contract topics and availability
  - endpoint helper usage

## Validation Record

### Static validation completed
- Python syntax checks passed for updated bridge modules:
  - `hub/bridge/app/config.py`
  - `hub/bridge/app/mqtt_client.py`
  - `hub/bridge/app/normalize.py`
  - `hub/bridge/app/ha_publish.py`
  - `hub/bridge/app/main.py`
- Compose render validation completed using temporary `.env.hub` generated from `.env.hub.example`:
  - confirmed `8883` mapping
  - confirmed cert/password bind mounts

### Runtime note
- In this execution environment, long-running Docker commands were inconsistent/hanging during interactive checks.
- Exact acceptance commands are preserved below for execution on the Windows/P16 host where `pwsh` is available.

## Acceptance Commands (Canonical)

### A) Bring up stack
```bash
pwsh ./scripts/hub-up.ps1
```

### B) Verify retained availability
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client sh -lc \
  'mosquitto_sub -h mosquitto -p 8883 --cafile /mqtt-certs/ca.crt -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "hub/mesh/_bridge/availability" -C 1 -v'
```

### C) Subscribe and publish deterministic samples
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client sh -lc \
  'mosquitto_sub -h mosquitto -p 8883 --cafile /mqtt-certs/ca.crt -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "hub/mesh/WinTAK-Paul/#" -v'
```
```bash
pwsh ./scripts/hub-publish-mesh-samples.ps1 -NodeId WinTAK-Paul
```

### D) Bridge-driven path
```bash
pwsh ./scripts/hub-publish-env.ps1 -NodeId WinTAK-Paul
pwsh ./scripts/hub-publish-pos.ps1 -NodeId WinTAK-Paul
```

## Example Endpoint Script Output
```text
Hub MQTT Endpoints
------------------
Phase 1 LAN:      mqtts://172.24.156.9:8883
Phase 2 Tailscale:mqtts://marzocchi-tech.ewe-mulley.ts.net:8883

HAOS CA path:     /config/ssl/mqtt/ca.crt
Hub CA source:    /mnt/c/Users/PaulMarzocchi/Vivarium/pTAK/mqtt-certs/ca.crt

MQTT username:    farm
MQTT password:    8a64691f37634abdb084a3a6143a4b8b
```

## Handoff Values (Final)
- Username: `farm`
- Password: `8a64691f37634abdb084a3a6143a4b8b`
- Phase 2 broker endpoint: `mqtts://marzocchi-tech.ewe-mulley.ts.net:8883`
- CA source in repo: `mqtt-certs/ca.crt`
- CA destination in HAOS: `/config/ssl/mqtt/ca.crt`

