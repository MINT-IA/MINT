"""
Authentication endpoints - register, login, and user info.
"""

from uuid import uuid4
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends, Request, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.analytics_event import AnalyticsEvent
from app.models.profile_model import ProfileModel
from app.models.session_model import SessionModel
from app.models.user import User
from app.schemas.auth import (
    UserRegister,
    UserLogin,
    TokenResponse,
    UserResponse,
    RefreshTokenRequest,
    DeleteAccountResponse,
)
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
)

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register_user(
    request: Request,
    user_data: UserRegister,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """
    Register a new user and return JWT token.

    Args:
        user_data: User registration data (email, password, display_name)
        db: Database session

    Returns:
        TokenResponse with access token and user info

    Raises:
        HTTPException: If email already exists (409)
    """
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un utilisateur avec cet email existe déjà"
        )

    # Create new user
    new_user = User(
        id=str(uuid4()),
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        display_name=user_data.display_name,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Generate tokens
    token = create_access_token(new_user.id, new_user.email)
    refresh = create_refresh_token(new_user.id)

    return TokenResponse(
        access_token=token,
        refresh_token=refresh,
        token_type="bearer",
        user_id=new_user.id,
        email=new_user.email,
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
def login_user(
    request: Request,
    login_data: UserLogin,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """
    Authenticate user and return JWT token.

    Args:
        login_data: User login credentials (email, password)
        db: Database session

    Returns:
        TokenResponse with access token and user info

    Raises:
        HTTPException: If credentials are invalid (401)
    """
    # Find user by email
    user = db.query(User).filter(User.email == login_data.email).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    # Generate tokens
    token = create_access_token(user.id, user.email)
    refresh = create_refresh_token(user.id)

    return TokenResponse(
        access_token=token,
        refresh_token=refresh,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
    )


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("30/minute")
def refresh_access_token(
    request: Request,
    body: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    """
    Refresh an access token using a refresh token.

    Expects JSON body: { "refresh_token": "..." }
    Returns a new access token + new refresh token (rotation).
    """
    refresh_token_value = body.refresh_token

    payload = decode_refresh_token(refresh_token_value)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide ou expiré",
        )

    user = db.query(User).filter(User.id == payload["user_id"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur non trouvé",
        )

    # Rotate: issue new access + refresh tokens
    new_access = create_access_token(user.id, user.email)
    new_refresh = create_refresh_token(user.id)

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
    )


@router.get("/me", response_model=UserResponse)
def get_current_user_info(
    current_user: User = Depends(require_current_user),
) -> UserResponse:
    """
    Get current authenticated user information.

    Args:
        current_user: Authenticated user from JWT token

    Returns:
        UserResponse with user details
    """
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        created_at=current_user.created_at,
    )


@router.delete("/account", response_model=DeleteAccountResponse)
def delete_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> DeleteAccountResponse:
    """
    Delete authenticated account and purge linked user data.

    Compliance intent:
    - Remove user credentials and user-linked financial data.
    - Keep aggregate analytics rows by anonymizing user_id.
    """
    user_id = current_user.id

    profiles = db.query(ProfileModel).filter(ProfileModel.user_id == user_id).all()
    profile_ids = [p.id for p in profiles]
    deleted_profiles = len(profile_ids)
    deleted_sessions = 0
    if profile_ids:
        deleted_sessions = (
            db.query(SessionModel)
            .filter(SessionModel.profile_id.in_(profile_ids))
            .count()
        )

    anonymized_analytics_events = (
        db.query(AnalyticsEvent)
        .filter(AnalyticsEvent.user_id == user_id)
        .update({AnalyticsEvent.user_id: None}, synchronize_session=False)
    )

    db.delete(current_user)
    db.commit()

    return DeleteAccountResponse(
        status="deleted",
        deleted_user_id=user_id,
        deleted_profiles=deleted_profiles,
        deleted_sessions=deleted_sessions,
        anonymized_analytics_events=anonymized_analytics_events,
    )
