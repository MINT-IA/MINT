"""Phase 96 D-08..D-11 — in-memory turn counter + terminal template.

Per CONTEXT 'Claude's Discretion' : default strategy is an in-memory
dict ; Redis backing is post-96 deferred per CONTEXT §"Deferred Ideas"
§7.

Multi-process caveat : uvicorn workers > 1 will NOT share this dict.
For Phase 96 staging deploy, run with workers=1 (uvicorn default).
If G2 surfaces drift, Phase 97 patches with Redis.

SECURITY (T-96-W2-TurnCountTamper) — the client-supplied
``CoachChatRequest.turn_count`` is NOT trusted. The server reads this
TURN_COUNTER dict as the source of truth ; the client value is
accepted for client-side UX transparency only (turn-counter display
in MintChatOverlay).

The verbatim FR ``TURN_CAP_TERMINAL_TEMPLATE`` (D-10) is returned at
turn 4 (cap hit) with ZERO LLM call. accent_lint_fr clean ; zero
LSFin banned terms — invariant guarded by
``tests/test_chat_as_verb/test_terminal_template.py``.
"""
from __future__ import annotations

from typing import Dict, Optional, Tuple

# Sentry SDK import is best-effort — production has it, some test
# environments may not. The breadcrumb emitter is fail-open and the
# module assigns ``sentry_sdk = None`` when import fails (covered by
# tests/test_chat_as_verb/test_sentry_overflow_breadcrumb.py).
try:  # pragma: no cover — import-time
    import sentry_sdk as _sentry_sdk
    sentry_sdk: Optional[object] = _sentry_sdk
except Exception:  # pragma: no cover — defensive
    sentry_sdk = None


# Key : (session_id, source_card_id). Value : count of turns spent on
# this card within this app-session. Resets on app/process restart per
# CONTEXT D-09 ("per-session, NOT per-day").
TURN_COUNTER: Dict[Tuple[str, str], int] = {}


# ---------------------------------------------------------------------------
# Phase 96 D-10 — verbatim FR terminal template.
#
# Returned at turn_count >= 3 with ZERO LLM call (zero token cost).
# accent_lint_fr clean (« exploré » + « hypothèses » with é) and zero
# LSFin banned terms (no « garanti », « optimal », « parfait », …).
# Guard tests at tests/test_chat_as_verb/test_terminal_template.py.
# ---------------------------------------------------------------------------
TURN_CAP_TERMINAL_TEMPLATE: str = (
    "Tu as exploré 3 angles sur cette carte. "
    "Pour aller plus loin, ouvre le simulateur depuis "
    "[Explorer →](/explorer?id={card_id}) — "
    "tu pourras y modifier les hypothèses en direct."
)


# The cap threshold. Hard-coded per D-08 (NO soft cap, NO extension).
TURN_CAP_THRESHOLD: int = 3


# Sentry breadcrumb category for the VERB-05 metric.
OVERFLOW_BREADCRUMB_CATEGORY: str = "coach.chat_overflow.turn_4"


def reset() -> None:
    """Test helper — clear the counter between test cases."""
    TURN_COUNTER.clear()


def is_cap_hit(key: Tuple[str, str]) -> bool:
    """True when TURN_COUNTER[key] >= TURN_CAP_THRESHOLD.

    Missing keys count as 0 (not hit).
    """
    return TURN_COUNTER.get(key, 0) >= TURN_CAP_THRESHOLD


def increment_and_get_previous(key: Tuple[str, str]) -> int:
    """Increment the counter for ``key`` ; return the value BEFORE increment.

    The wrapper at ``coach_chat._run_narrator_with_gate_and_cap`` uses
    this to know how many turns the user has spent on the card AFTER
    the cap-hit check (read-then-write semantics avoid a TOCTOU race
    within a single coroutine — async scheduling is not preemptive at
    this granularity).
    """
    previous = TURN_COUNTER.get(key, 0)
    TURN_COUNTER[key] = previous + 1
    return previous


def emit_overflow_breadcrumb(
    *, source_card_id: str, turn_count: int
) -> None:
    """Fire the VERB-05 Sentry breadcrumb on cap-hit.

    Fail-open per Phase 94 + 95 telemetry convention : any exception
    inside the SDK call is silently swallowed. Payload is non-PII —
    card_id is a stable enum slug (e.g. ``mon_3a_2026``), turn_count
    is a small integer. No user_message, no profile_context, no
    api_key, no user_id.
    """
    if sentry_sdk is None:
        return
    try:
        sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]
            category=OVERFLOW_BREADCRUMB_CATEGORY,
            message="3-turn cap hit",
            level="info",
            data={
                "source_card_id": source_card_id,
                "turn_count": int(turn_count),
            },
        )
    except Exception:  # pragma: no cover — fail-open telemetry
        pass


def render_terminal_template(card_id: str) -> str:
    """Render the D-10 verbatim FR terminal template with card_id substituted.

    Centralised so the wrapper and the test surface read the same
    substitution path (avoid `.format(card_id=...)` drift across the
    codebase).
    """
    return TURN_CAP_TERMINAL_TEMPLATE.format(card_id=card_id)
