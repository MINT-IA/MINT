"""
Authentication endpoints - register, login, and user info.
"""

from uuid import uuid4
from datetime import datetime, timezone, date, timedelta
from typing import Optional
import os
import logging
import csv
import io
from fastapi import APIRouter, HTTPException, Depends, Request, status
from fastapi import Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import require_current_user
from app.core.config import settings
from app.core.rate_limit import limiter
from app.models.analytics_event import AnalyticsEvent
from app.models.profile_model import ProfileModel
from app.models.session_model import SessionModel
from app.models.user import User
from app.models.auth_security import (
    LoginSecurityStateModel,
    PasswordResetTokenModel,
    EmailVerificationTokenModel,
)
from app.models.billing import (
    SubscriptionModel,
    EntitlementModel,
    BillingTransactionModel,
)
from app.schemas.auth import (
    UserRegister,
    UserLogin,
    RegisterResponse,
    TokenResponse,
    UserResponse,
    RefreshTokenRequest,
    LogoutResponse,
    EmailVerificationRequest,
    EmailVerificationConfirmRequest,
    EmailVerificationRequestResponse,
    EmailVerificationConfirmResponse,
    PasswordResetRequest,
    PasswordResetConfirmRequest,
    PasswordResetRequestResponse,
    PasswordResetConfirmResponse,
    DeleteAccountResponse,
    AuthAdminObservabilityResponse,
    AuthAdminPurgeUnverifiedRequest,
    AuthAdminPurgeUnverifiedResponse,
    AuthAdminOnboardingQualityResponse,
    AuthAdminOnboardingCohortsResponse,
)
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    decode_token,
    blacklist_token,
)
from app.services.audit_service import log_audit_event as _raw_log_audit_event
from app.services.auth_security_service import (
    get_login_block_seconds,
    record_failed_login,
    clear_failed_logins,
    issue_password_reset_token,
    consume_password_reset_token,
    issue_email_verification_token,
    consume_email_verification_token,
)
from app.services.email_service import (
    send_email_verification_email,
    send_password_reset_email,
)
from app.services.auth_admin_service import (
    build_auth_observability_snapshot,
    purge_unverified_users,
    build_auth_billing_cohort_rows,
    build_onboarding_quality_snapshot,
    build_onboarding_quality_cohorts,
)

router = APIRouter()
logger = logging.getLogger(__name__)


def log_audit_event(*args, **kwargs) -> None:
    """
    Best-effort audit logging.

    Auth endpoints must not fail hard if the audit table or migration is not
    available in a given environment.
    """
    try:
        _raw_log_audit_event(*args, **kwargs)
    except Exception as exc:  # pragma: no cover - defensive runtime guard
        logger.warning("Audit logging skipped due to runtime error: %s", exc)


def _request_ip(request: Request) -> Optional[str]:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


def _email_verification_required() -> bool:
    raw = os.getenv("AUTH_REQUIRE_EMAIL_VERIFICATION")
    if raw is not None:
        return raw.strip().lower() in {"1", "true", "yes", "on"}
    return bool(settings.AUTH_REQUIRE_EMAIL_VERIFICATION)


