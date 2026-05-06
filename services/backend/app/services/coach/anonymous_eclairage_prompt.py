"""
Anonymous Premier Éclairage prompt + builder (Phase 71b, 6-locale Phase 94).

The Premier Éclairage is a single, panel-locked, LSFin-compliant insight
emitted exactly once per anonymous session after coach turn 2. It surfaces
a hidden lever (e.g. unused fiscal margin on pillar 3a) without ever
quoting an absolute CHF figure for the user (no KYC at this stage).

Locked spec (Phase 71 panel verdict):
    kind: fiscal_margin_3a (default for v2.10 anonymous flow)
    headline: "Marge fiscale 3a non utilisée"
    body: see DEFAULT_FISCAL_MARGIN_3A_BODY below
    chf_range_low/high: 1500 / 2500 / period=year
    soft_account_hint: "Crée ton compte pour suivre ça."
    lsfin_disclaimer: locked educational-purpose disclaimer

Phase 94 / COMP-02: locale-aware payload (FR/DE/IT/EN/ES/PT) — FinSA art. 8 al. 1
let. d compliance. The FR variant is byte-identical to the Phase 71 panel
output; non-FR variants are translations vetted against ComplianceGuard.BANNED_TERMS.

Compliance:
    - LSFin art. 3 — information financiere, pas de conseil personnalise
    - LSFin art. 7-10 — no return guarantee, conditional formulations
    - No banned terms (« garanti », « optimal », « meilleur », etc.)
    - FinSA art. 8 al. 1 let. d — language alignment with the user's locale
"""

from __future__ import annotations

import logging

from app.schemas.anonymous_chat import EclairagePayload

logger = logging.getLogger(__name__)


# Locked headline + body (panel-validated FR, Phase 71)
DEFAULT_FISCAL_MARGIN_3A_HEADLINE = "Marge fiscale 3a non utilisée"

DEFAULT_FISCAL_MARGIN_3A_BODY = (
    "En Suisse, salarié·e, tu peux mettre jusqu'à CHF 7'258/an dans un 3a "
    "et déduire ce montant de ton revenu imposable. Pour beaucoup, ça "
    "représente ~CHF 1'500 à 2'500/an d'impôt en moins, selon ton canton "
    "et ton taux marginal."
)

DEFAULT_SOFT_ACCOUNT_HINT = "Crée ton compte pour suivre ça."


# Phase 94 / COMP-02 — 6-locale registry. Each variant cites the legal
# Swiss law constant CHF 7'258 (apostrophe in FR/DE/IT/ES/PT, comma in EN
# per UK/US convention). The conditional « selon ton canton » idiom is
# preserved in every locale so no return is implicitly promised.
_ECLAIRAGE_BY_LANGUAGE: dict[str, dict[str, str]] = {
    "fr": {
        "headline": DEFAULT_FISCAL_MARGIN_3A_HEADLINE,
        "body": DEFAULT_FISCAL_MARGIN_3A_BODY,
        "soft_account_hint": DEFAULT_SOFT_ACCOUNT_HINT,
    },
    "de": {
        "headline": "Ungenutzter steuerlicher Spielraum 3a",
        "body": (
            "In der Schweiz, als Angestellte·r, kannst du bis zu CHF 7'258/Jahr "
            "in eine Säule 3a einzahlen und diesen Betrag vom steuerbaren "
            "Einkommen abziehen. Für viele sind das ~CHF 1'500–2'500/Jahr "
            "weniger Steuern, je nach Kanton und Grenzsatz."
        ),
        "soft_account_hint": "Erstelle dein Konto, um dies zu verfolgen.",
    },
    "it": {
        "headline": "Margine fiscale 3a non utilizzato",
        "body": (
            "In Svizzera, come dipendente, puoi versare fino a CHF 7'258/anno "
            "in un pilastro 3a e dedurlo dal reddito imponibile. Per molti, "
            "ciò vale ~CHF 1'500–2'500/anno di imposte in meno, a seconda "
            "del cantone e dell'aliquota marginale."
        ),
        "soft_account_hint": "Crea il tuo account per seguire questo.",
    },
    "en": {
        "headline": "Unused 3a tax allowance",
        "body": (
            "In Switzerland, as an employee, you can contribute up to "
            "CHF 7,258/year to a 3a pillar and deduct this from your taxable "
            "income. For many, that means ~CHF 1,500–2,500/year less in tax, "
            "depending on your canton and marginal rate."
        ),
        "soft_account_hint": "Create your account to track this.",
    },
    "es": {
        "headline": "Margen fiscal 3a no utilizado",
        "body": (
            "En Suiza, como empleado·a, puedes aportar hasta CHF 7'258/año a "
            "un pilar 3a y deducir este importe de tu renta imponible. Para "
            "muchos, eso representa ~CHF 1'500–2'500/año menos de impuestos, "
            "según tu cantón y tu tipo marginal."
        ),
        "soft_account_hint": "Crea tu cuenta para seguir esto.",
    },
    "pt": {
        "headline": "Margem fiscal 3a não utilizada",
        "body": (
            "Na Suíça, como empregado·a, podes contribuir até CHF 7'258/ano "
            "num pilar 3a e deduzir esse montante do rendimento tributável. "
            "Para muitos, é ~CHF 1'500–2'500/ano de imposto a menos, conforme "
            "o cantão e a tua taxa marginal."
        ),
        "soft_account_hint": "Cria a tua conta para acompanhar isto.",
    },
}


def build_default_fiscal_margin_3a_eclairage(language: str = "fr") -> EclairagePayload:
    """Return the locked default Premier Éclairage payload (Phase 71b).

    Phase 94 / COMP-02: locale-aware. Falls back to FR with a warning log
    if `language` is not in the supported registry (FR/DE/IT/EN/ES/PT).

    LSFin compliance:
        - No absolute CHF figure for the user (we cite the legal cap CHF 7'258
          which is a public Swiss law constant, not a personalized number).
        - Range CHF 1'500–2'500/year is conditional ("selon ton canton et
          ton taux marginal") with disclaimer.
        - FinSA art. 8 al. 1 let. d — body language matches the user's locale.
    """
    variant = _ECLAIRAGE_BY_LANGUAGE.get(language)
    if variant is None:
        logger.warning(
            "anonymous_eclairage: unsupported language=%r, falling back to fr",
            language,
        )
        variant = _ECLAIRAGE_BY_LANGUAGE["fr"]
    return EclairagePayload(
        kind="fiscal_margin_3a",
        headline=variant["headline"],
        body=variant["body"],
        chf_range_low=1500,
        chf_range_high=2500,
        chf_range_period="year",
        soft_account_hint=variant["soft_account_hint"],
    )
