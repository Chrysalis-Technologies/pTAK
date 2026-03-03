from __future__ import annotations

import json
import logging
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .config import ConfigError, HubConfig, load_config
from .cot import build_cot_xml, send_cot_udp
from .ha_publish import publish_topics
from .mqtt_client import MQTTClient
from .normalize import normalize_message


class _HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            body = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(404)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        return


def _start_health_server(port: int, logger: logging.Logger) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(("0.0.0.0", port), _HealthHandler)
    thread = threading.Thread(target=server.serve_forever, name="health-server", daemon=True)
    thread.start()
    logger.info("Health endpoint listening on http://0.0.0.0:%s/health", port)
    return server


def _configure_logging(level_name: str) -> None:
    level = getattr(logging, level_name.upper(), logging.INFO)
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(name)s %(message)s")


def run(config: HubConfig) -> None:
    logger = logging.getLogger("hub_bridge")
    position_cache: dict[str, dict[str, float]] = {}

    _start_health_server(config.http_port, logger)

    def on_message(topic: str, payload_text: str) -> None:
        try:
            payload_obj = json.loads(payload_text)
        except json.JSONDecodeError:
            logger.warning("Skipping invalid JSON payload topic=%s", topic)
            return

        normalized, error = normalize_message(topic, payload_obj, position_cache, logger)
        if error:
            logger.warning("Skipping message topic=%s reason=%s", topic, error)
            return

        logger.info(
            "Normalized message node_id=%s type=%s topic=%s",
            normalized["node_id"],
            normalized["message_type"],
            topic,
        )

        cot_xml = build_cot_xml(normalized)
        if cot_xml:
            try:
                send_cot_udp(cot_xml, config.tak_cot_udp_host, config.tak_cot_udp_port)
                logger.info(
                    "CoT sent uid=%s destination=%s:%s",
                    normalized["uid"],
                    config.tak_cot_udp_host,
                    config.tak_cot_udp_port,
                )
            except OSError as exc:
                logger.error("Failed to send CoT uid=%s error=%s", normalized["uid"], exc)
        else:
            logger.info("CoT skipped uid=%s reason=missing position", normalized["uid"])

        publish_topics(
            client=mqtt_client,
            message=normalized,
            mqtt_pub_prefix=config.mqtt_pub_prefix,
            ha_mqtt_prefix=config.ha_mqtt_prefix,
        )
        logger.info("HA/MQTT topics published node_id=%s", normalized["node_id"])

    mqtt_client = MQTTClient(config=config, on_message_callback=on_message)
    mqtt_client.connect()
    mqtt_client.loop_forever()


def main() -> None:
    try:
        config = load_config()
    except ConfigError as exc:
        raise SystemExit(str(exc)) from exc

    _configure_logging(config.log_level)
    run(config)


if __name__ == "__main__":
    main()
