import json
from pathlib import Path

import yaml

from farmstack.cot import build_cot_xml


def test_cot_position_golden() -> None:
    envelope = json.loads(Path("contracts/examples/tele.position.json").read_text(encoding="utf-8"))
    config = yaml.safe_load(Path("configs/mqtt-cot-bridge.yaml").read_text(encoding="utf-8"))

    cot_xml = build_cot_xml(envelope, None, None, config)
    expected = Path("tests/fixtures/cot_position.xml").read_text(encoding="utf-8").strip()

    assert cot_xml == expected