from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any, Callable

import paho.mqtt.client as mqtt

from .config import HubConfig


MessageCallback = Callable[[str, str], None]
AVAILABILITY_TOPIC = "hub/mesh/_bridge/availability"


class MQTTClient:
    def __init__(self, config: HubConfig, on_message_callback: MessageCallback) -> None:
        self._config = config
        self._on_message_callback = on_message_callback
        self._logger = logging.getLogger("hub_bridge.mqtt")

        self._client = mqtt.Client()

        if self._config.mqtt_username:
            self._client.username_pw_set(self._config.mqtt_username, self._config.mqtt_password)

        if self._config.mqtt_tls:
            self._client.tls_set(
                ca_certs=self._config.mqtt_tls_ca,
                certfile=self._config.mqtt_tls_cert,
                keyfile=self._config.mqtt_tls_key,
            )
            self._client.tls_insecure_set(self._config.mqtt_tls_insecure)

        self._client.will_set(
            AVAILABILITY_TOPIC,
            payload=json.dumps(
                {
                    "v": 1,
                    "contract": "hub.mesh.v1",
                    "service": "hub-bridge",
                    "status": "offline",
                },
                separators=(",", ":"),
                sort_keys=True,
            ),
            qos=1,
            retain=True,
        )

        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message
        self._client.reconnect_delay_set(min_delay=1, max_delay=30)

    def connect(self) -> None:
        self._logger.info(
            "Connecting to MQTT broker %s:%s",
            self._config.mqtt_broker_host,
            self._config.mqtt_broker_port,
        )
        self._client.connect(self._config.mqtt_broker_host, self._config.mqtt_broker_port, keepalive=60)

    def loop_forever(self) -> None:
        self._client.loop_forever()

    def publish_json(self, topic: str, payload: dict[str, Any], retain: bool = False, qos: int = 0) -> None:
        body = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        result = self._client.publish(topic=topic, payload=body, retain=retain, qos=qos)
        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            self._logger.error("MQTT publish failed topic=%s rc=%s", topic, result.rc)

    def _on_connect(self, client: mqtt.Client, userdata: Any, flags: dict[str, Any], rc: int) -> None:
        if rc != 0:
            self._logger.error("MQTT connect failed rc=%s", rc)
            return

        self.publish_json(
            AVAILABILITY_TOPIC,
            {
                "v": 1,
                "contract": "hub.mesh.v1",
                "service": "hub-bridge",
                "status": "online",
                "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            },
            retain=True,
            qos=1,
        )

        for topic in self._config.mqtt_sub_topics:
            client.subscribe(topic)
            self._logger.info("Subscribed to topic: %s", topic)

    def _on_message(self, client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        try:
            payload_text = msg.payload.decode("utf-8")
        except UnicodeDecodeError:
            self._logger.warning("Skipping non-UTF8 payload on topic=%s", msg.topic)
            return

        try:
            self._on_message_callback(msg.topic, payload_text)
        except Exception:  # pylint: disable=broad-except
            self._logger.exception("Unhandled message processing error topic=%s", msg.topic)