def _require_admin_user(user: User) -> None:
    allowlist_raw = os.getenv("AUTH_ADMIN_EMAIL_ALLOWLIST")
    if allowlist_raw is None:
        allowlist_raw = settings.AUTH_ADMIN_EMAIL_ALLOWLIST
    allowlist_raw = allowlist_raw.strip()
    allowlist = {
        entry.strip().lower()
        for entry in allowlist_raw.split(",")
        if entry.strip()
    }
    email = (user.email or "").strip().lower()
    is_allowlisted = bool(email and allowlist and email in allowlist)
    if not is_allowlisted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    if not bool(user.email_verified):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access requires a verified email",
        )


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register_user(
    request: Request,
    user_data: UserRegister,
    db: Session = Depends(get_db),
) -> RegisterResponse:
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
        email_verified=False,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    # FIX-063: Handle concurrent registration with same email.
    from sqlalchemy.exc import IntegrityError as SAIntegrityError
    try:
        db.add(new_user)
        db.flush()  # trigger IntegrityError early if email exists
    except SAIntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un utilisateur avec cet email existe déjà",
        )
    verification_required = _email_verification_required()
    verification_token: Optional[str] = None
    verification_email_sent = False
    if verification_required:
        try:
            verification_token = issue_email_verification_token(db, new_user.id)
            verification_email_sent = send_email_verification_email(
                to_email=new_user.email,
                token=verification_token,
            )
        except Exception as exc:
            # Degrade gracefully: never block registration on email-verification
            # infrastructure issues (missing table/migration, SMTP, etc.).
            logger.warning(
                "Email verification bootstrap failed during register; "
                "continuing without mandatory verification: %s",
                exc,
            )
            verification_required = False
            verification_token = None
            verification_email_sent = False
    log_audit_event(
        db,
        event_type="auth.register",
        status="success",
        source="api",
        user_id=new_user.id,
        actor_email=new_user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    if verification_required:
        log_audit_event(
            db,
            event_type="auth.email_verification_request",
            status="success",
            source="api",
            user_id=new_user.id,
            actor_email=new_user.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={
                "reason": "post_register",
                "debug_token_issued": bool(verification_token),
                "email_sent": verification_email_sent,
            },
        )
    db.commit()
    db.refresh(new_user)

    if verification_required:
        return RegisterResponse(
            status="verification_required",
            user_id=new_user.id,
            email=new_user.email,
            email_verified=bool(new_user.email_verified),
            requires_email_verification=True,
        )

    # Generate tokens
    token = create_access_token(new_user.id, new_user.email)
    refresh = create_refresh_token(new_user.id)

    return RegisterResponse(
        status="registered",
        access_token=token,
        refresh_token=refresh,
        token_type="bearer",
        user_id=new_user.id,
        email=new_user.email,
        email_verified=bool(new_user.email_verified),
        requires_email_verification=False,
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
    block_seconds = get_login_block_seconds(db, login_data.email)
    if block_seconds > 0:
        log_audit_event(
            db,
            event_type="auth.login",
            status="blocked",
            source="api",
            actor_email=login_data.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"retry_after_seconds": block_seconds},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Trop de tentatives. Réessaie dans {block_seconds}s.",
        )

    # Find user by email
    user = db.query(User).filter(User.email == login_data.email).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        wait_seconds = record_failed_login(db, login_data.email)
        log_audit_event(
            db,
            event_type="auth.login",
            status="failed",
            source="api",
            user_id=user.id if user else None,
            actor_email=login_data.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={
                "reason": "invalid_credentials",
                "retry_after_seconds": wait_seconds,
            },
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )
    if _email_verification_required() and not bool(user.email_verified):
        log_audit_event(
            db,
            event_type="auth.login",
            status="blocked_unverified_email",
            source="api",
            user_id=user.id,
            actor_email=user.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "email_not_verified"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="E-mail non vérifié. Vérifie ton e-mail avant de te connecter.",
        )
    clear_failed_logins(db, login_data.email)

    # Generate tokens
    token = create_access_token(user.id, user.email)
    refresh = create_refresh_token(user.id)

    log_audit_event(
        db,
        event_type="auth.login",
        status="success",
        source="api",
        user_id=user.id,
        actor_email=user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    db.commit()

    return TokenResponse(
        access_token=token,
        refresh_token=refresh,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        email_verified=bool(user.email_verified),
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
        log_audit_event(
            db,
            event_type="auth.refresh",
            status="failed",
            source="api",
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "invalid_or_expired_refresh"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide ou expiré",
        )

    user = db.query(User).filter(User.id == payload["user_id"]).first()
    if not user:
        log_audit_event(
            db,
            event_type="auth.refresh",
            status="failed",
            source="api",
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "user_not_found"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur non trouvé",
        )

    # Rotate: issue new access + refresh tokens
    new_access = create_access_token(user.id, user.email)
    new_refresh = create_refresh_token(user.id)

    log_audit_event(
        db,
        event_type="auth.refresh",
        status="success",
        source="api",
        user_id=user.id,
        actor_email=user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    db.commit()

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        email_verified=bool(user.email_verified),
    )


_security_scheme = HTTPBearer(auto_error=False)


@router.post("/logout", response_model=LogoutResponse)
def logout(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(_security_scheme),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> LogoutResponse:
    """
    Logout by blacklisting the current token's JTI.

    The token will be rejected on subsequent requests until it naturally expires,
    at which point the blacklist entry is eligible for cleanup.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token requis",
        )

    payload = decode_token(credentials.credentials)
    if payload is None or "jti" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide",
        )

    expires_at = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
    blacklist_token(db, payload["jti"], expires_at)

    log_audit_event(
        db,
        event_type="auth.logout",
        status="success",
        source="api",
        user_id=current_user.id,
        actor_email=current_user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    db.commit()

    return LogoutResponse(status="logged_out")


@router.post("/password-reset/request", response_model=PasswordResetRequestResponse)
@limiter.limit("5/minute")
def request_password_reset(
    request: Request,
    body: PasswordResetRequest,
    db: Session = Depends(get_db),
) -> PasswordResetRequestResponse:
    """
    Request a password reset token.

    Always returns accepted to avoid account enumeration.
    """
    user = db.query(User).filter(User.email == body.email).first()
    debug_token = None
    if user:
        debug_token = issue_password_reset_token(db, user.id)
        reset_email_sent = send_password_reset_email(
            to_email=user.email,
            token=debug_token,
        )
        log_audit_event(
            db,
            event_type="auth.password_reset_request",
            status="success",
            source="api",
            user_id=user.id,
            actor_email=user.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"email_sent": reset_email_sent},
        )
    else:
        log_audit_event(
            db,
            event_type="auth.password_reset_request",
            status="accepted_unknown_email",
            source="api",
            actor_email=body.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
        )
    db.commit()
    is_testing = os.getenv("TESTING", "") == "1"
    return PasswordResetRequestResponse(
        status="accepted",
        debug_token=debug_token if is_testing else None,
    )


@router.post("/password-reset/confirm", response_model=PasswordResetConfirmResponse)
@limiter.limit("10/minute")
def confirm_password_reset(
    request: Request,
    body: PasswordResetConfirmRequest,
    db: Session = Depends(get_db),
) -> PasswordResetConfirmResponse:
    """
    Confirm password reset with one-time token.
    """
    user_id = consume_password_reset_token(db, body.token)
    if not user_id:
        log_audit_event(
            db,
            event_type="auth.password_reset_confirm",
            status="failed",
            source="api",
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "invalid_or_expired_token"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token invalide ou expiré",
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        log_audit_event(
            db,
            event_type="auth.password_reset_confirm",
            status="failed",
            source="api",
            user_id=user_id,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "user_not_found"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token invalide ou expiré",
        )

    user.hashed_password = hash_password(body.new_password)
    user.updated_at = datetime.now(timezone.utc)
    # FIX-049: Invalidate all existing tokens by setting password_changed_at.
    # Tokens issued before this timestamp are rejected by get_current_user().
    user.password_changed_at = datetime.now(timezone.utc)
    clear_failed_logins(db, user.email)
    log_audit_event(
        db,
        event_type="auth.password_reset_confirm",
        status="success",
        source="api",
        user_id=user.id,
        actor_email=user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    db.commit()
    return PasswordResetConfirmResponse(status="reset")


@router.post(
    "/email-verification/request", response_model=EmailVerificationRequestResponse
)
@limiter.limit("5/minute")
def request_email_verification(
    request: Request,
    body: EmailVerificationRequest,
    db: Session = Depends(get_db),
) -> EmailVerificationRequestResponse:
    """
    Request/resend email verification token.

    Always returns accepted to avoid account enumeration.
    """
    user = db.query(User).filter(User.email == body.email).first()
    debug_token = None
    if user and not bool(user.email_verified):
        debug_token = issue_email_verification_token(db, user.id)
        verification_email_sent = send_email_verification_email(
            to_email=user.email,
            token=debug_token,
        )
        log_audit_event(
            db,
            event_type="auth.email_verification_request",
            status="success",
            source="api",
            user_id=user.id,
            actor_email=user.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={
                "reason": "manual_request",
                "email_sent": verification_email_sent,
            },
        )
    elif user and bool(user.email_verified):
        log_audit_event(
            db,
            event_type="auth.email_verification_request",
            status="already_verified",
            source="api",
            user_id=user.id,
            actor_email=user.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
        )
    else:
        log_audit_event(
            db,
            event_type="auth.email_verification_request",
            status="accepted_unknown_email",
            source="api",
            actor_email=body.email,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
        )
    db.commit()
    is_testing = os.getenv("TESTING", "") == "1"
    return EmailVerificationRequestResponse(
        status="accepted",
        debug_token=debug_token if is_testing else None,
    )


@router.post(
    "/email-verification/confirm", response_model=EmailVerificationConfirmResponse
)
@limiter.limit("10/minute")
def confirm_email_verification(
    request: Request,
    body: EmailVerificationConfirmRequest,
    db: Session = Depends(get_db),
) -> EmailVerificationConfirmResponse:
    """
    Confirm email verification with one-time token.
    """
    user_id = consume_email_verification_token(db, body.token)
    if not user_id:
        log_audit_event(
            db,
            event_type="auth.email_verification_confirm",
            status="failed",
            source="api",
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "invalid_or_expired_token"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token invalide ou expiré",
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        log_audit_event(
            db,
            event_type="auth.email_verification_confirm",
            status="failed",
            source="api",
            user_id=user_id,
            ip_address=_request_ip(request),
            user_agent=request.headers.get("user-agent"),
            details={"reason": "user_not_found"},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token invalide ou expiré",
        )

    user.email_verified = True
    user.updated_at = datetime.now(timezone.utc)
    log_audit_event(
        db,
        event_type="auth.email_verification_confirm",
        status="success",
        source="api",
        user_id=user.id,
        actor_email=user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    db.commit()
    return EmailVerificationConfirmResponse(status="verified")


@router.get("/admin/observability", response_model=AuthAdminObservabilityResponse)
def auth_admin_observability(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AuthAdminObservabilityResponse:
    """
    Admin snapshot for auth/billing operational observability.
    """
    _require_admin_user(current_user)
    snapshot = build_auth_observability_snapshot(
        db,
        purge_days=settings.AUTH_UNVERIFIED_PURGE_DAYS,
    )
    return AuthAdminObservabilityResponse(**snapshot)


@router.post(
    "/admin/purge-unverified",
    response_model=AuthAdminPurgeUnverifiedResponse,
)
def auth_admin_purge_unverified(
    request: Request,
    body: AuthAdminPurgeUnverifiedRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AuthAdminPurgeUnverifiedResponse:
    """
    Admin purge for unverified accounts older than TTL.
    """
    _require_admin_user(current_user)
    days = (
        body.older_than_days
        if body.older_than_days is not None
        else settings.AUTH_UNVERIFIED_PURGE_DAYS
    )
    result = purge_unverified_users(
        db,
        older_than_days=days,
        dry_run=body.dry_run,
    )
    log_audit_event(
        db,
        event_type="auth.admin_purge_unverified",
        status="success",
        source="api",
        user_id=current_user.id,
        actor_email=current_user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
        details={
            "dry_run": result["dry_run"],
            "older_than_days": result["older_than_days"],
            "candidates": result["candidates"],
            "deleted_users": result["deleted_users"],
        },
    )
    db.commit()
    return AuthAdminPurgeUnverifiedResponse(**result)


@router.get("/admin/cohorts/export.csv")
def auth_admin_export_cohorts_csv(
    days: int = Query(default=30, ge=1, le=365),
    start_date: Optional[date] = Query(default=None),
    end_date: Optional[date] = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    """
    Export auth/billing cohort metrics in CSV format.
    """
    _require_admin_user(current_user)
    if start_date and end_date and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be <= end_date",
        )
    if start_date and not end_date:
        end_date = date.today()
    if end_date and not start_date:
        start_date = end_date - timedelta(days=days - 1)
    if not start_date or not end_date:
        end_date = date.today()
        start_date = end_date - timedelta(days=days - 1)

    rows = build_auth_billing_cohort_rows(
        db,
        start_date=start_date,
        end_date=end_date,
    )

    output = io.StringIO()
    writer = csv.DictWriter(
        output,
        fieldnames=[
            "date",
            "users_registered",
            "users_verified",
            "login_success",
            "login_failed",
            "login_blocked",
            "password_reset_requests",
            "email_verification_requests",
            "subscriptions_started",
            "billing_webhooks_received",
        ],
    )
    writer.writeheader()
    writer.writerows(rows)
    filename = f"mint_auth_billing_cohorts_{start_date.isoformat()}_{end_date.isoformat()}.csv"
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    "/admin/onboarding-quality",
    response_model=AuthAdminOnboardingQualityResponse,
)
def auth_admin_onboarding_quality(
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AuthAdminOnboardingQualityResponse:
    """
    Admin onboarding quality score computed from analytics events.
    """
    _require_admin_user(current_user)
    snapshot = build_onboarding_quality_snapshot(db, days=days)
    return AuthAdminOnboardingQualityResponse(**snapshot)


@router.get(
    "/admin/onboarding-quality/cohorts",
    response_model=AuthAdminOnboardingCohortsResponse,
)
def auth_admin_onboarding_quality_cohorts(
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AuthAdminOnboardingCohortsResponse:
    """
    Admin onboarding quality breakdown by cohort (variant + platform).
    """
    _require_admin_user(current_user)
    snapshot = build_onboarding_quality_cohorts(db, days=days)
    return AuthAdminOnboardingCohortsResponse(**snapshot)


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
        email_verified=bool(current_user.email_verified),
        display_name=current_user.display_name,
        created_at=current_user.created_at,
    )


@router.delete("/account", response_model=DeleteAccountResponse)
def delete_account(
    request: Request,
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

    # Purge auth-security artifacts
    db.query(LoginSecurityStateModel).filter(
        LoginSecurityStateModel.email == current_user.email
    ).delete(synchronize_session=False)
    db.query(PasswordResetTokenModel).filter(
        PasswordResetTokenModel.user_id == user_id
    ).delete(synchronize_session=False)
    db.query(EmailVerificationTokenModel).filter(
        EmailVerificationTokenModel.user_id == user_id
    ).delete(synchronize_session=False)

    # Purge billing artifacts linked to the account
    sub_ids = [
        sub_id
        for (sub_id,) in db.query(SubscriptionModel.id)
        .filter(SubscriptionModel.user_id == user_id)
        .all()
    ]
    db.query(EntitlementModel).filter(
        EntitlementModel.user_id == user_id
    ).delete(synchronize_session=False)
    if sub_ids:
        db.query(BillingTransactionModel).filter(
            BillingTransactionModel.subscription_id.in_(sub_ids)
        ).delete(synchronize_session=False)
        db.query(SubscriptionModel).filter(
            SubscriptionModel.id.in_(sub_ids)
        ).delete(synchronize_session=False)
    log_audit_event(
        db,
        event_type="auth.account_delete",
        status="success",
        source="api",
        user_id=user_id,
        actor_email=current_user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
        details={
            "deleted_profiles": deleted_profiles,
            "deleted_sessions": deleted_sessions,
            "anonymized_analytics_events": anonymized_analytics_events,
        },
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
