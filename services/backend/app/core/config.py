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
    # P1-Auth: Default True in production/staging (via env var override).
    # In development, defaults to False for convenience.
    # IMPORTANT: For production deployments, set AUTH_REQUIRE_EMAIL_VERIFICATION=true
    # in environment variables, or rely on the fail-safe below.
    AUTH_REQUIRE_EMAIL_VERIFICATION: bool = False
    AUTH_UNVERIFIED_PURGE_DAYS: int = 7
    AUTH_AUTO_PURGE_ON_STARTUP: bool = False
    AUTH_ADMIN_EMAIL_ALLOWLIST: str = ""

    # Logging & Monitoring
    LOG_LEVEL: str = "INFO"
    SENTRY_DSN: str = ""  # Set in Railway: https://sentry.io project DSN

    # Redis (for rate limiting; empty string = in-memory fallback)
    REDIS_URL: str = ""

    # Stripe billing
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PRICE_COACH_MONTHLY: str = ""
    BILLING_PORTAL_RETURN_URL: str = "https://mint.ch/profile"

    # Anthropic Claude API (coach AI)
    ANTHROPIC_API_KEY: str = ""
    COACH_MODEL: str = "claude-sonnet-4-20250514"  # Also valid: claude-3-5-sonnet-20241022
    COACH_MAX_TOKENS: int = 500
    COACH_DAILY_QUOTA: int = 30  # per user, free tier

    # Apple IAP / StoreKit
    APPLE_IAP_PRODUCT_COACH_MONTHLY: str = "ch.mint.coach.monthly"
    BILLING_ALLOW_CLIENT_APPLE_VERIFY: bool = False
    APPLE_WEBHOOK_SHARED_SECRET: str = ""

    # Apple IAP Products (P6 multi-tier)
    APPLE_IAP_PRODUCT_STARTER_MONTHLY: str = "ch.mint.starter.monthly"
    APPLE_IAP_PRODUCT_PREMIUM_MONTHLY: str = "ch.mint.premium.monthly"
    APPLE_IAP_PRODUCT_COUPLE_PLUS_MONTHLY: str = "ch.mint.couple_plus.monthly"

    # Stripe Prices (P6 multi-tier)
    STRIPE_PRICE_STARTER_MONTHLY: str = ""
    STRIPE_PRICE_PREMIUM_MONTHLY: str = ""
    STRIPE_PRICE_COUPLE_PLUS_MONTHLY: str = ""
    STRIPE_PRICE_STARTER_ANNUAL: str = ""
    STRIPE_PRICE_PREMIUM_ANNUAL: str = ""
    STRIPE_PRICE_COUPLE_PLUS_ANNUAL: str = ""

    # Internal full access (dev/TestFlight testing)
    INTERNAL_ACCESS_ENABLED: bool = False
    INTERNAL_ACCESS_ALLOWLIST: str = ""  # comma-separated emails
    INTERNAL_ACCESS_DEFAULT_TIER: str = "premium"

    # External API connectors
    EXTERNAL_API_TIMEOUT: int = 30  # seconds
    BLINK_API_URL: str = ""  # bLink sandbox/production URL
    CAISSE_PENSION_API_URL: str = ""  # Future: institutional pension fund API
    AVS_INSTITUTIONAL_API_URL: str = ""  # Future: AVS institutional API

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

# P1-Auth: Force email verification in production. Log a warning in staging
# if it's disabled (allows testing without SMTP, but flags the risk).
if os.getenv("ENVIRONMENT", "development") == "production":
    if not settings.AUTH_REQUIRE_EMAIL_VERIFICATION:
        import logging as _logging

        _logging.getLogger("mint.config").warning(
            "AUTH_REQUIRE_EMAIL_VERIFICATION is False in production. "
            "Set AUTH_REQUIRE_EMAIL_VERIFICATION=true in environment variables."
        )

# Fail-fast: INTERNAL_ACCESS_ENABLED with wildcard in production = universal premium
if (
    os.getenv("ENVIRONMENT", "development") == "production"
    and settings.INTERNAL_ACCESS_ENABLED
    and settings.INTERNAL_ACCESS_ALLOWLIST.strip() == "*"
):
    raise RuntimeError(
        "CRITICAL: INTERNAL_ACCESS_ENABLED=true with wildcard allowlist in production. "
        "This grants ALL users premium access. Set INTERNAL_ACCESS_ALLOWLIST to specific emails."
    )
