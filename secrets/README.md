# Secrets Directory

This folder is gitignored and stores local secret material.

## MQTT broker credentials

Create a password file here named `mosquitto.passwd`.

Generate with:
- PowerShell: `pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm`
- Bash: `./scripts/gen-mqtt-credentials.sh farm`

## Unified internal CA link

`bash ./scripts/ptak-ca.sh init` creates a symlink:
- `secrets/internal-ca -> ${PTAK_CA_DIR:-$HOME/.ptak/internal-ca}`

The actual CA state is stored outside `/mnt/c/...` by default (Linux home) for safer permissions.

Sensitive files under the CA directory include:
- `.ca-passphrase`
- `root/private/root-ca.key.pem`
- `issuing/private/issuing-ca.key.pem`
- `online/private/fts-online-ca.key.pem` (only if dangerous online mode is used)

Keep these private files mode `600` and do not copy CA keys into runtime cert directories unless explicitly required.
