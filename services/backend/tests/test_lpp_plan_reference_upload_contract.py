"""RED contract for the LPP regulation-reference upload boundary.

All examples are synthetic. A fund plan/regulation is document authority only:
it must never be interpreted as evidence about one insured person's LPP facts.
"""

from types import SimpleNamespace

import pytest

from app.api.v1.endpoints.documents import _detect_document_type
from app.models.document import DocumentModel
from app.schemas.document import DocumentUploadResponse
from tests.conftest import TestingSessionLocal


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


_NOISY_PERSONAL_CERTIFICATE_TEXTS = {
    "fr": """
        *** DUPLICATA — CERTIFICAT INDIVIDUEL DE PRÉVOYANCE ***
        Personne assurée : PERSONNE SYNTHÉTIQUE
        Salaire assuré : CHF 81'000.00
        Avoir de vieillesse : CHF 123'000.00
        Les prestations sont régies par le règlement de prévoyance et le plan
        de prévoyance de la caisse.
    """,
    "de": """
        *** ARCHIVKOPIE — PERSÖNLICHER VORSORGEAUSWEIS ***
        Versicherte Person: SYNTHETISCHE PERSON
        Versicherter Lohn: CHF 81'000.00
        Altersguthaben: CHF 123'000.00
        Massgebend sind das Vorsorgereglement und der Vorsorgeplan der Kasse.
    """,
    "it": """
        *** DUPLICATO — CERTIFICATO PERSONALE DI PREVIDENZA ***
        Persona assicurata: PERSONA SINTETICA
        Salario assicurato: CHF 81'000.00
        Avere di vecchiaia: CHF 123'000.00
        Si applicano il regolamento di previdenza e il piano di previdenza.
    """,
}


_GENERAL_PLAN_WITH_PERSONAL_TERMS = """
    RÈGLEMENT DE PRÉVOYANCE PROFESSIONNELLE
    Le présent plan définit de manière générale la personne assurée, le salaire
    assuré et la constitution de l'avoir de vieillesse. Il ne nomme aucune
    personne et ne certifie aucun montant individuel.
"""


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
    "language, text",
    _NOISY_PERSONAL_CERTIFICATE_TEXTS.items(),
    ids=_NOISY_PERSONAL_CERTIFICATE_TEXTS.keys(),
)
def test_noisy_personal_certificate_facts_win_over_plan_reference(language, text):
    assert _detect_document_type(text) == "lpp_certificate", language


def test_general_plan_terms_without_individual_facts_remain_plan():
    assert _detect_document_type(_GENERAL_PLAN_WITH_PERSONAL_TERMS) == "lpp_plan"


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


def _install_synthetic_plan_parser(monkeypatch, *, full_text=None):
    from app.services.docling import parser as parser_module
    from app.services.docling.extractors import lpp_certificate as lpp_module

    class _SyntheticPlanParser:
        parse_calls = 0

        @staticmethod
        def parse_pdf(file_bytes):
            _SyntheticPlanParser.parse_calls += 1
            assert file_bytes.startswith(b"%PDF-")
            return SimpleNamespace(
                full_text=full_text or _SYNTHETIC_PLAN_TEXTS["fr"],
                pages=[],
            )

    _LppExtractorSpy.constructor_calls = 0
    _LppExtractorSpy.extract_calls = 0
    monkeypatch.setattr(parser_module, "DocumentParser", _SyntheticPlanParser)
    monkeypatch.setattr(lpp_module, "LPPCertificateExtractor", _LppExtractorSpy)
    return _SyntheticPlanParser


def _upload_synthetic_plan(
    client,
    marker,
    *,
    index_in_rag=False,
    idempotency_key=None,
):
    headers = {}
    if idempotency_key is not None:
        headers["Idempotency-Key"] = idempotency_key
    return client.post(
        f"/api/v1/documents/upload?index_in_rag={'true' if index_in_rag else 'false'}",
        headers=headers,
        files={
            "file": (
                "synthetic-plan.pdf",
                f"%PDF-1.4\nsynthetic-plan-{marker}".encode(),
                "application/pdf",
            )
        },
    )


def _document_rows():
    db = TestingSessionLocal()
    try:
        return db.query(DocumentModel).all()
    finally:
        db.close()


def _poisoned_lpp_plan_cache_payload():
    return {
        "id": "other-user-durable-document-id",
        "document_type": "lpp_plan",
        "extracted_fields": {},
        "confidence": 0.0,
        "fields_found": 0,
        "fields_total": 0,
        "raw_text_preview": "OTHER-USER-PRIVATE-PREVIEW",
        "warnings": [
            "LPP plan or regulation detected. Its general terms were not "
            "treated as personal pension facts."
        ],
        "rag_indexed": False,
    }


def _assert_opaque_ephemeral_id(payload):
    response = DocumentUploadResponse.model_validate(payload)
    assert response.id
    assert isinstance(response.id, str)
    assert response.id != "test-user-id"
    assert response.id != "other-user-durable-document-id"

    assert "synthetic-plan" not in response.id
    assert "private" not in response.id.lower()


