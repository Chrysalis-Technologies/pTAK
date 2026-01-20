from __future__ import annotations

from typing import Any, Dict, Optional


def resolve_log_type(event_type: str, config: Dict[str, Any]) -> str:
    exact = config.get("exact_event_map", {})
    prefix = config.get("prefix_event_map", {})
    if event_type in exact:
        return exact[event_type]
    for prefix_key, log_type in prefix.items():
        if event_type.startswith(prefix_key):
            return log_type
    return config.get("log_type_default", "observation")


def _resolve_farmos_asset_uuid(meta: Optional[Dict[str, Any]]) -> Optional[str]:
    if not meta:
        return None
    data = meta.get("data")
    if not isinstance(data, dict):
        return None
    links = data.get("links")
    if not isinstance(links, dict):
        return None
    return links.get("farmos_asset_uuid")


def build_log_payload(
    envelope: Dict[str, Any],
    event_type: str,
    log_type: str,
    meta: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    message = envelope.get("data", {}).get("message", "")
    asset_uuid = _resolve_farmos_asset_uuid(meta)

    payload: Dict[str, Any] = {
        "data": {
            "type": f"log--{log_type}",
            "attributes": {
                "name": event_type,
                "timestamp": envelope.get("ts"),
                "status": "done",
                "notes": message,
                "data": envelope,
            },
        }
    }

    if asset_uuid:
        payload["data"]["relationships"] = {
            "asset": {
                "data": [
                    {
                        "type": "asset--asset",
                        "id": asset_uuid,
                    }
                ]
            }
        }

    return payload