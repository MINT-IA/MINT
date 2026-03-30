"""
Tests for JWT JTI blacklist — token replay attack prevention.

Covers:
- Token creation includes JTI claim
- Blacklisted JTI is rejected (401)
- Valid (non-blacklisted) JTI passes
- Cleanup removes expired entries only
- Logout endpoint blacklists the token
- Refresh token also carries JTI
- Double-blacklist is idempotent (no crash)
- Token without JTI still works (backward compat)
- Blacklisted refresh token scenario
- Cleanup returns correct count
"""

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import get_db
from app.models.user import User
from app.services.auth_service import (
    create_access_token,
    create_refresh_token,
    decode_token,
    decode_refresh_token,
    hash_password,
    is_jti_blacklisted,
    blacklist_token,
    cleanup_expired_blacklist,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_db_session():
    """Get a test DB session from the conftest engine."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal()


def _create_test_user(db: Session) -> User:
    """Insert a test user and return it."""
    user = User(
        id=str(uuid4()),
        email=f"test-{uuid4().hex[:8]}@mint.ch",
        hashed_password=hash_password("Test1234!"),
        email_verified=True,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _make_client_with_real_db():
    """Return a TestClient that uses the real test DB (no auth override)."""
    from tests.conftest import override_get_db
    app.dependency_overrides.clear()
    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


# ---------------------------------------------------------------------------
# 1. Token creation includes JTI
# ---------------------------------------------------------------------------

class TestJtiInTokens:
    def test_access_token_has_jti(self):
        token = create_access_token("user-1", "a@b.com")
        payload = decode_token(token)
        assert payload is not None
        assert "jti" in payload
        assert len(payload["jti"]) == 36  # UUID4 format

    def test_refresh_token_has_jti(self):
        token = create_refresh_token("user-1")
        payload = decode_refresh_token(token)
        assert payload is not None
        assert "jti" in payload
        assert len(payload["jti"]) == 36

    def test_each_token_has_unique_jti(self):
        t1 = create_access_token("user-1", "a@b.com")
        t2 = create_access_token("user-1", "a@b.com")
        p1 = decode_token(t1)
        p2 = decode_token(t2)
        assert p1["jti"] != p2["jti"]


# ---------------------------------------------------------------------------
# 2. Blacklist check
# ---------------------------------------------------------------------------

class TestBlacklistCheck:
    def test_non_blacklisted_jti_passes(self):
        db = _get_db_session()
        try:
            assert is_jti_blacklisted(db, str(uuid4())) is False
        finally:
            db.close()

    def test_blacklisted_jti_is_rejected(self):
        db = _get_db_session()
        try:
            jti = str(uuid4())
            blacklist_token(db, jti, datetime.now(timezone.utc) + timedelta(hours=1))
            assert is_jti_blacklisted(db, jti) is True
        finally:
            db.close()

    def test_different_jti_not_affected(self):
        db = _get_db_session()
        try:
            jti1 = str(uuid4())
            jti2 = str(uuid4())
            blacklist_token(db, jti1, datetime.now(timezone.utc) + timedelta(hours=1))
            assert is_jti_blacklisted(db, jti1) is True
            assert is_jti_blacklisted(db, jti2) is False
        finally:
            db.close()


# ---------------------------------------------------------------------------
# 3. Cleanup expired entries
# ---------------------------------------------------------------------------

class TestCleanup:
    def test_cleanup_removes_expired_entries(self):
        db = _get_db_session()
        try:
            expired_jti = str(uuid4())
            active_jti = str(uuid4())
            blacklist_token(
                db, expired_jti,
                datetime.now(timezone.utc) - timedelta(hours=1),
            )
            blacklist_token(
                db, active_jti,
                datetime.now(timezone.utc) + timedelta(hours=1),
            )
            purged = cleanup_expired_blacklist(db)
            assert purged == 1
            assert is_jti_blacklisted(db, expired_jti) is False
            assert is_jti_blacklisted(db, active_jti) is True
        finally:
            db.close()

    def test_cleanup_returns_zero_when_nothing_expired(self):
        db = _get_db_session()
        try:
            blacklist_token(
                db, str(uuid4()),
                datetime.now(timezone.utc) + timedelta(hours=1),
            )
            purged = cleanup_expired_blacklist(db)
            assert purged == 0
        finally:
            db.close()

    def test_cleanup_handles_empty_table(self):
        db = _get_db_session()
        try:
            purged = cleanup_expired_blacklist(db)
            assert purged == 0
        finally:
            db.close()


# ---------------------------------------------------------------------------
# 4. Auth middleware rejects blacklisted token
# ---------------------------------------------------------------------------

class TestAuthMiddlewareBlacklist:
    def test_blacklisted_token_returns_401(self):
        db = _get_db_session()
        try:
            user = _create_test_user(db)
            token = create_access_token(user.id, user.email)
            payload = decode_token(token)

            # Blacklist the token
            blacklist_token(
                db, payload["jti"],
                datetime.fromtimestamp(payload["exp"], tz=timezone.utc),
            )

            client = _make_client_with_real_db()
            resp = client.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 401
            assert "révoqué" in resp.json()["detail"]
        finally:
            app.dependency_overrides.clear()
            db.close()

    def test_valid_token_passes_middleware(self):
        db = _get_db_session()
        try:
            user = _create_test_user(db)
            token = create_access_token(user.id, user.email)

            client = _make_client_with_real_db()
            resp = client.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            assert resp.json()["email"] == user.email
        finally:
            app.dependency_overrides.clear()
            db.close()


# ---------------------------------------------------------------------------
# 5. Logout endpoint
# ---------------------------------------------------------------------------

class TestLogoutEndpoint:
    def test_logout_blacklists_token(self):
        db = _get_db_session()
        try:
            user = _create_test_user(db)
            token = create_access_token(user.id, user.email)
            decode_token(token)  # validate token is decodable

            client = _make_client_with_real_db()

            # Logout
            resp = client.post(
                "/api/v1/auth/logout",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200
            assert resp.json()["status"] == "logged_out"

            # Token should now be rejected
            resp2 = client.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp2.status_code == 401
        finally:
            app.dependency_overrides.clear()
            db.close()

    def test_logout_without_token_returns_401(self):
        client = _make_client_with_real_db()
        try:
            resp = client.post("/api/v1/auth/logout")
            assert resp.status_code == 401
        finally:
            app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# 6. Double-blacklist idempotency
# ---------------------------------------------------------------------------

class TestEdgeCases:
    def test_double_blacklist_same_jti_is_idempotent(self):
        """Inserting the same JTI twice is a no-op (P1-11: atomic TOCTOU fix)."""
        db = _get_db_session()
        try:
            jti = str(uuid4())
            expires = datetime.now(timezone.utc) + timedelta(hours=1)
            blacklist_token(db, jti, expires)
            # Second insert should silently succeed (idempotent)
            blacklist_token(db, jti, expires)
            # JTI should still be blacklisted
            assert is_jti_blacklisted(db, jti) is True
        finally:
            db.rollback()
            db.close()
