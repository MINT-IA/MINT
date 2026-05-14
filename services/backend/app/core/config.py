import os
from typing import Literal

from pydantic import ConfigDict, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(case_sensitive=True)

    PROJECT_NAME: str = "Mint API"
    API_V1_STR: str = "/api/v1"

    # Environment
    ENVIRONMENT: str = "development"

    # Database settings
    DATABASE_URL: str = "sqlite:///./mint.db"

    # ChromaDB persistence (Railway volume mount in prod; local relative path in dev)
    CHROMADB_PERSIST_DIR: str = "data/chromadb"

    # OpenAI embeddings (optional — RAG degrades gracefully without it)
    OPENAI_API_KEY: str = ""

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
    # Hard cap so coach replies stay under ~120 words (Gate 0 P1 — long
    # responses were flooding the chat bubble). Sonnet at 350 tokens
    # produces 5-7 dense sentences of French — exactly what we want.
    # Override per-deployment via env if needed; never raise above 500
    # without re-running the length-cap E2E suite.
    COACH_MAX_TOKENS: int = 350
    COACH_DAILY_QUOTA: int = 30  # per user, free tier

    # Phase 91 dual-LLM (extractor + narrator) split kill-flag.
    # False = legacy single-LLM path (current production).
    # True  = dual-LLM path: extractor LLM captures facts before the
    #         narrator LLM delivers the user-facing reply.
    # Wave 0 (this commit): scaffolding only — no consumers yet. The flag
    # is wired in Wave 2 (coach_chat.py Step 1.5) and flipped per Stage 4
    # staging soak. See .planning/phases/91-mvp-extractor-v2/RESEARCH.md
    # §4 Stage 0 T0.2 + 91-CONTEXT.md decision D-12.
    COACH_DUAL_LLM_ENABLED: bool = False

    # Phase 93.5 — feature flag for skill-bundle compiler (CONTEXT D-15).
    # Default `false` in prod ; `true` in staging during Stage 3 eval
    # (Plan 93.5-04). Mirrors `COACH_DUAL_LLM_ENABLED` rollout pattern.
    # When `true`, `coach_chat._build_system_prompt_with_memory` routes via
    # `build_narrator_system_prompt_from_bundles` (compile_bundles → 6 named
    # bundle fragments + tool allowlist + citation allowlist) instead of
    # the legacy `_NARRATOR_BASE_SYSTEM_PROMPT` template.
    COACH_BUNDLE_COMPILER_ENABLED: bool = False

    # COACH_CITATION_GATE_ENABLED — Phase 94 (CONTEXT D-19/D-20).
    # Closed-world citation gate post-process parser. Default OFF in prod ;
    # ON in staging during Stage 3 eval (Plan 94-03). Wired in coach_chat
    # narrator response stage (Plan 94-02) when True ; flag-OFF path is
    # byte-identical to the pre-Phase-94 narrator output (asserted by
    # tests/test_citation_gate/test_byte_identity_flag_off.py against the
    # 5 captured legacy snapshots in tests/fixtures/narrator_legacy_snapshots/).
    # Sunset clause: D-21 — flag + bypass code path removed in Phase 96 OR
    # after 4-week staging soak with `coach.citation_gate.fallback` rate ≤2%.
    COACH_CITATION_GATE_ENABLED: bool = False

    # === Wave 1a server-side compute rollback flags (D-05, D-09) ===
    # Plans 01-06 READ these flags but do NOT add new ones.
    # Defaults: 5 per-tool flags OFF (staged rollout), cap-garde ON.
    # Staging env enables the 5 OFF flags during Wave 1c validation.
    COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED: bool = False
    COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED: bool = False
    COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED: bool = False
    COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED: bool = False
    COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED: bool = False
    COACH_CAP_CHF_GARDE_ENABLED: bool = True
    # === end Wave 1a flags ===

    # Phase 97.5 W2-T5 — ConsentService 3-stage rollout enforcement mode.
    # `log_only`   (v2.9 default) : gate emits structured warning log +
    #                               Sentry breadcrumb on missing consent ;
    #                               returns 200 unchanged. Audit-trail only.
    # `soft_block` (v2.10 stage 2) : same + non-blocking warning header.
    # `hard_block` (v2.10 stage 3) : raises HTTPException(403, pointer).
    # Per .planning/phases/97.5-product-completeness-for-ship/97.5-PLAN.md §D.1.
    # v2.9 ships log_only by default — LSFin Art 8 « ability to demonstrer
    # la conformité » minimum. Promotion ladder lives in v2.10 (W3-T3 + W4-T2).
    CONSENT_GATE_ENFORCEMENT_MODE: Literal["log_only", "soft_block", "hard_block"] = "log_only"

    # Phase 91 D-01 — Narrator model selection. Default 'sonnet' matches
    # today's hardcoded Wave 2 narrator branch (preserves production
    # parity until Stage 3 eval gate flips the default in 91-05).
    # Per ADR-20260419-v2.8-kill-policy.md, Stage 3 fail => keep 'sonnet'
    # (cost +54% per turn ceiling); Stage 3 pass => flip to 'haiku'
    # (cost -2.5% per turn). The flip is the explicit decision documented
    # in 91-05-SUMMARY.md, NOT an automated default change here.
    # Wired in coach_chat.py via _NARRATOR_MODEL_MAP when
    # COACH_DUAL_LLM_ENABLED is True; flag-OFF path is unaffected.
    COACH_NARRATOR_MODEL: Literal["sonnet", "haiku"] = Field(
        default="sonnet",
        description=(
            "Phase 91 narrator model selection. 'sonnet' (default) = "
            "claude-sonnet-4-5-20250929; 'haiku' = claude-haiku-4-5-20251001. "
            "Wired in coach_chat narrator branch when COACH_DUAL_LLM_ENABLED. "
            "Per D-01 + ADR-20260419-v2.8-kill-policy.md."
        ),
    )

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

