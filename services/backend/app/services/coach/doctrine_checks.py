"""Doctrine checks — Wave 6.5 mechanical evaluation.

Validates that a coach response follows the MINT information doctrine
(amended after adversarial panel 2026-04-18):

    Un chiffre exact avec sa source, ajusté à l'archétype et à l'événement
    de vie. Un verbe d'action — ou un passage de main explicite quand la
    décision est irréversible.

The 6 checks below are pure functions. They run post-LLM, independent of
`ComplianceGuard` (which enforces banned terms + legal guardrails) and
give a 0-100 score on doctrine adherence per response. Used by
`test_coach_doctrine_eval` to verify the amended rule in `_BASE_SYSTEM_PROMPT`
produces compliant output.

Adversarial-panel verdict integration:
  * Check 1 (numeric anchor) becomes *conditional*: an existential question
    may legitimately open with recognition before any figure.
  * Check 4 (action verb) accepts an explicit hand-off ("rendez-vous",
    "spécialiste", "pause") as a valid escalation action.
  * Check 5 (archetype aware) enforces that any non-`swiss_native` response
    carrying an imperative also names the archetype-specific constraint.
  * Check 6 (escalation aware) enforces that existential OR irreversible
    questions include a recognition verb OR a hand-off cue.

References:
  * `.planning/information-doctrine-2026-04-18/PANEL.md` — 5-expert panel
  * `.planning/information-doctrine-2026-04-18/ADVERSARIAL.md` — 3 cas de casse
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Optional

__all__ = [
    "QuestionMeta",
    "CheckResult",
    "DoctrineReport",
    "check_numeric_anchor",
    "check_concision",
    "check_banned_terms",
    "check_action_or_handoff",
    "check_archetype_aware",
    "check_escalation_aware",
    "score_response",
]


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class QuestionMeta:
    """Metadata about the question the coach is answering.

    `archetype` uses the enum documented in CLAUDE.md §5: swiss_native,
    expat_eu, expat_non_eu, expat_us, independent_with_lpp,
    independent_no_lpp, cross_border, returning_swiss.

    `life_event` is one of the 18 canonical events or None.

    `irreversible` = the user is about to trigger an irrevocable decision
        (rente vs capital choice, major EPL withdrawal, rachat LPP > 50k).

    `existential` = the question is not quantitative (divorce emotional
        framing, job loss panic, death of relative). The response may
        open with recognition before any number.
    """

    archetype: str = "swiss_native"
    life_event: Optional[str] = None
    irreversible: bool = False
    existential: bool = False


@dataclass(frozen=True)
class CheckResult:
    name: str
    passed: bool
    reason: str = ""


@dataclass(frozen=True)
class DoctrineReport:
    response: str
    meta: QuestionMeta
    checks: tuple[CheckResult, ...]

    @property
    def passed_count(self) -> int:
        return sum(1 for c in self.checks if c.passed)

    @property
    def total(self) -> int:
        return len(self.checks)

    @property
    def score(self) -> float:
        if self.total == 0:
            return 0.0
        return 100.0 * self.passed_count / self.total

    def failures(self) -> list[CheckResult]:
        return [c for c in self.checks if not c.passed]


# ---------------------------------------------------------------------------
# Regex building blocks
# ---------------------------------------------------------------------------

# Numbers like 7'258, 2.5, 30'240, 65.5%, 12, 100k
_NUMBER_UNIT = re.compile(
    r"\d[\d'.,\s]*\s*(CHF|chf|%|an[s]?\b|mois|années|année|ans|k)",
    re.IGNORECASE,
)

# Sentence split on ., !, ?, ;, : followed by space/newline OR end-of-string.
# Intentionally keeps markdown bold markers (**) harmless.
_SENTENCE_SPLIT = re.compile(r"(?<=[.!?;:])\s+(?=[A-ZÀ-ÿ**])|\n{2,}")

# Imperative 2nd-person singular — curated whitelist from panel + common
# French imperatives coach uses. Case-insensitive word-boundary.
_IMPERATIVE_VERBS = [
    "vérifie",
    "verifie",
    "compare",
    "ouvre",
    "demande",
    "simule",
    "ajoute",
    "contacte",
    "calcule",
    "planifie",
    "prends",
    "regarde",
    "attends",
    "pose",
    "note",
    "garde",
    "évalue",
    "evalue",
    "écris",
    "ecris",
    "envoie",
    "parle",
    "liste",
    "choisis",
    "décide",
    "decide",
    "consulte",
    "relis",
    "refais",
    "recalcule",
    "vois",
    "fais",
    "lis",
    "inscris",
    "rassemble",
    "rappelle",
    "organise",
    "classe",
    "estime",
    "mesure",
    "trouve",
    "cherche",
    "explore",
    "essaie",
    "teste",
    "valide",
    "active",
    "bloque",
    "débloque",
    "debloque",
    "paye",
    "paie",
    "verse",
    "retire",
    "dépose",
    "depose",
    "signe",
    "évite",
    "evite",
    "sépare",
    "separe",
    "gèle",
    "gele",
    "reporte",
    "accepte",
    "refuse",
    "négocie",
    "negocie",
]
_IMPERATIVE_RE = re.compile(
    r"(?:^|[\s*_\-])(?:" + "|".join(_IMPERATIVE_VERBS) + r")\b",
    re.IGNORECASE,
)

# Hand-off cues: explicit escalation OR invitation to pause, reflect,
# speak to a specialist. Covers the adversarial panel requirement that
# irreversible decisions pass the hand instead of imposing a CTA.
_HANDOFF_PATTERNS = [
    r"rendez[-\s]vous",
    r"rendez[-\s]vous avec un[·\s]e?\s*spécialiste",
    r"spécialiste",
    r"specialiste",
    r"prends le temps",
    r"prenons le temps",
    r"prends une pause",
    r"pause avant",
    r"ne décide pas tout de suite",
    r"ne decide pas tout de suite",
    r"pas de décision rapide",
    r"c[’']est une décision lourde",
    r"parle[z]?\s*(?:en)?\s*à un[·\s]e?\s*spécialiste",
    r"demande[z]?\s*à un[·\s]e?\s*spécialiste",
    r"voyons d['\s]abord",
    r"regarde la mécanique",
    r"regardons la mécanique",
    r"ensemble on regarde",
    r"ensemble, on regarde",
    r"ça dépend de",
    r"cela dépend de",
]
_HANDOFF_RE = re.compile("|".join(_HANDOFF_PATTERNS), re.IGNORECASE)

# Recognition verbs / phrases — accepted opener when existential question.
_RECOGNITION_PATTERNS = [
    r"\b(?:oui|non)\b,?\s*tu t['’]en sors",
    r"tu t['’]en sors",
    r"tu vas t['’]en sortir",
    r"ce que tu traverses",
    r"ce que tu vis",
    r"c['’]est dur",
    r"c['’]est brutal",
    r"je comprends ce que",  # acceptable *only* when not the LLM slop opener
    r"on prend le temps",
    r"voyons ensemble",
    r"regardons ensemble",
    r"tu n['’]es pas seul",
    r"tu n['’]es pas seule",
    r"respire",
    r"commence par",
]
_RECOGNITION_RE = re.compile("|".join(_RECOGNITION_PATTERNS), re.IGNORECASE)

# Banned terms — mirror the ComplianceGuard list; duplicated here so doctrine
# checks are independent of the guard's mutation pipeline.
_BANNED_WORDS = {
    "garanti",
    "garantie",
    "garantis",
    "garanties",
    "garantissant",
    "garantirait",
    "assuré",
    "assurée",
    "assurés",
    "assurées",
    "assurant",
    "sans risque",
    "optimal",
    "optimale",
    "optimaux",
    "optimales",
    "meilleur",
    "meilleure",
    "meilleurs",
    "meilleures",
    "parfait",
    "parfaite",
    "parfaits",
    "parfaites",
    "idéal",
    "idéale",
    "le mieux",
    "tu devrais",
    "tu dois",
    "il faut que tu",
    "promettant",
    "promet un rendement",
}

# Archetype-specific constraint vocabulary. If archetype ≠ swiss_native,
# at least one cue must appear anywhere in the response.
_ARCHETYPE_CUES: dict[str, list[str]] = {
    "expat_us": [
        r"FATCA",
        r"IRS",
        r"US person",
        r"foreign trust",
        r"PFIC",
        r"form\s*3520",
        r"double imposition",
        r"citoyen[·ne]*\s*américain",
        r"green\s*card",
    ],
    "expat_eu": [
        r"totalisation",
        r"accord bilatéral",
        r"convention\s*CH[- ]?UE",
        r"ALCP",
        r"périodes\s*(?:UE|européennes)",
    ],
    "expat_non_eu": [
        r"pas de convention",
        r"convention bilatérale",
        r"remboursement\s*(?:LPP|2e pilier)",
        r"départ définitif",
    ],
    "cross_border": [
        r"frontali[eè]r",
        r"permis\s*G",
        r"impôt\s*(?:à la\s*)?source",
        r"accord fiscal",
    ],
    "independent_no_lpp": [
        r"ind[ée]pendant[·e]*",
        r"sans\s*LPP",
        r"20\s*%\s*(?:du\s*)?revenu",
        r"36'?288",
    ],
    "independent_with_lpp": [
        r"ind[ée]pendant[·e]*",
        r"avec\s*LPP",
    ],
    "returning_swiss": [
        r"rachat",
        r"retour\s*en\s*Suisse",
        r"lacune",
    ],
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _strip_md(text: str) -> str:
    """Remove markdown noise that skews word-length counts."""
    t = re.sub(r"\*\*|__|`", "", text)
    return t.strip()


def _sentences(text: str) -> list[str]:
    clean = _strip_md(text)
    raw = _SENTENCE_SPLIT.split(clean)
    return [s.strip() for s in raw if s.strip()]


def _words(text: str) -> list[str]:
    return [w for w in re.split(r"\s+", _strip_md(text)) if w]


def _nfc_lower(text: str) -> str:
    return unicodedata.normalize("NFC", text).lower()


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------


def check_numeric_anchor(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 1 — numeric anchor in the first 2 sentences.

    Conditional: existential questions are *exempt* because the adversarial
    panel showed that imposing a figure on "vais-je m'en sortir ?" is
    experienced as glacial robotic coldness. The response still needs a
    figure anywhere, just not in the opener.
    """
    name = "numeric_anchor"
    sents = _sentences(response)
    if not sents:
        return CheckResult(name, False, "empty response")

    head = " ".join(sents[:2])
    has_head_number = bool(_NUMBER_UNIT.search(head))
    has_any_number = bool(_NUMBER_UNIT.search(response))

    if meta.existential:
        if not has_any_number:
            return CheckResult(
                name,
                False,
                "existential: no number anywhere (recognition alone is not enough)",
            )
        return CheckResult(name, True, "existential: recognition first, number later — OK")

    if not has_head_number:
        return CheckResult(
            name,
            False,
            "no digit+unit in first 2 sentences (CHF/%/an/mois/k)",
        )
    return CheckResult(name, True, "digit+unit in opener")


