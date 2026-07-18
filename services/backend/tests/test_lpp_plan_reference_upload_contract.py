"""RED contract for the LPP regulation-reference upload boundary.

All examples are synthetic. A fund plan/regulation is document authority only:
it must never be interpreted as evidence about one insured person's LPP facts.
"""

from types import SimpleNamespace

import pytest

from app.api.v1.endpoints.documents import _detect_document_type


_SYNTHETIC_PLAN_TEXTS = {
    "fr": """
        RÈGLEMENT DE PRÉVOYANCE PROFESSIONNELLE
        Dispositions générales du plan de prévoyance de la caisse de pension.
        Le présent règlement décrit les prestations, les barèmes de cotisations
        et les taux de conversion applicables. Il ne constitue pas un certificat
        individuel et n'atteste aucune donnée personnelle.
    """,
    "de": """
        VORSORGEREGLEMENT DER PENSIONSKASSE
        Dieser Vorsorgeplan beschreibt die Leistungen, Beitragsstaffeln und
        Umwandlungssätze. Dieses Reglement ist kein persönlicher Vorsorgeausweis
        und bestätigt keine individuellen Versicherungsdaten.
    """,
    "it": """
        REGOLAMENTO DI PREVIDENZA PROFESSIONALE
        Il piano di previdenza della cassa pensione descrive le prestazioni,
        le aliquote contributive e i tassi di conversione. Non è un certificato
        personale e non attesta dati assicurativi individuali.
    """,
}


_SYNTHETIC_PERSONAL_CERTIFICATE_TEXTS = {
    "fr": """
        CERTIFICAT INDIVIDUEL DE PRÉVOYANCE PROFESSIONNELLE
        Personne assurée : PERSONNE SYNTHÉTIQUE
        Salaire assuré : CHF 81'000.00
        Avoir de vieillesse : CHF 123'000.00
        Ce certificat est établi selon le règlement du plan de prévoyance.
    """,
    "de": """
        PERSÖNLICHER VORSORGEAUSWEIS DER PENSIONSKASSE
        Versicherte Person: SYNTHETISCHE PERSON
        Versicherter Lohn: CHF 81'000.00
        Altersguthaben: CHF 123'000.00
        Dieser Ausweis verweist auf das Vorsorgereglement und den Vorsorgeplan.
    """,
    "it": """
        CERTIFICATO PERSONALE DI PREVIDENZA PROFESSIONALE
        Persona assicurata: PERSONA SINTETICA
        Salario assicurato: CHF 81'000.00
        Avere di vecchiaia: CHF 123'000.00
        Il certificato rinvia al regolamento e al piano di previdenza.
    """,
}


@pytest.mark.parametrize(
    "language, text",
    _SYNTHETIC_PLAN_TEXTS.items(),
    ids=_SYNTHETIC_PLAN_TEXTS.keys(),
)
def test_explicit_lpp_plan_or_regulation_is_classified_as_plan(language, text):
    assert _detect_document_type(text) == "lpp_plan", language


@pytest.mark.parametrize(
    "language, text",
    _SYNTHETIC_PERSONAL_CERTIFICATE_TEXTS.items(),
    ids=_SYNTHETIC_PERSONAL_CERTIFICATE_TEXTS.keys(),
)
def test_explicit_personal_certificate_wins_over_plan_reference(language, text):
    assert _detect_document_type(text) == "lpp_certificate", language


@pytest.mark.parametrize(
    "text",
    [
        "Liste de courses synthétique sans contenu financier.",
        (
            "Documentation générale LPP / BVG. Le plan et le certificat "
            "seront transmis séparément; aucun document n'est joint."
        ),
    ],
    ids=["unknown", "ambiguous-lpp-mention"],
)
def test_unknown_or_ambiguous_text_is_not_promoted_to_lpp_authority(text):
    assert _detect_document_type(text) == "unknown"


class _EmptyExtraction:
    confidence = 0.0
    extracted_fields_count = 0
    total_fields_count = 0

    @staticmethod
    def to_dict():
        return {
            "confidence": 0.0,
            "extracted_fields_count": 0,
            "total_fields_count": 0,
        }


class _LppExtractorSpy:
    constructor_calls = 0
    extract_calls = 0

    def __init__(self):
        type(self).constructor_calls += 1

    def extract(self, text, tables=None):
        type(self).extract_calls += 1
        return _EmptyExtraction()


def _install_synthetic_plan_parser(monkeypatch):
    from app.services.docling import parser as parser_module
    from app.services.docling.extractors import lpp_certificate as lpp_module

    class _SyntheticPlanParser:
        @staticmethod
        def parse_pdf(file_bytes):
            assert file_bytes.startswith(b"%PDF-")
            return SimpleNamespace(
                full_text=_SYNTHETIC_PLAN_TEXTS["fr"],
                pages=[],
            )

    _LppExtractorSpy.constructor_calls = 0
    _LppExtractorSpy.extract_calls = 0
    monkeypatch.setattr(parser_module, "DocumentParser", _SyntheticPlanParser)
    monkeypatch.setattr(lpp_module, "LPPCertificateExtractor", _LppExtractorSpy)


def _upload_synthetic_plan(client, marker):
    return client.post(
        "/api/v1/documents/upload",
        files={
            "file": (
                "synthetic-plan.pdf",
                f"%PDF-1.4\nsynthetic-plan-{marker}".encode(),
                "application/pdf",
            )
        },
    )


def test_lpp_plan_upload_returns_only_document_authority(client, monkeypatch):
    _install_synthetic_plan_parser(monkeypatch)

    response = _upload_synthetic_plan(client, "authority")

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["document_type"] == "lpp_plan"
    assert payload["extracted_fields"] == {}
    assert payload["fields_found"] == 0
    assert payload["fields_total"] == 0
    assert payload["warnings"] == [
        "LPP plan or regulation detected. Its general terms were not treated "
        "as personal pension facts."
    ]
    assert payload["rag_indexed"] is False


def test_lpp_plan_upload_never_calls_personal_certificate_extractor(
    client,
    monkeypatch,
):
    _install_synthetic_plan_parser(monkeypatch)

    response = _upload_synthetic_plan(client, "no-personal-extraction")

    assert response.status_code == 200, response.text
    assert _LppExtractorSpy.constructor_calls == 0
    assert _LppExtractorSpy.extract_calls == 0
