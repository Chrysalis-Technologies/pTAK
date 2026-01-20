import json
import logging
import os
import socket
import ssl
import time
from collections import OrderedDict
from pathlib import Path
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt
import yaml
from pydantic import BaseModel, ConfigDict, Field

from farmstack.cot import build_cot_xml
from farmstack.schema import default_schema_registry


class DedupeConfig(BaseModel):
    max_entries: int = 512
    window_s: int = 180


class BridgeConfig(BaseModel):
    model_config = ConfigDict(extra="allow")

    site_default: str = "farmstead"
    cot_defaults: Dict[str, Any] = Field(default_factory=dict)
    dedupe: DedupeConfig = Field(default_factory=DedupeConfig)
    asset_kind_map: Dict[str, Any] = Field(default_factory=dict)
    event_type_map: Dict[str, Any] = Field(default_factory=dict)


class DedupeCache:
    def __init__(self, max_entries: int, window_s: int) -> None:
        self.max_entries = max_entries
        self.window_s = window_s
        self._cache: OrderedDict[str, float] = OrderedDict()

    def seen(self, message_id: str) -> bool:
        now = time.time()
        if message_id in self._cache:
            if now - self._cache[message_id] <= self.window_s:
                return True
        self._cache[message_id] = now
        self._evict(now)
        return False

    def _evict(self, now: float) -> None:
        while self._cache and len(self._cache) > self.max_entries:
            self._cache.popitem(last=False)
        stale_keys = [key for key, ts in self._cache.items() if now - ts > self.window_s]
        for key in stale_keys:
            self._cache.pop(key, None)


class DevSinkSender:
    def __init__(self, host: Optional[str], port: int, protocol: str) -> None:
        self.host = host
        self.port = port
        self.protocol = protocol.lower()

    def send(self, cot_xml: str) -> None:
        if not self.host:
            logging.info("CoT dev output\n%s", cot_xml)
            return
        if self.protocol == "tcp":
            with socket.create_connection((self.host, self.port), timeout=5) as sock:
                sock.sendall(cot_xml.encode("utf-8") + b"\n")
            return
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.sendto(cot_xml.encode("utf-8"), (self.host, self.port))


class TlsTakSender:
    def __init__(self, host: str, port: int, cafile: str, certfile: str, keyfile: str, verify: bool) -> None:
        self.host = host
        self.port = port
        self.context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=cafile if verify else None)
        if not verify:
            self.context.check_hostname = False
            self.context.verify_mode = ssl.CERT_NONE
        if certfile and keyfile:
            self.context.load_cert_chain(certfile=certfile, keyfile=keyfile)

    def send(self, cot_xml: str) -> None:
        with socket.create_connection((self.host, self.port), timeout=5) as sock:
            server_name = self.host if self.context.check_hostname else None
            with self.context.wrap_socket(sock, server_hostname=server_name) as ssock:
                ssock.sendall(cot_xml.encode("utf-8") + b"\n")


def load_config(path: str) -> BridgeConfig:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return BridgeConfig.model_validate(data)


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

    config_path = os.getenv("BRIDGE_CONFIG", "/configs/mqtt-cot-bridge.yaml")
    config = load_config(config_path)
    config_data = config.model_dump()

    site = os.getenv("SITE", config.site_default)
    mqtt_host = os.getenv("MQTT_HOST", "mqtt-broker")
    mqtt_port = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user = os.getenv("MQTT_USERNAME")
    mqtt_pass = os.getenv("MQTT_PASSWORD")

    tak_mode = os.getenv("TAK_MODE", "dev").lower()
    if tak_mode == "tak":
        sender = TlsTakSender(
            host=os.getenv("TAK_HOST", "freetakserver"),
            port=int(os.getenv("TAK_PORT", "8089")),
            cafile=os.getenv("TAK_TLS_CA", "/certs/ca.pem"),
            certfile=os.getenv("TAK_TLS_CERT", "/certs/server.pem"),
            keyfile=os.getenv("TAK_TLS_KEY", "/certs/server.key"),
            verify=os.getenv("TAK_TLS_VERIFY", "true").lower() == "true",
        )
        logging.info("TAK mode enabled: TLS socket to %s", os.getenv("TAK_HOST", "freetakserver"))
    else:
        sender = DevSinkSender(
            host=os.getenv("COT_SINK_HOST"),
            port=int(os.getenv("COT_SINK_PORT", "9001")),
            protocol=os.getenv("COT_SINK_PROTOCOL", "udp"),
        )
        logging.info("Dev mode enabled: CoT output to %s", os.getenv("COT_SINK_HOST", "stdout"))

    schema_registry = default_schema_registry()
    dedupe = DedupeCache(config.dedupe.max_entries, config.dedupe.window_s)
    meta_cache: Dict[str, Dict[str, Any]] = {}

    def on_connect(client: mqtt.Client, userdata: Any, flags: Dict[str, Any], rc: int) -> None:
        if rc != 0:
            logging.error("MQTT connect failed: rc=%s", rc)
            return
        base = f"farm/{site}"
        client.subscribe(f"{base}/tele/+/position")
        client.subscribe(f"{base}/evt/+/#")
        client.subscribe(f"{base}/meta/+", qos=1)
        logging.info("Subscribed to MQTT topics under %s", base)

    def on_message(client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except json.JSONDecodeError:
            logging.warning("Invalid JSON payload on %s", msg.topic)
            return

        msg_class = payload.get("class")
        schema_map = {
            "tele": "tele.v1.schema.json",
            "evt": "evt.v1.schema.json",
            "meta": "meta.v1.schema.json",
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

        if dedupe.seen(payload["id"]):
            logging.info("Duplicate message skipped: %s", payload["id"])
            return

        event_type = parse_event_type(msg.topic, payload) if msg_class == "evt" else None
        cot_xml = build_cot_xml(payload, meta_cache.get(asset_id), event_type, config_data)
        if not cot_xml:
            logging.warning("No location available for %s, skipping CoT", payload.get("id"))
            return

        try:
            sender.send(cot_xml)
        except Exception as exc:  # pylint: disable=broad-except
            logging.error("Failed to send CoT: %s", exc)

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
