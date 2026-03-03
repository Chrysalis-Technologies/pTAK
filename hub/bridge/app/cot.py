from __future__ import annotations

import socket
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from typing import Any

DEFAULT_COT_TYPE = "a-f-G-U-C"
DEFAULT_STALE_SECONDS = 300


def _parse_iso_utc(value: str) -> datetime:
    parsed_value = value
    if parsed_value.endswith("Z"):
        parsed_value = f"{parsed_value[:-1]}+00:00"
    dt = datetime.fromisoformat(parsed_value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _format_iso_z(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_cot_xml(message: dict[str, Any], cot_type: str = DEFAULT_COT_TYPE, stale_seconds: int = DEFAULT_STALE_SECONDS) -> str | None:
    position = message.get("position")
    if not isinstance(position, dict):
        return None

    lat = position.get("lat")
    lon = position.get("lon")
    if lat is None or lon is None:
        return None

    timestamp_raw = message.get("timestamp")
    if not isinstance(timestamp_raw, str) or not timestamp_raw:
        return None

    event_time = _parse_iso_utc(timestamp_raw)
    stale_time = event_time + timedelta(seconds=stale_seconds)

    uid = str(message.get("uid", "")).strip()
    if not uid:
        return None

    callsign = str(message.get("callsign", message.get("node_id", uid)))

    event = ET.Element(
        "event",
        {
            "version": "2.0",
            "uid": uid,
            "type": cot_type,
            "time": _format_iso_z(event_time),
            "start": _format_iso_z(event_time),
            "stale": _format_iso_z(stale_time),
            "how": "m-g",
        },
    )

    ET.SubElement(
        event,
        "point",
        {
            "lat": f"{float(lat):.6f}",
            "lon": f"{float(lon):.6f}",
            "hae": "0.0",
            "ce": "9999999.0",
            "le": "9999999.0",
        },
    )

    detail = ET.SubElement(event, "detail")
    ET.SubElement(detail, "contact", {"callsign": callsign})

    return ET.tostring(event, encoding="utf-8", xml_declaration=False).decode("utf-8")


def send_cot_udp(cot_xml: str, host: str, port: int) -> None:
    payload = cot_xml.encode("utf-8")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(payload, (host, port))
