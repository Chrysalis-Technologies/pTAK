from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict

from jsonschema import Draft202012Validator, RefResolver


@dataclass
class SchemaRegistry:
    base_dir: Path

    def __post_init__(self) -> None:
        self._schemas: Dict[str, Dict[str, Any]] = {}
        self._validators: Dict[str, Draft202012Validator] = {}
        self._store: Dict[str, Dict[str, Any]] = {}
        self._load_schemas()

    def _load_schemas(self) -> None:
        for path in self.base_dir.glob("*.json"):
            schema = json.loads(path.read_text(encoding="utf-8"))
            schema_id = schema.get("$id", path.name)
            self._schemas[path.name] = schema
            self._store[schema_id] = schema
            self._store[path.name] = schema

    def validator(self, schema_filename: str) -> Draft202012Validator:
        if schema_filename not in self._validators:
            schema = self._schemas[schema_filename]
            resolver = RefResolver.from_schema(schema, store=self._store)
            self._validators[schema_filename] = Draft202012Validator(schema, resolver=resolver)
        return self._validators[schema_filename]

    def validate(self, schema_filename: str, payload: Dict[str, Any]) -> None:
        validator = self.validator(schema_filename)
        errors = sorted(validator.iter_errors(payload), key=lambda e: e.path)
        if errors:
            messages = "; ".join(error.message for error in errors)
            raise ValueError(f"schema validation failed: {messages}")


def default_schema_registry() -> SchemaRegistry:
    base_dir = Path(__file__).resolve().parents[1] / "contracts" / "schemas"
    return SchemaRegistry(base_dir=base_dir)