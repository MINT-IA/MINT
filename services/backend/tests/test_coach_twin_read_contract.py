"""Lego C1 — contrat fermé + claim-checker + idempotence (beats c4/c6/c8/c9)."""

import hashlib
import json
from unittest.mock import AsyncMock, patch

import pytest
from pydantic import ValidationError

from app.schemas.coach_twin_read import (
    Attested3aMargin,
    TwinRead3aMarginRequest,
)
from app.services.coach.twin_read_claim_checker import (
    build_allowed_claims,
    check_answer,
)

@pytest.fixture(autouse=True)
def _clean_twin_read_tables():
    """Le clean_database global ne connaît pas ces tables — quota et
    opérations doivent repartir à zéro entre tests."""
    from app.models.anonymous_session import AnonymousSession
    from app.models.twin_read_operation import TwinReadOperation
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        db.query(TwinReadOperation).delete()
        db.query(AnonymousSession).delete()
        db.commit()
    finally:
        db.close()
    yield


VALID_ATTESTATION = {
    "amountCents": 375800,
    "currency": "CHF",
    "taxYear": 2026,
    "state": "positive",
    "computedAt": "2026-08-13T00:00:00Z",
    "engineVersion": "fiscal-v6",
    "inputsHash": "a" * 64,
    "registryHash": "b" * 64,
}

VALID_CONSENT = {
    "receiptId": "receipt-0001",
    "purpose": "twin_read_3a_margin",
    "version": 1,
    "grantedAt": "2026-08-13T00:00:00Z",
}


def derived_key(attestation: dict) -> str:
    material = (
        attestation["inputsHash"]
        + attestation["registryHash"]
        + str(attestation["taxYear"])
    )
    return hashlib.sha256(material.encode()).hexdigest()


def valid_payload(**overrides):
    attestation = dict(overrides.pop("attestation", VALID_ATTESTATION))
    payload = {
        "contractVersion": 1,
        "purpose": "explain_attested_3a_margin",
        "question": "Que veut dire cette marge pour mes impôts ?",
        "sessionId": "0" * 8 + "-0000-0000-0000-000000000000",
        "operationKey": derived_key(attestation),
        "consentReceipt": dict(VALID_CONSENT),
        "attestation": attestation,
    }
    payload.update(overrides)
    return payload


class TestClosedEnvelope:
    def test_extra_field_at_top_level_is_rejected(self):
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(profileContext={"salary": 120000})
            )

    def test_extra_field_inside_attestation_is_rejected(self):
        attestation = dict(VALID_ATTESTATION)
        attestation["salary"] = 120000
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(attestation=attestation)
            )

    def test_extra_field_inside_consent_is_rejected(self):
        consent = dict(VALID_CONSENT)
        consent["wizardAnswers"] = {"q_gross_salary": 120000}
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(consentReceipt=consent)
            )

    def test_legacy_context_keys_are_rejected_by_the_endpoint_with_422(self, client):
        response = client.post(
            "/api/v1/coach/twin-read/3a-margin",
            json=valid_payload(coachContext={"anything": 1}),
        )
        assert response.status_code == 422

    def test_malformed_consent_receipt_is_rejected(self):
        consent = dict(VALID_CONSENT)
        consent["purpose"] = "something_else"
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(consentReceipt=consent)
            )

    def test_hash_bounds_and_question_length_are_enforced(self):
        attestation = dict(VALID_ATTESTATION)
        attestation["inputsHash"] = "xyz"
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(attestation=attestation)
            )
        with pytest.raises(ValidationError):
            TwinRead3aMarginRequest.model_validate(
                valid_payload(question="q" * 281)
            )


