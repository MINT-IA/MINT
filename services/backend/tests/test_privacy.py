"""
Tests for the nLPD Privacy module (conformite protection des donnees).

Covers:
    - PrivacyService.export_user_data() — 10 tests
    - PrivacyService.delete_user_data() — 10 tests
    - PrivacyService.get_consent_status() — 8 tests
    - PrivacyService.update_consent() — 6 tests
    - API endpoints (integration) — 8 tests
    - Compliance checks (banned words, disclaimers, sources) — 5 tests

Target: 47 tests.

Run: cd services/backend && python3 -m pytest tests/test_privacy.py -v
"""

import pytest
from datetime import datetime

from app.services.privacy_service import (
    PrivacyService,
    DISCLAIMER,
    GRACE_PERIOD_DAYS,
    RESPONSABLE_TRAITEMENT,
    RETENTION_POLICIES,
    SOURCES_EXPORT,
    SOURCES_DELETION,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def privacy_service():
    return PrivacyService()


@pytest.fixture
def sample_profile_data():
    return {
        "profile_id": "test-user-123",
        "age": 30,
        "canton": "ZH",
        "statut_professionnel": "salarie",
        "etat_civil": "celibataire",
    }


@pytest.fixture
def sample_sessions_data():
    return [
        {"session_id": "s1", "date": "2025-01-15", "wizard_type": "financial_checkup"},
        {"session_id": "s2", "date": "2025-02-01", "wizard_type": "3a_analysis"},
    ]


@pytest.fixture
def sample_reports_data():
    return [
        {"report_id": "r1", "type": "circle_score", "score": 72},
    ]


@pytest.fixture
def sample_documents_data():
    return [
        {"doc_id": "d1", "type": "certificat_salaire", "annee": 2024},
        {"doc_id": "d2", "type": "attestation_lpp", "annee": 2024},
    ]


@pytest.fixture
def sample_analytics_data():
    return [
        {"event": "page_view", "page": "/dashboard", "timestamp": "2025-01-15T10:00:00Z"},
        {"event": "simulation_run", "type": "3a", "timestamp": "2025-01-15T10:05:00Z"},
        {"event": "page_view", "page": "/budget", "timestamp": "2025-01-15T10:10:00Z"},
    ]


# ===========================================================================
# PrivacyService — Export (10 tests)
# ===========================================================================

class TestDataExport:
    """Tests for PrivacyService.export_user_data()."""

    def test_export_returns_profile_id(self, privacy_service, sample_profile_data):
        """Export should return the correct profile_id."""
        result = privacy_service.export_user_data(
            profile_id="test-user-123",
            profile_data=sample_profile_data,
        )
        assert result.profile_id == "test-user-123"

    def test_export_format_is_json(self, privacy_service):
        """Export format should be JSON."""
        result = privacy_service.export_user_data(profile_id="u1")
        assert result.format_donnees == "JSON"

    def test_export_date_is_iso_format(self, privacy_service):
        """Export date should be a valid ISO 8601 timestamp."""
        result = privacy_service.export_user_data(profile_id="u1")
        # Should not raise
        datetime.fromisoformat(result.date_export)

    def test_export_includes_all_categories(
        self, privacy_service, sample_profile_data,
        sample_sessions_data, sample_reports_data,
        sample_documents_data, sample_analytics_data,
    ):
        """Full export should include 5 categories."""
        result = privacy_service.export_user_data(
            profile_id="u1",
            profile_data=sample_profile_data,
            sessions_data=sample_sessions_data,
            reports_data=sample_reports_data,
            documents_data=sample_documents_data,
            analytics_data=sample_analytics_data,
        )
        assert len(result.categories) == 5
        category_names = [c.categorie for c in result.categories]
        assert "core_profile" in category_names
        assert "sessions" in category_names
        assert "rapports" in category_names
        assert "documents" in category_names
        assert "analytics" in category_names

    def test_export_category_counts(
        self, privacy_service, sample_profile_data,
        sample_sessions_data, sample_reports_data,
    ):
        """Category counts should match the data provided."""
        result = privacy_service.export_user_data(
            profile_id="u1",
            profile_data=sample_profile_data,
            sessions_data=sample_sessions_data,
            reports_data=sample_reports_data,
        )
        profile_cat = [c for c in result.categories if c.categorie == "core_profile"][0]
        sessions_cat = [c for c in result.categories if c.categorie == "sessions"][0]
        reports_cat = [c for c in result.categories if c.categorie == "rapports"][0]
        assert profile_cat.nombre_enregistrements == 1
        assert sessions_cat.nombre_enregistrements == 2
        assert reports_cat.nombre_enregistrements == 1

    def test_export_excludes_sessions_when_disabled(self, privacy_service, sample_sessions_data):
        """Export with include_sessions=False should exclude sessions."""
        result = privacy_service.export_user_data(
            profile_id="u1",
            sessions_data=sample_sessions_data,
            include_sessions=False,
        )
        assert result.donnees_sessions == []
        category_names = [c.categorie for c in result.categories]
        assert "sessions" not in category_names

    def test_export_excludes_analytics_when_disabled(self, privacy_service, sample_analytics_data):
        """Export with include_analytics=False should exclude analytics."""
        result = privacy_service.export_user_data(
            profile_id="u1",
            analytics_data=sample_analytics_data,
            include_analytics=False,
        )
        assert result.donnees_analytics == []
        category_names = [c.categorie for c in result.categories]
        assert "analytics" not in category_names

    def test_export_includes_retention_policies(self, privacy_service):
        """Export should include retention policies."""
        result = privacy_service.export_user_data(profile_id="u1")
        assert result.politique_conservation == RETENTION_POLICIES
        assert "core_profile" in result.politique_conservation

    def test_export_includes_responsable_traitement(self, privacy_service):
        """Export should include the data controller (responsable du traitement)."""
        result = privacy_service.export_user_data(profile_id="u1")
        assert result.responsable_traitement == RESPONSABLE_TRAITEMENT
        assert "MINT" in result.responsable_traitement

    def test_export_empty_profile(self, privacy_service):
        """Export with no data should still return valid structure."""
        result = privacy_service.export_user_data(profile_id="empty-user")
        assert result.profile_id == "empty-user"
        assert result.donnees_profil == {}
        assert result.donnees_sessions == []
        assert result.donnees_rapports == []
        assert result.donnees_documents == []
        assert result.donnees_analytics == []
        # Should still have at least core_profile category
        assert len(result.categories) >= 1


# ===========================================================================
# PrivacyService — Deletion (10 tests)
# ===========================================================================

class TestDataDeletion:
    """Tests for PrivacyService.delete_user_data()."""

    def test_deletion_grace_period_30_days(self, privacy_service):
        """Grace period deletion should have 30-day delay."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="grace_period",
        )
        assert result.delai_grace_jours == GRACE_PERIOD_DAYS
        assert result.delai_grace_jours == 30
        assert result.mode == "grace_period"

    def test_deletion_immediate_no_grace(self, privacy_service):
        """Immediate deletion should have 0-day delay."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
        )
        assert result.delai_grace_jours == 0
        assert result.mode == "immediate"

    def test_deletion_grace_period_date_calculation(self, privacy_service):
        """Effective deletion date should be 30 days after request for grace period."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="grace_period",
        )
        request_date = datetime.fromisoformat(result.date_demande)
        effective_date = datetime.fromisoformat(result.date_suppression_effective)
        diff = (effective_date - request_date).days
        assert diff == GRACE_PERIOD_DAYS

    def test_deletion_immediate_date_same(self, privacy_service):
        """Effective deletion date should be the same as request for immediate mode."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
        )
        request_date = datetime.fromisoformat(result.date_demande)
        effective_date = datetime.fromisoformat(result.date_suppression_effective)
        diff = (effective_date - request_date).total_seconds()
        assert diff == 0

    def test_deletion_returns_all_5_categories(self, privacy_service):
        """Deletion should process all 5 data categories."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
            nb_sessions=5, nb_reports=2, nb_documents=3, nb_analytics=10,
        )
        assert len(result.categories_traitees) == 5

    def test_deletion_core_profile_conserve_obligation_legale(self, privacy_service):
        """Core profile should be marked as conserved for legal obligation."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
        )
        profile_cat = [c for c in result.categories_traitees if c.categorie == "core_profile"][0]
        assert profile_cat.statut == "conserve_obligation_legale"
        assert profile_cat.motif_conservation is not None
        assert "CO art. 127" in profile_cat.motif_conservation

    def test_deletion_immediate_statut_supprime(self, privacy_service):
        """Immediate mode should set status to 'supprime' for non-profile categories."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
            nb_sessions=3,
        )
        sessions_cat = [c for c in result.categories_traitees if c.categorie == "sessions"][0]
        assert sessions_cat.statut == "supprime"
        assert sessions_cat.nombre_supprime == 3

    def test_deletion_grace_statut_marque(self, privacy_service):
        """Grace period should set status to 'marque_pour_suppression'."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="grace_period",
            nb_sessions=3,
        )
        sessions_cat = [c for c in result.categories_traitees if c.categorie == "sessions"][0]
        assert sessions_cat.statut == "marque_pour_suppression"

    def test_deletion_total_count(self, privacy_service):
        """Total deleted should sum all categories plus profile."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
            nb_sessions=5, nb_reports=2, nb_documents=3, nb_analytics=10,
        )
        # 5 + 2 + 3 + 10 + 1 (profile) = 21
        assert result.total_enregistrements_supprimes == 21

    def test_deletion_alertes_with_documents(self, privacy_service):
        """Deletion with documents should include a warning alert."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="grace_period",
            nb_documents=5,
        )
        alertes_text = " ".join(result.alertes)
        assert "document" in alertes_text.lower()
        assert "telecharger" in alertes_text.lower()


