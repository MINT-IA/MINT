"""
Integration test for the 3 P0 bugs fixed in 2026-04-15:

BUG #1 — /documents/scan-confirmation did not merge confirmed fields into
         ProfileModel. Proven by the E2E script: after confirm, GET
         /profiles/me.avoirLpp was null.

BUG #2 — /coach/chat did not inject the authenticated user's persisted
         profile into the system prompt. Coach replied "je n'ai aucune
         donnee" despite a populated profile row.

BUG #3 — /coach/chat had NO length enforcement. Response was 14
         sentences / 177 words with "**Les faits :**" / "**Pour toi :**"
         markdown headers (4-layer doctrine leak).

Related smoke script: tools/e2e_flow_smoke.sh (runs against staging).

Run:
    cd services/backend && python3 -m pytest tests/integration/test_profile_wire_e2e.py -q
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.main import app
from app.core.auth import get_current_user, require_current_user


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------


def _ensure_user_and_profile(client, household: str = "couple") -> str:
    """Create a user row (so FK works) and an empty profile; return profile_id."""
    from app.models.user import User
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        existing = db.query(User).filter(User.id == "test-user-id").first()
        if not existing:
            db.add(
                User(
                    id="test-user-id",
                    email="test@mint.ch",
                    hashed_password="x",
                )
            )
            db.commit()
    finally:
        db.close()

    # POST /profiles to bootstrap a row for this user.
    resp = client.post(
        "/api/v1/profiles",
        json={
            "householdType": household,
            "birthYear": 1977,
            "canton": "VS",
        },
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


# ---------------------------------------------------------------------------
# BUG #1 — scan-confirmation writes to ProfileModel
# ---------------------------------------------------------------------------


class TestScanConfirmationMerge:
    """POST /documents/scan-confirmation must merge confirmed fields to profile."""

    def test_avoir_lpp_and_salaire_assure_are_merged(self, client):
        profile_id = _ensure_user_and_profile(client)

        # Patch manual lppInsuredSalary to simulate user-entered value.
        patch_resp = client.patch(
            f"/api/v1/profiles/{profile_id}",
            json={"lppInsuredSalary": 91967, "incomeNetMonthly": 7600},
        )
        assert patch_resp.status_code == 200

        # POST scan-confirmation with Julien's LPP certificate values.
        confirm_resp = client.post(
            "/api/v1/documents/scan-confirmation",
            json={
                "documentType": "lpp_certificate",
                "overallConfidence": 0.88,
                "extractionMethod": "claude_vision",
                "confirmedFields": [
                    {
                        "fieldName": "avoirLppTotal",
                        "value": 70376.6,
                        "confidence": "high",
                    },
                    {
                        "fieldName": "salaireAssure",
                        "value": 95941.4,
                        "confidence": "high",
                    },
                    {
                        "fieldName": "rachatMaximum",
                        "value": 539414.0,
                        "confidence": "medium",
                    },
                    {
                        "fieldName": "tauxConversion",
                        "value": 5.0,
                        "confidence": "low",  # must NOT merge
                    },
                ],
            },
        )
        assert confirm_resp.status_code == 200, confirm_resp.text
        body = confirm_resp.json()
        # Backward compat: response shape preserved.
        assert body["status"] == "confirmed"
        assert body["fieldsUpdated"] == 4

        # GET /profiles/me must now surface the merged values.
        me = client.get("/api/v1/profiles/me")
        assert me.status_code == 200, me.text
        data = me.json()
        assert data["avoirLpp"] == 70376.6, "avoirLppTotal must merge to data.avoirLpp"
        # Vision overwrites the manual estimate (95941 vs 91967, >1% delta).
        assert data["lppInsuredSalary"] == 95941.4
        assert data["lppBuybackMax"] == 539414.0

    def test_low_confidence_fields_are_not_merged(self, client):
        _ensure_user_and_profile(client)
        confirm_resp = client.post(
            "/api/v1/documents/scan-confirmation",
            json={
                "documentType": "lpp_certificate",
                "overallConfidence": 0.5,
                "extractionMethod": "claude_vision",
                "confirmedFields": [
                    {
                        "fieldName": "avoirLppTotal",
                        "value": 999999.0,
                        "confidence": "low",
                    },
                ],
            },
        )
        assert confirm_resp.status_code == 200
        me = client.get("/api/v1/profiles/me")
        assert me.json().get("avoirLpp") in (None, 0)


# ---------------------------------------------------------------------------
# BUG #2 + #3 — /coach/chat loads profile + enforces length
# ---------------------------------------------------------------------------


def _mock_premium_entitlements():
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


class _SpyOrchestrator:
    """Orchestrator double that captures the system_prompt received by Claude."""

    def __init__(self, canned_answer: str):
        self.system_prompt_seen = ""
        self.canned_answer = canned_answer

    async def query(self, **kwargs):
        self.system_prompt_seen = kwargs.get("system_prompt") or ""
        return {
            "answer": self.canned_answer,
            "sources": [],
            "disclaimers": [],
            "tokens_used": 100,
        }


class TestCoachChatProfileInjection:
    """BUG #2: authenticated coach sees the persisted profile."""

    def test_system_prompt_contains_user_facts_block(self, client):
        profile_id = _ensure_user_and_profile(client)
        client.patch(
            f"/api/v1/profiles/{profile_id}",
            json={
                "birthYear": 1977,
                "canton": "VS",
                "incomeNetMonthly": 7600,
                "lppInsuredSalary": 91967,
                "has2ndPillar": True,
                "pillar3aAnnual": 7258,
                "employmentStatus": "salarie",
            },
        )

        spy = _SpyOrchestrator(
            canned_answer="Tu as 49 ans, canton VS, 7600 CHF net par mois."
        )

        with _mock_premium_entitlements(), patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            new=AsyncMock(return_value=spy),
        ):
            resp = client.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Que sais-tu de moi ? Cite mes chiffres.",
                    "provider": "claude",
                    "api_key": "sk-test-key",
                    "language": "fr",
                    "cashLevel": 3,
                },
            )
        assert resp.status_code == 200, resp.text

        sp = spy.system_prompt_seen
        assert "<facts_user>" in sp, "System prompt must carry the facts block"
        assert "VS" in sp
        assert "7600" in sp
        assert "91967" in sp or "91'967" in sp or "91 967" in sp or "Salaire assure LPP" in sp
        # Either the birthYear or the computed age must appear.
        assert "1977" in sp or "49 ans" in sp

    def test_empty_profile_context_still_reads_db(self, client):
        """Flutter may send {} — the DB persisted profile must still be used."""
        profile_id = _ensure_user_and_profile(client)
        client.patch(
            f"/api/v1/profiles/{profile_id}",
            json={"birthYear": 1977, "canton": "VS", "incomeNetMonthly": 7600},
        )

        spy = _SpyOrchestrator(canned_answer="Ok.")
        with _mock_premium_entitlements(), patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            new=AsyncMock(return_value=spy),
        ):
            resp = client.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Hello",
                    "provider": "claude",
                    "api_key": "sk-x",
                    "profileContext": {},  # intentionally empty
                },
            )
        assert resp.status_code == 200
        assert "<facts_user>" in spy.system_prompt_seen
        assert "VS" in spy.system_prompt_seen


