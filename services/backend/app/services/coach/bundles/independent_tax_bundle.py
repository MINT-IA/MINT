"""IndependentTaxBundle — intent-driven indépendant / Sàrl scaffold.

Phase mint-calc-engine-v1 Plan 08 (W2 bundles, D-CE-03 Override #2).
Activated when `intents` contains `taxes` or `career` (CONTEXT D-CE-03).

This bundle covers matrix domain 8 (Sàrl-vs-RI + dividende-vs-salaire).
The underlying calculators are NOT yet implemented (3 truly absent items
per CONTEXT §domain) ; the bundle scaffolds the narrator's coaching
register for indépendant users so the conversation can still surface the
relevant Swiss legal frame.

allowed_tools per RESEARCH §Q-F lines 900-905 :
`[avs_cotisations_independants, pillar_3a_indep, lpp_volontaire,
ijm_service]`. These are placeholder tool names — Plan 09 W2-03 will
review/rename against the Plan 05 REGISTRY canonical naming, and Plan
10 W2-04 will wire the adapter. For Plan 08, the bundle scaffolds the
narrator register only.

Pattern : mirrors `tax_explainer.py` / `lpp_projector.py` /
`mortgage_stressor.py` — Pydantic v2 frozen BundleBase subclass with
`Literal` field defaults locked at class level. Pattern adoption is
deliberate (deviation from PLAN's verbatim `def __init__` pattern) for
contract-consistency with the 7 Wave 0/2 bundles already shipped at
`services/backend/app/services/coach/bundles/`.

CLAUDE.md §1 — fragment uses registre éducatif, never LSFin-banned
verbs (see ComplianceNarratorBundle for the verbatim banned list under
the ``llm-doctrine-fragment-banned-list`` marker). Tool names are
referenced as ``code`` for the narrator's tool-routing reflex without
estimating amounts.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


_PROMPT_FRAGMENT = """\
## DOCTRINE INDÉPENDANT / SÀRL — REGISTRE ÉDUCATIF

Si l'utilisatrice ou l'utilisateur évoque son statut indépendant, sa
Sàrl, ou un arbitrage dividende-vs-salaire, garde le registre éducatif.
Tu poses la règle, tu ne classes JAMAIS un statut comme « préférable » ;
la décision dépend du revenu, de la prévoyance souhaitée et du canton.

**Cotisations sociales (LAVS art. 8)** : la personne indépendante cotise
à l'AVS/AI/APG sur le bénéfice net d'exploitation, à un taux progressif
défini par la LAVS. Le détail des paliers se lit dans la constante
régulatoire annuelle (jamais une estimation à la volée).

**Prévoyance professionnelle facultative (LPP art. 4)** : l'indépendant·e
peut s'affilier à titre facultatif à une institution LPP (caisse de sa
profession, fondation collective ou institution supplétive). Cette
affiliation ouvre l'accès aux mêmes rachats LPP et aux mêmes leviers
fiscaux qu'un·e salarié·e.

**Déductions fiscales (LIFD art. 33 al. 1 let. d et e)** : sans LPP, le
plafond 3a passe à 20% du revenu net (let. e). Avec LPP volontaire, les
versements 3a + rachat LPP restent intégralement déductibles du revenu
imposable (let. d et let. e), dans les limites de l'OPP3 et de la
lacune certifiée par la caisse.

**Sàrl vs raison individuelle** : la Sàrl sépare le patrimoine privé du
patrimoine professionnel et permet l'arbitrage dividende-vs-salaire ;
elle déclenche en contrepartie des obligations (capital social, comptes
annuels, double imposition économique). La raison individuelle est plus
légère mais expose l'ensemble du patrimoine privé. Le passage de l'un à
l'autre est un événement irréversible — passage de main vers un·e
fiscaliste avant signature.

**Outils disponibles (Plan 09 wiring pending)** : `avs_cotisations_independants`,
`pillar_3a_indep`, `lpp_volontaire`, `ijm_service` (indemnités
journalières maladie).

**Tonalité narrateur** : éducation, jamais prescription. « Voici ce que
la règle dit pour ton statut », jamais d'impératif sur le choix du
véhicule juridique sans passage de main spécialiste.
"""


class IndependentTaxBundle(BundleBase):
    """Intent-driven indépendant / Sàrl bundle (D-CE-03 Override #2).

    Wired into ``_INTENT_BUNDLES`` for `taxes` and `career` intents
    (CONTEXT D-CE-03 + Plan 08 Task 3). Listed first in
    ``_DROP_PRIORITY`` so it drops first under token-budget pressure ;
    the always-on `compliance-narrator` + `life-event-router` retain
    their LSFin doctrine and 18-event keyboard map.
    """

    name: Literal["independent-tax"] = "independent-tax"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "avs_cotisations_independants",
        "pillar_3a_indep",
        "lpp_volontaire",
        "ijm_service",
    ]
    citation_allowlist: list[str] = [
        "tool_avs_cotisations_independants",
        "tool_pillar_3a_indep",
        "tool_lpp_volontaire",
        "tool_ijm_service",
    ]


__all__ = ["IndependentTaxBundle"]
