"""TaxExplainerBundle — intent-driven Swiss tax doctrine fragment.

Phase 93.5 Wave 0 (Plan 93.5-01). Activated when `intents` contains
`taxes` or `housing` (CONTEXT D-02). Wave 0 ships a thin doctrine-only
fragment ; Wave 2 (Plan 93.5-03) fattens fragments based on Stage 3 eval
findings (CONTEXT D-17).

allowed_tools per CONTEXT D-20 : `[get_regulatory_constant, get_cross_pillar_analysis]`.

Citation keys are P95-pending : every entry below carries an inline
`# TODO Phase 95 — pending GroundingPack registry` comment until the
Phase 95 DAG-INVALIDATION work populates the registry.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## FISCALITÉ SUISSE — EXPLICATION (doctrine non-prescriptive)

Revenu imposable : LIFD art. 16 (revenus en argent ou nature). Les rentes
1er + 2e pilier y entrent intégralement (LIFD art. 22).

Déductions cardinales (LIFD art. 33) :
- Versement 3a (let. e) : déductible jusqu'au plafond OPP3 art. 7.
- Rachat LPP (let. d) : entièrement déductible, plafonné par la lacune.
- Cotisations AVS/AI/APG/AC : intégralement déductibles.

Retrait du capital de prévoyance (LIFD art. 38) : taxé séparément, à un
barème réduit (souvent ÷ 5). Le canton additionne sa propre échelle
cantonale (LHID art. 11 al. 3).

Harmonisation cantonale : LHID fixe le cadre (assiette, déductions
admissibles), chaque canton garde sa main sur les barèmes. Ne jamais
citer un taux cantonal sans préciser le canton et l'année.

Tonalité : éducation, jamais optimisation prescriptive. « Voici ce que
la règle dit pour ton archétype », pas « tu devrais ».
"""


class TaxExplainerBundle(BundleBase):
    """Intent-driven tax doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["tax-explainer"] = "tax-explainer"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "get_regulatory_constant",
        "get_cross_pillar_analysis",
    ]  # D-20
    citation_allowlist: list[str] = [
        "lifd_art_33_deductions",          # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_38_capital_prevoyance",  # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["TaxExplainerBundle"]
