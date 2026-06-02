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
from uuid import uuid4

# Make tools/parity importable without an editable install.
_REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(_REPO_ROOT))

from tools.parity.projection_diff import (  # noqa: E402
    DECIMAL_TOLERANCE,
    diff_payloads,
    main,
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


def test_cli_audit_all_users_without_db_url_exits_two(monkeypatch):
    """Missing DB target refuses to run instead of producing a false zero."""
    monkeypatch.delenv("STAGING_DATABASE_URL", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
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
    assert "STAGING_DATABASE_URL" in result.stdout


def _seed_audit_db(tmp_path, *, fact_value: float):
    """Create a minimal audit DB with one user, one snapshot, one fact_current."""
    import os
    import sys
    from datetime import datetime, timezone

    os.environ["TESTING"] = "1"
    backend_root = _REPO_ROOT / "services" / "backend"
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))

    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session

    import app.models  # noqa: F401 - register all models on Base.metadata
    from app.core.database import Base
    from app.models.fact_current import FactCurrent
    from app.models.phase02_parity_audit import Phase02ParityAudit  # noqa: F401
    from app.models.snapshot import SnapshotModel
    from app.models.user import User
    from app.services.encryption.encrypted_value_helper import encrypt_value

    db_file = tmp_path / f"audit-{uuid4().hex}.sqlite"
    db_url = f"sqlite:///{db_file}"
    engine = create_engine(db_url)
    Base.metadata.create_all(engine)

    user_id = "u-audit-1"
    with Session(engine) as session:
        session.add(
            User(
                id=user_id,
                email="audit@example.test",
                hashed_password="x",
            )
        )
        session.add(
            SnapshotModel(
                id="snap-1",
                user_id=user_id,
                created_at=datetime(2026, 6, 2, tzinfo=timezone.utc),
                trigger="profile_update",
                gross_income=8500.0,
            )
        )
        session.flush()
        session.add(
            FactCurrent(
                user_id=user_id,
                field_key="monthly_gross_income",
                value_enc=encrypt_value(session, user_id, fact_value),
                valid_from=datetime(2026, 6, 2, tzinfo=timezone.utc),
                latest_event_id="evt-audit-1",
            )
        )
        session.commit()
    engine.dispose()
    return db_url


def test_cli_audit_all_users_equal_persists_zero_diff(tmp_path, monkeypatch, capsys):
    db_url = _seed_audit_db(tmp_path, fact_value=8500.0)
    monkeypatch.setenv("STAGING_DATABASE_URL", db_url)

    exit_code = main(["--audit-all-users", "--persist-to", "_phase02_parity_audit"])
    out = capsys.readouterr().out

    assert exit_code == 0
    assert "USERS_AUDITED=1" in out
    assert "USERS_WITH_DIFF=0" in out
    assert "PERSISTED_ROWS=1" in out


def test_cli_audit_all_users_diff_exits_one(tmp_path, monkeypatch, capsys):
    db_url = _seed_audit_db(tmp_path, fact_value=9000.0)
    monkeypatch.setenv("STAGING_DATABASE_URL", db_url)

    exit_code = main(["--audit-all-users", "--persist-to", "_phase02_parity_audit"])
    out = capsys.readouterr().out

    assert exit_code == 1
    assert "USERS_AUDITED=1" in out
    assert "USERS_WITH_DIFF=1" in out
    assert "PERSISTED_ROWS=1" in out
