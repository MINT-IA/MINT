"""
Structured logging configuration for MINT API.

Uses Python stdlib logging with a JSON formatter.
Provides a LoggingMiddleware for FastAPI that logs request method, path, status, and duration.
"""

import json
import logging
import re
import time
from contextvars import ContextVar
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

# Mobile clients (MintHttpClient) stamp this header with a uuid4 per call.
# When present and well-formed we reuse it as the trace_id so client stdout
# and backend logs share a single key (see tools/debug/mint-trace.sh).
CLIENT_REQUEST_ID_HEADER = "x-mint-req-id"
_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def _coerce_client_request_id(raw: Optional[str]) -> Optional[str]:
    """Return ``raw`` only if it parses as a UUID — defense against log
    poisoning when the header is attacker-controlled."""
    if not raw:
        return None
    if not _UUID_RE.match(raw):
        return None
    try:
        UUID(raw)
    except ValueError:
        return None
    return raw.lower()

# Context variable for trace ID (correlates all logs within a single request)
trace_id_var: ContextVar[str] = ContextVar("trace_id", default="-")


class JsonFormatter(logging.Formatter):
    """Formats log records as single-line JSON objects."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "trace_id": trace_id_var.get("-"),
        }
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry, default=str)


def setup_logging(level: str = "INFO") -> None:
    """
    Configure structured JSON logging for the application.

    Args:
        level: Log level string (DEBUG, INFO, WARNING, ERROR, CRITICAL).
    """
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())

    # PRIV-03 — every log record passes through PIILogFilter before any
    # handler emits it. Attached to the root logger so all loggers and
    # handlers (including future Sentry / OTLP exporters) inherit it.
    try:
        from app.services.privacy.log_filter import PIILogFilter
        handler.addFilter(PIILogFilter())
    except Exception:  # pragma: no cover — defensive: never break startup
        pass

    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)

    # Remove existing handlers to avoid duplicate output
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    # Also attach the filter at the logger level so synthetic log records
    # (e.g. handler-less subscribers in tests) still see scrubbed output.
    try:
        from app.services.privacy.log_filter import PIILogFilter
        root_logger.addFilter(PIILogFilter())
    except Exception:  # pragma: no cover
        pass

    # Suppress noisy third-party loggers
    for noisy in ("uvicorn.access", "uvicorn.error", "sqlalchemy.engine"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


class LoggingMiddleware(BaseHTTPMiddleware):
    """
    FastAPI middleware that logs every request with method, path, status, and duration.
    Assigns a unique trace_id to each request for log correlation.
    """

    async def dispatch(self, request: Request, call_next):
        incoming = _coerce_client_request_id(
            request.headers.get(CLIENT_REQUEST_ID_HEADER)
        )
        request_trace_id = incoming or str(uuid4())
        trace_id_var.set(request_trace_id)

        # S98 Phase 2 — promote the X-MINT-Req-Id to a Sentry-searchable
        # tag. A backend exception captured during this request now
        # ships to Sentry with `mint_request_id=<uuid>`, which is the
        # join key into Railway log lines (same tag wired on mobile in
        # MintHttpClient). No-op when SENTRY_DSN unset.
        try:
            import sentry_sdk

            sentry_sdk.set_tag("mint_request_id", request_trace_id)
        except Exception:
            # Defence-in-depth — Sentry init failure must never block a
            # request response. Already-imported sentry_sdk is a no-op
            # when not initialised.
            pass

        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)

        logger = logging.getLogger("mint.access")
        logger.info(
            "method=%s path=%s status=%d duration_ms=%.2f",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )

        # Propagate trace_id in response header for debugging
        response.headers["X-Trace-Id"] = request_trace_id
        return response
