from __future__ import annotations

from typing import Any

from .mqtt_client import MQTTClient

CONTRACT_VERSION = 1
CONTRACT_NAME = "hub.mesh.v1"


def _publish_legacy_topics(client: MQTTClient, message: dict[str, Any], mqtt_pub_prefix: str, ha_mqtt_prefix: str) -> None:
    node_id = message["node_id"]
    message_type = message["message_type"]

    normalized_topic = f"{mqtt_pub_prefix}/normalized/{node_id}/{message_type}"
    client.publish_json(normalized_topic, message, retain=False, qos=0)

    state_topic = f"{ha_mqtt_prefix}/{node_id}/state"
    state_payload = {
        "uid": message.get("uid"),
        "node_id": node_id,
        "callsign": message.get("callsign"),
        "timestamp": message.get("timestamp"),
        "last_seen": message.get("last_seen"),
        "message_type": message_type,
        "position": message.get("position"),
        "telemetry": message.get("telemetry"),
        "link": message.get("link"),
        "source_topic": message.get("source_topic"),
        "position_from_cache": message.get("position_from_cache", False),
    }
    client.publish_json(state_topic, state_payload, retain=True, qos=0)

    telemetry = message.get("telemetry")
    if isinstance(telemetry, dict) and telemetry:
        telemetry_topic = f"{ha_mqtt_prefix}/{node_id}/telemetry"
        telemetry_payload = {"timestamp": message.get("timestamp"), **telemetry}
        client.publish_json(telemetry_topic, telemetry_payload, retain=True, qos=0)

    position = message.get("position")
    if isinstance(position, dict) and ("lat" in position and "lon" in position):
        position_topic = f"{ha_mqtt_prefix}/{node_id}/position"
        position_payload = {"timestamp": message.get("timestamp"), **position}
        client.publish_json(position_topic, position_payload, retain=True, qos=0)


def _publish_contract_topics(client: MQTTClient, message: dict[str, Any]) -> None:
    node_id = message["node_id"]
    base_topic = f"hub/mesh/{node_id}"
    base_payload = {
        "v": CONTRACT_VERSION,
        "contract": CONTRACT_NAME,
        "node_id": node_id,
        "uid": message.get("uid"),
        "callsign": message.get("callsign"),
        "ts": message.get("timestamp"),
        "last_seen": message.get("last_seen"),
        "source_topic": message.get("source_topic"),
    }

    telemetry = message.get("telemetry")
    if isinstance(telemetry, dict) and telemetry:
        telemetry_payload = {**base_payload, **telemetry}
        client.publish_json(f"{base_topic}/telemetry", telemetry_payload, retain=True, qos=1)

    link_payload: dict[str, Any] = {**base_payload, "status": "online"}
    link = message.get("link")
    if isinstance(link, dict) and link:
        link_payload.update(link)
    client.publish_json(f"{base_topic}/link", link_payload, retain=True, qos=1)

    position = message.get("position")
    if isinstance(position, dict) and ("lat" in position and "lon" in position):
        position_payload = {
            **base_payload,
            "lat": position.get("lat"),
            "lon": position.get("lon"),
            "position_from_cache": bool(message.get("position_from_cache", False)),
        }
        if "speed" in position:
            position_payload["speed_mps"] = position.get("speed")
        if "course" in position:
            position_payload["course_deg"] = position.get("course")
        client.publish_json(f"{base_topic}/position", position_payload, retain=True, qos=1)


def publish_topics(client: MQTTClient, message: dict[str, Any], mqtt_pub_prefix: str, ha_mqtt_prefix: str) -> None:
    _publish_legacy_topics(client, message, mqtt_pub_prefix, ha_mqtt_prefix)
    _publish_contract_topics(client, message)
