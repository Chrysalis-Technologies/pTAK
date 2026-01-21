# DIY x86 Router Automation

This repository captures a reproducible configuration pipeline for a small x86-based router appliance. It assumes you have already installed a stock Debian or Ubuntu image onto the hardware (typically via a USB installer) and now want to apply consistent, version-controlled networking, firewall, and DHCP settings.

The project does not build custom firmware images. Instead, it uses standard shell tooling and Ansible to configure an existing installation over SSH so you can iterate quickly, keep changes reviewable, and recover from mistakes by re-running the playbook.

## WinTAK + FreeTAKServer Quick Start
1. Start the stack: `docker compose up -d`.
2. Generate certs: `pwsh ./scripts/gen-fts-certs.ps1 -ClientCommonName WinTAK-Paul` (use `-Force` to regenerate).
3. Ensure PEM copies exist for FTS defaults: `Copy-Item fts-certs/ca.crt fts-certs/ca.pem` and `Copy-Item fts-certs/server.crt fts-certs/server.pem`.
4. Restart the server to load certs: `docker compose restart freetakserver`.
5. In WinTAK, use `WinTAK-Paul-NoPwd.p12` for the client identity and `FTS-CA.p12` for the truststore, then connect to `ssl://127.0.0.1:8089`.
6. Verify ports with `pwsh ./scripts/test-fts.ps1` (8089 must be open).

## TLS Notes
- `docker-compose.yml` must mount `fts-certs` read/write so FreeTAKServer can create `server.key.unencrypted`.
- TLS env vars should point at `/certs/ca.pem`, `/certs/server.pem`, `/certs/server.key`, and include `FTS_CERTS_PATH=/certs`.
- Server cert SANs include `freetakserver`, `localhost`, `127.0.0.1`; use one of these in WinTAK to avoid hostname mismatch.
- The repo mounts patched SSL controllers from `overrides/` to bypass CRL enforcement unless you manage `fts-certs/FTS_CRL.json`.

## Farm Situational Awareness & Control Stack
This repo includes a local integration scaffold that links MQTT, TAK, and farmOS with a shared data contract under `contracts/`.

### Quickstart (dev mode)
1. Generate MQTT TLS certs:
   - PowerShell: `pwsh ./scripts/gen-mqtt-certs.ps1 -AltNames "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"`
   - Bash: `./scripts/gen-mqtt-certs.sh "mqtt-broker,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"`
2. Create MQTT credentials:
   - PowerShell: `pwsh ./scripts/gen-mqtt-credentials.ps1 -Username farm`
   - Bash: `./scripts/gen-mqtt-credentials.sh farm`
3. Copy environment defaults and set `MQTT_USERNAME`/`MQTT_PASSWORD` to match:
   - PowerShell: `Copy-Item .env.example .env`
   - Bash: `cp .env.example .env`
4. Start services: `docker compose up -d`.
5. Publish demo messages:
   - PowerShell: `pwsh ./scripts/demo.ps1`
   - Bash: `./scripts/demo.sh`

Expected results:
- CoT XML appears in `docker compose logs cot-sink` and files under `data/cot-sink/`.
- farmOS mock records requests under `data/farmos-mock/`.

### Connect HAOS over Tailscale
- Copy `mqtt-certs/ca.crt` to HAOS (for example `/config/ssl/mqtt/ca.crt`).
- Configure the HAOS MQTT integration with the broker MagicDNS name `marzocchi-tech.ewe-mulley.ts.net`, port `8883`, and the credentials in `.env`.
- Use `integrations/homeassistant/mqtt-package.yaml` for example sensors/automation or configure via UI.
- Restrict Tailscale ACLs so only HAOS can reach the broker port.

### Configure real TAK
- Set `TAK_MODE=tak` in `.env`.
- Point `TAK_HOST`, `TAK_PORT`, and TLS paths (`TAK_TLS_CA`, `TAK_TLS_CERT`, `TAK_TLS_KEY`) to the mounted client cert + key in PEM form.
- For FreeTAKServer in this repo, place client PEMs under `./fts-certs` (for example `client.pem`/`client.key`) or update the env values.

### Configure real farmOS
- Set `FARMOS_MODE=farmos` and `FARMOS_BASE_URL` to your farmOS instance.
- Provide `FARMOS_TOKEN` (or alternate auth) and adjust `FARMOS_LOG_ENDPOINT` if needed.

### Add a new asset or mapping
- Publish a retained meta message to `farm/<site>/meta/<asset_id>` with `data.tak` and `data.links.farmos_asset_uuid`.
- Update defaults in `configs/mqtt-cot-bridge.yaml` and `configs/mqtt-farmos-logger.yaml` if you need custom CoT types or log mappings.

### Docs and tests
- Data contract: `docs/data-contract.md`
- HA snippets: `integrations/homeassistant/mqtt-package.yaml`
- QGIS/TAK overlays: `docs/overlays.md`
- Tests: `pip install -r requirements-dev.txt` then `pytest`

## Launcher
- Run `pwsh ./scripts/launch-lab.ps1` to start docker compose, launch WinTAK (set `WINTAK_EXE` if needed), and open Edge with tabs for the pTAK workspace, farmOS, and the HAOS SPRINT dashboard. Defaults: Edge profile `Default`, workspace link prefilled, farmOS at `http://marzocchi-tech.ewe-mulley.ts.net:8082`, HA at `http://homeassistant.local:8123/lovelace/sprint`. Optional env overrides: `EDGE_PROFILE_DIR`, `PTAK_WORKSPACE_URL`, `FARMOS_URL`, `HAOS_SPRINT_URL`.

## Hardware Overview
See `docs/hardware-bom.md` for the recommended router chassis, storage, cabling, and optional accessories that mirror the “fanless 4×2.5 GbE” homelab builds.

## Quick Start
1. Clone this repository on your management laptop or WSL2 environment.
2. Copy `router/config/router-config.example.yml` to `router/config/router-config.local.yml` and edit it with your WAN/LAN interface names, addressing, and DHCP range.
3. Confirm you can SSH into the router as the configured user (key-based auth is recommended).
4. Run the Ansible playbook:
   ```bash
   ansible-playbook -i router/ansible/inventory.ini router/ansible/site.yml \
     -e @router/config/router-config.local.yml
   ```
   The playbook is idempotent—re-running it safely reconciles the router with the declared state.

## Local Dev Setup
1. Create and activate a Python virtual environment (WSL2 example):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install --upgrade pip
   pip install -r requirements.txt
   ```
2. Export any required Ansible environment variables (e.g., `ANSIBLE_HOST_KEY_CHECKING=False` for first-run lab devices).
3. Update `router/config/router-config.local.yml` with your router host/IP, SSH user, and networking values.
4. Apply the configuration using the `ansible-playbook` command shown above whenever you need to reconcile the router. Use `ansible-playbook --syntax-check` or the provided VS Code task before deploying changes.

## What This Router Configures
- WAN + LAN IP addressing via Netplan, including DHCP on WAN and static LAN gateway settings.
- Firewalling and NAT using nftables, with IPv4 forwarding enabled and the LAN interface masqueraded out the WAN uplink.
- A dnsmasq-based DHCP/DNS service advertising the LAN gateway and forwarding queries to user-defined upstream DNS servers.
- Helpful bootstrap + verification scripts under `router/scripts/` along with an inventory and playbook meant to be run from your laptop.

For a visual overview of how the router sits between your modem/ONT and downstream switches/APs, review `docs/network-topology.md`.
