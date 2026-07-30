"""Phase 94 — closed-world citation gate parser.

Per CONTEXT D-01..D-13 :
- D-01 : citation format is `{{cite:<key>}}` ONLY (legacy bracketed
  square-bracket form is rejected — uniformity with Phase 93.5 bundle
  citation_allowlist annotations).
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
  placeholder body (M3 fix iter 1 — strip placeholders from the SCAN
  input before number detection ; the original `response_text` is
  preserved for substitution).
- D-08 : retry budget HARD-CAPPED at 1. Enforced by the `is_retry`
  argument — second-pass rejection forces FALLBACK.
- D-09 : verbatim FR reprompt addendum for missing citations.
- D-10 : verbatim FR templated fallback (no template variables — the
  D-10 string is a `str` constant, not an `f"..."`).
- D-12 : « affirmative verb + cited number » regex — rejection EVEN
  WITH a valid citation (LSFin no-promise doctrine).
- D-13 : banned-claim retry reprompts at the conditional ; the cited
  placeholder is preserved, only the verb is reframed.
"""
from __future__ import annotations

import re
import unicodedata as _unicodedata
from dataclasses import dataclass, field
from decimal import Decimal as _Decimal, InvalidOperation as _DecimalInvalid
from enum import Enum
from typing import TYPE_CHECKING, Iterable, Optional

import sentry_sdk

from app.services.coach.citation_registry import CITATION_REGISTRY, resolve
from app.services.coach.narrative_sleeve_lint import lint_sleeve

if TYPE_CHECKING:
    from app.schemas.narrative_sleeve import NarrativeSleeve
    from app.services.coach.grounding_pack import ProjectionGroundingPack


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
    r"\b(?:\d{1,3}(?:['  ]\d{3})+|\d+)(?:[.,]\d{1,2})?\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b"
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

