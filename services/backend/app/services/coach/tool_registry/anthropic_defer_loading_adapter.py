"""Phase mint-calc-engine-v1 Plans 07 + 09 — AnthropicDeferLoadingAdapter (DEFAULT).

Wires Anthropic Tool Search Tool (beta ``tool-search-tool-2025-10-19``) :

- 5 chip-emitters stay always-on (sub-500 ms L1 latency budget per CONTEXT
  §Latency contract). Their descriptions are sourced from ``coach_tools.py``
  where they already live as ``COACH_TOOLS`` entries (Plan 09 rewrote them
  with FR keyword discipline + legal article refs).
- All 60+ calculator entries from ``app.calculators.REGISTRY`` (Plan 05 AST
  scaffold) carry ``defer_loading: True``. Anthropic's BM25 search-tool loads
  3-5 of them just-in-time per turn — cache-preserving (initial prompt is not
  invalidated). RESEARCH §Q-A confirms this design.
- 1 ``tool_search_tool_bm25_20251119`` declaration so Sonnet 4.5 has the
  server-side BM25 retrieval primitive available.

Plan 09 (W2-03 description rewrite, Concern A) ships the ``_TOOL_DESCRIPTIONS_FR``
map below : per-tool French descriptions with Swiss legal article refs (CC art.
122-124 divorce, LAVS art. 29sexies splitting, CC art. 462+467-469 succession,
LIFD art. 33 al. 1 let. d/e déductions, LPP art. 14 conversion, Directives ASB
(FINMA) hypothèque, LIFD art. 38 capital, LAA, LAMal, LAI…) so the Anthropic Tool
Search BM25 surfacing earns top-3 matches on French user queries (« si je
divorce demain », « racheter ma LPP », « frontalier vaudois FATCA »…).

The templated fallback ``_templated_description_for`` stays as a safety net
for any REGISTRY entry NOT in the ``_TOOL_DESCRIPTIONS_FR`` map.

NOT wired into the coach narrator yet — see Plan 10 (W2-04 ``CoachToolResponse``
V2 ``latency_tier`` envelope) for the consumer hook. This adapter is scaffolding.
"""
from __future__ import annotations

from typing import Any

from app.calculators import REGISTRY
from app.services.coach.tool_registry.adapter import (
    LatencyTier,
    ToolDefinition,
)


# 5 chip-emitters — always-on per D-CE-01 + W0 audit rows 46-50.
_ALWAYS_ON_TOOLS: frozenset[str] = frozenset(
    {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }
)


# Anthropic Tool Search Tool — server-side BM25 retrieval. MINT only declares
# it ; Anthropic injects the search-tool implementation on the model side.
# Reference : platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
_TOOL_SEARCH_DECLARATION: ToolDefinition = {
    "type": "tool_search_tool_bm25_20251119",
    "name": "tool_search_tool_bm25",
}


# The Anthropic beta header that activates ``defer_loading`` semantics.
# Stable since Oct 2025 (~7 months). RESEARCH §Q-A.
_BETA_HEADER = "tool-search-tool-2025-10-19"


# Chip-emitter description cache — read lazily from ``coach_tools.COACH_TOOLS``
# so the source of truth stays in one file.
def _load_chip_emitter_descriptions() -> dict[str, ToolDefinition]:
    """Return ``{name: ToolDefinition}`` for the 5 always-on chip-emitters.

    Sourced from ``app.services.coach.coach_tools.COACH_TOOLS`` where the
    descriptions already live (existing wire-up at ``coach_chat.py``).
    """
    # Local import to avoid a top-of-module circular : ``coach_tools`` does
    # not import this adapter, but the adapter is imported from
    # ``services.coach`` package init in future plans.
    from app.services.coach.coach_tools import COACH_TOOLS

    chip_defs: dict[str, ToolDefinition] = {}
    for entry in COACH_TOOLS:
        name = entry.get("name")
        if name in _ALWAYS_ON_TOOLS:
            chip_defs[name] = {
                "name": name,
                "description": entry["description"],
                "input_schema": entry.get(
                    "input_schema",
                    {"type": "object", "properties": {}, "required": []},
                ),
            }
    return chip_defs


