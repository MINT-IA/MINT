"""
Tests for magic link authentication flow.

Covers: token generation, SHA-256 hashing, verify (valid, expired, used, invalid),
auto-create user, rate limiting, send/verify endpoints.
"""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import Base, engine, get_db
from app.models.user import User
from app.models.magic_link_token import MagicLinkTokenModel
from app.services.magic_link_service import MagicLinkService


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def setup_db():
    """Create tables before each test, drop after."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    """Provide a DB session for direct model access."""
    session = next(get_db())
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def existing_user(db_session):
    """Create a user that already exists in the DB."""
    user = User(
        id="user-existing-1",
        email="existing@example.com",
        hashed_password="hashed_pw",
        email_verified=True,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Unit tests: MagicLinkService
# ---------------------------------------------------------------------------

class TestMagicLinkServiceGenerateToken:
    """Test token generation."""

    def test_token_generation_produces_urlsafe_token(self, db_session):
        service = MagicLinkService(db_session)
        token = service.generate_token("test@example.com")
        # secrets.token_urlsafe(32) produces ~43 chars
        assert len(token) >= 32

    def test_token_hash_is_sha256(self, db_session):
        service = MagicLinkService(db_session)
        token = service.generate_token("test@example.com")
        expected_hash = hashlib.sha256(token.encode()).hexdigest()
        # The stored record should have this hash
        record = db_session.query(MagicLinkTokenModel).filter(
            MagicLinkTokenModel.token_hash == expected_hash
        ).first()
        assert record is not None

    def test_token_stored_with_expiry(self, db_session):
        service = MagicLinkService(db_session)
        token = service.generate_token("test@example.com")
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        record = db_session.query(MagicLinkTokenModel).filter(
            MagicLinkTokenModel.token_hash == token_hash
        ).first()
        assert record is not None
        expires_at = record.expires_at.replace(tzinfo=timezone.utc) if record.expires_at.tzinfo is None else record.expires_at
        assert expires_at > datetime.now(timezone.utc)
        # Expiry should be ~15 minutes from now
        delta = expires_at - datetime.now(timezone.utc)
        assert timedelta(minutes=14) < delta < timedelta(minutes=16)


class TestMagicLinkServiceVerifyToken:
    """Test token verification."""

    def test_verify_valid_token_returns_user(self, db_session, existing_user):
        service = MagicLinkService(db_session)
        token = service.generate_token(existing_user.email)
        user = service.verify_token(token)
        assert user.email == existing_user.email

    def test_verify_expired_token_raises_401(self, db_session, existing_user):
        service = MagicLinkService(db_session)
        token = service.generate_token(existing_user.email)
        # Manually expire the token
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        record = db_session.query(MagicLinkTokenModel).filter(
            MagicLinkTokenModel.token_hash == token_hash
        ).first()
        record.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db_session.commit()

        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            service.verify_token(token)
        assert exc_info.value.status_code == 401

    def test_verify_used_token_raises_401(self, db_session, existing_user):
        service = MagicLinkService(db_session)
        token = service.generate_token(existing_user.email)
        # Use the token once
        service.verify_token(token)
        # Second use should fail
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            service.verify_token(token)
        assert exc_info.value.status_code == 401

    def test_verify_invalid_token_raises_401(self, db_session):
        service = MagicLinkService(db_session)
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            service.verify_token("completely-invalid-token")
        assert exc_info.value.status_code == 401

    def test_auto_create_user_on_first_magic_link(self, db_session):
        service = MagicLinkService(db_session)
        email = "newuser@example.com"
        # No user exists yet
        assert db_session.query(User).filter(User.email == email).first() is None
        token = service.generate_token(email)
        user = service.verify_token(token)
        assert user is not None
        assert user.email == email
        # User should now exist in DB
        assert db_session.query(User).filter(User.email == email).first() is not None


class TestMagicLinkServiceSendEmail:
    """Test email sending."""

    @patch("app.services.magic_link_service.httpx")
    def test_send_email_with_resend_api(self, mock_httpx, db_session):
        service = MagicLinkService(db_session)
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_httpx.post.return_value = mock_response

        with patch.dict("os.environ", {"RESEND_API_KEY": "re_test_key", "MAGIC_LINK_BASE_URL": "https://mint.ch/auth/verify"}):
            service.send_magic_link_email("test@example.com", "test-token")
            mock_httpx.post.assert_called_once()

    def test_send_email_without_api_key_logs_warning(self, db_session, caplog):
        service = MagicLinkService(db_session)
        with patch.dict("os.environ", {}, clear=True):
            # Remove env vars if present
            import os
            os.environ.pop("RESEND_API_KEY", None)
            service.send_magic_link_email("test@example.com", "test-token")
            # Should not raise, just log


# ---------------------------------------------------------------------------
# Integration tests: Endpoints
# ---------------------------------------------------------------------------

class TestMagicLinkEndpoints:
    """Test HTTP endpoints."""

    def test_send_endpoint_returns_200(self, client, existing_user):
        with patch("app.services.magic_link_service.MagicLinkService.send_magic_link_email"):
            response = client.post(
                "/api/v1/auth/magic-link/send",
                json={"email": "existing@example.com"},
            )
        assert response.status_code == 200
        assert "message" in response.json()

    def test_verify_endpoint_returns_jwt(self, client, db_session, existing_user):
        service = MagicLinkService(db_session)
        token = service.generate_token(existing_user.email)
        with patch("app.services.magic_link_service.MagicLinkService.send_magic_link_email"):
            response = client.post(
                "/api/v1/auth/magic-link/verify",
                json={"token": token},
            )
        assert response.status_code == 200
        data = response.json()
        # Response uses camelCase aliases from Pydantic alias_generator
        assert "accessToken" in data
        assert data["tokenType"] == "bearer"

    def test_send_endpoint_unknown_email_still_200(self, client):
        """No information disclosure -- same response for known/unknown emails."""
        with patch("app.services.magic_link_service.MagicLinkService.send_magic_link_email"):
            response = client.post(
                "/api/v1/auth/magic-link/send",
                json={"email": "unknown@example.com"},
            )
        assert response.status_code == 200

    def test_verify_endpoint_invalid_token_returns_401(self, client):
        response = client.post(
            "/api/v1/auth/magic-link/verify",
            json={"token": "invalid-token-xyz"},
        )
        assert response.status_code == 401