# ===========================================================================
# PrivacyService — Consent Status (8 tests)
# ===========================================================================

class TestConsentStatus:
    """Tests for PrivacyService.get_consent_status()."""

    def test_consent_default_only_core_active(self, privacy_service):
        """By default (Privacy by Design), only core_profile should be active."""
        result = privacy_service.get_consent_status(profile_id="u1")
        active_cats = [c for c in result.consentements if c.est_actif]
        active_names = [c.categorie for c in active_cats]
        assert "core_profile" in active_names
        # Other optional categories should not be active by default
        for c in result.consentements:
            if c.categorie != "core_profile":
                assert c.est_actif is False, f"{c.categorie} should not be active by default"

    def test_consent_returns_6_categories(self, privacy_service):
        """Should return exactly 6 consent categories."""
        result = privacy_service.get_consent_status(profile_id="u1")
        assert len(result.consentements) == 6

    def test_consent_categories_complete(self, privacy_service):
        """All expected categories should be present."""
        result = privacy_service.get_consent_status(profile_id="u1")
        categories = {c.categorie for c in result.consentements}
        expected = {"core_profile", "analytics", "coaching_notifications",
                    "open_banking", "document_upload", "rag_queries"}
        assert categories == expected

    def test_consent_core_profile_is_obligatory(self, privacy_service):
        """core_profile should be marked as obligatory."""
        result = privacy_service.get_consent_status(profile_id="u1")
        core = [c for c in result.consentements if c.categorie == "core_profile"][0]
        assert core.est_obligatoire is True
        assert core.peut_etre_retire is False
        assert core.base_legale == "contract"

    def test_consent_optional_categories_can_be_withdrawn(self, privacy_service):
        """Optional categories should allow withdrawal."""
        result = privacy_service.get_consent_status(profile_id="u1")
        for c in result.consentements:
            if c.categorie != "core_profile":
                assert c.est_obligatoire is False
                assert c.peut_etre_retire is True

    def test_consent_open_banking_explicit(self, privacy_service):
        """open_banking should require explicit consent."""
        result = privacy_service.get_consent_status(profile_id="u1")
        ob = [c for c in result.consentements if c.categorie == "open_banking"][0]
        assert ob.base_legale == "explicit_consent"

    def test_consent_custom_consents_reflected(self, privacy_service):
        """Custom consents dict should be reflected in the status."""
        custom = {
            "core_profile": True,
            "analytics": True,
            "coaching_notifications": True,
            "open_banking": False,
            "document_upload": True,
            "rag_queries": False,
        }
        result = privacy_service.get_consent_status(
            profile_id="u1",
            current_consents=custom,
        )
        for c in result.consentements:
            assert c.est_actif == custom[c.categorie], (
                f"{c.categorie} should be {custom[c.categorie]}"
            )

    def test_consent_count_actifs_and_optionnels(self, privacy_service):
        """Active and optional counts should be correct."""
        custom = {
            "core_profile": True,
            "analytics": True,
            "coaching_notifications": False,
            "open_banking": False,
            "document_upload": True,
            "rag_queries": False,
        }
        result = privacy_service.get_consent_status(
            profile_id="u1",
            current_consents=custom,
        )
        assert result.nb_consentements_actifs == 3  # core, analytics, documents
        assert result.nb_consentements_optionnels == 5  # all except core


