"""
Claude Coach Service — S56.

Server-side proxy for Claude API. The API key stays on the server,
never in the mobile app. Rate limiting per user.

Compliance:
    - Educational only (LSFin art. 3)
    - ComplianceGuard filters all output
    - No PII logged (no salary, no name in logs)
    - System prompt enforces MINT voice (5 pillars)
"""

import logging
import os
import re
from typing import List, Optional

from app.core.config import settings

# Lazy import: anthropic SDK may not be installed in all environments (CI cache).
# The service degrades gracefully without it.
try:
    from anthropic import Anthropic
    _HAS_ANTHROPIC = True
except ImportError:
    Anthropic = None  # type: ignore[assignment,misc]
    _HAS_ANTHROPIC = False

logger = logging.getLogger(__name__)

# Banned terms that must never appear in coach output
BANNED_TERMS = [
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait",
    "conseiller",  # → use "specialiste"
    "voici ta situation",
    "n'hesite pas",
    "excellent travail", "bravo", "felicitations",
]

DISCLAIMER = (
    "Outil educatif — ne constitue pas un conseil financier (LSFin art. 3). "
    "Consulte un-e specialiste pour les decisions importantes."
)


def build_system_prompt(
    *,
    first_name: Optional[str] = None,
    age: Optional[int] = None,
    canton: Optional[str] = None,
    salary_annual: Optional[float] = None,
    civil_status: Optional[str] = None,
    archetype: Optional[str] = None,
    financial_literacy_level: str = "intermediate",
    fri_total: Optional[int] = None,
    replacement_ratio: Optional[float] = None,
    confidence_score: Optional[float] = None,
    avoir_lpp: Optional[float] = None,
    epargne_3a: Optional[float] = None,
    total_dettes: Optional[float] = None,
    last_cap_served: Optional[str] = None,
    completed_actions: Optional[List[str]] = None,
    abandoned_flows: Optional[List[str]] = None,
    declared_goals: Optional[List[str]] = None,
) -> str:
    """Build the MINT coach system prompt with user context."""

    name = first_name or "utilisateur"

    parts = [
        f"Tu es le coach financier MINT. Tu aides {name} a comprendre "
        "sa situation financiere suisse.",
        "",
        "VOIX MINT (5 piliers) :",
        "- CALME : Tu parles calmement, jamais dans l'urgence.",
        "- PRECIS : Chaque mot est choisi. Pas de remplissage.",
        "- FIN : Understatement suisse romand. L'esprit nait de "
        "l'observation, pas de la blague.",
        "- RASSURANT : 'On va y arriver, voici par ou commencer.' "
        "Accompagne sans porter.",
        "- NET : Dis la verite, meme inconfortable, avec tact.",
        "",
        "REGLES ABSOLUES :",
        "- Tu NE calcules JAMAIS. Tu utilises uniquement les donnees "
        "fournies par le systeme.",
        "- Tu NE donnes JAMAIS de conseil financier. Tu es educatif.",
        "- Tu dis toujours 'consulte un-e specialiste' pour les "
        "decisions importantes.",
        "- Tu parles en francais, tu tutoies.",
        "- Tu cites TOUJOURS tes sources legales (LPP art. X, "
        "OPP3 art. Y, LIFD art. Z, etc.).",
        "- Tu NE dis JAMAIS : 'garanti', 'certain', 'assure', "
        "'sans risque', 'optimal', 'meilleur', 'parfait'.",
        "- Tu NE dis JAMAIS : 'Voici ta situation', 'N'hesite pas', "
        "'Excellent travail', 'Bravo', 'Felicitations'.",
        "- Tu ajoutes un disclaimer si tu parles de projections.",
        "- Commence par le chiffre ou le fait. Explique apres.",
        "",
    ]

    # Literacy adaptation
    if financial_literacy_level == "beginner":
        parts.append(
            "ADAPTATION : Niveau NOVICE — phrases courtes, pas de sigle "
            "sans explication, metaphores concretes."
        )
    elif financial_literacy_level == "advanced":
        parts.append(
            "ADAPTATION : Niveau EXPERT — references legales directes, "
            "scenarios avances, hypotheses editables."
        )
    else:
        parts.append(
            "ADAPTATION : Niveau AUTONOME — sigles OK, chiffres directs, "
            "moins de contexte."
        )

    # User context
    parts.append("")
    parts.append("CONTEXTE UTILISATEUR :")
    if age:
        parts.append(f"- Age : {age}")
    if canton:
        parts.append(f"- Canton : {canton}")
    if civil_status:
        parts.append(f"- Statut : {civil_status}")
    if archetype:
        parts.append(f"- Archetype : {archetype}")
    if fri_total is not None:
        parts.append(f"- Score Fitness : {fri_total}/100")
    if replacement_ratio is not None:
        parts.append(f"- Taux de remplacement : {replacement_ratio:.1f}%")
    if confidence_score is not None:
        parts.append(f"- Confiance donnees : {confidence_score:.0f}%")
    if avoir_lpp is not None:
        parts.append(f"- Avoir LPP : ~CHF {avoir_lpp:,.0f}")
    if epargne_3a is not None and epargne_3a > 0:
        parts.append(f"- Epargne 3a : ~CHF {epargne_3a:,.0f}")
    if total_dettes is not None and total_dettes > 0:
        parts.append(f"- Dettes : ~CHF {total_dettes:,.0f}")

    # Coach memory (CapMemory context)
    if completed_actions:
        recent = completed_actions[-5:]
        parts.append(f"- Actions realisees recemment : {', '.join(recent)}")
    if abandoned_flows:
        recent = abandoned_flows[-3:]
        parts.append(f"- Flows abandonnes : {', '.join(recent)}")
    if declared_goals:
        parts.append(f"- Objectifs declares : {', '.join(declared_goals)}")
    if last_cap_served:
        parts.append(f"- Dernier cap servi : {last_cap_served}")

    parts.append("")
    parts.append(
        "STRUCTURE DE TA REPONSE :"
    )
    parts.append("- Commence par le chiffre ou le fait.")
    parts.append("- Propose 1-3 actions concretes.")
    parts.append("- Cite tes sources legales.")
    parts.append(
        "- Termine par : 'Outil educatif, ne constitue pas "
        "un conseil financier.'"
    )

    return "\n".join(parts)


