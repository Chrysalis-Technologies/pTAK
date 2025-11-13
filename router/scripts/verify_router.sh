#!/usr/bin/env bash
# Quick health check for the router. Run on the router itself.
set -euo pipefail

CONFIG_FILE="/etc/router-config.env"
PING_TARGET="8.8.8.8"
PING_TIMEOUT=2

declare -A RESULTS
EXIT_CODE=0

usage() {
  cat <<USAGE
Usage: ${0##*/} [-c /path/to/router-config.env] [--skip-ping]

Ensures WAN/LAN interfaces are up, DHCP/DNS services are healthy, and nftables
contains the masquerade rule emitted by Ansible.
USAGE
}

SKIP_PING=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --skip-ping)
      SKIP_PING=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file $CONFIG_FILE not found. Run the Ansible playbook first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

for var in WAN_INTERFACE LAN_INTERFACE LAN_GATEWAY LAN_CIDR; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing $var in $CONFIG_FILE" >&2
    exit 1
  fi
done

LAN_PREFIX="${LAN_CIDR#*/}"
EXPECTED_LAN_ADDR="${LAN_GATEWAY}/${LAN_PREFIX}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' is not installed." >&2
    exit 1
  fi
}

require_cmd ip
require_cmd nft
require_cmd systemctl
require_cmd awk

status_ok() {
  local key="$1" msg="$2"
  RESULTS["$key"]="OK  - $msg"
}

status_fail() {
  local key="$1" msg="$2"
  RESULTS["$key"]="FAIL - $msg"
  EXIT_CODE=1
}

wan_addr=$(ip -4 addr show "$WAN_INTERFACE" | awk '/inet / {print $2; exit}')
if [[ -n "$wan_addr" ]]; then
  status_ok "WAN" "${WAN_INTERFACE} has IPv4 $wan_addr"
else
  status_fail "WAN" "${WAN_INTERFACE} is missing an IPv4 lease"
fi

lan_addr=$(ip -4 addr show "$LAN_INTERFACE" | awk '/inet / {print $2; exit}')
if [[ "$lan_addr" == "$EXPECTED_LAN_ADDR" ]]; then
  status_ok "LAN" "${LAN_INTERFACE} advertises ${LAN_GATEWAY}"
else
  status_fail "LAN" "${LAN_INTERFACE} has $lan_addr (expected ${LAN_GATEWAY})"
fi

if nft list table ip nat | grep -q "oifname \"$WAN_INTERFACE\" masquerade"; then
  status_ok "NAT" "nftables is masquerading LAN out ${WAN_INTERFACE}"
else
  status_fail "NAT" "Missing masquerade rule on ${WAN_INTERFACE}"
fi

if systemctl is-active --quiet dnsmasq; then
  status_ok "DNSMASQ" "dnsmasq service running"
else
  status_fail "DNSMASQ" "dnsmasq service inactive"
fi

if [[ "$SKIP_PING" == false ]]; then
  if ping -c1 -W "$PING_TIMEOUT" "$PING_TARGET" >/dev/null 2>&1; then
    status_ok "PING" "Outbound ping to $PING_TARGET succeeded"
  else
    status_fail "PING" "Outbound ping to $PING_TARGET failed"
  fi
else
  RESULTS["PING"]="SKIP - Ping test skipped"
fi

echo "Router verification summary (config: $CONFIG_FILE)"
for key in "WAN" "LAN" "NAT" "DNSMASQ" "PING"; do
  [[ -n "${RESULTS[$key]:-}" ]] && echo " - ${RESULTS[$key]}"
done

exit "$EXIT_CODE"
