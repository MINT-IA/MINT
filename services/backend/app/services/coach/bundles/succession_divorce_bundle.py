"""SuccessionDivorceBundle — intent-driven succession + divorce citation grammar.

Phase mint-calc-engine-v1 Plan 08 (W2 bundles, D-CE-03 Override #2).
Activated when `intents` contains `family` (CONTEXT D-CE-03).

Matrix domains 6 (famille / succession) and 7 (divorce) ALREADY ship the
calculators (`divorce_simulator.py`, `succession_simulator.py`,
`concubinage_succession.py`). What was missing was the narrator prompt
scaffolding — this bundle adds the citation grammar so the coach can
surface CC art. 122-124 (partage LPP), CC art. 462 (droit du conjoint
survivant), CC art. 470-471 (réserves héréditaires) and LAVS art. 29sexies
(splitting AVS) when the user describes a divorce, séparation, décès or
succession scenario.

allowed_tools per RESEARCH §Q-F line 922 :
`[divorce_simulator, succession_simulator, concubinage_succession]`.
These are placeholder tool names — Plan 09 W2-03 reviews them against
the Plan 05 REGISTRY canonical naming, and Plan 10 W2-04 wires the
adapter.

Pattern : mirrors `tax_explainer.py` / `lpp_projector.py` (Literal field
defaults locked at class level) for contract-consistency with the
7 Wave 0/2 bundles already shipped.

Legal article references verified against `docs/AGENTS/swiss-brain.md`
line 121-122 (LAVS art. 29sexies splitting confirmed) and standard
Swiss legal-reference conventions (CC art. 122-124 = LPP partage at
divorce ; CC art. 462 = conjoint survivant ordre de successibles ;
CC art. 470-471 = réserves héréditaires).
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


# llm-doctrine-fragment-banned-list
_PROMPT_FRAGMENT = """\
## DOCTRINE SUCCESSION ET DIVORCE — REGISTRE ÉDUCATIF + FACTUEL

Si l'utilisatrice ou l'utilisateur évoque un divorce, une séparation, un
décès ou une succession, garde le registre éducatif. Pose la règle, cite
l'article, jamais d'avis. Les décisions de cette catégorie sont
existentielles ou irréversibles — passage de main vers un·e
notaire ou avocat·e spécialisé·e dès qu'on touche au chiffrage final.

**Partage LPP au divorce (CC art. 122-124)** : les avoirs de prévoyance
accumulés pendant le mariage sont partagés par moitié. Le partage est
calculé sur la durée du mariage (CC art. 122) ; les ajustements
spécifiques (rente déjà en cours, exception pour cas de rigueur)
relèvent de CC art. 123-124. Le calcul exact passe par la caisse de
prévoyance et un·e juge.

**Splitting AVS (LAVS art. 29sexies)** : pendant la durée du mariage, les
revenus AVS du couple sont splittés à moitié entre les deux conjoint·e·s
pour le calcul de la rente individuelle ultérieure. Le splitting
intervient lors du divorce ou au moment où les deux conjoint·e·s
atteignent l'âge de référence AVS.

**Droit du conjoint survivant (CC art. 462)** : en l'absence de
disposition pour cause de mort, le conjoint survivant hérite à parts
définies selon le régime matrimonial (participation aux acquêts par
défaut, CC art. 196 et suivants) et l'ordre des autres successibles
légaux (descendants, parents, fratrie). Concubinage = AUCUNE protection
successorale par défaut — il faut un testament ou un pacte successoral.

**Réserves héréditaires (CC art. 470-471)** : la liberté de disposer par
testament est encadrée par les réserves héréditaires en faveur des
descendants et du conjoint survivant. La réserve descendante = 1/2 de
la part légale depuis la réforme du droit des successions entrée en
vigueur le 1er janvier 2023 (avant : 3/4). La quotité disponible est
le solde — utilisable au profit de tiers ou pour augmenter la part
d'un héritier réservataire.

**Concubinage** : le partenariat non enregistré ne crée AUCUN droit
successoral légal et AUCUNE rente de survivant LPP par défaut. Vérifier
le règlement de la caisse de prévoyance pour les bénéficiaires désignés
+ rédiger un testament + envisager une assurance-vie au profit du
partenaire.

**Outils disponibles** : `divorce_simulator`, `succession_simulator`,
`concubinage_succession`.

**Tonalité narrateur** : éducation + factuel. « Voici la règle, voici
l'article, voici qui appeler pour le chiffrage. » Reconnaissance
émotionnelle d'abord si l'utilisateur évoque un décès ou un divorce en
cours — la doctrine d'irréversibilité de la ComplianceNarratorBundle
s'applique.
"""


class SuccessionDivorceBundle(BundleBase):
    """Intent-driven succession + divorce bundle (D-CE-03 Override #2).

    Wired into ``_INTENT_BUNDLES`` for the `family` intent (CONTEXT
    D-CE-03 + Plan 08 Task 3). Listed second in ``_DROP_PRIORITY`` (after
    IndependentTaxBundle) so it drops second under token-budget pressure.
    """

    name: Literal["succession-divorce"] = "succession-divorce"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "divorce_simulator",
        "succession_simulator",
        "concubinage_succession",
    ]
    citation_allowlist: list[str] = [
        "tool_divorce_simulator",
        "tool_succession_simulator",
        "tool_concubinage_succession",
    ]


__all__ = ["SuccessionDivorceBundle"]
