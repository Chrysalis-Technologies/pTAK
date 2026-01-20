from __future__ import annotations

from datetime import datetime, timedelta, timezone


def parse_ts(ts: str) -> datetime:
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


def format_ts(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def add_seconds(ts: str, seconds: int) -> str:
    return format_ts(parse_ts(ts) + timedelta(seconds=seconds))