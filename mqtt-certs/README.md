# MQTT TLS certificates

This directory contains runtime MQTT broker TLS artifacts used by docker compose.

Expected files:
- `ca.crt` (public trust anchor)
- `server.crt`
- `server.key`

These files are generated from the unified pTAK internal PKI toolkit.

Generate/provision with:
- Unified toolkit (recommended): `bash ./scripts/ptak-ca.sh provision`
- Compatibility PowerShell wrapper: `pwsh ./scripts/gen-mqtt-certs.ps1 -AltNames "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"`
- Compatibility bash wrapper: `./scripts/gen-mqtt-certs.sh "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"`

Include your broker DNS names and IPs in SAN values so TLS hostname validation succeeds.
