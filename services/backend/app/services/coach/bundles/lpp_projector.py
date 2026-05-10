"""LppProjectorBundle — intent-driven LPP doctrine fragment.

Phase 93.5 Wave 0 (Plan 93.5-01). Activated when `intents` contains
`retirement` or `career` (CONTEXT D-02). Wave 0 ships a thin doctrine-only
fragment ; Wave 2 (Plan 93.5-03) fattens fragments based on Stage 3 eval
findings (CONTEXT D-17).

allowed_tools per CONTEXT D-20 : `[get_retirement_projection, get_cross_pillar_analysis]`.

Citation keys are P95-pending : every entry below carries an inline
`# TODO Phase 95 — pending GroundingPack registry` comment until the
Phase 95 DAG-INVALIDATION work populates the registry.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## LPP — PROJECTION RENTE / CAPITAL (doctrine non-prescriptive)

Taux de conversion minimum (part obligatoire) : 6.8% (LPP art. 14 al. 2).
Le taux surobligatoire est librement fixé par la caisse — vérifier sur le
certificat de prévoyance, jamais présumer.

Déduction de coordination : 26'460 CHF (OPP2 art. 1, valeur 2026).
La part du salaire au-dessus de la déduction génère les bonifications LPP.

Rente vs capital : la rente est un revenu imposable annuel (LIFD art. 22) ;
le capital est taxé une seule fois au retrait, à barème séparé (LIFD art. 38).
La comparaison dépend de l'horizon, de l'archétype et du canton — chiffrer
les deux scénarios, jamais classer.

Libre-passage : 6 mois pour transférer à la nouvelle caisse (LFLP art. 4).
Au-delà, l'avoir part à l'Institution supplétive — récupérable mais
fragmenté.

Tonalité : conditionnel uniquement. Renvoyer à un·e spécialiste pour la
décision rente-vs-capital (irréversible, doctrine cardinale §3).
"""


class LppProjectorBundle(BundleBase):
    """Intent-driven LPP doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["lpp-projector"] = "lpp-projector"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    ]  # D-20
    citation_allowlist: list[str] = [
        "lpp_taux_conversion_2026",         # TODO Phase 95 — pending GroundingPack registry
        "lpp_deduction_coordination_2026",  # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["LppProjectorBundle"]