# ─── Plan 09 W2-03 — Concern A FR description map ──────────────────────────
#
# Per-tool French descriptions with Swiss legal article refs + life-event
# keywords. Anthropic's BM25 Tool Search ranks against ``name`` + ``description``
# (RESEARCH §Q-A) — French keyword density here is what surfaces the right tool
# in top-3 for French user messages.
#
# Rubric (enforced by ``tools/checks/tool_description_rubric.py``) :
# - R1 FR verb : simule | calcule | compare | estime | projette | évalue | analyse
# - R2 FR accent : ≥1 accented vowel
# - R3 Legal/domain : art. <N> OR CHF/canton/3a/LPP/AVS/LIFD/LCC/rachat/rente/...
# - R4 Length ≥80 chars
#
# Sources for legal article refs : docs/AGENTS/swiss-brain.md §10 (LPP/LAVS/
# LIFD/LHID/OPP2/OPP3/LAMal/LAI/CO/CC). NEVER « optimal | garanti | meilleur |
# parfait | sans risque » (LSFin § 1 banned). NEVER « tu devrais | vous devriez »
# (paraphrase verb).
#
_TOOL_DESCRIPTIONS_FR: dict[str, str] = {
    # ── Housing / mortgage (Directives ASB (FINMA), OPP2 art. 5, Tragbarkeit) ──
    "affordability_service__AffordabilityService_calculate_affordability": (
        "Calcule la capacité d'achat immobilier selon les règles FINMA/ASB "
        "(Directives ASB (FINMA) plafond charges 33% revenu brut, taux théorique 5%, "
        "amortissement 1%/an, frais 1%/an) avec fonds propres minimum 20% "
        "(max 10% issu du 2e pilier OPP2 art. 5). Produit le prix d'achat "
        "plafond CHF et l'écart vs prix cible. Mots-clés : hypothèque, achat, "
        "appartement, maison, propriété, capacité, financement, fonds propres."
    ),
    "amortization_service__AmortizationService_compare": (
        "Compare l'amortissement direct vs indirect d'une hypothèque suisse "
        "(Directives ASB (FINMA)) sur la durée résiduelle, avec effet fiscal LIFD art. 33 "
        "des déductions 3a en cas d'amortissement indirect. Produit le coût "
        "net cumulé CHF + le rendement 3a versus économies d'intérêts. "
        "Mots-clés : amortissement, hypothèque, 3a, déduction, fiscal, prêt."
    ),
    "saron_vs_fixed_service__SaronVsFixedService_compare": (
        "Compare un taux SARON variable vs un taux fixe pour une hypothèque "
        "(Directives ASB (FINMA)) sur plusieurs scénarios de taux d'intérêt. Estime le "
        "coût cumulé CHF + la sensibilité au mouvement de courbe. "
        "Mots-clés : SARON, taux fixe, hypothèque, taux variable, financement."
    ),
    "epl_combined_service__EplCombinedService_calculate": (
        "Calcule l'encouragement à la propriété (EPL, OPP2 art. 5 min 20'000 "
        "CHF, blocage 3 ans art. 79b al. 3) combinant retrait 3a + 2e pilier "
        "pour un achat immobilier. Estime l'impôt LIFD art. 38 sur le retrait "
        "capital et l'effet sur la rente LPP future. Mots-clés : EPL, retrait, "
        "propriété, 2e pilier, 3a, achat, rachat, hypothèque."
    ),
    "epl_service__EPLService_simulate": (
        "Simule un retrait anticipé du 2e pilier pour achat immobilier (EPL, "
        "LPP art. 79b al. 3) selon le montant, l'âge et le canton. Estime "
        "l'impôt LIFD art. 38 sur le retrait capital et le délai de rachat "
        "post-EPL. Mots-clés : EPL, LPP, retrait, propriété, achat, hypothèque."
    ),
    "imputed_rental_service__ImputedRentalService_calculate": (
        "Calcule la valeur locative d'un bien immobilier en propre (LHID art. "
        "7 al. 1, taux cantonal sur valeur officielle ou de rendement) et "
        "l'effet sur le revenu imposable. Mots-clés : valeur locative, propriété, "
        "impôt, canton, revenu imposable, immobilier."
    ),
    "housing_sale_service__HousingSaleService_calculate": (
        "Calcule l'impôt sur le gain immobilier (LHID art. 12, cantonal) lors "
        "de la vente d'un bien suisse, selon durée de détention et canton. "
        "Estime le gain net CHF et la part remboursable au 2e pilier post-EPL. "
        "Mots-clés : vente immobilier, gain, propriété, canton, impôt, EPL."
    ),
    "location_vs_propriete__compare_location_vs_propriete": (
        "Compare la location vs l'achat immobilier sur 10-30 ans, intégrant "
        "valeur locative (LHID art. 7), intérêts hypothécaires, amortissement, "
        "appréciation du bien et coût d'opportunité du capital. Produit la "
        "différence de patrimoine net CHF par scénario. Mots-clés : location, "
        "propriété, achat, hypothèque, immobilier, patrimoine."
    ),
    # ── Retirement / LPP / 3a / AVS ─────────────────────────────────────────
    "avs_estimation_service__AvsEstimationService_estimate": (
        "Estime la rente AVS à la retraite (LAVS art. 21 âge référence, art. "
        "29bis-29quater calcul, art. 35 cap couple 150%) selon années de "
        "cotisation, salaire moyen et lacunes. Produit la rente CHF/mois + "
        "le gap si lacunes. Mots-clés : AVS, rente, retraite, cotisation, "
        "1er pilier, splitting, prévoyance."
    ),
    "retirement_projection_service__RetirementProjectionService_compute": (
        "Projette le revenu total à la retraite cumulant les trois piliers "
        "(AVS LAVS art. 21 + LPP art. 14 conversion 6.8% + 3a LIFD art. 33 "
        "al. 1 let. e) selon l'âge, le canton et l'archétype. Produit la "
        "rente CHF/mois projetée + le taux de remplacement vs salaire actuel. "
        "Mots-clés : retraite, rente, pension, AVS, LPP, 3a, prévoyance."
    ),
    "lpp_conversion_service__LppConversionService_compare": (
        "Compare le taux de conversion LPP (art. 14, obligatoire 6.8% vs "
        "surobligatoire libre selon caisse) à la conversion en rente. Estime "
        "la rente CHF/mois selon avoir total et taux applicable. "
        "Mots-clés : LPP, conversion, rente, retraite, 2e pilier, taux."
    ),
    "rachat_echelonne_service__RachatEchelonneService_simulate": (
        "Simule un rachat LPP échelonné sur N années (LIFD art. 33 al. 1 let. "
        "d, déduction du revenu imposable l'année du versement). Compare le "
        "coût net selon canton et le ROI par tranche. Mots-clés : rachat, LPP, "
        "2e pilier, déduction, fiscal, échelonnement, LIFD."
    ),
    "rachat_vs_marche__compare_rachat_vs_marche": (
        "Compare un rachat LPP (LIFD art. 33 al. 1 let. d) versus un placement "
        "équivalent sur les marchés financiers sur l'horizon retraite. Estime "
        "le delta de patrimoine net CHF en intégrant économie fiscale et "
        "rendement. Mots-clés : rachat, LPP, marché, prévoyance, fiscal, ROI."
    ),
    "rente_vs_capital__compare_rente_vs_capital": (
        "Compare le retrait du 2e pilier en rente vs en capital (LPP art. 37, "
        "LIFD art. 38 tarif réduit 1/5 sur capital). Estime la fiscalité de "
        "chaque option et la longévité du capital sous différents scénarios "
        "de rendement et espérance de vie. Mots-clés : rente, capital, LPP, "
        "retraite, retrait, fiscal."
    ),
    "calendrier_retraits__compare_calendrier_retraits": (
        "Compare différents calendriers de retraits 2e pilier et 3a (LIFD art. "
        "38 tarif réduit 1/5, progressif par tranche cumulative). Estime "
        "l'impôt CHF total selon ordre et étalement des retraits. "
        "Mots-clés : calendrier, retrait, capital, LPP, 3a, retraite, fiscal."
    ),
    "multi_account_service__MultiAccountService_simulate_staggered_withdrawal": (
        "Simule un retrait étalé de plusieurs comptes 3a sur N années (LIFD "
        "art. 38) pour lisser la progressivité cantonale du tarif réduit. "
        "Produit l'impôt CHF total + l'économie vs retrait massé. "
        "Mots-clés : 3a, retrait, étalement, fiscal, canton, capital."
    ),
    "retroactive_3a_service__calculate_retroactive_3a": (
        "Calcule le rachat rétroactif 3a (OPP3 art. 7a / LIFD art. 33 al. 1 "
        "let. e) : comble les lacunes dès 2025 (fenêtre 10 ans), plafonné au "
        "petit maximum 3a par année civile. Estime l'économie fiscale CHF. "
        "Mots-clés : 3a, rétroactif, déduction, fiscal, prévoyance."
    ),
    "cross_pillar_service__CrossPillarService_compute": (
        "Analyse les trois piliers cumulés (AVS + LPP art. 14 + 3a LIFD art. "
        "33) pour identifier gaps et arbitrages chiffrés entre piliers. "
        "Produit le potentiel de rachat LPP, le gap 3a et l'effet fiscal "
        "estimé. Mots-clés : 3a, LPP, AVS, rachat, prévoyance, arbitrage."
    ),
    # ── Fiscal / canton ─────────────────────────────────────────────────────
    "cantonal_comparator__CantonalComparator_estimate_tax": (
        "Estime l'impôt sur le revenu cantonal et fédéral (LIFD + LHID) pour "
        "un revenu donné, selon canton, statut civil et enfants à charge. "
        "Produit l'impôt CHF/an total. Mots-clés : impôt, revenu, canton, "
        "fiscal, LIFD, déclaration."
    ),
    "cantonal_comparator__CantonalComparator_compare_all_cantons": (
        "Compare l'imposition du revenu (LIFD + LHID) sur 26 cantons suisses "
        "pour un profil donné. Produit le classement chiffré CHF/an et le "
        "delta cross-cantonal. Mots-clés : impôt, revenu, canton, fiscal, "
        "comparaison, déménagement, mobilité."
    ),
    "cantonal_comparator__CantonalComparator_simulate_move": (
        "Simule l'impact fiscal d'un déménagement cantonal (LHID art. 68 "
        "domicile fiscal) sur le revenu imposable d'un profil. Estime le "
        "delta d'impôt CHF/an. Mots-clés : déménagement, canton, impôt, "
        "domicile, mobilité, fiscal."
    ),
    "wealth_tax_service__WealthTaxService_estimate_wealth_tax": (
        "Estime l'impôt sur la fortune cantonal (LHID art. 13, taux progressif "
        "cantonal) pour un patrimoine donné. Produit l'impôt CHF/an. "
        "Mots-clés : fortune, patrimoine, impôt, canton, fiscal."
    ),
    "wealth_tax_service__WealthTaxService_compare_all_cantons": (
        "Compare l'impôt sur la fortune (LHID art. 13) entre les 26 cantons "
        "suisses pour un patrimoine donné. Produit le classement CHF/an et "
        "le delta cross-cantonal. Mots-clés : fortune, patrimoine, canton, "
        "impôt, comparaison."
    ),
    "wealth_tax_service__WealthTaxService_simulate_move_wealth": (
        "Simule l'effet d'un déménagement cantonal sur l'impôt fortune (LHID "
        "art. 13). Estime le delta CHF/an et le gain net post-déménagement. "
        "Mots-clés : fortune, déménagement, canton, impôt, mobilité."
    ),
    "church_tax_service__ChurchTaxService_estimate_church_tax": (
        "Estime l'impôt ecclésiastique cantonal selon le canton et "
        "l'affiliation religieuse. Produit la part CHF/an additionnelle à "
        "l'impôt cantonal. Mots-clés : impôt ecclésiastique, canton, fiscal, "
        "affiliation religieuse."
    ),
    "church_tax_service__ChurchTaxService_compare_church_tax_all_cantons": (
        "Compare l'impôt ecclésiastique entre cantons suisses selon "
        "affiliation. Produit le classement CHF/an. Mots-clés : impôt "
        "ecclésiastique, canton, fiscal, comparaison."
    ),
    # ── Family / divorce / succession / naissance ──────────────────────────
    "divorce_simulator__DivorceSimulator_simulate": (
        "Simule l'impact financier d'un divorce ou d'une séparation : "
        "splitting AVS (LAVS art. 29sexies), partage LPP (CC art. 122-124), "
        "pension alimentaire éventuelle (CC art. 125), partage des avoirs "
        "selon régime matrimonial (CC art. 181-251). Produit les flux CHF "
        "et la nouvelle situation patrimoniale. Mots-clés : divorce, "
        "séparation, splitting, LPP, AVS, pension alimentaire, régime "
        "matrimonial."
    ),
    "succession_simulator__SuccessionSimulator_simulate": (
        "Estime les frais de succession cantonaux selon CC art. 462 (conjoint "
        "survivant) et CC art. 467-469 (réserves héréditaires, réforme 2023 "
        "1/2 vs 3/4). Produit l'impôt CHF par héritier et la part nette. "
        "Mots-clés : succession, héritage, conjoint, réserve héréditaire, "
        "canton, impôt."
    ),
    "concubinage_service__ConcubinageService_compare_mariage_vs_concubinage": (
        "Compare la situation fiscale d'un couple marié (CC art. 159) vs "
        "concubinage selon canton, revenus et enfants. Estime le delta "
        "d'impôt CHF/an et l'effet du cap AVS (LAVS art. 35 plafond 150%). "
        "Mots-clés : mariage, concubinage, couple, impôt, canton, AVS, "
        "splitting fiscal."
    ),
    "concubinage_service__ConcubinageService_estimate_inheritance_tax": (
        "Estime l'impôt de succession entre concubins (CC art. 462 inappli- "
        "cable, fiscalité cantonale durcie) selon canton et patrimoine. "
        "Produit l'impôt CHF + la part nette. Mots-clés : concubinage, "
        "succession, héritage, canton, impôt, conjoint."
    ),
    "mariage_service__MariageService_compare_fiscal_impact": (
        "Compare l'impact fiscal d'un mariage (CC art. 159) selon canton et "
        "revenus des deux conjoints. Estime le delta d'impôt CHF/an (penalty "
        "ou bonus selon écart de revenus). Mots-clés : mariage, couple, "
        "fiscal, impôt, canton, splitting."
    ),
    "mariage_service__MariageService_estimate_survivor_benefits": (
        "Estime les prestations de survivant LPP (LPP art. 19-21) et AVS "
        "(LAVS art. 23) en cas de décès d'un conjoint. Produit la rente "
        "CHF/mois pour le conjoint survivant. Mots-clés : survivant, mariage, "
        "conjoint, LPP, AVS, décès, rente."
    ),
    "mariage_service__MariageService_simulate_regime_matrimonial": (
        "Simule les régimes matrimoniaux (CC art. 181 participation aux "
        "acquêts, art. 247 communauté de biens, art. 247sqq. séparation de "
        "biens) sur le partage en cas de divorce ou succession. Produit la "
        "part de chacun CHF. Mots-clés : régime matrimonial, mariage, "
        "acquêts, séparation de biens, divorce, succession."
    ),
    "naissance_service__NaissanceService_calculate_impact_fiscal_enfant": (
        "Calcule l'impact fiscal de la naissance d'un enfant (LIFD art. 35 "
        "déduction enfant, allocations cantonales). Produit l'économie "
        "d'impôt CHF/an et les allocations. Mots-clés : naissance, enfant, "
        "famille, fiscal, déduction, canton, allocation."
    ),
    "naissance_service__NaissanceService_estimate_allocations": (
        "Estime les allocations familiales et de naissance selon canton "
        "(LAFam art. 3). Produit les montants CHF/mois et les bonus de "
        "naissance. Mots-clés : allocation, naissance, famille, enfant, "
        "canton, LAFam."
    ),
    "naissance_service__NaissanceService_simulate_conge_parental": (
        "Simule l'impact financier du congé maternité (LAPG art. 16b 14 "
        "semaines à 80%) et paternité (LAPG art. 16i 2 semaines). Produit "
        "l'indemnité CHF + l'écart vs salaire. Mots-clés : congé, maternité, "
        "paternité, naissance, indemnité, LAPG."
    ),
    "donation_service__DonationService_calculate": (
        "Calcule l'impôt cantonal sur donations entre vifs (LHID art. 12 "
        "réservé aux cantons, taux progressif selon parenté). Produit "
        "l'impôt CHF et la part nette du donataire. Mots-clés : donation, "
        "héritage, canton, impôt, parenté, succession."
    ),
    # ── Cross-border / expat / frontalier (FATCA, EU, US) ──────────────────
    "frontalier_service__FrontalierService_calculate_source_tax": (
        "Calcule l'impôt à la source pour un travailleur frontalier en "
        "Suisse (LIFD art. 91, accord CH-FR 1983). Produit la retenue CHF/mois "
        "selon canton et statut. Mots-clés : frontalier, impôt à la source, "
        "permis G, canton, LIFD, retenue."
    ),
    "frontalier_service__FrontalierService_compare_social_charges": (
        "Compare les charges sociales d'un frontalier (cotisations AVS/AI/APG "
        "côté CH vs sécurité sociale côté pays voisin). Estime l'écart CHF/an "
        "selon options. Mots-clés : frontalier, cotisation, AVS, sécurité "
        "sociale, permis G, charges."
    ),
    "frontalier_service__FrontalierService_estimate_lamal_option": (
        "Estime le coût LAMal vs CMU pour un frontalier (droit d'option, "
        "accord bilatéral CH-EU). Produit les primes annuelles CHF par option "
        "et le delta. Mots-clés : LAMal, CMU, frontalier, assurance maladie, "
        "primes, option."
    ),
    "expat_service__ExpatService_compare_tax_burden": (
        "Compare la charge fiscale d'un expatrié entre Suisse (LIFD + LHID "
        "cantonal) et pays cible selon archétype (expat_eu, expat_us avec "
        "FATCA). Produit l'écart d'impôt CHF/an. Mots-clés : expat, FATCA, "
        "fiscal, impôt, canton, double imposition, cross-border."
    ),
    "expat_service__ExpatService_estimate_avs_gap": (
        "Estime les lacunes AVS (LAVS art. 29bis-29ter) pour un expatrié "
        "selon années passées hors CH. Produit le gap CHF/an de rente et la "
        "possibilité de rachat AVS volontaire. Mots-clés : AVS, expat, "
        "lacunes, rachat, rente, retraite, prévoyance."
    ),
    "expat_service__ExpatService_simulate_forfait_fiscal": (
        "Simule l'imposition d'après la dépense (LIFD art. 14, forfait "
        "fiscal cantonal pour étrangers fortunés sans activité lucrative en "
        "CH). Estime l'impôt CHF/an selon dépenses de train de vie. "
        "Mots-clés : forfait fiscal, expat, canton, impôt, dépense."
    ),
    # ── Independant ─────────────────────────────────────────────────────────
    "independant_service__IndependantService_calculate_avs_contribution": (
        "Calcule les cotisations AVS/AI/APG pour un travailleur indépendant "
        "(LAVS art. 8, taux dégressif sur revenu net). Produit la cotisation "
        "CHF/an. Mots-clés : indépendant, AVS, cotisation, AI, APG, revenu."
    ),
    "independant_service__IndependantService_calculate_3a_plafond": (
        "Calcule le plafond 3a indépendant sans LPP (LIFD art. 33 al. 1 let. "
        "e, 20% du revenu net, max 36'288 CHF/an en 2025). Mots-clés : 3a, "
        "indépendant, plafond, déduction, fiscal, prévoyance."
    ),
    "independant_service__IndependantService_estimate_ijm_cost": (
        "Estime le coût d'une assurance indemnité journalière maladie (IJM) "
        "pour un indépendant selon revenu et délai d'attente. Produit la "
        "prime CHF/an. Mots-clés : indépendant, IJM, indemnité journalière, "
        "maladie, prime."
    ),
    "independant_service__IndependantService_estimate_laa_cost": (
        "Estime le coût d'une assurance accident LAA pour un indépendant "
        "(LAA art. 4, affiliation volontaire). Produit la prime CHF/an. "
        "Mots-clés : indépendant, LAA, accident, assurance, prime."
    ),
    # ── Career / unemployment / debt ───────────────────────────────────────
    "calculator__UnemploymentCalculator_calculate": (
        "Calcule l'indemnité chômage suisse (LACI art. 22, 70% du gain "
        "assuré ou 80% si enfants/bas revenu, durée max 400 jours selon âge "
        "et cotisations). Produit l'indemnité CHF/mois et la durée. "
        "Mots-clés : chômage, LACI, indemnité, gain assuré, perte d'emploi."
    ),
    "job_comparator__JobComparator_compare": (
        "Compare deux offres d'emploi suisses en intégrant salaire brut, "
        "LPP (LPP art. 7 seuil d'accès), 3a, fiscalité cantonale (LIFD + "
        "LHID) et charges. Produit le revenu net CHF/an comparé. "
        "Mots-clés : emploi, salaire, LPP, comparaison, canton, fiscal."
    ),
    "debt_ratio_service__DebtRatioService_calculate_debt_ratio": (
        "Calcule le ratio d'endettement personnel selon revenus mensuels et "
        "charges de dette. Identifie les dépassements du seuil de 33% "
        "endettement-revenu (référence FINMA hypothèque Directives ASB (FINMA)). "
        "Mots-clés : dette, endettement, ratio, charges, revenu, surendettement."
    ),
    "repayment_service__RepaymentService_compare_strategies": (
        "Compare les stratégies de remboursement de dette (snowball par "
        "petite dette d'abord, avalanche par taux d'intérêt). Estime le "
        "coût total CHF et la durée. Mots-clés : dette, remboursement, "
        "snowball, avalanche, stratégie, intérêt."
    ),
    # ── Arbitrage / allocation / FRI ───────────────────────────────────────
    "allocation_annuelle__compare_allocation_annuelle": (
        "Compare l'allocation annuelle d'une épargne disponible entre 3a "
        "(LIFD art. 33), rachat LPP (LIFD art. 33), amortissement hypothèque "
        "(Directives ASB (FINMA)) et placement libre. Produit le ROI par scénario selon "
        "canton et profil. Mots-clés : 3a, rachat, LPP, hypothèque, "
        "arbitrage, allocation, fiscal."
    ),
    "fri_service__FriService_compute_fiscal": (
        "Calcule l'axe fiscal du Financial Readiness Index (FRI) en intégrant "
        "impôt sur le revenu (LIFD + LHID), fortune (LHID art. 13) et "
        "potentiels d'optimisation 3a + LPP. Mots-clés : FRI, fiscal, impôt, "
        "fortune, 3a, LPP, canton."
    ),
    "fri_service__FriService_compute_retirement": (
        "Calcule l'axe retraite du FRI en cumulant AVS (LAVS art. 21), LPP "
        "(LPP art. 14) et 3a (LIFD art. 33 al. 1 let. e) projetés. "
        "Mots-clés : FRI, retraite, AVS, LPP, 3a, prévoyance."
    ),
    "real_return_service__RealReturnService_calculate_real_return": (
        "Calcule le rendement réel net d'un placement après inflation et "
        "fiscalité du revenu (LIFD) + fortune (LHID art. 13). Produit le "
        "rendement net CHF/an. Mots-clés : rendement, réel, inflation, "
        "placement, fiscal, fortune."
    ),
    "provider_comparator_service__ProviderComparatorService_compare_providers": (
        "Compare les fournisseurs de produits financiers suisses (fonds 3a, "
        "ETF, banques) sur les frais TER, performance et accessibilité. "
        "Produit le classement sans recommandation personnalisée. "
        "Mots-clés : 3a, ETF, fonds, frais, comparaison, prévoyance."
    ),
}


