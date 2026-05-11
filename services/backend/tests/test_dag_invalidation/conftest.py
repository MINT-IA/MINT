"""Phase 95 — shared fixtures for DAG invalidation tests."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any
import pytest

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


@pytest.fixture(scope="session")
def hash_parity_inputs() -> list[dict[str, Any]]:
    """50-fixture pack for Python<->Dart hash parity."""
    path = FIXTURES_DIR / "hash_parity_50.jsonl"
    with path.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


@pytest.fixture
def sample_profile_inputs() -> dict[str, Any]:
    """Canonical happy-path inputs for unit tests."""
    return {
        "canton": "VD",
        "age": 35,
        "salary": 80000.0,
        "gross_annual_3a": 7056.0,
        "marital_status": "single",
    }