# ===========================================================================
# PrivacyService — Consent Update (6 tests)
# ===========================================================================

class TestConsentUpdate:
    """Tests for PrivacyService.update_consent()."""

    def test_update_activate_analytics(self, privacy_service):
        """Activating analytics consent should succeed."""
        result = privacy_service.update_consent(
            profile_id="u1", categorie="analytics", est_actif=True,
        )
        assert result.est_actif is True
        assert result.categorie == "analytics"
        assert "Consentement accorde" in result.message

    def test_update_deactivate_analytics(self, privacy_service):
        """Deactivating analytics consent should succeed."""
        result = privacy_service.update_consent(
            profile_id="u1", categorie="analytics", est_actif=False,
        )
        assert result.est_actif is False
        assert "Consentement retire" in result.message

    def test_update_core_profile_cannot_be_deactivated(self, privacy_service):
        """Deactivating core_profile should raise ValueError."""
        with pytest.raises(ValueError, match="requis"):
            privacy_service.update_consent(
                profile_id="u1", categorie="core_profile", est_actif=False,
            )

    def test_update_core_profile_can_be_activated(self, privacy_service):
        """Activating core_profile should succeed (it's already active but the call is valid)."""
        result = privacy_service.update_consent(
            profile_id="u1", categorie="core_profile", est_actif=True,
        )
        assert result.est_actif is True

    def test_update_unknown_category_raises(self, privacy_service):
        """Unknown category should raise ValueError."""
        with pytest.raises(ValueError, match="inconnue"):
            privacy_service.update_consent(
                profile_id="u1", categorie="unknown_category", est_actif=True,
            )

    def test_update_date_is_iso_format(self, privacy_service):
        """Update date should be a valid ISO 8601 timestamp."""
        result = privacy_service.update_consent(
            profile_id="u1", categorie="analytics", est_actif=True,
        )
        # Should not raise
        datetime.fromisoformat(result.date_modification)