def _description_for(meta: dict[str, Any]) -> str:
    """Plan 09 W2-03 : return the FR description for ``meta["name"]`` if a
    Concern A entry exists, else fall back to the templated stub.

    The map covers the long-tail tools most likely to be surfaced by Anthropic
    Tool Search BM25 on French user queries (divorce, retraite, frontalier,
    hypothèque, déménagement cantonal, indépendant, naissance…). REGISTRY
    entries not in the map keep the templated stub — those tend to be internal
    helpers (FriService_compute, NextStepsService_calculate) that BM25 should
    not surface first anyway.
    """
    name = meta.get("name", "")
    fr_desc = _TOOL_DESCRIPTIONS_FR.get(name)
    if fr_desc:
        return fr_desc
    return _templated_description_for(meta)


def _templated_description_for(meta: dict[str, Any]) -> str:
    """Templated fallback description for REGISTRY entries NOT in
    ``_TOOL_DESCRIPTIONS_FR``. Surfaces life_events_served + name so BM25 has
    SOMETHING to match against (Plan 07 v1 behaviour preserved)."""
    name = meta.get("name", "")
    events = ", ".join(meta.get("life_events_served", []) or ["cross_cutting"])
    fields = ", ".join(meta.get("profile_fields_needed", [])[:5])
    return (
        f"{name} — life_events_served : {events}. "
        f"profile_fields_needed : {fields}. "
        f"v1 templated description — Plan 09 LSFin keyword rewrite fallback."
    )