# Fail-fast: reject hardcoded / weak secret outside a known development
# context. Previous logic only tripped when ENVIRONMENT explicitly equalled
# "production" or "staging" — if the variable was unset, misspelled, or
# defaulted to "development" on a prod deploy, the dev secret leaked
# through. Flip to fail-closed: only ENVIRONMENT="development" is allowed
# to use weak secrets, and any other value (including unset) requires a
# strong JWT_SECRET_KEY.
_env = os.getenv("ENVIRONMENT", "development").strip().lower()
_is_dev = _env == "development"
_default_secret = "mint-dev-secret-change-in-production"

if not _is_dev and settings.JWT_SECRET_KEY == _default_secret:
    raise RuntimeError(
        f"CRITICAL: JWT_SECRET_KEY must be set via environment variable "
        f"(ENVIRONMENT={_env!r}). Do not use the default dev secret. "
        f"Generate one with: openssl rand -hex 32"
    )

if not _is_dev and len(settings.JWT_SECRET_KEY) < 32:
    raise RuntimeError(
        f"CRITICAL: JWT_SECRET_KEY too short ({len(settings.JWT_SECRET_KEY)} "
        f"chars) for ENVIRONMENT={_env!r}. Use at least 32 chars "
        f"(openssl rand -hex 32 produces 64)."
    )

# Fail-fast: reject SQLite in production/staging (P0-INFRA-1)
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.DATABASE_URL.startswith("sqlite")
):
    raise RuntimeError(
        "CRITICAL: DATABASE_URL must point to PostgreSQL in production/staging. "
        "SQLite is ephemeral on Railway and will lose all data on restart. "
        "Set DATABASE_URL in Railway environment variables."
    )

# Warn if OPENAI_API_KEY missing in production/staging (embeddings will fail)
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and not settings.OPENAI_API_KEY
):
    import logging as _logging_oai
    _logging_oai.getLogger("mint.config").warning(
        "OPENAI_API_KEY not set in %s. RAG embeddings will fail silently. "
        "Set OPENAI_API_KEY in Railway environment variables.",
        settings.ENVIRONMENT,
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
