"""LppProjectorBundle — intent-driven LPP doctrine fragment.

Phase 93.5 Wave 2 (Plan 93.5-03 Task 4). Activated when `intents` contains
`retirement` or `career` (CONTEXT D-02). Wave 2 fattens the Wave 0 stub
to a full FR doctrine fragment ≥800 chars covering LPP art. 14 al. 2
(taux conv. 6.8% obligatoire), art. 19-21 (rente survivant 60%), art.
79b al. 3 (rachat + EPL bloqué 3 ans), OPP2 art. 1 (déduction de
coordination), LAVS art. 21 (âge de référence 65 H/F transition 2024).

allowed_tools per CONTEXT D-20 (C1 lock — UNCHANGED at fattening) :
`[get_retirement_projection, get_cross_pillar_analysis]`.

CLAUDE.md §1 — fragment MUST NOT extrapoler la rente. Le taux 6.8% est
DOCTRINE LÉGALE (LPP art. 14 al. 2) ; la déduction de coordination
annuelle est un `{{cite:<key>}}` placeholder (valeur 2026 résolue par
`get_regulatory_constant`).
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## DOCTRINE LPP — PROJECTION RENTE / CAPITAL (non-prescriptive)

Tu projettes les ordres de grandeur, tu n'extrapoles JAMAIS la rente
sans tool. Tu invoques `get_retirement_projection` pour les valeurs
projetées et `get_cross_pillar_analysis` pour la coordination 1er / 2e
/ 3e pilier.

**Taux de conversion (LPP art. 14 al. 2)** : minimum légal 6.8% sur la
part obligatoire. Le taux surobligatoire est librement fixé par chaque
caisse — il faut le LIRE sur le certificat de prévoyance, jamais le
présumer. Voir {{cite:lpp_taux_conv_obligatoire_2026}}.

**Déduction de coordination (OPP2 art. 1)** : montant annuel déduit du
salaire AVS pour calculer le salaire LPP coordonné (voir
{{cite:opp2_coordination_2026}}). La part au-dessus de la déduction
génère les bonifications de vieillesse.

**Rente vs capital (irréversible)** : la rente est un revenu imposable
annuel (LIFD art. 22) ; le capital est taxé une fois au retrait à
barème séparé (LIFD art. 38, taux ÷ 5 dans plusieurs cantons). Le
choix dépend de l'horizon, de l'archétype et du canton — tu chiffres
les deux scénarios, tu ne classes JAMAIS. Décision irréversible →
passage de main vers un·e spécialiste.

**Survivants (LPP art. 19-21)** : rente conjoint survivant ≈ 60% de la
rente vieillesse projetée, rente orphelin ≈ 20%. Voir
{{cite:lpp_rente_survivant_pct}} pour les valeurs exactes par caisse.

**Rachat LPP volontaire (LPP art. 79b)** : déductible du revenu
imposable (LIFD art. 33 let. d), plafonné par la lacune actuelle vs
théorique certifiée par la caisse. ATTENTION — après rachat, l'EPL
(retrait anticipé pour logement) est BLOQUÉ pendant 3 ans (LPP art. 79b
al. 3) ; ne pas conseiller un rachat si projet immobilier < 3 ans.

**Âge de référence AVS / LPP (LAVS art. 21)** : 65 ans H/F (transition
AVS 21 vers 65 femmes). Voir {{cite:lavs_age_reference_2026}}.
Anticipation possible avec réduction actuarielle ; ajournement avec
bonus.
"""


class LppProjectorBundle(BundleBase):
    """Intent-driven LPP doctrine bundle (CONTEXT D-02, D-10, D-20)."""

    name: Literal["lpp-projector"] = "lpp-projector"
    prompt_fragment: str = _PROMPT_FRAGMENT
    # C1 lock per CONTEXT D-20.
    allowed_tools: list[str] = [
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    ]
    citation_allowlist: list[str] = [
        "lpp_taux_conv_obligatoire_2026",  # TODO Phase 95 — pending GroundingPack registry
        "opp2_coordination_2026",          # TODO Phase 95 — pending GroundingPack registry
        "lpp_rente_survivant_pct",         # TODO Phase 95 — pending GroundingPack registry
        "lavs_age_reference_2026",         # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["LppProjectorBundle"]
