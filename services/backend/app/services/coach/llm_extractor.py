"""LLM extractor (Phase 91 Wave 1).

JSON-only Sonnet 4.5 call that augments the regex extractor (kept
forever as deterministic floor per CONTEXT D-09). Non-fatal: returns
empty `ExtractorOutput` on any failure path so the narrator pipeline
degrades to today's regex-only behavior.

Wave 1 status: defined + unit-tested. NOT WIRED into coach_chat
pipeline yet — Wave 2 (`91-02-PLAN.md`) does the integration behind
the `COACH_DUAL_LLM_ENABLED` flag.

Design references:
  - `.planning/phases/91-mvp-extractor-v2/RESEARCH.md` §3 (contract),
    §6 Pitfalls 1+3 (parsing, hallucinated source_quote)
  - `.planning/phases/91-mvp-extractor-v2/91-CONTEXT.md` D-04
    (anonymous chat, request-scoped state in Wave 2)
  - `.planning/phases/91-mvp-extractor-v2/91-01-PLAN.md` Task 1.2

Reuse (Karpathy #2 / RESEARCH §8 « Don't Hand-Roll »):
  - `LLMClient.generate(...)` — same retry policy + error envelope
    (`services/backend/app/services/rag/llm_client.py:112-149`).
  - JSON-fence regex pattern — same shape as
    `rag/orchestrator.py:_parse_vision_fields` lines 339-356.
  - Pydantic `ExtractorOutput.model_validate(...)` — schema-level
    enforcement of the key whitelist + confidence enum.

Sanitization invariant: callers MUST pass `user_message` and
`conversation_history` already sanitized (via
`coach_chat._sanitize_conversation_history` and the
`_INJECTION_PATTERNS` filter). Wave 2 wiring will satisfy this.
"""
from __future__ import annotations

import json
import logging
import re
from typing import Any

from pydantic import ValidationError

from app.services.coach.extractor_schema import ExtractedFact, ExtractorOutput
from app.services.rag.llm_client import LLMClient

logger = logging.getLogger(__name__)


# Verbatim from RESEARCH §3 lines 228-257 (FR JSON-only prompt).
# accent_lint_fr.py is enforced on this module — keep accents 100% FR.
EXTRACTOR_SYSTEM_PROMPT = """\
Tu es un EXTRACTEUR de faits financiers. Tu n'écris JAMAIS de prose pour l'utilisateur.
Sortie : JSON STRICT respectant le schéma fourni. Aucun autre texte.

INPUT : message utilisateur + 6 derniers tours + snapshot profil.

OUTPUT (JSON) :
{
  "facts": [
    {
      "key": "<one of the canonical keys>",
      "value": <number | string | boolean>,
      "confidence": "high" | "medium",
      "source_quote": "<verbatim user quote, max 80 chars>"
    }
  ],
  "intents": ["debt" | "housing" | "family" | "career" | "retirement" | "taxes"]
}

RÈGLES :
- Extrais SEULEMENT ce que l'utilisateur a explicitement dit.
- N'extrais pas ce qui est déjà dans le snapshot profil sauf si l'utilisateur le corrige.
- Confidence "high" si le chiffre est exact (« 80'000 »). "medium" si arrondi (« environ 80k »).
  N'émets jamais "low" — si tu n'es pas sûr, n'émets pas le fait.
- source_quote DOIT être un extrait verbatim du message utilisateur. Si tu ne peux pas
  citer, n'émets pas le fait.
- Pas de prose. Pas de markdown. JSON UNIQUEMENT.
"""


_RETRY_PROMPT_SUFFIX = (
    "\n\nVotre réponse précédente n'était pas un JSON valide. "
    "Retournez UNIQUEMENT l'objet JSON, sans préambule, sans markdown."
)


# Same regex pattern as `rag/orchestrator.py:341` (RESEARCH §6 Pitfall 1).
# Handles ```json\n{...}\n``` and ```\n{...}\n``` fences.
_JSON_FENCE_RE = re.compile(r"```(?:json)?\s*([\s\S]*?)```", re.DOTALL)


def _extract_json_payload(text: str) -> dict[str, Any]:
    """Parse extractor LLM output into a dict.

    Handles:
      - raw JSON: `{...}`
      - markdown fence: ```json\\n{...}\\n```
      - generic fence:  ```\\n{...}\\n```

    Raises `ValueError` on failure (caller treats this identically to
    a Pydantic `ValidationError` and triggers retry).
    """
    text = (text or "").strip()
    if not text:
        raise ValueError("empty response")

    # Try fenced first.
    match = _JSON_FENCE_RE.search(text)
    if match:
        candidate = match.group(1).strip()
    else:
        # Fallback: first `{` ... last `}`.
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            raise ValueError("no JSON object found")
        candidate = text[start : end + 1]

    try:
        parsed = json.loads(candidate)
    except json.JSONDecodeError as exc:
        raise ValueError(f"json decode failed: {exc}") from exc

    if not isinstance(parsed, dict):
        raise ValueError(f"expected JSON object, got {type(parsed).__name__}")
    return parsed


