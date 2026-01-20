import json
import logging
import os
from pathlib import Path
from typing import Any, Dict

import paho.mqtt.client as mqtt
import yaml
from pydantic import BaseModel, ConfigDict, Field

from farmstack.meshtastic import normalize_meshtastic
from farmstack.schema import default_schema_registry


class NormalizerConfig(BaseModel):
    model_config = ConfigDict(extra="allow")

    site_default: str = "farmstead"
    asset_kind_default: str = "meshtastic-node"
    asset_name_prefix: str = ""
    loc_defaults: Dict[str, float] = Field(default_factory=dict)
    ttl_s_default: int = 120


def load_config(path: str) -> NormalizerConfig:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return NormalizerConfig.model_validate(data)


def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    config_path = os.getenv("NORMALIZER_CONFIG", "/configs/meshtastic-normalizer.yaml")
    config = load_config(config_path)
    site = os.getenv("SITE", config.site_default)

    mqtt_host = os.getenv("MQTT_HOST", "mqtt-broker")
    mqtt_port = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user = os.getenv("MQTT_USERNAME")
    mqtt_pass = os.getenv("MQTT_PASSWORD")

    schema_registry = default_schema_registry()

    def on_connect(client: mqtt.Client, userdata: Any, flags: Dict[str, Any], rc: int) -> None:
        if rc != 0:
            logging.error("MQTT connect failed: rc=%s", rc)
            return
        base = f"farm/{site}/raw/meshtastic"
        client.subscribe(f"{base}/+/telemetry")
        client.subscribe(f"{base}/+/position")
        logging.info("Subscribed to Meshtastic raw topics under %s", base)

    def on_message(client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except json.JSONDecodeError:
            logging.warning("Invalid JSON payload on %s", msg.topic)
            return

        envelope = normalize_meshtastic(payload, site, config.model_dump())
        if not envelope:
            logging.warning("Unable to normalize payload on %s", msg.topic)
            return

        try:
            schema_registry.validate("tele.v1.schema.json", envelope)
        except ValueError as exc:
            logging.warning("Normalized payload failed schema: %s", exc)
            return

        asset_id = envelope.get("asset", {}).get("id")
        if not asset_id:
            logging.warning("Missing asset id after normalization")
            return

        topic = f"farm/{site}/tele/{asset_id}/position"
        client.publish(topic, json.dumps(envelope), qos=0, retain=False)
        logging.info("Published normalized telemetry for %s", asset_id)

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
