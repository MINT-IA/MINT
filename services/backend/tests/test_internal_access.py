"""
Tests for Internal Full Access override (dev/TestFlight testing).

Verifies:
1. Override grants configured tier when enabled + user in allowlist
2. Override disabled by default (fail-closed)
3. User not in allowlist gets no override
4. Audit trail logged on each override
5. Production safety: disabled flag = no override regardless of allowlist
6. Non-regression: billing/household unaffected
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from app.core.config import settings
from app.models.billing import SubscriptionModel
from app.models.household import AdminAuditEventModel
from app.models.user import User
from app.services.billing_service import (
    _compute_effective_tier,
    _is_internal_access_user,
    recompute_entitlements,
)
from tests.conftest import TestingSessionLocal


def _create_user(db, email: str = "tester@mint.ch", user_id: str = "internal-user-1") -> User:
    user = User(id=user_id, email=email, hashed_password="x")
    db.add(user)
    db.commit()
    return user


def _create_subscription(db, user_id: str, tier: str = "starter") -> None:
    db.add(SubscriptionModel(
        user_id=user_id,
        tier=tier,
        status="active",
        source="stripe",
        current_period_end=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=30),
    ))
    db.commit()


# ---------------------------------------------------------------------------
# 1. Override grants configured tier when enabled + user in allowlist
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "premium")
def test_internal_override_grants_premium():
    db = TestingSessionLocal()
    try:
        _create_user(db)
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "premium"
    finally:
        db.close()


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "couple_plus")
def test_internal_override_grants_couple_plus():
    db = TestingSessionLocal()
    try:
        _create_user(db)
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "couple_plus"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 2. Override disabled by default (fail-closed)
# ---------------------------------------------------------------------------


def test_internal_override_disabled_by_default():
    """With default settings, no user gets internal override."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "free"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 3. User not in allowlist gets no override
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "other@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "premium")
def test_non_allowlisted_user_no_override():
    db = TestingSessionLocal()
    try:
        _create_user(db)
        assert not _is_internal_access_user(db, "internal-user-1")
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "free"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 4. Audit trail logged on each override
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "premium")
def test_internal_override_creates_audit_log():
    db = TestingSessionLocal()
    try:
        _create_user(db)
        recompute_entitlements(db, "internal-user-1")  # audit logged here
        audit = (
            db.query(AdminAuditEventModel)
            .filter(
                AdminAuditEventModel.action == "internal_access_override",
                AdminAuditEventModel.target_user_id == "internal-user-1",
            )
            .first()
        )
        assert audit is not None
        assert "premium" in audit.reason
        assert "INTERNAL_ACCESS_ENABLED" in audit.reason
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 5. Production safety: enabled=False => no override
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", False)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
def test_prod_safety_disabled_flag():
    """Even with email in allowlist, disabled flag = no override."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        assert not _is_internal_access_user(db, "internal-user-1")
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "free"
    finally:
        db.close()


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "")
def test_empty_allowlist_no_override():
    """Enabled but empty allowlist = no override."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        assert not _is_internal_access_user(db, "internal-user-1")
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 5b. Wildcard "*" grants access to all authenticated users
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "*")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "couple_plus")
def test_wildcard_allowlist_grants_all_users():
    """Wildcard '*' gives internal access to any authenticated user."""
    db = TestingSessionLocal()
    try:
        _create_user(db, email="random@example.com", user_id="random-user")
        assert _is_internal_access_user(db, "random-user")
        tier = _compute_effective_tier(db, "random-user")
        assert tier == "couple_plus"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 6. Non-regression: real subscription still works when not internal
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", False)
def test_real_subscription_unaffected():
    """Normal billing flow unaffected by internal access feature."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        _create_subscription(db, "internal-user-1", tier="starter")
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "starter"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 7. Override takes priority over real subscription
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "couple_plus")
def test_internal_override_beats_real_subscription():
    """Internal override takes priority even when user has a real subscription."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        _create_subscription(db, "internal-user-1", tier="starter")
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "couple_plus"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 8. recompute_entitlements respects internal override
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "premium")
def test_recompute_entitlements_with_internal_override():
    """recompute_entitlements returns premium features for internal user."""
    db = TestingSessionLocal()
    try:
        _create_user(db)
        tier, features = recompute_entitlements(db, "internal-user-1")
        assert tier == "premium"
        # Premium features include dashboard, coachLlm, monteCarlo, etc.
        assert "dashboard" in features
        assert "coachLlm" in features
        assert "monteCarlo" in features
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 9. Invalid default tier falls back to premium
# ---------------------------------------------------------------------------


@patch.object(settings, "INTERNAL_ACCESS_ENABLED", True)
@patch.object(settings, "INTERNAL_ACCESS_ALLOWLIST", "tester@mint.ch")
@patch.object(settings, "INTERNAL_ACCESS_DEFAULT_TIER", "invalid_tier")
def test_invalid_default_tier_falls_back_to_premium():
    db = TestingSessionLocal()
    try:
        _create_user(db)
        tier = _compute_effective_tier(db, "internal-user-1")
        assert tier == "premium"
    finally:
        db.close()