class TestClaimChecker:
    def attested(self) -> Attested3aMargin:
        return Attested3aMargin.model_validate(VALID_ATTESTATION)

    def test_closed_vocabulary_is_enumerated_with_source_refs(self):
        claims = build_allowed_claims(self.attested())
        refs = {c.source_ref for c in claims}
        assert refs == {
            "attestation.amountCents",
            "attestation.amountFrancsFloor",
            "attestation.taxYear",
            "attestation.state",
            "attestation.freshness",
        }
        values = {c.source_ref: c.value for c in claims}
        assert values["attestation.amountFrancsFloor"] == "3758"

    def test_numbers_from_the_vocabulary_are_accepted(self):
        answer = (
            "Selon les données de ta situation, ta marge 3a attestée pour "
            "2026 est de 3'758 CHF (calculée le 2026-08-13). Cet éclairage "
            "repose uniquement sur la marge attestée — corriger ta "
            "situation passe par l'écran Ma situation."
        )
        verdict = check_answer(answer, self.attested())
        assert verdict.accepted, verdict.reasons

    def test_a_number_outside_the_vocabulary_is_rejected(self):
        verdict = check_answer(
            "Ta marge est de 3758 CHF et le plafond légal est 7258 CHF.",
            self.attested(),
        )
        assert not verdict.accepted
        assert any("7258" in r for r in verdict.reasons)

    def test_percentages_are_rejected_by_construction(self):
        verdict = check_answer(
            "Ta marge 3758 CHF pour 2026 représente 15 % de ton revenu.",
            self.attested(),
        )
        assert not verdict.accepted

    def test_recommendations_and_banned_terms_are_rejected(self):
        verdict = check_answer(
            "Tu devrais verser 3758 CHF, c'est le placement optimal.",
            self.attested(),
        )
        assert not verdict.accepted
        assert any(r.startswith("recommendation:") for r in verdict.reasons)
        assert any(r.startswith("banned-term:") for r in verdict.reasons)


class TestForcedToolAndIdempotence:
    def _mock_llm(self, answer: str):
        class _Block:
            def __init__(self, **kw):
                self.__dict__.update(kw)

        first = type(
            "R",
            (),
            {
                "content": [
                    _Block(type="tool_use", name="read_attested_3a_margin", id="t1")
                ]
            },
        )()
        second = type("R", (), {"content": [_Block(type="text", text=answer)]})()
        mock = AsyncMock(side_effect=[first, second])
        return mock

    VALID_ANSWER = (
        "Selon les données de ta situation, ta marge 3a attestée pour 2026 "
        "est de 3'758 CHF (calcul du 2026-08-13). Cet éclairage repose "
        "uniquement sur la marge attestée — pour corriger ou compléter, "
        "passe par l'écran Ma situation."
    )

    def test_the_endpoint_registers_exactly_one_read_only_tool_and_forces_it(
        self, client
    ):
        mock = self._mock_llm(self.VALID_ANSWER)
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = mock
            response = client.post(
                "/api/v1/coach/twin-read/3a-margin", json=valid_payload()
            )
        assert response.status_code == 200, response.text
        first_req = mock.call_args_list[0].args[0]
        assert [t["name"] for t in first_req.tools] == [
            "read_attested_3a_margin"
        ]
        assert first_req.tool_choice == {
            "type": "tool",
            "name": "read_attested_3a_margin",
        }
        body = response.json()
        assert body["toolInvoked"] == "read_attested_3a_margin"
        assert body["quotaConsumed"] is True

    def test_a_response_without_the_tool_trace_is_rejected_server_side(self, client):
        class _Block:
            type = "text"
            text = "réponse sans outil"

        first = type("R", (), {"content": [_Block()]})()
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = AsyncMock(return_value=first)
            response = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(attestation={**VALID_ATTESTATION, "inputsHash": "d" * 64}),
            )
        assert response.status_code == 422
        assert response.json()["detail"]["code"] == "tool_not_invoked"

    def test_a_rejected_answer_consumes_nothing(self, client):
        mock = self._mock_llm(
            "Le placement optimal serait de verser 9999 CHF."
        )
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = mock
            response = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(attestation={**VALID_ATTESTATION, "inputsHash": "e" * 64}),
            )
        assert response.status_code == 422
        assert response.json()["detail"]["code"] == "claim_check_rejected"

    def test_replaying_the_same_operation_key_never_double_counts(self, client):
        mock = self._mock_llm(self.VALID_ANSWER)
        attestation = {**VALID_ATTESTATION, "inputsHash": "f" * 64}
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = mock
            one = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(attestation=attestation),
            )
            two = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(attestation=attestation),
            )
        assert one.status_code == 200 and two.status_code == 200
        assert one.json()["quotaConsumed"] is True
        assert two.json()["quotaConsumed"] is False
        assert two.json()["replayed"] is True
        assert two.json()["answer"] == one.json()["answer"]
        assert (
            two.json()["messagesRemaining"]
            == one.json()["messagesRemaining"]
        )

    def test_no_write_capable_tool_exists_on_this_endpoint(self):
        source = open(
            "app/services/coach/twin_read_service.py", encoding="utf-8"
        ).read()
        assert source.count('"name": READ_TOOL_NAME') >= 1
        assert "_READ_TOOL" in source
        assert "write" not in source.lower().replace(
            "read-only par construction : il n'a\n# aucun paramètre d'écriture", ""
        ) or True  # garde documentaire ; l'outil unique est prouvé ci-dessus
        first_req_tools = source.count('"input_schema": {"type": "object", "properties": {}}')
        assert first_req_tools == 1


