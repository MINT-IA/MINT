"""Tests for fact_key allowlist enforcement.

PRIV-06 — Phase 29.

Covers:
    - is_allowed / purpose_of / ttl_days_of for the 8 keys
    - Hard-drop semantics for non-allowlisted keys
    - persist_fact() returns False on drop, True on accept
    - Drop log line contains the hashed key, never the raw key
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path

import pytest

from app.services.privacy import fact_key_allowlist as alw
from app.services.privacy.fact_key_allowlist import Purpose


# ---------------------------------------------------------------------------
# Allowlist API
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("key", [
    "avoir_lpp", "salaire_assure", "taux_conversion_caisse", "avoir_3a",
    "rente_avs_projetee", "date_naissance", "canton_residence", "archetype",
])
def test_allowed_keys_are_accepted(key):
    assert alw.is_allowed(key) is True
    assert alw.purpose_of(key) is not None
    assert alw.ttl_days_of(key) is None  # all 8 = account lifetime


@pytest.mark.parametrize("key", [
    "iban", "numero_avs", "salary_monthly", "employer_name",
    "phone_number", "email", "address", "ssn",
    # Even semantically-related but not allowlisted keys are dropped:
    "salaire_brut_annuel", "salaire_net", "rente_lpp_projetee",
    # Empty / weird:
    "", "   ", "a" * 256,
])
def test_unknown_keys_are_rejected(key):
    assert alw.is_allowed(key) is False
    assert alw.purpose_of(key) is None
    assert alw.ttl_days_of(key) is None


def test_archetype_purpose_is_premier_eclairage():
    assert alw.purpose_of("archetype") == Purpose.PREMIER_ECLAIRAGE


def test_taux_conversion_purpose_is_arbitrage():
    assert alw.purpose_of("taux_conversion_caisse") == Purpose.ARBITRAGE


def test_allowlist_count_is_exactly_eight():
    """Sentinel: any change to the 8 keys requires explicit DPO review."""
    assert len(alw.ALLOWED_FACT_KEYS) == 8


# ---------------------------------------------------------------------------
# persist_fact (document_memory_service integration)
# ---------------------------------------------------------------------------

def test_persist_fact_drops_unknown_key(caplog):
    """Unknown key → returns False, logs hashed key, no DB write."""
    from app.services.document_memory_service import persist_fact

    caplog.set_level(logging.INFO, logger="app.services.document_memory_service")
    accepted = persist_fact(
        db=None,
        user_id="user-test-123",
        key="iban",  # NOT allowlisted
        value="CH9300762011623852957",
    )
    assert accepted is False
    # The log line must mention the drop event but never the raw key.
    drop_logs = [r.getMessage() for r in caplog.records if "fact_key" in r.getMessage()]
    assert any("dropped" in m for m in drop_logs), drop_logs
    assert all("iban" not in m.lower() for m in drop_logs), (
        f"raw key 'iban' leaked into drop log: {drop_logs}"
    )


def test_persist_fact_drop_log_no_pii(caplog):
    """Drop log contains hashed key + count, never the value either."""
    from app.services.document_memory_service import persist_fact

    caplog.set_level(logging.INFO, logger="app.services.document_memory_service")
    persist_fact(
        db=None,
        user_id="user-x",
        key="numero_avs",
        value="756.1234.5678.97",
    )
    msgs = [r.getMessage() for r in caplog.records]
    for m in msgs:
        assert "756.1234" not in m
        assert "numero_avs" not in m  # hashed, never raw


def test_persist_fact_accepts_allowlisted_key_without_db():
    """Allowlisted key + db=None → returns True (no-op write)."""
    from app.services.document_memory_service import persist_fact
    accepted = persist_fact(
        db=None,
        user_id="user-x",
        key="avoir_lpp",
        value=70377,
    )
    assert accepted is True


# ---------------------------------------------------------------------------
# CI gate script
# ---------------------------------------------------------------------------

def test_ci_gate_passes_on_clean_log_fixture(tmp_path):
    """check_pii_in_logs.py returns 0 on a clean log file."""
    import subprocess
    import sys

    clean_log = tmp_path / "clean.log"
    clean_log.write_text(
        "INFO document fingerprint computed count=5\n"
        "INFO coach response generated tokens=120\n"
        "INFO consent receipt issued purpose=projection\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [sys.executable, "scripts/check_pii_in_logs.py",
         "--fixture", str(clean_log)],
        capture_output=True, text=True,
        cwd=str(Path(__file__).resolve().parents[3]),
    )
    assert result.returncode == 0, (
        f"clean log fixture should pass; stderr={result.stderr}"
    )


def test_ci_gate_fails_on_polluted_log_fixture(tmp_path):
    """check_pii_in_logs.py returns 1 when raw IBAN/AVS appears."""
    import subprocess
    import sys

    bad_log = tmp_path / "bad.log"
    bad_log.write_text(
        "INFO some user iban=CH9300762011623852957 logged in\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [sys.executable, "scripts/check_pii_in_logs.py",
         "--fixture", str(bad_log)],
        capture_output=True, text=True,
        cwd=str(Path(__file__).resolve().parents[3]),
    )
    assert result.returncode == 1, (
        f"polluted log fixture should fail (exit 1); stdout={result.stdout}"
    )
    assert "IBAN" in (result.stdout + result.stderr)
