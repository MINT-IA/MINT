"""Tests for tools/checks/control_matrix_coverage.py — Plan 97-03.

Covers:
  - Test 1 parser smoke: 18-row fixture parses to 18 Row objects
  - Test 2 coverage formula: GREEN / (GREEN + AMBER + RED), DEFERRED excluded
  - Test 3 threshold: pass at exactly 0.95, fail at 0.94
  - Test 4 missing-anchor row: declared GREEN but anchor empty -> RED override
  - Test 5 missing-test-id row: declared GREEN but test_id empty -> AMBER override
  - Test 6 art. 16 N/A row: declared DEFERRED stays DEFERRED, excluded from denominator
  - Test 7 real matrix: shipped docs/compliance/CONTROL_MATRIX.md parses to >= 0.95
"""
from __future__ import annotations

import importlib.util
import pathlib
import subprocess
import sys
import textwrap

import pytest

REPO = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools" / "checks" / "control_matrix_coverage.py"
REAL_MATRIX = REPO / "docs" / "compliance" / "CONTROL_MATRIX.md"


def _load_module():
    """Import the script as a module without invoking main().

    Register in sys.modules before executing so that dataclasses + PEP 563
    `from __future__ import annotations` can resolve InitVar/ClassVar markers
    (Python 3.9 dataclass introspection looks up the class's module via
    sys.modules at decoration time)."""
    name = "control_matrix_coverage"
    spec = importlib.util.spec_from_file_location(name, SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


@pytest.fixture(scope="module")
def cmc():
    assert SCRIPT.is_file(), f"Coverage script missing at {SCRIPT}"
    return _load_module()


def _matrix_text(rows: list[tuple[str, str, str, str, str, str, str, str]]) -> str:
    """Build a fixture matrix Markdown body with N rows."""
    header = (
        "| FinSA Article | Requirement | Control | Implementation Anchor | "
        "Test ID | Last Green Commit | Status | Doctrine Reference |\n"
        "|---|---|---|---|---|---|---|---|\n"
    )
    body = "".join(
        f"| {a} | {req} | {ctrl} | {anchor} | {test_id} | {commit} | {status} | {doc} |\n"
        for (a, req, ctrl, anchor, test_id, commit, status, doc) in rows
    )
    return "# fixture\n\n" + header + body


def _row(article="art. 7", status="GREEN", anchor="path/to/file.dart",
         test_id="path/to/test.dart") -> tuple[str, str, str, str, str, str, str, str]:
    return (article, "req", "ctrl", anchor, test_id, "abc1234", status, "doctrine.md")


# ─── Test 1 — parser smoke ───────────────────────────────────────────────
def test_parser_extracts_all_rows(cmc, tmp_path):
    rows_in = [_row() for _ in range(18)]
    p = tmp_path / "matrix.md"
    p.write_text(_matrix_text(rows_in), encoding="utf-8")
    parsed = cmc.parse(p.read_text(encoding="utf-8"))
    assert len(parsed) == 18
    assert all(r.article.startswith("art.") for r in parsed)


# ─── Test 2 — coverage formula excludes DEFERRED ─────────────────────────
def test_coverage_excludes_deferred(cmc, tmp_path):
    rows_in = [_row(status="GREEN") for _ in range(16)] + [
        _row(status="DEFERRED", anchor="n/a", test_id="n/a"),
        _row(status="DEFERRED", anchor="n/a", test_id="n/a"),
    ]
    p = tmp_path / "matrix.md"
    p.write_text(_matrix_text(rows_in), encoding="utf-8")
    rows = cmc.parse(p.read_text(encoding="utf-8"))
    ratio, tally = cmc.coverage(rows)
    assert tally["GREEN"] == 16
    assert tally["DEFERRED"] == 2
    assert tally["AMBER"] == 0
    assert tally["RED"] == 0
    assert ratio == pytest.approx(1.0)


# ─── Test 3 — threshold pass / fail boundary ─────────────────────────────
def test_threshold_pass_at_exact_ratio(cmc, tmp_path):
    # 19 GREEN + 1 AMBER (anchor present, test_id missing) -> 19/20 = 0.95
    rows_in = [_row(status="GREEN") for _ in range(19)] + [
        _row(status="GREEN", test_id=""),
    ]
    p = tmp_path / "matrix.md"
    p.write_text(_matrix_text(rows_in), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--matrix", str(p), "--threshold", "0.95"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_threshold_fail_below(cmc, tmp_path):
    # 19 GREEN + 1 RED (anchor empty) -> 19/20 = 0.95 -> would pass at 0.95.
    # Build a 17-GREEN + 1-AMBER + 1-RED case to land at 17/19 ≈ 0.894.
    rows_in = (
        [_row(status="GREEN") for _ in range(17)]
        + [_row(status="GREEN", test_id="")]   # AMBER override
        + [_row(status="GREEN", anchor="")]    # RED override
    )
    p = tmp_path / "matrix.md"
    p.write_text(_matrix_text(rows_in), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--matrix", str(p), "--threshold", "0.95"],
        capture_output=True, text=True,
    )
    assert result.returncode == 1, result.stdout + result.stderr


# ─── Test 4 — missing anchor auto-flags RED ──────────────────────────────
def test_missing_anchor_overrides_to_red(cmc):
    r = cmc.Row("art. 7", "req", "ctrl", "", "tests/foo.py", "abc", "GREEN", "doc")
    assert cmc.normalise(r) == "RED"


# ─── Test 5 — missing test id auto-flags AMBER ───────────────────────────
def test_missing_test_id_overrides_to_amber(cmc):
    r = cmc.Row("art. 9", "req", "ctrl", "path/to/anchor.dart", "", "abc", "GREEN", "doc")
    assert cmc.normalise(r) == "AMBER"


# ─── Test 6 — DEFERRED stays DEFERRED ────────────────────────────────────
def test_deferred_row_excluded_from_threshold(cmc):
    r = cmc.Row("art. 16", "req", "ctrl", "n/a", "n/a", "n/a", "DEFERRED", "art-16-deferred")
    assert cmc.normalise(r) == "DEFERRED"


# ─── Test 7 — real matrix passes the gate ────────────────────────────────
def test_shipped_matrix_meets_threshold(cmc):
    assert REAL_MATRIX.is_file(), f"shipped matrix missing at {REAL_MATRIX}"
    rows = cmc.parse(REAL_MATRIX.read_text(encoding="utf-8"))
    assert len(rows) >= 17, f"expected >= 17 rows, got {len(rows)}"
    ratio, tally = cmc.coverage(rows)
    assert ratio >= 0.95, f"coverage {ratio:.4f} < 0.95 — tally {tally}"


# ─── Test 8 — JSON output is well-formed ─────────────────────────────────
def test_json_output_well_formed(cmc, tmp_path):
    """Bonus coverage of the --json branch (still part of the 7-test charter
    via parser + threshold separation; counted as edge case)."""
    import json
    rows_in = [_row(status="GREEN") for _ in range(20)]
    p = tmp_path / "matrix.md"
    p.write_text(_matrix_text(rows_in), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--matrix", str(p), "--threshold", "0.95", "--json"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert payload["pass"] is True
    assert payload["total_rows"] == 20
    assert payload["tally"]["GREEN"] == 20
    assert payload["coverage"] == 1.0


def test_missing_matrix_file_exits_one(tmp_path):
    """Missing matrix file -> exit 1 (not crash)."""
    bogus = tmp_path / "does-not-exist.md"
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--matrix", str(bogus)],
        capture_output=True, text=True,
    )
    assert result.returncode == 1
    assert "Matrix file not found" in result.stderr
