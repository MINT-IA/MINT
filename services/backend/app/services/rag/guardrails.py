"""
Compliance guardrails for Swiss financial content.

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

import re
from typing import Optional


class ComplianceGuardrails:
    """Post-generation compliance filter for Swiss financial content.

    .. deprecated:: S34
        Use :class:`app.services.coach.compliance_guard.ComplianceGuard` for
        the full 5-layer validation. This class is kept for RAG orchestrator
        backward compatibility.
    """

    # Terms that should never appear in financial advice (implies guarantees)
    BANNED_TERMS = [
        # French
        "garanti",
        "assuré",
        "certain",
        "sans risque",
        "rendement fixe",
        "profit assuré",
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

        # ── Disclaimer logic (multilingual, retained here) ──
        # Only add disclaimers for non-French languages.
        # For French, ComplianceGuard already handles disclaimer injection
        # in Layer 4 — adding them here too would double-inject.
        if language != "fr":
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

        return {
            "text": filtered_text,
            "warnings": filter_warnings,
            "disclaimers_added": disclaimers_added,
        }

    def _legacy_filter_banned(self, response: str, language: str = "fr") -> str:
        """Legacy banned-term replacement for non-French languages."""
        filtered_text = response
        response_lower = response.lower()
        for term in self.BANNED_TERMS:
            if term.lower() in response_lower:
                pattern = re.compile(re.escape(term), re.IGNORECASE)
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
        """
        base = self.SYSTEM_PROMPTS.get(language, self.SYSTEM_PROMPTS["fr"])

        if not profile_context:
            return base

        summary = profile_context.get("financial_summary")
        if not summary:
            return base

        # Inject the user's financial profile into the system prompt
        profile_block = (
            "\n\n--- PROFIL FINANCIER DE L'UTILISATEUR ---\n"
            f"{summary}\n"
            "--- FIN DU PROFIL ---\n\n"
            "Utilise ces informations pour personnaliser tes réponses "
            "à la situation spécifique de l'utilisateur. "
            "Ne répète pas ces données textuellement, "
            "mais adapte tes explications et exemples en conséquence."
        )

        return base + profile_block

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
