#!/usr/bin/env python3
"""Fail-closed preflight for the final G1 runtime ticket."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EVIDENCE = ROOT / ".planning/runtime-evidence/phase-37/ticket-evidence.json"
TICKET_REGISTRY = ROOT / ".planning/goals/G1-blocking-gate-tickets.md"


def _canonical_ticket_ids() -> tuple[set[str], list[str]]:
    ticket_ids = re.findall(
        r"(?m)^\| (G1-[A-Z0-9]+(?:-[A-Z0-9]+)*) \|",
        TICKET_REGISTRY.read_text(encoding="utf-8"),
    )
    errors: list[str] = []
    if len(ticket_ids) != 31:
        errors.append(
            f"canonical registry must contain 31 ticket rows, found {len(ticket_ids)}"
        )
    counts = Counter(ticket_ids)
    duplicates = sorted(ticket_id for ticket_id, count in counts.items() if count != 1)
    if duplicates:
        errors.append(
            "canonical registry ticket IDs must be unique: " + ", ".join(duplicates)
        )
    return set(ticket_ids), errors


def validate_records(records: list[dict[str, Any]]) -> list[str]:
    """Return validation failures for a candidate runtime evidence set."""
    errors: list[str] = []
    ticket_ids = [record.get("ticket_id") for record in records]
    valid_ticket_ids = [
        ticket_id for ticket_id in ticket_ids if isinstance(ticket_id, str)
    ]
    counts = Counter(valid_ticket_ids)
    expected_ids, registry_errors = _canonical_ticket_ids()
    errors.extend(registry_errors)

    if len(records) != 31:
        errors.append(f"expected 31 ticket records, found {len(records)}")

    invalid_ids = [
        ticket_id for ticket_id in ticket_ids if not isinstance(ticket_id, str)
    ]
    if invalid_ids:
        errors.append("every ticket_id must be a string")

    duplicates = sorted(
        str(ticket_id) for ticket_id, count in counts.items() if count != 1
    )
    if duplicates:
        errors.append(f"ticket IDs must be unique: {', '.join(duplicates)}")

    actual_ids = set(valid_ticket_ids)
    missing = sorted(expected_ids - actual_ids)
    unexpected = sorted(actual_ids - expected_ids)
    if missing:
        errors.append("missing canonical ticket IDs: " + ", ".join(missing))
    if unexpected:
        errors.append("unexpected ticket IDs: " + ", ".join(unexpected))

    by_id = {
        record["ticket_id"]: record
        for record in records
        if isinstance(record.get("ticket_id"), str)
    }
    runtime = by_id.get("G1-RUNTIME-01")
    if runtime is None:
        errors.append("G1-RUNTIME-01 is missing")
    elif runtime.get("state") != "red_proven":
        errors.append("G1-RUNTIME-01 must be the only red_proven record")

    non_green = sorted(
        ticket_id
        for ticket_id, record in by_id.items()
        if ticket_id != "G1-RUNTIME-01" and record.get("state") != "green"
    )
    if non_green:
        errors.append("all non-runtime tickets must be green: " + ", ".join(non_green))

    green_count = sum(record.get("state") == "green" for record in records)
    red_ids = sorted(
        str(record.get("ticket_id"))
        for record in records
        if record.get("state") == "red_proven"
    )
    if green_count != 30:
        errors.append(f"expected 30 green records, found {green_count}")
    if red_ids != ["G1-RUNTIME-01"]:
        errors.append(
            "expected only G1-RUNTIME-01 red_proven, found "
            + (", ".join(red_ids) or "none")
        )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    args = parser.parse_args()
    payload = json.loads(args.evidence.read_text(encoding="utf-8"))
    errors = validate_records(payload.get("tickets", []))
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print("PASS: G1 runtime preflight is exactly 30/31 GREEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
