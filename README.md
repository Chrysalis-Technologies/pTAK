# DIY x86 Router Automation

This repository captures a reproducible configuration pipeline for a small x86-based router appliance. It assumes you have already installed a stock Debian or Ubuntu image onto the hardware (typically via a USB installer) and now want to apply consistent, version-controlled networking, firewall, and DHCP settings.

The project does not build custom firmware images. Instead, it uses standard shell tooling and Ansible to configure an existing installation over SSH so you can iterate quickly, keep changes reviewable, and recover from mistakes by re-running the playbook.

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
