"""
Deterministic profile fact extractor.

Runs BEFORE the LLM in coach_chat.py. Parses the raw user message with regex
patterns and returns a list of Fact records ready to be persisted as
CoachInsightRecord rows (same storage as the LLM-driven save_insight tool).

Rationale
---------
save_insight relies on Claude Sonnet's compliance with an imperative system
prompt. Even with explicit instructions, Claude is reluctant to call the tool
consistently. We therefore guarantee extraction on the backend with a simple,
auditable regex pass. When the LLM does call save_insight it will dedup by
(user_id, topic) so double-extraction is harmless — the deterministic pass
is a floor, not a ceiling.

Scope
-----
Only extract facts that are:
- Self-declared by the user (first-person claims)
- Short, unambiguous, and regex-detectable
- Relevant to financial profiling: age, salary, canton, city, marital
  status, family, LPP, 3a, debt

Anything ambiguous or narrative is left to the LLM.

Privacy
-------
No names, IBANs, SSN, or employers are ever captured. Values are truncated
to stay within the 200-char insight summary budget.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import Any, Iterable

# ---------------------------------------------------------------------------
# Fact record
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Fact:
    """A single extracted profile fact.

    Mirrors CoachInsightRecord fields (topic, insight_type, summary). The
    `value` field is advisory only — it is the parsed numeric/string form
    of the fact and is not persisted directly (the textual `text` carries
    it to the LLM on reload).

    SECURITY CONTRACT — `text` must be a **deterministic template** built
    from validated captures, never raw user input passthrough. On the
    anonymous path, `Fact.text` is injected into the system prompt as-is,
    so any leak of T-13-05 forbidden tokens (`outil|tool|dossier|profil|
    memoire|memory`) would break the information-disclosure guard. New
    extractors that echo user strings MUST scrub these tokens first. Tests:
    `test_profile_extractor_v2_patterns.py::test_facts_never_contain_forbidden_lexicon`.

    DOCTRINE — PII vs facts: the extractor runs on the raw (pre-scrub)
    message on the anonymous path by design, so salaries and LPP amounts
    ARE propagated to the LLM via the `<facts_user>` block. This is a
    conscious trade-off: without it the coach cannot cite the user's
    numbers and the MSG1 insight regresses to generic advice. The raw
    `question` field reaching the orchestrator stays scrubbed — the facts
    block is the narrow, explicit channel for numeric grounding.
    """

    topic: str  # "identity", "salary", "location", "household", "lpp", "3a", "debt"
    insight_type: str  # "fact" | "decision" | "preference"
    text: str  # Human-readable summary stored in CoachInsightRecord.summary
    value: Any = None  # Parsed value (int, str, bool) — advisory
    confidence: float = 1.0  # 0.0-1.0 — currently always 1.0 for regex hits


# ---------------------------------------------------------------------------
# Canton + city reference data
# ---------------------------------------------------------------------------

# 26 Swiss cantons — full names (FR/DE/IT) and ISO codes.
_CANTONS: dict[str, str] = {
    # Romandie
    "vaud": "VD",
    "genève": "GE",
    "geneve": "GE",
    "neuchâtel": "NE",
    "neuchatel": "NE",
    "jura": "JU",
    "valais": "VS",
    "fribourg": "FR",
    # Deutschschweiz
    "zurich": "ZH",
    "zürich": "ZH",
    "berne": "BE",
    "bern": "BE",
    "lucerne": "LU",
    "luzern": "LU",
    "zoug": "ZG",
    "zug": "ZG",
    "argovie": "AG",
    "aargau": "AG",
    "saint-gall": "SG",
    "st-gall": "SG",
    "st. gallen": "SG",
    "sankt gallen": "SG",
    "thurgovie": "TG",
    "thurgau": "TG",
    "soleure": "SO",
    "solothurn": "SO",
    "schaffhouse": "SH",
    "schaffhausen": "SH",
    "bâle-ville": "BS",
    "basel-stadt": "BS",
    "bâle-campagne": "BL",
    "basel-landschaft": "BL",
    "grisons": "GR",
    "graubünden": "GR",
    "graubunden": "GR",
    "uri": "UR",
    "schwyz": "SZ",
    "obwald": "OW",
    "obwalden": "OW",
    "nidwald": "NW",
    "nidwalden": "NW",
    "glaris": "GL",
    "glarus": "GL",
    "appenzell": "AR",  # Default to AR; AI rare
    # Ticino
    "tessin": "TI",
    "ticino": "TI",
}

# Major Swiss cities — mapped to their canton for enrichment.
_CITIES: dict[str, str] = {
    "lausanne": "VD",
    "montreux": "VD",
    "nyon": "VD",
    "yverdon": "VD",
    "vevey": "VD",
    "morges": "VD",
    "genève": "GE",
    "geneve": "GE",
    "carouge": "GE",
    "neuchâtel": "NE",
    "neuchatel": "NE",
    "la chaux-de-fonds": "NE",
    "delémont": "JU",
    "delemont": "JU",
    "sion": "VS",
    "sierre": "VS",
    "martigny": "VS",
    "monthey": "VS",
    "crans-montana": "VS",
    "verbier": "VS",
    "fribourg": "FR",
    "bulle": "FR",
    "zurich": "ZH",
    "zürich": "ZH",
    "winterthur": "ZH",
    "winterthour": "ZH",
    "berne": "BE",
    "bern": "BE",
    "bienne": "BE",
    "biel": "BE",
    "thun": "BE",
    "thoune": "BE",
    "lucerne": "LU",
    "luzern": "LU",
    "zoug": "ZG",
    "zug": "ZG",
    "aarau": "AG",
    "baden": "AG",
    "saint-gall": "SG",
    "st-gall": "SG",
    "st. gallen": "SG",
    "bâle": "BS",
    "basel": "BS",
    "bale": "BS",
    "lugano": "TI",
    "locarno": "TI",
    "bellinzone": "TI",
    "bellinzona": "TI",
    "coire": "GR",
    "chur": "GR",
    "davos": "GR",
    "st-moritz": "GR",
    "saint-moritz": "GR",
}


# ---------------------------------------------------------------------------
# Regex helpers
# ---------------------------------------------------------------------------

_NUM = r"(\d[\d'’\u00a0., ]*)"  # 95000, 95'000, 95 000, 95.000, 95’000


def _to_int(raw: str) -> int | None:
    """Normalize a CH-formatted number ('95’000', '95 000', '95.000') → int."""
    if raw is None:
        return None
    cleaned = re.sub(r"[^\d]", "", raw)
    if not cleaned:
        return None
    try:
        return int(cleaned)
    except ValueError:
        return None


def _clamp(s: str, n: int = 200) -> str:
    s = s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"


# ---------------------------------------------------------------------------
# Individual extractors
# ---------------------------------------------------------------------------


def _extract_age(msg: str) -> Fact | None:
    # "j'ai 34 ans", "j ai 34 ans", "I am 34", "34 years old"
    m = re.search(
        r"\b(?:j[' ]?ai|i(?:'| a)?m|i am|je suis .*?|ai)\s+(\d{1,2})\s*(?:ans?\b|years?[-\s]old)",
        msg,
        re.IGNORECASE,
    )
    if not m:
        m = re.search(r"\b(\d{2})\s*ans?\b", msg, re.IGNORECASE)
    if not m:
        m = re.search(r"\b(\d{2})\s*years?[-\s]old\b", msg, re.IGNORECASE)
    if m:
        age = int(m.group(1))
        if 16 <= age <= 99:
            return Fact(
                topic="identity",
                insight_type="fact",
                text=f"{age} ans",
                value=age,
            )

    # "né en 1985" / "born in 1985"
    m = re.search(r"\b(?:né(?:e)?\s+en|born\s+in)\s+(\d{4})\b", msg, re.IGNORECASE)
    if m:
        year = int(m.group(1))
        current = date.today().year
        if 1920 <= year <= current - 16:
            age = current - year
            return Fact(
                topic="identity",
                insight_type="fact",
                text=f"né·e en {year} (≈{age} ans)",
                value=year,
            )
    return None


def _extract_salary(msg: str) -> Fact | None:
    """Extract salary fact from a user message.

    Handles (in priority order):
    1. Monthly salaries with explicit "par mois" / "mensuel" / "/mois".
       Annualises × 12 with a 3k-40k/month plausibility gate — this is the
       dominant way Swiss residents state their income ("7600 Fr net /mois").
    2. Annual salaries with keyword ("gagne / salaire / revenu") or marker
       ("brut / net / par an").
    3. Short "XXk brut" form.
    """
    net_or_brut_marker = re.search(r"\b(brut|net)\b", msg, re.IGNORECASE)
    marker = (net_or_brut_marker.group(1).lower() if net_or_brut_marker else "brut")

    # ------------------------------------------------------------------
    # (1) Monthly salary — highest priority (most common natural phrasing).
    # If a monthly phrasing is present ANYWHERE in the message, we do NOT
    # fall through to the annual pass — otherwise "80000 francs par mois"
    # would be mis-detected as an annual salary of 80k.
    # ------------------------------------------------------------------
    has_monthly_context = bool(
        re.search(
            r"\b(?:par\s+mois|/\s*mois|mensuel(?:s|le)?|monthly)\b",
            msg,
            re.IGNORECASE,
        )
    )
    monthly_patterns = [
        # "7600 Fr net par mois", "7'600 CHF /mois", "8500 par mois"
        _NUM + r"\s*(?:chf|francs?|fr\.?)?\s*(?:brut|net)?\s*"
        r"(?:par\s+mois|/\s*mois|mensuel(?:s|le)?|monthly)",
        # "salaire mensuel (de) 6200", "mon salaire mensuel est de 6200"
        r"(?:salaire|revenu|income)\s+(?:mensuel(?:s|le)?|monthly)"
        r"[^\d]{0,12}" + _NUM,
    ]
    for pattern in monthly_patterns:
        m = re.search(pattern, msg, re.IGNORECASE)
        if not m:
            continue
        monthly = _to_int(m.group(1))
        if monthly is None:
            continue
        # Plausibility: 3k-40k/month (covers Geneva cadres, excludes rente +
        # CEO fantasy). 40k cap keeps annual ≤ 480k, inside the annual band.
        if not (3_000 <= monthly <= 40_000):
            continue
        annual = monthly * 12
        return Fact(
            topic="salary",
            insight_type="fact",
            text=f"{annual:,} CHF {marker}/an ({monthly:,}/mois)"
                 .replace(",", "'"),
            value=annual,
        )
    if has_monthly_context:
        # The user clearly stated a monthly figure. Don't invent an annual
        # one by pattern-matching the same number as CHF/year.
        return None

    # ------------------------------------------------------------------
    # (2) Annual salary / existing behaviour (kept verbatim for regression)
    # ------------------------------------------------------------------
    patterns = [
        # "XXk" or "XX k" short form with salary keyword
        (
            r"\b(?:gagne|salaire|revenu|earn|income|paid?)\s*[:\-]?\s*(\d{1,3})\s*k\b",
            1000,
        ),
        # "95'000 brut", "120000 CHF brut", "95000 par an"
        (
            r"(?:gagne|salaire|revenu|earn|income)[^\d]{0,12}"
            + _NUM
            + r"\s*(?:chf|francs?|fr\.?)?\s*(?:brut|net|par\s+an|/an|annuel|yearly)?",
            1,
        ),
        # "95'000 CHF brut" (salary-like amount with brut/net marker, no verb)
        (_NUM + r"\s*(?:chf|francs?|fr\.?)?\s*(?:brut|net)\b", 1),
    ]
    for pattern, multiplier in patterns:
        m = re.search(pattern, msg, re.IGNORECASE)
        if not m:
            continue
        raw = m.group(1)
        if multiplier == 1000:
            try:
                amount = int(raw) * 1000
            except ValueError:
                continue
        else:
            amount = _to_int(raw)
        if amount is None:
            continue
        # Plausibility gate: full-time Swiss salaries 15k-500k/year.
        if not (15_000 <= amount <= 500_000):
            continue
        return Fact(
            topic="salary",
            insight_type="fact",
            text=f"{amount:,} CHF {marker}/an".replace(",", "'"),
            value=amount,
        )
    return None


def _extract_canton_or_city(msg: str) -> Fact | None:
    lowered = msg.lower()
    # Location verbs: "je vis à X", "j'habite X", "I live in X", "based in X"
    loc_match = re.search(
        r"(?:je\s+vis\s+(?:à|en|au)|j[' ]?habite(?:\s+(?:à|en|au))?|"
        r"je\s+suis\s+(?:à|en|au|de)|i\s+live\s+in|based\s+in|"
        r"résid(?:e|ant)?\s+(?:à|en|au)|canton\s+(?:de|du))\s+"
        r"([a-zà-öø-ÿ\-\.\s]{2,30})",
        lowered,
    )
    candidate_blob = loc_match.group(1) if loc_match else lowered

    # Try canton names first (longer matches first to avoid "bern" matching before "berne-ville")
    for name, iso in sorted(_CANTONS.items(), key=lambda kv: -len(kv[0])):
        if re.search(rf"\b{re.escape(name)}\b", candidate_blob):
            return Fact(
                topic="location",
                insight_type="fact",
                text=f"canton {iso}",
                value=iso,
            )

    # ISO codes ("canton VS", "en VD") — require canton context to avoid false positives
    m = re.search(
        r"\bcanton\s+(?:de|du|d[' ])?\s*([A-Z]{2})\b", msg
    )
    if m and m.group(1) in set(_CANTONS.values()):
        return Fact(
            topic="location",
            insight_type="fact",
            text=f"canton {m.group(1)}",
            value=m.group(1),
        )

    # City names
    for city, iso in sorted(_CITIES.items(), key=lambda kv: -len(kv[0])):
        if re.search(rf"\b{re.escape(city)}\b", candidate_blob):
            # Capitalize city for storage
            pretty = city.title()
            return Fact(
                topic="location",
                insight_type="fact",
                text=f"{pretty} ({iso})",
                value=pretty,
            )
    return None


def _extract_marital_status(msg: str) -> Fact | None:
    patterns = [
        # Accept "marié", "mariée", "marie", "mariee" (accent-agnostic)
        (r"\b(?:je\s+suis\s+|suis\s+)?mari[ée]e?\b", "marié·e"),
        (r"\bmariee\b", "marié·e"),
        (r"\b(?:je\s+suis\s+|suis\s+)?c[ée]libataire\b", "célibataire"),
        (r"\b(?:je\s+suis\s+|suis\s+)?divorc[ée]e?\b", "divorcé·e"),
        (r"\b(?:je\s+suis\s+|suis\s+)?(?:veuf|veuve)\b", "veuf·ve"),
        (r"\ben\s+(?:couple|concubinage)\b", "en couple"),
        (r"\bpacs[ée]\b", "pacsé·e"),
        (r"\bi[' ]?(?:a)?m\s+married\b", "marié·e"),
        (r"\bi[' ]?(?:a)?m\s+single\b", "célibataire"),
        (r"\bi[' ]?(?:a)?m\s+divorced\b", "divorcé·e"),
    ]
    for pattern, label in patterns:
        if re.search(pattern, msg, re.IGNORECASE):
            return Fact(
                topic="household",
                insight_type="fact",
                text=label,
                value=label,
            )
    return None


def _extract_family(msg: str) -> Fact | None:
    # "j'ai 2 enfants", "avec deux enfants", "deux enfants", "1 enfant"
    # Look for a count token (digits or French word) immediately before "enfant".
    m = re.search(
        r"(\d+|\bun\b|\bune\b|\bdeux\b|\btrois\b|\bquatre\b)\s+enfants?\b",
        msg,
        re.IGNORECASE,
    )
    if m:
        word = m.group(1).lower()
        word_map = {"un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4}
        n: int | None
        if word in word_map:
            n = word_map[word]
        else:
            try:
                n = int(word)
            except ValueError:
                n = None
        if n is not None and 0 <= n <= 12:
            return Fact(
                topic="family",
                insight_type="fact",
                text=f"{n} enfant{'s' if n > 1 else ''}",
                value=n,
            )
    if re.search(r"\b(?:mon\s+fils|ma\s+fille|mes\s+enfants)\b", msg, re.IGNORECASE):
        return Fact(
            topic="family",
            insight_type="fact",
            text="a des enfants",
            value=True,
        )
    if re.search(r"\b(?:mon\s+(?:mari|conjoint|époux)|ma\s+(?:femme|conjointe|épouse))\b", msg, re.IGNORECASE):
        return Fact(
            topic="household",
            insight_type="fact",
            text="a un·e conjoint·e",
            value=True,
        )
    return None


def _extract_lpp(msg: str) -> Fact | None:
    """Extract a 2e-pilier / LPP amount.

    Covers the natural-language forms actually used by Swiss residents in
    addition to the technical lexicon:
    - Technical: `LPP`, `2e pilier`, `deuxième pilier`, `2nd pillar`
    - Natural: `valeur de rachat`, `caisse de pension`, `avoir de vieillesse`,
               `rachat possible`, `montant de rachat`
    All share the same plausibility band (1'000 – 5'000'000 CHF).
    """
    # Keyword set — ordered widest-first so the first hit wins.
    keywords = (
        r"lpp|2e\s+pilier|deuxi[èe]me\s+pilier|2nd\s+pillar|"
        r"valeur\s+de\s+rachat|caisse\s+de\s+pension|avoir\s+de\s+vieillesse|"
        r"rachat\s+(?:possible|maximum|max)|montant\s+de\s+rachat"
    )
    # Number AFTER keyword: "LPP 70'000", "valeur de rachat de 300 000"
    m = re.search(
        rf"\b(?:{keywords})[^\d]{{0,30}}" + _NUM + r"\s*(?:chf|k|francs?|fr\.?)?",
        msg,
        re.IGNORECASE,
    )
    # Number BEFORE keyword: "300'000 Fr de valeur de rachat".
    # REQUIRE an explicit currency marker (CHF / francs / Fr.) to avoid
    # capturing years ("en 2025 la caisse de pension a valu ...") — the
    # year would pass the 1'000-5'000'000 band silently.
    if not m:
        m = re.search(
            _NUM
            + r"\s*(?:chf|k|francs?|fr\.?)"
            + rf"(?:\s+\w+){{0,6}}\s+(?:{keywords})",
            msg,
            re.IGNORECASE,
        )
    if not m:
        return None
    raw = m.group(1)
    amount = _to_int(raw)
    if amount is None:
        return None
    # "k" suffix handling
    if re.search(r"\b\d{1,3}\s*k\b", m.group(0), re.IGNORECASE) and amount < 1000:
        amount *= 1000
    if not (1_000 <= amount <= 5_000_000):
        return None
    return Fact(
        topic="lpp",
        insight_type="fact",
        text=f"LPP ≈ {amount:,} CHF".replace(",", "'"),
        value=amount,
    )


def _extract_pillar3a(msg: str) -> Fact | None:
    kw = r"(?:3a|3e\s+pilier|troisi[èe]me\s+pilier|pillar\s*3a?)"
    # number AFTER keyword: "3a 32'000"
    m = re.search(kw + r"[^\d]{0,20}" + _NUM + r"\s*(?:chf|k|francs?)?", msg, re.IGNORECASE)
    # number BEFORE keyword: "32000 sur mon 3a"
    if not m:
        m = re.search(_NUM + r"\s*(?:chf|k|francs?)?(?:\s+\w+){0,4}\s+" + kw, msg, re.IGNORECASE)
    if m:
        raw = m.group(1)
        amount = _to_int(raw)
        if amount is not None:
            if re.search(r"\b\d{1,3}\s*k\b", m.group(0), re.IGNORECASE) and amount < 1000:
                amount *= 1000
            if 100 <= amount <= 2_000_000:
                return Fact(
                    topic="3a",
                    insight_type="fact",
                    text=f"3a ≈ {amount:,} CHF".replace(",", "'"),
                    value=amount,
                )
    return None


def _extract_debt(msg: str) -> Fact | None:
    # Negative explicit
    if re.search(
        r"\b(?:pas\s+de\s+dette|aucune\s+dette|sans\s+dette|no\s+debt)\b",
        msg,
        re.IGNORECASE,
    ):
        return Fact(
            topic="debt",
            insight_type="fact",
            text="pas de dette",
            value=False,
        )
    # Positive
    if re.search(
        r"\b(?:j[' ]?ai\s+(?:des?\s+)?dettes?|emprunts?|cr[ée]dit\s+(?:conso|personnel)|"
        r"i\s+have\s+debt|leasing\s+(?:voiture|auto))\b",
        msg,
        re.IGNORECASE,
    ):
        return Fact(
            topic="debt",
            insight_type="concern",
            text="a des dettes/emprunts",
            value=True,
        )
    return None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

_EXTRACTORS = (
    _extract_age,
    _extract_salary,
    _extract_canton_or_city,
    _extract_marital_status,
    _extract_family,
    _extract_lpp,
    _extract_pillar3a,
    _extract_debt,
)


def extract_profile_facts(
    user_message: str,
    current_profile: dict[str, Any] | None = None,
) -> list[Fact]:
    """Run all extractors on `user_message` and return the detected facts.

    Parameters
    ----------
    user_message : str
        The raw, sanitized (post-injection-filter) user message.
    current_profile : dict | None
        Optional snapshot of the user's current profile context. Used to
        suppress redundant extractions when the same value is already
        recorded. Matching is conservative — when in doubt we emit the
        fact and let CoachInsightRecord dedup by (user_id, topic).

    Returns
    -------
    list[Fact]
        Zero or more Fact records. Never raises; on any parsing error
        the offending extractor is skipped.
    """
    if not user_message or not isinstance(user_message, str):
        return []

    # Clamp message length to avoid regex pathologies.
    message = user_message[:4000]
    profile = current_profile or {}

    out: list[Fact] = []
    seen_topics: set[str] = set()
    for extractor in _EXTRACTORS:
        try:
            fact = extractor(message)
        except Exception:
            continue
        if fact is None:
            continue
        # One fact per topic per message — the LLM can still add nuance.
        if fact.topic in seen_topics:
            continue
        # Light suppression: if profile already has this scalar exactly, skip.
        if _already_known(fact, profile):
            continue
        seen_topics.add(fact.topic)
        out.append(
            Fact(
                topic=fact.topic,
                insight_type=fact.insight_type,
                text=_clamp(fact.text),
                value=fact.value,
                confidence=fact.confidence,
            )
        )
    return out


def _already_known(fact: Fact, profile: dict[str, Any]) -> bool:
    """Return True if `fact` is already represented in `profile`."""
    if fact.topic == "identity" and isinstance(fact.value, int):
        # Either age (2-digit) or birth year (4-digit)
        by = profile.get("birthYear") or profile.get("birth_year")
        if by and 1900 <= int(by) <= 2020:
            if 1000 <= fact.value <= 2020 and int(by) == int(fact.value):
                return True
            if fact.value < 120 and (date.today().year - int(by)) == fact.value:
                return True
    if fact.topic == "location" and isinstance(fact.value, str):
        canton = profile.get("canton")
        if canton and canton.upper() == fact.value.upper():
            return True
    if fact.topic == "household" and isinstance(fact.value, str):
        hh = (profile.get("householdType") or profile.get("household_type") or "").lower()
        if hh == "couple" and fact.value in {"marié·e", "en couple", "pacsé·e"}:
            return True
        if hh == "single" and fact.value in {"célibataire"}:
            return True
    if fact.topic == "debt" and isinstance(fact.value, bool):
        existing = profile.get("hasDebt")
        if existing is not None and bool(existing) == fact.value:
            return True
    return False


def facts_to_insight_rows(
    facts: Iterable[Fact],
    *,
    user_id: str,
) -> list[dict[str, Any]]:
    """Convert Fact records into kwargs for CoachInsightRecord creation.

    This helper exists so callers can keep the import of the SQLAlchemy
    model at the call site and keep this module free of DB coupling.
    """
    return [
        {
            "user_id": user_id,
            "topic": f.topic,
            "summary": f.text,
            "insight_type": f.insight_type,
        }
        for f in facts
    ]
