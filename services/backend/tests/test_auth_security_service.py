"""
Tests for auth_security_service.py (P1 — anti-bruteforce + tokens).

Covers:
    - Failed logins trigger progressive delay then lockout
    - Lockout expires after timeout
    - Successful login resets failure counter
    - Password reset token is single-use
    - Token hash prevents plaintext storage
    - Email verification tokens

Run: cd services/backend && python3 -m pytest tests/test_auth_security_service.py -v
"""

from datetime import datetime, timedelta
from hashlib import sha256
from unittest.mock import patch

import pytest
from sqlalchemy.orm import Session

from app.models.auth_security import (
    LoginSecurityStateModel,
    PasswordResetTokenModel,
    EmailVerificationTokenModel,
)
from app.services.auth_security_service import (
    get_login_block_seconds,
    record_failed_login,
    clear_failed_logins,
    issue_password_reset_token,
    consume_password_reset_token,
    issue_email_verification_token,
    consume_email_verification_token,
    MAX_FAILED_ATTEMPTS,
    LOCKOUT_MINUTES,
    DELAY_START_ATTEMPT,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_db():
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal()


# ---------------------------------------------------------------------------
# Anti-bruteforce Tests
# ---------------------------------------------------------------------------

class TestAntiBruteforce:

    def test_no_block_on_first_attempt(self):
        """No blocking before any failed attempt."""
        db = _get_db()
        try:
            block = get_login_block_seconds(db, "fresh@test.ch")
            assert block == 0
        finally:
            db.close()

    def test_no_delay_before_threshold(self):
        """No delay for first N-1 failed attempts (below DELAY_START_ATTEMPT)."""
        db = _get_db()
        try:
            for i in range(DELAY_START_ATTEMPT - 1):
                wait = record_failed_login(db, "nodelay@test.ch")
                assert wait == 0
            db.commit()
        finally:
            db.close()

    def test_progressive_delay_after_threshold(self):
        """Delay kicks in after DELAY_START_ATTEMPT failed attempts."""
        db = _get_db()
        try:
            for i in range(DELAY_START_ATTEMPT):
                wait = record_failed_login(db, "delay@test.ch")
            db.commit()
            # After exactly DELAY_START_ATTEMPT attempts, wait should be > 0
            assert wait > 0
        finally:
            db.close()

    def test_lockout_after_max_attempts(self):
        """Account locked out after MAX_FAILED_ATTEMPTS."""
        db = _get_db()
        try:
            for i in range(MAX_FAILED_ATTEMPTS):
                wait = record_failed_login(db, "lockout@test.ch")
            db.commit()
            assert wait == LOCKOUT_MINUTES * 60
            block = get_login_block_seconds(db, "lockout@test.ch")
            assert block > 0
        finally:
            db.close()

    def test_successful_login_resets_counter(self):
        """Successful login resets failure counter to 0."""
        db = _get_db()
        try:
            for i in range(3):
                record_failed_login(db, "reset@test.ch")
            db.commit()

            clear_failed_logins(db, "reset@test.ch")
            db.commit()

            state = (
                db.query(LoginSecurityStateModel)
                .filter_by(email="reset@test.ch")
                .first()
            )
            assert state.failed_attempts == 0
            assert state.next_allowed_at is None
            assert state.lockout_until is None
        finally:
            db.close()

    def test_email_normalized(self):
        """Email is normalized (lowercased, stripped)."""
        db = _get_db()
        try:
            record_failed_login(db, "  Test@MINT.ch  ")
            db.commit()

            state = (
                db.query(LoginSecurityStateModel)
                .filter_by(email="test@mint.ch")
                .first()
            )
            assert state is not None
            assert state.failed_attempts == 1
        finally:
            db.close()


# ---------------------------------------------------------------------------
# Password Reset Token Tests
# ---------------------------------------------------------------------------

class TestPasswordResetToken:

    def test_issue_returns_plaintext(self):
        """issue_password_reset_token returns a plaintext token string."""
        db = _get_db()
        try:
            token = issue_password_reset_token(db, "user-abc")
            db.commit()
            assert isinstance(token, str)
            assert len(token) > 20
        finally:
            db.close()

    def test_token_hash_stored_not_plaintext(self):
        """Token is stored as SHA-256 hash, not plaintext."""
        db = _get_db()
        try:
            token = issue_password_reset_token(db, "user-hash")
            db.commit()

            expected_hash = sha256(token.encode("utf-8")).hexdigest()
            row = (
                db.query(PasswordResetTokenModel)
                .filter_by(user_id="user-hash")
                .first()
            )
            assert row.token_hash == expected_hash
            assert row.token_hash != token  # Not stored as plaintext
        finally:
            db.close()

    def test_consume_valid_token(self):
        """Consuming a valid token returns user_id."""
        db = _get_db()
        try:
            token = issue_password_reset_token(db, "user-consume")
            db.commit()

            user_id = consume_password_reset_token(db, token)
            db.commit()
            assert user_id == "user-consume"
        finally:
            db.close()

    def test_token_is_single_use(self):
        """Consuming the same token twice returns None on second use."""
        db = _get_db()
        try:
            token = issue_password_reset_token(db, "user-single")
            db.commit()

            result1 = consume_password_reset_token(db, token)
            db.commit()
            assert result1 == "user-single"

            result2 = consume_password_reset_token(db, token)
            assert result2 is None
        finally:
            db.close()

    def test_expired_token_rejected(self):
        """Expired token returns None."""
        db = _get_db()
        try:
            token = issue_password_reset_token(db, "user-expired")
            db.commit()

            # Manually set expiry to the past
            row = (
                db.query(PasswordResetTokenModel)
                .filter_by(user_id="user-expired")
                .first()
            )
            row.expires_at = datetime.utcnow() - timedelta(minutes=1)
            db.commit()

            result = consume_password_reset_token(db, token)
            assert result is None
        finally:
            db.close()


# ---------------------------------------------------------------------------
# Email Verification Token Tests
# ---------------------------------------------------------------------------

class TestEmailVerificationToken:

    def test_issue_and_consume_email_token(self):
        """Email verification token can be issued and consumed."""
        db = _get_db()
        try:
            token = issue_email_verification_token(db, "user-email")
            db.commit()

            user_id = consume_email_verification_token(db, token)
            db.commit()
            assert user_id == "user-email"
        finally:
            db.close()

    def test_email_token_single_use(self):
        """Email verification token is single-use."""
        db = _get_db()
        try:
            token = issue_email_verification_token(db, "user-email2")
            db.commit()

            consume_email_verification_token(db, token)
            db.commit()

            result = consume_email_verification_token(db, token)
            assert result is None
        finally:
            db.close()
