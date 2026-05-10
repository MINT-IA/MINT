"""Phase 94 Wave 0 — closed-world citation gate parser primitives.

Per CONTEXT D-01..D-04 :
- D-01 : citation format is `{{cite:<key>}}` (NEVER `[citation:source_id]`).
- D-02 : 5 number-family regex (currency / percentage / legal article /
  duration / regulatory constant) compiled at module import time. Pure
  Python `re` — no NLP library, no LLM call, ≤50ms target on 200-token
  narrator output (D-17).
- D-03 : `is_meta_quoted` + `is_meta_negation` are PUBLIC API (renamed
  from `_is_meta_*` private aliases in `tools/eval_narrator.py:250-296`)
  — single source of truth, consumed by both the runtime gate AND the
  eval-time scorer. The eval module re-imports + re-binds the underscore
  aliases for backward compat.
- D-04 : a number is allowed without `{{cite:}}` ONLY when (1) inside a
  meta-negation context, (2) inside a meta-quote, (3) part of a legal
  article reference itself, or (4) inside an explicit `{{cite:...}}`
  placeholder body. Wave 0 ships the primitives ; Plan 94-02 wires the
  full `gate()` body.

Wave 0 status — `gate()` is a SKELETON returning PASS / FALLBACK based
on whether `response_text.strip()` is non-empty. The fattened body
(allowlist intersect, banned-claim regex, retry-once flow, sentry
breadcrumbs) lands in Plan 94-02.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable, Optional


# ---------------------------------------------------------------------------
# FR-aware character class — copy-verbatim from compliance_guard.py:121.
# Single canonical literal (L1 fix iter 1) ; kept in sync with the
# compliance_guard banned-term scanner.
# ---------------------------------------------------------------------------

_FR_LETTER = r"a-zA-ZÀ-ÿ"


# ---------------------------------------------------------------------------
# D-02 — 5 number-family regex (compiled at module import time).
# Bounded quantifiers ({1,3}, \d+ with explicit unit) — ReDoS-safe per
# compliance_guard.py:607-609 precedent. Threat T-94-01 mitigated by
# tests/test_citation_gate/test_regex_engine_performance.py.
# ---------------------------------------------------------------------------

# 1. CHF / EUR / USD / fr. amounts. Apostrophe + non-breaking space + regular
#    space tolerated as group separator. Decimals via `,` or `.`. Unit MUST
#    follow the digits (D-02 spec — `CHF 80000` is out of scope).
_RE_CURRENCY = re.compile(
    r"\b\d{1,3}(?:['  ]\d{3})*(?:[.,]\d{1,2})?\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b"
)

# 2. Percentages — `4%`, `4.5%`, `4,5%`, `100 %`.
_RE_PERCENT = re.compile(r"\b\d{1,3}(?:[.,]\d{1,2})?\s*%")

# 3. Legal article references (Swiss law abbreviations). Captures the whole
#    reference span — by D-04#3 the article reference IS the citation.
_RE_LEGAL_ARTICLE = re.compile(
    r"\bart\.?\s*\d+(?:\s*al\.?\s*\d+)?\s*(?:LIFD|LPP|LAVS|LCA|LPCC|OPP[23]?|OCC|LHID|CO)\b"
)

# 4. Time durations — `5 ans`, `3 mois`, `30 jours`, `2 années`, `4 trimestres`.
_RE_DURATION = re.compile(
    r"\b\d+\s*(?:ans?|mois|jours?|semaines?|années?|trimestres?)\b"
)

# 5. Regulatory constants by name — case-insensitive (named constants are
#    a numeric claim by reference, not just a noun).
_RE_REGULATORY = re.compile(
    r"(?:taux\s+de\s+conversion|plafond\s+3a|bar[èe]me\s+LIFD|coefficient\s+\w+)",
    re.IGNORECASE,
)

# 6. Citation placeholder body — `{{cite:r3a_plafond_2026}}`. Used by the
#    gate to STRIP the placeholder span before number detection (D-04#4) so
#    digits inside the key don't false-trigger the regex above. Plan 94-02
#    Task 1 step 2 consumes this. Single brace / whitespace inside MUST NOT
#    match (defensive — narrator MUST emit the canonical form).
_RE_CITE_PLACEHOLDER = re.compile(r"\{\{cite:[A-Za-z0-9_\-]+\}\}")


# ---------------------------------------------------------------------------
# FR negation lexicon — port from `tools/eval_narrator.py:243-247`.
# Single source of truth (D-03) ; the eval module re-imports the helpers
# below and the eval-local `_NEGATION_RE` is deleted.
# ---------------------------------------------------------------------------

_NEGATION_RE = re.compile(
    r"\b(?:aucun(?:e|s)?|pas\s+(?:de|d['’])|n['’]est\s*(?:pas)?|n['’]existe\s*pas"
    r"|il\s+n['’]y\s+a\s+pas|sans\s+aucun(?:e)?|jamais)\b",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# D-03 — meta-helpers (PUBLIC API).
# Verbatim port of `_is_meta_quoted` + `_is_meta_negation` from
# `tools/eval_narrator.py:250-296`. H2 fix iter 1 — names are public
# (no leading underscore) because they are consumed by both the runtime
# gate and the eval scorer.
# ---------------------------------------------------------------------------


def is_meta_quoted(response: str, match_start: int, match_end: int) -> bool:
    """True if the match is wrapped in a quote pair on the same line.

    Recognized quote pairs : French guillemets (« »), straight double
    quotes ("), curly double quotes (“ ”). The match span MUST be
    INSIDE the quote pair on the same logical line (no newline crossing).
    """
    line_start = response.rfind("\n", 0, match_start) + 1
    line_end_idx = response.find("\n", match_end)
    line_end = line_end_idx if line_end_idx != -1 else len(response)
    pre = response[line_start:match_start]
    post = response[match_end:line_end]

    # French guillemets
    if "«" in pre and "»" in post:
        if pre.count("«") > pre.count("»") and post.count("»") > post.count("«"):
            return True
    # Straight double quotes — odd count before AND after means we're inside
    if pre.count('"') % 2 == 1 and post.count('"') % 2 == 1:
        return True
    # Curly double quotes
    if "“" in pre and "”" in post:
        if pre.count("“") > pre.count("”") and post.count("”") > post.count("“"):
            return True
    return False


def is_meta_negation(response: str, match_start: int, match_end: int) -> bool:
    """True if a FR negation marker appears in the same sentence as the match.

    Negation can be either before the term ("aucun X n'est <T>") or after
    it ("le <T> n'existe pas"). The scope is the sentence boundary on
    both sides — the marker MUST be in the same sentence, not just nearby.

    Sentence boundaries : `.`, `!`, `?` followed by whitespace, OR a
    blank line (`\n\n`). 250-char horizon caps the scan.
    """
    boundary_re = re.compile(r"[.!?]\s+|\n\n")

    sentence_start = max(0, match_start - 250)
    for m in boundary_re.finditer(response[sentence_start:match_start]):
        sentence_start = sentence_start + m.end()

    horizon_end = min(len(response), match_end + 250)
    sentence_end = horizon_end
    m = boundary_re.search(response[match_end:horizon_end])
    if m:
        sentence_end = match_end + m.start()

    sentence = response[sentence_start:sentence_end]
    return bool(_NEGATION_RE.search(sentence))


# ---------------------------------------------------------------------------
# Public dataclasses — gate verdict + structured response.
# ---------------------------------------------------------------------------


class GateVerdict(str, Enum):
    """Closed-world citation gate verdict (CONTEXT GATE-01..04)."""

    PASS = "pass"
    REJECTED_UNCITED = "rejected_uncited"
    REJECTED_BANNED_CLAIM = "rejected_banned_claim"
    FALLBACK = "fallback"


@dataclass(frozen=True)
class GatedResponse:
    """Structured output of `gate()`.

    Fields :
    - `verdict` — `GateVerdict` enum.
    - `gated_text` — narrator response after placeholder substitution
      (Wave 0 skeleton : echoes the input verbatim ; Plan 94-02 fattens).
    - `retry_needed` — True if the caller MUST reprompt the narrator
      (cf. D-08 hard-cap=1 retry).
    - `reprompt_addendum` — verbatim FR text appended to the user
      message on retry (D-09 / D-13).
    - `uncited_numbers_count` — count of detections that could not be
      resolved via the closed-world allowlist. Plan 94-02 populates.
    - `banned_claims_found` — tuple of D-12 banned-claim verb spans
      caught even WITH a citation. Plan 94-02 populates.
    - `inputs_hash` — Phase 95 stub field. Always `None` in Phase 94.
    """

    verdict: GateVerdict
    gated_text: str
    retry_needed: bool
    reprompt_addendum: Optional[str]
    uncited_numbers_count: int = 0
    banned_claims_found: tuple[str, ...] = field(default_factory=tuple)
    inputs_hash: Optional[str] = None  # Phase 95 stub


# ---------------------------------------------------------------------------
# Wave 0 skeleton — Plan 94-02 fattens.
# ---------------------------------------------------------------------------


def gate(
    response_text: str,
    ctx,  # CoachContext — typed `Any` in Wave 0 to avoid circular import
    citation_allowlist: Optional[Iterable[str]] = None,
    is_retry: bool = False,
) -> GatedResponse:
    """Closed-world citation gate. Pure function, no I/O.

    Wave 0 skeleton — Plan 94-02 fattens.

    The fattened version (Plan 94-02) will :
    1. Strip `{{cite:<key>}}` placeholder bodies via `_RE_CITE_PLACEHOLDER`
       so digits inside the key don't false-trigger detection (D-04#4).
    2. Run the 5 D-02 regex over the stripped text.
    3. For each match, check meta-quote / meta-negation excuses (D-03 / D-04#1-2).
    4. For un-excused matches, demand an adjacent `{{cite:<key>}}` whose
       key is in the allowlist union (D-07 closed-world contract).
    5. Run the D-12 banned-claim regex even on cited numbers — affirmative
       verbs ("vous ferez") force REJECTED_BANNED_CLAIM.
    6. On rejection : if `is_retry=False` → `retry_needed=True` +
       reprompt addendum (D-09 / D-13). If `is_retry=True` →
       `verdict=FALLBACK` + templated text (D-10).

    Wave 0 contract : non-empty input → PASS verdict (echo) ; empty /
    whitespace-only input → FALLBACK verdict (empty text).

    Args :
        response_text : narrator output as collected from the LLM.
        ctx : `CoachContext` (consumed by Plan 94-02 for `resolve()`).
        citation_allowlist : per-request union of bundle citation_allowlists
            (Phase 93.5 D-18). When `None`, falls back to the global
            `CITATION_REGISTRY` keys (Plan 94-02 wires this).
        is_retry : True on the second call after a first rejection.

    Returns :
        `GatedResponse` with `verdict` ∈ {PASS, FALLBACK} in Wave 0.
    """
    if not response_text or not response_text.strip():
        return GatedResponse(
            verdict=GateVerdict.FALLBACK,
            gated_text="",
            retry_needed=False,
            reprompt_addendum=None,
            uncited_numbers_count=0,
            banned_claims_found=(),
            inputs_hash=None,
        )

    return GatedResponse(
        verdict=GateVerdict.PASS,
        gated_text=response_text,
        retry_needed=False,
        reprompt_addendum=None,
        uncited_numbers_count=0,
        banned_claims_found=(),
        inputs_hash=None,
    )


__all__ = [
    # Public dataclasses + enum
    "GateVerdict",
    "GatedResponse",
    # Public functions
    "gate",
    "is_meta_quoted",
    "is_meta_negation",
    # Compiled regex (private but re-used by tests)
    "_RE_CURRENCY",
    "_RE_PERCENT",
    "_RE_LEGAL_ARTICLE",
    "_RE_DURATION",
    "_RE_REGULATORY",
    "_RE_CITE_PLACEHOLDER",
]
