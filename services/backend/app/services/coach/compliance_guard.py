"""
Compliance Guard — Sprint S34 (BLOCKER).

Validates ALL LLM output before display. No LLM text reaches the user
without passing through this 5-layer validation pipeline.

Layers:
    1. Banned terms detection + sanitization
    2. Prescriptive language detection (imperative financial instructions)
    3. Hallucination detection (numbers verified against financial_core)
    4. Disclaimer auto-injection (if discussing projections/simulations)
    5. Length constraints per component type

References:
    - LSFin art. 3/8 (quality of financial information)
    - FINMA circular 2008/21 (operational risk)
    - LPD art. 6 (data processing principles)
"""

import logging
import re
import unicodedata
from typing import Optional

from app.services.coach.coach_models import (
    ComplianceResult,
    CoachContext,
    ComponentType,
    COMPONENT_WORD_LIMITS,
)
from app.services.coach.hallucination_detector import HallucinationDetector

logger = logging.getLogger(__name__)


class ComplianceGuard:
    """Validates LLM output before user display."""

    # ═══════════════════════════════════════════════════════════════════
    # Layer 1: Banned terms
    # ═══════════════════════════════════════════════════════════════════

    BANNED_TERMS = [
        # Masculine forms
        "garanti",
        "certain",
        "assuré",
        "sans risque",
        "optimal",
        "meilleur",
        "parfait",
        "conseiller",          # → use "spécialiste"
        # Feminine forms (audit: bypass via inflection)
        "garantie",
        "assurée",
        "optimale",
        "meilleure",
        "parfaite",
        "conseillère",
        # Plural forms (GAP #1: inflection bypass via plurals)
        "garantis",
        "garanties",
        "assurés",
        "assurées",
        "certains",
        "certaines",
        "optimaux",
        "optimales",
        "meilleurs",
        "meilleures",
        "parfaits",
        "parfaites",
        # Prescriptive phrases
        "tu devrais",
        "tu dois",
        "il faut que tu",
        "la meilleure option",
        "nous recommandons",
        "nous te conseillons",
        "il est optimal",
        "la solution idéale",
        # Product recommendation terms (GAP #3: named products/ISINs)
        "idéal",
        "idéale",
        # Superlative form of "meilleur" (GAP #4: "le mieux" bypass)
        "le mieux",
        # Conditional/subjunctive forms (GAP #5: conjugation bypass)
        "garantirait",
        "garantiraient",
        "serait garanti",
        "serait garantie",
        "seraient garantis",
        "seraient garanties",
        "assurerait",
        "assureront",
        # Infinitive prescriptive bypass
        "garantir un rendement",
        "assurer un retour",
    ]

    # Pre-compiled word-boundary patterns (French-aware: includes À-ÿ).
    # Mirroring Flutter compliance_guard.dart approach.
    _FR_LETTER = r"a-zA-Z\u00C0-\u00FF"
    _BANNED_PATTERNS_MAP: dict[str, re.Pattern] = {}

    @classmethod
    def _get_banned_patterns(cls) -> dict[str, re.Pattern]:
        """Lazy-init pre-compiled banned term patterns."""
        if not cls._BANNED_PATTERNS_MAP:
            for term in cls.BANNED_TERMS:
                if " " in term:
                    cls._BANNED_PATTERNS_MAP[term] = re.compile(
                        re.escape(term), re.IGNORECASE
                    )
                else:
                    cls._BANNED_PATTERNS_MAP[term] = re.compile(
                        rf"(?<![{cls._FR_LETTER}]){re.escape(term)}(?![{cls._FR_LETTER}])",
                        re.IGNORECASE,
                    )
        return cls._BANNED_PATTERNS_MAP

    # Replacement map for salvageable terms
    TERM_REPLACEMENTS = {
        "garanti": "possible dans ce scénario",
        "certain": "probable",
        "assuré": "envisageable",
        "sans risque": "à risque modéré",
        "optimal": "adapté",
        "meilleur": "pertinent",
        "parfait": "adapté",
        "conseiller": "spécialiste",
        # Feminine forms
        "garantie": "possible dans ce scénario",
        "assurée": "envisageable",
        "optimale": "adaptée",
        "meilleure": "pertinente",
        "parfaite": "adaptée",
        "conseillère": "spécialiste",
        # Plural forms
        "garantis": "possibles dans ce scénario",
        "garanties": "possibles dans ce scénario",
        "assurés": "envisageables",
        "assurées": "envisageables",
        "certains": "probables",
        "certaines": "probables",
        "optimaux": "adaptés",
        "optimales": "adaptées",
        "meilleurs": "pertinents",
        "meilleures": "pertinentes",
        "parfaits": "adaptés",
        "parfaites": "adaptées",
        # Prescriptive phrases
        "tu devrais": "tu pourrais envisager de",
        "tu dois": "il serait utile de",
        "il faut que tu": "tu pourrais",
        "la meilleure option": "une option à considérer",
        "nous recommandons": "une piste possible serait",
        "nous te conseillons": "une approche envisageable serait",
        "il est optimal": "il pourrait être pertinent",
        "la solution idéale": "une approche adaptée",
        # Product recommendation terms
        "idéal": "adapté",
        "idéale": "adaptée",
        # Superlative form
        "le mieux": "une option pertinente",
        # Conditional/subjunctive forms
        "garantirait": "pourrait permettre",
        "garantiraient": "pourraient permettre",
        "serait garanti": "serait envisageable",
        "serait garantie": "serait envisageable",
        "seraient garantis": "seraient envisageables",
        "seraient garanties": "seraient envisageables",
        "assurerait": "pourrait offrir",
        "assureront": "pourraient offrir",
        "garantir un rendement": "viser un rendement",
        "assurer un retour": "viser un retour",
    }

    # ═══════════════════════════════════════════════════════════════════
    # Layer 2: Prescriptive patterns
    # ═══════════════════════════════════════════════════════════════════

    PRESCRIPTIVE_PATTERNS = [
        re.compile(r"fais\s+un\s+rachat", re.IGNORECASE),
        re.compile(r"verse\s+sur\s+ton", re.IGNORECASE),
        re.compile(r"ach[eè]te", re.IGNORECASE),
        re.compile(r"vends\b", re.IGNORECASE),
        re.compile(r"choisis\s+la\s+rente", re.IGNORECASE),
        re.compile(r"prends?\s+le\s+capital", re.IGNORECASE),
        re.compile(r"investis?\s+dans", re.IGNORECASE),
        re.compile(r"priorit[ée]\s+absolue", re.IGNORECASE),
        re.compile("c['\u2018\u2019]est\\s+plus\\s+important\\s+que", re.IGNORECASE),
        re.compile(r"souscris\b", re.IGNORECASE),
        re.compile(r"rach[eè]te\b", re.IGNORECASE),
        re.compile(r"transf[eè]re\b", re.IGNORECASE),
        # Social comparison patterns (GAP #2: ranking users against others)
        re.compile(r"top\s+\d+\s*%", re.IGNORECASE),
        re.compile(r"meilleur\s+que\s+\d+\s*%", re.IGNORECASE),
        re.compile(r"devant\s+\d+\s*%\s+des", re.IGNORECASE),
        re.compile(r"parmi\s+les\s+meilleurs", re.IGNORECASE),
        re.compile(r"au-dessus\s+de\s+la\s+moyenne", re.IGNORECASE),
    ]

    # ═══════════════════════════════════════════════════════════════════
    # Layer 4: Disclaimer keywords (trigger disclaimer injection)
    # ═══════════════════════════════════════════════════════════════════

    PROJECTION_KEYWORDS = [
        "projection", "simulation", "scénario", "scenario",
        "estimé", "estimée", "estimation", "prévision",
        "retraite", "rente", "capital", "rendement",
    ]

    STANDARD_DISCLAIMER = (
        "Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). "
        "Consulte un·e spécialiste pour une analyse personnalisée."
    )

    # ═══════════════════════════════════════════════════════════════════
    # Main validation
    # ═══════════════════════════════════════════════════════════════════

    def __init__(self):
        self._detector = HallucinationDetector()

    def validate(
        self,
        llm_output: str,
        context: Optional[CoachContext] = None,
        component_type: ComponentType = ComponentType.general,
        user_id: Optional[str] = None,
    ) -> ComplianceResult:
        """Validate LLM output through 5 compliance layers.

        Args:
            llm_output: Raw LLM-generated text.
            context: CoachContext with known values for hallucination detection.
            component_type: Type of component (for length limits).
            user_id: Optional anonymized user ID for compliance audit trail.

        Returns:
            ComplianceResult with compliance status and sanitized text.
        """
        violations = []
        use_fallback = False

        # ── Pre-check: None / non-string input ──
        if not isinstance(llm_output, str):
            return ComplianceResult(
                is_compliant=False,
                sanitized_text="",
                violations=["Entrée invalide (non-string)"],
                use_fallback=True,
            )

        text = llm_output

        # ── Pre-check: empty output ──
        if not text or not text.strip():
            return ComplianceResult(
                is_compliant=False,
                sanitized_text="",
                violations=["Sortie vide"],
                use_fallback=True,
            )

        # ── NFKC normalization: converts Cyrillic/homoglyph lookalikes to Latin ──
        # Prevents banned-term bypass via Unicode homoglyphs (e.g. Cyrillic "а" → Latin "a").
        text = unicodedata.normalize("NFKC", text)

        # ── Pre-check: wrong language (basic heuristic) ──
        language_violations = self._check_language(text)
        if language_violations:
            violations.extend(language_violations)
            use_fallback = True

        # ── Layer 1: Banned terms ──
        banned_found = self._check_banned_terms(text)
        if banned_found:
            logger.warning("ComplianceGuard L1: banned terms %s in %s user=%s", banned_found, component_type, user_id or "anonymous")
            violations.extend(
                [f"Terme interdit: '{term}'" for term in banned_found]
            )
            if len(banned_found) > 2:
                use_fallback = True
            else:
                text = self._sanitize_banned_terms(text)

        # ── Layer 2: Prescriptive patterns ──
        prescriptive_found = self._check_prescriptive(text)
        if prescriptive_found:
            logger.warning("ComplianceGuard L2: prescriptive %s in %s user=%s", prescriptive_found, component_type, user_id or "anonymous")
            violations.extend(
                [f"Langage prescriptif: '{p}'" for p in prescriptive_found]
            )
            use_fallback = True

        # ── Layer 3: Hallucination detection ──
        if context and context.known_values:
            hallucinations = self._detector.detect(text, context.known_values)
            if hallucinations:
                for h in hallucinations:
                    violations.append(
                        f"Hallucination: '{h.found_text}' "
                        f"(attendu ~{h.closest_value}, trouvé {h.found_value}, "
                        f"déviation {h.deviation_pct:.1f}%)"
                    )
                use_fallback = True  # Hallucinated numbers = always fallback

        # ── Layer 4: Disclaimer injection ──
        if not use_fallback:
            text = self._inject_disclaimer_if_needed(text)

        # ── Layer 5: Length check ──
        if not use_fallback:
            word_limit = COMPONENT_WORD_LIMITS.get(
                component_type, COMPONENT_WORD_LIMITS[ComponentType.general]
            )
            text, length_violation = self._enforce_length(text, word_limit)
            if length_violation:
                violations.append(length_violation)

        # Defense-in-depth: if sanitization emptied the text, force fallback.
        if not use_fallback and not text.strip():
            use_fallback = True
            violations.append("Texte vide après sanitisation")

        is_compliant = len(violations) == 0
        return ComplianceResult(
            is_compliant=is_compliant,
            sanitized_text=text if not use_fallback else "",
            violations=violations,
            use_fallback=use_fallback,
        )

    # ═══════════════════════════════════════════════════════════════════
    # Layer implementations
    # ═══════════════════════════════════════════════════════════════════

    def _check_language(self, text: str) -> list:
        """Basic check for non-French text (Layer 0)."""
        violations = []
        # Simple heuristic: check for common English-only words
        english_markers = [
            r"\byour\b", r"\byou\b", r"\bshould\b", r"\bwould\b",
            r"\bcould\b", r"\bthe\b", r"\bwith\b", r"\bthis\b",
        ]
        english_count = 0
        for pattern in english_markers:
            if re.search(pattern, text, re.IGNORECASE):
                english_count += 1

        # If 3+ English markers, likely wrong language
        if english_count >= 3:
            violations.append(
                f"Langue incorrecte: texte semble être en anglais "
                f"({english_count} marqueurs détectés)"
            )
        return violations

    # Regex patterns for fuzzy banned term matching (catches variants)
    BANNED_PATTERNS = [
        # FIX: ReDoS — replaced (?:\w+\s+)* (exponential backtracking) with bounded {0,3}
        (re.compile(r"sans\s+(?:\w+\s+){0,3}risque", re.IGNORECASE), "sans risque"),
    ]

    def _check_banned_terms(self, text: str) -> list:
        """Layer 1: Check for banned terms using French-aware word boundaries."""
        lower = text.lower()
        found = []
        for term, pattern in self._get_banned_patterns().items():
            if pattern.search(lower):
                found.append(term)
        # Also check regex patterns for fuzzy variants
        for pattern, label in self.BANNED_PATTERNS:
            if label not in found and pattern.search(lower):
                found.append(label)
        return found

    def _sanitize_banned_terms(self, text: str) -> str:
        """Replace banned terms using French-aware word-boundary patterns.

        Processes multi-word phrases first for longest-match priority.
        """
        result = text
        patterns = self._get_banned_patterns()
        # Phrases first, then single-word terms
        phrases = [(t, r) for t, r in self.TERM_REPLACEMENTS.items() if " " in t]
        words = [(t, r) for t, r in self.TERM_REPLACEMENTS.items() if " " not in t]
        for term, replacement in phrases + words:
            p = patterns.get(term)
            if p:
                result = p.sub(replacement, result)
        return result

    def _check_prescriptive(self, text: str) -> list:
        """Layer 2: Check for prescriptive financial language."""
        found = []
        for pattern in self.PRESCRIPTIVE_PATTERNS:
            match = pattern.search(text)
            if match:
                found.append(match.group(0))
        return found

    def _inject_disclaimer_if_needed(self, text: str) -> str:
        """Layer 4: Auto-inject disclaimer if text discusses projections."""
        text_lower = text.lower()
        discusses_projection = any(
            kw in text_lower for kw in self.PROJECTION_KEYWORDS
        )
        has_disclaimer = any(
            kw in text_lower
            for kw in ["outil éducatif", "outil educatif", "lsfin", "spécialiste"]
        )

        if discusses_projection and not has_disclaimer:
            text = text.rstrip()
            if not text.endswith("."):
                text += "."
            text += f"\n\n_{self.STANDARD_DISCLAIMER}_"

        return text

    def _enforce_length(self, text: str, max_words: int) -> tuple:
        """Layer 5: Truncate at last complete sentence if too long."""
        words = text.split()
        if len(words) <= max_words:
            return text, None

        # Truncate at last complete sentence within limit
        truncated_words = words[:max_words]
        truncated = " ".join(truncated_words)

        # Find last sentence boundary
        last_period = truncated.rfind(".")
        last_exclaim = truncated.rfind("!")
        last_question = truncated.rfind("?")
        last_boundary = max(last_period, last_exclaim, last_question)

        if last_boundary > 0:
            truncated = truncated[: last_boundary + 1]

        violation = (
            f"Texte trop long: {len(words)} mots (limite: {max_words})"
        )
        return truncated, violation
