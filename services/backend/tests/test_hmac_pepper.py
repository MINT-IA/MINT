"""Unit tests for app.services.audit.hmac_pepper canonical entry.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-07/D-14/D-15/D-24.

Replaces the Plan 02-01 W0 stub (which raised NotImplementedError).
Tests the real HMAC-SHA256-pepper implementation that gates all audit-PII writes.
"""
from __future__ import annotations

import hashlib
import os

import pytest

from app.services.audit.hmac_pepper import (
    PepperNotConfigured,
    hmac_actor_email,
    hmac_pii,
    hmac_user_id,
)


# ---------------------------------------------------------------------------
# hmac_user_id basics
# ---------------------------------------------------------------------------


def test_hmac_user_id_returns_64_char_lowercase_hex():
    """HMAC-SHA256 hex digest is 64 chars, lowercase, [0-9a-f] only."""
    result = hmac_user_id("user-123")
    assert isinstance(result, str)
    assert len(result) == 64
    assert result == result.lower()
    assert all(c in "0123456789abcdef" for c in result)


def test_hmac_user_id_deterministic_same_input_same_output():
    """Same user_id → same hash across calls (deterministic per process)."""
    a = hmac_user_id("user-123")
    b = hmac_user_id("user-123")
    assert a == b


def test_hmac_user_id_different_inputs_different_outputs():
    """user_id is the message — different users yield different hashes."""
    a = hmac_user_id("user-A")
    b = hmac_user_id("user-B")
    assert a != b


def test_hmac_user_id_none_returns_none():
    """None input → None output (caller passes user.id which can be NULL)."""
    assert hmac_user_id(None) is None


def test_hmac_user_id_pepper_changes_output_vs_bare_sha256():
    """The pepper MUST change the digest vs bare hashlib.sha256(user_id).

    This is the rainbow-table mitigation per D-24: an attacker with the audit
    table cannot precompute sha256 of common emails / user IDs and reverse
    them. The pepper makes precomputation infeasible.
    """
    pepper_hash = hmac_user_id("user-123")
    bare_sha = hashlib.sha256(b"user-123").hexdigest()
    assert pepper_hash != bare_sha


# ---------------------------------------------------------------------------
# hmac_actor_email + hmac_pii parity
# ---------------------------------------------------------------------------


def test_hmac_actor_email_same_contract_as_hmac_user_id():
    """actor_email hashes use the SAME pepper but distinct input → distinct output."""
    a = hmac_actor_email("julien@example.test")
    assert isinstance(a, str)
    assert len(a) == 64
    # actor_email and user_id are different inputs → different outputs even
    # when the underlying string is identical.
    same_as_user_id = hmac_user_id("julien@example.test")
    # Both use the same pepper, so for the SAME plaintext the digest is the
    # same. This is intentional: the function names are domain markers, not
    # cryptographic domain separators (which would require salting per call
    # site). D-15 acceptance: hash deterministic across PII categories so
    # cross-table joins by hash still work for compliance reports.
    assert same_as_user_id == a


def test_hmac_pii_none_returns_none():
    """hmac_pii(None) → None (uniform with hmac_user_id contract)."""
    assert hmac_pii(None) is None


def test_hmac_pii_consistent_with_hmac_user_id_for_same_input():
    """hmac_pii is the generic underlying primitive. Calling hmac_user_id and
    hmac_pii with the same value yields the same digest."""
    assert hmac_pii("x") == hmac_user_id("x")


# ---------------------------------------------------------------------------
# PepperNotConfigured failure path
# ---------------------------------------------------------------------------


def test_pepper_not_configured_raises_outside_testing(monkeypatch):
    """When MINT_AUDIT_HASH_PEPPER is unset AND TESTING != 1, calling raises.

    Fail-closed beats silently-degraded-PII per D-07. Production deployments
    without the pepper set MUST fail boot rather than write reversible hashes.
    """
    # Clear cache so the lru_cached _get_pepper re-reads env vars
    from app.services.audit.hmac_pepper import _get_pepper
    _get_pepper.cache_clear()
    monkeypatch.delenv("MINT_AUDIT_HASH_PEPPER", raising=False)
    monkeypatch.delenv("TESTING", raising=False)

    with pytest.raises(PepperNotConfigured):
        hmac_user_id("user-123")

    # Reset cache so subsequent tests see TESTING=1 fallback again
    _get_pepper.cache_clear()


def test_pepper_too_short_raises_outside_testing(monkeypatch):
    """A pepper < 32 chars is a security smell — refuse to use it."""
    from app.services.audit.hmac_pepper import _get_pepper
    _get_pepper.cache_clear()
    monkeypatch.setenv("MINT_AUDIT_HASH_PEPPER", "short")
    monkeypatch.delenv("TESTING", raising=False)

    with pytest.raises(PepperNotConfigured):
        hmac_user_id("user-123")

    _get_pepper.cache_clear()


def test_testing_env_allows_test_pepper_fallback(monkeypatch):
    """TESTING=1 lets the suite run without the operator setting a real pepper.

    The test-pepper is a fixed string (NOT a real secret), used only inside
    the test suite. Production deploys ALWAYS set the env var explicitly.
    """
    from app.services.audit.hmac_pepper import _get_pepper
    _get_pepper.cache_clear()
    monkeypatch.delenv("MINT_AUDIT_HASH_PEPPER", raising=False)
    monkeypatch.setenv("TESTING", "1")

    # Should not raise
    result = hmac_user_id("user-123")
    assert isinstance(result, str)
    assert len(result) == 64

    _get_pepper.cache_clear()
