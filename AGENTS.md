# AGENTS

## Goal
Manage a unified internal PKI for pTAK services (MQTT, FreeTAKServer, WinTAK, and future devices) with an offline root + issuing intermediate model.

## Canonical toolkit
- `scripts/ptak-ca.sh` (bash core)
- `scripts/ptak-ca.ps1` (PowerShell wrapper)
- `scripts/ptak-ca-verify.sh` (validation checks)
- OpenSSL profiles: `scripts/openssl/*.cnf`

## CA storage model
- Default CA state path: `${PTAK_CA_DIR:-$HOME/.ptak/internal-ca}`
- Repo symlink: `secrets/internal-ca -> $PTAK_CA_DIR` (created by `init`)
- Root and issuing CA private keys remain outside runtime cert dirs by default.

## Procedure
1. Start stack: `docker compose up -d`.
2. Initialize PKI (idempotent): `bash ./scripts/ptak-ca.sh init`.
3. Provision runtime cert outputs: `bash ./scripts/ptak-ca.sh provision`.
   - Writes compatibility files to `mqtt-certs/` and `fts-certs/`.
   - Always creates timestamped backup snapshots before overwrite.
4. Restart FreeTAKServer: `docker compose restart freetakserver`.
5. Configure WinTAK to use `fts-certs/WinTAK-Paul.p12` and trust the CA.
6. Verify:
   - `pwsh ./scripts/test-fts.ps1`
   - `bash ./scripts/ptak-ca-verify.sh`

## Compatibility outputs
- MQTT:
  - `mqtt-certs/ca.crt`
  - `mqtt-certs/server.crt`
  - `mqtt-certs/server.key`
- FTS/WinTAK:
  - `fts-certs/ca.pem`
  - `fts-certs/server.pem`
  - `fts-certs/server.key`
  - `fts-certs/WinTAK-<name>.crt|key|p12`
  - `fts-certs/client.pem|client.key`

## Dangerous mode
If runtime CA signing is truly required by FTS, provision with:
- `bash ./scripts/ptak-ca.sh provision --allow-online-ca-key`

This copies only a dedicated online intermediate key into `fts-certs/ca.key`. It never copies root or main issuing key.

## Revocation and CRL
- Revoke: `bash ./scripts/ptak-ca.sh revoke <cert-name-or-path>`
- Generate CRL: `bash ./scripts/ptak-ca.sh crl`
- Public CRL output: `$PTAK_CA_DIR/public/ca.crl.pem`

## Backups
- Encrypted backup + checksum: `bash ./scripts/ptak-ca.sh backup`
- See `docs/internal-ca.md` for backup/restore and trust distribution.
