import logging
import os
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.gzip import GZipMiddleware
from starlette.requests import Request
from slowapi.errors import RateLimitExceeded
from app.core.config import settings
from app.core.database import Base, engine
from app.core.logging_config import setup_logging, LoggingMiddleware
from app.core.rate_limit import limiter
from app.api.v1.router import api_router

# Initialize structured logging before anything else
setup_logging(settings.LOG_LEVEL)

# Initialize Sentry error tracking (production/staging only)
if settings.SENTRY_DSN:  # pragma: no cover — DSN only set in production env
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENVIRONMENT,
        traces_sample_rate=0.1,
        profiles_sample_rate=0.1,
        send_default_pii=False,  # nLPD compliance
    )

logger = logging.getLogger(__name__)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware that adds security headers to every response."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        # API version for client compatibility checks
        response.headers["X-API-Version"] = "1.0.0"
        response.headers["X-Min-App-Version"] = "1.0.0"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        # CSP: API-only, no inline scripts/styles needed
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
        # Permissions-Policy: disable all browser features (API server)
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=(), payment=()"
        )
        if settings.ENVIRONMENT != "development":
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables and auto-ingest RAG knowledge base on startup."""
    # Import models to ensure they're registered with Base
    from app import models as _models  # noqa: F401
    Base.metadata.create_all(bind=engine)

    # FIX-106: Validate DB connectivity at startup — fail fast if misconfigured.
    try:
        from sqlalchemy import text
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        logger.info("Database connectivity: OK")
    except Exception as exc:
        logger.critical("Database connectivity FAILED: %s", exc)
        raise SystemExit(f"Cannot connect to database: {exc}") from exc

    # Optional auth hygiene: purge stale unverified accounts on startup.
    # SAFETY: Only run in non-production or with explicit flag.
    if settings.AUTH_AUTO_PURGE_ON_STARTUP and settings.ENVIRONMENT != "production":
        try:
            from sqlalchemy.orm import Session
            from app.services.auth_admin_service import purge_unverified_users

            db = Session(bind=engine)
            try:
                result = purge_unverified_users(
                    db,
                    older_than_days=settings.AUTH_UNVERIFIED_PURGE_DAYS,
                    dry_run=False,
                )
                logger.info(
                    "Startup unverified purge: deleted=%s candidates=%s days=%s",
                    result.get("deleted_users"),
                    result.get("candidates"),
                    result.get("older_than_days"),
                )
            finally:
                db.close()
        except Exception as exc:
            logger.warning("Startup unverified purge failed (non-fatal): %s", exc)

    # FIX-107: Validate SMTP config if email sending is enabled.
    if settings.EMAIL_SEND_ENABLED:
        if not settings.SMTP_HOST or not settings.EMAIL_FROM:
            logger.critical(
                "EMAIL_SEND_ENABLED=true but SMTP_HOST or EMAIL_FROM missing. "
                "Users will not receive password reset / verification emails."
            )
            # Don't crash — degrade gracefully but log at CRITICAL level.

    # Auto-ingest education inserts into RAG vector store if empty
    _auto_ingest_rag()

    # v2.7 Task 6: SLO monitor background task (fail-open).
    slo_task = None
    try:
        from app.services.slo_monitor import slo_monitor
        import asyncio as _asyncio
        slo_task = _asyncio.create_task(slo_monitor.run_forever())
        logger.info("SLO monitor started")
    except Exception as exc:
        logger.warning("SLO monitor startup failed (non-fatal): %s", exc)

    yield

    # Shutdown: stop SLO monitor
    if slo_task is not None:
        try:
            from app.services.slo_monitor import slo_monitor
            slo_monitor.stop()
            slo_task.cancel()
        except Exception:
            pass


_is_production = settings.ENVIRONMENT == "production"

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=None if _is_production else f"{settings.API_V1_STR}/openapi.json",
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    version="0.1.0",
    lifespan=lifespan,
)

# GZip compression — reduce payload size for large responses
app.add_middleware(GZipMiddleware, minimum_size=500)

# Rate limiting — 429 on excess requests with machine-readable error code (P2-19)
app.state.limiter = limiter


async def _rate_limit_handler(request: Request, exc: RateLimitExceeded):
    """Custom rate limit handler that includes machine-readable error_code."""
    return JSONResponse(
        status_code=429,
        content={
            "detail": "Trop de requêtes. Réessaie dans quelques instants.",
            "error_code": "rate_limited",
        },
    )


app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)


# Global exception handler — catch unhandled exceptions
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    # FIX-077 nLPD: Don't log full exception (may contain PII in values).
    # Log only the type name + first 100 chars of message.
    logger.error("Unhandled %s: %.100s", type(exc).__name__, str(exc))  # pragma: no cover
    # F8: Explicit Sentry capture — auto-integration may miss custom handlers
    if settings.SENTRY_DSN:  # pragma: no cover
        sentry_sdk.capture_exception(exc)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erreur interne du serveur", "error_code": "internal_error"},
    )


# Security headers middleware
app.add_middleware(SecurityHeadersMiddleware)

# Request logging middleware
app.add_middleware(LoggingMiddleware)

# v2.7 Phase 29 / PRIV-04 — envelope encryption request context
from app.middleware.encryption_context import EncryptionContextMiddleware  # noqa: E402
app.add_middleware(EncryptionContextMiddleware)

# Setup CORS — production MUST set CORS_ORIGINS env var
_cors_origins_raw = os.getenv("CORS_ORIGINS", "")
if not _cors_origins_raw and settings.ENVIRONMENT in ("production", "staging"):  # pragma: no cover
    logger.critical(
        "CORS_ORIGINS env var not set in %s. "
        "API will reject cross-origin requests. "
        "Set CORS_ORIGINS in Railway dashboard.",
        settings.ENVIRONMENT,
    )
_cors_origins = (
    [o.strip() for o in _cors_origins_raw.split(",") if o.strip()]
    if _cors_origins_raw
    else ["http://localhost:3000", "http://localhost:8080"]  # Dev only — explicit origins
)
# Only enable credentials when origins are explicitly listed (not wildcard)
_allow_credentials = "*" not in _cors_origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=_allow_credentials,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


def _auto_ingest_rag():
    """
    Auto-ingest education inserts into the RAG vector store if it's empty.

    This runs at startup and is a no-op if:
    - RAG dependencies are not installed
    - The vector store already has documents
    - The education inserts directory doesn't exist
    """
    try:
        from app.services.rag import RAG_AVAILABLE

        if not RAG_AVAILABLE:
            logger.info("RAG dependencies not installed, skipping auto-ingest")
            return

        from app.services.rag.vector_store import MintVectorStore
        from app.services.rag.ingester import MarkdownIngester

        # Determine paths
        backend_dir = os.path.dirname(os.path.dirname(__file__))

        # ChromaDB persist directory — configurable via CHROMADB_PERSIST_DIR env var
        persist_dir = settings.CHROMADB_PERSIST_DIR
        if not os.path.isabs(persist_dir):
            persist_dir = os.path.join(backend_dir, persist_dir)

        # Education inserts:
        # In Docker: /app/education/inserts (COPY'd by Dockerfile)
        # Locally: ../../education/inserts relative to backend dir
        inserts_dir = os.path.join(backend_dir, "education", "inserts")
        if not os.path.isdir(inserts_dir):
            # Fallback for local dev (repo root structure)
            inserts_dir = os.path.normpath(
                os.path.join(backend_dir, "..", "..", "education", "inserts")
            )

        if not os.path.isdir(inserts_dir):
            logger.info(
                "Education inserts directory not found at %s, skipping auto-ingest",
                inserts_dir,
            )
            return

        # Initialize vector store
        vector_store = MintVectorStore(persist_directory=persist_dir)

        # Only ingest if the store is empty
        if vector_store.count() > 0:
            logger.info(
                "RAG vector store: %d documents (persist_dir=%s)",
                vector_store.count(),
                persist_dir,
            )
            return

        # Ingest education inserts (language auto-detected from filenames)
        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(inserts_dir)
        logger.info("Auto-ingested %d document chunks from education inserts", count)

    except Exception as e:
        # Non-fatal: RAG is optional, don't block app startup
        logger.warning("RAG auto-ingest failed (non-fatal): %s", e)


app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {"msg": "Welcome to Mint API"}
