"""Unit tests for projection_diff.diff_payloads — iter-2 A10.

Covers : Decimal tolerance, key reordering, missing-vs-None,
list-length drift, nested-dict diff, type-mismatch, EQUAL/DIFF
return-shape and CLI exit codes.
"""
from __future__ import annotations

import json
import subprocess
import sys
from decimal import Decimal
from pathlib import Path

import pytest

# Make tools/parity importable without an editable install.
_REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(_REPO_ROOT))

from tools.parity.projection_diff import (  # noqa: E402
    DECIMAL_TOLERANCE,
    diff_payloads,
)


_SCRIPT = _REPO_ROOT / "tools" / "parity" / "projection_diff.py"


# ── Library API tests ────────────────────────────────────────────────────


def test_identical_dicts_equal():
    assert diff_payloads({"a": 1}, {"a": 1}).is_equal is True


def test_key_reordering_equal():
    left = {"a": 1, "b": 2, "c": 3}
    right = {"c": 3, "a": 1, "b": 2}
    assert diff_payloads(left, right).is_equal is True


def test_decimal_float_within_tolerance_equal():
    assert diff_payloads({"x": Decimal("12345.67")}, {"x": 12345.67}).is_equal


def test_decimal_drift_beyond_tolerance_diff():
    result = diff_payloads({"x": 12345.67}, {"x": 12345.68})
    assert result.is_equal is False
    assert "numeric diff" in result.reasons[0]


def test_missing_key_vs_none_equal():
    """Key absent on one side + None on other = EQUAL (rule)."""
    assert diff_payloads({"a": 1}, {"a": 1, "lpp": None}).is_equal is True


def test_missing_key_vs_nonzero_diff():
    """Key absent on one side + non-None on other = DIFF."""
    result = diff_payloads({"a": 1}, {"a": 1, "lpp": 0.0})
    assert result.is_equal is False


def test_nested_dict_reordering_equal():
    left = {
        "tags": ["expat_eu"],
        "conf": {"expat_eu": {"c": 0.8, "a": 0.9}},
    }
    right = {
        "conf": {"expat_eu": {"a": 0.9, "c": 0.8}},
        "tags": ["expat_eu"],
    }
    assert diff_payloads(left, right).is_equal is True


def test_list_length_diff():
    result = diff_payloads({"tags": ["a", "b"]}, {"tags": ["a"]})
    assert result.is_equal is False
    assert "list length diff" in result.reasons[0]


def test_list_element_diff():
    result = diff_payloads({"tags": ["a", "b"]}, {"tags": ["a", "c"]})
    assert result.is_equal is False


def test_type_mismatch_list_vs_dict_diff():
    result = diff_payloads({"a": [1, 2]}, {"a": {"0": 1, "1": 2}})
    assert result.is_equal is False
    assert "type mismatch" in result.reasons[0]


def test_decimal_tolerance_constant():
    """Tolerance is 1e-9 — covers float-Decimal noise without hiding cents."""
    assert DECIMAL_TOLERANCE == Decimal("1e-9")
    # Cents drift is caught (10^-2 > 10^-9)
    assert diff_payloads({"x": 1.00}, {"x": 1.01}).is_equal is False
    # Sub-femto drift is ignored (10^-15 < 10^-9)
    assert diff_payloads({"x": 1.0}, {"x": 1.0 + 1e-15}).is_equal is True


def test_string_value_diff():
    result = diff_payloads({"canton": "VD"}, {"canton": "GE"})
    assert result.is_equal is False


def test_empty_payloads_equal():
    assert diff_payloads({}, {}).is_equal is True


def test_decimal_via_string_form_equal():
    """SnapshotModel pillar_3a_balance Decimal vs float canary form."""
    # Plan 02-02 canary returned '12345.67' as canonical str ; the new
    # fact_current path returns Decimal('12345.67'). Both should equal.
    assert diff_payloads(
        {"pillar_3a_balance": "12345.67"},
        {"pillar_3a_balance": Decimal("12345.67")},
    ).is_equal is True


# ── CLI tests ─────────────────────────────────────────────────────────────


def test_cli_self_test_exits_zero():
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--self-test"],
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 0, (
        f"self-test exit={result.returncode}\nstdout={result.stdout}\n"
        f"stderr={result.stderr}"
    )
    assert "SELF-TEST OK" in result.stdout


def test_cli_pair_equal_exits_zero(tmp_path):
    left = tmp_path / "left.json"
    right = tmp_path / "right.json"
    left.write_text(json.dumps({"a": 1, "b": 2}))
    right.write_text(json.dumps({"b": 2, "a": 1}))
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--pair", str(left), str(right)],
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 0
    assert "EQUAL" in result.stdout


def test_cli_pair_diff_exits_one(tmp_path):
    left = tmp_path / "left.json"
    right = tmp_path / "right.json"
    left.write_text(json.dumps({"a": 1}))
    right.write_text(json.dumps({"a": 99}))
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--pair", str(left), str(right)],
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 1
    assert "DIFF" in result.stdout


def test_cli_audit_all_users_stub_exits_two_with_message():
    """Stub-blocking exit prevents false zero-diff signal pre-staging-wire."""
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--audit-all-users"],
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 2, (
        f"expected stub exit 2, got {result.returncode}\n{result.stdout}"
    )
    assert "STAGING_BASE_URL" in result.stdout
