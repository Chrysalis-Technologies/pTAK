#!/usr/bin/env bash
set -euo pipefail

username=${1:-"farm"}
force=${2:-""}

secrets_dir="$(cd "$(dirname "$0")/../secrets" && pwd)"
mkdir -p "$secrets_dir"
passwd_file="$secrets_dir/mosquitto.passwd"

if [[ -f "$passwd_file" && "$force" != "--force" ]]; then
  echo "Existing mosquitto.passwd found. Re-run with --force to overwrite." >&2
  exit 1
fi

echo "Generating mosquitto.passwd for user '$username'..."

docker run --rm -it -v "$secrets_dir:/secrets" eclipse-mosquitto:2 mosquitto_passwd /secrets/mosquitto.passwd "$username"

echo "Credential file created at $passwd_file"