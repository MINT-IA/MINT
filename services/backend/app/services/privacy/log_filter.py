"""PIILogFilter — scrub every log record before it is emitted.

PRIV-03 — Phase 29.

Attached to the root logger in ``core/logging_config.setup_logging``. Every
handler attached to root inherits the filter, so structured-log JSON,
console handlers, and any future Sentry handler all see scrubbed output.

Scrubs:
    - ``record.msg``                   — the format string itself
    - ``record.args``                  — positional substitution arguments
    - ``record.__dict__`` extra fields — set via ``logger.info(..., extra={})``

The filter never raises. On any internal failure it lets the original
record through with a single ``WARNING`` to stderr (logging fail-safe per
``logging`` doc) so we never lose observability over a scrubber bug.

Mode: ``mask`` is hard-coded — log lines are read by humans and tools that
expect ``<IBAN>`` placeholders, not parseable tokens. FPE is reserved for
batch scrubbing of historical logs (post-mortem cron, deferred to PRIV-03
follow-up).
"""
from __future__ import annotations

import logging
from typing import Any

from app.services.privacy.pii_scrubber import scrub

# Attribute names on LogRecord that are NOT user data — never scrub these.
_LOGRECORD_RESERVED = frozenset({
    "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
    "module", "exc_info", "exc_text", "stack_info", "lineno", "funcName",
    "created", "msecs", "relativeCreated", "thread", "threadName",
    "processName", "process", "message",
})


class PIILogFilter(logging.Filter):
    """logging.Filter that scrubs PII from every record."""

    def filter(self, record: logging.LogRecord) -> bool:  # noqa: D401
        try:
            self._scrub_record(record)
        except Exception as exc:  # pragma: no cover — fail-open
            # Don't drop the record — log volume matters more than the
            # one-off scrub failure. Surface it once at WARNING.
            try:
                import sys
                sys.stderr.write(
                    f"PIILogFilter scrub error: {type(exc).__name__}\n"
                )
            except Exception:
                pass
        return True  # always keep the record

    @staticmethod
    def _scrub_record(record: logging.LogRecord) -> None:
        # 1. The format string. ``record.msg`` may not be a string when
        #    callers do ``logger.info(some_obj)`` — we coerce to str.
        if record.msg is not None:
            if isinstance(record.msg, str):
                record.msg = scrub(record.msg, mode="mask")
            else:
                record.msg = scrub(str(record.msg), mode="mask")

        # 2. Positional args used by %-formatting. Tuple is the common
        #    case (logger.info("a=%s", x)); dict is allowed by stdlib.
        if record.args:
            if isinstance(record.args, tuple):
                record.args = tuple(_scrub_arg(a) for a in record.args)
            elif isinstance(record.args, dict):
                record.args = {k: _scrub_arg(v) for k, v in record.args.items()}

        # 3. Extra fields set via logger.info(..., extra={...}). They
        #    live as attributes on the record. Skip stdlib reserved names.
        for key, value in list(record.__dict__.items()):
            if key in _LOGRECORD_RESERVED or key.startswith("_"):
                continue
            if isinstance(value, str) and value:
                record.__dict__[key] = scrub(value, mode="mask")


def _scrub_arg(value: Any) -> Any:
    """Scrub a single args-list value. Non-strings pass through unchanged."""
    if isinstance(value, str):
        return scrub(value, mode="mask")
    return value


__all__ = ["PIILogFilter"]
