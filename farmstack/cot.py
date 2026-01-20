from __future__ import annotations

from typing import Any, Dict, Optional
import xml.etree.ElementTree as ET

from farmstack.time_utils import add_seconds


def _coalesce(*values: Optional[str]) -> Optional[str]:
    for value in values:
        if value:
            return value
    return None


def _format_float(value: float, precision: int) -> str:
    return f"{value:.{precision}f}"


def _resolve_loc(envelope: Dict[str, Any], meta: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if envelope.get("loc"):
        return envelope.get("loc")
    if meta and meta.get("loc"):
        return meta.get("loc")
    if meta and isinstance(meta.get("data"), dict) and meta["data"].get("loc"):
        return meta["data"].get("loc")
    return None


def _resolve_meta_tak(meta: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if not meta:
        return {}
    data = meta.get("data")
    if isinstance(data, dict):
        tak = data.get("tak")
        if isinstance(tak, dict):
            return tak
    return {}


def build_cot_xml(
    envelope: Dict[str, Any],
    meta: Optional[Dict[str, Any]],
    event_type: Optional[str],
    config: Dict[str, Any],
) -> Optional[str]:
    site = envelope.get("site")
    asset = envelope.get("asset", {})
    asset_id = asset.get("id")
    asset_kind = asset.get("kind")
    message_class = envelope.get("class")
    ts = envelope.get("ts")
    src = envelope.get("src", {})

    loc = _resolve_loc(envelope, meta)
    if not loc:
        return None

    tak_meta = _resolve_meta_tak(meta)
    defaults = config.get("cot_defaults", {})
    asset_kind_map = config.get("asset_kind_map", {})
    event_type_map = config.get("event_type_map", {})

    is_event = message_class == "evt"
    if is_event:
        uid = f"farm.{site}.alert.{asset_id}.{event_type}"
        event_cfg = event_type_map.get(event_type, {})
        cot_type = event_cfg.get("cot_type")
        if not cot_type:
            if event_type and ("geofence" in event_type or "breach" in event_type):
                cot_type = defaults.get("geofence_cot_type", "b-a-g")
            else:
                cot_type = defaults.get("alert_cot_type", "b-a")
    else:
        uid = _coalesce(tak_meta.get("uid"), f"farm.{site}.{asset_id}")
        kind_cfg = asset_kind_map.get(asset_kind, {})
        cot_type = _coalesce(
            tak_meta.get("cot_type"),
            kind_cfg.get("cot_type"),
            defaults.get("contact_cot_type", "a-f-G-U-C"),
        )

    how = defaults.get("how_machine", "m-g")
    if src.get("system") == "manual":
        how = defaults.get("how_manual", "h-e")

    ttl_s = envelope.get("ttl_s")
    if ttl_s is None:
        ttl_s = tak_meta.get("stale_s_default", defaults.get("stale_s_default", 300))

    stale = add_seconds(ts, int(ttl_s))

    callsign = _coalesce(
        tak_meta.get("callsign"),
        asset.get("name"),
        asset_id,
    )

    event = ET.Element(
        "event",
        {
            "version": "2.0",
            "uid": uid,
            "type": cot_type,
            "time": ts,
            "start": ts,
            "stale": stale,
            "how": how,
        },
    )

    point = ET.SubElement(
        event,
        "point",
        {
            "lat": _format_float(float(loc.get("lat")), 6),
            "lon": _format_float(float(loc.get("lon")), 6),
            "hae": _format_float(float(loc.get("hae_m", 0.0)), 1),
            "ce": _format_float(float(loc.get("ce_m", 9999999.0)), 1),
            "le": _format_float(float(loc.get("le_m", 9999999.0)), 1),
        },
    )
    _ = point

    detail = ET.SubElement(event, "detail")
    ET.SubElement(detail, "contact", {"callsign": callsign})

    if is_event and event_type:
        remarks_text = f"event_type={event_type} id={envelope.get('id')}"
        remarks = ET.SubElement(detail, "remarks")
        remarks.text = remarks_text

    return ET.tostring(event, encoding="utf-8", xml_declaration=False).decode("utf-8")