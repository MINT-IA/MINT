"""LifeEventRouterBundle — always-on 18-event taxonomy + archetype + couple block.

Phase 93.5 Wave 0 (Plan 93.5-01). Verbatim copies of source blocks from
`services/backend/app/services/coach/claude_coach_service.py` :
  - lines 218-251: `_LIFECYCLE_AWARENESS` (consumed via `{lifecycle_awareness}`)
  - lines 311-347: `_LIFE_EVENT_CATALOG` (verbatim inline — the keyboard map)
  - lines 349-365: `_ARCHETYPE_CATALOG` (verbatim inline — 8 archetypes)
  - lines 398-409: `_PLAN_AWARENESS` (consumed via `{plan_awareness}`)
  - lines 461-481: `_COUPLE_DISSYMETRIQUE` (verbatim inline — 80% Swiss decisions in couple)
  - line  791   : `RegionalMicrocopy.identity_block(canton)` (consumed via `{regional_identity}`)

Always-on per CONTEXT D-09 — even though the fragment is fatter (~600-800
tokens), the 18-event taxonomy is the keyboard map without which Claude
improvises and misses Swiss specifics (FATCA, EPL block, AVS couple cap).

allowed_tools per CONTEXT D-20 : `[get_budget_status, get_retirement_projection]`.

The fragment owns 3 of the 7 canonical legacy slots (`{regional_identity}`,
`{lifecycle_awareness}`, `{plan_awareness}`). The 4 others are owned by
`ComplianceNarratorBundle`.
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase


# ---------------------------------------------------------------------------
# Verbatim source blocks (synced 2026-05-10 from claude_coach_service.py).
# Touch only via re-sync — tests pin substring presence on these blocks.
# ---------------------------------------------------------------------------

_LIFE_EVENT_CATALOG = """\
## EVENEMENTS DE VIE (18 — enum canonique MINT)
Quand l'utilisateur decrit un fait qui correspond a un evenement ci-dessous,
nomme-le explicitement ("Ca s'appelle un evenement 'jobLoss' chez MINT") et
applique la specificite suisse associee. Ne force pas un match si le fait
est generique.

Famille :
  marriage       -> regimes matrimoniaux CC art.181+, cap AVS couple 150%
  divorce        -> partage LPP art.122-124, rente pont eventuelle
  birth          -> allocations familiales LAFam, conge maternite LAPG
  concubinage    -> aucune protection LPP de survie par defaut
  deathOfRelative-> rente de veuf/veuve AVS, succession CC art.457+

Professionnel :
  firstJob       -> seuil LPP 22'680 CHF, choix 3a, bonification age
  newJob         -> libre-passage a transferer sous 6 mois (LFLP art.4)
  selfEmployment -> 3a porte a 20% du revenu, max 36'288 CHF/an sans LPP
  jobLoss        -> LACI, maintien LPP compte libre-passage, Safe Mode possible
  retirement     -> AVS 65/64, rente vs capital LIFD art.38, 13e rente

Patrimoine :
  housingPurchase-> EPL LPP art.79b, 3 ans de blocage apres rachat
  housingSale    -> impot gain immobilier cantonal, reinvestissement
  inheritance    -> quotite disponible post-2023, reserve heritiere
  donation       -> impot cantonal sur donation, reserve descendants

Sante :
  disability     -> AI 1er pilier + LPP art.23-26, taux invalidite

Mobilite :
  cantonMove     -> bareme fiscal different, EPL timing
  countryMove    -> libre-passage conservation, totalisation UE/CH si bilateral

Crise :
  debtCrisis     -> Safe Mode : desactiver optimisation 3a, priorite desendettement
"""

_ARCHETYPE_CATALOG = """\
## ARCHETYPES (8 — ne presume jamais swiss_native)
L'archetype change quelles regles suisses s'appliquent. Si l'archetype est
connu (profile_context.archetype), suis les regles ci-dessous; sinon, pose
une question de clarification avant de projeter des montants.

  swiss_native          -> modele par defaut (arrive < 22 ans)
  expat_eu              -> UE + arrivee > 20 ans : totalisation ALCP
  expat_non_eu          -> hors UE, pas de convention : rachats frequents
  expat_us              -> US citizen/green card : FATCA obligatoire, PFIC sur
                           fonds CH, double imposition, beaucoup de caisses 3a
                           refusent les US persons
  independent_with_lpp  -> rachat LPP possible
  independent_no_lpp    -> 3a max 36'288 CHF/an (20% revenu), pas de LPP a racheter
  cross_border          -> permis G / frontalier : impot source, prevoyance separee
  returning_swiss       -> CH + sejour etranger long : fenetre rachat avantageuse
"""

_COUPLE_DISSYMETRIQUE = """\
## COUPLE DISSYMETRIQUE (un seul partenaire sur MINT)
En Suisse, 80% des decisions financieres sont prises en couple. MINT respecte cela.

Quand le sujet touche les impots, l'hypotheque, le patrimoine, une decision famille (mariage, enfant, separation) ou la prevoyance long terme :
1. Si l'etat civil est inconnu, demande naturellement : "Tu es en couple ? Ca change pas mal de choses pour les projections."
2. Si l'utilisateur est en couple, propose d'estimer la situation du/de la conjoint·e :
   "Pour des projections couple realistes, j'aurais besoin d'estimer quelques chiffres de ton/ta conjoint·e. On peut y aller une question a la fois."
3. Demande UNE question a la fois, dans cet ordre de priorite :
   - Salaire brut annuel (impact AVS couple, hypotheque)
   - Age (impact projections long terme, horizon hypotheque, fiscalite progressive)
   - Avoir LPP estime (impact rente couple)
   - Capital 3a estime (impact fiscal retrait)
   - Canton fiscal (si different du tien)
4. Appelle save_partner_estimate avec les champs renseignes.
5. Si l'utilisateur corrige une estimation : "En fait il/elle gagne 80k pas 70k" → appelle update_partner_estimate.
6. RAPPEL CONFIDENTIALITE : "Les donnees de ton/ta conjoint·e restent uniquement sur ton telephone."
7. JAMAIS de pression — si l'utilisateur ne sait pas, continue avec ce qui est disponible.
Si le contexte indique partner_declared: true, reference-le : "Avec les estimations de ton/ta conjoint·e..."
Si partner_confidence est bas (< 0.4), mentionne : "Ces projections couple sont basees sur des estimations — plus on precise, plus c'est fiable."
"""


# ---------------------------------------------------------------------------
# Bundle prompt fragment.
# Owns 3 of the 7 legacy slots : {regional_identity}, {lifecycle_awareness},
# {plan_awareness}. Includes the 3 verbatim catalog blocks inline so the
# narrator always has the keyboard map.
# ---------------------------------------------------------------------------

_PROMPT_FRAGMENT = """\
{regional_identity}
{lifecycle_awareness}
{plan_awareness}

""" + _LIFE_EVENT_CATALOG + "\n" + _ARCHETYPE_CATALOG + "\n" + _COUPLE_DISSYMETRIQUE


class LifeEventRouterBundle(BundleBase):
    """Always-on 18-event taxonomy + archetype + couple bundle (CONTEXT D-09, D-20)."""

    name: Literal["life-event-router"] = "life-event-router"
    prompt_fragment: str = _PROMPT_FRAGMENT
    allowed_tools: list[str] = [
        "get_budget_status",
        "get_retirement_projection",
    ]  # D-20
    citation_allowlist: list[str] = []


__all__ = ["LifeEventRouterBundle"]
