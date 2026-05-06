"""Coach message audit log model (Phase 93 — COMP-01).

Persists one row per coach LLM response (authenticated /coach/chat +
anonymous /anonymous/chat) so a FINMA inspector running

    SELECT * FROM coach_message_audits WHERE created_at > '2026-05-06'

sees one row per LLM response, with hashed prompt + response (nLPD-safe),
archetype, banned-term-hit flag, eclairage kind, and retained_until = +10y.

Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy import Boolean, Column, DateTime, String

from app.core.database import Base


# 10 years per OAR-G art. 24 (3653 days = 10 * 365 + 3 leap days, generous
# margin so the inspector never sees a < 10y gap on a row created near a
# leap-year boundary).
_RETENTION_DAYS = 3653


def _default_retained_until() -> datetime:
    """Return now + 10y in UTC. Default for the retained_until column."""
    return datetime.now(timezone.utc) + timedelta(days=_RETENTION_DAYS)


class CoachMessageAudit(Base):
    """Immutable-style audit row for every coach LLM response.

    Columns:
        - id: UUID4 primary key.
        - session_id: UUID for anonymous chat, str(user.id) for authed
          chat. Single column so the inspector query stays trivial.
          Indexed.
        - archetype: user archetype (swiss_native, expat_us, ...) or
          ``"anonymous"`` for the unauthed flow. Nullable to keep the
          insert best-effort even when archetype detection fails.
        - prompt_hash: SHA-256 hex (64 chars) of the sanitized user
          message. Raw prompt is NEVER persisted (nLPD art. 6, LPD).
        - response_hash: SHA-256 hex (64 chars) of the LLM answer.
        - banned_term_hit: True when ComplianceGuardrails matched a
          banned term in the response (LSFin art. 3 / 8 telemetry).
        - eclairage_kind: name of the Premier Eclairage emitted, if
          any (e.g. ``"fiscal_margin_3a"``). Null when no eclairage.
        - created_at: insertion timestamp (UTC, indexed).
        - retained_until: hard-delete deadline (now + 10y). The actual
          purge cron lands in Phase 96; for Phase 93 we only need the
          column so the inspector can verify retention policy.

    Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.
    """

    __tablename__ = "coach_message_audits"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    session_id = Column(String, nullable=False, index=True)
    archetype = Column(String, nullable=True)
    prompt_hash = Column(String, nullable=False)
    response_hash = Column(String, nullable=False)
    banned_term_hit = Column(Boolean, nullable=False, default=False)
    eclairage_kind = Column(String, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    retained_until = Column(
        DateTime,
        nullable=True,
        default=_default_retained_until,
    )
