"""
MINT — Server-side translations for API response disclaimers.

This module provides multilingual disclaimer text and short UI labels
used in JSON API responses. The six supported locales cover the four
Swiss national languages plus Portuguese and Spanish for seasonal
and cross-border workers.

Swiss legal terms (AVS, LPP, LAMal, LACI, ...) are intentionally kept
in French across *all* locales to match official Federal publications
and avoid legal ambiguity.

Usage:
    from app.services.i18n import get_disclaimer, get_translation

    disclaimer = get_disclaimer("fr")
    label = get_translation("pt", "educational_notice")
"""

from __future__ import annotations

from typing import Dict

# ---------------------------------------------------------------------------
# Public constants
# ---------------------------------------------------------------------------
SUPPORTED_LOCALES = ("fr", "de", "en", "it", "pt", "es")
DEFAULT_LOCALE = "fr"

# ---------------------------------------------------------------------------
# Disclaimers — shown at the bottom of every financial report / simulation
# ---------------------------------------------------------------------------
_DISCLAIMERS: Dict[str, str] = {
    "fr": (
        "Les informations fournies par MINT sont a caractere educatif uniquement. "
        "Elles ne constituent ni un conseil financier, ni un conseil fiscal, "
        "ni une recommandation d'investissement. Consultez un professionnel "
        "agree pour toute decision financiere importante."
    ),
    "de": (
        "Die von MINT bereitgestellten Informationen dienen ausschliesslich "
        "Bildungszwecken. Sie stellen weder eine Finanzberatung noch eine "
        "Steuerberatung noch eine Anlageempfehlung dar. Wenden Sie sich "
        "fuer wichtige finanzielle Entscheidungen an einen zugelassenen Fachmann."
    ),
    "en": (
        "The information provided by MINT is for educational purposes only. "
        "It does not constitute financial advice, tax advice, or an investment "
        "recommendation. Consult a licensed professional for any important "
        "financial decision."
    ),
    "it": (
        "Le informazioni fornite da MINT hanno scopo puramente educativo. "
        "Non costituiscono consulenza finanziaria, consulenza fiscale, "
        "ne una raccomandazione di investimento. Consultate un professionista "
        "abilitato per qualsiasi decisione finanziaria importante."
    ),
    "pt": (
        "As informacoes fornecidas pela MINT tem carater exclusivamente educativo. "
        "Nao constituem aconselhamento financeiro, fiscal, nem recomendacao "
        "de investimento. Consulte um profissional certificado para qualquer "
        "decisao financeira importante."
    ),
    "es": (
        "La informacion proporcionada por MINT tiene caracter exclusivamente "
        "educativo. No constituye asesoramiento financiero, fiscal, ni una "
        "recomendacion de inversion. Consulte a un profesional autorizado "
        "para cualquier decision financiera importante."
    ),
}

# ---------------------------------------------------------------------------
# Short labels — reusable snippets for API JSON payloads
# ---------------------------------------------------------------------------
_TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "educational_notice": {
        "fr": "A titre educatif uniquement",
        "de": "Nur zu Bildungszwecken",
        "en": "For educational purposes only",
        "it": "Solo a scopo educativo",
        "pt": "Apenas para fins educativos",
        "es": "Solo con fines educativos",
    },
    "report_generated": {
        "fr": "Rapport genere le {date}",
        "de": "Bericht erstellt am {date}",
        "en": "Report generated on {date}",
        "it": "Rapporto generato il {date}",
        "pt": "Relatorio gerado em {date}",
        "es": "Informe generado el {date}",
    },
    "data_source": {
        "fr": "Source: Administration federale des contributions (AFC)",
        "de": "Quelle: Eidgenoessische Steuerverwaltung (ESTV)",
        "en": "Source: Federal Tax Administration (FTA)",
        "it": "Fonte: Amministrazione federale delle contribuzioni (AFC)",
        "pt": "Fonte: Administracao Federal de Contribuicoes (AFC)",
        "es": "Fuente: Administracion Federal de Contribuciones (AFC)",
    },
    "no_personal_data": {
        "fr": "Aucune donnee personnelle n'est partagee avec des tiers.",
        "de": "Es werden keine personenbezogenen Daten an Dritte weitergegeben.",
        "en": "No personal data is shared with third parties.",
        "it": "Nessun dato personale viene condiviso con terze parti.",
        "pt": "Nenhum dado pessoal e partilhado com terceiros.",
        "es": "Ningun dato personal se comparte con terceros.",
    },
    "swiss_legal_terms_notice": {
        "fr": "Les termes AVS, LPP, LAMal et LACI font reference aux lois federales suisses.",
        "de": "Die Begriffe AVS, LPP, LAMal und LACI beziehen sich auf Schweizer Bundesgesetze.",
        "en": "The terms AVS, LPP, LAMal and LACI refer to Swiss federal laws.",
        "it": "I termini AVS, LPP, LAMal e LACI si riferiscono alle leggi federali svizzere.",
        "pt": "Os termos AVS, LPP, LAMal e LACI referem-se as leis federais suicas.",
        "es": "Los terminos AVS, LPP, LAMal y LACI se refieren a las leyes federales suizas.",
    },
}


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def _normalise_locale(locale: str) -> str:
    """Return a supported locale code, falling back to French."""
    code = locale.lower().strip()[:2]
    return code if code in SUPPORTED_LOCALES else DEFAULT_LOCALE


def get_disclaimer(locale: str = DEFAULT_LOCALE) -> str:
    """Return the legal disclaimer in the requested language."""
    return _DISCLAIMERS[_normalise_locale(locale)]


def get_translation(locale: str, key: str) -> str:
    """Return a translated label for the given *key*.

    Parameters
    ----------
    locale : str
        ISO 639-1 language code (e.g. ``"pt"``).
    key : str
        Translation key (e.g. ``"educational_notice"``).

    Returns
    -------
    str
        The translated string, or the French fallback if the key/locale
        combination is unknown.
    """
    code = _normalise_locale(locale)
    entry = _TRANSLATIONS.get(key, {})
    return entry.get(code, entry.get(DEFAULT_LOCALE, f"[{key}]"))


def get_all_disclaimers() -> Dict[str, str]:
    """Return disclaimers for every supported locale (useful for PDF exports)."""
    return dict(_DISCLAIMERS)
