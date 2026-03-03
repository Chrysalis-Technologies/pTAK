from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping, MutableMapping


def _now_utc_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _to_utc_iso(dt: datetime) -> str:
    utc_dt = dt.astimezone(timezone.utc)
    return utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_timestamp(raw: Any, logger: Any) -> tuple[str | None, str | None]:
    if raw is None:
        return _now_utc_iso(), None

    if isinstance(raw, bool):
        return None, "timestamp type bool is not supported"

    if isinstance(raw, (int, float)):
        try:
            parsed = datetime.fromtimestamp(float(raw), tz=timezone.utc)
            return _to_utc_iso(parsed), None
        except (OverflowError, OSError, ValueError):
            logger.warning("Invalid epoch timestamp value '%s'; using current UTC time", raw)
            return _now_utc_iso(), None

    if isinstance(raw, str):
        value = raw.strip()
        if not value:
            logger.warning("Empty timestamp string; using current UTC time")
            return _now_utc_iso(), None

        if value.endswith("Z"):
            value = f"{value[:-1]}+00:00"

        try:
            parsed = datetime.fromisoformat(value)
        except ValueError:
            logger.warning("Invalid ISO8601 timestamp '%s'; using current UTC time", raw)
            return _now_utc_iso(), None

        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return _to_utc_iso(parsed), None

    return None, f"timestamp type {type(raw).__name__} is not supported"


def _parse_meshtastic_topic(topic: str) -> tuple[str | None, str | None, str | None]:
    parts = topic.split("/")
    if len(parts) != 3 or parts[0] != "meshtastic":
        return None, None, "topic must match meshtastic/<node_id>/telemetry or meshtastic/<node_id>/position"

    node_id = parts[1].strip()
    message_type = parts[2].strip()
    if not node_id:
        return None, None, "node_id in topic cannot be empty"

    if message_type not in {"telemetry", "position"}:
        return None, None, "message type in topic must be telemetry or position"

    return node_id, message_type, None


def _to_float(value: Any, field_name: str, logger: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool):
        logger.warning("Ignoring boolean value for numeric field %s", field_name)
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        logger.warning("Ignoring non-numeric value for field %s: %s", field_name, value)
        return None


def _to_int(value: Any, field_name: str, logger: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        logger.warning("Ignoring boolean value for integer field %s", field_name)
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        logger.warning("Ignoring non-integer value for field %s: %s", field_name, value)
        return None


def normalize_message(
    topic: str,
    payload: Mapping[str, Any],
    position_cache: MutableMapping[str, dict[str, float]],
    logger: Any,
) -> tuple[dict[str, Any] | None, str | None]:
    if not isinstance(payload, Mapping):
        return None, "payload must be a JSON object"

    node_id, message_type, topic_error = _parse_meshtastic_topic(topic)
    if topic_error:
        return None, topic_error

    timestamp_raw = payload.get("timestamp", payload.get("ts"))
    timestamp, timestamp_error = _parse_timestamp(timestamp_raw, logger)
    if timestamp_error:
        return None, timestamp_error

    raw_callsign = payload.get("callsign")
    if isinstance(raw_callsign, str) and raw_callsign.strip():
        callsign = raw_callsign.strip()
    else:
        callsign = str(node_id)

    lat = _to_float(payload.get("lat"), "lat", logger)
    lon = _to_float(payload.get("lon"), "lon", logger)
    speed = _to_float(payload.get("speed"), "speed", logger)
    course = _to_float(payload.get("course"), "course", logger)

    temperature_c = _to_float(payload.get("temperature_c", payload.get("temp")), "temperature_c", logger)
    humidity_pct = _to_float(payload.get("humidity_pct", payload.get("humidity")), "humidity_pct", logger)
    pressure_hpa = _to_float(payload.get("pressure_hpa", payload.get("pressure")), "pressure_hpa", logger)
    rssi_dbm = _to_float(payload.get("rssi_dbm", payload.get("rssi")), "rssi_dbm", logger)
    snr_db = _to_float(payload.get("snr_db", payload.get("snr")), "snr_db", logger)
    hops_away = _to_int(payload.get("hops_away"), "hops_away", logger)
    hop_limit = _to_int(payload.get("hop_limit"), "hop_limit", logger)
    channel_utilization_pct = _to_float(
        payload.get("channel_utilization_pct", payload.get("channel_utilization")),
        "channel_utilization_pct",
        logger,
    )
    air_util_tx_pct = _to_float(payload.get("air_util_tx_pct"), "air_util_tx_pct", logger)

    if lat is not None and lon is not None:
        position_cache[str(node_id)] = {"lat": lat, "lon": lon}
        position_from_cache = False
    else:
        cached = position_cache.get(str(node_id))
        if cached:
            lat = cached["lat"]
            lon = cached["lon"]
            position_from_cache = True
        else:
            lat = None
            lon = None
            position_from_cache = False

    normalized: dict[str, Any] = {
        "uid": f"meshtastic-{node_id}",
        "node_id": str(node_id),
        "callsign": callsign,
        "message_type": str(message_type),
        "timestamp": timestamp,
        "last_seen": _now_utc_iso(),
        "source_topic": topic,
        "position_from_cache": position_from_cache,
    }

    position: dict[str, Any] = {}
    if lat is not None:
        position["lat"] = lat
    if lon is not None:
        position["lon"] = lon
    if speed is not None:
        position["speed"] = speed
    if course is not None:
        position["course"] = course
    if position:
        normalized["position"] = position

    telemetry: dict[str, Any] = {}
    if temperature_c is not None:
        telemetry["temperature_c"] = temperature_c
    if humidity_pct is not None:
        telemetry["humidity_pct"] = humidity_pct
    if pressure_hpa is not None:
        telemetry["pressure_hpa"] = pressure_hpa
    if telemetry:
        normalized["telemetry"] = telemetry

    link: dict[str, Any] = {}
    if rssi_dbm is not None:
        link["rssi_dbm"] = rssi_dbm
    if snr_db is not None:
        link["snr_db"] = snr_db
    if hops_away is not None:
        link["hops_away"] = hops_away
    if hop_limit is not None:
        link["hop_limit"] = hop_limit
    if channel_utilization_pct is not None:
        link["channel_utilization_pct"] = channel_utilization_pct
    if air_util_tx_pct is not None:
        link["air_util_tx_pct"] = air_util_tx_pct
    if link:
        normalized["link"] = link

    return normalized, None
