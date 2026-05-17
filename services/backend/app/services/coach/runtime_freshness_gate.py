# noqa: stale-regulatory-anchors — module documents the values it catches in its docstring + tests (not LLM-injected). Per Fix D opt-out convention.
"""Post-Stage-3-UAT (2026-05-17, obs #157) — runtime regulatory-value freshness gate.

Triple-defense layer (c) for stale-numeric-value LSFin risk. Sister to
`runtime_verb_gate` (D-CE-16(c) for banned verbs) ; this gate scans the
narrator's output for any literal CHF / EUR / USD / % / duration value that
matches a STALE entry in `app.services.regulatory.registry._PARAMETERS`
(i.e. a value tagged under `<category>.historical_limits.<year>` where the
SAME value is NOT in the canonical/current key). Fail-closed : if a stale
value slips through, return the LSFin-safe templated fallback.

Defense layers active in parallel :
    (a) prompt-doctrine — `citation_grammar._TOOL_USE_MANDATE` mandates
        `tool_use(get_regulatory_constant)` BEFORE emitting any regulatory
        non-`tool_*` citation key (Fix B).
    (b) toxic-example removal — `citation_grammar.py:564` no longer
        contains a literal stale value in a REJETÉ example (Fix A).
    (c) THIS MODULE — runtime regex on NFKC-normalised + zero-width-
        stripped narrator output (Fix C).
    (d) lefthook lint (planned, Fix D) — scan all
        `services/backend/app/services/coach/**.py` for any literal that
        also appears in `historical_limits.<year-not-current>` registry
        entries.

Why all layers : the citation gate (Phase 94) enforces FORMAT only
(presence of `{{cite:<key>}}`), not CONTENT freshness. The coach LLM can
emit `« 7'056 CHF {{cite:r3a_plafond_salarie_2026}} »` — the citation
gate accepts because the key is valid, but the VALUE is the stale 2024
figure hallucinated from training data. Without this freshness gate, any
year-tagged regulatory value the LLM hallucinates from a prior tax year
ships to the user with a citation chip that falsely asserts the value is
the official 2026 one.

User-echo exemption :
    The user may legitimately echo a historical figure (« j'ai versé
    7'056 l'an dernier ») and the narrator may echo it back ; per the
    same exemption pattern in `citation_parser.gate` step 5b, we skip
    matches that are ALSO present (verbatim, normalised) in
    `user_message`. Caller passes `user_message` explicitly.

Determinism contract :
    The fallback template is a verbatim string literal — INTENTIONALLY
    SHORTER than Phase 94's `FALLBACK_TEMPLATED_TEXT` so QA can
    distinguish a freshness-gate fallback from a citation-gate or
    verb-gate fallback. Sentry breadcrumb
    `coach.freshness_gate.fired` is emitted at the call site
    (coach_chat.py) when this gate returns (False, _FALLBACK_FR).

Threat coverage :
    - T-3a-stale (LLM emits 7'056 / 6'883 / 6'826 / 6'768 etc. with a
      2026 regulatory citation key) — value is in STALE_VALUES, gate
      catches.
    - T-lpp-stale, T-avs-stale, T-ifd-stale — same mechanism extends to
      every category with `historical_limits.*` keys in the registry.
    - T-future-anchor — a future toxic few-shot example in another
      file (e.g. a bundle fragment) would still be caught at runtime
      even if Fix A / B / D don't catch it at prompt-build / lint time.
    - T-paraphrase — values are exact integer-match ; no paraphrase
      attack surface since values are numbers, not lexemes.
    - T-NFKC-bypass — NFKC normalisation first.
    - T-thousand-separator-bypass — Swiss apostrophe `7'056`, no-sep
      `7056`, space-sep `7 056`, comma-sep `7,056` all normalised to
      the same int before matching.
    - T-info-disclosure — gate returns the template, never the
      offending narrator text.
"""
from __future__ import annotations

import re
import unicodedata
from functools import lru_cache

from app.services.regulatory.registry import _PARAMETERS


# Verbatim FR template — INTENTIONALLY SHORTER + tone consistent with
# `runtime_verb_gate._FALLBACK_FR` and Phase 94 `FALLBACK_TEMPLATED_TEXT`.
_FALLBACK_FR: str = "Je n'ai pas cette donnée à jour pour l'instant."

# Zero-width / invisible chars from runtime_verb_gate (kept in sync).
_ZERO_WIDTH_CHARS: frozenset[str] = frozenset({
    "​",  # ZERO WIDTH SPACE
    "‌",  # ZERO WIDTH NON-JOINER
    "‍",  # ZERO WIDTH JOINER
    "﻿",  # ZERO WIDTH NO-BREAK SPACE (BOM)
    "⁠",  # WORD JOINER
})


def _strip_zero_width(s: str) -> str:
    """Remove all zero-width / invisible chars from `s`."""
    if not s:
        return s
    if not any(c in _ZERO_WIDTH_CHARS for c in s):
        return s
    return "".join(c for c in s if c not in _ZERO_WIDTH_CHARS)


