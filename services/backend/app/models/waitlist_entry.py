"""Waitlist entry model — sub-phase 01.5 archetype HARD GATE.

Captures the email + consent metadata of users whose archetype is NOT
in the calibrated set (`swiss_native`, `swiss_native_couple`-equivalent).
The mobile WaitlistScreen POSTs to /api/v1/waitlist when a user is
routed to the « pas encore supporté pour ton profil » screen.

Security scope source : `.planning/phases/01.5-archetype-hard-gate-fatca/01.5-SECURITY-fatca-scope.md`
4 mandatory consent guardrails (§5) implemented :
  1. Explicit opt-in checkbox  → `consent_given` column (NOT NULL)
  2. Controller identity        → `legal_entity` column (default 'MINT SA' from privacy_service.py)
  3. One-click unsubscribe      → enforced server-side by future outbound-mail infra (out of scope here)
  4. Data retention period      → `retention_purge_after` column (default now() + 12 months)

LSFin classification : the waitlist screen itself is NOT a financial
service communication. The follow-up notification email IS marketing
communication (UCA art. 3(1)(o)) — the opt-in captured here is the
prior consent that legitimizes that future email.

Per memory `project_orm_orphan_pattern` — this model ships in the same
PR as its alembic migration (services/backend/alembic/versions/p123_waitlist_entry.py).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import Boolean, Column, DateTime, String

from app.core.database import Base


# Allowed archetype slugs — must match the Pydantic Literal in
# `app/schemas/waitlist.py` so the validation is single-source-of-truth.
_ALLOWED_ARCHETYPES = (
    "expat_us",
    "expat_eu",
    "cross_border",
    "independent_no_lpp",
    "couple_one_works",
    "senior_post_64",
    "unknown",   # detected but ambiguous — bias-false-positive bucket
    "other",     # last-resort catch-all when the gate fires without a slug
)

# Allowed locales — matches the 6 ARB files in apps/mobile/lib/l10n/.
_ALLOWED_LOCALES = ("fr", "en", "de", "es", "it", "pt")

# Where the gate fired from — useful for analytics + future onboarding tuning.
_ALLOWED_SOURCES = ("onboarding_hard_gate", "settings", "other")


def _default_retention_purge_after() -> datetime:
    """12-month retention per Security §6 Q2 + nLPD art. 25 transparency."""
    return datetime.now(timezone.utc) + timedelta(days=365)


class WaitlistEntry(Base):
    """One row per user opt-in on the archetype hard-gate screen."""

    __tablename__ = "waitlist_entries"

    # Server-generated UUID PK (kept as String for sqlite/postgres
    # cross-compat — same pattern as `anonymous_sessions.session_id`).
    id = Column(String(36), primary_key=True)

    # User-submitted email (single-purpose : notification when archetype lands).
    # Pydantic EmailStr validates at request boundary ; column allows reasonable max.
    email = Column(String(254), nullable=False, index=True)

    # Detected archetype that triggered the gate. One of `_ALLOWED_ARCHETYPES`.
    archetype = Column(String(32), nullable=False, index=True)

    # Locale the screen was rendered in. One of `_ALLOWED_LOCALES`.
    locale = Column(String(8), nullable=False)

    # Which surface the gate fired from. One of `_ALLOWED_SOURCES`.
    source = Column(String(32), nullable=False, server_default="other")

    # Reused X-Anonymous-Session UUID from AnonymousSessionService (mobile).
    # Indexed so the same anon user can be deduped client-side without
    # surfacing the email back to the device. NOT a FK because anonymous
    # sessions can be GC'd separately ; the waitlist row outlives them.
    anonymous_session_id = Column(String(36), nullable=False, index=True)

    # Explicit opt-in checkbox state. UCA art. 3(1)(o) requires prior
    # consent for commercial email. Without this = legally void.
    consent_given = Column(Boolean, nullable=False)

    # Data controller identity surfaced in the consent UI. Defaults to
    # « MINT SA » per `services/backend/app/services/privacy_service.py:41`
    # — but stored on the row so we can audit consent against the entity
    # named at the moment of capture (in case the legal entity ever changes).
    legal_entity = Column(String(64), nullable=False, server_default="MINT SA")

    # When the row was captured. UTC.
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    # When (or if) we notified the user their archetype became supported.
    # NULL until the follow-up email infrastructure (future phase) writes here.
    notified_at = Column(DateTime, nullable=True)

    # nLPD art. 25 retention bound — auto-purge after this timestamp.
    # 12-month default per Security §6 Q2. Background purge job is
    # out-of-scope for 01.5 ; the column locks the contract.
    retention_purge_after = Column(
        DateTime,
        nullable=False,
        default=_default_retention_purge_after,
    )

    def __repr__(self) -> str:  # pragma: no cover — debug-only
        return (
            f"<WaitlistEntry id={self.id} email=*** "
            f"archetype={self.archetype} locale={self.locale}>"
        )
