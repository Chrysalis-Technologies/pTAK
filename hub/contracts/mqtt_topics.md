# Hub MQTT Topics (`hub.mesh.v1`)

## Inbound topics (bridge input)
- `meshtastic/<node_id>/telemetry`
- `meshtastic/<node_id>/position`

`hub-bridge` subscribes to these raw topics and emits both contract topics (`hub/mesh/...`) and legacy topics (`hub/normalized/...`, `ha/hub/...`).

## Contract topics (stable for HAOS)
- `hub/mesh/<node_id>/telemetry`
- `hub/mesh/<node_id>/link`
- `hub/mesh/<node_id>/position`
- `hub/mesh/_bridge/availability`

All `hub.mesh.v1` topics publish with:
- `qos=1`
- `retain=true`

## Availability semantics
- LWT topic: `hub/mesh/_bridge/availability`
- Online payload (on connect):
```json
{"v":1,"contract":"hub.mesh.v1","service":"hub-bridge","status":"online","ts":"2026-02-24T12:00:00Z"}
```
- Offline payload (LWT):
```json
{"v":1,"contract":"hub.mesh.v1","service":"hub-bridge","status":"offline"}
```

## `hub/mesh/<node_id>/telemetry`
Published only when telemetry fields are present in the normalized message.

Required fields:
- `v` (int, `1`)
- `contract` (string, `hub.mesh.v1`)
- `node_id` (string)
- `uid` (string, `meshtastic-<node_id>`)
- `callsign` (string)
- `ts` (UTC ISO8601 string)
- `last_seen` (UTC ISO8601 string)
- `source_topic` (string)

Optional telemetry fields:
- `temperature_c` (number)
- `humidity_pct` (number)
- `pressure_hpa` (number)

Example:
```json
{"v":1,"contract":"hub.mesh.v1","node_id":"WinTAK-Paul","uid":"meshtastic-WinTAK-Paul","callsign":"WinTAK-Paul","ts":"2026-02-24T12:00:00Z","last_seen":"2026-02-24T12:00:00Z","source_topic":"meshtastic/WinTAK-Paul/telemetry","temperature_c":12.3,"humidity_pct":58.1,"pressure_hpa":1016.4}
```

## `hub/mesh/<node_id>/link`
Published on every inbound telemetry/position message. `last_seen` is refreshed on every publish.

Required fields:
- `v` (int, `1`)
- `contract` (string, `hub.mesh.v1`)
- `node_id` (string)
- `uid` (string)
- `callsign` (string)
- `ts` (UTC ISO8601 string)
- `last_seen` (UTC ISO8601 string)
- `source_topic` (string)
- `status` (string, `online`)

Optional link fields:
- `rssi_dbm` (number; accepts inbound alias `rssi`)
- `snr_db` (number; accepts inbound alias `snr`)
- `hops_away` (integer)
- `hop_limit` (integer)
- `channel_utilization_pct` (number)
- `air_util_tx_pct` (number)

Example:
```json
{"v":1,"contract":"hub.mesh.v1","node_id":"WinTAK-Paul","uid":"meshtastic-WinTAK-Paul","callsign":"WinTAK-Paul","ts":"2026-02-24T12:00:00Z","last_seen":"2026-02-24T12:00:00Z","source_topic":"meshtastic/WinTAK-Paul/telemetry","status":"online","rssi_dbm":-105,"snr_db":7.5,"hops_away":1,"hop_limit":3}
```

## `hub/mesh/<node_id>/position`
Published only when `lat` + `lon` exist (from current message or position cache).

Required fields:
- `v` (int, `1`)
- `contract` (string, `hub.mesh.v1`)
- `node_id` (string)
- `uid` (string)
- `callsign` (string)
- `ts` (UTC ISO8601 string)
- `last_seen` (UTC ISO8601 string)
- `source_topic` (string)
- `lat` (number)
- `lon` (number)
- `position_from_cache` (boolean)

Optional position fields:
- `speed_mps` (number)
- `course_deg` (number)

Example:
```json
{"v":1,"contract":"hub.mesh.v1","node_id":"WinTAK-Paul","uid":"meshtastic-WinTAK-Paul","callsign":"WinTAK-Paul","ts":"2026-02-24T12:00:05Z","last_seen":"2026-02-24T12:00:05Z","source_topic":"meshtastic/WinTAK-Paul/position","lat":43.04531,"lon":-76.1227,"speed_mps":3.4,"course_deg":182.0,"position_from_cache":false}
```

## Legacy topics (temporary dual publish)
`hub-bridge` continues publishing:
- `hub/normalized/<node_id>/telemetry|position`
- `ha/hub/<node_id>/state|telemetry|position`