def _normalise_number_token(raw: str) -> int | None:
    """Strip Swiss / French / anglo thousand separators ; parse to int.

    Accepts : `7'056`, `7056`, `7 056`, `7 056`, `7,056`,
    `7.056` (when followed by a non-decimal context — rare ; we
    conservatively only strip `,` if 3-digit grouping is consistent).
    Returns None if the token is not parseable as a thousand-grouped
    integer.

    Pure function ; no I/O ; safe for high-call-frequency use.
    """
    s = re.sub(r"[\s']", "", raw)
    # Anglo-comma thousand separator : « 7,056 » → 7056. Skip if any
    # comma is followed by 1-2 digits (= decimal, not grouping).
    if "," in s:
        parts = s.split(",")
        if all(len(p) == 3 for p in parts[1:]) and parts[0].isdigit():
            s = "".join(parts)
        else:
            return None
    if not s.isdigit():
        return None
    try:
        return int(s)
    except (ValueError, TypeError):
        return None


@lru_cache(maxsize=1)
def _build_stale_value_set() -> frozenset[int]:
    """Compute the frozen set of stale-year regulatory integer values.

    Algorithm :
        1. CURRENT_INTS = {int(p.value) for p in _PARAMETERS where
           p.key does NOT match `*.historical_limits.<year>` AND
           p.value is numeric}.
        2. HISTORICAL_INTS = {int(p.value) for p in _PARAMETERS where
           p.key matches `*.historical_limits.<year>` AND p.value is
           numeric}.
        3. STALE_INTS = HISTORICAL_INTS - CURRENT_INTS.

    A historical value that ALSO appears in a current canonical key
    (e.g. 7'258 appears in both `pillar3a.max_with_lpp` AND
    `pillar3a.historical_limits.2025` because OFAS didn't change it
    for 2026) is NOT stale — it's still the right answer today.

    Cached via lru_cache : built once at first call, reused for the
    process lifetime. The registry is module-level immutable.
    """
    historical_pat = re.compile(r"\.historical_limits\.\d{4}$")
    current_ints: set[int] = set()
    historical_ints: set[int] = set()
    for p in _PARAMETERS:
        if not isinstance(p.value, (int, float)):
            continue
        # Ratios (e.g. 0.20 for 20%) — skip ; freshness gate only
        # protects nominal monetary / count thresholds, not ratios.
        if abs(p.value) < 100:
            continue
        ivalue = int(p.value)
        if historical_pat.search(p.key):
            historical_ints.add(ivalue)
        else:
            current_ints.add(ivalue)
    return frozenset(historical_ints - current_ints)


# Number-token regex : matches integer with optional Swiss apostrophe
# `'`, French space ` `, NBSP ` `, or anglo comma `,` thousand
# separators. Min length 4 digits (≥ 1000) to avoid false-positives on
# small numbers (ages, percent, counts).
_NUMBER_TOKEN_RE: re.Pattern[str] = re.compile(
    r"\b\d{1,3}(?:['  ,]\d{3})+\b|\b\d{4,}\b",
)


def gate(text: str, user_message: str = "") -> tuple[bool, str]:
    """Runtime freshness gate — fail-closed on stale regulatory values.

    Args:
        text: Narrator output (post-LLM, pre-Phase-94 citation gate).
        user_message: The user's most recent message in this turn —
            used to exempt legitimate user-echoes (« j'ai versé 7'056
            l'an dernier ») from triggering the gate. Pass empty string
            if not available.

    Returns:
        (passed, output) :
            - (True, text) — text contains no stale regulatory value
              (after NFKC + zero-width strip + thousand-separator
              normalisation) ; original string returned unchanged.
            - (False, _FALLBACK_FR) — at least one stale integer value
              detected in `text` that is NOT also present in
              `user_message`. The verbatim FR template is returned ;
              the narrator's text is NEVER leaked to the user.

    Empty-string / whitespace-only text is pass-through (True, text) —
    same convention as `runtime_verb_gate.gate`. Phase 94 citation
    gate owns the empty-input FALLBACK.
    """
    if not text or not text.strip():
        return (True, text)

    stale_set = _build_stale_value_set()
    if not stale_set:
        # Defensive : empty registry → no stale values → nothing to
        # block. Shouldn't happen in production but keep the gate
        # robust during tests with monkey-patched registry.
        return (True, text)

    normalised = unicodedata.normalize("NFKC", text)
    cleaned = _strip_zero_width(normalised)

    # User-echo exemption — pre-compute the set of stale ints present
    # in the user message ; matches in narrator output that are also in
    # the user message are not gate violations (legit echo).
    user_stale: set[int] = set()
    if user_message:
        u_norm = _strip_zero_width(unicodedata.normalize("NFKC", user_message))
        for m in _NUMBER_TOKEN_RE.finditer(u_norm):
            n = _normalise_number_token(m.group(0))
            if n is not None and n in stale_set:
                user_stale.add(n)

    for m in _NUMBER_TOKEN_RE.finditer(cleaned):
        n = _normalise_number_token(m.group(0))
        if n is not None and n in stale_set and n not in user_stale:
            return (False, _FALLBACK_FR)

    return (True, text)


__all__ = [
    "gate",
    "_FALLBACK_FR",
    "_ZERO_WIDTH_CHARS",
    "_build_stale_value_set",
    "_normalise_number_token",
]
