import json
from pathlib import Path

import yaml

from farmstack.meshtastic import normalize_meshtastic


def test_meshtastic_normalizer_fixture() -> None:
    raw = json.loads(
        Path("services/meshtastic-normalizer/fixtures/raw.json").read_text(encoding="utf-8")
    )
    config = yaml.safe_load(Path("configs/meshtastic-normalizer.yaml").read_text(encoding="utf-8"))

    envelope = normalize_meshtastic(raw, "farmstead", config)
    expected = json.loads(
        Path("services/meshtastic-normalizer/fixtures/canonical.json").read_text(encoding="utf-8")
    )

    assert envelope == expected