"""
Compliance guardrails for Swiss financial content.

Post-filters added 2026-04-15 (PR A — prompt hardening):
- Layer/Couche doctrine marker scrubbing (strip internal layer labels that
  sometimes leak into user-visible text).
- Formal "vous" detection (log-only telemetry; tutoiement strict is enforced
  at the prompt level, this is a detection canary).
- Jaccard-similarity filter for follow-up chips: drops any follow-up that
  paraphrases the user's last message (score > 0.6) — anti-echo guarantee.
- Sentence-count truncation: clamps user-visible answers to 3 sentences so
  the prompt contract ("3 phrases max") is enforced even when Claude drifts.

.. deprecated:: S34
    This module is maintained for backward compatibility with the RAG
    orchestrator. New code should use ``app.services.coach.compliance_guard``
    which implements the full 5-layer validation pipeline (banned terms,
    prescriptive language, hallucination detection, disclaimer injection,
    length constraints).

    The Flutter client also runs ComplianceGuard on every LLM response,
    providing defense-in-depth regardless of backend filtering.

Ensures generated responses comply with Swiss financial regulations:
- No product recommendations
- No guaranteed returns
- Educational purpose only
- Proper disclaimers
"""

from __future__ import annotations

import logging
import re
from typing import Optional

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Post-filter regexes (2026-04-15 — PR A prompt hardening)
# ─────────────────────────────────────────────────────────────────────────────

# Strips doctrine layer markers like "Couche 2 :", "**Couche 3:**", "Niveau 1 -".
# We only scrub the LABEL + its punctuation — the rest of the sentence is kept.
_LAYER_LEAK_RE = re.compile(
    r"\*{0,2}\s*(?:Couche|Layer|Niveau|[ÉE]tape|Phase)\s*\d+\s*\*{0,2}\s*[:\-–—]\s*",
    re.IGNORECASE,
)

# Detects formal singular "vous" usage. Explicit plural markers
# ("vous deux", "vous autres") are excluded — those are natural plural pronouns.
_FORMAL_VOUS_RE = re.compile(
    r"\bvous\s+(?!deux\b|autres\b)"
    r"(avez|êtes|etes|pourriez|devriez|allez|voulez|savez|pouvez|"
    r"aurez|serez|feriez|auriez|seriez|prenez|faites)\b",
    re.IGNORECASE,
)

# Sentence splitter for length truncation. Keeps the delimiter with the
# sentence it terminates.
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?…])\s+(?=\S)")


