import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.core.config import settings
from app.core.database import Base, engine
from app.core.logging_config import setup_logging, LoggingMiddleware
from app.core.rate_limit import limiter
from app.api.v1.router import api_router

# Initialize structured logging before anything else
setup_logging(settings.LOG_LEVEL)

logger = logging.getLogger(__name__)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware that adds security headers to every response."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if settings.ENVIRONMENT != "development":
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables and auto-ingest RAG knowledge base on startup."""
    # Import models to ensure they're registered with Base
    Base.metadata.create_all(bind=engine)

    # Auto-ingest education inserts into RAG vector store if empty
    _auto_ingest_rag()
    yield


_is_production = settings.ENVIRONMENT == "production"

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=None if _is_production else f"{settings.API_V1_STR}/openapi.json",
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    version="0.1.0",
    lifespan=lifespan,
)

# Rate limiting — 429 on excess requests
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# Global exception handler — catch unhandled exceptions
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erreur interne du serveur"},
    )


# Security headers middleware
app.add_middleware(SecurityHeadersMiddleware)

# Request logging middleware
app.add_middleware(LoggingMiddleware)

# Setup CORS — production must set CORS_ORIGINS env var
_cors_origins_raw = os.getenv("CORS_ORIGINS", "")
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
        persist_dir = os.path.join(backend_dir, "data", "chromadb")
        # Education inserts are at: ../../education/inserts/ relative to backend dir
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
                "Vector store already has %d documents, skipping auto-ingest",
                vector_store.count(),
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
