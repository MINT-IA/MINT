"""Phase 96-03 OBS-03 — Sentry audit-tag plumbing helper.

Single source of truth for the 4-tag pattern emitted on every coach
response (authed /coach/chat normal path + FATCA handoff path + anonymous
/anonymous/chat path). The helper consumes the SAME data dict that the
Phase 93-01 audit hook computed (``hash_for_audit`` results, archetype,
``banned_term_hit``, ``eclairage_kind``) — it never recomputes hashes,
never re-runs the compliance guardrails, never re-derives archetype.
That is the « no double-compute » contract.

Best-effort contract (Karpathy practice 3 — surgical):
  * Any exception inside the helper is caught and logged as a Sentry
    breadcrumb. A failure here MUST NOT propagate to the user response.
  * If ``sentry_sdk`` is missing / Sentry is misconfigured, all tag
    calls are silently swallowed.
  * The helper has no return value. It is pure side-effect.

Tag value contracts (per Plan 96-03 CONTEXT § OBS-03):
  * ``eclairage_kind`` — snake_case string (e.g. ``"fiscal_margin_3a"``,
    ``"fatca_handoff"``) or ``"none"`` when the audit row carried None.
  * ``banned_term_hit`` — ``"true"`` / ``"false"`` lowercase, matches
    the existing ``audit_emitted`` style.
  * ``eval_score`` — string. Until the Phase 95 promptfoo assertion
    YAMLs land, callers pass ``"unavailable"`` and we tag it verbatim
    so Sentry filtering still works (filter:
    ``tags[eval_score]:unavailable`` shows the fallback population).
    Numeric float scores (e.g. ``0.97``) are accepted as float and
    formatted to 2 decimals.
  * ``archetype`` — string from the audit row (e.g. ``"swiss_native"``,
    ``"expat_us"``, ``"anonymous"``) or ``"unknown"`` when ``None``.
"""
from __future__ import annotations

import logging
from typing import Optional, Union

logger = logging.getLogger(__name__)

EvalScore = Union[float, str, None]


def _format_eval_score(value: EvalScore) -> str:
    """Coerce an eval_score input into the Sentry tag string contract."""
    if value is None:
        return "unavailable"
    if isinstance(value, str):
        # Caller already supplied a string fallback (e.g. "unavailable").
        return value
    try:
        return f"{float(value):.2f}"
    except (TypeError, ValueError):
        return "unavailable"


def emit_sentry_audit_tags(
    *,
    eclairage_kind: Optional[str],
    banned_term_hit: bool,
    eval_score: EvalScore,
    archetype: Optional[str],
) -> None:
    """Set the 4 audit tags on the in-flight Sentry transaction.

    All keyword-only to prevent positional drift if the contract ever
    grows a 5th tag (e.g. ``model_used``).

    The implementation reuses the EXACT data already computed by the
    Phase 93-01 audit hook — the caller passes the values it just
    persisted to ``coach_message_audits``. This is the « single source
    of truth » contract. Do not recompute hashes / re-scan banned terms
    inside this helper.

    Best-effort: never raises. Any failure is logged via Python logging
    and (when Sentry is reachable) emitted as a breadcrumb so the
    runbook can detect a silent tagging regression.
    """
    try:
        import sentry_sdk
    except ImportError:
        # Sentry SDK missing entirely — environment without observability
        # plumbing (some unit-test contexts). Stay silent.
        return
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("OBS-03 sentry_sdk import failed: %s", exc)
        return

    try:
        sentry_sdk.set_tag("eclairage_kind", eclairage_kind or "none")
        sentry_sdk.set_tag(
            "banned_term_hit", "true" if banned_term_hit else "false"
        )
        sentry_sdk.set_tag("eval_score", _format_eval_score(eval_score))
        sentry_sdk.set_tag("archetype", archetype or "unknown")
    except Exception as exc:
        # Tag emission failed — best-effort wrap. Log + breadcrumb so
        # the runbook can spot the regression in Sentry itself.
        logger.warning("OBS-03 sentry tag emission failed: %s", exc)
        try:
            sentry_sdk.add_breadcrumb(
                category="obs.audit_tags",
                message="sentry_audit_tags_emit_failed",
                level="warning",
                data={"err": str(exc)},
            )
        except Exception:  # pragma: no cover — last-resort defensive
            pass


# Underscore-prefixed alias kept for the « private helper » convention
# referenced by Plan 96-03 § interfaces. Both names resolve to the same
# function so future PRs can grep for either.
_emit_sentry_audit_tags = emit_sentry_audit_tags

__all__ = ["emit_sentry_audit_tags", "_emit_sentry_audit_tags"]
