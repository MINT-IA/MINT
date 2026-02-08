"""
Authentication endpoints - register, login, and user info.
"""

from uuid import uuid4
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import require_current_user
from app.models.user import User
from app.schemas.auth import UserRegister, UserLogin, TokenResponse, UserResponse
from app.services.auth_service import hash_password, verify_password, create_access_token

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register_user(
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
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Generate token
    token = create_access_token(new_user.id, new_user.email)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=new_user.id,
        email=new_user.email,
    )


@router.post("/login", response_model=TokenResponse)
def login_user(
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

    # Generate token
    token = create_access_token(user.id, user.email)

    return TokenResponse(
        access_token=token,
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
