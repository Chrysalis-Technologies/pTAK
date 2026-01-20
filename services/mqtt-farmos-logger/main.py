import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt
import requests
import yaml
from pydantic import BaseModel, ConfigDict, Field

from farmstack.farmos import build_log_payload, resolve_log_type
from farmstack.schema import default_schema_registry


class IdempotencyConfig(BaseModel):
    sqlite_path: str = "/data/processed.sqlite"


class LoggerConfig(BaseModel):
    model_config = ConfigDict(extra="allow")

    site_default: str = "farmstead"
    log_type_default: str = "observation"
    exact_event_map: Dict[str, str] = Field(default_factory=dict)
    prefix_event_map: Dict[str, str] = Field(default_factory=dict)
    idempotency: IdempotencyConfig = Field(default_factory=IdempotencyConfig)


class IdempotencyStore:
    def __init__(self, path: str) -> None:
        self.path = path
        self._conn = sqlite3.connect(self.path, check_same_thread=False)
        self._conn.execute(
            "CREATE TABLE IF NOT EXISTS processed (id TEXT PRIMARY KEY, ts TEXT)"
        )
        self._conn.commit()

    def seen(self, message_id: str) -> bool:
        cursor = self._conn.execute("SELECT 1 FROM processed WHERE id = ?", (message_id,))
        return cursor.fetchone() is not None

    def mark(self, message_id: str, ts: str) -> None:
        self._conn.execute("INSERT OR IGNORE INTO processed (id, ts) VALUES (?, ?)", (message_id, ts))
        self._conn.commit()


def load_config(path: str) -> LoggerConfig:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return LoggerConfig.model_validate(data)


def parse_event_type(topic: str, payload: Dict[str, Any]) -> Optional[str]:
    parts = topic.split("/")
    if len(parts) < 5:
        return payload.get("data", {}).get("event_type")
    event_type = "/".join(parts[4:])
    if not event_type:
        event_type = payload.get("data", {}).get("event_type")
    return event_type.replace("/", ".") if event_type else None


def parse_asset_id(topic: str, payload: Dict[str, Any]) -> Optional[str]:
    parts = topic.split("/")
    if len(parts) >= 4:
        return parts[3]
    return payload.get("asset", {}).get("id")


def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    config_path = os.getenv("FARMOS_CONFIG", "/configs/mqtt-farmos-logger.yaml")
    config = load_config(config_path)
    config_data = config.model_dump()

    site = os.getenv("SITE", config.site_default)
    mqtt_host = os.getenv("MQTT_HOST", "mqtt-broker")
    mqtt_port = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user = os.getenv("MQTT_USERNAME")
    mqtt_pass = os.getenv("MQTT_PASSWORD")

    farmos_mode = os.getenv("FARMOS_MODE", "mock").lower()
    farmos_base_url = os.getenv("FARMOS_BASE_URL", "http://farmos-mock:8000")
    farmos_log_endpoint = os.getenv("FARMOS_LOG_ENDPOINT", "/jsonapi/log")
    farmos_token = os.getenv("FARMOS_TOKEN")

    idempotency = IdempotencyStore(config.idempotency.sqlite_path)
    schema_registry = default_schema_registry()
    meta_cache: Dict[str, Dict[str, Any]] = {}

    def on_connect(client: mqtt.Client, userdata: Any, flags: Dict[str, Any], rc: int) -> None:
        if rc != 0:
            logging.error("MQTT connect failed: rc=%s", rc)
            return
        base = f"farm/{site}"
        client.subscribe(f"{base}/evt/+/#", qos=1)
        client.subscribe(f"{base}/meta/+", qos=1)
        client.subscribe(f"{base}/state/+/status", qos=1)
        logging.info("Subscribed to MQTT topics under %s", base)

    def on_message(client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except json.JSONDecodeError:
            logging.warning("Invalid JSON payload on %s", msg.topic)
            return

        msg_class = payload.get("class")
        schema_map = {
            "evt": "evt.v1.schema.json",
            "meta": "meta.v1.schema.json",
            "state": "state.v1.schema.json",
        }
        schema_name = schema_map.get(msg_class)
        if schema_name:
            try:
                schema_registry.validate(schema_name, payload)
            except ValueError as exc:
                logging.warning("Schema validation failed: %s", exc)
                return

        asset_id = parse_asset_id(msg.topic, payload)
        if not asset_id:
            logging.warning("Missing asset id for topic %s", msg.topic)
            return

        if msg_class == "meta":
            meta_cache[asset_id] = payload
            logging.info("Updated meta cache for %s", asset_id)
            return

        if not payload.get("id"):
            logging.warning("Missing message id on %s", msg.topic)
            return

        if idempotency.seen(payload["id"]):
            logging.info("Duplicate message skipped: %s", payload["id"])
            return

        if msg_class == "state":
            event_type = f"state.status.{payload.get('data', {}).get('status', 'unknown')}"
        else:
            event_type = parse_event_type(msg.topic, payload) or "evt.unknown"

        log_type = resolve_log_type(event_type, config_data)
        log_payload = build_log_payload(payload, event_type, log_type, meta_cache.get(asset_id))

        endpoint = farmos_log_endpoint
        if not endpoint.startswith("/"):
            endpoint = "/" + endpoint
        post_url = f"{farmos_base_url.rstrip('/')}{endpoint}/{log_type}"

        headers: Dict[str, str] = {"Content-Type": "application/vnd.api+json"}
        if farmos_mode == "farmos" and farmos_token:
            headers["Authorization"] = f"Bearer {farmos_token}"

        try:
            response = requests.post(post_url, json=log_payload, headers=headers, timeout=10)
            response.raise_for_status()
            idempotency.mark(payload["id"], payload.get("ts", ""))
            logging.info("Logged event %s to farmOS (%s)", event_type, log_type)
        except Exception as exc:  # pylint: disable=broad-except
            logging.error("Failed to log to farmOS: %s", exc)

    client = mqtt.Client()
    if mqtt_user:
        client.username_pw_set(mqtt_user, mqtt_pass)
    mqtt_tls = os.getenv("MQTT_TLS", "false").lower() == "true"
    if mqtt_tls:
        mqtt_ca = os.getenv("MQTT_TLS_CA")
        mqtt_cert = os.getenv("MQTT_TLS_CERT") or None
        mqtt_key = os.getenv("MQTT_TLS_KEY") or None
        if not mqtt_ca:
            logging.warning("MQTT_TLS enabled but MQTT_TLS_CA not set; using system CAs")
        client.tls_set(ca_certs=mqtt_ca, certfile=mqtt_cert, keyfile=mqtt_key)
        if os.getenv("MQTT_TLS_INSECURE", "false").lower() == "true":
            client.tls_insecure_set(True)

    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(mqtt_host, mqtt_port, keepalive=60)
    client.loop_forever()


if __name__ == "__main__":
    main()
