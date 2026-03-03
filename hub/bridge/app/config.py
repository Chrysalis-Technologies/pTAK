from __future__ import annotations

import os
from dataclasses import dataclass
from typing import List


class ConfigError(RuntimeError):
    """Raised when required hub-bridge configuration is invalid."""


@dataclass(frozen=True)
class HubConfig:
    mqtt_broker_host: str
    mqtt_broker_port: int
    mqtt_username: str | None
    mqtt_password: str | None
    mqtt_tls: bool
    mqtt_tls_ca: str | None
    mqtt_tls_cert: str | None
    mqtt_tls_key: str | None
    mqtt_tls_insecure: bool
    mqtt_sub_topics: List[str]
    mqtt_pub_prefix: str
    tak_cot_udp_host: str
    tak_cot_udp_port: int
    ha_mqtt_prefix: str
    log_level: str
    http_port: int


def _required_env(name: str, errors: List[str]) -> str:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        errors.append(f"{name} is required and cannot be empty.")
        return ""
    return raw.strip()


def _optional_env(name: str) -> str | None:
    raw = os.getenv(name)
    if raw is None:
        return None

    value = raw.strip()
    return value if value else None


def _parse_port(name: str, raw: str, errors: List[str]) -> int:
    try:
        value = int(raw)
    except (TypeError, ValueError):
        errors.append(f"{name} must be an integer between 1 and 65535.")
        return 0

    if not 1 <= value <= 65535:
        errors.append(f"{name} must be in range 1..65535 (got {value}).")
        return 0
    return value


def _parse_bool(name: str, raw: str, errors: List[str]) -> bool:
    value = raw.strip().lower()
    if value in {"1", "true", "yes", "on"}:
        return True
    if value in {"0", "false", "no", "off"}:
        return False

    errors.append(f"{name} must be a boolean value (true/false).")
    return False


def load_config() -> HubConfig:
    errors: List[str] = []

    mqtt_broker_host = _required_env("MQTT_BROKER_HOST", errors)
    mqtt_broker_port_raw = _required_env("MQTT_BROKER_PORT", errors)
    mqtt_username = _optional_env("MQTT_USERNAME")
    mqtt_password = _optional_env("MQTT_PASSWORD")
    mqtt_tls = _parse_bool("MQTT_TLS", os.getenv("MQTT_TLS", "false"), errors)
    mqtt_tls_ca = _optional_env("MQTT_TLS_CA")
    mqtt_tls_cert = _optional_env("MQTT_TLS_CERT")
    mqtt_tls_key = _optional_env("MQTT_TLS_KEY")
    mqtt_tls_insecure = _parse_bool("MQTT_TLS_INSECURE", os.getenv("MQTT_TLS_INSECURE", "false"), errors)
    mqtt_sub_topics_raw = _required_env("MQTT_SUB_TOPICS", errors)
    mqtt_pub_prefix = _required_env("MQTT_PUB_PREFIX", errors)
    tak_cot_udp_host = _required_env("TAK_COT_UDP_HOST", errors)
    tak_cot_udp_port_raw = _required_env("TAK_COT_UDP_PORT", errors)
    ha_mqtt_prefix = _required_env("HA_MQTT_PREFIX", errors)
    log_level = _required_env("LOG_LEVEL", errors).upper()

    http_port_raw = os.getenv("HTTP_PORT", "8080").strip()

    mqtt_broker_port = _parse_port("MQTT_BROKER_PORT", mqtt_broker_port_raw, errors)
    tak_cot_udp_port = _parse_port("TAK_COT_UDP_PORT", tak_cot_udp_port_raw, errors)
    http_port = _parse_port("HTTP_PORT", http_port_raw, errors)

    mqtt_sub_topics = [topic.strip() for topic in mqtt_sub_topics_raw.split(",") if topic.strip()]
    if not mqtt_sub_topics:
        errors.append("MQTT_SUB_TOPICS must contain at least one topic.")

    if mqtt_username and not mqtt_password:
        errors.append("MQTT_PASSWORD is required when MQTT_USERNAME is set.")
    if mqtt_password and not mqtt_username:
        errors.append("MQTT_USERNAME is required when MQTT_PASSWORD is set.")

    if mqtt_tls and not mqtt_tls_ca:
        errors.append("MQTT_TLS_CA is required when MQTT_TLS is true.")

    if bool(mqtt_tls_cert) != bool(mqtt_tls_key):
        errors.append("MQTT_TLS_CERT and MQTT_TLS_KEY must either both be set or both be empty.")

    if errors:
        formatted = "\n".join(f"- {item}" for item in errors)
        raise ConfigError(f"Invalid hub-bridge configuration:\n{formatted}")

    return HubConfig(
        mqtt_broker_host=mqtt_broker_host,
        mqtt_broker_port=mqtt_broker_port,
        mqtt_username=mqtt_username,
        mqtt_password=mqtt_password,
        mqtt_tls=mqtt_tls,
        mqtt_tls_ca=mqtt_tls_ca,
        mqtt_tls_cert=mqtt_tls_cert,
        mqtt_tls_key=mqtt_tls_key,
        mqtt_tls_insecure=mqtt_tls_insecure,
        mqtt_sub_topics=mqtt_sub_topics,
        mqtt_pub_prefix=mqtt_pub_prefix,
        tak_cot_udp_host=tak_cot_udp_host,
        tak_cot_udp_port=tak_cot_udp_port,
        ha_mqtt_prefix=ha_mqtt_prefix,
        log_level=log_level,
        http_port=http_port,
    )