def _install_empty_idempotency_spies(monkeypatch):
    from app.services import idempotency

    calls = SimpleNamespace(
        lookup_key=[],
        lookup_sha=[],
        store_key=[],
        store_sha=[],
    )

    async def lookup_by_key(key):
        calls.lookup_key.append(key)
        return None

    async def lookup_by_file_sha(sha):
        calls.lookup_sha.append(sha)
        return None

    async def store_by_key(key, payload):
        calls.store_key.append((key, payload))
        return True

    async def store_by_file_sha(sha, payload):
        calls.store_sha.append((sha, payload))
        return True

    monkeypatch.setattr(idempotency, "lookup_by_key", lookup_by_key)
    monkeypatch.setattr(idempotency, "lookup_by_file_sha", lookup_by_file_sha)
    monkeypatch.setattr(idempotency, "store_by_key", store_by_key)
    monkeypatch.setattr(idempotency, "store_by_file_sha", store_by_file_sha)
    return calls


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


def test_lpp_plan_response_is_exact_zero_fact_raw_free_and_never_indexed(
    client,
    monkeypatch,
):
    from app.api.v1.endpoints import documents as documents_endpoint

    private_sentinel = "PRIVATE-SYNTHETIC-PLAN-CONTACT-ALICE-EXAMPLE"
    parser = _install_synthetic_plan_parser(
        monkeypatch,
        full_text=f"{private_sentinel}\n{_SYNTHETIC_PLAN_TEXTS['fr']}",
    )
    _install_empty_idempotency_spies(monkeypatch)
    rag_calls = []

    def index_in_rag(*args, **kwargs):
        rag_calls.append((args, kwargs))
        pytest.fail("lpp_plan authority must never enter RAG")

    monkeypatch.setattr(documents_endpoint, "_index_in_rag", index_in_rag)

    response = _upload_synthetic_plan(
        client,
        "ephemeral-raw-free",
        index_in_rag=True,
        idempotency_key="00000000-0000-4000-8000-000000000000",
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    _assert_opaque_ephemeral_id(payload)
    assert payload["document_type"] == "lpp_plan"
    assert payload["extracted_fields"] == {}
    assert payload["confidence"] == 0.0
    assert payload["fields_found"] == 0
    assert payload["fields_total"] == 0
    assert payload["rag_indexed"] is False
    assert payload.get("raw_text_preview") is None
    assert private_sentinel not in response.text
    assert parser.parse_calls == 1
    assert _LppExtractorSpy.constructor_calls == 0
    assert _LppExtractorSpy.extract_calls == 0
    assert rag_calls == []


def test_lpp_plan_authority_is_not_persisted_or_addressable(
    client,
    monkeypatch,
):
    _install_synthetic_plan_parser(monkeypatch)
    _install_empty_idempotency_spies(monkeypatch)

    response = _upload_synthetic_plan(client, "no-durable-row")

    assert response.status_code == 200, response.text
    payload = response.json()
    _assert_opaque_ephemeral_id(payload)
    assert _document_rows() == []
    assert client.get(f"/api/v1/documents/{payload['id']}").status_code == 404


def test_lpp_plan_authority_response_is_never_cached(
    client,
    monkeypatch,
):
    _install_synthetic_plan_parser(monkeypatch)
    cache_calls = _install_empty_idempotency_spies(monkeypatch)

    response = _upload_synthetic_plan(
        client,
        "no-response-cache",
        idempotency_key="00000000-0000-4000-8000-000000000000",
    )

    assert response.status_code == 200, response.text
    assert cache_calls.store_key == []
    assert cache_calls.store_sha == []


def test_cross_user_sha_cache_cannot_replay_or_classify_lpp_plan(
    client,
    monkeypatch,
):
    from app.services import idempotency

    parser = _install_synthetic_plan_parser(monkeypatch)
    cache_calls = _install_empty_idempotency_spies(monkeypatch)

    async def poisoned_sha_lookup(_sha):
        cache_calls.lookup_sha.append(_sha)
        return _poisoned_lpp_plan_cache_payload()

    monkeypatch.setattr(idempotency, "lookup_by_file_sha", poisoned_sha_lookup)

    response = _upload_synthetic_plan(client, "cross-user-sha-cache")

    assert response.status_code == 200, response.text
    payload = response.json()
    _assert_opaque_ephemeral_id(payload)
    assert payload["document_type"] == "lpp_plan"
    assert payload.get("raw_text_preview") is None
    assert "OTHER-USER-PRIVATE-PREVIEW" not in response.text
    assert parser.parse_calls == 1
    assert cache_calls.store_sha == []
    assert _document_rows() == []


def test_idempotency_key_cache_cannot_replay_lpp_plan_response(
    client,
    monkeypatch,
):
    from app.services import idempotency

    parser = _install_synthetic_plan_parser(monkeypatch)
    cache_calls = _install_empty_idempotency_spies(monkeypatch)

    async def poisoned_key_lookup(key):
        cache_calls.lookup_key.append(key)
        return _poisoned_lpp_plan_cache_payload()

    monkeypatch.setattr(idempotency, "lookup_by_key", poisoned_key_lookup)

    response = _upload_synthetic_plan(
        client,
        "idempotency-key-cache",
        idempotency_key="00000000-0000-4000-8000-000000000000",
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    _assert_opaque_ephemeral_id(payload)
    assert payload["document_type"] == "lpp_plan"
    assert payload.get("raw_text_preview") is None
    assert "OTHER-USER-PRIVATE-PREVIEW" not in response.text
    assert parser.parse_calls == 1
    assert cache_calls.store_key == []
    assert cache_calls.store_sha == []
    assert _document_rows() == []
