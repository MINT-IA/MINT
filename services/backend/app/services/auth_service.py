"""
Authentication service - handles password hashing and JWT token generation.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, Set
import jwt
from passlib.context import CryptContext
from app.core.config import settings

logger = logging.getLogger(__name__)

# V5-8b: In-memory set of used refresh token JTIs.
# TODO: Replace with DB table or Redis for production persistence.
_used_refresh_jtis: Set[str] = set()

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """
    Hash a plain password using bcrypt.

    Args:
        password: Plain text password

    Returns:
        Hashed password string
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain password against a hashed password.

    Args:
        plain_password: Plain text password to verify
        hashed_password: Hashed password to check against

    Returns:
        True if password matches, False otherwise
    """
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: str, email: str) -> str:
    """
    Create a short-lived JWT access token for a user.

    Args:
        user_id: User's unique identifier
        email: User's email address

    Returns:
        JWT token string (valid for JWT_EXPIRY_HOURS)
    """
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.JWT_EXPIRY_HOURS)
    payload = {
        "user_id": user_id,
        "email": email,
        "type": "access",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    """
    Create a long-lived refresh token for token rotation.

    V5-8b audit fix: added jti (JWT ID) claim for replay detection,
    and iat (issued-at) for age verification.

    Args:
        user_id: User's unique identifier

    Returns:
        JWT refresh token string (valid for 7 days)
    """
    expire = datetime.now(timezone.utc) + timedelta(days=7)
    payload = {
        "user_id": user_id,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode and verify a JWT access token.

    Args:
        token: JWT token string

    Returns:
        Decoded token payload if valid access token, None otherwise.
        Returns None if the token is a refresh token (type != "access").
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        # Reject non-access tokens (e.g. refresh tokens used as access tokens)
        if payload.get("type") != "access":
            return None
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def decode_refresh_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode and verify a refresh token.

    V5-8b audit fix: checks jti (JWT ID) for replay detection.
    If a jti has already been used, the token is rejected and a warning
    is logged (potential token replay attack).

    Args:
        token: JWT refresh token string

    Returns:
        Decoded payload if valid refresh token, None otherwise
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        if payload.get("type") != "refresh":
            return None

        # V5-8b: Check jti for replay detection
        jti = payload.get("jti")
        if jti:
            if jti in _used_refresh_jtis:
                logger.warning(
                    "V5-8b: Refresh token reuse detected (jti=%s, user=%s). "
                    "Possible token replay attack.",
                    jti,
                    payload.get("user_id"),
                )
                return None
            _used_refresh_jtis.add(jti)
            # TODO: Replace in-memory set with DB/Redis for production.
            # Prune old entries periodically to prevent unbounded growth.

        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
