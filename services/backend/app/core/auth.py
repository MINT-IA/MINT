"""
Authentication dependency for FastAPI endpoints.
Extracts and validates JWT tokens from requests.
"""

from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User
from app.services.auth_service import decode_token

security = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """
    Extract and validate JWT token, return user.
    Returns None if no token provided (for backward compatibility).

    Args:
        credentials: HTTP Bearer token from request header
        db: Database session

    Returns:
        User object if authenticated, None if no auth provided

    Raises:
        HTTPException: If token is invalid or user not found
    """
    # If no credentials provided, return None (anonymous mode)
    if credentials is None:
        return None

    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide ou expiré"
        )

    user = db.query(User).filter(User.id == payload["user_id"]).first()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur non trouvé"
        )

    return user


def require_current_user(
    user: Optional[User] = Depends(get_current_user),
) -> User:
    """
    Require authentication - raises 401 if no user authenticated.

    Args:
        user: User from get_current_user dependency

    Returns:
        User object

    Raises:
        HTTPException: If no user authenticated
    """
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication requise"
        )
    return user
