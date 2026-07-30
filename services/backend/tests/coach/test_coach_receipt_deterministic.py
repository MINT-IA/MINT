"""Deterministic MoneyTruthReceipt short-circuit on the LIVE coach path (P0 #1114 suite).

Contexte prouvé (diagnostic 2026-07-30, staging LIVE, deployment 1da71b81 ⊃ dev)
=============================================================================
Le grounding du receipt EST câblé dans le system prompt (prouvé : dump de la
chaîne complète store→resolve→context→prompt = 5849 présent ; longueur du prompt
staging resolved 45879 vs pending 45596, delta = bloc valeur) ET la valeur EST
exemptée par le gate citations (« Ton net est 5849 CHF » → PASS). MAIS le
narrateur LLM ne rend PAS la valeur : sur le handoff /first-job (profil vide),
l'échafaudage d'onboarding + le bloc de reasoning « profil vide » (appended APRÈS
le grounding) noient le bloc, et quand le LLM tente un nombre dérivé/arrondi
(70188/an, 5869) le gate le REJETTE → retry → FALLBACK. Résultat staging : 0/8.

Ce fichier encode le contrat du fix : quand un tour porte un receipt RÉSOLU et
que l'utilisateur demande son net, le coach rend LA valeur du receipt de façon
DÉTERMINISTE (sans LLM, sans gate) — même mécanisme que le raccourci
rente/capital déjà en place. Les tests reproduisent le chemin LIVE (endpoint réel
POST /api/v1/coach/chat), pas seulement build_system_prompt.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints.coach_chat import (
    _message_is_net_salary_query,
    _receipt_deterministic_loop_result,
)
from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.services.encryption.banned_terms_runtime import _scan_text as _scan_banned

# Shape EXACTE produite par resolve_receipt_context (chemin resolved).
RESOLVED = {
    "status": "resolved",
    "receiptId": "rcpt-firstjob",
    "inputsHash": "a" * 64,
    "value": 5849.17,
    "base": "net",
    "taxYear": 2026,
    "jurisdiction": "CH-ZH",
    "sources": [
        {"id": "avs", "label": "AVS/AI/APG (LAVS art. 5)", "vintage": 2026},
        {"id": "lpp", "label": "LPP bonifications (LPP art. 16)", "vintage": 2026},
    ],
    "range": {"low": 5836.17, "high": 5868.67},
    "confidence": 0.82,
}
PENDING = {
    "status": "pending",
    "inputs": {"salaireBrutMensuel": 6500.0, "age": 25, "canton": "ZH"},
}

_NET_QUESTIONS = [
    "Quel est mon salaire net exact ?",
    "Combien me reste-t-il après les cotisations sociales ?",
    "Confirme-moi mon net mensuel, en chiffres.",
]
_CONTROL_3A = "Sur ce salaire, combien pourrais-je verser au 3a cette année ?"


# ── Intent detector ──────────────────────────────────────────────────────────
class TestNetSalaryQueryDetector:
    @pytest.mark.parametrize("q", _NET_QUESTIONS)
    def test_net_questions_match(self, q):
        assert _message_is_net_salary_query(q) is True

    def test_3a_control_does_not_match(self):
        # Le receipt net ne porte PAS le plafond 3a — on défère au LLM.
        assert _message_is_net_salary_query(_CONTROL_3A) is False

    @pytest.mark.parametrize(
        "q",
        [
            "Combien puis-je verser sur mon pilier 3a ?",
            "Quelle sera ma rente de retraite ?",
            "Combien d'impôt vais-je payer ?",
            "Est-ce que je peux racheter ma LPP ?",
        ],
    )
    def test_off_topic_does_not_match(self, q):
        assert _message_is_net_salary_query(q) is False

    @pytest.mark.parametrize(
        "q",
        [
            # Faux positifs trouvés par la revue adversariale Codex (2026-07-30).
            "Mon abonnement internet me coûte combien ?",  # "interNET" (sous-chaîne)
            "Quel est mon salaire brut ?",  # brut, pas net
            "Quel est mon patrimoine net ?",  # patrimoine, pas salaire
            "What is my net worth?",  # net worth, pas salaire
            "Quel est mon revenu locatif ?",  # revenu locatif
            "Combien je gagne avec mes investissements ?",  # investissements
            "Pourquoi ma paie est-elle en retard ?",  # retard de paie, pas montant
        ],
    )
    def test_codex_false_positives_do_not_match(self, q):
        assert _message_is_net_salary_query(q) is False

    def test_empty_message_does_not_match(self):
        assert _message_is_net_salary_query("") is False
        assert _message_is_net_salary_query(None) is False


# ── Deterministic loop-result builder ────────────────────────────────────────
class TestReceiptDeterministicLoopResult:
    @pytest.mark.parametrize("q", _NET_QUESTIONS)
    def test_resolved_net_question_renders_value(self, q):
        result = _receipt_deterministic_loop_result(RESOLVED, q)
        assert result is not None
        # La valeur du receipt (5849, franc arrondi) apparaît dans la réponse.
        assert "5'849" in result["answer"] or "5849" in result["answer"]
        assert result["tokens_used"] == 0
        assert result["degraded"] is False
        assert result["model_used"] == "deterministic-money-truth-receipt"

    def test_resolved_answer_has_no_banned_terms(self):
        result = _receipt_deterministic_loop_result(RESOLVED, _NET_QUESTIONS[0])
        hit = _scan_banned(result["answer"])
        assert hit is None, f"terme banni dans la réponse déterministe: {hit}"

    def test_resolved_answer_carries_disclaimer_and_sources(self):
        result = _receipt_deterministic_loop_result(RESOLVED, _NET_QUESTIONS[0])
        assert result["disclaimers"], "disclaimer LSFin requis"
        assert result["sources"], "sources du receipt attendues"
        # Forme RagSource du contrat mobile (title/file/section).
        for s in result["sources"]:
            assert set(s.keys()) == {"title", "file", "section"}, s

    def test_3a_control_defers_to_llm(self):
        assert _receipt_deterministic_loop_result(RESOLVED, _CONTROL_3A) is None

    def test_pending_defers_to_llm(self):
        # Pending ne porte pas de net calculé — pas de raccourci déterministe.
        assert _receipt_deterministic_loop_result(PENDING, _NET_QUESTIONS[0]) is None

    def test_no_receipt_is_noop(self):
        assert _receipt_deterministic_loop_result(None, _NET_QUESTIONS[0]) is None

    def test_resolved_without_finite_value_is_noop(self):
        bad = {**RESOLVED, "value": None}
        assert _receipt_deterministic_loop_result(bad, _NET_QUESTIONS[0]) is None

    @pytest.mark.parametrize("bad_value", [float("nan"), float("inf"), -5849.5, 0, 2e9])
    def test_non_positive_or_out_of_range_value_is_noop(self, bad_value):
        # Revue Codex : montant négatif / hors-borne / non fini -> on défère au LLM.
        bad = {**RESOLVED, "value": bad_value}
        assert _receipt_deterministic_loop_result(bad, _NET_QUESTIONS[0]) is None

    def test_banned_term_in_source_label_defers(self):
        # Revue Codex : un label de source forgé portant un terme banni LSFin ne
        # doit JAMAIS fuir (le chemin déterministe saute ComplianceGuard).
        poisoned = {
            **RESOLVED,
            "sources": [
                {"id": "x", "label": "Rendement garanti sans risque", "vintage": 2026}
            ],
        }
        assert _receipt_deterministic_loop_result(poisoned, _NET_QUESTIONS[0]) is None


# ── Chemin LIVE : endpoint réel POST /api/v1/coach/chat ──────────────────────
def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES

    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_consent_allow():
    from app.services.consent.consent_service import ConsentCheckResult

    return patch(
        "app.services.consent.consent_service.consent_service.check_or_log",
        return_value=ConsentCheckResult(grant_exists=True, allow=True),
    )


@pytest.fixture
def client_with_auth():
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), _mock_consent_allow(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


def _mock_orchestrator():
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(
        side_effect=AssertionError("orchestrator.query must NOT run on the receipt shortcut")
    )
    return patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        return_value=mock_orch,
    )


class TestLiveEndpointReceiptShortcut:
    """RED avant fix : sans raccourci, le tour part au LLM (mock lève) → pas 5849."""

    def test_resolved_receipt_net_question_renders_value_without_llm(
        self, client_with_auth
    ):
        agent_loop = AsyncMock(
            side_effect=AssertionError("_run_agent_loop must NOT run on the receipt shortcut")
        )
        with patch(
            "app.services.lucidity.receipt_store.resolve_receipt_context",
            return_value=RESOLVED,
        ), _mock_orchestrator(), patch(
            "app.api.v1.endpoints.coach_chat._run_agent_loop", agent_loop
        ):
            resp = client_with_auth.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Quel est mon salaire net exact ?",
                    "apiKey": "sk-test-key-12345",
                    "receiptId": "rcpt-firstjob",
                    "inputsHash": "a" * 64,
                },
            )
        assert resp.status_code == 200, resp.text
        msg = resp.json()["message"]
        assert "5'849" in msg or "5849" in msg, msg
        agent_loop.assert_not_called()

    def test_3a_control_still_uses_llm(self, client_with_auth):
        # Le contrôle 3a NE court-circuite PAS : le LLM (mocké) doit tourner.
        llm_result = {
            "answer": "Le plafond 3a pourrait s'appliquer selon ta situation.",
            "tool_calls": [],
            "citation_chips": None,
            "sources": [],
            "disclaimers": ["Outil éducatif."],
            "tokens_used": 42,
            "degraded": False,
            "model_used": "claude",
        }
        agent_loop = AsyncMock(return_value=llm_result)
        with patch(
            "app.services.lucidity.receipt_store.resolve_receipt_context",
            return_value=RESOLVED,
        ), patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            return_value=MagicMock(query=AsyncMock(return_value=llm_result)),
        ), patch(
            "app.api.v1.endpoints.coach_chat._run_agent_loop", agent_loop
        ):
            resp = client_with_auth.post(
                "/api/v1/coach/chat",
                json={
                    "message": _CONTROL_3A,
                    "apiKey": "sk-test-key-12345",
                    "receiptId": "rcpt-firstjob",
                    "inputsHash": "a" * 64,
                },
            )
        assert resp.status_code == 200, resp.text
        agent_loop.assert_called()
