#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import paho.mqtt.client as mqtt


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if value is None or not value.strip():
        raise ValueError(f"{name} is required and cannot be empty.")
    return value.strip()


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish simulated telemetry message to Meshtastic MQTT topic.")
    parser.add_argument("--node-id", required=True, help="Node identifier used in topic path")
    parser.add_argument("--lat", type=float, default=43.04523)
    parser.add_argument("--lon", type=float, default=-76.12288)
    parser.add_argument("--temp", type=float, default=12.3)
    parser.add_argument("--humidity", type=float, default=58.1)
    parser.add_argument("--pressure", type=float, default=1016.4)
    args = parser.parse_args()

    host = _require_env("MQTT_BROKER_HOST")
    port_raw = _require_env("MQTT_BROKER_PORT")

    try:
        port = int(port_raw)
    except ValueError as exc:
        raise ValueError("MQTT_BROKER_PORT must be an integer.") from exc

    if not 1 <= port <= 65535:
        raise ValueError(f"MQTT_BROKER_PORT must be in range 1..65535 (got {port}).")

    topic = f"meshtastic/{args.node_id}/telemetry"
    payload = {
        "timestamp": _utc_now_iso(),
        "callsign": args.node_id,
        "temperature_c": args.temp,
        "humidity_pct": args.humidity,
        "pressure_hpa": args.pressure,
        "lat": args.lat,
        "lon": args.lon,
    }

    client = mqtt.Client()
    client.connect(host, port, keepalive=60)
    info = client.publish(topic, json.dumps(payload, separators=(",", ":")))
    info.wait_for_publish()

    if info.rc != mqtt.MQTT_ERR_SUCCESS:
        raise RuntimeError(f"MQTT publish failed with rc={info.rc}.")

    client.disconnect()
    print(f"Published telemetry message to {topic}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pylint: disable=broad-except
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
