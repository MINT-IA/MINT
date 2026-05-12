"""Tests for ConsentService extensions — Phase 97.5 W2-T5 + W2-T6.

Covers the 2 new gate-read + idempotent-granter methods added to support
the v2.9 log_only ConsentService rollout (julien-go 2026-05-12 Option A):

    - has_active_grant(db, *, user_id, purpose) -> bool
    - grant_with_basis(db, *, user_id, purpose, policy_version, basis)
        -> Optional[ConsentModel]

Plus the `check_or_log(db, *, user_id, purpose, mode)` gate dispatch.
"""
from __future__ import annotations

import os
import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
import app.models  # noqa: F401 — register all model tables
from app.models.consent import ConsentModel
from app.schemas.consent_receipt import ConsentPurpose
from app.services.consent.consent_service import (
    ConsentCheckResult,
    ConsentService,
)


# Fresh in-memory DB per test — mirrors test_consent_service.py pattern.
@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def service():
    return ConsentService()


# --- has_active_grant -------------------------------------------------------

def test_has_active_grant_returns_false_on_empty_table(db, service):
    """Empty table → no active grant for any (user, purpose)."""
    assert service.has_active_grant(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
    ) is False


def test_has_active_grant_true_after_grant_false_after_revoke(db, service):
    """grant() → True. revoke() → False. The revoke check is the « active » qualifier."""
    row = service.grant(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC.value,
        policy_version="v2.3.0",
    )
    assert service.has_active_grant(
        db, user_id="u1", purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC
    ) is True
    # Different user → still False (per-user isolation).
    assert service.has_active_grant(
        db, user_id="u2", purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC
    ) is False
    # Different purpose for same user → False.
    assert service.has_active_grant(
        db, user_id="u1", purpose=ConsentPurpose.PERSISTENCE_365D
    ) is False

    # Revoke the grant.
    service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    assert service.has_active_grant(
        db, user_id="u1", purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC
    ) is False


# --- grant_with_basis -------------------------------------------------------

def test_grant_with_basis_is_idempotent(db, service):
    """Second call to grant_with_basis returns None (no second receipt row)."""
    first = service.grant_with_basis(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        policy_version="v2.3.0",
        basis="legal-continuity-pre-granular-T&C",
    )
    assert first is not None
    assert first.purpose_category == "transfer_us_anthropic"

    # Second call — same (user, purpose) — must short-circuit to None.
    second = service.grant_with_basis(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        policy_version="v2.3.0",
        basis="legal-continuity-pre-granular-T&C",
    )
    assert second is None

    # And only one row physically exists on the chain.
    rows = db.query(ConsentModel).filter(
        ConsentModel.user_id == "u1",
        ConsentModel.purpose_category == "transfer_us_anthropic",
    ).all()
    assert len(rows) == 1


def test_grant_with_basis_writes_basis_and_chains_via_merkle(db, service):
    """`basis` lands in receipt_json AND prev_hash chains from previous row."""
    # Seed the chain with a regular grant so we can verify chaining.
    seed = service.grant(
        db,
        user_id="u1",
        purpose=ConsentPurpose.VISION_EXTRACTION.value,
        policy_version="v2.3.0",
    )
    assert seed.prev_hash is None  # genesis

    row = service.grant_with_basis(
        db,
        user_id="u1",
        purpose=ConsentPurpose.PERSISTENCE_365D,
        policy_version="v2.3.0",
        basis="legal-continuity-pre-granular-T&C",
    )
    assert row is not None

    # basis present in receipt_json
    assert row.receipt_json["basis"] == "legal-continuity-pre-granular-T&C"
    # other audit fields preserved
    assert row.receipt_json["lawfulBasis"] == "consent_nLPD_art_6_al_6"
    assert row.purpose_category == "persistence_365d"

    # merkle chain: prev_hash of the new row = sha256(seed.signature)
    import hashlib
    expected_prev = hashlib.sha256(seed.signature.encode("utf-8")).hexdigest()
    assert row.prev_hash == expected_prev

    # Chain length incremented by exactly 1.
    chain_len = db.query(ConsentModel).filter(
        ConsentModel.user_id == "u1"
    ).count()
    assert chain_len == 2


# --- check_or_log dispatch --------------------------------------------------

def test_check_or_log_log_only_missing_grant(db, service, caplog):
    """log_only + grant missing → allow=True + warning log emitted."""
    import logging
    caplog.set_level(logging.WARNING, logger="app.services.consent.consent_service")
    result = service.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="log_only",
    )
    assert isinstance(result, ConsentCheckResult)
    assert result.grant_exists is False
    assert result.allow is True
    assert result.warning_header is None
    assert result.deny_pointer is None
    # Warning log fired.
    assert any(
        "consent_missing" in rec.message for rec in caplog.records
    ), "expected a 'consent_missing' warning log line"


def test_check_or_log_log_only_grant_present_no_log(db, service, caplog):
    """log_only + grant present → allow=True, NO warning log."""
    import logging
    service.grant(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC.value,
        policy_version="v2.3.0",
    )
    caplog.set_level(logging.WARNING, logger="app.services.consent.consent_service")
    caplog.clear()
    result = service.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="log_only",
    )
    assert result.grant_exists is True
    assert result.allow is True
    assert not any(
        "consent_missing" in rec.message for rec in caplog.records
    ), "no warning log expected when grant exists"


def test_check_or_log_soft_block_populates_warning_header(db, service):
    """soft_block + missing grant → allow=True + warning_header populated."""
    result = service.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="soft_block",
    )
    assert result.allow is True
    assert result.warning_header == "missing:transfer_us_anthropic"
    assert result.deny_pointer is None


def test_check_or_log_hard_block_populates_deny_pointer(db, service):
    """hard_block + missing grant → allow=False + deny_pointer populated."""
    result = service.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="hard_block",
    )
    assert result.allow is False
    assert result.deny_pointer is not None
    assert result.deny_pointer["purpose"] == "transfer_us_anthropic"
    assert result.deny_pointer["action"].startswith("POST")
    assert "modal_copy_key" in result.deny_pointer


def test_check_or_log_unknown_mode_defaults_to_log_only(db, service, caplog):
    """Misconfigured env var → fail-OPEN (allow=True) per R-2 mitigation."""
    import logging
    caplog.set_level(logging.WARNING, logger="app.services.consent.consent_service")
    result = service.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="nonsense_value",
    )
    assert result.allow is True
    assert result.grant_exists is False
    assert any(
        "consent_gate_unknown_mode_defaulting_to_log_only" in rec.message
        for rec in caplog.records
    )
