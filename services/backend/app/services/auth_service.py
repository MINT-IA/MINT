"""
Authentication service - handles password hashing and JWT token generation.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import jwt
from passlib.context import CryptContext
from app.core.config import settings

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

    Args:
        user_id: User's unique identifier

    Returns:
        JWT refresh token string (valid for 7 days)
    """
    expire = datetime.now(timezone.utc) + timedelta(days=7)
    payload = {
        "user_id": user_id,
        "type": "refresh",
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
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
