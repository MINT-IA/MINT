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
        # NOTE: "certain" / "certaine" / "certains" / "certaines" are handled
        # by context-aware detection in _check_certain_guarantee() because
        # they have a legitimate adjective meaning ("certains cas", "une
        # certaine somme", "dans certaines situations") that was being
        # blocked by a blanket rule — every 3rd coach reply fell to
        # fallback on perfectly valid French.
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

    # Context-aware patterns for the "certain" family. These catch the
    # guarantee usage ("c'est certain", "est certaine", "sera certain",
    # "reste certain") WITHOUT flagging legitimate adjective usage ("un
    # certain montant", "dans certains cas", "une certaine somme").
    # Each match is reported as the canonical "certain" banned term so
    # sanitisation can replace it with "probable".
    _CERTAIN_GUARANTEE_PATTERNS = [
        re.compile(
            r"\b(?:c['\u2018\u2019]est|est|sera|reste|demeure|semble|para[iî]t|"
            r"devient|rendu|rendue)\s+certain(?:e|s|es)?\b",
            re.IGNORECASE,
        ),
        re.compile(
            r"\bc['\u2018\u2019]est\s+(?:tout\s+[àa]\s+fait|absolument|"
            r"totalement|vraiment)\s+certain(?:e|s|es)?\b",
            re.IGNORECASE,
        ),
        re.compile(
            r"\b(?:rendement|r[ée]sultat|gain|retour|profit)s?\s+certain(?:e|s|es)?\b",
            re.IGNORECASE,
        ),
        # Superlative "(le|la|les) plus certain(e)(s)" — "the most certain
        # choice" reads as a guarantee even without an auxiliary verb.
        re.compile(
            r"\b(?:le|la|les)\s+plus\s+certain(?:e|s|es)?\b",
            re.IGNORECASE,
        ),
    ]

    # Replacement map for salvageable terms
    TERM_REPLACEMENTS = {
        "garanti": "possible dans ce scénario",
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

    # ═══════════════════════════════════════════════════════════════════
    # Layer 2b: High-register drift (N4/N5 only) — Phase 11 / VOICE-08
    # ═══════════════════════════════════════════════════════════════════
    #
    # These patterns activate ONLY when the caller passes cursor_level in
    # {"N4","N5"}. They harden the guard against the specific drift modes
    # that high-register voice tends to produce: imperatives without hedge,
    # judging the emitter, social/age shaming, and named-product drift.
    #
    # Each entry is (pattern, failure_category, label) so the audit log
    # records WHICH adversarial mode tripped.

    HIGH_REGISTER_DRIFT_PATTERNS: list = [
        # ── imperative_no_hedge ──────────────────────────────────────
        (re.compile(r"\barr[êe]te\s+de\b", re.IGNORECASE), "imperative_no_hedge", "arrête de"),
        (re.compile(r"\bferme\s+(?:ce|cette|ton|ta)\b", re.IGNORECASE), "imperative_no_hedge", "ferme ce/cette"),
        (re.compile(r"\bchange-en\b", re.IGNORECASE), "imperative_no_hedge", "change-en"),
        (re.compile(r"\bquitte\s+(?:cette|ta|ton)\b", re.IGNORECASE), "imperative_no_hedge", "quitte cette"),
        # ── judging the emitter (doctrine: never judge the issuer) ──
        (re.compile(r"\barnaque\b", re.IGNORECASE), "imperative_no_hedge", "arnaque"),
        (re.compile(r"\bc['\u2018\u2019]est\s+nul\b", re.IGNORECASE), "imperative_no_hedge", "c'est nul"),
        (re.compile(r"\bc['\u2018\u2019]est\s+inutile\b", re.IGNORECASE), "imperative_no_hedge", "c'est inutile"),
        # ── shame_vector: social comparison + age shaming ───────────
        (re.compile(r"\bton\s+voisin\b", re.IGNORECASE), "shame_vector", "ton voisin"),
        (re.compile(r"\bgens\s+de\s+ton\s+[âa]ge\b", re.IGNORECASE), "shame_vector", "gens de ton âge"),
        (re.compile(r"\bsuisses\s+de\s+ton\s+[âa]ge\b", re.IGNORECASE), "shame_vector", "Suisses de ton âge"),
        (re.compile(r"\btous\s+les\s+suisses\b", re.IGNORECASE), "shame_vector", "tous les Suisses"),
        (re.compile(r"\bcomme\s+les\s+suisses\s+qui\b", re.IGNORECASE), "shame_vector", "comme les Suisses qui"),
        (re.compile(r"\btu\s+vas\s+finir\s+comme\b", re.IGNORECASE), "shame_vector", "tu vas finir comme"),
        (re.compile(r"\b(?:tu\s+es\s+)?en\s+retard\b", re.IGNORECASE), "shame_vector", "en retard"),
        (re.compile(r"\d+\s*%\s+de\s+plus\s+que\s+toi", re.IGNORECASE), "shame_vector", "X% de plus que toi"),
        (re.compile(r"\d+\s*%\s+des\s+gens\b", re.IGNORECASE), "shame_vector", "% des gens"),
        # ── prescription_drift: named products + FOMO urgency ───────
        (re.compile(r"\bbitcoin\b", re.IGNORECASE), "prescription_drift", "Bitcoin"),
        (re.compile(r"\bnestl[ée]\b", re.IGNORECASE), "prescription_drift", "Nestlé"),
        (re.compile(r"\broche\b", re.IGNORECASE), "prescription_drift", "Roche"),
        (re.compile(r"\bnovartis\b", re.IGNORECASE), "prescription_drift", "Novartis"),
        (re.compile(r"\bubs\b", re.IGNORECASE), "prescription_drift", "UBS"),
        (re.compile(r"\bmsci\s+world\b", re.IGNORECASE), "prescription_drift", "MSCI World"),
        (re.compile(r"\bsinon\s+tu\s+rateras\b", re.IGNORECASE), "prescription_drift", "sinon tu rateras"),
        (re.compile(r"\brater(?:as|a|ait)?\s+le\s+train\b", re.IGNORECASE), "prescription_drift", "rater le train"),
    ]

    # Negated-guarantee whitelist: phrases like "rien n'est garanti" or
    # "n'est jamais garanti" are IN-DOCTRINE (anti-promise) but contain the
    # banned root "garanti". Strip them from a working copy used only for
    # banned-term scanning so they don't trigger Layer 1.
    _NEGATED_GUARANTEE_PATTERNS = [
        re.compile(r"rien\s+n['\u2018\u2019]est\s+garanti(?:e|s|es)?\b", re.IGNORECASE),
        re.compile(r"n['\u2018\u2019]est\s+jamais\s+garanti(?:e|s|es)?\b", re.IGNORECASE),
        re.compile(r"n['\u2018\u2019]est\s+pas\s+garanti(?:e|s|es)?\b", re.IGNORECASE),
        re.compile(r"\bnon\s+garanti(?:e|s|es)?\b", re.IGNORECASE),
        re.compile(r"\bjamais\s+garanti(?:e|s|es)?\b", re.IGNORECASE),
    ]

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
        cursor_level: Optional[str] = None,
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
        # P0 DIAG: per-layer trigger attribution. We need to know WHICH
        # layer kills each response in prod so we can stop guessing which
        # fallback is silently erasing coach replies (Gate 0 P0-3).
        fallback_reasons: list[str] = []

        # ── Pre-check: None / non-string input ──
        if not isinstance(llm_output, str):
            logger.warning(
                "ComplianceGuard.validate: use_fallback=True reason=non_string_input "
                "component=%s user=%s",
                component_type, user_id or "anonymous",
            )
            return ComplianceResult(
                is_compliant=False,
                sanitized_text="",
                violations=["Entrée invalide (non-string)"],
                use_fallback=True,
            )

        text = llm_output

        # ── Pre-check: empty output ──
        if not text or not text.strip():
            logger.warning(
                "ComplianceGuard.validate: use_fallback=True reason=empty_input "
                "component=%s user=%s",
                component_type, user_id or "anonymous",
            )
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
        # NOTE: log-only by default. Modern French finance uses English tech
        # terms (ETF, cash, score, KPI). Detecting "you/the/with" 3 times
        # kills legitimate French responses. Defense is in the prompt.
        language_violations = self._check_language(text)
        if language_violations:
            violations.extend(language_violations)
            # use_fallback intentionally NOT set — log only.

        # ── Layer 1: Banned terms ──
        # Strip negated guarantees (e.g. "rien n'est garanti") from the
        # working copy used for banned-term scanning. The user-visible text
        # is preserved — only Layer 1 detection sees the masked version.
        scan_text = text
        for neg in self._NEGATED_GUARANTEE_PATTERNS:
            scan_text = neg.sub("", scan_text)
        banned_found = self._check_banned_terms(scan_text)
        if banned_found:
            logger.warning("ComplianceGuard L1: banned terms %s in %s user=%s", banned_found, component_type, user_id or "anonymous")
            violations.extend(
                [f"Terme interdit: '{term}'" for term in banned_found]
            )
            # Always sanitize banned terms instead of fallback.
            # The >2 threshold was killing legitimate French finance responses
            # where "meilleur/optimal" appear naturally. Sanitization replaces
            # terms with compliant alternatives — sufficient for LSFin.
            text = self._sanitize_banned_terms(text)
            if len(banned_found) > 5:
                # Only fallback on truly egregious cases (5+ distinct banned terms
                # suggests a fundamentally non-compliant response).
                use_fallback = True
                fallback_reasons.append(
                    f"banned_terms>5 ({len(banned_found)}: {banned_found[:5]})"
                )

        # ── Layer 2: Prescriptive patterns ──
        # NEVER fallback on prescriptive language — always log only.
        # The system prompt already instructs Claude to use conditional language.
        # Killing the response for natural French like "rachète ta LPP" or
        # "investis dans ton 3a" destroys every substantive coach response.
        # Defense is in the prompt, not in post-hoc rejection.
        prescriptive_found = self._check_prescriptive(text)
        if prescriptive_found:
            logger.info("ComplianceGuard L2: prescriptive %s in %s user=%s (logged, not rejected)", prescriptive_found, component_type, user_id or "anonymous")
            violations.extend(
                [f"Langage prescriptif: '{p}'" for p in prescriptive_found]
            )

        # ── Layer 2b: High-register drift (N4/N5 only) ──
        # NOTE: log-only. N4/N5 cursor not yet active in production today.
        # Keeping the detector wired but non-blocking lets us observe drift
        # in telemetry without killing responses. When N4/N5 is activated,
        # re-enable the `use_fallback = True` branch after validating the
        # patterns against real high-register generations.
        if cursor_level in ("N4", "N5"):
            drift_found = self._check_high_register_drift(text)
            if drift_found:
                logger.info(
                    "ComplianceGuard L2b: drift %s level=%s component=%s user=%s "
                    "(logged, not enforced)",
                    drift_found, cursor_level, component_type, user_id or "anonymous",
                )
                violations.extend(
                    [f"Drift {cat}: '{label}'" for (cat, label) in drift_found]
                )
                # use_fallback intentionally NOT set — log only.

        # ── Layer 3: Hallucination detection ──
        # Threshold-based: only MAJOR deviations (>= 30%) trigger fallback.
        # Minor deviations (< 30%) are logged and the response is preserved —
        # small numeric drift (e.g. 7.0% conversion rate vs 6.8%) is closer
        # to a rounding slip than a material hallucination, and killing the
        # whole reply over it silently erases substantive coach output.
        # Major deviations (>= 30%) still fallback: these are genuine
        # fabrications (e.g. "tu as 500k LPP" when user has 70k).
        _HALLUCINATION_MAJOR_THRESHOLD_PCT = 30.0
        if context and context.known_values:
            hallucinations = self._detector.detect(text, context.known_values)
            if hallucinations:
                major = [h for h in hallucinations if h.deviation_pct >= _HALLUCINATION_MAJOR_THRESHOLD_PCT]
                minor = [h for h in hallucinations if h.deviation_pct < _HALLUCINATION_MAJOR_THRESHOLD_PCT]
                for h in hallucinations:
                    violations.append(
                        f"Hallucination: '{h.found_text}' "
                        f"(attendu ~{h.closest_value}, trouvé {h.found_value}, "
                        f"déviation {h.deviation_pct:.1f}%)"
                    )
                if minor:
                    logger.info(
                        "ComplianceGuard L3: minor hallucinations (<%s%%) "
                        "component=%s user=%s hits=%s (logged, response preserved)",
                        _HALLUCINATION_MAJOR_THRESHOLD_PCT,
                        component_type, user_id or "anonymous",
                        [(h.found_text, h.found_value, h.closest_value, round(h.deviation_pct, 1)) for h in minor[:5]],
                    )
                if major:
                    logger.warning(
                        "ComplianceGuard L3: MAJOR hallucinations (>=%s%%) "
                        "component=%s user=%s hits=%s",
                        _HALLUCINATION_MAJOR_THRESHOLD_PCT,
                        component_type, user_id or "anonymous",
                        [(h.found_text, h.found_value, h.closest_value, round(h.deviation_pct, 1)) for h in major[:5]],
                    )
                    use_fallback = True
                    fallback_reasons.append(
                        f"hallucination_major hits={[(h.found_text, h.found_value, h.closest_value) for h in major[:3]]}"
                    )

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
            fallback_reasons.append("empty_after_sanitisation")

        # P0 DIAG: one structured log per fallback decision so prod tells
        # us WHICH layer killed the reply. Previously this was silent.
        if use_fallback:
            logger.warning(
                "ComplianceGuard.validate: use_fallback=True reasons=%s "
                "component=%s user=%s cursor=%s violations=%d preview=%r",
                fallback_reasons or ["unknown"],
                component_type, user_id or "anonymous", cursor_level,
                len(violations),
                (llm_output or "")[:200],
            )

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
        # Context-aware "certain" family: only flag guarantee usage, not
        # legitimate adjective usage ("un certain montant", "certains cas").
        if self._check_certain_guarantee(text):
            found.append("certain")
        return found

    def _check_certain_guarantee(self, text: str) -> bool:
        """Detect the 'certain' family used as a guarantee ("c'est certain",
        "rendement certain"). Returns False for the adjective form that is
        standard French ("un certain montant", "dans certains cas")."""
        for pattern in self._CERTAIN_GUARANTEE_PATTERNS:
            if pattern.search(text):
                return True
        return False

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
        # Context-aware "certain" sanitisation: rewrite only the guarantee
        # phrasing, leave adjective usage untouched.
        for pattern in self._CERTAIN_GUARANTEE_PATTERNS:
            result = pattern.sub(self._replace_certain_guarantee, result)
        return result

    @staticmethod
    def _replace_certain_guarantee(match: "re.Match[str]") -> str:
        """Replacement helper: rewrite guarantee phrasing of 'certain'
        while preserving the grammatical form of the surrounding words."""
        phrase = match.group(0)
        lowered = phrase.lower()
        # "rendement/résultat/gain certain" → "rendement/... probable"
        for head in ("rendement", "résultat", "resultat", "gain", "retour", "profit"):
            if lowered.startswith(head) or lowered.startswith(head + "s"):
                return re.sub(
                    r"certain(e|s|es)?\b",
                    lambda m: "probable" + (m.group(1) or ""),
                    phrase,
                    flags=re.IGNORECASE,
                )
        # "c'est / est / sera / reste certain(e)(s)" → "... probable(s)"
        return re.sub(
            r"certain(e|s|es)?\b",
            lambda m: "probable" + (m.group(1) or ""),
            phrase,
            flags=re.IGNORECASE,
        )

    def _check_high_register_drift(self, text: str) -> list:
        """Layer 2b: Detect N4/N5 drift modes.

        Returns list of (failure_category, label) tuples — empty if clean.
        Only invoked by validate() when cursor_level in {"N4","N5"}.
        """
        found: list = []
        for pattern, category, label in self.HIGH_REGISTER_DRIFT_PATTERNS:
            if pattern.search(text):
                found.append((category, label))
        return found

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