# ===========================================================================
# Compliance Checks (5 tests)
# ===========================================================================

class TestComplianceChecks:
    """Verify compliance with MINT rules: disclaimers, sources, banned words."""

    def test_disclaimer_no_banned_words(self):
        """Disclaimer should not contain banned words."""
        banned = ["garanti", "certain", "assure", "sans risque",
                  "optimal", "meilleur", "parfait", "conseiller"]
        for word in banned:
            assert word not in DISCLAIMER.lower(), f"Banned word '{word}' found in DISCLAIMER"

    def test_disclaimer_mentions_specialiste(self):
        """Disclaimer should mention 'specialiste' (not 'conseiller')."""
        assert "specialiste" in DISCLAIMER.lower()

    def test_disclaimer_mentions_nlpd(self):
        """Disclaimer should reference nLPD."""
        assert "nLPD" in DISCLAIMER

    def test_sources_export_reference_nlpd_art_25(self):
        """Export sources should reference nLPD art. 25."""
        source_text = " ".join(SOURCES_EXPORT)
        assert "nLPD art. 25" in source_text

    def test_sources_deletion_reference_nlpd_and_co(self):
        """Deletion sources should reference nLPD and CO."""
        source_text = " ".join(SOURCES_DELETION)
        assert "nLPD" in source_text
        assert "CO art. 127" in source_text

    def test_export_premier_eclairage_has_content(self, privacy_service):
        """Export premier éclairage should mention enregistrement(s)."""
        result = privacy_service.export_user_data(
            profile_id="u1",
            profile_data={"age": 30},
            sessions_data=[{"s": 1}, {"s": 2}],
        )
        assert "enregistrement" in result.premier_eclairage.lower()
        assert "categorie" in result.premier_eclairage.lower()

    def test_deletion_premier_eclairage_has_content(self, privacy_service):
        """Deletion premier éclairage should mention the count and nLPD."""
        result = privacy_service.delete_user_data(
            profile_id="u1", mode="immediate",
            nb_sessions=5, nb_reports=2,
        )
        assert "enregistrement" in result.premier_eclairage.lower()
        assert "nLPD" in result.premier_eclairage

    def test_consent_premier_eclairage_has_content(self, privacy_service):
        """Consent premier éclairage should mention traitement(s) and nLPD."""
        result = privacy_service.get_consent_status(profile_id="u1")
        assert "traitement" in result.premier_eclairage.lower()
        assert "nLPD" in result.premier_eclairage


# ===========================================================================
# API Endpoint Tests (integration) — 8 tests
# ===========================================================================

