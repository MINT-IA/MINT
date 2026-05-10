"""Pillar3aOptimizerBundle — intent-driven 3a doctrine fragment.

Phase 93.5 Wave 2 (Plan 93.5-03 Task 5). Activated when `intents` contains
`retirement` or `taxes` (CONTEXT D-02). Wave 2 fattens the Wave 0 stub
(760 chars, hardcoded `7'258 CHF` / `36'288 CHF`) to a full FR doctrine
fragment ≥800 chars covering OPP3 art. 7 (plafonds salarié vs
indépendant), LIFD art. 33 (déduction du revenu imposable), LIFD art. 38
(retrait capital ÷ 5), LPP art. 79b al. 3 (EPL bloqué 3 ans après
rachat), stratégies multi-comptes 3a et rachat-vs-versement.

allowed_tools per CONTEXT D-20 (C1 lock — UNCHANGED at fattening) :
`[get_retirement_projection, get_cross_pillar_analysis]`.

CLAUDE.md TOP rule #1 + Plan 03 Task 5 H8 — the LSFin adjective forbidden
to MINT (« le mieux possible » in user-facing voice) MUST NOT appear in
the prompt_fragment (the class NAME can contain `optimizer` — that's
metadata, not narrator instruction). Prefer « adapté », « pertinent »,
« envisageable ».

CLAUDE.md §1 — fragment MUST NOT hardcoder les plafonds 3a annuels. Les
valeurs 2026 sont des `{{cite:<key>}}` placeholders résolus à runtime
par `get_regulatory_constant`.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## DOCTRINE PILIER 3A — LEVIER FISCAL (non-prescriptive)

Tu poses les règles, tu n'évalues JAMAIS un produit. Tu invoques
`get_retirement_projection` pour la projection retraite et
`get_cross_pillar_analysis` pour le 3a-gap et le potentiel de rachat
LPP. Pour les chiffres exacts par année fiscale, tu invoques
`get_regulatory_constant`.

**Plafond annuel (OPP3 art. 7)** :
- Salarié·e affilié·e LPP : plafond fixe annuel (voir
  {{cite:r3a_plafond_salarie_2026}}).
- Indépendant·e sans LPP : 20% du revenu net, dans la limite d'un
  plafond annuel (voir {{cite:r3a_plafond_independant_2026}}).
Tu ne mémorises PAS le chiffre — tu lis la constante régulatoire.

**Levier fiscal (LIFD art. 33 let. e)** : versement déductible du
revenu imposable l'année du paiement (voir {{cite:lifd_art_33_deduction}}).
Effet d'épargne dépend de la tranche marginale du contribuable et du
canton — tu n'estimes JAMAIS le gain sans `get_cross_pillar_analysis`.

**Retrait du capital (LIFD art. 38)** : taxé séparément à barème réduit
(souvent ÷ 5 dans plusieurs cantons, voir
{{cite:lifd_art_38_capital_taux}}).

**Stratégie multi-comptes** : ouvrir 3 à 5 comptes 3a permet de retirer
en années fiscales différentes. Comme la taxe LIFD art. 38 est
progressive, étaler le retrait sur ≥ 2 années réduit la progressivité
globale — sans changer le total versé. C'est de la doctrine d'usage,
pas un classement de banque.

**Rachat LPP vs versement 3a** : le rachat LPP volontaire est aussi
déductible (LIFD art. 33 let. d) MAIS plafonné par la lacune actuelle-
théorique certifiée par la caisse. ATTENTION — après rachat, le
retrait EPL (logement) est BLOQUÉ pendant 3 ans (LPP art. 79b al. 3).
Donc : ne pas conseiller un rachat si projet immobilier < 3 ans.

**Tonalité narrateur** : le 3a est un LEVIER FISCAL, pas un produit
de retraite à vendre. Vocabulaire — « adapté à ta situation »,
« pertinent », « envisageable ». Pour rachat étalé > 50k ou EPL
combiné, passage de main vers un·e spécialiste (irréversible).
"""


class Pillar3aOptimizerBundle(BundleBase):
    """Intent-driven 3a doctrine bundle (CONTEXT D-02, D-10, D-20).

    Note : the class name contains `Optimizer` and the bundle name
    contains `optimizer` — that's metadata, not narrator output. The
    prompt_fragment itself avoids the LSFin banned adjective per
    CLAUDE.md TOP rule #1.
    """

    name: Literal["pillar3a-optimizer"] = "pillar3a-optimizer"
    prompt_fragment: str = _PROMPT_FRAGMENT
    # C1 lock per CONTEXT D-20.
    allowed_tools: list[str] = [
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    ]
    citation_allowlist: list[str] = [
        "r3a_plafond_salarie_2026",       # TODO Phase 95 — pending GroundingPack registry
        "r3a_plafond_independant_2026",   # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_33_deduction",          # TODO Phase 95 — pending GroundingPack registry
        "lifd_art_38_capital_taux",       # TODO Phase 95 — pending GroundingPack registry
    ]


__all__ = ["Pillar3aOptimizerBundle"]
