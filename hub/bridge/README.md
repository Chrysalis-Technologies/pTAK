# Hub Bridge

`hub-bridge` subscribes to Meshtastic-style MQTT telemetry/position topics, normalizes messages, emits CoT over UDP to TAK, and publishes:
- contract topics under `hub/mesh/#` (`hub.mesh.v1`)
- legacy compatibility topics under `hub/normalized/#` and `ha/hub/#`

## Environment Variables
Create `.env.hub` from `.env.hub.example` and set:
- `MQTT_BROKER_HOST`
- `MQTT_BROKER_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `MQTT_TLS`
- `MQTT_TLS_CA`
- `MQTT_TLS_CERT` (optional)
- `MQTT_TLS_KEY` (optional)
- `MQTT_TLS_INSECURE`
- `MQTT_SUB_TOPICS`
- `MQTT_PUB_PREFIX`
- `TAK_COT_UDP_HOST`
- `TAK_COT_UDP_PORT`
- `HA_MQTT_PREFIX`
- `LOG_LEVEL`
- optional: `HTTP_PORT` (default `8080`)

If `.env.hub` is missing, `pwsh ./scripts/hub-up.ps1` auto-creates it from `.env.hub.example`.

## Bring Up Hub Services
```bash
pwsh ./scripts/hub-up.ps1
```

## Publish Test Messages
Bridge-driven input path:
```powershell
pwsh ./scripts/hub-publish-env.ps1 -NodeId WinTAK-Paul
pwsh ./scripts/hub-publish-pos.ps1 -NodeId WinTAK-Paul
```

Deterministic direct contract samples:
```powershell
pwsh ./scripts/hub-publish-mesh-samples.ps1 -NodeId WinTAK-Paul
```

## Verification
1. Verify retained bridge availability:
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client sh -lc 'mosquitto_sub -h mosquitto -p 8883 --cafile /mqtt-certs/ca.crt -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "hub/mesh/_bridge/availability" -C 1 -v'
```
2. Verify contract topics:
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client sh -lc 'mosquitto_sub -h mosquitto -p 8883 --cafile /mqtt-certs/ca.crt -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "hub/mesh/#" -v'
```
3. Verify legacy topics still publish:
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml run --rm mqtt-client sh -lc 'mosquitto_sub -h mosquitto -p 8883 --cafile /mqtt-certs/ca.crt -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -t "ha/hub/#" -v'
```
4. Verify bridge logs:
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml logs -f hub-bridge
```
5. Health endpoint check (inside `hub-bridge` container):
```bash
docker compose --env-file .env.hub -f docker-compose.hub.yml exec hub-bridge python -c "import os,urllib.request; print(urllib.request.urlopen(f'http://127.0.0.1:{os.getenv(\"HTTP_PORT\",\"8080\")}/health', timeout=2).read().decode())"
```

## Endpoint Helper
Use this script to print concrete broker endpoints and HAOS CA paths:
```powershell
pwsh ./scripts/hub-endpoints.ps1
```

## TAK_COT_UDP_HOST Guidance
- Use `host.docker.internal` when WinTAK runs on the Windows host and hub runs in Docker.
- Use the device IP/hostname when WinTAK runs on another device.
- `127.0.0.1` only targets the `hub-bridge` container itself.