class TestPrivacyEndpoints:
    """Integration tests for privacy FastAPI endpoints."""

    def test_export_endpoint_200(self, client):
        """POST /privacy/export should return 200.

        V12-1: profileId in request body is ignored; server uses _user.id.
        """
        response = client.post(
            "/api/v1/privacy/export",
            json={
                "includeSessions": True,
                "includeReports": True,
                "includeDocuments": True,
                "includeAnalytics": True,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "profileId" in data
        # V12-1: profileId in response is now the authenticated user's ID
        assert data["profileId"] == "test-user-id"
        assert "dateExport" in data
        assert "formatDonnees" in data
        assert "categories" in data
        assert "donneesProfilel" in data or "donneesProfil" in data
        assert "disclaimer" in data
        assert "sources" in data
        assert "premierEclairage" in data
        assert "responsableTraitement" in data

    def test_export_endpoint_camelcase(self, client):
        """Export response should use camelCase aliases."""
        response = client.post(
            "/api/v1/privacy/export",
            json={},
        )
        assert response.status_code == 200
        data = response.json()
        assert "profileId" in data
        assert "dateExport" in data
        assert "formatDonnees" in data
        assert "politiqueConservation" in data

    def test_export_ignores_client_supplied_profile_id(self, client):
        """V12-1: Even if client sends profileId, server uses _user.id."""
        response = client.post(
            "/api/v1/privacy/export",
            json={"profileId": "attacker-supplied-id"},
        )
        assert response.status_code == 200
        data = response.json()
        # Must be the authenticated user's ID, not the attacker's
        assert data["profileId"] == "test-user-id"

    def test_delete_endpoint_grace_period(self, client):
        """POST /privacy/delete with grace period should return 200."""
        response = client.post(
            "/api/v1/privacy/delete",
            json={
                "mode": "grace_period",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["mode"] == "grace_period"
        assert data["delaiGraceJours"] == 30
        assert "categoriesTraitees" in data
        assert "disclaimer" in data
        # V12-1: profileId in response is the authenticated user's ID
        assert data["profileId"] == "test-user-id"

    def test_delete_endpoint_immediate(self, client):
        """POST /privacy/delete with immediate mode should return 200."""
        response = client.post(
            "/api/v1/privacy/delete",
            json={
                "mode": "immediate",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["mode"] == "immediate"
        assert data["delaiGraceJours"] == 0
        assert data["profileId"] == "test-user-id"

    def test_consent_status_endpoint(self, client):
        """GET /privacy/consent-status should return 200.

        V12-1: No longer takes profile_id as query param; uses _user.id.
        """
        response = client.get("/api/v1/privacy/consent-status")
        assert response.status_code == 200
        data = response.json()
        assert "profileId" in data
        assert data["profileId"] == "test-user-id"
        assert "consentements" in data
        assert len(data["consentements"]) == 6
        assert "nbConsentementsActifs" in data
        assert "nbConsentementsOptionnels" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_consent_status_has_6_categories(self, client):
        """Consent status should list exactly 6 categories."""
        response = client.get("/api/v1/privacy/consent-status")
        assert response.status_code == 200
        data = response.json()
        categories = [c["categorie"] for c in data["consentements"]]
        assert len(categories) == 6
        assert "core_profile" in categories
        assert "analytics" in categories
        assert "coaching_notifications" in categories
        assert "open_banking" in categories
        assert "document_upload" in categories
        assert "rag_queries" in categories

    def test_consent_update_activate(self, client):
        """POST /privacy/consent-update should activate a consent.

        V12-1: profileId in request body is ignored; server uses _user.id.
        """
        response = client.post(
            "/api/v1/privacy/consent-update",
            json={
                "categorie": "analytics",
                "estActif": True,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["estActif"] is True
        assert data["categorie"] == "analytics"
        assert data["profileId"] == "test-user-id"
        assert "dateModification" in data
        assert "disclaimer" in data

    def test_consent_update_reject_core_profile_deactivation(self, client):
        """POST /privacy/consent-update should reject deactivating core_profile."""
        response = client.post(
            "/api/v1/privacy/consent-update",
            json={
                "categorie": "core_profile",
                "estActif": False,
            },
        )
        assert response.status_code == 400
        data = response.json()
        assert "requis" in data["detail"].lower() or "obligatoire" in data["detail"].lower() or "contractuelle" in data["detail"].lower()
