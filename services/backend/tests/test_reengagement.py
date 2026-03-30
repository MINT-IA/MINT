"""
Tests for Reengagement Engine + Consent Hardening — Sprint S40.

Test categories:
    1. Calendar messages (7 tests): each month trigger generates correct message
    2. Personal numbers present (3 tests): every message has personal_number + time_constraint
    3. Consent defaults (3 tests): all OFF by default, correct labels, revocable
    4. BYOK detail (2 tests): sent fields correct, never-sent fields listed
    5. Compliance (3 tests): no generic encouragement, no banned terms, disclaimer present

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from datetime import date

import pytest

from app.services.reengagement.reengagement_engine import ReengagementEngine
from app.services.reengagement.reengagement_models import (
    ConsentType,
    ReengagementTrigger,
)
from app.services.reengagement.consent_manager import ConsentManager


# ===================================================================
# Banned generic phrases — reengagement must NEVER use these
# ===================================================================

BANNED_GENERIC = [
    "tu nous manques",
    "reviens",
    "nouvelles fonctionnalites",
    "n'as pas utilise",
    "garanti",
    "certain",
    "optimal",
]


# ===================================================================
# Fixtures
# ===================================================================


@pytest.fixture
def engine():
    return ReengagementEngine()


@pytest.fixture
def consent_manager():
    return ConsentManager()


# ===================================================================
# 1. Calendar messages (7 tests)
# ===================================================================


class TestCalendarMessages:
    """Each calendar month trigger generates the correct message type."""

    def test_january_new_year(self, engine):
        """January generates a new_year message with 3a ceiling."""
        msgs = engine.generate_messages(
            today=date(2026, 1, 15),
            tax_saving_3a=1500.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.new_year in triggers
        new_year_msg = next(
            m for m in msgs if m.trigger == ReengagementTrigger.new_year
        )
        assert "7'258" in new_year_msg.body
        assert "1'500" in new_year_msg.body
        assert new_year_msg.month == 1

    def test_february_tax_prep(self, engine):
        """February generates a tax_prep message."""
        msgs = engine.generate_messages(
            today=date(2026, 2, 10),
            tax_saving_3a=2000.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.tax_prep in triggers
        tax_msg = next(
            m for m in msgs if m.trigger == ReengagementTrigger.tax_prep
        )
        assert "declaration" in tax_msg.body.lower()
        assert tax_msg.month == 2

    def test_march_tax_deadline(self, engine):
        """March generates a tax_deadline message with canton."""
        msgs = engine.generate_messages(
            today=date(2026, 3, 5),
            canton="GE",
            tax_saving_3a=1200.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.tax_deadline in triggers
        deadline_msg = next(
            m for m in msgs if m.trigger == ReengagementTrigger.tax_deadline
        )
        assert "GE" in deadline_msg.body
        assert deadline_msg.month == 3

    def test_october_3a_countdown(self, engine):
        """October generates a three_a_countdown message with days remaining."""
        msgs = engine.generate_messages(
            today=date(2026, 10, 1),
            tax_saving_3a=1800.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.three_a_countdown in triggers
        countdown_msg = next(
            m for m in msgs
            if m.trigger == ReengagementTrigger.three_a_countdown
        )
        assert "jours" in countdown_msg.body
        assert "1'800" in countdown_msg.body
        assert countdown_msg.month == 10

    def test_november_3a_urgency(self, engine):
        """November generates a three_a_urgency message."""
        msgs = engine.generate_messages(
            today=date(2026, 11, 15),
            tax_saving_3a=2500.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.three_a_urgency in triggers
        urgency_msg = next(
            m for m in msgs
            if m.trigger == ReengagementTrigger.three_a_urgency
        )
        assert "jours" in urgency_msg.body
        assert "2'500" in urgency_msg.body
        assert urgency_msg.month == 11

    def test_december_3a_final(self, engine):
        """December generates a three_a_final message."""
        msgs = engine.generate_messages(
            today=date(2026, 12, 1),
            tax_saving_3a=3000.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.three_a_final in triggers
        final_msg = next(
            m for m in msgs
            if m.trigger == ReengagementTrigger.three_a_final
        )
        assert "Dernier mois" in final_msg.body
        assert "3'000" in final_msg.body
        assert final_msg.month == 12

    def test_quarterly_fri_april(self, engine):
        """April generates a quarterly_fri message."""
        msgs = engine.generate_messages(
            today=date(2026, 4, 1),
            fri_total=72.0,
            fri_delta=5.0,
        )
        triggers = [m.trigger for m in msgs]
        assert ReengagementTrigger.quarterly_fri in triggers
        fri_msg = next(
            m for m in msgs
            if m.trigger == ReengagementTrigger.quarterly_fri
        )
        assert "72" in fri_msg.body
        assert "+5" in fri_msg.body
        assert fri_msg.month == 4


# ===================================================================
# 2. Personal numbers present (3 tests)
# ===================================================================


class TestPersonalNumbers:
    """Every message must include personal_number and time_constraint."""

    def test_all_messages_have_personal_number(self, engine):
        """Every generated message has a non-empty personal_number."""
        for month in range(1, 13):
            msgs = engine.generate_messages(
                today=date(2026, month, 15),
                tax_saving_3a=1000.0,
                fri_total=50.0,
                fri_delta=3.0,
            )
            for msg in msgs:
                assert msg.personal_number, (
                    f"Month {month}, trigger {msg.trigger}: "
                    f"personal_number is empty"
                )

    def test_all_messages_have_time_constraint(self, engine):
        """Every generated message has a non-empty time_constraint."""
        for month in range(1, 13):
            msgs = engine.generate_messages(
                today=date(2026, month, 15),
                tax_saving_3a=1000.0,
                fri_total=50.0,
                fri_delta=3.0,
            )
            for msg in msgs:
                assert msg.time_constraint, (
                    f"Month {month}, trigger {msg.trigger}: "
                    f"time_constraint is empty"
                )

    def test_all_messages_have_deeplink(self, engine):
        """Every generated message has a non-empty deeplink."""
        for month in range(1, 13):
            msgs = engine.generate_messages(
                today=date(2026, month, 15),
                tax_saving_3a=1000.0,
                fri_total=50.0,
                fri_delta=3.0,
            )
            for msg in msgs:
                assert msg.deeplink.startswith("/"), (
                    f"Month {month}, trigger {msg.trigger}: "
                    f"deeplink should start with /"
                )


# ===================================================================
# 3. Consent defaults (3 tests)
# ===================================================================


class TestConsentDefaults:
    """All consents must be OFF by default and correctly structured."""

    def test_all_consents_off_by_default(self, consent_manager):
        """All 5 consents must start disabled (opt-in model)."""
        dashboard = consent_manager.get_default_dashboard()
        assert len(dashboard.consents) == 5
        for consent in dashboard.consents:
            assert consent.enabled is False, (
                f"Consent {consent.consent_type.value} should be OFF by default"
            )

    def test_consent_labels_in_french(self, consent_manager):
        """All consent labels must be in French."""
        dashboard = consent_manager.get_default_dashboard()
        for consent in dashboard.consents:
            assert consent.label, "Consent label is empty"
            assert consent.detail, "Consent detail is empty"
            assert consent.never_sent, "Consent never_sent is empty"

    def test_all_consents_revocable(self, consent_manager):
        """All consents must be revocable at any time."""
        dashboard = consent_manager.get_default_dashboard()
        for consent in dashboard.consents:
            assert consent.revocable is True, (
                f"Consent {consent.consent_type.value} must be revocable"
            )


# ===================================================================
# 4. BYOK detail (2 tests)
# ===================================================================


class TestByokDetail:
    """BYOK detail must list sent and never-sent fields."""

    def test_sent_fields_correct(self, consent_manager):
        """Sent fields include the expected anonymized fields."""
        detail = consent_manager.get_byok_detail()
        sent = detail["sent_fields"]
        expected = [
            "firstName", "archetype", "age", "canton",
            "friTotal", "friDelta", "replacementRatio",
            "monthsLiquidity", "taxSavingPotential",
            "confidenceScore", "daysSinceLastVisit", "fiscalSeason",
        ]
        for field_name in expected:
            assert field_name in sent, f"Missing sent field: {field_name}"

    def test_never_sent_fields_listed(self, consent_manager):
        """Never-sent fields include PII and sensitive financial data."""
        detail = consent_manager.get_byok_detail()
        never_sent = detail["never_sent_fields"]
        assert "exact salary" in never_sent
        assert "exact savings" in never_sent
        assert "exact debt" in never_sent
        assert "bank names" in never_sent
        assert "employer name" in never_sent
        assert "NPA/address" in never_sent
        assert "family names" in never_sent


# ===================================================================
# 5. Compliance (3 tests)
# ===================================================================


class TestCompliance:
    """Compliance checks: no generic encouragement, no banned terms."""

    def test_no_generic_encouragement(self, engine):
        """No message body may contain banned generic phrases."""
        for month in range(1, 13):
            msgs = engine.generate_messages(
                today=date(2026, month, 15),
                tax_saving_3a=1000.0,
                fri_total=50.0,
                fri_delta=3.0,
            )
            for msg in msgs:
                body_lower = msg.body.lower()
                title_lower = msg.title.lower()
                for banned in BANNED_GENERIC:
                    assert banned not in body_lower, (
                        f"Month {month}: body contains banned phrase "
                        f"'{banned}': {msg.body}"
                    )
                    assert banned not in title_lower, (
                        f"Month {month}: title contains banned phrase "
                        f"'{banned}': {msg.title}"
                    )

    def test_no_banned_terms_in_consent(self, consent_manager):
        """Consent labels and details must not contain banned terms."""
        dashboard = consent_manager.get_default_dashboard()
        for consent in dashboard.consents:
            for text in [consent.label, consent.detail, consent.never_sent]:
                text_lower = text.lower()
                for banned in BANNED_GENERIC:
                    assert banned not in text_lower, (
                        f"Consent '{consent.consent_type.value}' contains "
                        f"banned phrase '{banned}': {text}"
                    )

    def test_disclaimer_present_in_consent(self, consent_manager):
        """Consent dashboard must have a disclaimer with nLPD reference."""
        dashboard = consent_manager.get_default_dashboard()
        assert dashboard.disclaimer, "Disclaimer is empty"
        assert "nLPD" in dashboard.disclaimer, (
            "Disclaimer must reference nLPD"
        )
        assert len(dashboard.sources) >= 2, (
            "At least 2 legal sources required"
        )


# ===================================================================
# 6. Additional edge case tests
# ===================================================================


class TestEdgeCases:
    """Edge cases and boundary conditions."""

    def test_no_messages_in_non_trigger_month(self, engine):
        """Months without triggers (e.g. May) generate no messages."""
        msgs = engine.generate_messages(
            today=date(2026, 5, 15),
            tax_saving_3a=1000.0,
        )
        assert len(msgs) == 0

    def test_january_has_two_messages(self, engine):
        """January triggers both new_year and quarterly_fri."""
        msgs = engine.generate_messages(
            today=date(2026, 1, 15),
            tax_saving_3a=1500.0,
            fri_total=65.0,
            fri_delta=-2.0,
        )
        triggers = {m.trigger for m in msgs}
        assert ReengagementTrigger.new_year in triggers
        assert ReengagementTrigger.quarterly_fri in triggers
        assert len(msgs) == 2

    def test_october_has_two_messages(self, engine):
        """October triggers both three_a_countdown and quarterly_fri."""
        msgs = engine.generate_messages(
            today=date(2026, 10, 1),
            tax_saving_3a=1500.0,
            fri_total=80.0,
            fri_delta=10.0,
        )
        triggers = {m.trigger for m in msgs}
        assert ReengagementTrigger.three_a_countdown in triggers
        assert ReengagementTrigger.quarterly_fri in triggers
        assert len(msgs) == 2

    def test_chf_formatting_with_apostrophe(self, engine):
        """CHF amounts must use Swiss apostrophe formatting."""
        msgs = engine.generate_messages(
            today=date(2026, 1, 15),
            tax_saving_3a=12345.0,
        )
        new_year_msg = next(
            m for m in msgs if m.trigger == ReengagementTrigger.new_year
        )
        assert "12'345" in new_year_msg.body

    def test_negative_fri_delta(self, engine):
        """Negative FRI delta is displayed without + sign."""
        msgs = engine.generate_messages(
            today=date(2026, 4, 1),
            fri_total=45.0,
            fri_delta=-8.0,
        )
        fri_msg = next(
            m for m in msgs
            if m.trigger == ReengagementTrigger.quarterly_fri
        )
        assert "-8" in fri_msg.body
        assert "+8" not in fri_msg.body

    def test_title_max_60_chars(self, engine):
        """All message titles must be 60 characters or fewer."""
        for month in range(1, 13):
            msgs = engine.generate_messages(
                today=date(2026, month, 15),
                canton="GE",
                tax_saving_3a=36288.0,
                fri_total=99.0,
                fri_delta=25.0,
            )
            for msg in msgs:
                assert len(msg.title) <= 60, (
                    f"Month {month}, trigger {msg.trigger}: "
                    f"title too long ({len(msg.title)} chars): {msg.title}"
                )

    def test_consent_types_are_five_independent(self, consent_manager):
        """Consent dashboard has exactly 5 independent consent types."""
        dashboard = consent_manager.get_default_dashboard()
        types = {c.consent_type for c in dashboard.consents}
        assert types == {
            ConsentType.byok_data_sharing,
            ConsentType.snapshot_storage,
            ConsentType.notifications,
            ConsentType.document_upload,
            ConsentType.conversation_memory,
        }

    def test_byok_detail_has_disclaimer_and_sources(self, consent_manager):
        """BYOK detail must include disclaimer and legal sources."""
        detail = consent_manager.get_byok_detail()
        assert "LSFin" in detail["disclaimer"]
        assert "nLPD" in detail["disclaimer"]
        assert len(detail["sources"]) >= 2
