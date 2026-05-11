"""
Phase 97 W7 iter#7 — B004 repro test.

The bare `except Exception: pass` at core/auth.py:55 swallows BOTH :
  (a) pyjwt decode failures (the INTENDED behavior — fall through to
      decode_token which has its own error handling)
  (b) sqlalchemy errors from `is_jti_blacklisted(db, jti)` (UNINTENDED —
      auth-bypass via infra degradation : a revoked token re-authenticates
      if the blacklist DB query raises)

Tests :
  1. DB error during blacklist check → must NOT authenticate (currently
     returns 200 — the bug). Post-fix : HTTPException 503 fail-CLOSED.
  2. JWT decode error in unverified path → flow proceeds to decode_token
     (preserve intended behavior).
  3. Valid non-revoked token → 200 OK (happy path regression guard).
  4. Valid revoked token → HTTPException 401 « Token révoqué » (existing
     blacklist enforcement still works post-fix).

Pre-fix : test 1 FAILS RED (returns 200, evidence of the auth-bypass).
Post-fix : 4/4 GREEN.
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.core.auth import get_current_user
from app.core.database import get_db
from app.main import app
from app.models.token_blacklist import TokenBlacklist
from app.models.user import User
from app.services.auth_service import create_access_token, hash_password


# ---------------------------------------------------------------------------
# Local probe endpoint — exercises get_current_user without the heavier
# coach_chat / documents auth stacks. Mirrors the production wiring
# (Depends(get_current_user)) so the bug surfaces identically.
# ---------------------------------------------------------------------------

_probe = FastAPI()


@_probe.get("/probe/me")
def _probe_me(user=Depends(get_current_user)):
    if user is None:
        return {"authenticated": False}
    return {"authenticated": True, "user_id": user.id}


@pytest.fixture
def probe_client():
    """Test client mounted on the local probe app (no main-app overrides)."""
    # Inherit the conftest in-memory DB
    from tests.conftest import override_get_db

    _probe.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(_probe) as c:
            yield c
    finally:
        _probe.dependency_overrides.clear()


@pytest.fixture
def seeded_user(probe_client):
    """Seed a real user in the in-memory DB and return (user_id, email)."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        u = User(
            id="b004-user-id",
            email="b004@mint.local",
            hashed_password=hash_password("b004pass123"),
            display_name="B004 Test User",
        )
        db.add(u)
        db.commit()
        return ("b004-user-id", "b004@mint.local")
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_b004_blacklist_db_error_fails_closed(probe_client, seeded_user):
    """
    Test 1 — THE B004 BUG.

    A valid (signed) JWT is presented. `is_jti_blacklisted` raises a
    SQLAlchemyError (simulated DB outage). The bare except WAS swallowing
    this and letting the request proceed to decode_token → 200 OK
    (auth-bypass : a token whose revocation status is unknown is accepted).

    Post-fix : fail-CLOSED with HTTPException 503 « Service de blacklist
    temporairement indisponible » — the system refuses authentication when
    revocation cannot be verified.
    """
    user_id, email = seeded_user
    token = create_access_token(user_id=user_id, email=email)

    # Simulate DB failure during the blacklist check
    fake_err = OperationalError("SELECT", {}, Exception("simulated DB outage"))
    with patch(
        "app.core.auth.is_jti_blacklisted",
        side_effect=fake_err,
    ):
        resp = probe_client.get(
            "/probe/me",
            headers={"Authorization": f"Bearer {token}"},
        )

    # Pre-fix this returned 200 (the bug). Post-fix : 503 (fail-closed).
    assert resp.status_code == 503, (
        f"Expected 503 fail-closed when blacklist DB raises ; got "
        f"{resp.status_code} body={resp.text!r}. If this is 200, the "
        f"B004 bare-except bug is still present (auth-bypass via "
        f"infra degradation)."
    )
    assert "blacklist" in resp.json().get("detail", "").lower()


def test_b004_jwt_decode_error_still_falls_through(probe_client, seeded_user):
    """
    Test 2 — preserve intended decode-fallback behavior.

    The original bare except was justified by the comment « If decode fails
    entirely, let decode_token handle it ». The fix MUST preserve this :
    a pyjwt.exceptions.PyJWTError raised by the UNVERIFIED decode at
    auth.py:46 must still pass through to the canonical `decode_token()`
    call at line 58 (which has its own ExpiredSignatureError /
    InvalidTokenError handling and returns None → 401).

    We test this by sending a structurally broken token : pyjwt.decode
    (even with verify_signature=False, verify_exp=False) raises
    DecodeError on garbage input. The downstream `decode_token` also
    returns None for the same garbage → 401 « Token invalide ou expiré ».
    """
    resp = probe_client.get(
        "/probe/me",
        headers={"Authorization": "Bearer not.a.valid.jwt.string"},
    )
    # Must reach decode_token path → 401 (not 503). If we get 503 here,
    # the fix is over-aggressive and catches PyJWTError as a DB error.
    assert resp.status_code == 401, (
        f"Expected 401 from decode_token path (garbage JWT) ; got "
        f"{resp.status_code}. If 503, the fix over-catches "
        f"PyJWTError as SQLAlchemyError."
    )


def test_b004_happy_path_valid_token_authenticates(probe_client, seeded_user):
    """
    Test 3 — happy path regression guard.

    Valid signed JWT, no DB error, JTI not in blacklist → 200 OK.
    Catches a fix that accidentally fails-closed on the happy path.
    """
    user_id, email = seeded_user
    token = create_access_token(user_id=user_id, email=email)

    resp = probe_client.get(
        "/probe/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["authenticated"] is True
    assert body["user_id"] == user_id


def test_b004_valid_revoked_token_returns_401(probe_client, seeded_user):
    """
    Test 4 — revocation enforcement still works post-fix.

    Valid signed JWT, JTI IS in blacklist (token revoked) → 401
    « Token révoqué ». Catches a fix that accidentally bypasses the
    blacklist check entirely.
    """
    from tests.conftest import TestingSessionLocal

    user_id, email = seeded_user
    token = create_access_token(user_id=user_id, email=email)

    # Extract the JTI from the just-issued token
    import jwt as pyjwt

    unverified = pyjwt.decode(
        token, options={"verify_exp": False, "verify_signature": False}
    )
    jti = unverified["jti"]

    # Insert into blacklist
    db = TestingSessionLocal()
    try:
        db.add(
            TokenBlacklist(
                jti=jti,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
                blacklisted_at=datetime.now(timezone.utc),
            )
        )
        db.commit()
    finally:
        db.close()

    resp = probe_client.get(
        "/probe/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 401
    assert resp.json()["detail"] == "Token révoqué"
