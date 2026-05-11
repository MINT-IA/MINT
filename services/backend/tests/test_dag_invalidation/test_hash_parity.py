"""Phase 95 — DAG-01 Python<->Dart 50/50 parity.

R1 (RESEARCH §"Pitfalls #1") — if Python and Dart can't agree on hashes
on 50/50 fixtures, the entire DAG-invalidation contract is unworkable
and Wave 2 must pivot to centime/bps integer-scaling before fattening
the migration. Failure = blocker.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

from app.services.coach.inputs_hash import compute_inputs_hash

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


def _load_jsonl(p: Path) -> list[dict]:
    with p.open() as f:
        return [json.loads(line) for line in f if line.strip()]


def test_fixture_pack_has_50_entries():
    fixtures = _load_jsonl(FIXTURES_DIR / "hash_parity_50.jsonl")
    assert len(fixtures) == 50


def test_expected_pack_has_50_entries():
    expected = _load_jsonl(FIXTURES_DIR / "hash_parity_50_expected.jsonl")
    assert len(expected) == 50


def test_python_hashes_match_expected_golden_file():
    """Catch regressions in compute_inputs_hash : the 50 expected
    hashes are frozen ; any drift signals a hash-algorithm change."""
    fixtures = _load_jsonl(FIXTURES_DIR / "hash_parity_50.jsonl")
    expected = {e["id"]: e["sha256"] for e in _load_jsonl(FIXTURES_DIR / "hash_parity_50_expected.jsonl")}
    drift = []
    for fx in fixtures:
        got = compute_inputs_hash(fx["inputs"])
        want = expected.get(fx["id"])
        if got != want:
            drift.append((fx["id"], got, want))
    assert not drift, f"Python hash drift on {len(drift)}/50 fixtures: {drift[:3]}"


@pytest.mark.integration
@pytest.mark.skipif(
    shutil.which("dart") is None,
    reason="Dart toolchain not installed on this runner — Python<->Dart "
    "parity is enforced on Flutter-CI jobs that provision the SDK. Local "
    "or backend-only CI runs skip cleanly per Phase 95 R1 escalation "
    "contract (gate runs where Dart is present).",
)
def test_python_dart_parity_50_50():
    """Run the Dart harness and assert byte-identical hashes against Python.

    Marked `integration` so it skips by default in fast unit runs ; the
    phase-gate `pytest -q` enables integration via pytest.ini.
    """
    harness_dir = Path(__file__).parent.parent.parent.parent.parent / "apps" / "mobile" / "tools" / "hash_parity_harness"
    src_fixture = FIXTURES_DIR / "hash_parity_50.jsonl"
    result = subprocess.run(
        ["dart", "run", "main.dart", str(src_fixture)],
        cwd=harness_dir,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode == 0, f"Dart harness failed: {result.stderr}"
    dart_hashes = {}
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        dart_hashes[row["id"]] = row["sha256"]
    assert len(dart_hashes) == 50
    drift = []
    for fx in _load_jsonl(src_fixture):
        py = compute_inputs_hash(fx["inputs"])
        dart = dart_hashes.get(fx["id"])
        if py != dart:
            drift.append((fx["id"], py, dart))
    assert not drift, (
        f"Python<->Dart hash drift on {len(drift)}/50 fixtures: {drift[:3]}. "
        f"R1 escalation: pivot to centime/bps integer-scaling per "
        f"RESEARCH §D-03 fallback before Wave 2."
    )