def _templated_input_schema_for(meta: dict[str, Any]) -> dict[str, Any]:
    """v1 input schema — empty object until Plan 09 walks each calculator's
    Pydantic request schema and produces a proper JSON Schema. This is enough
    for BM25 indexing on ``description`` ; Sonnet 4.5 will not invoke a
    deferred tool with this empty schema in v1 (Plan 10 wires the dispatcher).
    """
    return {
        "type": "object",
        "properties": {},
        "required": [],
    }


class AnthropicDeferLoadingAdapter:
    """D-CE-01 default — Anthropic Tool Search Tool with per-tool defer_loading.

    Implements :py:class:`app.services.coach.tool_registry.ToolRegistryAdapter`
    structurally (no inheritance needed — ``runtime_checkable`` Protocol).
    """

    def __init__(self) -> None:
        # Cache the chip-emitter definitions at construction time so the
        # ``coach_tools`` import happens once, not per ``register_tools`` call.
        self._chip_definitions = _load_chip_emitter_descriptions()

    # ─── ToolRegistryAdapter protocol ──────────────────────────────────────

    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
        """Return the full Anthropic ``tools`` array for the current turn.

        Shape :
        - 5 chip-emitters always-on (no ``defer_loading`` key — Anthropic
          default False).
        - 63 long-tail calculators with ``defer_loading: True``.
        - 1 ``tool_search_tool_bm25_20251119`` declaration.
        """
        tools: list[ToolDefinition] = []

        # 1. Always-on chip-emitters (5).
        for name in _ALWAYS_ON_TOOLS:
            if name in self._chip_definitions:
                tools.append(self._chip_definitions[name])

        # 2. Long-tail deferred calculators (63 from REGISTRY).
        for name, meta in REGISTRY.items():
            if name in _ALWAYS_ON_TOOLS:
                # Belt-and-suspenders : the AST scanner doesn't emit chip
                # emitters today (verified Plan 05 SUMMARY), but if a future
                # scanner widening picks them up, the always-on path wins.
                continue
            tools.append(
                {
                    "name": name,
                    "description": _description_for(meta),
                    "input_schema": _templated_input_schema_for(meta),
                    "defer_loading": True,
                }
            )

        # 3. Tool Search Tool declaration.
        tools.append(_TOOL_SEARCH_DECLARATION)

        return tools

    def latency_tier(self, tool_name: str) -> LatencyTier:
        """Map a tool name to its Flutter rendering surface tier.

        - Chip-emitters → L1 (sub-500 ms atomic surface).
        - Long-tail calc in REGISTRY → ``output_type`` from registry metadata
          (Plan 05 emits ``L1`` for all today ; Plan 09 retrofits L2/L3).
        - Unknown → ``L2`` default (narrative loader 2-8 s).
        """
        if tool_name in _ALWAYS_ON_TOOLS:
            return "L1"
        meta = REGISTRY.get(tool_name)
        if meta is None:
            return "L2"
        output_type = meta.get("output_type")
        if output_type in ("L1", "L2", "L3"):
            return output_type  # type: ignore[return-value]
        # L4 invariants are surfaced via dedicated endpoint (Plan 04), not
        # via the tool-registry latency surface — map L4 → L2 for routing.
        return "L2"

    # ─── Anthropic-specific extension ──────────────────────────────────────

    @property
    def beta_header(self) -> str:
        """The ``anthropic-beta`` header value to add to ``messages.create()``.

        Pinned at ``tool-search-tool-2025-10-19``. If Anthropic ships v2026-XX,
        ONLY this property updates — other adapters are immune.
        """
        return _BETA_HEADER
