# CoT Mapping (Hub Bridge v1)

## Defaults
- CoT `type`: `a-f-G-U-C`
- CoT `how`: `m-g`
- CoT stale offset: `+300s`

## Field mapping
- `uid`: `meshtastic-<node_id>`
- `callsign`: payload `callsign` if provided, else `node_id`
- `time`: normalized timestamp (UTC)
- `start`: same as `time`
- `stale`: `time + 300 seconds`
- `point.lat`: normalized `position.lat`
- `point.lon`: normalized `position.lon`

## Position behavior
- If current payload has valid `lat` and `lon`, use it.
- If telemetry payload does not include position, use cached last-known position for that node.
- If no current or cached position exists, CoT emission is skipped for that message.
