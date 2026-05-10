"""Pillar3aOptimizerBundle — intent-driven 3a doctrine fragment.

Phase 93.5 Wave 0 (Plan 93.5-01). Activated when `intents` contains
`retirement` or `taxes` (CONTEXT D-02). Wave 0 ships a thin doctrine-only
fragment ; Wave 2 (Plan 93.5-03) fattens fragments based on Stage 3 eval
findings (CONTEXT D-17).

allowed_tools per CONTEXT D-20 : `[get_retirement_projection, get_cross_pillar_analysis]`.

Citation keys are P95-pending : every entry below carries an inline
`# TODO Phase 95 — pending GroundingPack registry` comment until the
Phase 95 DAG-INVALIDATION work populates `grounding_pack.GROUNDING_PACK_KEYS_REGISTRY`.
The `test_bundle_citation_allowlist_subset_of_grounding_pack` test stays
xfail until the registry is non-empty.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## PILIER 3A — OPTIMISATION (doctrine non-prescriptive)

Plafond annuel salarié avec LPP : 7'258 CHF (2026, OPP3 art. 7 al. 1 let. a).
Plafond indépendant sans LPP : 20% du revenu net, max 36'288 CHF
(OPP3 art. 7 al. 1 let. b).

Levier fiscal : versement déductible du revenu imposable (LIFD art. 33
al. 1 let. e). Retrait taxé séparément à barème réduit (LIFD art. 38),
divisé par 5 dans plusieurs cantons.

ATTENTION EPL : un rachat 3a couplé à un EPL (retrait anticipé pour
acquisition d'un logement) bloque l'EPL pendant 3 ans (LPP art. 79b
al. 3, applicable par renvoi à OPP3).

Tonalité : conditionnel uniquement. Chiffrer un cas, jamais classer un
produit. Renvoyer à un·e spécialiste pour les décisions irréversibles
(rachat étalé > 50k, EPL combiné).
"""


class Pillar3aOptimizerBundle(BundleBase):
    """Intent-driven 3a doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["pillar3a-optimizer"] = "pillar3a-optimizer"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    ]  # D-20
    citation_allowlist: list[str] = [
        "r3a_ceiling_2026",          # TODO Phase 95 — pending GroundingPack registry
        "r3a_ceiling_independent",   # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["Pillar3aOptimizerBundle"]
