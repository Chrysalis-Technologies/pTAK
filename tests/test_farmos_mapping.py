import json
from pathlib import Path

import yaml

from farmstack.farmos import build_log_payload, resolve_log_type


def test_farmos_log_type_mapping() -> None:
    config = yaml.safe_load(Path("configs/mqtt-farmos-logger.yaml").read_text(encoding="utf-8"))

    assert resolve_log_type("gate.open", config) == "observation"
    assert resolve_log_type("security.breach", config) == "observation"
    assert resolve_log_type("irrigation.start", config) == "activity"
    assert resolve_log_type("unknown.event", config) == "observation"


def test_farmos_payload_includes_asset_link() -> None:
    envelope = json.loads(Path("contracts/examples/evt.gate-open.json").read_text(encoding="utf-8"))
    meta = json.loads(Path("contracts/examples/meta.gate-east.json").read_text(encoding="utf-8"))

    payload = build_log_payload(envelope, "gate.open", "observation", meta)

    relationships = payload.get("data", {}).get("relationships", {})
    assert "asset" in relationships