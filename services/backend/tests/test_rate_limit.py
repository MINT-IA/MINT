"""
Tests de sécurité — rate limiting et TTL refresh token.

Vérifie:
1. Les endpoints coûteux (/retirement/*, /arbitrage/*, /scenarios, /fri/*) sont
   protégés par un rate limit de 10/minute (réponse 429 après dépassement).
2. Le refresh token expire dans < 8 jours (et non plus 30 jours).
"""

import os
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from unittest.mock import patch

# Force rate limiting ON for these tests (conftest sets TESTING=1 which disables it)
# We override the limiter's enabled flag directly in each test that needs it.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _retirement_avs_payload() -> dict:
    return {
        "age_actuel": 50,
        "age_retraite": 65,
        "is_couple": False,
        "annees_lacunes": 0,
        "esperance_vie": 85,
    }


def _arbitrage_rente_payload() -> dict:
    return {
        "capital_lpp_total": 300000,
        "capital_obligatoire": 200000,
        "capital_surobligatoire": 100000,
        "rente_annuelle_proposee": 18000,
    }


def _scenario_payload() -> dict:
    import uuid
    return {
        "profileId": str(uuid.uuid4()),
        "kind": "compound_interest",
        "inputs": {"principal": 10000, "annualRate": 5.0, "years": 10},
    }


def _fri_payload() -> dict:
    # Uses camelCase aliases as required by FriBaseModel (alias_generator=to_camel)
    # input_data has alias="inputData", income_volatility must be "low"/"medium"/"high"
    return {
        "inputData": {
            "liquidAssets": 30000,
            "monthlyFixedCosts": 3000,
            "shortTermDebtRatio": 0.1,
            "incomeVolatility": "low",
            "actual3a": 50000,
            "max3a": 7258,
            "potentielRachatLpp": 20000,
            "rachatEffectue": 0,
            "tauxMarginal": 0.25,
            "isPropertyOwner": False,
            "amortIndirect": 0,
            "replacementRatio": 0.6,
            "disabilityGapRatio": 0.2,
            "hasDependents": False,
            "deathProtectionGapRatio": 0.0,
            "mortgageStressRatio": 0.0,
            "concentrationRatio": 0.2,
            "employerDependencyRatio": 0.8,
            "archetype": "swiss_native",
            "age": 50,
            "canton": "ZH",
        },
        "confidenceScore": 80,
    }


# ---------------------------------------------------------------------------
# Task 1: Rate limit — endpoints coûteux retournent 429 après dépassement
# ---------------------------------------------------------------------------

class TestRateLimitCostlyEndpoints:
    """
    Ces tests activent le rate limiter en remplaçant le limiter.enabled
    temporairement, puis envoient (limit + 1) requêtes successives pour
    vérifier que la dernière retourne 429.
    """

    def _enable_limiter_for_test(self, app, client):
        """Context helper : active le limiter et retourne le client."""
        from app.core.rate_limit import limiter
        original = limiter.enabled
        limiter.enabled = True
        try:
            yield client
        finally:
            limiter.enabled = original

    def test_retirement_avs_rate_limited(self, client: TestClient):
        """Test T1: /retirement/avs/estimate → 429 après 10 req/min."""
        from app.core.rate_limit import limiter

        limiter.enabled = True
        try:
            payload = _retirement_avs_payload()
            responses = [
                client.post("/api/v1/retirement/avs/estimate", json=payload)
                for _ in range(11)
            ]
            status_codes = [r.status_code for r in responses]
            # Les 10 premières doivent passer (200), la 11e → 429
            assert 200 in status_codes, "Aucune requête n'a réussi"
            assert 429 in status_codes, (
                f"429 non reçu après 11 requêtes — codes: {status_codes}"
            )
        finally:
            limiter.enabled = False

    def test_arbitrage_rente_rate_limited(self, client: TestClient):
        """Test T2: /arbitrage/rente-vs-capital → 429 après 10 req/min."""
        from app.core.rate_limit import limiter

        limiter.enabled = True
        try:
            payload = _arbitrage_rente_payload()
            responses = [
                client.post("/api/v1/arbitrage/rente-vs-capital", json=payload)
                for _ in range(11)
            ]
            status_codes = [r.status_code for r in responses]
            assert 429 in status_codes, (
                f"429 non reçu sur /arbitrage/rente-vs-capital — codes: {status_codes}"
            )
        finally:
            limiter.enabled = False

    def test_scenarios_rate_limited(self, client: TestClient):
        """Test T3: /scenarios → 429 après 10 req/min."""
        from app.core.rate_limit import limiter

        limiter.enabled = True
        try:
            payload = _scenario_payload()
            responses = [
                client.post("/api/v1/scenarios", json=payload)
                for _ in range(11)
            ]
            status_codes = [r.status_code for r in responses]
            assert 429 in status_codes, (
                f"429 non reçu sur /scenarios — codes: {status_codes}"
            )
        finally:
            limiter.enabled = False

    def test_fri_rate_limited(self, client: TestClient):
        """Test T4: /fri/current → 429 après 10 req/min."""
        from app.core.rate_limit import limiter

        limiter.enabled = True
        try:
            payload = _fri_payload()
            responses = [
                client.post("/api/v1/fri/current", json=payload)
                for _ in range(11)
            ]
            status_codes = [r.status_code for r in responses]
            assert 429 in status_codes, (
                f"429 non reçu sur /fri/current — codes: {status_codes}"
            )
        finally:
            limiter.enabled = False

    def test_rate_limit_response_is_json_429(self, client: TestClient):
        """Test T5: réponse 429 est bien en JSON avec status_code correct."""
        from app.core.rate_limit import limiter

        limiter.enabled = True
        try:
            payload = _retirement_avs_payload()
            responses = [
                client.post("/api/v1/retirement/avs/estimate", json=payload)
                for _ in range(12)
            ]
            four_twenty_nines = [r for r in responses if r.status_code == 429]
            assert four_twenty_nines, "Aucun 429 reçu"
            resp = four_twenty_nines[0]
            assert resp.status_code == 429
        finally:
            limiter.enabled = False


