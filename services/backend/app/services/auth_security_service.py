"""
Authentication security service (anti-bruteforce + password reset tokens).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from hashlib import sha256
from secrets import token_urlsafe
import math
from typing import Optional
from sqlalchemy.orm import Session

from app.models.auth_security import LoginSecurityStateModel, PasswordResetTokenModel
from app.models.auth_security import EmailVerificationTokenModel


MAX_FAILED_ATTEMPTS = 10
LOCKOUT_MINUTES = 15
DELAY_START_ATTEMPT = 5
MAX_BACKOFF_SECONDS = 8
RESET_TOKEN_TTL_MINUTES = 60
EMAIL_VERIFICATION_TOKEN_TTL_MINUTES = 24 * 60


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _get_or_create_security_state(db: Session, email: str) -> LoginSecurityStateModel:
    normalized = email.lower().strip()
    state = (
        db.query(LoginSecurityStateModel)
        .filter(LoginSecurityStateModel.email == normalized)
        .first()
    )
    if state:
        return state
    # FIX-061: Handle concurrent creation — catch IntegrityError from race.
    try:
        state = LoginSecurityStateModel(email=normalized, failed_attempts=0)
        db.add(state)
        db.flush()
        return state
    except Exception:  # pragma: no cover — race condition path
        db.rollback()  # pragma: no cover
        return (  # pragma: no cover
            db.query(LoginSecurityStateModel)
            .filter(LoginSecurityStateModel.email == normalized)
            .first()
        ) or LoginSecurityStateModel(email=normalized, failed_attempts=0)


def get_login_block_seconds(db: Session, email: str) -> int:
    """
    Return remaining block delay in seconds (0 means login is currently allowed).
    """
    state = _get_or_create_security_state(db, email)
    now = _now()
    if state.lockout_until and state.lockout_until > now:
        return max(1, int(math.ceil((state.lockout_until - now).total_seconds())))
    if state.next_allowed_at and state.next_allowed_at > now:
        return max(1, int(math.ceil((state.next_allowed_at - now).total_seconds())))
    return 0


def record_failed_login(db: Session, email: str) -> int:
    """
    Record failed login attempt and return the wait time before next attempt.
    """
    state = _get_or_create_security_state(db, email)
    now = _now()
    state.failed_attempts = int(state.failed_attempts or 0) + 1

    wait_seconds = 0
    if state.failed_attempts >= MAX_FAILED_ATTEMPTS:
        state.lockout_until = now + timedelta(minutes=LOCKOUT_MINUTES)
        state.next_allowed_at = state.lockout_until
        wait_seconds = LOCKOUT_MINUTES * 60
    elif state.failed_attempts >= DELAY_START_ATTEMPT:
        exponent = state.failed_attempts - DELAY_START_ATTEMPT
        wait_seconds = min(2**exponent, MAX_BACKOFF_SECONDS)
        state.next_allowed_at = now + timedelta(seconds=wait_seconds)
    else:
        state.next_allowed_at = None
        state.lockout_until = None

    db.flush()
    return wait_seconds


def clear_failed_logins(db: Session, email: str) -> None:
    """
    Reset anti-bruteforce counters after successful login.
    """
    state = _get_or_create_security_state(db, email)
    state.failed_attempts = 0
    state.next_allowed_at = None
    state.lockout_until = None
    db.flush()


def issue_password_reset_token(db: Session, user_id: str) -> str:
    """
    Create a single-use password reset token and return its plaintext value.
    """
    token = token_urlsafe(32)
    token_hash = sha256(token.encode("utf-8")).hexdigest()
    row = PasswordResetTokenModel(
        user_id=user_id,
        token_hash=token_hash,
        expires_at=_now() + timedelta(minutes=RESET_TOKEN_TTL_MINUTES),
    )
    db.add(row)
    db.flush()
    return token


def consume_password_reset_token(db: Session, token: str) -> Optional[str]:
    """
    Validate and consume a reset token. Returns user_id if valid, else None.
    """
    token_hash = sha256(token.encode("utf-8")).hexdigest()
    now = _now()
    row = (
        db.query(PasswordResetTokenModel)
        .filter(
            PasswordResetTokenModel.token_hash == token_hash,
            PasswordResetTokenModel.used_at.is_(None),
            PasswordResetTokenModel.expires_at >= now,
        )
        .first()
    )
    if not row:
        return None
    row.used_at = now
    db.flush()
    return row.user_id


def issue_email_verification_token(db: Session, user_id: str) -> str:
    """
    Create a single-use email verification token.
    """
    token = token_urlsafe(32)
    token_hash = sha256(token.encode("utf-8")).hexdigest()
    row = EmailVerificationTokenModel(
        user_id=user_id,
        token_hash=token_hash,
        expires_at=_now() + timedelta(minutes=EMAIL_VERIFICATION_TOKEN_TTL_MINUTES),
    )
    db.add(row)
    db.flush()
    return token


def consume_email_verification_token(db: Session, token: str) -> Optional[str]:
    """
    Validate and consume an email verification token. Returns user_id if valid.
    """
    token_hash = sha256(token.encode("utf-8")).hexdigest()
    now = _now()
    row = (
        db.query(EmailVerificationTokenModel)
        .filter(
            EmailVerificationTokenModel.token_hash == token_hash,
            EmailVerificationTokenModel.used_at.is_(None),
            EmailVerificationTokenModel.expires_at >= now,
        )
        .first()
    )
    if not row:
        return None
    row.used_at = now
    db.flush()
    return row.user_id