def _drop_hallucinated_quotes(
    output: ExtractorOutput, user_message: str
) -> ExtractorOutput:
    """source_quote substring check — drop facts whose quote isn't in
    the user message.

    Per RESEARCH §6 Pitfall 3 (« hallucinated source_quote ») + §3
    « source_quote DOIT être un extrait verbatim ».

    Comparison: case-insensitive, whitespace-collapsed (matches the LLM's
    propensity to insert/strip spaces around quoted text). Logging
    uses only `fact.key` — never the source_quote string — to avoid
    leaking PII in logs (T-91-W1-05 mitigation).
    """
    haystack = re.sub(r"\s+", " ", user_message.lower()).strip()
    kept: list[ExtractedFact] = []
    for fact in output.facts:
        needle = re.sub(r"\s+", " ", fact.source_quote.lower()).strip()
        if needle and needle in haystack:
            kept.append(fact)
        else:
            logger.info(
                "llm_extractor: dropped fact with hallucinated source_quote (key=%s)",
                fact.key,
            )
    return ExtractorOutput(facts=kept, intents=output.intents)


def _normalize_text(response: Any) -> str:
    """Normalize `LLMClient.generate(...)` return to a plain text string.

    The real signature returns `str | dict`:
      - `str` when the call had no tools and no usage metadata.
      - `dict` with key `text` when usage metadata is present
        (`{"text": "...", "usage_tokens": N}`) or tool_calls
        (we never pass tools here, so tool_calls is empty).

    See `services/backend/app/services/rag/llm_client.py:112-149,
    283-300`.
    """
    if isinstance(response, str):
        return response
    if isinstance(response, dict):
        return str(response.get("text", "") or "")
    # Defensive: unknown shape.
    return ""


async def _call_once(
    *,
    system_prompt: str,
    user_message: str,
    conversation_history: list[dict],
    profile_snapshot: dict,
    client: LLMClient,
) -> ExtractorOutput:
    """Single attempt: LLM call → parse → validate. Raises on failure."""
    # Profile snapshot is appended to system prompt as a JSON block
    # (RESEARCH §3 Input section). Sorted keys for determinism.
    snapshot_json = json.dumps(profile_snapshot, ensure_ascii=False, sort_keys=True)
    full_system = f"{system_prompt}\n\nSNAPSHOT PROFIL ACTUEL :\n{snapshot_json}"

    response = await client.generate(
        system_prompt=full_system,
        user_message=user_message,
        context_chunks=[],
        tools=None,
        conversation_history=conversation_history,
    )
    text = _normalize_text(response)
    payload = _extract_json_payload(text)
    return ExtractorOutput.model_validate(payload)


async def run_llm_extractor(
    *,
    user_message: str,
    conversation_history: list[dict],
    profile_snapshot: dict,
    api_key: str,
    provider: str,
    model: str = "claude-sonnet-4-5-20250929",
    client: LLMClient | None = None,
) -> ExtractorOutput:
    """Run the LLM extractor.

    Returns `ExtractorOutput(facts=[], intents=[])` on any failure
    (non-fatal degradation per RESEARCH §3 Failure mode).

    Args:
        user_message: Already-sanitized user message
            (caller MUST pass through `_sanitize_conversation_history` /
            `_INJECTION_PATTERNS` filter — Wave 2 invariant).
        conversation_history: Last 6 turns, sanitized.
        profile_snapshot: Compact dict of current profile fields,
            sanitized (Wave 2 wiring uses
            `_sanitize_profile_context`).
        api_key: BYOK API key — passed to `LLMClient` constructor.
        provider: Provider name (currently only "claude" exercised in
            production; the BYOK contract supports "openai"/"mistral"
            but the extractor JSON prompt is FR-tuned for Claude).
        model: Model id. Default = Sonnet 4.5 per CONTEXT D-01
            (extractor stays Sonnet ; narrator switches to Haiku
            in Wave 2 behind the eval gate).
        client: Optional pre-built `LLMClient` (test injection).
            When None, a fresh client is built from
            `(provider, api_key, model)`.

    Wave 1 status: NOT YET CALLED from `coach_chat.py` — Wave 2
    wires it behind `COACH_DUAL_LLM_ENABLED`.
    """
    if not (user_message or "").strip():
        return ExtractorOutput()

    if client is None:
        client = LLMClient(provider=provider, api_key=api_key, model=model)

    # Attempt 1.
    try:
        out = await _call_once(
            system_prompt=EXTRACTOR_SYSTEM_PROMPT,
            user_message=user_message,
            conversation_history=conversation_history,
            profile_snapshot=profile_snapshot,
            client=client,
        )
        return _drop_hallucinated_quotes(out, user_message)
    except (ValueError, ValidationError) as exc:
        logger.warning(
            "llm_extractor: attempt 1 failed (%s) — retrying",
            type(exc).__name__,
        )
    except Exception as exc:  # noqa: BLE001 — non-Validation = no retry.
        logger.warning(
            "llm_extractor: attempt 1 unexpected error (%s) — empty fallback",
            type(exc).__name__,
        )
        return ExtractorOutput()

    # Attempt 2 (retry with explicit re-prompt).
    try:
        retry_prompt = EXTRACTOR_SYSTEM_PROMPT + _RETRY_PROMPT_SUFFIX
        out = await _call_once(
            system_prompt=retry_prompt,
            user_message=user_message,
            conversation_history=conversation_history,
            profile_snapshot=profile_snapshot,
            client=client,
        )
        return _drop_hallucinated_quotes(out, user_message)
    except (ValueError, ValidationError) as exc:
        logger.warning(
            "llm_extractor: attempt 2 failed (%s) — empty fallback",
            type(exc).__name__,
        )
        return ExtractorOutput()
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "llm_extractor: attempt 2 unexpected error (%s) — empty fallback",
            type(exc).__name__,
        )
        return ExtractorOutput()
