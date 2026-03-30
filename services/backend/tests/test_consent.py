"""
Tests for ConsentManager — nLPD compliance (Sprint S40).

Dedicated test suite for granular consent state management.
Covers: toggle, independence, revocation, multi-user isolation,
opt-in defaults, BYOK field boundaries, and LPD right to erasure.

Sources:
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

import pytest

from app.services.reengagement.consent_manager import (
    ConsentManager,
    _clear_consent_store,
)
from app.services.reengagement.reengagement_models import (
    ConsentType,
)


# ===================================================================
# Fixtures
# ===================================================================


@pytest.fixture(autouse=True)
def clean_consent_store():
    """Clear in-memory consent store before and after each test."""
    _clear_consent_store()
    yield
    _clear_consent_store()


@pytest.fixture
def manager():
    return ConsentManager()


USER_A = "user-alice-001"
USER_B = "user-bob-002"


# ===================================================================
# 1. Opt-in defaults — nLPD art. 6 (5 tests)
# ===================================================================


class TestOptInDefaults:
    """nLPD requires opt-in (not opt-out): every consent starts OFF."""

    def test_byok_off_by_default(self, manager):
        """BYOK data sharing is OFF for a new user."""
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is False

    def test_snapshot_off_by_default(self, manager):
        """Snapshot storage is OFF for a new user."""
        assert ConsentManager.is_consent_given(USER_A, ConsentType.snapshot_storage) is False

    def test_notifications_off_by_default(self, manager):
        """Notifications are OFF for a new user."""
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is False

    def test_default_dashboard_all_off(self, manager):
        """Default dashboard returns 5 consents, all disabled."""
        dashboard = manager.get_default_dashboard()
        assert len(dashboard.consents) == 5
        for c in dashboard.consents:
            assert c.enabled is False

    def test_user_dashboard_all_off_for_new_user(self, manager):
        """User dashboard for new user mirrors default (all OFF)."""
        dashboard = manager.get_user_dashboard(USER_A)
        assert len(dashboard.consents) == 5
        for c in dashboard.consents:
            assert c.enabled is False


# ===================================================================
# 2. Toggle individual consents (4 tests)
# ===================================================================


class TestToggleConsent:
    """Each consent can be individually enabled and disabled."""

    def test_enable_byok(self, manager):
        """Enabling BYOK sets it to True."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is True

    def test_disable_byok_after_enable(self, manager):
        """Disabling BYOK after enabling sets it back to False."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, False)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is False

    def test_enable_snapshot_storage(self, manager):
        """Enabling snapshot storage sets it to True."""
        ConsentManager.update_consent(USER_A, ConsentType.snapshot_storage, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.snapshot_storage) is True

    def test_enable_notifications(self, manager):
        """Enabling notifications sets it to True."""
        ConsentManager.update_consent(USER_A, ConsentType.notifications, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is True


# ===================================================================
# 3. Independence of consents (3 tests)
# ===================================================================


class TestConsentIndependence:
    """Toggling one consent MUST NOT affect others (nLPD)."""

    def test_enable_byok_does_not_affect_snapshot(self, manager):
        """Enabling BYOK leaves snapshot OFF."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.snapshot_storage) is False
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is False

    def test_enable_notifications_does_not_affect_byok(self, manager):
        """Enabling notifications leaves BYOK and snapshot OFF."""
        ConsentManager.update_consent(USER_A, ConsentType.notifications, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is False
        assert ConsentManager.is_consent_given(USER_A, ConsentType.snapshot_storage) is False

    def test_mixed_state_preserved(self, manager):
        """Each consent maintains its own state independently."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        ConsentManager.update_consent(USER_A, ConsentType.snapshot_storage, False)
        ConsentManager.update_consent(USER_A, ConsentType.notifications, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is True
        assert ConsentManager.is_consent_given(USER_A, ConsentType.snapshot_storage) is False
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is True


# ===================================================================
# 4. Revoke all (3 tests)
# ===================================================================


class TestRevokeAll:
    """revoke_all() must disable every consent at once (nLPD art. 6)."""

    def test_revoke_all_disables_everything(self, manager):
        """After revoke_all, every consent is False."""
        for ct in ConsentType:
            ConsentManager.update_consent(USER_A, ct, True)
        ConsentManager.revoke_all(USER_A)
        for ct in ConsentType:
            assert ConsentManager.is_consent_given(USER_A, ct) is False

    def test_revoke_all_on_new_user_is_noop(self, manager):
        """Revoking all on a user with no state does not raise."""
        ConsentManager.revoke_all(USER_A)
        for ct in ConsentType:
            assert ConsentManager.is_consent_given(USER_A, ct) is False

    def test_re_enable_after_revoke_all(self, manager):
        """User can re-enable consents after revoking all."""
        for ct in ConsentType:
            ConsentManager.update_consent(USER_A, ct, True)
        ConsentManager.revoke_all(USER_A)
        ConsentManager.update_consent(USER_A, ConsentType.notifications, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is True
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is False


# ===================================================================
# 5. Multi-user isolation (3 tests)
# ===================================================================


class TestMultiUserIsolation:
    """Consent state is isolated per user."""

    def test_different_users_have_separate_state(self, manager):
        """Enabling consent for user A does not affect user B."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.byok_data_sharing) is True
        assert ConsentManager.is_consent_given(USER_B, ConsentType.byok_data_sharing) is False

    def test_revoke_all_does_not_affect_other_user(self, manager):
        """Revoking all for user A does not affect user B."""
        ConsentManager.update_consent(USER_A, ConsentType.notifications, True)
        ConsentManager.update_consent(USER_B, ConsentType.notifications, True)
        ConsentManager.revoke_all(USER_A)
        assert ConsentManager.is_consent_given(USER_A, ConsentType.notifications) is False
        assert ConsentManager.is_consent_given(USER_B, ConsentType.notifications) is True

    def test_user_dashboard_reflects_individual_state(self, manager):
        """Each user's dashboard reflects only their own consent state."""
        ConsentManager.update_consent(USER_A, ConsentType.byok_data_sharing, True)
        ConsentManager.update_consent(USER_A, ConsentType.snapshot_storage, True)
        ConsentManager.update_consent(USER_B, ConsentType.notifications, True)

        dash_a = manager.get_user_dashboard(USER_A)
        dash_b = manager.get_user_dashboard(USER_B)

        a_map = {c.consent_type: c.enabled for c in dash_a.consents}
        b_map = {c.consent_type: c.enabled for c in dash_b.consents}

        assert a_map[ConsentType.byok_data_sharing] is True
        assert a_map[ConsentType.snapshot_storage] is True
        assert a_map[ConsentType.notifications] is False

        assert b_map[ConsentType.byok_data_sharing] is False
        assert b_map[ConsentType.snapshot_storage] is False
        assert b_map[ConsentType.notifications] is True


# ===================================================================
# 6. Dashboard structure + compliance (4 tests)
# ===================================================================


class TestDashboardCompliance:
    """Dashboard structure meets nLPD + LSFin compliance requirements."""

    def test_dashboard_has_disclaimer_with_nlpd(self, manager):
        """Dashboard disclaimer references nLPD art. 6."""
        dashboard = manager.get_default_dashboard()
        assert "nLPD" in dashboard.disclaimer

    def test_dashboard_has_legal_sources(self, manager):
        """Dashboard has at least 2 legal sources."""
        dashboard = manager.get_default_dashboard()
        assert len(dashboard.sources) >= 2
        source_text = " ".join(dashboard.sources)
        assert "LPD" in source_text
        assert "LSFin" in source_text

    def test_all_consents_marked_revocable(self, manager):
        """Every consent state must have revocable=True."""
        dashboard = manager.get_default_dashboard()
        for c in dashboard.consents:
            assert c.revocable is True

    def test_consent_labels_not_empty(self, manager):
        """Every consent has non-empty label, detail, and never_sent."""
        dashboard = manager.get_default_dashboard()
        for c in dashboard.consents:
            assert len(c.label) > 0, f"{c.consent_type}: label empty"
            assert len(c.detail) > 0, f"{c.consent_type}: detail empty"
            assert len(c.never_sent) > 0, f"{c.consent_type}: never_sent empty"


# ===================================================================
# 7. BYOK field boundaries (3 tests)
# ===================================================================


class TestByokFieldBoundaries:
    """BYOK detail enforces strict data boundaries."""

    def test_sent_fields_count(self, manager):
        """Exactly 12 fields are sent to LLM provider."""
        detail = manager.get_byok_detail()
        assert len(detail["sent_fields"]) == 12

    def test_never_sent_fields_count(self, manager):
        """Exactly 7 categories of PII are never sent."""
        detail = manager.get_byok_detail()
        assert len(detail["never_sent_fields"]) == 7

    def test_byok_detail_has_disclaimer_with_lsfin(self, manager):
        """BYOK disclaimer mentions LSFin and nLPD."""
        detail = manager.get_byok_detail()
        assert "LSFin" in detail["disclaimer"]
        assert "nLPD" in detail["disclaimer"]


# ===================================================================
# 8. Consent type enum completeness (2 tests)
# ===================================================================


class TestConsentTypeEnum:
    """ConsentType enum covers exactly the 5 required types."""

    def test_exactly_five_consent_types(self):
        """There are exactly 5 consent types."""
        assert len(ConsentType) == 5

    def test_consent_type_values(self):
        """Consent type values match expected strings."""
        assert ConsentType.byok_data_sharing.value == "byok_data_sharing"
        assert ConsentType.snapshot_storage.value == "snapshot_storage"
        assert ConsentType.notifications.value == "notifications"
        assert ConsentType.document_upload.value == "document_upload"
        assert ConsentType.conversation_memory.value == "conversation_memory"
