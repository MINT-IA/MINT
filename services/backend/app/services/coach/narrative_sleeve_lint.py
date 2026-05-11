"""Phase 96 D-16 — NarrativeSleeve hook digit-free linter.

Response middleware ; runs AFTER the Phase 94 citation gate (the citation
gate stays first in the middleware chain). If the narrator's emitted
``hook`` field contains any digit (regex ``\\d``), swap it to the verbatim
FR fallback string defined in D-16. NEVER raise. NEVER 500.

T-96-W3-LinterDoS mitigation (3 defenses) :

1. The regex is ``re.compile(r"\\d", re.UNICODE)`` — a simple character
   class.  No alternation, no backreferences, no nested quantifiers : not
   susceptible to catastrophic backtracking.
2. The ``.search()`` call is wrapped in a ``signal.setitimer(ITIMER_REAL,
   0.1)`` budget on POSIX hosts (defense-in-depth ; the regex itself can't
   hang but a future regex change must inherit the budget).  On Windows
   test runners (no ``SIGALRM``), the regex runs unguarded.
3. On ANY exception (timeout, regex error, sentry breadcrumb error), the
   linter forces the fallback swap.  Fail-safe, never fail-open.

Wiring : ``citation_parser._substitute_placeholders`` runs first, then the
endpoint (or whoever assembles the ``CoachChatResponse``) calls
``lint_sleeve(narrative_sleeve)`` AFTER substitution and BEFORE response
serialization.  This module exposes ``lint_sleeve`` + ``HOOK_FALLBACK``
as its public API.
"""
from __future__ import annotations

import re
import signal

import sentry_sdk

from app.schemas.narrative_sleeve import NarrativeSleeve

# Simple character class — no catastrophic backtracking. The UNICODE flag
# keeps the semantics explicit (Python 3 enables Unicode by default for
# `str` patterns, but the flag pins intent for future reviewers).
_DIGIT_RE: re.Pattern[str] = re.compile(r"\d", re.UNICODE)

# D-16 verbatim FR — accent_lint clean (« ça » carries cedilla), zero
# LSFin banned terms.  Snapshot-pinned by
# `test_narrative_sleeve_lint.test_hook_fallback_verbatim_d16`.
HOOK_FALLBACK: str = "Voyons ensemble ce que ça change pour toi."


class _LintTimeout(Exception):
    """Raised when the SIGALRM budget on the regex search expires."""


def _timeout_handler(signum: int, frame: object) -> None:  # noqa: ARG001
    raise _LintTimeout()


def _has_digit_with_timeout(hook: str, *, timeout_ms: int = 100) -> bool:
    """Run the regex search under a SIGALRM budget.

    Returns True on digit match.  On SIGALRM timeout, the caller will
    catch ``_LintTimeout`` via the broad ``except Exception:`` in
    ``lint_sleeve`` and force the fallback swap — but the helper itself
    re-raises (rather than returning True) so the caller can decide what
    the safe choice is.
    """
    # signal.SIGALRM is POSIX-only — guard for Windows test runners.
    if not hasattr(signal, "SIGALRM"):
        return bool(_DIGIT_RE.search(hook))

    old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
    signal.setitimer(signal.ITIMER_REAL, timeout_ms / 1000.0)
    try:
        return bool(_DIGIT_RE.search(hook))
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, old_handler)


def lint_sleeve(sleeve: NarrativeSleeve) -> NarrativeSleeve:
    """Swap ``hook`` to ``HOOK_FALLBACK`` if it contains any digit.

    ``NarrativeSleeve`` is ``frozen=True`` — ``model_copy(update=...)`` is
    the only mutation path.  Returns the SAME instance on clean input
    (cheaper than a defensive copy + observably idempotent for tests).
    """
    try:
        needs_swap = _has_digit_with_timeout(sleeve.hook)
    except Exception:  # noqa: BLE001 — defense-in-depth (T-96-W3-LinterDoS)
        # On ANY error (timeout, regex error, hook-attribute error),
        # force the fallback swap.  Fail-safe : a polluted response is
        # better than a 500.
        needs_swap = True

    if not needs_swap:
        return sleeve

    # Non-PII breadcrumb : length only, never the hook content. Fail-open
    # on Sentry SDK errors (the breadcrumb is observability, not a gate).
    try:
        sentry_sdk.add_breadcrumb(
            category="coach.narrative_sleeve.hook_swap",
            message="hook contained digit -> swapped to fallback",
            level="info",
            data={"original_hook_length": len(sleeve.hook)},
        )
    except Exception:  # pragma: no cover — breadcrumb is fail-open
        pass

    return sleeve.model_copy(update={"hook": HOOK_FALLBACK})
