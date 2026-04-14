"""Phase 28-01 / Task 4: third-party detection + signatures fixture tests."""
from __future__ import annotations

from app.schemas.document_understanding import (
    ConfidenceLevel,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    RenderMode,
)
from app.services.document_third_party import (
    detect_third_party,
    load_issuer_signatures,
)


def _result_with_source(source_text: str) -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=[
            ExtractedField(
                field_name="salaireAssure",
                value=91967.0,
                confidence=ConfidenceLevel.high,
                source_text=source_text,
            )
        ],
        overall_confidence=0.9,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
    )


def test_partner_name_recognised_as_self():
    r = _result_with_source("Titulaire: Lauren Battaglia, Salaire assuré: CHF 91'967")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", "Lauren")
    assert flagged is False
    assert name is None


def test_user_lastname_only_match_recognised():
    r = _result_with_source("Compte au nom de Julien Battaglia")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", None)
    assert flagged is False
    assert name is None


def test_stranger_name_flagged():
    r = _result_with_source("Titulaire du contrat: Marc Dupont, prime annuelle CHF 1'200")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", "Lauren")
    assert flagged is True
    assert name == "Marc Dupont"


def test_no_proper_noun_returns_false():
    r = _result_with_source("avoir total chf 70'377 bonification 24%")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", "Lauren")
    assert flagged is False
    assert name is None


def test_non_person_bigrams_filtered():
    r = _result_with_source("Caisse Pensions de l'État, Plan Maxi, Bonification Vieillesse")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", None)
    assert flagged is False
    assert name is None


def test_missing_partner_still_matches_self():
    r = _result_with_source("Compte de Julien Battaglia")
    flagged, name = detect_third_party(r, "Julien", "Battaglia", None)
    assert flagged is False


def test_diacritics_normalised():
    # "François" in source; user is "Francois" (no cedilla)
    r = _result_with_source("Titulaire: François Battaglia")
    flagged, name = detect_third_party(r, "Francois", "Battaglia", None)
    assert flagged is False


def test_signatures_yaml_loads():
    sigs = load_issuer_signatures()
    assert "issuers" in sigs
    issuers = sigs["issuers"]
    assert len(issuers) >= 5
    names = {i["name"] for i in issuers}
    assert {"CPE", "Swisscanto", "AVS IK", "Raiffeisen", "UBS"}.issubset(names)
    # Schema sanity
    for i in issuers:
        assert "keywords" in i and isinstance(i["keywords"], list)
        assert "document_classes" in i and isinstance(i["document_classes"], list)