class TestCoachChatLengthEnforcement:
    """BUG #3: coach answer is truncated to ≤ 5 sentences, no doctrine headers."""

    LONG_ANSWER_WITH_HEADERS = (
        "**Les faits :** Tu as 49 ans. Tu vis en VS. Ton salaire net est de 7600 CHF. "
        "Ton salaire assure LPP est de 91967 CHF. Ton avoir LPP est de 70376 CHF. "
        "**Pour toi :** Ca veut dire que tu es bien positionne. Tu as encore 16 ans "
        "avant la retraite legale. Ta marge de rachat est confortable. Ton taux de "
        "remplacement sera acceptable. **Questions :** As-tu deja envisage un rachat ? "
        "Veux-tu optimiser ton 3a ? Sais-tu que ton conjoint peut aussi contribuer ?"
    )

    def test_response_is_truncated_to_five_sentences(self, client):
        _ensure_user_and_profile(client)
        spy = _SpyOrchestrator(canned_answer=self.LONG_ANSWER_WITH_HEADERS)

        with _mock_premium_entitlements(), patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            new=AsyncMock(return_value=spy),
        ):
            resp = client.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Cite mes chiffres",
                    "provider": "claude",
                    "api_key": "sk-x",
                },
            )
        assert resp.status_code == 200
        msg = resp.json()["message"]

        # No markdown doctrine headers.
        assert "**Les faits" not in msg, f"Doctrine leak: {msg!r}"
        assert "**Pour toi" not in msg, f"Doctrine leak: {msg!r}"
        assert "**Questions" not in msg, f"Doctrine leak: {msg!r}"

        # ≤ 5 sentences. Split on ., !, ? — lenient count.
        import re as _re
        parts = [p for p in _re.split(r"[.!?]+", msg) if p.strip()]
        assert len(parts) <= 5, f"Expected ≤ 5 sentences, got {len(parts)}: {msg!r}"

    def test_system_prompt_contains_length_directive(self, client):
        _ensure_user_and_profile(client)
        spy = _SpyOrchestrator(canned_answer="Ok.")
        with _mock_premium_entitlements(), patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            new=AsyncMock(return_value=spy),
        ):
            client.post(
                "/api/v1/coach/chat",
                json={
                    "message": "Salut",
                    "provider": "claude",
                    "api_key": "sk-x",
                },
            )
        sp = spy.system_prompt_seen
        assert "LONGUEUR STRICTE" in sp
        assert "AUCUN en-tete" in sp
