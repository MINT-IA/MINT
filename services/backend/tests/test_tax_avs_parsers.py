"""
Tests for Tax Declaration Parser (S44) and AVS Extract Parser (S45).

Test categories:
    1. Tax declaration parsing FR (8 tests)
    2. Tax declaration parsing DE (4 tests)
    3. Tax cross-validation (4 tests)
    4. AVS extract parsing FR (6 tests)
    5. AVS extract parsing DE (3 tests)
    6. AVS cross-validation (3 tests)
    7. Edge cases (5 tests)
    8. Confidence delta (3 tests)
    9. API endpoints (4 tests)
    10. Compliance (3 tests)

Total: 43 tests

Sources:
    - LIFD art. 25-33 (revenu imposable)
    - LIFD art. 38 (imposition du capital)
    - LIFD art. 33 al. 1 let. e (deduction 3a: 7'258 CHF)
    - LHID art. 7-9 (harmonisation fiscale cantonale)
    - LAVS art. 29bis-29quinquies (duree de cotisation)
    - LAVS art. 29quater-29sexies (calcul de la rente, RAMD)
    - LAVS art. 29sexies (bonifications pour taches educatives)
"""

import pytest
from fastapi.testclient import TestClient

from app.services.document_parser.document_models import (
    DocumentType,
)
from app.services.document_parser.tax_declaration_parser import (
    parse_tax_declaration,
    estimate_tax_confidence_delta,
    TAX_FIELD_PATTERNS,
    TAX_HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.avs_extract_parser import (
    parse_avs_extract,
    estimate_avs_confidence_delta,
    AVS_FIELD_PATTERNS,
    AVS_HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.extraction_confidence_scorer import (
    score_extraction,
    rank_fields_by_impact,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Test fixtures — sample OCR texts
# ═══════════════════════════════════════════════════════════════════════════════

SAMPLE_TAX_FR = """
Avis de taxation 2024 — Canton de Vaud
Revenu imposable: CHF 95'400
Fortune imposable: CHF 180'000
Déductions admises: CHF 12'516 (dont 3a: CHF 7'056)
Impôt cantonal et communal: CHF 14'280
Impôt fédéral direct: CHF 3'850
Taux marginal estimé: 28.5%
"""

SAMPLE_TAX_FR_GENEVE = """
Avis de taxation 2024 — Canton de Genève
Revenu net imposable: CHF 120'000
Fortune nette imposable: CHF 350'000
Total des déductions: CHF 18'200
Impôts cantonal et communal: CHF 22'500
Impôt fédéral direct: CHF 5'100
Taux marginal effectif: 32.5%
"""

SAMPLE_TAX_DE = """
Steuerveranlagung 2024 — Kanton Zürich
Steuerbares Einkommen: CHF 105'000
Steuerbares Vermögen: CHF 220'000
Totale Abzüge: CHF 15'000
Kantons- und Gemeindesteuer: CHF 16'200
Direkte Bundessteuer: CHF 4'350
Grenzsteuersatz: 30.2%
"""

SAMPLE_TAX_DE_BERN = """
Steuerveranlagung 2024 — Kanton Bern
Steuerbares Einkommen: CHF 88'000
Steuerbares Vermögen: CHF 150'000
Zulässige Abzüge: CHF 11'000
Kantonssteuer: CHF 12'800
Bundessteuer: CHF 3'200
Marginaler Steuersatz: 26.0%
"""

SAMPLE_TAX_INCONSISTENT = """
Avis de taxation 2024
Revenu imposable: CHF 50'000
Impôt cantonal et communal: CHF 40'000
Impôt fédéral direct: CHF 15'000
"""

SAMPLE_TAX_HIGH_MARGINAL = """
Avis de taxation 2024
Revenu imposable: CHF 100'000
Taux marginal estimé: 65.0%
"""

SAMPLE_TAX_LOW_INCOME = """
Avis de taxation 2024
Revenu imposable: CHF 500
"""

SAMPLE_TAX_PARTIAL = """
Avis de taxation 2024
Revenu imposable: CHF 80'000
Fortune imposable: CHF 50'000
"""

SAMPLE_AVS_FR = """
Extrait de compte individuel (CI)
Années de cotisation: 15
Revenu annuel moyen déterminant (RAMD): CHF 72'500
Lacunes de cotisation: 2 années
Bonifications pour tâches éducatives: 3 années
"""

SAMPLE_AVS_FR_LONG = """
Extrait de compte individuel CI — demandé le 15.02.2026
Durée de cotisation: 28 années
Revenu annuel moyen déterminant: CHF 85'000
Lacunes de cotisation: 0 années
Bonifications éducatives: 5 années
"""

SAMPLE_AVS_DE = """
Individuelles Konto (IK) — Auszug
Beitragsjahre: 22
Durchschnittliches Jahreseinkommen: CHF 78'000
Beitragslücken: 1 Jahre
Erziehungsgutschriften: 4 Jahre
"""

SAMPLE_AVS_INCONSISTENT = """
Extrait de compte individuel
Années de cotisation: 40
Lacunes de cotisation: 10 années
"""

SAMPLE_AVS_LOW_RAMD = """
Extrait de compte individuel
Revenu annuel moyen déterminant: CHF 10'000
"""

SAMPLE_AVS_HIGH_RAMD = """
Extrait de compte individuel
Revenu annuel moyen déterminant (RAMD): CHF 250'000
"""

SAMPLE_AVS_PARTIAL = """
Extrait de compte individuel
Années de cotisation: 20
Revenu annuel moyen déterminant (RAMD): CHF 65'000
"""

SAMPLE_AVS_HIGH_BONIF = """
Extrait de compte individuel
Bonifications pour tâches éducatives: 20 années
"""


# ═══════════════════════════════════════════════════════════════════════════════
# Banned terms — NEVER appear in any user-facing text
# ═══════════════════════════════════════════════════════════════════════════════

BANNED_TERMS = [
    "garanti",
    "certain",
    "sans risque",
    "optimal",
    "meilleur",
    "parfait",
    "conseiller",
]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Tax Declaration Parsing — French (8 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestTaxDeclarationParsingFR:
    """Tests d'extraction de declarations fiscales en francais."""

    def test_parse_full_declaration_extracts_all_fields(self):
        """Une declaration complete doit extraire 6 champs."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        assert len(result.fields) == 6
        assert result.document_type == DocumentType.tax_declaration

    def test_parse_revenu_imposable(self):
        """Extrait le revenu imposable."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("revenu_imposable")
        assert field is not None
        assert field.value == 95400.0

    def test_parse_fortune_imposable(self):
        """Extrait la fortune imposable."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("fortune_imposable")
        assert field is not None
        assert field.value == 180000.0

    def test_parse_deductions(self):
        """Extrait les deductions admises."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("deductions_effectuees")
        assert field is not None
        assert field.value == 12516.0

    def test_parse_impot_cantonal(self):
        """Extrait l'impot cantonal et communal."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("impot_cantonal")
        assert field is not None
        assert field.value == 14280.0

    def test_parse_impot_federal(self):
        """Extrait l'impot federal direct."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("impot_federal")
        assert field is not None
        assert field.value == 3850.0

    def test_parse_taux_marginal(self):
        """Extrait le taux marginal effectif."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        field = result.get_field("taux_marginal_effectif")
        assert field is not None
        assert field.value == 28.5

    def test_parse_geneve_format(self):
        """Extrait les champs d'un avis de taxation genevois."""
        result = parse_tax_declaration(SAMPLE_TAX_FR_GENEVE)
        assert len(result.fields) >= 5
        revenu = result.get_field("revenu_imposable")
        assert revenu is not None
        assert revenu.value == 120000.0
        taux = result.get_field("taux_marginal_effectif")
        assert taux is not None
        assert taux.value == 32.5


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Tax Declaration Parsing — German (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestTaxDeclarationParsingDE:
    """Tests d'extraction de declarations fiscales en allemand."""

    def test_parse_german_declaration_extracts_fields(self):
        """Une declaration allemande doit extraire des champs."""
        result = parse_tax_declaration(SAMPLE_TAX_DE)
        assert len(result.fields) >= 5

    def test_parse_german_steuerbares_einkommen(self):
        """Extrait le steuerbares Einkommen."""
        result = parse_tax_declaration(SAMPLE_TAX_DE)
        field = result.get_field("revenu_imposable")
        assert field is not None
        assert field.value == 105000.0

    def test_parse_german_steuerbares_vermogen(self):
        """Extrait le steuerbares Vermogen."""
        result = parse_tax_declaration(SAMPLE_TAX_DE)
        field = result.get_field("fortune_imposable")
        assert field is not None
        assert field.value == 220000.0

    def test_parse_german_bern_format(self):
        """Extrait les champs d'une taxation bernoise."""
        result = parse_tax_declaration(SAMPLE_TAX_DE_BERN)
        assert len(result.fields) >= 4
        revenu = result.get_field("revenu_imposable")
        assert revenu is not None
        assert revenu.value == 88000.0


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Tax Cross-Validation (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestTaxCrossValidation:
    """Tests de cross-validation des valeurs fiscales."""

    def test_consistent_taxes_no_incoherence_warning(self):
        """Pas de warning d'incoherence quand les impots sont plausibles."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        incoherence_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(incoherence_warnings) == 0

    def test_inconsistent_taxes_triggers_warning(self):
        """Warning quand les impots sont incoherents par rapport au revenu."""
        result = parse_tax_declaration(SAMPLE_TAX_INCONSISTENT)
        # 40000 + 15000 = 55000 on a 50000 income = 110% effective rate
        incoherence_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(incoherence_warnings) >= 1

    def test_consistent_taxes_boosts_confidence(self):
        """La confiance augmente quand les valeurs sont coherentes."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        revenu = result.get_field("revenu_imposable")
        assert revenu is not None
        # Cross-validation boosted confidence
        assert revenu.confidence >= 0.7

    def test_high_marginal_rate_triggers_warning(self):
        """Warning quand le taux marginal est anormalement eleve."""
        result = parse_tax_declaration(SAMPLE_TAX_HIGH_MARGINAL)
        rate_warnings = [w for w in result.warnings if "taux marginal" in w.lower()]
        assert len(rate_warnings) >= 1


# ═══════════════════════════════════════════════════════════════════════════════
# 4. AVS Extract Parsing — French (6 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAvsExtractParsingFR:
    """Tests d'extraction d'extraits AVS en francais."""

    def test_parse_full_extract_extracts_all_fields(self):
        """Un extrait complet doit extraire 4 champs."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        assert len(result.fields) == 4
        assert result.document_type == DocumentType.avs_extract

    def test_parse_annees_cotisation(self):
        """Extrait les annees de cotisation."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        field = result.get_field("annees_cotisation")
        assert field is not None
        assert field.value == 15.0

    def test_parse_ramd(self):
        """Extrait le RAMD."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        field = result.get_field("ramd")
        assert field is not None
        assert field.value == 72500.0

    def test_parse_lacunes(self):
        """Extrait les lacunes de cotisation."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        field = result.get_field("lacunes_cotisation")
        assert field is not None
        assert field.value == 2.0

    def test_parse_bonifications(self):
        """Extrait les bonifications educatives."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        field = result.get_field("bonifications_educatives")
        assert field is not None
        assert field.value == 3.0

    def test_parse_long_career_extract(self):
        """Extrait les champs d'un extrait avec longue carriere."""
        result = parse_avs_extract(SAMPLE_AVS_FR_LONG)
        assert len(result.fields) >= 3
        annees = result.get_field("annees_cotisation")
        assert annees is not None
        assert annees.value == 28.0
        ramd = result.get_field("ramd")
        assert ramd is not None
        assert ramd.value == 85000.0


# ═══════════════════════════════════════════════════════════════════════════════
# 5. AVS Extract Parsing — German (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAvsExtractParsingDE:
    """Tests d'extraction d'extraits AVS en allemand."""

    def test_parse_german_extract_extracts_fields(self):
        """Un extrait allemand doit extraire des champs."""
        result = parse_avs_extract(SAMPLE_AVS_DE)
        assert len(result.fields) >= 3

    def test_parse_german_beitragsjahre(self):
        """Extrait les Beitragsjahre."""
        result = parse_avs_extract(SAMPLE_AVS_DE)
        field = result.get_field("annees_cotisation")
        assert field is not None
        assert field.value == 22.0

    def test_parse_german_jahreseinkommen(self):
        """Extrait le durchschnittliches Jahreseinkommen."""
        result = parse_avs_extract(SAMPLE_AVS_DE)
        field = result.get_field("ramd")
        assert field is not None
        assert field.value == 78000.0


# ═══════════════════════════════════════════════════════════════════════════════
# 6. AVS Cross-Validation (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAvsCrossValidation:
    """Tests de cross-validation des valeurs AVS."""

    def test_consistent_years_no_warning(self):
        """Pas de warning quand annees + lacunes <= 44."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        # 15 + 2 = 17 <= 44
        incoherence_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(incoherence_warnings) == 0

    def test_inconsistent_years_triggers_warning(self):
        """Warning quand annees + lacunes > 44."""
        result = parse_avs_extract(SAMPLE_AVS_INCONSISTENT)
        # 40 + 10 = 50 > 44
        incoherence_warnings = [w for w in result.warnings if "incoherence" in w.lower()]
        assert len(incoherence_warnings) >= 1

    def test_low_ramd_triggers_warning(self):
        """Warning quand le RAMD est inferieur au minimum AVS."""
        result = parse_avs_extract(SAMPLE_AVS_LOW_RAMD)
        ramd_warnings = [w for w in result.warnings if "RAMD" in w or "minimum" in w.lower()]
        assert len(ramd_warnings) >= 1


# ═══════════════════════════════════════════════════════════════════════════════
# 7. Edge Cases (5 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestEdgeCases:
    """Tests des cas limites pour les deux parsers."""

    def test_tax_empty_text_returns_empty_result(self):
        """Un texte vide retourne un resultat vide avec warning."""
        result = parse_tax_declaration("")
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0
        assert any("vide" in w.lower() for w in result.warnings)

    def test_avs_empty_text_returns_empty_result(self):
        """Un texte vide retourne un resultat vide avec warning."""
        result = parse_avs_extract("")
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0
        assert any("vide" in w.lower() for w in result.warnings)

    def test_tax_none_text_returns_empty_result(self):
        """None retourne un resultat vide."""
        result = parse_tax_declaration(None)  # type: ignore[arg-type]
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0

    def test_avs_none_text_returns_empty_result(self):
        """None retourne un resultat vide."""
        result = parse_avs_extract(None)  # type: ignore[arg-type]
        assert len(result.fields) == 0
        assert result.overall_confidence == 0.0

    def test_random_text_returns_no_fields(self):
        """Un texte sans rapport ne retourne aucun champ."""
        result = parse_tax_declaration("Ceci est un texte quelconque sans chiffres financiers.")
        assert len(result.fields) == 0
        result2 = parse_avs_extract("Ceci est un texte quelconque sans chiffres financiers.")
        assert len(result2.fields) == 0

    def test_tax_partial_extraction_has_lower_confidence(self):
        """Une extraction partielle a une confiance plus basse qu'une complete."""
        full = parse_tax_declaration(SAMPLE_TAX_FR)
        partial = parse_tax_declaration(SAMPLE_TAX_PARTIAL)
        assert partial.overall_confidence < full.overall_confidence

    def test_avs_high_bonifications_warning(self):
        """Warning quand les bonifications educatives sont trop elevees."""
        result = parse_avs_extract(SAMPLE_AVS_HIGH_BONIF)
        bonif_warnings = [w for w in result.warnings if "bonification" in w.lower()]
        assert len(bonif_warnings) >= 1


# ═══════════════════════════════════════════════════════════════════════════════
# 8. Confidence Delta (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestConfidenceDelta:
    """Tests du delta de confiance pour les nouveaux parsers."""

    def test_tax_delta_positive_for_new_fields(self):
        """Le delta de confiance fiscale doit etre positif pour des champs nouveaux."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        delta = estimate_tax_confidence_delta(result, {})
        assert delta > 0.0

    def test_tax_delta_lower_for_existing_fields(self):
        """Le delta est plus faible quand les champs existent deja."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        profile_with = {
            "actual_taxable_income": 95000,
            "actual_marginal_rate": 28.0,
            "actual_cantonal_tax": 14000,
        }
        delta_with = estimate_tax_confidence_delta(result, profile_with)
        delta_without = estimate_tax_confidence_delta(result, {})
        assert delta_with < delta_without

    def test_tax_delta_capped_at_20(self):
        """Le delta fiscal ne depasse jamais 20 points."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        delta = estimate_tax_confidence_delta(result, {})
        assert delta <= 20.0

    def test_avs_delta_positive_for_new_fields(self):
        """Le delta de confiance AVS doit etre positif pour des champs nouveaux."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        delta = estimate_avs_confidence_delta(result, {})
        assert delta > 0.0

    def test_avs_delta_capped_at_25(self):
        """Le delta AVS ne depasse jamais 25 points."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        delta = estimate_avs_confidence_delta(result, {})
        assert delta <= 25.0


# ═══════════════════════════════════════════════════════════════════════════════
# 9. API Endpoints (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestAPIEndpoints:
    """Tests des endpoints FastAPI pour les nouveaux types de documents."""

    @pytest.fixture
    def client(self):
        """Create a test client."""
        from app.main import app
        return TestClient(app)

    def test_parse_tax_declaration_returns_200(self, client):
        """POST /parse avec tax_declaration retourne 200."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": SAMPLE_TAX_FR,
                "documentType": "tax_declaration",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "fields" in data
        assert "overallConfidence" in data
        assert "disclaimer" in data
        assert "sources" in data
        # Check that sources are tax-specific
        sources_text = " ".join(data["sources"])
        assert "LIFD" in sources_text

    def test_parse_avs_extract_returns_200(self, client):
        """POST /parse avec avs_extract retourne 200."""
        response = client.post(
            "/api/v1/document-parser/parse",
            json={
                "text": SAMPLE_AVS_FR,
                "documentType": "avs_extract",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "fields" in data
        assert "overallConfidence" in data
        assert "disclaimer" in data
        assert "sources" in data
        # Check that sources are AVS-specific
        sources_text = " ".join(data["sources"])
        assert "LAVS" in sources_text

    def test_tax_confidence_delta_endpoint(self, client):
        """POST /confidence-delta pour tax_declaration retourne le delta."""
        response = client.post(
            "/api/v1/document-parser/confidence-delta",
            json={
                "text": SAMPLE_TAX_FR,
                "documentType": "tax_declaration",
                "currentProfile": {},
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["confidenceDelta"] > 0
        assert data["fieldsExtracted"] > 0
        assert "disclaimer" in data

    def test_avs_confidence_delta_endpoint(self, client):
        """POST /confidence-delta pour avs_extract retourne le delta."""
        response = client.post(
            "/api/v1/document-parser/confidence-delta",
            json={
                "text": SAMPLE_AVS_FR,
                "documentType": "avs_extract",
                "currentProfile": {},
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["confidenceDelta"] > 0
        assert data["fieldsExtracted"] > 0
        assert "disclaimer" in data


# ═══════════════════════════════════════════════════════════════════════════════
# 10. Compliance (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestCompliance:
    """Tests de compliance: disclaimer, sources, termes interdits, privacy."""

    def test_tax_disclaimer_and_sources(self):
        """Le resultat fiscal contient disclaimer et sources legales."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        assert result.disclaimer is not None
        assert len(result.disclaimer) > 20
        assert "educatif" in result.disclaimer.lower()
        assert "lsfin" in result.disclaimer.lower()
        assert "jamais stock" in result.disclaimer.lower()
        assert len(result.sources) >= 3
        assert any("LIFD" in s for s in result.sources)

    def test_avs_disclaimer_and_sources(self):
        """Le resultat AVS contient disclaimer et sources legales."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        assert result.disclaimer is not None
        assert len(result.disclaimer) > 20
        assert "educatif" in result.disclaimer.lower()
        assert "lsfin" in result.disclaimer.lower()
        assert "jamais stock" in result.disclaimer.lower()
        assert len(result.sources) >= 3
        assert any("LAVS" in s for s in result.sources)

    def test_no_banned_terms_in_tax_disclaimer(self):
        """Le disclaimer fiscal ne contient aucun terme interdit."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        disclaimer_lower = result.disclaimer.lower()
        for term in BANNED_TERMS:
            assert term not in disclaimer_lower, f"Terme interdit '{term}' trouve dans le disclaimer"

    def test_no_banned_terms_in_avs_disclaimer(self):
        """Le disclaimer AVS ne contient aucun terme interdit."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        disclaimer_lower = result.disclaimer.lower()
        for term in BANNED_TERMS:
            assert term not in disclaimer_lower, f"Terme interdit '{term}' trouve dans le disclaimer"

    def test_no_banned_terms_in_tax_warnings(self):
        """Les warnings fiscaux ne contiennent aucun terme interdit."""
        result = parse_tax_declaration(SAMPLE_TAX_INCONSISTENT)
        for warning in result.warnings:
            warning_lower = warning.lower()
            for term in BANNED_TERMS:
                assert term not in warning_lower, f"Terme interdit '{term}' dans: {warning}"


# ═══════════════════════════════════════════════════════════════════════════════
# 11. Extraction Confidence Scorer integration (3 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestExtractionScorerIntegration:
    """Tests de l'integration avec le scorer de confiance."""

    def test_tax_extraction_has_positive_score(self):
        """Un score d'extraction fiscal positif pour une declaration complete."""
        result = parse_tax_declaration(SAMPLE_TAX_FR)
        score = score_extraction(result)
        assert score > 30.0

    def test_avs_extraction_has_positive_score(self):
        """Un score d'extraction AVS positif pour un extrait complet."""
        result = parse_avs_extract(SAMPLE_AVS_FR)
        score = score_extraction(result)
        assert score > 30.0

    def test_tax_field_impact_ranking(self):
        """Les champs fiscaux sont correctement classes par impact."""
        missing = ["revenu_imposable", "taux_marginal_effectif", "impot_federal"]
        ranked = rank_fields_by_impact(missing, DocumentType.tax_declaration)
        impacts = [item["impact"] for item in ranked]
        assert impacts == sorted(impacts, reverse=True)
        # revenu_imposable and taux_marginal should be highest
        assert ranked[0]["impact"] == 10

    def test_avs_field_impact_ranking(self):
        """Les champs AVS sont correctement classes par impact."""
        missing = ["annees_cotisation", "ramd", "bonifications_educatives"]
        ranked = rank_fields_by_impact(missing, DocumentType.avs_extract)
        impacts = [item["impact"] for item in ranked]
        assert impacts == sorted(impacts, reverse=True)
        # annees_cotisation and ramd should be highest
        assert ranked[0]["impact"] == 10


# ═══════════════════════════════════════════════════════════════════════════════
# 12. Field Patterns Configuration (2 tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestFieldPatterns:
    """Tests de la configuration des patterns."""

    def test_tax_all_6_fields_defined(self):
        """6 champs fiscaux sont definis dans TAX_FIELD_PATTERNS."""
        assert len(TAX_FIELD_PATTERNS) == 6

    def test_avs_all_4_fields_defined(self):
        """4 champs AVS sont definis dans AVS_FIELD_PATTERNS."""
        assert len(AVS_FIELD_PATTERNS) == 4

    def test_tax_high_impact_fields_subset(self):
        """TAX_HIGH_IMPACT_FIELDS est un sous-ensemble de TAX_FIELD_PATTERNS."""
        for field in TAX_HIGH_IMPACT_FIELDS:
            assert field in TAX_FIELD_PATTERNS, f"{field} absent de TAX_FIELD_PATTERNS"

    def test_avs_high_impact_fields_subset(self):
        """AVS_HIGH_IMPACT_FIELDS est un sous-ensemble de AVS_FIELD_PATTERNS."""
        for field in AVS_HIGH_IMPACT_FIELDS:
            assert field in AVS_FIELD_PATTERNS, f"{field} absent de AVS_FIELD_PATTERNS"


# ── Regression tests added 2026-04-25 (extraction uplift) ───────────


class TestTaxLifdLawCitationDoesNotPickAmount:
    """Regression: `(LIFD art. 33): 7'258 CHF` line was matching the
    `ifd` pattern of impot_federal and stealing the 3a deduction
    amount as if it was a federal tax. Fixed by negative lookbehind
    on `[A-Za-z]ifd` and negative lookahead on `ifd\\s*art`."""

    def test_lifd_article_citation_does_not_match_impot_federal(self):
        """3a deduction line MUST NOT be matched as impot_federal."""
        text = (
            "Revenu brut: 122'207 CHF\n"
            "Deductions:\n"
            "3e pilier A (LIFD art. 33): 7'258 CHF\n"
            "Revenu imposable: 112'400 CHF\n"
        )
        result = parse_tax_declaration(text)
        federal = next(
            (f for f in result.fields if f.field_name == "impot_federal"),
            None,
        )
        assert federal is None, (
            "Regression: LIFD law citation matched as impot_federal "
            f"(value: {federal.value if federal else None})"
        )

    def test_explicit_impot_federal_still_matches(self):
        """Real impot_federal label MUST still extract the amount."""
        text = (
            "Recapitulatif:\n"
            "Impot federal direct: 8'200 CHF\n"
            "Impot cantonal: 12'500 CHF\n"
        )
        result = parse_tax_declaration(text)
        federal = next(
            (f for f in result.fields if f.field_name == "impot_federal"),
            None,
        )
        assert federal is not None
        assert federal.value == 8200.0

    def test_dbst_law_citation_does_not_match_german(self):
        """Same fix for German DBST law citation."""
        text = (
            "Saulen 3a (DBSt art. 81): 7'056 CHF\n"
            "Steuerbares Einkommen: 95'000 CHF\n"
        )
        result = parse_tax_declaration(text)
        federal = next(
            (f for f in result.fields if f.field_name == "impot_federal"),
            None,
        )
        assert federal is None


class TestAvsIkTableHeuristic:
    """Regression: AVS IK extracts printed as YEAR/EMPLOYER/INCOME tables
    were extracting 0 fields because no `années de cotisation` /
    `RAMD` literal label was present. Fallback heuristic now derives
    both from row count + mean income."""

    def test_table_with_10_years_extracts_annees_and_ramd(self):
        text = (
            "Extrait du compte individuel AVS\n"
            "Annee | Employeur | Revenu cotisant (CHF)\n"
            "2016 | Employeur Test 1 | 95000\n"
            "2017 | Employeur Test 2 | 97500\n"
            "2018 | Employeur Test 3 | 100000\n"
            "2019 | Employeur Test 4 | 103500\n"
            "2020 | Employeur Test 5 | 108000\n"
            "2021 | Employeur Test 6 | 111000\n"
            "2022 | Employeur Test 7 | 114500\n"
            "2023 | Employeur Test 8 | 117000\n"
            "2024 | Employeur Test 9 | 119500\n"
            "2025 | Employeur Test 10 | 122207\n"
        )
        result = parse_avs_extract(text)
        annees = next(
            (f for f in result.fields if f.field_name == "annees_cotisation"),
            None,
        )
        ramd = next(
            (f for f in result.fields if f.field_name == "ramd"), None
        )
        assert annees is not None and annees.value == 10.0, (
            f"annees_cotisation mismatch: {annees.value if annees else None}"
        )
        assert ramd is not None
        # Mean of (95000 + 97500 + 100000 + 103500 + 108000 + 111000 +
        #          114500 + 117000 + 119500 + 122207) / 10 = 108_820.70
        assert abs(ramd.value - 108_820.70) < 1.0
        assert ramd.needs_review is True  # Heuristic, not official

    def test_table_with_only_2_rows_does_not_trigger(self):
        """Below the 3-row floor: no table extraction."""
        text = (
            "Annee | Employeur | Revenu\n"
            "2024 | Test | 100000\n"
            "2025 | Test | 105000\n"
        )
        result = parse_avs_extract(text)
        # Neither annees nor ramd should be set from the table.
        annees = next(
            (f for f in result.fields if f.field_name == "annees_cotisation"),
            None,
        )
        ramd = next(
            (f for f in result.fields if f.field_name == "ramd"), None
        )
        assert annees is None and ramd is None

    def test_employer_index_digits_ignored_for_income(self):
        """`Employeur 5` digit 5 must NOT be picked as income."""
        text = (
            "Annee | Employeur | Revenu\n"
            "2023 | Employeur 5 | 117000\n"
            "2024 | Employeur 9 | 119500\n"
            "2025 | Employeur 10 | 122000\n"
        )
        result = parse_avs_extract(text)
        ramd = next(
            (f for f in result.fields if f.field_name == "ramd"), None
        )
        assert ramd is not None
        assert ramd.value > 100_000

    def test_explicit_label_takes_precedence_over_table(self):
        """If both an explicit RAMD label AND a table are present, the
        explicit label must win (already in extracted_fields before
        the table fallback runs)."""
        text = (
            "Annees de cotisation: 25\n"
            "Revenu annuel moyen determinant (RAMD): 95'000 CHF\n"
            "Annee | Employeur | Revenu\n"
            "2023 | A | 80000\n"
            "2024 | B | 82000\n"
            "2025 | C | 84000\n"
        )
        result = parse_avs_extract(text)
        annees = next(
            (f for f in result.fields if f.field_name == "annees_cotisation"),
            None,
        )
        ramd = next(
            (f for f in result.fields if f.field_name == "ramd"), None
        )
        assert annees is not None and annees.value == 25.0
        assert ramd is not None and ramd.value == 95000.0
