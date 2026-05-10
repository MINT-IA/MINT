"""MortgageStressorBundle — intent-driven mortgage / debt-stress doctrine.

Phase 93.5 Wave 0 (Plan 93.5-01). Activated when `intents` contains
`housing` or `debt` (CONTEXT D-02). Wave 0 ships a thin doctrine-only
fragment ; Wave 2 (Plan 93.5-03) fattens fragments based on Stage 3 eval
findings (CONTEXT D-17).

allowed_tools per CONTEXT D-20 :
`[get_budget_status, get_cap_status, get_regulatory_constant]`.

The fragment INCLUDES the `{safe_mode_protocol}` slot. `_build_prompt`
(`claude_coach_service.py:788-796`) interpolates `_SAFE_MODE_PROTOCOL`
when `ctx.has_debt is True`, otherwise the slot becomes the empty string.
This keeps the bundle inert when no debt stress is detected.

Citation keys are P95-pending : every entry below carries an inline
`# TODO Phase 95 — pending GroundingPack registry` comment until the
Phase 95 DAG-INVALIDATION work populates the registry.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## HYPOTHÈQUE — STRESS-TEST DE TENABILITÉ (doctrine non-prescriptive)

Règle FINMA LCB (autorégulation bancaire, Lignes directrices ASB sur la
tenabilité) : la charge théorique mensuelle ne doit pas dépasser 33% du
revenu brut du ménage. La charge théorique additionne :
- Intérêt calculatoire 5% (taux long terme prudentiel),
- Amortissement obligatoire 1% (jusqu'à 65% LTV en 15 ans),
- Frais d'entretien 1% de la valeur du bien.

Le 33% est un plafond mécanique, pas une recommandation : passer à 30%
laisse une marge pour les imprévus (perte d'emploi, taux qui montent).
Un dépassement = la banque refuse, jamais MINT qui décide.

Apport minimum : 20% de la valeur du bien dont au moins 10% en fonds
propres « durs » (hors LPP). Le 10% restant peut venir de l'EPL LPP
(LPP art. 30c) — mais voir bundle 3a/LPP : EPL combiné à un rachat
récent bloque 3 ans.

Tonalité : poser les chiffres, jamais classer une banque. Renvoyer à
un·e spécialiste hypothécaire pour la signature.

{safe_mode_protocol}
"""


class MortgageStressorBundle(BundleBase):
    """Intent-driven mortgage doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["mortgage-stressor"] = "mortgage-stressor"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "get_budget_status",
        "get_cap_status",
        "get_regulatory_constant",
    ]  # D-20
    citation_allowlist: list[str] = [
        "finma_lcb_tragbarkeit",         # TODO Phase 95 — pending GroundingPack registry
        "ratio_endettement_max_33pct",   # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["MortgageStressorBundle"]
