"""FATCA pre-emission gate for the expat_us archetype (Phase 93 — COMP-04).

When a user with archetype ``expat_us`` asks the coach about
3a / pillar3a / PFIC / CH-US treaty / FBAR / foreign trust topics, we
MUST short-circuit the LLM call and return a hand-off card pointing the
user to a US-CH cross-border specialist instead. Generic 3a impératifs
are dangerous for US persons (FATCA reporting, FBAR threshold, PFIC
classification of Swiss funds, CH-US double-taxation convention) and
the existing post-validation rule in ``doctrine_checks.py:291`` only
catches issues *after* the LLM emits text.

This module provides the topic-detection regex + the localized hand-off
payload builder. The endpoint wires both at ``coach_chat.py`` Step 2.5.

Per OAR-G art. 24 + FINMA Guidance 8/2024 §VI.

Closes:
    - REQUIREMENTS.md COMP-04
    - USER_WALKTHROUGH_2026-05-06 BUG #22 P1
"""

from __future__ import annotations

import re
from typing import Optional

from pydantic import BaseModel, Field

__all__ = [
    "_topic_is_fatca_sensitive",
    "build_fatca_handoff_card",
    "FatcaHandoffPayload",
    "SUPPORTED_LANGUAGES",
]


SUPPORTED_LANGUAGES = ("fr", "en", "de", "es", "it", "pt")


# Topic regex set. Tight by design — only FATCA-relevant tokens fire the
# gate. Mortgage / budget / divorce / health-insurance questions for
# ``expat_us`` users still pass through to the LLM normally so we never
# over-block (per threat T-93-07).
_TOPIC_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "3a_or_pillar3a",
        re.compile(
            r"\b("
            r"3a"
            r"|3\s*[èe]me\s+pilier"
            r"|troisi[èe]me\s+pilier"
            r"|pillar\s*3a"
            r"|pilier\s*3a"
            r")\b",
            re.IGNORECASE,
        ),
    ),
    (
        "pfic",
        re.compile(r"\bPFIC\b", re.IGNORECASE),
    ),
    (
        "treaty",
        re.compile(
            r"\b("
            r"treaty"
            r"|convention\s+(CH-US|fiscale\s+US|bilat[eé]rale\s+US)"
            r")\b",
            re.IGNORECASE,
        ),
    ),
    (
        "foreign_trust_fbar",
        re.compile(
            r"\b(foreign\s+trust|form\s+3520|fbar)\b",
            re.IGNORECASE,
        ),
    ),
]


def _topic_is_fatca_sensitive(text: str) -> Optional[str]:
    """Return the matched topic label if any FATCA-sensitive pattern hits.

    Args:
        text: The sanitized user message.

    Returns:
        The label of the first matching pattern (one of
        ``"3a_or_pillar3a"`` / ``"pfic"`` / ``"treaty"`` /
        ``"foreign_trust_fbar"``) or ``None`` if no pattern matches.
        The label is used by the Sentry breadcrumb downstream so we
        can monitor gate fire-rate by topic in Phase 96.
    """
    if not isinstance(text, str) or not text:
        return None
    for label, pattern in _TOPIC_PATTERNS:
        if pattern.search(text):
            return label
    return None


