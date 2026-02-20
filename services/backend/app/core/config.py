import os

from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(case_sensitive=True)

    PROJECT_NAME: str = "Mint API"
    API_V1_STR: str = "/api/v1"

    # Environment
    ENVIRONMENT: str = "development"

    # Database settings
    DATABASE_URL: str = "sqlite:///./mint.db"

    # JWT settings — env var JWT_SECRET_KEY required in production
    JWT_SECRET_KEY: str = "mint-dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_HOURS: int = 24
    AUTH_REQUIRE_EMAIL_VERIFICATION: bool = False
    AUTH_UNVERIFIED_PURGE_DAYS: int = 7
    AUTH_AUTO_PURGE_ON_STARTUP: bool = False

    # Logging
    LOG_LEVEL: str = "INFO"

    # Redis (for rate limiting; empty string = in-memory fallback)
    REDIS_URL: str = ""

    # Stripe billing
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PRICE_COACH_MONTHLY: str = ""
    BILLING_PORTAL_RETURN_URL: str = "https://mint.ch/profile"

    # Apple IAP / StoreKit
    APPLE_IAP_PRODUCT_COACH_MONTHLY: str = "ch.mint.coach.monthly"

    # Transactional email (SMTP)
    EMAIL_SEND_ENABLED: bool = False
    EMAIL_FROM: str = "no-reply@mint.ch"
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    FRONTEND_BASE_URL: str = "https://app.mint.ch"


settings = Settings()

# Fail-fast: reject hardcoded secret in production
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.JWT_SECRET_KEY == "mint-dev-secret-change-in-production"
):
    raise RuntimeError(
        "CRITICAL: JWT_SECRET_KEY must be set via environment variable in production. "
        "Do not use the default dev secret."
    )