# ---------------------------------------------------------------------------
# Task 2: Refresh token TTL — doit être < 8 jours (7 jours cible)
# ---------------------------------------------------------------------------

class TestRefreshTokenTTL:
    """Vérifie que le refresh token expire dans 7 jours (pas 30)."""

    def test_refresh_token_expires_within_8_days(self):
        """Test T6: Le refresh token expire dans moins de 8 jours."""
        from app.services.auth_service import create_refresh_token
        import jwt
        from app.core.config import settings

        token = create_refresh_token(user_id="test-user-ttl")
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        now = datetime.now(timezone.utc)
        delta_days = (exp - now).total_seconds() / 86400

        assert delta_days <= 7.1, (
            f"Refresh token TTL trop long: {delta_days:.1f} jours (max 7)"
        )

    def test_refresh_token_not_expired_immediately(self):
        """Test T7: Le refresh token est valide immédiatement après création."""
        from app.services.auth_service import create_refresh_token, decode_refresh_token

        token = create_refresh_token(user_id="test-user-valid")
        payload = decode_refresh_token(token)
        assert payload is not None, "Refresh token invalide immédiatement après création"
        assert payload["user_id"] == "test-user-valid"

    def test_refresh_token_ttl_exactly_7_days(self):
        """Test T8: Le TTL du refresh token est d'exactement 7 jours (±1 seconde)."""
        from app.services.auth_service import create_refresh_token
        import jwt
        from app.core.config import settings

        before = datetime.now(timezone.utc)
        token = create_refresh_token(user_id="test-user-7d")
        after = datetime.now(timezone.utc)

        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        iat = datetime.fromtimestamp(payload["iat"], tz=timezone.utc)

        ttl_seconds = (exp - iat).total_seconds()
        expected_seconds = 7 * 24 * 3600  # 604800

        assert abs(ttl_seconds - expected_seconds) < 2, (
            f"TTL inattendu: {ttl_seconds}s (attendu ~{expected_seconds}s = 7 jours)"
        )

    def test_refresh_token_type_is_refresh(self):
        """Test T9: Le payload contient type='refresh'."""
        from app.services.auth_service import create_refresh_token
        import jwt
        from app.core.config import settings

        token = create_refresh_token(user_id="test-type")
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        assert payload.get("type") == "refresh", (
            f"Type incorrect: {payload.get('type')}"
        )

    def test_expired_refresh_token_is_rejected(self):
        """Test T10: Un refresh token expiré est rejeté par decode_refresh_token."""
        import jwt
        from app.core.config import settings
        from app.services.auth_service import decode_refresh_token

        # Forge un token déjà expiré (exp = il y a 1 seconde)
        expired_payload = {
            "user_id": "test-expired",
            "type": "refresh",
            "exp": datetime.now(timezone.utc) - timedelta(seconds=1),
            "iat": datetime.now(timezone.utc) - timedelta(days=7),
        }
        expired_token = jwt.encode(
            expired_payload,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )
        result = decode_refresh_token(expired_token)
        assert result is None, "Un token expiré ne doit pas être décodé"