def compliance_filter(text: str) -> str:
    """Filter banned terms from coach output."""
    result = text
    for term in BANNED_TERMS:
        pattern = re.compile(re.escape(term), re.IGNORECASE)
        if pattern.search(result):
            logger.warning("Compliance: filtered banned term '%s'", term)
            if term == "conseiller":
                result = pattern.sub("specialiste", result)
            elif term in ("bravo", "felicitations", "excellent travail"):
                result = pattern.sub("", result)
            else:
                result = pattern.sub("[terme filtre]", result)
    return result.strip()


class ClaudeCoachService:
    """Server-side Claude proxy for MINT coach."""

    def __init__(self):
        if not _HAS_ANTHROPIC:
            logger.warning("anthropic SDK not installed — coach chat disabled")
            self._client = None
            return
        api_key = settings.ANTHROPIC_API_KEY
        if not api_key:
            logger.warning("ANTHROPIC_API_KEY not set — coach chat disabled")
            self._client = None
        else:
            self._client = Anthropic(api_key=api_key)

    @property
    def is_available(self) -> bool:
        return self._client is not None

    def chat(
        self,
        *,
        message: str,
        conversation_history: list,
        system_prompt: str,
    ) -> dict:
        """Send a message to Claude with tool calling.

        Claude can choose to call a tool (show a widget) alongside
        its text response. The response includes both 'reply' (text)
        and optionally 'widget' (tool call with parameters).

        Returns:
            dict with 'reply', 'model', 'tokens_used', 'widget' (optional)
        """
        if not self._client:
            return {
                "reply": (
                    "Le coach IA n'est pas disponible pour le moment. "
                    "Les outils et simulateurs restent accessibles."
                ),
                "model": "fallback",
                "tokens_used": 0,
            }

        from app.services.coach.coach_tools import COACH_TOOLS

        # Build messages array
        messages = []
        for msg in conversation_history[-20:]:
            messages.append({
                "role": msg.get("role", "user"),
                "content": msg.get("content", ""),
            })
        messages.append({"role": "user", "content": message})

        try:
            response = self._client.messages.create(
                model=settings.COACH_MODEL,
                max_tokens=settings.COACH_MAX_TOKENS,
                system=system_prompt,
                messages=messages,
                tools=COACH_TOOLS,
            )

            # Extract text and tool calls from response
            reply_text = ""
            widget = None

            for block in response.content:
                if block.type == "text":
                    reply_text = block.text
                elif block.type == "tool_use":
                    widget = {
                        "tool": block.name,
                        "params": block.input,
                    }

            filtered = compliance_filter(reply_text) if reply_text else ""

            # Ensure disclaimer
            if filtered and "educatif" not in filtered.lower():
                filtered += f"\n\n_{DISCLAIMER}_"

            total_tokens = (
                response.usage.input_tokens + response.usage.output_tokens
            )

            result = {
                "reply": filtered,
                "model": settings.COACH_MODEL,
                "tokens_used": total_tokens,
            }

            if widget:
                result["widget"] = widget

            return result

        except Exception as e:
            logger.error("Claude API error: %s", str(e))
            return {
                "reply": (
                    "Je n'ai pas pu traiter ta question. "
                    "Les outils restent accessibles."
                ),
                "model": "error",
                "tokens_used": 0,
            }
