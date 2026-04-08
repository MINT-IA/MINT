"""Fragility Detector Service — Phase 11 (VOICE-10).

Auto-detects user "fragile" periods from gravity events on their profile,
and exposes helpers to clamp the voice cursor to N3 while fragile.

Trigger rule (D-06 / CONTEXT 11):
    >= 3 G2 or G3 events in a rolling 14-day window  ->  enter fragile mode

Expiry rule:
    fragile mode lasts 30 days from `fragileModeEnteredAt`. After day 30
    the user is no longer fragile and the level cap lifts back to N5
    (subject to the N5 hard gate in claude_coach_service).

Storage:
    Profile.recentGravityEvents : list[dict]   (rolling 30-day window)
        Each entry: {"ts": ISO8601 string, "gravity": "G1"|"G2"|"G3"}
    Profile.fragileModeEnteredAt : datetime | None

Pure-function style: no I/O, no global state. Caller is responsible for
persisting the returned profile mutation.

Threats mitigated:
    T-11-02 Repudiation — caller writes immutable biography entry on
        first fragile entry; this module flags `entered_now=True` exactly
        once per fragile window.
    T-11-03 Information Disclosure — only gravity label + timestamp are
        stored. No PII.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

logger = logging.getLogger(__name__)

# Tunables (frozen by VOICE-10 spec; do not soften without ADR)
FRAGILE_TRIGGER_GRAVITIES: frozenset[str] = frozenset({"G2", "G3"})
FRAGILE_TRIGGER_COUNT: int = 3
FRAGILE_TRIGGER_WINDOW_DAYS: int = 14
FRAGILE_MODE_DURATION_DAYS: int = 30
EVENT_LOG_RETENTION_DAYS: int = 30  # purge anything older when reading
MAX_LEVEL_WHILE_FRAGILE: int = 3


@dataclass(frozen=True)
class FragilityCheckResult:
    """Result of `check_and_update`.

    Attributes:
        is_fragile: True if the user is currently in fragile mode after
            this check (whether they were already, or just entered).
        entered_now: True iff THIS call transitioned the user into
            fragile mode. Caller MUST write the biography disclosure
            entry exactly once when this is True.
        events: Updated rolling event log (purged + new event appended).
        fragile_entered_at: Updated timestamp (unchanged if already fragile).
    """

    is_fragile: bool
    entered_now: bool
    events: list[dict]
    fragile_entered_at: datetime | None


def _now() -> datetime:
    """Indirection for monkeypatching in tests."""
    return datetime.now(timezone.utc)


def _parse_ts(raw: Any) -> datetime | None:
    """Parse a stored ISO8601 timestamp; return None if malformed."""
    if isinstance(raw, datetime):
        return raw if raw.tzinfo else raw.replace(tzinfo=timezone.utc)
    if not isinstance(raw, str):
        return None
    try:
        dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None


def _purge_stale(events: list[dict], now: datetime) -> list[dict]:
    """Drop events older than EVENT_LOG_RETENTION_DAYS."""
    cutoff = now - timedelta(days=EVENT_LOG_RETENTION_DAYS)
    fresh: list[dict] = []
    for e in events:
        ts = _parse_ts(e.get("ts"))
        if ts is not None and ts >= cutoff:
            fresh.append(e)
    return fresh


def _count_trigger_events(events: list[dict], now: datetime) -> int:
    """Count G2/G3 events within the rolling 14-day trigger window."""
    cutoff = now - timedelta(days=FRAGILE_TRIGGER_WINDOW_DAYS)
    n = 0
    for e in events:
        gravity = str(e.get("gravity", "")).upper()
        if gravity not in FRAGILE_TRIGGER_GRAVITIES:
            continue
        ts = _parse_ts(e.get("ts"))
        if ts is not None and ts >= cutoff:
            n += 1
    return n


def is_currently_fragile(
    fragile_entered_at: datetime | None,
    now: datetime | None = None,
) -> bool:
    """True iff user is within an active fragile window."""
    if fragile_entered_at is None:
        return False
    now = now or _now()
    entered = (
        fragile_entered_at
        if fragile_entered_at.tzinfo
        else fragile_entered_at.replace(tzinfo=timezone.utc)
    )
    return (now - entered) < timedelta(days=FRAGILE_MODE_DURATION_DAYS)


def clamp_level_if_fragile(
    requested_level: int,
    fragile_entered_at: datetime | None,
    now: datetime | None = None,
) -> int:
    """Clamp the requested voice level to N3 while fragile.

    Returns the level the LLM/template should actually use.
    """
    if is_currently_fragile(fragile_entered_at, now=now):
        clamped = min(requested_level, MAX_LEVEL_WHILE_FRAGILE)
        if clamped != requested_level:
            logger.info(
                "fragility_clamp level=%d->%d", requested_level, clamped
            )
        return clamped
    return requested_level


def check_and_update(
    recent_events: list[dict],
    fragile_entered_at: datetime | None,
    new_event: dict,
    now: datetime | None = None,
) -> FragilityCheckResult:
    """Append new_event, purge stale, and re-evaluate fragile mode.

    Pure function. Caller persists the returned events + entered_at.

    Args:
        recent_events: Profile.recentGravityEvents (current value).
        fragile_entered_at: Profile.fragileModeEnteredAt (current value).
        new_event: dict with keys 'ts' (ISO8601 str or datetime) and
            'gravity' ("G1"|"G2"|"G3").
        now: optional clock override (test seam).

    Returns:
        FragilityCheckResult — see dataclass docstring.
    """
    now = now or _now()

    # Normalise the incoming event timestamp to ISO8601 string for storage.
    raw_ts = new_event.get("ts", now)
    ts_dt = _parse_ts(raw_ts) or now
    gravity = str(new_event.get("gravity", "")).upper()
    normalised_event = {"ts": ts_dt.isoformat(), "gravity": gravity}

    # Purge + append.
    events = _purge_stale(list(recent_events), now)
    events.append(normalised_event)

    already_fragile = is_currently_fragile(fragile_entered_at, now=now)
    trigger_count = _count_trigger_events(events, now)
    should_be_fragile = trigger_count >= FRAGILE_TRIGGER_COUNT

    entered_now = False
    new_entered_at = fragile_entered_at

    if already_fragile:
        # Stay fragile; do NOT reset the timer or re-disclose.
        is_fragile = True
    elif should_be_fragile:
        # Transition: enter fragile mode now.
        new_entered_at = now
        entered_now = True
        is_fragile = True
        logger.info(
            "fragility_entered trigger_count=%d window_days=%d",
            trigger_count,
            FRAGILE_TRIGGER_WINDOW_DAYS,
        )
    else:
        is_fragile = False

    return FragilityCheckResult(
        is_fragile=is_fragile,
        entered_now=entered_now,
        events=events,
        fragile_entered_at=new_entered_at,
    )


__all__ = [
    "FragilityCheckResult",
    "FRAGILE_TRIGGER_COUNT",
    "FRAGILE_TRIGGER_WINDOW_DAYS",
    "FRAGILE_MODE_DURATION_DAYS",
    "MAX_LEVEL_WHILE_FRAGILE",
    "check_and_update",
    "is_currently_fragile",
    "clamp_level_if_fragile",
]
