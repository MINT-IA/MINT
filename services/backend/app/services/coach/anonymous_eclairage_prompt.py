"""
Anonymous Premier Éclairage prompt + builder (Phase 71b).

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

Compliance:
    - LSFin art. 3 — information financiere, pas de conseil personnalise
    - LSFin art. 7-10 — no return guarantee, conditional formulations
    - No banned terms (« garanti », « optimal », « meilleur », etc.)
"""

from __future__ import annotations

from app.schemas.anonymous_chat import EclairagePayload


# Locked headline + body (panel-validated FR, Phase 71)
DEFAULT_FISCAL_MARGIN_3A_HEADLINE = "Marge fiscale 3a non utilisée"

DEFAULT_FISCAL_MARGIN_3A_BODY = (
    "En Suisse, salarié·e, tu peux mettre jusqu'à CHF 7'258/an dans un 3a "
    "et déduire ce montant de ton revenu imposable. Pour beaucoup, ça "
    "représente ~CHF 1'500 à 2'500/an d'impôt en moins, selon ton canton "
    "et ton taux marginal."
)

DEFAULT_SOFT_ACCOUNT_HINT = "Crée ton compte pour suivre ça."


def build_default_fiscal_margin_3a_eclairage() -> EclairagePayload:
    """Return the locked default Premier Éclairage payload (Phase 71b).

    LSFin compliance:
        - No absolute CHF figure for the user (we cite the legal cap CHF 7'258
          which is a public Swiss law constant, not a personalized number).
        - Range CHF 1'500–2'500/year is conditional ("selon ton canton et
          ton taux marginal") with disclaimer.
    """
    return EclairagePayload(
        kind="fiscal_margin_3a",
        headline=DEFAULT_FISCAL_MARGIN_3A_HEADLINE,
        body=DEFAULT_FISCAL_MARGIN_3A_BODY,
        chf_range_low=1500,
        chf_range_high=2500,
        chf_range_period="year",
        soft_account_hint=DEFAULT_SOFT_ACCOUNT_HINT,
    )