# Localized hand-off card strings. SOURCE OF TRUTH for the FR copy is
# the ARB file ``apps/mobile/lib/l10n/app_fr.arb`` (keys
# ``fatcaHandoffTitle`` / ``fatcaHandoffBody`` / ``fatcaHandoffCta``);
# the backend mirrors the same strings here so the hand-off response
# is self-sufficient (the mobile widget can either render via key
# lookup or display the inline ``message`` from the response — both
# produce the same visible text). Drift between the ARB and this dict
# is caught by the 18-string test in
# ``tests/test_fatca_pre_emission_gate.py``.
#
# All strings are CLAUDE.md règle 1 clean (no « optimal » / « garanti »
# / « meilleur » / « parfait » / « sans risque ») and CLAUDE.md règle 2
# clean for FR (proper diacritics).
_HANDOFF_STRINGS: dict[str, dict[str, str]] = {
    "fr": {
        "title": "Situation US-CH : un éclairage spécialisé est utile",
        "body": (
            "En tant que contribuable US en Suisse, ta situation 3a interagit "
            "avec FATCA, FBAR (au-dessus de $10 000 sur l'ensemble de tes "
            "comptes étrangers) et la classification PFIC de certains fonds "
            "suisses. La convention CH-US prévoit des mécanismes contre la "
            "double imposition. Avant tout versement 3a, il pourrait être "
            "adapté d'en parler à un·e spécialiste US-CH cross-border, qui "
            "saura cadrer ta décision selon ta situation."
        ),
        "cta": "Trouver un·e spécialiste US-CH",
    },
    "en": {
        "title": "US-CH situation: a specialist perspective is useful",
        "body": (
            "As a US taxpayer living in Switzerland, your pillar 3a situation "
            "interacts with FATCA, FBAR (when your foreign account total goes "
            "above $10,000) and the PFIC classification that may apply to "
            "some Swiss funds. The CH-US tax treaty provides mechanisms to "
            "avoid double taxation. Before making any pillar 3a contribution, "
            "it could be adapted to discuss your situation with a US-CH "
            "cross-border specialist who can frame the decision around your "
            "specific case."
        ),
        "cta": "Find a US-CH specialist",
    },
    "de": {
        "title": "US-CH-Situation: eine Fachperspektive ist hilfreich",
        "body": (
            "Als US-Steuerpflichtige·r in der Schweiz hat deine Säule-3a-"
            "Situation Wechselwirkungen mit FATCA, FBAR (sobald die Summe "
            "deiner ausländischen Konten 10 000 USD übersteigt) und der "
            "PFIC-Klassifikation gewisser Schweizer Fonds. Das CH-US-"
            "Doppelbesteuerungsabkommen sieht Mechanismen gegen "
            "Doppelbesteuerung vor. Vor einer Säule-3a-Einzahlung könnte "
            "es passend sein, dich mit einer US-CH Cross-Border-Fachperson "
            "auszutauschen, die deine Entscheidung situationsgerecht "
            "einordnen kann."
        ),
        "cta": "US-CH-Fachperson finden",
    },
    "es": {
        "title": "Situación US-CH: una perspectiva especializada es útil",
        "body": (
            "Como contribuyente estadounidense residente en Suiza, tu "
            "situación de pilar 3a interactúa con FATCA, FBAR (cuando el "
            "total de tus cuentas extranjeras supera los 10 000 USD) y la "
            "clasificación PFIC que puede aplicarse a ciertos fondos suizos. "
            "El convenio fiscal CH-US prevé mecanismos contra la doble "
            "imposición. Antes de realizar cualquier aportación al pilar 3a, "
            "podría ser adecuado conversar con un·a especialista US-CH "
            "cross-border que ayude a enmarcar tu decisión según tu "
            "situación."
        ),
        "cta": "Encontrar un·a especialista US-CH",
    },
    "it": {
        "title": "Situazione US-CH: un parere specialistico è utile",
        "body": (
            "In quanto contribuente statunitense residente in Svizzera, la "
            "tua situazione del pilastro 3a interagisce con FATCA, FBAR "
            "(quando il totale dei tuoi conti esteri supera i 10 000 USD) e "
            "la classificazione PFIC che può riguardare alcuni fondi "
            "svizzeri. La convenzione fiscale CH-US prevede meccanismi "
            "contro la doppia imposizione. Prima di qualsiasi versamento al "
            "pilastro 3a, potrebbe essere adeguato confrontarsi con un·a "
            "specialista US-CH cross-border che inquadri la decisione "
            "rispetto alla tua situazione."
        ),
        "cta": "Trovare un·a specialista US-CH",
    },
    "pt": {
        "title": "Situação US-CH: uma perspetiva especializada é útil",
        "body": (
            "Enquanto contribuinte dos EUA residente na Suíça, a tua "
            "situação do pilar 3a interage com FATCA, FBAR (quando o total "
            "das tuas contas estrangeiras ultrapassa 10 000 USD) e a "
            "classificação PFIC que pode incidir sobre certos fundos suíços. "
            "A convenção fiscal CH-US prevê mecanismos contra a dupla "
            "tributação. Antes de qualquer contribuição ao pilar 3a, poderia "
            "ser adequado conversar com um·a especialista US-CH cross-"
            "border que enquadre a tua decisão de acordo com a tua "
            "situação."
        ),
        "cta": "Encontrar um·a especialista US-CH",
    },
}


class FatcaHandoffPayload(BaseModel):
    """Pre-emission FATCA hand-off card payload.

    Attributes:
        message: The localized hand-off body text. Returned to the
            client as ``CoachChatResponse.message`` so even older mobile
            builds without the ``FatcaHandoffCard`` widget still see
            the FATCA context (graceful degradation).
        tool_call: A Flutter-bound tool_call dict matching the existing
            ``{"name": str, "input": dict}`` shape consumed by the
            mobile dispatcher (see ``coach_chat.py:1222``). Contains
            the ARB key names so the mobile side can render via
            ``AppLocalizations.of(context)!`` for native typography.
        topic_label: Populated by the caller (the endpoint) with the
            ``_topic_is_fatca_sensitive`` return value. Used for the
            Sentry breadcrumb only — never returned to the client.
    """

    message: str
    tool_call: dict
    topic_label: str = Field(default="")


def build_fatca_handoff_card(language: str = "fr") -> FatcaHandoffPayload:
    """Build the localized FATCA hand-off card payload.

    Args:
        language: ISO 639-1 language code. Falls back to ``"fr"`` for
            unsupported languages so the gate never breaks on an
            unexpected locale.

    Returns:
        A :class:`FatcaHandoffPayload` ready to be returned from the
        coach chat endpoint. ``topic_label`` is empty by default — the
        caller populates it after running ``_topic_is_fatca_sensitive``
        so the Sentry breadcrumb can record which pattern matched.

    Per OAR-G art. 24 + FINMA Guidance 8/2024 §VI.
    """
    lang = language if language in SUPPORTED_LANGUAGES else "fr"
    strings = _HANDOFF_STRINGS[lang]
    return FatcaHandoffPayload(
        message=f"{strings['title']}\n\n{strings['body']}",
        tool_call={
            "name": "show_handoff_card",
            "input": {
                "kind": "fatca",
                "title_key": "fatcaHandoffTitle",
                "body_key": "fatcaHandoffBody",
                "cta_key": "fatcaHandoffCta",
                "title": strings["title"],
                "body": strings["body"],
                "cta": strings["cta"],
            },
        },
        topic_label="",
    )
