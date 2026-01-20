# Farm Stack Data Contract

This document defines the canonical MQTT envelope, topic tree, and mapping rules used by the farm situational awareness stack.

## MQTT topic tree
- `farm/<site>/tele/<asset_id>/<stream>`
- `farm/<site>/state/<asset_id>/<stream>` (retain=true)
- `farm/<site>/evt/<asset_id>/<event_type>`
- `farm/<site>/cmd/<asset_id>/<command>`
- `farm/<site>/ack/<asset_id>/<command>`
- `farm/<site>/meta/<asset_id>` (retain=true)
- optional: `farm/<site>/raw/<source>/<asset_id>/<stream>`

## Canonical envelope (v1)
All messages on tele/state/evt/cmd/ack/meta topics use the same envelope.

```json
{
  "v": 1,
  "id": "<uuid-or-ulid>",
  "ts": "2026-01-19T20:15:31Z",
  "site": "<site>",
  "class": "tele|state|evt|cmd|ack|meta",
  "asset": { "id": "<asset_id>", "kind": "<kind>", "name": "<optional>" },
  "src": { "system": "meshtastic|ha|plc|gateway|manual|script", "gw": "<optional>", "id": "<optional>" },
  "loc": { "lat": 0.0, "lon": 0.0, "hae_m": 0.0, "ce_m": 0.0, "le_m": 0.0 },
  "ttl_s": 300,
  "tags": { "zone": "<optional>", "field": "<optional>" },
  "data": { }
}
```

JSON Schemas live under `contracts/schemas/`. Examples live under `contracts/examples/`.

## QoS and retain
- tele: qos0 retain=false
- state: qos1 retain=true
- evt: qos1 retain=false
- meta: qos1 retain=true
- cmd/ack: qos1 retain=false

## CoT mapping (mqtt-cot-bridge)
- uid:
  - prefer `meta.data.tak.uid`
  - else `farm.<site>.<asset_id>`
- type:
  - for position telemetry: `meta.data.tak.cot_type` else `a-f-G-U-C`
  - infrastructure markers default to `a-f-G-I`
  - alerts default to `b-a`; geofence breach uses `b-a-g`
- how:
  - default `m-g` for machine generated
  - `h-e` when `src.system == "manual"`
- time/start = `ts`
- stale = `ts + (ttl_s || meta.data.tak.stale_s_default || 300)`
- point uses `loc` (or `meta.loc` fallback); if no location is available, CoT emit is skipped
- detail/contact callsign uses `meta.data.tak.callsign` else `asset.name` else `asset.id`
- event alerts use uid `farm.<site>.alert.<asset_id>.<event_type>`

## farmOS mapping (mqtt-farmos-logger)
- Persist semantic events (evt/* and selected state transitions). Telemetry is not logged.
- Event type -> farmOS log type mapping is configured in `configs/mqtt-farmos-logger.yaml`.
- Link to farmOS asset via `meta.data.links.farmos_asset_uuid` when available.
- Store original MQTT message under the farmOS log "data" field.
- Enforce idempotency with a local SQLite registry of message ids.

## Meta registry
- Retained messages on `farm/<site>/meta/<asset_id>` populate the in-memory registry.
- The registry provides default TAK identifiers, farmOS asset links, and a fallback location.