"""VisionGuard — LLM-as-judge for Vision-derived free text.

PRIV-05 (judge half) — Phase 29-04.

Applies a secondary Claude Haiku 4.5 pass over Vision outputs (summary,
narrative, premier_eclairage) BEFORE they reach the user. Blocks:

    (a) conseil produit spécifique (ISIN, ticker, named product)
    (b) promesse de rendement ("tu es garanti de toucher X")
    (c) info nominative tierce (third-party named person)
    (d) terme banni (garanti / optimal / sans risque / meilleur / idéal)
    (e) langage prescriptif ("tu dois", "il faut")

Fail-closed on judge unavailable (API error, missing key, parse error):
the default is to block. Operators can hard-bypass via
``VISION_GUARD_ENABLED=false`` env var (emergency only — logged as a
structured warning so the incident is visible).

This is cheaper than running Sonnet again: Haiku pricing target is
~$0.0003 per call, +800 ms latency. Small talk bypasses (no guard call).
Applied only to the 3 critical Vision outputs per plan 29-04 decision
D-PRIV-05.

Per CLAUDE.md §6, neither the judge prompt nor the reformulation output
can use banned terms (garanti, certain, optimal, meilleur, parfait).
Tests assert this invariant.
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

logger = logging.getLogger(__name__)

# Haiku 4.5 — the cheap, fast judge. Pinned string so the prompt and
# cost telemetry stay in sync. If Anthropic retires this id the test
# ``test_vision_guard_model_pinned`` will fail and force an explicit
# update rather than a silent fallback.
HAIKU_MODEL = "claude-haiku-4-5-20251022"

# Latency / cost budget documented in plan 29-04 <action>.
_MAX_TOKENS = 400
_TIMEOUT_S = 10.0

GuardCategory = Literal[
    "product_advice",
    "return_promise",
    "third_party_specific",
    "banned_term",
    "prescriptive_language",
]


class GuardVerdict(BaseModel):
    """Outcome of a VisionGuard judge pass on a Vision free-text bundle."""

    model_config = ConfigDict(frozen=True)

    allow: bool
    flagged_categories: List[GuardCategory] = Field(default_factory=list)
    reformulation: Optional[str] = None
    reason: str = ""
    cost_usd: float = 0.0


# ---------------------------------------------------------------------------
# Prompt — JSON-forced via a tool schema so the judge cannot free-form.
# ---------------------------------------------------------------------------

_JUDGE_TOOL = {
    "name": "lsfin_compliance_verdict",
    "description": (
        "Emit a structured LSFin compliance verdict for the provided Vision "
        "output. Judge the text against the 5 categories. Return a "
        "reformulation only if the text is salvageable as educational."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "allow": {"type": "boolean"},
            "flagged_categories": {
                "type": "array",
                "items": {
                    "type": "string",
                    "enum": [
                        "product_advice",
                        "return_promise",
                        "third_party_specific",
                        "banned_term",
                        "prescriptive_language",
                    ],
                },
            },
            "reformulation": {"type": ["string", "null"]},
            "reason": {"type": "string"},
        },
        "required": ["allow", "flagged_categories", "reason"],
    },
}

_JUDGE_SYSTEM = (
    "Tu es juge de conformite LSFin pour une app financiere suisse (MINT). "
    "Tu evalues du texte genere par un LLM Vision qui a lu un document. "
    "Ton role: bloquer tout contenu qui :\n"
    "  (a) recommande un produit specifique (ISIN, ticker, nom de banque, "
    "fond/ETF nomme, conseil 'achete X')\n"
    "  (b) promet un rendement ('tu toucheras', 'tu es assure de', "
    "'rendement garanti')\n"
    "  (c) nomme un tiers identifiable (prenom+nom d'une personne qui n'est "
    "pas l'utilisateur, ex. conjoint, employeur)\n"
    "  (d) contient un terme banni (garanti, optimal, sans risque, parfait, "
    "meilleur, ideal, certain utilise comme garantie)\n"
    "  (e) utilise un langage prescriptif direct ('tu dois', 'il faut que tu', "
    "'rachete', 'investis')\n"
    "\n"
    "Contraintes DURES sur ta sortie :\n"
    "  - Tu DOIS appeler la fonction lsfin_compliance_verdict (pas de texte libre).\n"
    "  - 'reformulation' ne doit JAMAIS contenir les termes bannis ci-dessus. "
    "Utilise 'possible dans ce scenario', 'adapte', 'envisageable', 'pertinent'.\n"
    "  - 'reformulation' reste fidele aux chiffres bruts (pas d'invention), "
    "en langage educatif, conditionnel, non-prescriptif.\n"
    "  - Si le texte est court/benin (small talk, ack technique) : allow=true.\n"
    "  - Fail-closed: dans le doute, allow=false + reformulation educative.\n"
)

_JUDGE_USER_TEMPLATE = (
    "Evalue ce bundle Vision avant qu'il n'atteigne l'utilisateur.\n"
    "\n"
    "--- SUMMARY ---\n{summary}\n"
    "--- NARRATIVE ---\n{narrative}\n"
    "--- FIELDS SUMMARY ---\n{fields_summary}\n"
    "\n"
    "Reponds via la fonction lsfin_compliance_verdict."
)


# ---------------------------------------------------------------------------
# Banned-term invariant on reformulation — defense-in-depth.
# If Haiku slips a banned term into its own reformulation (rare but observed
# in early prototyping), the coach-side sanitizer strips it before display.
# ---------------------------------------------------------------------------


def _sanitize_reformulation(text: Optional[str]) -> Optional[str]:
    if not text:
        return text
    try:
        from app.services.coach.compliance_guard import ComplianceGuard

        return ComplianceGuard()._sanitize_banned_terms(text)  # noqa: SLF001
    except Exception as exc:  # pragma: no cover - defensive
        logger.warning("vision_guard: reformulation sanitize failed err=%s", exc)
        return text


def _guard_enabled() -> bool:
    """Env-var bypass. Default true; set VISION_GUARD_ENABLED=false to disable."""
    value = os.environ.get("VISION_GUARD_ENABLED", "true").strip().lower()
    return value not in ("false", "0", "no", "off")


def _estimate_cost_usd(input_tokens: int, output_tokens: int) -> float:
    """Rough Haiku 4.5 pricing — public $0.80 / $4 per 1M (in/out)."""
    return (input_tokens * 0.0000008) + (output_tokens * 0.000004)


def _scrub_log_text(text: Optional[str]) -> str:
    """Strip PII from any text we log. Reuses Phase 29-03 pii_scrubber.

    Fail-open: if the scrubber is missing (shouldn't be — same phase),
    we log "<unscrubbable>" rather than leak the raw text.
    """
    if not text:
        return ""
    try:
        from app.services.privacy.pii_scrubber import scrub

        return scrub(text)
    except Exception:  # pragma: no cover - defensive
        return "<unscrubbable>"


# ---------------------------------------------------------------------------
# Public API.
# ---------------------------------------------------------------------------


def _fallback_safe_text() -> str:
    """Canonical safe fallback when the judge blocks and no reformulation."""
    return (
        "MINT n'a pas pu resumer ce document de maniere educative. "
        "Voici les chiffres bruts validés — tu peux les confirmer ou les corriger."
    )


async def judge_vision_output(
    summary: Optional[str],
    narrative: Optional[str],
    fields_summary: Optional[str] = None,
    *,
    api_key: Optional[str] = None,
) -> GuardVerdict:
    """Call Haiku 4.5 as LSFin judge on a Vision free-text bundle.

    Returns a ``GuardVerdict``. On API error / missing key / parse error,
    fail-closed: allow=False with reason="judge_unavailable" and a Sentry
    warning. Operators can hard-bypass via ``VISION_GUARD_ENABLED=false``
    which makes this function return allow=True with a warning log.

    Cost telemetry is computed best-effort from the ``usage`` block on the
    response and exposed via ``cost_usd``. Never logs raw Vision text —
    only PII-scrubbed previews.
    """
    if not _guard_enabled():
        logger.warning(
            "vision_guard: disabled via VISION_GUARD_ENABLED=false — output passes without check",
        )
        return GuardVerdict(allow=True, reason="guard_disabled_by_env")

    # Empty bundle shortcut — nothing to judge.
    if not any((summary, narrative, fields_summary)):
        return GuardVerdict(allow=True, reason="empty_bundle")

    # Resolve API key. We accept explicit override for tests + reuse the
    # standard settings path in prod.
    if api_key is None:
        try:
            from app.core.config import settings

            api_key = settings.ANTHROPIC_API_KEY
        except Exception:
            api_key = ""

    if not api_key:
        logger.warning("vision_guard: ANTHROPIC_API_KEY missing — fail-closed")
        return GuardVerdict(
            allow=False,
            reason="judge_unavailable",
            reformulation=_fallback_safe_text(),
        )

    try:
        from anthropic import AsyncAnthropic
    except ImportError:  # pragma: no cover - anthropic always installed in prod
        logger.warning("vision_guard: anthropic package missing — fail-closed")
        return GuardVerdict(
            allow=False,
            reason="judge_unavailable",
            reformulation=_fallback_safe_text(),
        )

    client = AsyncAnthropic(api_key=api_key, timeout=_TIMEOUT_S)
    user_prompt = _JUDGE_USER_TEMPLATE.format(
        summary=summary or "(none)",
        narrative=narrative or "(none)",
        fields_summary=fields_summary or "(none)",
    )

    try:
        response = await client.messages.create(
            model=HAIKU_MODEL,
            max_tokens=_MAX_TOKENS,
            system=_JUDGE_SYSTEM,
            tools=[_JUDGE_TOOL],
            tool_choice={"type": "tool", "name": "lsfin_compliance_verdict"},
            messages=[{"role": "user", "content": user_prompt}],
        )
    except Exception as exc:
        logger.warning("vision_guard: judge API error — fail-closed err=%s", exc)
        return GuardVerdict(
            allow=False,
            reason="judge_unavailable",
            reformulation=_fallback_safe_text(),
        )

    # Extract tool_use block.
    tool_input: Any = None
    for block in getattr(response, "content", []) or []:
        if getattr(block, "type", None) == "tool_use":
            tool_input = getattr(block, "input", None)
            break

    if tool_input is None:
        logger.warning("vision_guard: judge returned no tool_use — fail-closed")
        return GuardVerdict(
            allow=False,
            reason="judge_no_tool_use",
            reformulation=_fallback_safe_text(),
        )

    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except Exception:
            logger.warning("vision_guard: judge tool_input non-JSON — fail-closed")
            return GuardVerdict(
                allow=False,
                reason="judge_parse_error",
                reformulation=_fallback_safe_text(),
            )

    allow = bool(tool_input.get("allow", False))
    flagged = [
        c for c in (tool_input.get("flagged_categories") or [])
        if c in {
            "product_advice",
            "return_promise",
            "third_party_specific",
            "banned_term",
            "prescriptive_language",
        }
    ]
    reformulation = tool_input.get("reformulation")
    reason = (tool_input.get("reason") or "").strip() or "judged"

    # Defense-in-depth: if the judge shipped a reformulation, scrub it
    # through the coach ComplianceGuard Layer 1 to catch any residual
    # banned term the judge itself slipped in.
    if reformulation:
        reformulation = _sanitize_reformulation(reformulation)

    # Cost telemetry — scrubbed, no PII.
    cost_usd = 0.0
    usage = getattr(response, "usage", None)
    if usage is not None:
        try:
            cost_usd = _estimate_cost_usd(
                int(getattr(usage, "input_tokens", 0) or 0),
                int(getattr(usage, "output_tokens", 0) or 0),
            )
        except Exception:
            cost_usd = 0.0

    logger.info(
        "vision_guard: allow=%s flagged=%s cost_usd=%.6f reason=%s",
        allow, flagged, cost_usd, reason,
    )

    # When the judge blocks and returns no usable reformulation, surface
    # the canonical safe fallback so the caller always has something to
    # display (the raw numeric fields remain available independently).
    if not allow and not reformulation:
        reformulation = _fallback_safe_text()

    return GuardVerdict(
        allow=allow,
        flagged_categories=flagged,
        reformulation=reformulation,
        reason=reason,
        cost_usd=cost_usd,
    )


__all__ = [
    "GuardVerdict",
    "GuardCategory",
    "HAIKU_MODEL",
    "judge_vision_output",
]