class ComplianceGuardrails:
    """Post-generation compliance filter for Swiss financial content.

    .. deprecated:: S34
        Use :class:`app.services.coach.compliance_guard.ComplianceGuard` for
        the full 5-layer validation. This class is kept for RAG orchestrator
        backward compatibility.
    """

    # Terms that should never appear in financial advice (implies guarantees)
    BANNED_TERMS = [
        # French (masculine + feminine)
        "garanti",
        "garantie",
        "assuré",
        "assurée",
        "certain",
        "sans risque",
        "rendement fixe",
        "profit assuré",
        "optimal",
        "optimale",
        "meilleur",
        "meilleure",
        "parfait",
        "parfaite",
        "conseiller",
        "conseillère",
        # German
        "garantiert",
        "gesichert",
        "sicher",
        "risikofrei",
        "feste Rendite",
        # English
        "guaranteed",
        "assured",
        "certain return",
        "risk-free",
        "fixed return",
        # Italian
        "garantito",
        "assicurato",
        "senza rischio",
    ]

    # Terms that require a disclaimer to be appended
    REQUIRES_DISCLAIMER = [
        # French
        "impôt",
        "fiscal",
        "déduction",
        "3a",
        "3b",
        "pilier",
        "rente",
        "pension",
        "lpp",
        "avs",
        "prévoyance",
        # German
        "Steuer",
        "steuerlich",
        "Abzug",
        "Säule",
        "Rente",
        "Pension",
        "BVG",
        "AHV",
        "Vorsorge",
        # English
        "tax",
        "deduction",
        "pillar",
        "pension",
        "retirement",
        # Italian
        "imposta",
        "fiscale",
        "deduzione",
        "pilastro",
        "pensione",
        "previdenza",
    ]

    DISCLAIMERS = {
        "fr": {
            "general": (
                "Cette information est fournie à titre éducatif uniquement "
                "et ne constitue pas un conseil financier personnalisé."
            ),
            "tax": (
                "Les estimations fiscales sont indicatives. "
                "Consultez un·e spécialiste en fiscalité pour votre situation spécifique."
            ),
            "investment": (
                "Les performances passées ne préjugent pas des performances futures. "
                "Tout investissement comporte des risques."
            ),
        },
        "de": {
            "general": (
                "Diese Informationen dienen ausschliesslich zu Bildungszwecken "
                "und stellen keine persönliche Finanzberatung dar."
            ),
            "tax": (
                "Die Steuerschätzungen sind indikativ. "
                "Konsultieren Sie einen Steuerberater für Ihre spezifische Situation."
            ),
            "investment": (
                "Die vergangene Performance lässt keine Rückschlüsse auf die "
                "zukünftige Performance zu. Jede Anlage birgt Risiken."
            ),
        },
        "en": {
            "general": (
                "This information is provided for educational purposes only "
                "and does not constitute personalized financial advice."
            ),
            "tax": (
                "Tax estimates are indicative. "
                "Consult a tax advisor for your specific situation."
            ),
            "investment": (
                "Past performance does not guarantee future results. "
                "All investments carry risk."
            ),
        },
        "it": {
            "general": (
                "Queste informazioni sono fornite esclusivamente a scopo educativo "
                "e non costituiscono una consulenza finanziaria personalizzata."
            ),
            "tax": (
                "Le stime fiscali sono indicative. "
                "Consultate un consulente fiscale per la vostra situazione specifica."
            ),
            "investment": (
                "Le prestazioni passate non garantiscono risultati futuri. "
                "Ogni investimento comporta dei rischi."
            ),
        },
    }

    SYSTEM_PROMPTS = {
        "fr": (
            "Tu es un assistant éducatif suisse en finances personnelles pour l'app MINT.\n\n"
            "RÈGLES STRICTES :\n"
            "1. Tu ne fais JAMAIS de recommandation de produit financier spécifique.\n"
            "2. Tu ne garantis JAMAIS de rendement ou de résultat.\n"
            "3. Tu cites TOUJOURS tes sources quand tu utilises le contexte fourni.\n"
            "4. Tu rappelles que tes réponses sont ÉDUCATIVES et ne remplacent pas un conseil professionnel.\n"
            "5. Tu es spécialisé dans le système suisse (AVS/AI, LPP, 3e pilier, fiscalité cantonale).\n"
            "6. Tu réponds dans la langue de la question.\n"
            "7. Si tu ne connais pas la réponse, dis-le clairement. N'invente jamais.\n"
            "8. N'utilise JAMAIS les termes : garanti, assuré, certain, sans risque.\n\n"
            "Tu bases tes réponses sur le contexte fourni (knowledge base MINT)."
        ),
        "de": (
            "Du bist ein Schweizer Bildungsassistent für persönliche Finanzen in der MINT-App.\n\n"
            "STRENGE REGELN:\n"
            "1. Du machst NIEMALS eine Empfehlung für ein bestimmtes Finanzprodukt.\n"
            "2. Du garantierst NIEMALS eine Rendite oder ein Ergebnis.\n"
            "3. Du zitierst IMMER deine Quellen, wenn du den bereitgestellten Kontext verwendest.\n"
            "4. Du erinnerst daran, dass deine Antworten BILDUNGSZWECKEN dienen.\n"
            "5. Du bist auf das Schweizer System spezialisiert (AHV/IV, BVG, 3. Säule, kantonale Steuern).\n"
            "6. Du antwortest in der Sprache der Frage.\n"
            "7. Wenn du die Antwort nicht kennst, sage es klar. Erfinde nie etwas.\n"
            "8. Verwende NIEMALS die Begriffe: garantiert, gesichert, risikofrei.\n\n"
            "Du basierst deine Antworten auf dem bereitgestellten Kontext (MINT Knowledge Base)."
        ),
        "en": (
            "You are a Swiss personal finance education assistant for the MINT app.\n\n"
            "STRICT RULES:\n"
            "1. NEVER recommend a specific financial product.\n"
            "2. NEVER guarantee any return or outcome.\n"
            "3. ALWAYS cite your sources when using the provided context.\n"
            "4. Remind that your answers are for EDUCATIONAL purposes only.\n"
            "5. You specialize in the Swiss system (AHV/AI, LPP/BVG, 3rd pillar, cantonal taxes).\n"
            "6. Respond in the language of the question.\n"
            "7. If you don't know the answer, say so clearly. Never make things up.\n"
            "8. NEVER use the terms: guaranteed, assured, risk-free, certain return.\n\n"
            "Base your answers on the provided context (MINT knowledge base)."
        ),
        "it": (
            "Sei un assistente educativo svizzero per le finanze personali nell'app MINT.\n\n"
            "REGOLE RIGOROSE:\n"
            "1. Non raccomandare MAI un prodotto finanziario specifico.\n"
            "2. Non garantire MAI un rendimento o un risultato.\n"
            "3. Cita SEMPRE le tue fonti quando usi il contesto fornito.\n"
            "4. Ricorda che le tue risposte sono a scopo EDUCATIVO.\n"
            "5. Sei specializzato nel sistema svizzero (AVS/AI, LPP, 3o pilastro, fiscalità cantonale).\n"
            "6. Rispondi nella lingua della domanda.\n"
            "7. Se non conosci la risposta, dillo chiaramente. Non inventare mai.\n"
            "8. Non usare MAI i termini: garantito, assicurato, senza rischio.\n\n"
            "Basa le tue risposte sul contesto fornito (knowledge base MINT)."
        ),
    }

    # Safe fallback message when ComplianceGuard rejects the response.
    _SAFE_FALLBACK_FR = (
        "Je suis là pour t'aider à comprendre ta situation financière. "
        "N'hésite pas à reformuler ta question, ou explore les simulateurs "
        "pour des estimations chiffrées."
    )

    def filter_response(self, response: str, language: str = "fr") -> dict:
        """
        Apply compliance filters to a generated response.

        Delegates core validation to :class:`ComplianceGuard` (5-layer pipeline)
        when the language is French, falling back to legacy term replacement
        for other languages. Disclaimer logic is retained here because it is
        multilingual.

        Returns:
            dict with keys: text, warnings, disclaimers_added
        """
        filter_warnings: list[str] = []
        disclaimers_added: list[str] = []

        # ── Guard: None / non-string input ──
        if not isinstance(response, str):
            return {
                "text": self._SAFE_FALLBACK_FR,
                "warnings": ["Entrée invalide (non-string)"],
                "disclaimers_added": [],
            }

        # ── Delegate to ComplianceGuard for French (primary language) ──
        if language == "fr":
            try:
                from app.services.coach.compliance_guard import ComplianceGuard

                guard = ComplianceGuard()
                result = guard.validate(response)
                filter_warnings.extend(result.violations)
                if result.use_fallback:
                    # CRIT #3 fix: when ComplianceGuard rejects (prescriptive,
                    # hallucination, etc.), use safe fallback — NOT the original
                    # response filtered only for banned terms.
                    filtered_text = self._SAFE_FALLBACK_FR
                else:
                    filtered_text = result.sanitized_text
            except ImportError:
                filtered_text = self._legacy_filter_banned(response)
        else:
            filtered_text = self._legacy_filter_banned(response, language)
            # Populate warnings for non-French: detect which banned terms were present.
            response_lower = response.lower()
            for term in self.BANNED_TERMS:
                if " " in term:
                    pat = re.compile(re.escape(term), re.IGNORECASE)
                else:
                    pat = re.compile(
                        rf"(?<![{self._FR_LETTER}]){re.escape(term)}(?![{self._FR_LETTER}])",
                        re.IGNORECASE,
                    )
                if pat.search(response_lower):
                    filter_warnings.append(f"Terme interdit: '{term}'")

        # ── Disclaimer logic (multilingual, retained here) ──
        # For French, ComplianceGuard injects disclaimers into the text (Layer 4).
        # We reflect them into disclaimers_added for API consistency.
        if language == "fr":

            disclaimers_added.append(self.DISCLAIMERS["fr"]["general"])
            response_lower = response.lower()
            for term in self.REQUIRES_DISCLAIMER:
                if term.lower() in response_lower:
                    tax_terms = {
                        "impôt", "fiscal", "déduction",
                    }
                    if term.lower() in tax_terms:
                        if self.DISCLAIMERS["fr"]["tax"] not in disclaimers_added:
                            disclaimers_added.append(self.DISCLAIMERS["fr"]["tax"])
                    else:
                        if self.DISCLAIMERS["fr"]["investment"] not in disclaimers_added:
                            disclaimers_added.append(self.DISCLAIMERS["fr"]["investment"])
        else:
            response_lower = response.lower()
            needs_tax_disclaimer = False
            needs_investment_disclaimer = False

            for term in self.REQUIRES_DISCLAIMER:
                if term.lower() in response_lower:
                    tax_terms = {
                        "impôt", "fiscal", "déduction", "steuer", "steuerlich",
                        "abzug", "tax", "deduction", "imposta", "fiscale", "deduzione",
                    }
                    if term.lower() in tax_terms:
                        needs_tax_disclaimer = True
                    else:
                        needs_investment_disclaimer = True

            lang_disclaimers = self.DISCLAIMERS.get(language, self.DISCLAIMERS["fr"])
            disclaimers_added.append(lang_disclaimers["general"])

            if needs_tax_disclaimer:
                disclaimers_added.append(lang_disclaimers["tax"])

            if needs_investment_disclaimer:
                disclaimers_added.append(lang_disclaimers["investment"])

        # ── Layer/Couche doctrine leak scrubbing (PR A) ──
        filtered_text, layer_leak_count = self._scrub_layer_markers(filtered_text)
        if layer_leak_count:
            logger.info(
                "compliance.layer_leak_scrubbed count=%d lang=%s",
                layer_leak_count,
                language,
            )
            filter_warnings.append(
                f"Layer doctrine marker scrubbed ({layer_leak_count} occurrence(s))"
            )

        # ── Formal-vous detection (log-only; tutoiement is enforced at prompt level) ──
        formal_vous_count = self._count_formal_vous(filtered_text)
        if formal_vous_count:
            logger.info(
                "compliance.formal_vous_detected count=%d lang=%s",
                formal_vous_count,
                language,
            )

        return {
            "text": filtered_text,
            "warnings": filter_warnings,
            "disclaimers_added": disclaimers_added,
        }

    # ────────────────────────────────────────────────────────────────────
    # Post-filter helpers (PR A — prompt hardening)
    # ────────────────────────────────────────────────────────────────────

    @staticmethod
    def _scrub_layer_markers(text: str) -> tuple[str, int]:
        """Strip doctrine layer labels ("Couche 2 :", "Layer 1 -", "Niveau 3:").

        Returns (cleaned_text, hit_count). Collapses double whitespace produced
        by the replacement.
        """
        if not isinstance(text, str) or not text:
            return text, 0
        matches = _LAYER_LEAK_RE.findall(text)
        if not matches:
            return text, 0
        cleaned = _LAYER_LEAK_RE.sub("", text)
        # Collapse any run of >1 spaces AND any newline immediately followed
        # by leftover whitespace.
        cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)
        cleaned = re.sub(r"\n[ \t]+", "\n", cleaned)
        return cleaned.strip(), len(matches)

    @staticmethod
    def _count_formal_vous(text: str) -> int:
        """Count formal-singular "vous" occurrences (excludes 'vous deux')."""
        if not isinstance(text, str) or not text:
            return 0
        return len(_FORMAL_VOUS_RE.findall(text))

    @classmethod
    def filter_follow_up_questions(
        cls,
        questions: list[str],
        user_message: str,
        threshold: float = 0.6,
    ) -> list[str]:
        """Drop follow-up chips that paraphrase the user's last message.

        Uses Jaccard similarity over lowercased word tokens (>= 4 chars to
        ignore stopwords). A follow-up is rejected when similarity with the
        user's message exceeds ``threshold``.

        Fail-open: on unexpected input types, returns the original list
        unchanged.
        """
        if not isinstance(questions, list) or not isinstance(user_message, str):
            return questions  # type: ignore[return-value]

        user_tokens = cls._tokenize_for_similarity(user_message)
        if not user_tokens:
            return [q for q in questions if isinstance(q, str) and q.strip()]

        kept: list[str] = []
        dropped = 0
        for q in questions:
            if not isinstance(q, str) or not q.strip():
                continue
            q_tokens = cls._tokenize_for_similarity(q)
            if not q_tokens:
                kept.append(q)
                continue
            inter = len(user_tokens & q_tokens)
            union = len(user_tokens | q_tokens)
            jaccard = inter / union if union else 0.0
            if jaccard > threshold:
                dropped += 1
                continue
            kept.append(q)
        if dropped:
            logger.info(
                "compliance.follow_up_echo_dropped count=%d threshold=%.2f",
                dropped,
                threshold,
            )
        return kept

    @staticmethod
    def _tokenize_for_similarity(text: str) -> set[str]:
        """Lowercase word tokens, length >= 4, stripped of diacritics-light."""
        if not text:
            return set()
        # Strip markdown/punctuation, keep accented letters as-is.
        words = re.findall(r"[a-zà-ÿA-ZÀ-Ÿ0-9]{4,}", text.lower())
        return set(words)

    @classmethod
    def truncate_to_sentences(cls, text: str, max_sentences: int = 3) -> tuple[str, bool]:
        """Clamp ``text`` to at most ``max_sentences`` sentences.

        Splits on `.!?…` followed by whitespace. Preserves the terminal
        punctuation. Returns (text, was_truncated). No-op on empty input.

        Post-fix 2026-04-15 (bug Run-001 #1): list markers like "1.", "2.",
        "3." are merged into the following sentence instead of being
        counted as sentences themselves, and a kept truncation that ends
        on a dangling list marker or conjunction is cleaned up so the
        output never terminates mid-enumeration.
        """
        if not isinstance(text, str) or not text.strip():
            return text, False
        raw_parts = _SENTENCE_SPLIT_RE.split(text.strip())

        # Merge dangling list markers ("1.", "2.") into the following
        # sentence so they don't consume a slot.
        list_marker = re.compile(r"^\d+\.$")
        parts: list[str] = []
        pending: str | None = None
        for p in raw_parts:
            p = p.strip()
            if not p:
                continue
            if list_marker.match(p):
                pending = p
                continue
            if pending is not None:
                parts.append(f"{pending} {p}")
                pending = None
            else:
                parts.append(p)
        if pending is not None:
            # Trailing list marker with no following sentence — drop it.
            pass

        if len(parts) <= max_sentences:
            return " ".join(parts), False

        kept = parts[:max_sentences]
        # Clean up trailing fragment that ends on a bullet/conjunction
        # ("et", "mais", ",", "(" without close, etc.) — if the last kept
        # sentence clearly ends mid-thought, drop it rather than ship a
        # mutilated tail.
        last = kept[-1]
        ends_badly = (
            last.endswith(",")
            or re.search(r"\b(et|mais|ou|donc|car|puis|alors)\s*$", last, re.IGNORECASE)
            or (last.count("(") > last.count(")"))
        )
        if ends_badly and len(kept) > 1:
            kept = kept[:-1]
        truncated = " ".join(kept).strip()
        logger.info(
            "compliance.length_truncated original=%d kept=%d",
            len(parts),
            len(kept),
        )
        return truncated, True

    # French-aware letter class for word boundaries (matches À-ÿ range).
    _FR_LETTER = r"a-zA-Z\u00C0-\u00FF"

    def _legacy_filter_banned(self, response: str, language: str = "fr") -> str:
        """Legacy banned-term replacement for non-French languages.

        Uses French-aware word boundaries to avoid false positives on
        substrings like 'incertain' matching 'certain'.
        """
        filtered_text = response
        lower = response.lower()
        for term in self.BANNED_TERMS:
            if " " in term:
                pattern = re.compile(re.escape(term), re.IGNORECASE)
            else:
                pattern = re.compile(
                    rf"(?<![{self._FR_LETTER}]){re.escape(term)}(?![{self._FR_LETTER}])",
                    re.IGNORECASE,
                )
            if pattern.search(lower):
                filtered_text = pattern.sub(
                    self._get_replacement(term, language), filtered_text
                )
        return filtered_text

    def build_system_prompt(
        self,
        language: str = "fr",
        profile_context: Optional[dict] = None,
    ) -> str:
        """Return the MINT compliance system prompt for the given language.

        If profile_context contains a financial_summary, it is injected
        into the system prompt so the LLM can personalize its answers.

        If profile_context contains a canton field, canton-specific tax
        and housing data are injected so Claude is canton-aware.
        """
        base = self.SYSTEM_PROMPTS.get(language, self.SYSTEM_PROMPTS["fr"])

        if not profile_context:
            return base

        extra_blocks: list[str] = []

        # ── Canton-specific enrichment ──────────────────────────────────────
        canton = profile_context.get("canton")
        if canton:
            try:
                from app.services.rag.cantonal_knowledge import CantonalKnowledge

                tax = CantonalKnowledge.tax_specifics(canton)
                housing = CantonalKnowledge.housing_market(canton)

                canton_lines: list[str] = [f"Canton de l'utilisateur: {canton.upper()}"]

                if tax:
                    canton_lines.append(
                        f"Taux marginal cantonal+communal (approx.): {tax['marginal_rate_pct']}%"
                    )
                    canton_lines.append(
                        f"Impôt sur la fortune (‰): {tax['wealth_tax_rate_permille']}"
                    )
                    if tax.get("notable_deductions"):
                        deductions = ", ".join(tax["notable_deductions"])
                        canton_lines.append(f"Déductions notables: {deductions}")
                    canton_lines.append(f"Source fiscale: {tax['source']}")

                if housing:
                    canton_lines.append(
                        f"Loyer médian 4p (CHF/mois): {housing['median_rent_4pce_chf']}"
                    )
                    canton_lines.append(
                        f"Prix médian achat (CHF/m²): {housing['median_price_per_sqm_buy_chf']}"
                    )
                    canton_lines.append(
                        f"Pression immobilière: {housing['market_pressure']}"
                    )

                if len(canton_lines) > 1:
                    extra_blocks.append(
                        "\n\n--- CONTEXTE CANTONAL ---\n"
                        + "\n".join(canton_lines)
                        + "\n--- FIN CONTEXTE CANTONAL ---\n\n"
                        "Utilise ces données cantonales pour personnaliser tes réponses "
                        "fiscales et immobilières. "
                        "Données approximatives — estimations basées sur les données publiques cantonales 2024/2025 (LSFin)."
                    )
            except ImportError:
                pass

        # ── Financial summary ────────────────────────────────────────────────
        summary = profile_context.get("financial_summary")
        if summary:
            extra_blocks.append(
                "\n\n--- PROFIL FINANCIER DE L'UTILISATEUR ---\n"
                f"{summary}\n"
                "--- FIN DU PROFIL ---\n\n"
                "Utilise ces informations pour personnaliser tes réponses "
                "à la situation spécifique de l'utilisateur. "
                "Ne répète pas ces données textuellement, "
                "mais adapte tes explications et exemples en conséquence."
            )

        return base + "".join(extra_blocks)

    def _get_replacement(self, term: str, language: str) -> str:
        """Get a softer replacement for a banned term."""
        replacements = {
            # French
            "garanti": "potentiel",
            "assuré": "estimé",
            "certain": "probable",
            "sans risque": "à faible risque",
            "rendement fixe": "rendement estimé",
            "profit assuré": "potentiel de gain",
            # German
            "garantiert": "potenziell",
            "gesichert": "geschätzt",
            "sicher": "wahrscheinlich",
            "risikofrei": "risikoarm",
            "feste Rendite": "geschätzte Rendite",
            # English
            "guaranteed": "potential",
            "assured": "estimated",
            "certain return": "estimated return",
            "risk-free": "low-risk",
            "fixed return": "estimated return",
            # Italian
            "garantito": "potenziale",
            "assicurato": "stimato",
            "senza rischio": "a basso rischio",
        }
        return replacements.get(term.lower(), term)