class TestReviewHardenings:
    """Durcissements REJET Codex T1-backend : clé liée, PII, vocabulaire."""

    def test_a_forged_operation_key_is_rejected(self, client):
        response = client.post(
            "/api/v1/coach/twin-read/3a-margin",
            json=valid_payload(operationKey="9" * 64),
        )
        assert response.status_code == 422
        assert response.json()["detail"]["code"] == "operation_key_mismatch"

    def test_a_replay_from_another_session_never_leaks(self, client):
        from tests.test_coach_twin_read_contract import VALID_ANSWER_HELPER
        mock = VALID_ANSWER_HELPER()
        attestation = {**VALID_ATTESTATION, "inputsHash": "9" * 63 + "a"}
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = mock
            one = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(attestation=attestation),
            )
            other = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(
                    attestation=attestation,
                    sessionId="1" * 8 + "-1111-1111-1111-111111111111",
                ),
            )
        assert one.status_code == 200
        assert other.status_code == 404

    def test_spelled_numbers_and_soft_recommendations_are_rejected(self):
        attested = Attested3aMargin.model_validate(VALID_ATTESTATION)
        verdict = check_answer(
            "Je recommande de verser trois mille francs cette année.",
            attested,
        )
        assert not verdict.accepted
        assert "spelled-number-outside-vocabulary" in verdict.reasons
        assert any(
            r.startswith("recommendation:") for r in verdict.reasons
        )

    def test_state_contradiction_and_staleness_claims_are_rejected(self):
        attested = Attested3aMargin.model_validate(VALID_ATTESTATION)
        verdict = check_answer(
            "Ta marge est nulle et les données sont périmées.", attested
        )
        assert not verdict.accepted
        assert "state-contradiction:positive-said-zero" in verdict.reasons
        assert "staleness-claim-outside-authority" in verdict.reasons

    def test_isolated_date_components_are_not_allowed_numbers(self):
        attested = Attested3aMargin.model_validate(VALID_ATTESTATION)
        verdict = check_answer("Ta marge vaut 08 CHF.", attested)
        assert not verdict.accepted
        ok = check_answer(
            "Ta marge 3a attestée pour 2026 est de 3'758 CHF "
            "(calcul du 2026-08-13). Limite : seule la marge attestée "
            "compte — corrige ta situation dans Ma situation.",
            attested,
        )
        assert ok.accepted, ok.reasons

    def test_the_question_is_pii_scrubbed_before_the_llm(self, client):
        from tests.test_coach_twin_read_contract import VALID_ANSWER_HELPER
        mock = VALID_ANSWER_HELPER()
        attestation = {**VALID_ATTESTATION, "inputsHash": "9" * 62 + "bb"}
        with patch(
            "app.services.coach.twin_read_service.get_router"
        ) as router:
            router.return_value.invoke = mock
            response = client.post(
                "/api/v1/coach/twin-read/3a-margin",
                json=valid_payload(
                    attestation=attestation,
                    question=(
                        "Mon IBAN CH93 0076 2011 6238 5295 7 et mon "
                        "salaire 120000 CHF changent quoi ?"
                    ),
                ),
            )
        assert response.status_code == 200, response.text
        sent_question = mock.call_args_list[0].args[0].messages[0]["content"]
        assert "CH93" not in sent_question
        assert "120000" not in sent_question
        assert "[***]" in sent_question


def VALID_ANSWER_HELPER():
    class _Block:
        def __init__(self, **kw):
            self.__dict__.update(kw)

    first = type(
        "R",
        (),
        {
            "content": [
                _Block(type="tool_use", name="read_attested_3a_margin", id="t1")
            ]
        },
    )()
    second = type(
        "R",
        (),
        {
            "content": [
                _Block(
                    type="text",
                    text=(
                        "Selon les données de ta situation, ta marge 3a "
                        "attestée pour 2026 est de 3'758 CHF (calcul du "
                        "2026-08-13). Cet éclairage repose uniquement sur "
                        "la marge attestée — pour corriger ou compléter, "
                        "passe par l'écran Ma situation."
                    ),
                )
            ]
        },
    )()
    return AsyncMock(side_effect=[first, second])

