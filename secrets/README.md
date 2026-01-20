# MQTT broker credentials

Create a password file here named `mosquitto.passwd`.

Generate with:
- PowerShell: `pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm -Password (Read-Host -AsSecureString)`
- Bash: `./scripts/gen-mqtt-credentials.sh farm`