def check_concision(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 2 — ≤20 words/sentence, ≤120 words total.

    Existential and irreversible responses are allowed one 40-word opener
    (recognition/hand-off cadence) but the remainder still caps at 20.
    Total word cap goes up to 140 words when irreversible to accommodate
    hand-off framing.
    """
    name = "concision"
    sents = _sentences(response)
    if not sents:
        return CheckResult(name, False, "empty response")

    total_words = len(_words(response))
    cap_total = 140 if meta.irreversible or meta.existential else 120
    if total_words > cap_total:
        return CheckResult(
            name, False, f"{total_words} words > cap {cap_total}"
        )

    per_sent_cap = 20
    opener_cap = 40 if (meta.existential or meta.irreversible) else per_sent_cap
    for idx, s in enumerate(sents):
        cap = opener_cap if idx == 0 else per_sent_cap
        n = len(_words(s))
        if n > cap:
            return CheckResult(
                name,
                False,
                f"sentence {idx + 1}: {n} words > cap {cap}",
            )
    return CheckResult(name, True, f"{total_words} words / {len(sents)} sentences")


def check_banned_terms(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 3 — zero banned terms."""
    name = "no_banned_terms"
    t = _nfc_lower(response)
    hits: list[str] = []
    for term in _BANNED_WORDS:
        pat = r"(?:^|[^a-zA-ZÀ-ÿ])" + re.escape(term) + r"(?:$|[^a-zA-ZÀ-ÿ])"
        if re.search(pat, t):
            hits.append(term)
    if hits:
        return CheckResult(name, False, f"hit: {hits[:3]}")
    return CheckResult(name, True, "clean")


def check_action_or_handoff(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 4 — ≥1 imperative verb OR explicit hand-off.

    Panel rule required an imperative. Adversarial verdict relaxed this:
    on irreversible decisions, the right behavior is to pass the hand.
    A hand-off cue counts as the same category as an action.
    """
    name = "action_or_handoff"
    has_imp = bool(_IMPERATIVE_RE.search(response))
    has_handoff = bool(_HANDOFF_RE.search(response))

    if meta.irreversible:
        if has_handoff:
            return CheckResult(name, True, "hand-off present (irreversible)")
        if has_imp:
            # Irreversible + imperative is tolerated only if hand-off is also
            # present; otherwise the adversarial case 2 triggers.
            return CheckResult(
                name,
                False,
                "imperative without hand-off on irreversible decision",
            )
        return CheckResult(name, False, "no imperative and no hand-off")

    if has_imp or has_handoff:
        return CheckResult(name, True, "imperative or hand-off present")
    return CheckResult(name, False, "neither imperative nor hand-off")


def check_archetype_aware(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 5 — if archetype ≠ swiss_native, acknowledge constraint.

    Adversarial case 3: telling an expat_us "Verse 7'258 CHF sur ton 3a"
    without mentioning FATCA/PFIC/foreign-trust is a professional fault
    because most 3a providers refuse US persons. This check enforces that
    the response names at least one archetype-specific cue.
    """
    name = "archetype_aware"
    if meta.archetype == "swiss_native":
        return CheckResult(name, True, "swiss_native: no extra constraint")

    cues = _ARCHETYPE_CUES.get(meta.archetype, [])
    if not cues:
        return CheckResult(name, True, f"archetype {meta.archetype}: no cues defined — pass")

    lower = _nfc_lower(response)
    for pat in cues:
        if re.search(pat, lower, re.IGNORECASE):
            return CheckResult(name, True, f"{meta.archetype} cue found")
    return CheckResult(
        name,
        False,
        f"{meta.archetype} but response names no archetype-specific constraint",
    )


def check_escalation_aware(response: str, meta: QuestionMeta) -> CheckResult:
    """Check 6 — existential/irreversible → recognition or hand-off cue.

    Adversarial cases 1 (divorce existential) and 2 (rente vs capital
    irreversible) both failed when the response opened with a number and
    closed with a 3-word imperative. This check demands explicit softening.
    """
    name = "escalation_aware"
    if not (meta.existential or meta.irreversible):
        return CheckResult(name, True, "standard question: no escalation required")

    has_recog = bool(_RECOGNITION_RE.search(response))
    has_handoff = bool(_HANDOFF_RE.search(response))

    if meta.existential and not has_recog:
        return CheckResult(
            name,
            False,
            "existential: no recognition verb ('tu t'en sors', 'voyons ensemble', ...)",
        )
    if meta.irreversible and not has_handoff:
        return CheckResult(
            name,
            False,
            "irreversible: no hand-off cue ('rendez-vous', 'spécialiste', 'prends le temps', ...)",
        )
    return CheckResult(name, True, "recognition or hand-off present")


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


_ALL_CHECKS = (
    check_numeric_anchor,
    check_concision,
    check_banned_terms,
    check_action_or_handoff,
    check_archetype_aware,
    check_escalation_aware,
)


def score_response(response: str, meta: Optional[QuestionMeta] = None) -> DoctrineReport:
    """Run all 6 checks against a response; return structured report."""
    meta = meta or QuestionMeta()
    results = tuple(check(response, meta) for check in _ALL_CHECKS)
    return DoctrineReport(response=response, meta=meta, checks=results)
