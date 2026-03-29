"""
Authentication schemas for user registration, login, and tokens.
"""

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


class UserRegister(BaseModel):
    """Schema for user registration."""
    email: EmailStr
    password: str
    display_name: Optional[str] = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Le mot de passe doit contenir au moins 8 caractères')
        return v


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh request."""
    refresh_token: str


class PasswordResetRequest(BaseModel):
    """Schema for password reset request."""
    email: EmailStr


class PasswordResetConfirmRequest(BaseModel):
    """Schema for password reset confirmation."""
    token: str
    new_password: str

    @field_validator('new_password')
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Le mot de passe doit contenir au moins 8 caractères')
        return v


class PasswordResetRequestResponse(BaseModel):
    """Schema for password reset request response."""
    status: str
    debug_token: Optional[str] = None


class PasswordResetConfirmResponse(BaseModel):
    """Schema for password reset confirm response."""
    status: str


class EmailVerificationRequest(BaseModel):
    """Schema for email verification request."""
    email: EmailStr


class EmailVerificationConfirmRequest(BaseModel):
    """Schema for email verification confirmation."""
    token: str


class EmailVerificationRequestResponse(BaseModel):
    """Schema for email verification request response."""
    status: str
    debug_token: Optional[str] = None


class EmailVerificationConfirmResponse(BaseModel):
    """Schema for email verification confirm response."""
    status: str


class DeleteAccountResponse(BaseModel):
    """Schema for account deletion response."""
    status: str
    deleted_user_id: str
    deleted_profiles: int
    deleted_sessions: int
    anonymized_analytics_events: int


class AuthAdminObservabilityResponse(BaseModel):
    """Schema for auth admin observability snapshot."""
    users_total: int
    users_verified: int
    users_unverified: int
    users_unverified_older_than_ttl: int
    login_states_tracked: int
    login_states_locked_now: int
    password_reset_tokens_active: int
    email_verification_tokens_active: int
    subscriptions_total: int
    subscriptions_active_like: int


class AuthAdminPurgeUnverifiedRequest(BaseModel):
    """Schema for purge request."""
    older_than_days: Optional[int] = None
    dry_run: bool = True


class AuthAdminPurgeUnverifiedResponse(BaseModel):
    """Schema for purge response."""
    dry_run: bool
    older_than_days: int
    candidates: int
    deleted_users: int
    anonymized_analytics_events: int


class AuthAdminOnboardingQualityResponse(BaseModel):
    """Schema for onboarding quality snapshot."""
    days: int
    sessions_started: int
    sessions_completed: int
    completion_rate_pct: float
    step1_sessions: int
    step2_sessions: int
    step3_sessions: int
    step4_sessions: int
    step1_to_2_pct: float
    step2_to_3_pct: float
    step3_to_4_pct: float
    avg_completion_seconds: float
    avg_step_duration_seconds: float
    quality_score: float


class AuthAdminOnboardingCohortRow(BaseModel):
    """Schema for a single onboarding quality cohort row."""
    cohort_key: str
    variant: str
    platform: str
    sessions_started: int
    sessions_completed: int
    completion_rate_pct: float
    avg_completion_seconds: float
    avg_step_duration_seconds: float
    quality_score: float


class AuthAdminOnboardingCohortsResponse(BaseModel):
    """Schema for onboarding quality cohort breakdown."""
    days: int
    total_sessions_started: int
    cohorts: list[AuthAdminOnboardingCohortRow]


class LogoutResponse(BaseModel):
    """Schema for logout response."""
    status: str


class TokenResponse(BaseModel):
    """Schema for JWT token response."""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    user_id: str
    email: str
    email_verified: bool = False


class RegisterResponse(BaseModel):
    """Schema for registration response (supports verify-before-login mode)."""
    status: Literal["registered", "verification_required"] = "registered"
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_type: Optional[str] = None
    user_id: str
    email: str
    email_verified: bool = False
    requires_email_verification: bool = False


class UserResponse(BaseModel):
    """Schema for user information response."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    email_verified: bool
    display_name: Optional[str]
    created_at: datetime
