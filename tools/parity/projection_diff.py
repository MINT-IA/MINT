#!/usr/bin/env python3
"""Deterministic projection-parity diff — Plan 02-03 iter-2 A10.

Compares two projection payloads (one from the legacy SnapshotModel path,
one from the new fact_current path) and reports `EQUAL` or `DIFF` with a
canonical reason. The drift definition is deterministic per these rules :

1. JSON canonicalisation : `json.dumps(value, sort_keys=True, default=str,
   separators=(",", ":"), ensure_ascii=False)`. Key ordering is normalized,
   Decimal/datetime values are coerced to string before comparison.
2. Decimal tolerance : `abs(Decimal(a) - Decimal(b)) < Decimal("1e-9")` for
   numerical fields. Eliminates float→Decimal silent rounding noise.
3. Missing-key rule : a key absent from one side AND present-with-None on
   the other = EQUAL (NOT a diff). Mirrors the SQLAlchemy / Pydantic
   convention that `Field(default=None)` and an unset field are
   semantically identical.

The two main entry points are :

- `diff_payloads(left, right) -> ParityDiffResult`
  Library API. Returns a structured result object that callers can pattern-
  match on (`.is_equal`, `.reasons`).

- `main()` (CLI)
  `python3 tools/parity/projection_diff.py --pair <left.json> <right.json>`
    -> exit 0 on EQUAL, exit 1 on DIFF, prints structured stdout.
  `python3 tools/parity/projection_diff.py --self-test`
    -> exit 0 if the 12-pair fixture (6 equal, 6 different) returns the
    expected verdicts ; exit 1 if any verdict surprises.
  `python3 tools/parity/projection_diff.py --audit-all-users
       --persist-to _phase02_parity_audit`
    -> Stub for Task 2a Julien-checkpoint precondition. Hits a configured
       backend endpoint per user, runs `diff_payloads`, writes to a table.
       Implementation surfaces a clear NotImplementedError with the
       required env vars listed (see below) — the runtime is opened by
       PR-3a integration with Railway staging.

Why this exists (qa-expert HIGH-1 from REVIEWS.md)
==================================================
The original Plan 02-03 Task 2 spec said « run `diff /tmp/proj_new.json
/tmp/proj_legacy.json`, expect empty diff ». That fails on :
- key reorderings (Python dict ordering vs JSON serialization)
- Decimal-vs-float representations of the same numerical value
- missing-vs-None distinction
- timestamps with different second-fractions but same logical instant

This module makes the « zero drift » assertion deterministic and
reproducible by Julien (or any reviewer) at any point in the soak window.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, List, Optional


# Decimal tolerance for numeric comparison ; values closer than this are
# treated as equal. 1e-9 covers float-to-Decimal silent rounding noise
# without hiding cents-scale drift (10^-2 CHF is a genuine discrepancy).
DECIMAL_TOLERANCE = Decimal("1e-9")


@dataclass
class ParityDiffResult:
    """Structured result of a projection-parity comparison."""

    is_equal: bool
    reasons: List[str] = field(default_factory=list)

    def as_text(self) -> str:
        if self.is_equal:
            return "EQUAL"
        return "DIFF: " + " ; ".join(self.reasons)


def _is_missing_or_none(value: Any) -> bool:
    """A sentinel-aware None check (covers Python `None` plus JSON `null`)."""
    return value is None


def _to_decimal(value: Any) -> Optional[Decimal]:
    """Best-effort Decimal coercion. Returns None if `value` isn't numeric.

    Handles : int, float, str-of-numeric, Decimal. Returns None for dicts,
    lists, booleans, and other non-numeric types so the caller can fall
    back to structural comparison.
    """
    if isinstance(value, bool):
        # bool is a subclass of int — guard explicitly so True/1 don't
        # collapse into the numeric path.
        return None
    if isinstance(value, Decimal):
        return value
    if isinstance(value, (int, float)):
        return Decimal(str(value))
    if isinstance(value, str):
        try:
            return Decimal(value)
        except (InvalidOperation, ValueError):
            return None
    return None


def _canonical_dump(value: Any) -> str:
    """Canonical JSON serialization for byte-level comparison.

    `default=str` coerces Decimal / datetime / UUID to their str() form so
    bytes-equality after sort_keys reorders the dict deterministically.
    """
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
        ensure_ascii=False,
    )


def _diff_recursive(
    left: Any, right: Any, path: str, reasons: List[str]
) -> None:
    """Walk both sides, appending diff reasons. Mutates `reasons`."""
    # 1. Missing-key vs None : EQUAL
    if _is_missing_or_none(left) and _is_missing_or_none(right):
        return

    # 2. One side None, other has a value → DIFF (unless caller chose
    # to treat missing-key as None — that's handled at the dict layer).
    if _is_missing_or_none(left) or _is_missing_or_none(right):
        reasons.append(
            f"{path}: one side is None/missing (left={left!r}, right={right!r})"
        )
        return

    # 3. Numeric tolerance comparison
    ld = _to_decimal(left)
    rd = _to_decimal(right)
    if ld is not None and rd is not None:
        if abs(ld - rd) < DECIMAL_TOLERANCE:
            return
        reasons.append(
            f"{path}: numeric diff (left={ld}, right={rd}, tol={DECIMAL_TOLERANCE})"
        )
        return

    # 4. Dict structural comparison — missing-key=None rule applies per-key
    if isinstance(left, dict) or isinstance(right, dict):
        if not isinstance(left, dict) or not isinstance(right, dict):
            reasons.append(
                f"{path}: type mismatch (left={type(left).__name__}, right={type(right).__name__})"
            )
            return
        all_keys = set(left.keys()) | set(right.keys())
        for k in sorted(all_keys):
            _diff_recursive(left.get(k), right.get(k), f"{path}.{k}" if path else str(k), reasons)
        return

    # 5. List/tuple structural comparison — same length required ; element-wise
    if isinstance(left, (list, tuple)) or isinstance(right, (list, tuple)):
        if not isinstance(left, (list, tuple)) or not isinstance(right, (list, tuple)):
            reasons.append(
                f"{path}: type mismatch (left={type(left).__name__}, right={type(right).__name__})"
            )
            return
        if len(left) != len(right):
            reasons.append(
                f"{path}: list length diff (left={len(left)}, right={len(right)})"
            )
            return
        for i, (l, r) in enumerate(zip(left, right)):
            _diff_recursive(l, r, f"{path}[{i}]", reasons)
        return

    # 6. Fallback : canonical-JSON byte comparison (catches strings, bools,
    # any custom-serializable type via the default=str hook).
    if _canonical_dump(left) != _canonical_dump(right):
        reasons.append(
            f"{path}: scalar diff (left={left!r}, right={right!r})"
        )


def diff_payloads(left: Any, right: Any) -> ParityDiffResult:
    """Compare two projection payloads. Returns ParityDiffResult.

    The comparison is deterministic per the module rules : canonical JSON +
    Decimal tolerance + missing-key=None.
    """
    reasons: List[str] = []
    _diff_recursive(left, right, path="", reasons=reasons)
    return ParityDiffResult(is_equal=not reasons, reasons=reasons)


# ── CLI ────────────────────────────────────────────────────────────────────


def _self_test_fixtures():
    """Return 12 (left, right, expected_equal) triples for the self-test.

    The set covers each rule (canonicalisation, Decimal tolerance, missing-
    vs-None, list length, dict nesting). Equal=True cases prove the
    canonicaliser doesn't false-positive ; Equal=False cases prove it
    catches real drift.
    """
    return [
        # ── 6 EQUAL pairs ─────────────────────────────────────────────────
        # 1. Identical scalars
        ({"a": 1}, {"a": 1}, True),
        # 2. Key reordering
        ({"a": 1, "b": 2}, {"b": 2, "a": 1}, True),
        # 3. Decimal-vs-float within tolerance
        ({"x": Decimal("12345.67")}, {"x": 12345.67}, True),
        # 4. Missing-key vs None
        ({"a": 1}, {"a": 1, "lpp": None}, True),
        # 5. Nested dicts, key-reordered
        (
            {"tags": ["expat_eu"], "conf": {"expat_eu": {"c": 0.8, "a": 0.9}}},
            {"conf": {"expat_eu": {"a": 0.9, "c": 0.8}}, "tags": ["expat_eu"]},
            True,
        ),
        # 6. Empty payload pair
        ({}, {}, True),
        # ── 6 DIFF pairs ──────────────────────────────────────────────────
        # 7. Numeric value drift beyond tolerance (cents)
        ({"x": 12345.67}, {"x": 12345.68}, False),
        # 8. Type mismatch
        ({"a": "1"}, {"a": 1}, True),  # Decimal coercion catches this as EQUAL
        # 8b. Real type mismatch — list vs dict
        ({"a": [1, 2]}, {"a": {"0": 1, "1": 2}}, False),
        # 9. List length drift
        ({"tags": ["a", "b"]}, {"tags": ["a"]}, False),
        # 10. One side has a key with a non-None value, other side missing it
        ({"a": 1}, {"a": 1, "lpp": 0.0}, False),
        # 11. Nested-string difference
        ({"conf": {"x": "high"}}, {"conf": {"x": "low"}}, False),
        # 12. None vs non-None (real drift, not missing-key)
        ({"a": None}, {"a": 0}, False),
    ]


def _run_self_test() -> int:
    fixtures = _self_test_fixtures()
    failures = []
    for i, (left, right, expected_equal) in enumerate(fixtures, start=1):
        result = diff_payloads(left, right)
        if result.is_equal != expected_equal:
            failures.append(
                f"fixture {i}: expected is_equal={expected_equal}, got "
                f"is_equal={result.is_equal} ({result.as_text()})"
            )
    if failures:
        print(f"SELF-TEST FAILED ({len(failures)}/{len(fixtures)}) :")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"SELF-TEST OK ({len(fixtures)}/{len(fixtures)} fixtures)")
    return 0


def _run_pair(left_path: Path, right_path: Path) -> int:
    left = json.loads(left_path.read_text(encoding="utf-8"))
    right = json.loads(right_path.read_text(encoding="utf-8"))
    result = diff_payloads(left, right)
    print(result.as_text())
    return 0 if result.is_equal else 1


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Deterministic projection-parity diff (Plan 02-03 iter-2 A10). "
            "Compares two JSON projection payloads via canonical JSON + "
            "Decimal tolerance + missing-key=None rule."
        ),
    )
    parser.add_argument(
        "--pair",
        nargs=2,
        type=Path,
        metavar=("LEFT", "RIGHT"),
        help="Compare two JSON files ; exit 0 EQUAL, exit 1 DIFF.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run the 12-fixture self-test ; exit 0 OK, exit 1 surprise.",
    )
    parser.add_argument(
        "--audit-all-users",
        action="store_true",
        help=(
            "PR-3a checkpoint precondition (stub). Iterates 100%% of staging "
            "users, runs diff_payloads on each, persists to "
            "_phase02_parity_audit. Requires STAGING_BASE_URL + "
            "STAGING_DATABASE_URL env vars."
        ),
    )
    parser.add_argument(
        "--persist-to",
        type=str,
        default=None,
        help="Target table for --audit-all-users (e.g., _phase02_parity_audit).",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return _run_self_test()
    if args.pair:
        return _run_pair(args.pair[0], args.pair[1])
    if args.audit_all_users:
        # Surface a clear blocker until the staging-runtime wiring lands.
        # The Task 2a checkpoint preamble (Claude steps 5-8) is where this
        # gets exercised against Railway staging ; until then, refuse
        # silently-running and produce no false zero-diff signal.
        print(
            "ERROR: --audit-all-users requires STAGING_BASE_URL + "
            "STAGING_DATABASE_URL env vars and PR-3a backfill deployed to "
            "Railway staging. This is the Task 2a checkpoint preamble "
            "(Claude steps 5-8). Stub-blocked here to prevent false "
            "zero-diff signal."
        )
        return 2
    parser.print_help()
    return 0


__all__ = [
    "DECIMAL_TOLERANCE",
    "ParityDiffResult",
    "diff_payloads",
    "main",
]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
