"""
Auth security models (login protection + password reset tokens).
"""

from uuid import uuid4
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer
from app.core.database import Base


class LoginSecurityStateModel(Base):
    """Track failed login attempts and temporary lockouts per email."""

    __tablename__ = "login_security_states"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    email = Column(String, unique=True, nullable=False, index=True)
    failed_attempts = Column(Integer, nullable=False, default=0)
    next_allowed_at = Column(DateTime, nullable=True)
    lockout_until = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PasswordResetTokenModel(Base):
    """Single-use password reset tokens."""

    __tablename__ = "password_reset_tokens"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=False, index=True)
    token_hash = Column(String, unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class EmailVerificationTokenModel(Base):
    """Single-use email verification tokens."""

    __tablename__ = "email_verification_tokens"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=False, index=True)
    token_hash = Column(String, unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
