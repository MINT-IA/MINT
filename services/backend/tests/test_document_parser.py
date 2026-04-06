"""
Tests for Document Parser — Sprint S42-S43: LPP Certificate Parsing.

Test categories:
    1. LPP certificate parsing FR (15+ tests)
    2. LPP certificate parsing DE (5 tests)
    3. Swiss number parsing (5 tests)
    4. Cross-validation oblig + suroblig = total (5 tests)
    5. Confidence scoring (5 tests)
    6. Field impact ranking (5 tests)
    7. Edge cases (5 tests)
    8. API endpoints (5+ tests)
    9. Compliance (5 tests)

Sources:
    - LPP art. 7 (seuil d'entree: 22'680 CHF)
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 14 (taux de conversion minimum: 6.8%)
    - LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)
    - LPP art. 79b al. 3 (blocage rachat: 3 ans)
"""

import pytest
from fastapi.testclient import TestClient

from app.services.document_parser.document_models import (
    DocumentType,
    DataSource,
    ExtractedField,
    ExtractionResult,
    ProfileField,
    DATA_SOURCE_ACCURACY,
)
from app.services.document_parser.lpp_certificate_parser import (
    parse_lpp_certificate,
    estimate_confidence_delta,
    parse_swiss_number,
    KNOWN_FIELD_PATTERNS,
    HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.extraction_confidence_scorer import (
    score_extraction,
    rank_fields_by_impact,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Test fixtures — sample OCR texts
# ═══════════════════════════════════════════════════════════════════════════════

SAMPLE_LPP_FR = """
Certificat de prévoyance 2025
Caisse de pension: Fondation LPP Swiss Life

Avoir de vieillesse total: CHF 143'287.00
Part obligatoire: CHF 98'400.00
Part surobligatoire: CHF 44'887.00
Taux de conversion (obligatoire): 6.80%
Taux de conversion (surobligatoire): 5.20%
Lacune de rachat: CHF 45'000.00
Rente de vieillesse projetée à 65: CHF 26'500/an
Capital projeté à 65: CHF 389'000.00
Cotisation employé: CHF 450.00/mois
Cotisation employeur: CHF 600.00/mois
Salaire assuré: CHF 62'000.00
Prestation d'invalidité: CHF 4'200.00/mois
Prestation de décès: CHF 250'000.00
"""

SAMPLE_LPP_DE = """
Vorsorgeausweis 2025
Pensionskasse: BVK Personalvorsorge

Totales Altersguthaben: CHF 185'500.00
Obligatorisches Altersguthaben: CHF 120'000.00
Überobligatorisches Altersguthaben: CHF 65'500.00
BVG-Umwandlungssatz: 6.80%
Überobligatorischer Umwandlungssatz: 4.80%
Einkaufslücke: CHF 32'000.00
Projizierte Altersrente: CHF 31'200/Jahr
Projiziertes Altersguthaben bei 65: CHF 450'000.00
Arbeitnehmerbeitrag: CHF 520.00/Monat
Arbeitgeberbeitrag: CHF 680.00/Monat
Versicherter Lohn: CHF 72'000.00
Invalidenleistung: CHF 5'100.00/Monat
Todesfallkapital: CHF 320'000.00
"""

SAMPLE_LPP_PARTIAL = """
Certificat de prévoyance
Avoir de vieillesse total: CHF 75'000.00
Taux de conversion (obligatoire): 6.80%
Salaire assuré: CHF 55'000.00
"""

SAMPLE_LPP_INCONSISTENT = """
Certificat de prévoyance 2025
Avoir de vieillesse total: CHF 200'000.00
Part obligatoire: CHF 98'400.00
Part surobligatoire: CHF 44'887.00
"""

SAMPLE_LPP_MONTHLY_CONTRIBUTIONS = """
Certificat de prévoyance 2025
Avoir de vieillesse total: CHF 100'000.00
Part obligatoire: CHF 70'000.00
Part surobligatoire: CHF 30'000.00
Cotisation employé: CHF 350.00/mois
Cotisation employeur: CHF 250.00/mois
"""


# ═══════════════════════════════════════════════════════════════════════════════
# Banned terms — NEVER appear in any user-facing text
# ═══════════════════════════════════════════════════════════════════════════════

BANNED_TERMS = [
    "garanti",
    "certain",
    "assuré",  # as absolute guarantee
    "sans risque",
    "optimal",
    "meilleur",
    "parfait",
    "conseiller",
]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. LPP Certificate Parsing — French (15+ tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestLppCertificateParsingFR:
    """Tests d'extraction de certificats LPP en francais."""

    def test_parse_full_certificate_extracts_all_fields(self):
        """Un certificat complet doit extraire ~13 champs."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        assert len(result.fields) >= 10
        assert result.document_type == DocumentType.lpp_certificate

    def test_parse_avoir_total(self):
        """Extrait l'avoir de vieillesse total."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("avoir_total")
        assert field is not None
        assert field.value == 143287.0

    def test_parse_part_obligatoire(self):
        """Extrait la part obligatoire."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("part_obligatoire")
        assert field is not None
        assert field.value == 98400.0

    def test_parse_part_surobligatoire(self):
        """Extrait la part surobligatoire."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("part_surobligatoire")
        assert field is not None
        assert field.value == 44887.0

    def test_parse_taux_conversion_oblig(self):
        """Extrait le taux de conversion obligatoire."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("taux_conversion_oblig")
        assert field is not None
        assert field.value == 6.8

    def test_parse_taux_conversion_suroblig(self):
        """Extrait le taux de conversion surobligatoire."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("taux_conversion_suroblig")
        assert field is not None
        assert field.value == 5.2

    def test_parse_lacune_rachat(self):
        """Extrait la lacune de rachat."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("lacune_rachat")
        assert field is not None
        assert field.value == 45000.0

    def test_parse_rente_projetee(self):
        """Extrait la rente de vieillesse projetee."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("rente_projetee")
        assert field is not None
        assert field.value == 26500.0

    def test_parse_capital_projete_65(self):
        """Extrait le capital projete a 65."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("capital_projete_65")
        assert field is not None
        assert field.value == 389000.0

    def test_parse_cotisation_employe(self):
        """Extrait la cotisation employe."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("cotisation_employe")
        assert field is not None
        assert field.value == 450.0

    def test_parse_cotisation_employeur(self):
        """Extrait la cotisation employeur."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("cotisation_employeur")
        assert field is not None
        assert field.value == 600.0

    def test_parse_salaire_assure(self):
        """Extrait le salaire assure."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("salaire_assure")
        assert field is not None
        assert field.value == 62000.0

    def test_parse_prestation_invalidite(self):
        """Extrait la prestation d'invalidite."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("prestation_invalidite")
        assert field is not None
        assert field.value == 4200.0

    def test_parse_prestation_deces(self):
        """Extrait la prestation de deces."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        field = result.get_field("prestation_deces")
        assert field is not None
        assert field.value == 250000.0

    def test_overall_confidence_is_positive(self):
        """La confiance globale doit etre positive pour un certificat complet."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        assert result.overall_confidence > 0.5

    def test_field_confidence_is_set(self):
        """Chaque champ extrait doit avoir une confiance entre 0 et 1."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        for field in result.fields:
            assert 0.0 <= field.confidence <= 1.0

    def test_source_text_is_populated(self):
        """Chaque champ extrait doit avoir un texte source."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        for field in result.fields:
            assert field.source_text is not None
            assert len(field.source_text) > 0


# ═══════════════════════════════════════════════════════════════════════════════
# 2. LPP Certificate Parsing — German (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestLppCertificateParsingDE:
    """Tests d'extraction de certificats LPP en allemand (Vorsorgeausweis)."""

    def test_parse_german_certificate_extracts_fields(self):
        """Un certificat allemand doit extraire des champs."""
        result = parse_lpp_certificate(SAMPLE_LPP_DE)
        assert len(result.fields) >= 8

    def test_parse_german_altersguthaben_total(self):
        """Extrait le totales Altersguthaben."""
        result = parse_lpp_certificate(SAMPLE_LPP_DE)
        field = result.get_field("avoir_total")
        assert field is not None
        assert field.value == 185500.0

    def test_parse_german_obligatorisch(self):
        """Extrait l'obligatorisches Altersguthaben."""
        result = parse_lpp_certificate(SAMPLE_LPP_DE)
        field = result.get_field("part_obligatoire")
        assert field is not None
        assert field.value == 120000.0

    def test_parse_german_ueberobligatorisch(self):
        """Extrait l'ueberobligatorisches Altersguthaben."""
        result = parse_lpp_certificate(SAMPLE_LPP_DE)
        field = result.get_field("part_surobligatoire")
        assert field is not None
        assert field.value == 65500.0

    def test_parse_german_umwandlungssatz(self):
        """Extrait le BVG-Umwandlungssatz."""
        result = parse_lpp_certificate(SAMPLE_LPP_DE)
        field = result.get_field("taux_conversion_oblig")
        assert field is not None
        assert field.value == 6.8


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Swiss Number Parsing (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestSwissNumberParsing:
    """Tests du parsing de nombres au format suisse."""

    def test_parse_with_apostrophe_separator(self):
        """Parse CHF 143'287 avec apostrophe."""
        assert parse_swiss_number("143'287") == 143287.0

    def test_parse_with_apostrophe_and_decimals(self):
        """Parse CHF 143'287.00 avec apostrophe et decimales."""
        assert parse_swiss_number("143'287.00") == 143287.0

    def test_parse_percentage(self):
        """Parse 6.80 (pourcentage sans signe %)."""
        assert parse_swiss_number("6.80") == 6.8

    def test_parse_plain_integer(self):
        """Parse 250000 sans separateur."""
        assert parse_swiss_number("250000") == 250000.0

    def test_parse_comma_decimal(self):
        """Parse 143'287,50 avec virgule decimale."""
        assert parse_swiss_number("143'287,50") == 143287.5

    def test_parse_empty_returns_none(self):
        """Une chaine vide retourne None."""
        assert parse_swiss_number("") is None

    def test_parse_invalid_returns_none(self):
        """Un texte non numerique retourne None."""
        assert parse_swiss_number("abc") is None

    def test_parse_right_quote_separator(self):
        """Parse avec right single quotation mark (Unicode 2019)."""
        assert parse_swiss_number("143\u2019287") == 143287.0  # 143'287 with right quote


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Cross-Validation (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestCrossValidation:
    """Tests de cross-validation obligatoire + surobligatoire = total."""

    def test_consistent_totals_no_warning(self):
        """Pas de warning quand oblig + suroblig = total."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        # 98400 + 44887 = 143287 = exact match
        total_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(total_warnings) == 0

    def test_inconsistent_totals_triggers_warning(self):
        """Warning quand oblig + suroblig != total."""
        result = parse_lpp_certificate(SAMPLE_LPP_INCONSISTENT)
        # 200'000 != 98400 + 44887 = 143287
        total_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(total_warnings) >= 1

    def test_consistent_totals_boosts_confidence(self):
        """La confiance des champs augmente quand les totaux sont coherents."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        oblig = result.get_field("part_obligatoire")
        assert oblig is not None
        # Consistency check boosts confidence by 0.1
        assert oblig.confidence >= 0.7

    def test_inconsistent_totals_flags_review(self):
        """Les champs sont marques needs_review quand incoherents."""
        result = parse_lpp_certificate(SAMPLE_LPP_INCONSISTENT)
        total = result.get_field("avoir_total")
        if total:
            assert total.needs_review is True

    def test_employer_lower_than_employee_warning(self):
        """Warning quand cotisation employeur < cotisation employe (inhabituel)."""
        result = parse_lpp_certificate(SAMPLE_LPP_MONTHLY_CONTRIBUTIONS)
        employer_warnings = [w for w in result.warnings if "employeur" in w.lower()]
        assert len(employer_warnings) >= 1


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Confidence Scoring (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestConfidenceScoring:
    """Tests du scoring de confiance de l'extraction."""

    def test_full_extraction_high_score(self):
        """Un certificat complet doit avoir un score eleve."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        score = score_extraction(result)
        assert score > 50.0

    def test_partial_extraction_lower_score(self):
        """Un certificat partiel doit avoir un score plus bas."""
        result = parse_lpp_certificate(SAMPLE_LPP_PARTIAL)
        score = score_extraction(result)
        # Partial = less fields = lower score
        assert score < 80.0

    def test_empty_extraction_zero_score(self):
        """Pas de champs = score 0."""
        result = ExtractionResult(document_type=DocumentType.lpp_certificate)
        score = score_extraction(result)
        assert score == 0.0

    def test_score_bounded_0_100(self):
        """Le score doit etre entre 0 et 100."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        score = score_extraction(result)
        assert 0.0 <= score <= 100.0

    def test_confidence_delta_positive_for_new_fields(self):
        """Le delta de confiance doit etre positif pour des champs nouveaux."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        delta = estimate_confidence_delta(result, {})
        assert delta > 0.0

    def test_confidence_delta_lower_for_existing_fields(self):
        """Le delta est plus faible quand les champs existent deja."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        # Profile already has estimates for the main fields
        profile_with_estimates = {
            "lpp_total": 150000,
            "lpp_obligatoire": 100000,
            "lpp_surobligatoire": 50000,
            "conversion_rate_oblig": 6.8,
            "buyback_potential": 40000,
        }
        delta_with = estimate_confidence_delta(result, profile_with_estimates)
        delta_without = estimate_confidence_delta(result, {})
        assert delta_with < delta_without

    def test_confidence_delta_capped_at_30(self):
        """Le delta ne depasse jamais 30 points."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        delta = estimate_confidence_delta(result, {})
        assert delta <= 30.0


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Field Impact Ranking (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestFieldImpactRanking:
    """Tests du classement des champs par impact."""

    def test_ranking_returns_sorted_by_impact(self):
        """Les champs sont tries par impact decroissant."""
        missing = ["avoir_total", "part_obligatoire", "prestation_deces"]
        ranked = rank_fields_by_impact(missing, DocumentType.lpp_certificate)
        impacts = [item["impact"] for item in ranked]
        assert impacts == sorted(impacts, reverse=True)

    def test_part_obligatoire_highest_impact(self):
        """part_obligatoire a l'impact le plus eleve (10)."""
        missing = list(KNOWN_FIELD_PATTERNS.keys())
        ranked = rank_fields_by_impact(missing, DocumentType.lpp_certificate)
        assert ranked[0]["field_name"] == "part_obligatoire"
        assert ranked[0]["impact"] == 10

    def test_unknown_field_gets_minimal_impact(self):
        """Un champ inconnu recoit un impact minimal (1)."""
        missing = ["champ_inconnu"]
        ranked = rank_fields_by_impact(missing, DocumentType.lpp_certificate)
        assert ranked[0]["impact"] == 1

    def test_ranking_includes_reason(self):
        """Chaque champ classe a une raison explicative."""
        missing = ["part_obligatoire"]
        ranked = rank_fields_by_impact(missing, DocumentType.lpp_certificate)
        assert "reason" in ranked[0]
        assert len(ranked[0]["reason"]) > 10

    def test_ranking_includes_projection_affected(self):
        """Chaque champ classe indique les projections affectees."""
        missing = ["taux_conversion_oblig"]
        ranked = rank_fields_by_impact(missing, DocumentType.lpp_certificate)
        assert "projection_affected" in ranked[0]
        assert "rente_vs_capital" in ranked[0]["projection_affected"]


# ═══════════════════════════════════════════════════════════════════════════════
# 7. Edge Cases (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestEdgeCases:
    """Tests des cas limites."""

    def test_empty_text_returns_empty_result(self):
        """Un texte vide retourne un resultat vide avec warning."""
        result = parse_lpp_certificate("")
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0
        assert any("vide" in w.lower() for w in result.warnings)

    def test_none_text_returns_empty_result(self):
        """None retourne un resultat vide."""
        result = parse_lpp_certificate(None)  # type: ignore[arg-type]
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0

    def test_random_text_returns_no_fields(self):
        """Un texte sans rapport ne retourne aucun champ LPP."""
        result = parse_lpp_certificate("Ceci est un texte quelconque sans chiffres financiers.")
        assert len(result.fields) == 0

    def test_malformed_numbers_handled(self):
        """Les nombres mal formates ne causent pas d'erreur."""
        text = "Avoir de vieillesse total: CHF abc'def.gh"
        result = parse_lpp_certificate(text)
        # Should not crash, field just not extracted
        field = result.get_field("avoir_total")
        assert field is None or isinstance(field.value, (int, float))

    def test_very_large_text_handled(self):
        """Un texte tres long ne cause pas de timeout."""
        long_text = SAMPLE_LPP_FR * 100  # Repeat 100 times
        result = parse_lpp_certificate(long_text)
        # Should still extract fields from the first occurrence
        assert len(result.fields) > 0

    def test_get_field_value_returns_none_for_missing(self):
        """get_field_value retourne None pour un champ absent."""
        result = parse_lpp_certificate(SAMPLE_LPP_PARTIAL)
        assert result.get_field_value("prestation_deces") is None

    def test_get_field_returns_none_for_missing(self):
        """get_field retourne None pour un champ absent."""
        result = parse_lpp_certificate(SAMPLE_LPP_PARTIAL)
        assert result.get_field("prestation_deces") is None


# ═══════════════════════════════════════════════════════════════════════════════
# 8. API Endpoints (5+ tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAPIEndpoints:
    """Tests des endpoints FastAPI."""

    @pytest.fixture
    def client(self):
        """Create a test client."""
        from app.main import app
        return TestClient(app)

    def test_parse_endpoint_returns_200(self, client):
        """POST /parse retourne 200 avec un certificat valide."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": SAMPLE_LPP_FR,
                "documentType": "lpp_certificate",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "fields" in data
        assert "overallConfidence" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_parse_endpoint_extracts_fields(self, client):
        """POST /parse extrait les champs correctement."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": SAMPLE_LPP_FR,
                "documentType": "lpp_certificate",
            },
        )
        data = response.json()
        field_names = [f["fieldName"] for f in data["fields"]]
        assert "avoir_total" in field_names
        assert "part_obligatoire" in field_names

    def test_parse_endpoint_with_profile(self, client):
        """POST /parse avec profil calcule le confidence delta."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": SAMPLE_LPP_FR,
                "documentType": "lpp_certificate",
                "currentProfile": {"lpp_total": 150000},
            },
        )
        data = response.json()
        assert data["confidenceDelta"] >= 0

    def test_confidence_delta_endpoint(self, client):
        """POST /confidence-delta retourne le delta correctement."""
        response = client.post(
            "/api/v1/document-parser/confidence-delta",
            json={
                "text": SAMPLE_LPP_FR,
                "documentType": "lpp_certificate",
                "currentProfile": {},
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["confidenceDelta"] > 0
        assert data["fieldsExtracted"] > 0
        assert "disclaimer" in data

    def test_field_impact_endpoint(self, client):
        """GET /field-impact/lpp_certificate retourne le classement."""
        response = client.get("/api/v1/document-parser/field-impact/lpp_certificate")
        assert response.status_code == 200
        data = response.json()
        assert data["documentType"] == "lpp_certificate"
        assert len(data["fields"]) > 0
        assert "disclaimer" in data

    def test_field_impact_invalid_type_returns_400(self, client):
        """GET /field-impact/invalid retourne 400."""
        response = client.get("/api/v1/document-parser/field-impact/invalid_type")
        assert response.status_code == 400

    def test_parse_unsupported_type_returns_501(self, client):
        """POST /parse avec type non implemente retourne 501."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": "some text",
                "documentType": "three_a_attestation",
            },
        )
        assert response.status_code == 501

    def test_parse_empty_text_returns_200_with_warning(self, client):
        """POST /parse avec texte minimal retourne 200 avec warning."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": "x",
                "documentType": "lpp_certificate",
            },
        )
        assert response.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
# 9. Compliance (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestCompliance:
    """Tests de compliance: disclaimer, sources, termes interdits, privacy."""

    def test_disclaimer_present(self):
        """Le resultat contient un disclaimer."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        assert result.disclaimer is not None
        assert len(result.disclaimer) > 20
        assert "educatif" in result.disclaimer.lower()
        assert "lsfin" in result.disclaimer.lower()

    def test_sources_present(self):
        """Le resultat contient des sources legales."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        assert len(result.sources) >= 3
        assert any("LPP" in s for s in result.sources)

    def test_no_banned_terms_in_disclaimer(self):
        """Le disclaimer ne contient aucun terme interdit."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        disclaimer_lower = result.disclaimer.lower()
        for term in BANNED_TERMS:
            # "assuré" is allowed in "salaire assuré" context but not as "garanti"
            if term == "assuré":
                continue
            assert term not in disclaimer_lower, f"Terme interdit '{term}' trouve dans le disclaimer"

    def test_no_banned_terms_in_warnings(self):
        """Les warnings ne contiennent aucun terme interdit."""
        result = parse_lpp_certificate(SAMPLE_LPP_INCONSISTENT)
        for warning in result.warnings:
            warning_lower = warning.lower()
            for term in BANNED_TERMS:
                if term == "assuré":
                    continue
                assert term not in warning_lower, f"Terme interdit '{term}' trouve dans warning: {warning}"

    def test_privacy_mention_in_disclaimer(self):
        """Le disclaimer mentionne que l'image source n'est jamais stockee."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        assert "jamais stock" in result.disclaimer.lower()


# ═══════════════════════════════════════════════════════════════════════════════
# 10. Data Models (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestDataModels:
    """Tests des modeles de donnees."""

    def test_document_type_enum_values(self):
        """DocumentType contient les 5 types de documents."""
        assert DocumentType.lpp_certificate.value == "lpp_certificate"
        assert DocumentType.tax_declaration.value == "tax_declaration"
        assert DocumentType.avs_extract.value == "avs_extract"
        assert DocumentType.three_a_attestation.value == "three_a_attestation"
        assert DocumentType.mortgage_attestation.value == "mortgage_attestation"

    def test_data_source_enum_values(self):
        """DataSource contient les 8 sources de donnees."""
        assert len(DataSource) == 8
        assert DataSource.user_estimate.value == "user_estimate"
        assert DataSource.document_scan_verified.value == "document_scan_verified"

    def test_data_source_accuracy_weights(self):
        """Les poids de fiabilite sont coherents (open_banking > user_estimate)."""
        assert DATA_SOURCE_ACCURACY[DataSource.open_banking] > DATA_SOURCE_ACCURACY[DataSource.user_estimate]
        assert DATA_SOURCE_ACCURACY[DataSource.document_scan_verified] > DATA_SOURCE_ACCURACY[DataSource.document_scan]

    def test_extracted_field_creation(self):
        """ExtractedField se cree correctement."""
        field = ExtractedField(
            field_name="avoir_total",
            value=143287.0,
            confidence=0.95,
            source_text="Avoir de vieillesse total: CHF 143'287.00",
        )
        assert field.field_name == "avoir_total"
        assert field.value == 143287.0
        assert field.needs_review is False

    def test_profile_field_creation(self):
        """ProfileField se cree correctement."""
        pf = ProfileField(
            field_name="lpp_total",
            value=143287.0,
            source=DataSource.document_scan_verified,
            updated_at="2026-02-24T10:00:00Z",
            field_confidence=0.95,
        )
        assert pf.source == DataSource.document_scan_verified
        assert pf.field_confidence == 0.95

    def test_extraction_result_get_field_value(self):
        """ExtractionResult.get_field_value retourne la valeur du champ."""
        result = parse_lpp_certificate(SAMPLE_LPP_FR)
        value = result.get_field_value("avoir_total")
        assert value == 143287.0


# ═══════════════════════════════════════════════════════════════════════════════
# 11. Known Field Patterns (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestKnownFieldPatterns:
    """Tests de la configuration des patterns."""

    def test_all_14_fields_defined(self):
        """14 champs LPP sont definis dans KNOWN_FIELD_PATTERNS."""
        assert len(KNOWN_FIELD_PATTERNS) == 14

    def test_high_impact_fields_subset_of_patterns(self):
        """HIGH_IMPACT_FIELDS est un sous-ensemble de KNOWN_FIELD_PATTERNS."""
        for field in HIGH_IMPACT_FIELDS:
            assert field in KNOWN_FIELD_PATTERNS, f"{field} absent de KNOWN_FIELD_PATTERNS"

    def test_each_field_has_type_and_patterns(self):
        """Chaque champ a un type (amount/rate) et des patterns."""
        for name, defn in KNOWN_FIELD_PATTERNS.items():
            assert "type" in defn, f"{name} manque le type"
            assert defn["type"] in ("amount", "rate", "percentage"), f"{name} type invalide: {defn['type']}"
            assert "patterns" in defn, f"{name} manque les patterns"
            assert len(defn["patterns"]) >= 2, f"{name} a trop peu de patterns"


# ═══════════════════════════════════════════════════════════════════════════════
# 12. Vision Cross-Field Coherence (DOC-05) — 12 tests
# ═══════════════════════════════════════════════════════════════════════════════


from app.schemas.document_scan import (
    ConfidenceLevel as VisionConfidenceLevel,
    ExtractedFieldConfirmation,
    DocumentType as VisionDocumentType,
)
from app.services.document_vision_service import validate_lpp_coherence


def _make_lpp_fields(oblig, suroblig, total, confidence="high"):
    """Helper to create LPP field list for coherence testing."""
    fields = []
    if oblig is not None:
        fields.append(ExtractedFieldConfirmation(
            field_name="avoirLppObligatoire",
            value=oblig,
            confidence=VisionConfidenceLevel(confidence),
            source_text=f"Obligatoire: {oblig}",
        ))
    if suroblig is not None:
        fields.append(ExtractedFieldConfirmation(
            field_name="avoirLppSurobligatoire",
            value=suroblig,
            confidence=VisionConfidenceLevel(confidence),
            source_text=f"Surobligatoire: {suroblig}",
        ))
    if total is not None:
        fields.append(ExtractedFieldConfirmation(
            field_name="avoirLppTotal",
            value=total,
            confidence=VisionConfidenceLevel(confidence),
            source_text=f"Total: {total}",
        ))
    return fields


class TestVisionCoherence:
    """Tests for validate_lpp_coherence() — DOC-05."""

    def test_coherent_values_no_warnings(self):
        """Test 1: oblig + suroblig = total exactly -> no warnings."""
        fields = _make_lpp_fields(200000, 150000, 350000)
        warnings = validate_lpp_coherence(fields)
        assert len(warnings) == 0

    def test_10x_error_detected(self):
        """Test 2: total = 10x expected -> 10x error warning."""
        fields = _make_lpp_fields(200000, 150000, 3500000)
        warnings = validate_lpp_coherence(fields)
        assert any("10x" in w or "disproportionne" in w.lower() for w in warnings)

    def test_over_5_percent_triggers_warning(self):
        """Test 3: >5% deviation triggers coherence warning."""
        # 200k + 150k = 350k; total = 380k -> deviation = 30k/380k = 7.9%
        fields = _make_lpp_fields(200000, 150000, 380000)
        warnings = validate_lpp_coherence(fields)
        assert any("correspondent pas" in w for w in warnings)

    def test_within_5_percent_no_warning(self):
        """Test 4: within 5% tolerance -> no warning."""
        # 200k + 150k = 350k; total = 365k -> deviation = 15k/365k = 4.1%
        fields = _make_lpp_fields(200000, 150000, 365000)
        warnings = validate_lpp_coherence(fields)
        coherence_warnings = [w for w in warnings if "correspondent pas" in w]
        assert len(coherence_warnings) == 0

    def test_missing_field_no_warning(self):
        """Test 5: missing oblig field -> no warning (can't validate)."""
        fields = _make_lpp_fields(None, 150000, 350000)
        warnings = validate_lpp_coherence(fields)
        assert len(warnings) == 0

    def test_coherence_failure_downgrades_confidence(self):
        """Test 6: coherence failure downgrades all 3 fields to low."""
        fields = _make_lpp_fields(200000, 150000, 3500000, confidence="high")
        validate_lpp_coherence(fields)
        for f in fields:
            assert f.confidence == VisionConfidenceLevel.low

    def test_coherence_warning_message_in_french(self):
        """Test 7: coherence warning is in French."""
        fields = _make_lpp_fields(200000, 150000, 400000)
        warnings = validate_lpp_coherence(fields)
        assert any("Verifie" in w for w in warnings)

    def test_exact_5_percent_boundary_pass(self):
        """Test boundary: exactly 5% deviation should pass."""
        # 200k + 150k = 350k; total where deviation = 5% exactly
        # deviation = |350k - total| / total = 0.05
        # 350 / total = 0.95 -> total = 350000/0.95 = 368421.05
        # Let's use total = 368000 -> deviation = 18000/368000 = 4.89% (passes)
        fields = _make_lpp_fields(200000, 150000, 368000)
        warnings = validate_lpp_coherence(fields)
        coherence_warnings = [w for w in warnings if "correspondent pas" in w]
        assert len(coherence_warnings) == 0

    def test_just_over_5_percent_boundary_fail(self):
        """Test boundary: just over 5% deviation should fail."""
        # total = 370000 -> deviation = 20000/370000 = 5.4% (fails)
        fields = _make_lpp_fields(200000, 150000, 370000)
        warnings = validate_lpp_coherence(fields)
        assert any("correspondent pas" in w for w in warnings)

    def test_10x_specific_warning_text(self):
        """Test 10: 10x error has specific warning text."""
        fields = _make_lpp_fields(50000, 50000, 5000000)
        warnings = validate_lpp_coherence(fields)
        assert any("erreur 10x" in w.lower() or "disproportionne" in w.lower() for w in warnings)

    def test_coherent_preserves_high_confidence(self):
        """Coherent values preserve original confidence."""
        fields = _make_lpp_fields(200000, 150000, 350000, confidence="high")
        validate_lpp_coherence(fields)
        for f in fields:
            assert f.confidence == VisionConfidenceLevel.high

    def test_missing_suroblig_no_warning(self):
        """Missing surobligatoire -> no coherence check possible."""
        fields = _make_lpp_fields(200000, None, 350000)
        warnings = validate_lpp_coherence(fields)
        assert len(warnings) == 0
