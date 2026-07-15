from __future__ import annotations

import copy
import re
from pathlib import Path

from tools.checks.g1_runtime_preflight import validate_records


RUNTIME_ID = "G1-RUNTIME-01"
ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / ".planning/goals/G1-blocking-gate-tickets.md"


def _expected_ids() -> set[str]:
    ids = set(
        re.findall(
            r"(?m)^\| (G1-[A-Z0-9]+(?:-[A-Z0-9]+)*) \|",
            REGISTRY.read_text(encoding="utf-8"),
        )
    )
    assert len(ids) == 31
    return ids


def _valid_records() -> list[dict[str, str]]:
    records = [
        {"ticket_id": ticket_id, "state": "green"}
        for ticket_id in sorted(_expected_ids() - {RUNTIME_ID})
    ]
    records.append({"ticket_id": RUNTIME_ID, "state": "red_proven"})
    return records


def test_accepts_exactly_thirty_green_with_only_runtime_red() -> None:
    assert validate_records(_valid_records()) == []


def test_rejects_missing_record() -> None:
    records = _valid_records()[:-1]
    assert validate_records(records)


def test_rejects_duplicate_ticket_id() -> None:
    records = _valid_records()
    records[-1] = copy.deepcopy(records[0])
    assert validate_records(records)


def test_rejects_ticket_only_state() -> None:
    records = _valid_records()
    records[0]["state"] = "ticket_only"
    assert validate_records(records)


def test_rejects_runtime_already_green() -> None:
    records = _valid_records()
    records[-1]["state"] = "green"
    assert validate_records(records)


def test_rejects_non_runtime_red() -> None:
    records = _valid_records()
    records[0]["state"] = "red_proven"
    records[-1]["state"] = "green"
    assert validate_records(records)


def test_rejects_substituted_non_registry_ticket() -> None:
    records = _valid_records()
    records[0]["ticket_id"] = "G1-FAKE-01"
    assert validate_records(records)