# 7. D-12 — affirmative verb + immediate digit. Triggers
#    REJECTED_BANNED_CLAIM EVEN WITH a valid citation. The two patterns
#    (uncited number / banned claim) run independently per CONTEXT
#    specifics line 179.
#
# v1 scope : 2nd-person futur direct only (vous/tu × ferez/feras/aurez/
# auras/gagnerez/gagneras + immediate digit). Out of scope in v1 :
#   - 3rd-person ('rapportera', 'sera de', 'atteindra') — eval pack
#     measures false-negative rate per fixture category (Plan 94-03
#     Task 1 fixtures cit-31..cit-40 include 3rd-person variants for
#     measurement, NOT enforcement).
#   - infinitive promises ('faire 4%', 'rapporter 100 CHF').
#   - 'garanti' / 'optimal' / 'meilleur' — these are the LSFin
#     BANNED_TERMS surface, caught at compliance_guard.py:43-117, NOT
#     here. The two gates run independently per CONTEXT specifics line
#     179.
# Phase 96 fattens the regex if eval-pack 3rd-person false-negative rate
# exceeds 10% (per RESEARCH §Pitfall 6 walkback path).
_BANNED_AFFIRMATIVE_VERB_RE = re.compile(
    r"(?:vous|tu)\s+(?:ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# D-09 / D-10 / D-13 — verbatim FR string constants.
# Byte-equal to CONTEXT.md (UTF-8 with French accents). DO NOT introduce
# template variables (`f"..."`, `.format(...)`, `%s`) on these strings —
# determinism contract per D-10. Lint via `tools/checks/accent_lint_fr.py`.
# ---------------------------------------------------------------------------

# D-09 — verbatim FR reprompt for missing citations
REPROMPT_ADDENDUM_UNCITED: str = (
    "\n\nRAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. "
    "Si tu n'as pas la source pour un chiffre, écris "
    "« je n'ai pas cette donnée » à la place."
)


# ---------------------------------------------------------------------------
# P003 (2026-05-12) — user-input number awareness.
#
# The gate's pre-P003 exemption set (meta-quote, meta-negation, legal-article
# overlap, adjacent {{cite:<key>}}) did NOT include numbers that the user
# supplied in their own message. citation_grammar.py:147-149 nonetheless
# promised the narrator that such numbers were exempt — a prompt-code
# contract violation that caused FALLBACK on every first-prompt where the
# narrator legitimately echoed user-supplied data (cycle P003 root cause).
#
# `_normalize_user_number_token` strips Swiss thousand separators (apostrophe
# `'`, non-breaking space `\xa0`, regular space ` `), normalises decimal
# comma to dot, drops currency / duration / count suffixes, and casts the
# result to `Decimal` for set-membership comparison. Two textual forms
# `7600`, `7'600`, `7 600 CHF`, `7'600.00`, `7600,00`, `7'600 francs` all
# normalise to `Decimal("7600")` and match a user-supplied `7600`.
# ---------------------------------------------------------------------------

_USER_NUMBER_SUFFIX_RE = re.compile(
    r"\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?|%|ans?|mois|jours?|"
    r"semaines?|années?|trimestres?|comptes?|enfants?|personnes?)\s*$",
    re.IGNORECASE,
)


def _normalize_user_number_token(token: str) -> Optional[_Decimal]:
    """Return the canonical Decimal value of a numeric token, or None.

    Tolerant of Swiss notation : apostrophe / non-breaking space / regular
    space thousand separators ; comma OR dot decimal mark ; trailing unit
    (CHF / EUR / %, ans / mois / etc.). Returns None on any parse failure
    so callers can fail-open (treat unparseable tokens as not-user-input).
    """
    if not token:
        return None
    # Normalise whitespace (incl. NBSP) and Unicode chars.
    s = _unicodedata.normalize("NFKC", token).strip()
    # Drop trailing unit if any.
    s = _USER_NUMBER_SUFFIX_RE.sub("", s).strip()
    # Strip thousand separators (apostrophe + any whitespace).
    s = s.replace("'", "").replace(" ", "").replace(" ", "")
    # Normalise decimal comma → dot. Only one separator may remain at
    # this point ; if the string has both comma and dot, we trust the
    # later one to be the decimal mark.
    if "," in s and "." in s:
        # Drop the earlier separator (interpreted as thousands).
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif "," in s:
        s = s.replace(",", ".")
    try:
        return _Decimal(s)
    except _DecimalInvalid:
        return None


# Numeric extractor over a user message. Catches integer-like and decimal-
# like tokens, optionally followed by a currency / unit / count suffix
# matched by the gate's number-family regexes. The output is a frozenset
# of Decimal values keyed by canonical normalisation, so spelling variants
# in the narrator's echo still match.
_USER_NUMBER_EXTRACTION_RE = re.compile(
    r"\b\d{1,3}(?:[ ' ]\d{3})+(?:[.,]\d+)?"  # 7'600 / 300 000 / 1'234.56
    r"|\b\d+(?:[.,]\d+)?\b"  # 49 / 7600 / 7,5
)


def extract_user_input_numbers(text: str) -> frozenset[_Decimal]:
    """Extract numeric tokens from arbitrary user-supplied free text.

    Tolerates Swiss notation and intermixed prose. Returns a frozenset of
    canonical Decimal values for set-membership comparison inside the
    gate's number-detection pass.

    Examples :
      ``"j'ai 49 ans, 7'600 CHF, 300 000 CHF rachat, 5 comptes"``
        → frozenset({Decimal("49"), Decimal("7600"),
                     Decimal("300000"), Decimal("5")})
      ``""`` → frozenset()

    Per CONTEXT D-04 P003 amendment — single source of truth for the
    user-input exemption used by the gate (step 5b).
    """
    if not text:
        return frozenset()
    matches = _USER_NUMBER_EXTRACTION_RE.findall(text)
    out: set[_Decimal] = set()
    for raw in matches:
        normed = _normalize_user_number_token(raw)
        if normed is not None:
            out.add(normed)
    return frozenset(out)


def extract_gated_number_tokens(text: str) -> frozenset[_Decimal]:
    """Normalised values of tokens the gate's number-family regexes WOULD flag.

    Unlike `extract_user_input_numbers` (which grabs EVERY numeric token, incl.
    bare years and law-article numbers), this returns only the values carried by
    a currency / percent / duration UNIT — i.e. exactly the numbers that, if the
    narrator echoes them, would count against the closed-world citation
    requirement (step 5b).

    Used to build the receipt-grounding exemption (P0 #1114) from the RENDERED
    grounding block WITHOUT over-exempting incidental unit-less numbers: a bare
    `2026` (tax year) or `5` (`art. 5`) is never turned into an exemptable
    `2026 CHF` / `5 CHF` fabrication. The regulatory named-constant regex is
    intentionally excluded — it matches names, not narrator-echoable amounts.
    """
    if not text:
        return frozenset()
    out: set[_Decimal] = set()
    for pattern in (_RE_CURRENCY, _RE_PERCENT, _RE_DURATION):
        for m in pattern.finditer(text):
            normed = _normalize_user_number_token(m.group(0))
            if normed is not None:
                out.add(normed)
    return frozenset(out)

# D-13 — verbatim FR reprompt for banned-claim assertions
REPROMPT_ADDENDUM_BANNED_CLAIM: str = (
    "\n\nRAPPEL — Une projection est une scénario, pas une promesse. "
    "Reformule au conditionnel (« pourrait », « selon ce scénario », "
    "« si X reste constant »)."
)

# D-10 — verbatim FR fallback text (no template variables — DETERMINISM
# CONTRACT). String literal only ; no `f"..."`, no `.format(...)`, no `%s`.
FALLBACK_TEMPLATED_TEXT: str = (
    "Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, "
    "dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) "
    "et je peux t'orienter vers ce qui s'applique chez toi."
)


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
      (PASS branch) or the verbatim FALLBACK string (FALLBACK branch),
      or the original `response_text` when verdict is REJECTED_*.
    - `retry_needed` — True if the caller MUST reprompt the narrator
      (cf. D-08 hard-cap=1 retry).
    - `reprompt_addendum` — verbatim FR text appended to the user
      message on retry (D-09 uncited / D-13 banned-claim) ; `None` on
      PASS / FALLBACK.
    - `uncited_numbers_count` — count of detections that could not be
      resolved via the closed-world allowlist (D-07 contract).
    - `banned_claims_found` — tuple of D-12 banned-claim verb spans
      caught even WITH a citation (LSFin no-promise doctrine).
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
# gate() body — fattened in Plan 94-02 (Wave 1).
# ---------------------------------------------------------------------------


# Adjacency horizon (chars) used to bind a number to its `{{cite:<key>}}`
# placeholder. The narrator is instructed to keep the placeholder right
# next to the digit ; 80 chars covers typical surrounding punctuation,
# unit suffixes, and short clauses without bleeding into the next sentence.
_CITATION_ADJACENCY_CHARS = 80


def _strip_placeholders(
    response_text: str,
) -> tuple[str, list[tuple[int, int, int, int]]]:
    """Return the response text with `{{cite:<key>}}` placeholders removed.

    Also returns a sorted list of placeholder spans, each as a 4-tuple
    `(orig_start, orig_end, scan_start, scan_end)` mapping the original
    span back to its stripped-text position. Used by the gate to (a)
    run number detection on `scan_text` (placeholders removed — M3 fix
    iter 1, D-04#4) and (b) compute citation adjacency on the original
    `response_text`.
    """
    spans: list[tuple[int, int, int, int]] = []
    scan_chunks: list[str] = []
    cursor = 0
    scan_cursor = 0
    for m in _RE_CITE_PLACEHOLDER.finditer(response_text):
        s, e = m.start(), m.end()
        # Append the non-placeholder slice
        gap = response_text[cursor:s]
        scan_chunks.append(gap)
        scan_start = scan_cursor + len(gap)
        scan_cursor = scan_start
        spans.append((s, e, scan_start, scan_start))
        cursor = e
    scan_chunks.append(response_text[cursor:])
    return "".join(scan_chunks), spans


def _scan_to_orig_offset(
    scan_pos: int,
    placeholder_spans: list[tuple[int, int, int, int]],
) -> int:
    """Map a position in the stripped `scan_text` back to the position
    in the original `response_text`. Walks the placeholder span list
    and adds back the cumulative placeholder length for each span that
    sits at or before `scan_pos`.
    """
    offset = scan_pos
    for orig_start, orig_end, scan_start, _scan_end in placeholder_spans:
        if scan_start <= scan_pos:
            offset += orig_end - orig_start
        else:
            break
    return offset


def _has_adjacent_cite(
    response_text: str,
    orig_match_start: int,
    orig_match_end: int,
    active_allowlist: Optional[set[str]],
) -> tuple[bool, Optional[str]]:
    """True iff a `{{cite:<key>}}` placeholder appears within
    `_CITATION_ADJACENCY_CHARS` before or after the match span in the
    ORIGINAL `response_text`. Also returns the matched key string when
    found (or None).

    The closed-world allowlist check : when `active_allowlist` is not
    None, the key MUST be in the allowlist for the citation to count.
    Unknown keys are treated as uncited (D-07 closed-world contract).
    """
    window_start = max(0, orig_match_start - _CITATION_ADJACENCY_CHARS)
    window_end = min(len(response_text), orig_match_end + _CITATION_ADJACENCY_CHARS)
    window = response_text[window_start:window_end]
    for m in _RE_CITE_PLACEHOLDER.finditer(window):
        # Extract the key from `{{cite:<key>}}`.
        body = m.group(0)
        key = body[len("{{cite:"):-2]
        if active_allowlist is None or key in active_allowlist:
            return True, key
    return False, None


def _substitute_placeholders(
    response_text: str,
    ctx,
    *,                                                # keyword-only barrier (Pitfall 3)
    pack: "ProjectionGroundingPack | None" = None,
) -> str:
    """D-09 double-lookup. Tries `pack.entries[key]` first when a pack
    is supplied ; falls back to `CITATION_REGISTRY.resolve(key, ctx)`.

    Both paths cohabit during Phase 95 + 96 (CITATION_REGISTRY removal
    deferred post-96). When a pack is present AND a pack miss falls back
    to a registry hit (or no-op), a Sentry breadcrumb
    `coach.grounding_pack.fallback` is emitted for T-95-04 instrumentation.

    Phase 95 ships `pack=None` at all production call sites ; Phase 96 W2
    will populate the pack from financial_core consumer wrappers. The
    pack=None code path is byte-identical to the Phase 94 behaviour
    (registry-only) — see test_pack_none_preserves_phase_94_behavior.
    """
    def _swap(m: re.Match[str]) -> str:
        body = m.group(0)
        key = body[len("{{cite:"):-2]
        # D-09 step 1 — pack lookup if a pack is supplied
        if pack is not None:
            entry = pack.entries.get(key)
            if entry is not None:
                return str(entry.value)
            # Pack present but miss → instrument and fall through
            try:
                sentry_sdk.add_breadcrumb(
                    category="coach.grounding_pack.fallback",
                    message="pack miss -> registry lookup",
                    level="info",
                    data={"key": key, "reason": "pack_miss"},
                )
            except Exception:  # pragma: no cover — breadcrumb is fail-open
                pass
        # D-09 step 2 — registry fallback (unchanged Phase 94 path)
        resolved = resolve(key, ctx)
        return resolved if resolved is not None else body

    return _RE_CITE_PLACEHOLDER.sub(_swap, response_text)


def lint_response_sleeve(
    sleeve: "NarrativeSleeve | None",
) -> "NarrativeSleeve | None":
    """Phase 96 D-16 — middleware-ordering helper.

    The Phase 94 citation gate stays FIRST in the response chain (the
    ``gate()`` + ``_substitute_placeholders()`` pair above runs on the
    raw narrator output BEFORE this helper). After substitution AND
    BEFORE the response is serialised to the client, response-build
    code calls ``lint_response_sleeve(sleeve)`` — which is a no-op when
    the sleeve is ``None`` and delegates to
    ``narrative_sleeve_lint.lint_sleeve`` when the sleeve is populated.

    Centralising the None-guard here keeps caller sites terse and pins
    the documented invariant from CONTEXT D-16 (« linter never 500s the
    response » + « citation gate runs first »).
    """
    if sleeve is None:
        return None
    return lint_sleeve(sleeve)


def gate(
    response_text: str,
    ctx,  # CoachContext — typed `Any` to avoid a circular import
    citation_allowlist: Optional[Iterable[str]] = None,
    is_retry: bool = False,
    *,
    pack: "ProjectionGroundingPack | None" = None,
    user_input_numbers: Optional["frozenset[_Decimal]"] = None,
) -> GatedResponse:
    """Closed-world citation gate. Pure function, no I/O.

    Decision flow (CONTEXT D-08..D-13) :
    1. Empty / whitespace-only input → FALLBACK (defensive).
    2. M3 fix iter 1 (D-04#4) — strip `{{cite:<key>}}` placeholder
       bodies from a SCAN COPY of the text BEFORE running any number
       detection. Digits inside placeholder keys (e.g. timestamps in
       `{{cite:plafond_80000_chf_2026}}`) are exempt by construction.
       The original `response_text` is preserved for citation
       adjacency checks and final substitution.
    3. D-12 banned-claim scan on `scan_text` — affirmative verb +
       immediate digit triggers REJECTED_BANNED_CLAIM EVEN WITH a
       citation. On `is_retry=True`, the verdict collapses to
       FALLBACK (D-08 hard-cap).
    4. Legal-article spans (D-04#3) computed first on `scan_text` —
       they have priority and exempt interior digits.
    5. 4 number-family regexes (currency / percentage / duration /
       regulatory) iterated. Each match is :
       (a) skipped if it overlaps a legal-article span,
       (b) skipped if `is_meta_quoted` or `is_meta_negation` excuses,
       (c) checked for an adjacent `{{cite:<key>}}` within
           `_CITATION_ADJACENCY_CHARS` chars in the ORIGINAL
           `response_text` ; if absent OR if the key is not in the
           active allowlist (closed-world breach), it counts as
           uncited.
    6. Verdict :
       - any uncited number + `is_retry=False` → REJECTED_UNCITED +
         D-09 reprompt addendum, retry needed.
       - any uncited number + `is_retry=True` → FALLBACK + D-10
         templated text, no further retry.
       - otherwise → PASS, with `{{cite:<key>}}` placeholders
         substituted via `resolve()` (verbatim when resolve returns
         None).

    Args :
        response_text : narrator output as collected from the LLM.
        ctx : `CoachContext` (or None) — consumed by `resolve()` for
            `profile:` source kinds. Wave-1 stub passes None at most
            test sites.
        citation_allowlist : per-request union of bundle citation
            allowlists (Phase 93.5 D-18). When `None`, falls back to
            the global `CITATION_REGISTRY` keys.
        is_retry : True on the second call after a first rejection.
            Forces FALLBACK on any rejection (D-08 hard-cap).

    Returns :
        Frozen `GatedResponse`.
    """
    if not response_text or not response_text.strip():
        return GatedResponse(
            verdict=GateVerdict.FALLBACK,
            gated_text="",
            retry_needed=False,
            reprompt_addendum=None,
            uncited_numbers_count=0,
            banned_claims_found=(),
            inputs_hash=pack.inputs_hash if pack else None,
        )

    # D-04#4 (M3 fix iter 1) — strip placeholders from the SCAN copy.
    # The original `response_text` is preserved for citation adjacency
    # and substitution at step 6. The banned-claim scan (step 3) ALSO
    # uses `scan_text` so a fragment like « vous ferez {{cite:foo}} »
    # does NOT trigger (no digit follows the verb after strip).
    scan_text, placeholder_spans = _strip_placeholders(response_text)

    # D-07 — active allowlist resolution.
    active_allowlist: Optional[set[str]]
    if citation_allowlist is not None:
        active_allowlist = set(citation_allowlist)
    else:
        active_allowlist = set(CITATION_REGISTRY.keys())

    # Step 3 — D-12 banned-claim scan.
    banned_matches = _BANNED_AFFIRMATIVE_VERB_RE.findall(scan_text)
    if banned_matches:
        banned_tuple = tuple(banned_matches)
        if is_retry:
            return GatedResponse(
                verdict=GateVerdict.FALLBACK,
                gated_text=FALLBACK_TEMPLATED_TEXT,
                retry_needed=False,
                reprompt_addendum=None,
                uncited_numbers_count=0,
                banned_claims_found=banned_tuple,
                inputs_hash=pack.inputs_hash if pack else None,
            )
        return GatedResponse(
            verdict=GateVerdict.REJECTED_BANNED_CLAIM,
            gated_text=response_text,  # D-13 keeps the original text incl. cite
            retry_needed=True,
            reprompt_addendum=REPROMPT_ADDENDUM_BANNED_CLAIM,
            uncited_numbers_count=0,
            banned_claims_found=banned_tuple,
            inputs_hash=pack.inputs_hash if pack else None,
        )

    # Step 4 — legal-article span priority (D-04#3).
    legal_spans: list[tuple[int, int]] = [
        (m.start(), m.end()) for m in _RE_LEGAL_ARTICLE.finditer(scan_text)
    ]

    def _overlaps_legal(s: int, e: int) -> bool:
        for ls, le in legal_spans:
            if s < le and e > ls:
                return True
        return False

    # Step 5 — number detection passes.
    # P003 (2026-05-12) — step 5b adds a user-input exemption BEFORE the
    # adjacency check : if the matched numeric span normalises to a value
    # the user supplied in their own message (`user_input_numbers`), the
    # gate treats it as already-cited. This aligns the gate's behaviour
    # with the system-prompt fragment that has long promised this
    # exemption (citation_grammar.py:147-149 pre-P003). The
    # `user_input_numbers` set is passed by the coach_chat wrapper after
    # extracting numbers from `body.message` ; the regulatory v1 (Phase
    # 94 D-08) called `gate` without this kwarg, in which case the set
    # is empty and behaviour is byte-identical to pre-P003.
    user_inputs = user_input_numbers or frozenset()
    uncited_count = 0
    for pattern in (_RE_CURRENCY, _RE_PERCENT, _RE_DURATION, _RE_REGULATORY):
        for m in pattern.finditer(scan_text):
            s, e = m.start(), m.end()
            if _overlaps_legal(s, e):
                continue
            if is_meta_quoted(scan_text, s, e):
                continue
            if is_meta_negation(scan_text, s, e):
                continue
            # P003 step 5b — user-input exemption.
            if user_inputs:
                token_value = _normalize_user_number_token(scan_text[s:e])
                if token_value is not None and token_value in user_inputs:
                    continue
            # Map scan_text span back to response_text for adjacency check.
            orig_s = _scan_to_orig_offset(s, placeholder_spans)
            orig_e = _scan_to_orig_offset(e, placeholder_spans)
            cited, _key = _has_adjacent_cite(
                response_text, orig_s, orig_e, active_allowlist
            )
            if not cited:
                uncited_count += 1

    # Step 6 — verdict.
    if uncited_count > 0:
        if is_retry:
            return GatedResponse(
                verdict=GateVerdict.FALLBACK,
                gated_text=FALLBACK_TEMPLATED_TEXT,
                retry_needed=False,
                reprompt_addendum=None,
                uncited_numbers_count=uncited_count,
                banned_claims_found=(),
                inputs_hash=pack.inputs_hash if pack else None,
            )
        return GatedResponse(
            verdict=GateVerdict.REJECTED_UNCITED,
            gated_text=response_text,
            retry_needed=True,
            reprompt_addendum=REPROMPT_ADDENDUM_UNCITED,
            uncited_numbers_count=uncited_count,
            banned_claims_found=(),
            inputs_hash=pack.inputs_hash if pack else None,
        )

    # PASS — substitute placeholders via resolve() (D-09 double-lookup
    # when a pack is supplied ; registry-only fallback otherwise).
    gated_text = _substitute_placeholders(response_text, ctx, pack=pack)
    return GatedResponse(
        verdict=GateVerdict.PASS,
        gated_text=gated_text,
        retry_needed=False,
        reprompt_addendum=None,
        uncited_numbers_count=0,
        banned_claims_found=(),
        inputs_hash=pack.inputs_hash if pack else None,
    )


__all__ = [
    # Public dataclasses + enum
    "GateVerdict",
    "GatedResponse",
    # Public functions
    "gate",
    "is_meta_quoted",
    "is_meta_negation",
    # Verbatim FR string constants (D-09 / D-10 / D-13)
    "REPROMPT_ADDENDUM_UNCITED",
    "REPROMPT_ADDENDUM_BANNED_CLAIM",
    "FALLBACK_TEMPLATED_TEXT",
    "extract_user_input_numbers",
    "extract_gated_number_tokens",
    # Compiled regex (private but re-used by tests)
    "_RE_CURRENCY",
    "_RE_PERCENT",
    "_RE_LEGAL_ARTICLE",
    "_RE_DURATION",
    "_RE_REGULATORY",
    "_RE_CITE_PLACEHOLDER",
    "_BANNED_AFFIRMATIVE_VERB_RE",
]
