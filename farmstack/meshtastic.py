from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import uuid4

from farmstack.time_utils import format_ts


def normalize_meshtastic(
    raw: Dict[str, Any],
    site: str,
    config: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    payload = raw.get("payload", {})
    lat = payload.get("latitude")
    lon = payload.get("longitude")
    if lat is None or lon is None:
        return None

    ts = raw.get("ts") or raw.get("timestamp")
    if not ts:
        ts = format_ts(datetime.now(tz=timezone.utc))

    asset_id = raw.get("node") or raw.get("from")
    if not asset_id:
        return None

    asset_kind = config.get("asset_kind_default", "meshtastic-node")
    name_prefix = config.get("asset_name_prefix", "")
    loc_defaults = config.get("loc_defaults", {})

    message_id = raw.get("id") or str(uuid4())

    envelope = {
        "v": 1,
        "id": message_id,
        "ts": ts,
        "site": site,
        "class": "tele",
        "asset": {
            "id": asset_id,
            "kind": asset_kind,
            "name": f"{name_prefix}{asset_id}" if name_prefix else asset_id,
        },
        "src": {
            "system": "meshtastic",
            "id": raw.get("from"),
        },
        "loc": {
            "lat": float(lat),
            "lon": float(lon),
            "hae_m": float(payload.get("altitude", 0.0)),
            "ce_m": float(loc_defaults.get("ce_m", 10.0)),
            "le_m": float(loc_defaults.get("le_m", 15.0)),
        },
        "ttl_s": int(config.get("ttl_s_default", 120)),
        "data": {
            "stream": "position",
            "metrics": {
                "battery_pct": payload.get("battery_level"),
                "rssi_dbm": payload.get("rssi"),
            },
        },
    }

    return envelope
