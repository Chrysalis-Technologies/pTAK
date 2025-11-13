#!/usr/bin/env bash
# Bootstrap script meant to run ON the router to ensure apt + Python bits are
# present before running Ansible remotely.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[provision_router] Please run as root (sudo -i)." >&2
  exit 1
fi

APT_PACKAGES=(
  python3
  python3-apt
  python3-distutils
  python3-venv
  python3-pip
  openssh-server
  nftables
  dnsmasq
)

echo "[provision_router] Updating apt metadata..."
apt-get update -qq

echo "[provision_router] Installing base packages: ${APT_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"

echo "[provision_router] Ensuring SSH is enabled so Ansible can connect."
systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd

echo "[provision_router] Done. Run the Ansible playbook from your laptop to complete configuration."
