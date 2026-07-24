"""RegulatoryRegistry — in-memory registry of all Swiss financial constants.

Single source of truth consumed by:
    - Backend calculators (via get())
    - API endpoints (via /regulatory/*)
    - LLM tools (via get_regulatory_constant)
    - Frontend (via API sync)

Architecture:
    - Singleton pattern: one registry instance per process.
    - Constants are hardcoded in _PARAMETERS for now (DB migration planned P4).
    - Every constant from social_insurance.py is mirrored here with full metadata.
    - Freshness tracking: reviewed_at powers runtime/scheduled stale reports.

Sources:
    - CLAUDE.md §5 (Key Constants 2025/2026)
    - app/constants/social_insurance.py (raw values)
    - OPP3 art. 7, LPP art. 7-16, LAVS art. 21-40, LIFD art. 38
    - FINMA/ASB mortgage guidelines
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Optional

from app.models.regulatory_parameter import RegulatoryParameter

logger = logging.getLogger(__name__)

# ══════════════════════════════════════════════════════════════════════════════
# OFAS source URLs (used across multiple parameters)
# ══════════════════════════════════════════════════════════════════════════════

_OFAS_LPP_URL = "https://www.bsv.admin.ch/bsv/fr/home/assurances-sociales/bv/donnees-de-base-et-parametres/donnees-importantes-de-la-prevoyance-professionnelle.html"
_OFAS_AVS_URL = "https://www.bsv.admin.ch/bsv/fr/home/assurances-sociales/ahv/donnees-de-base-et-parametres/rentes.html"
_OFAS_CONTRIBUTIONS_URL = "https://www.bsv.admin.ch/fr/cotisations-apercu"
_OFAS_3A_URL = "https://www.bsv.admin.ch/bsv/fr/home/assurances-sociales/bv/donnees-de-base-et-parametres/pilier-3a.html"
# Audit factuel -zaw (2026-07-23) : 132 constantes vérifiées sur sources
# officielles par 4 agents WebSearch — 12 valeurs corrigées (échelle 44,
# RAMD, ajournement 2/3/4 ans, cotisation volontaire, limites 3a
# historiques), provenance précisée (OAMal 103, OEPL 5, doc 318.117.011).
# Verdicts complets : .planning/audit-etat-des-lieux-2026-07/constants-audit/.
_REVIEWED = date(2026, 7, 23)

# Sources précises — campagne provenance beads MINT_nosync-337 (verdict C).
# URLs vérifiées par l'audit factuel -zaw du 2026-07-23 (WebSearch/WebFetch).
_ASB_HYPO_URL = (
    "https://www.finma.ch/fr/~/media/finma/dokumente/dokumentencenter/"
    "myfinma/4dokumentation/selbstregulierung/"
    "sbvg_rl_hypofinanzierungen_20231213.pdf"
)
_LIFD_ART38_URL = (
    "https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_38"
)
_ESTV_CAPITAL_SIM_URL = (
    "https://swisstaxcalculator.estv.admin.ch/#/calculator/capital-benefit-tax"
)
_LEGACY_CAPITAL_NOTE = (
    "Approximation v1 (taux plat) — le calcul canonique de l'impôt de "
    "retrait est le modèle v2 estimate_capital_withdrawal_tax (IFD "
    "art. 38 exact + interpolation ESTV 130 points, beads -2i2). Usages "
    "restants : validation canton et chemin override explicite "
    "(calculate_progressive_capital_tax). Les deux anciens proxys "
    "heuristiques (location_vs_propriete impôt revenu, allocation "
    "invest libre impôt fortune) ont été migrés vers les modèles v2 "
    "(beads -cm4)."
)

# Pratique bancaire de place (test de tenue) — non normée par la
# directive ASB : celle-ci ne fixe que la part min. hors 2e pilier et
# l'amortissement aux 2/3 en 15 ans (vérifié sur le PDF, review #994).
_VZ_TENUE_URL = (
    "https://www.vermoegenszentrum.ch/fr/competences/"
    "un-bien-foncier-doit-etre-financierement-supportable"
)
_PRATIQUE_TENUE_NOTE = (
    "Convention de place appliquée par les banques dans le test de tenue "
    "des charges — non normée par la directive ASB exigences minimales "
    "(qui ne fixe que la part min. 10% hors 2e pilier et l'amortissement "
    "aux 2/3 de la valeur de nantissement en 15 ans)."
)

# ══════════════════════════════════════════════════════════════════════════════
# All regulatory parameters — seeded from social_insurance.py
# ══════════════════════════════════════════════════════════════════════════════

_PARAMETERS: list[RegulatoryParameter] = [
    # ─────────────────────────────────────────────────────────────────
    # Pillar 3a — Prévoyance individuelle liée (OPP3 art. 7)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="pillar3a.max_with_lpp",
        value=7_258.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        tax_year=2025,
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 al. 1",
        source_type="ordinance",
        description="Plafond annuel 3a pour salariés affiliés à la LPP (petit 3a).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.max_without_lpp",
        value=36_288.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        tax_year=2025,
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 al. 2",
        source_type="ordinance",
        description="Plafond annuel 3a pour indépendants sans LPP (grand 3a = 20% du revenu net, max 36'288).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.income_rate_without_lpp",
        value=0.20,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 al. 2",
        source_type="ordinance",
        description="Part du revenu déterminant pour le grand 3a : 20%.",
        reviewed_at=_REVIEWED,
    ),
    # 3a historical limits (2016-2026)
    RegulatoryParameter(
        key="pillar3a.historical_limits.2026",
        value=7_258.0,
        unit="CHF",
        tax_year=2026,
        effective_from=date(2026, 1, 1),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2026.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2025",
        value=7_258.0,
        unit="CHF",
        tax_year=2025,
        effective_from=date(2025, 1, 1),
        effective_to=date(2025, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2025.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2024",
        value=7_056.0,
        unit="CHF",
        tax_year=2024,
        effective_from=date(2024, 1, 1),
        effective_to=date(2024, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2024.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2023",
        value=7_056.0,
        unit="CHF",
        tax_year=2023,
        effective_from=date(2023, 1, 1),
        effective_to=date(2023, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2023.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2022",
        value=6_883.0,
        unit="CHF",
        tax_year=2022,
        effective_from=date(2022, 1, 1),
        effective_to=date(2022, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2022.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2021",
        value=6_883.0,
        unit="CHF",
        tax_year=2021,
        effective_from=date(2021, 1, 1),
        effective_to=date(2021, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2021.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2020",
        value=6_826.0,
        unit="CHF",
        tax_year=2020,
        effective_from=date(2020, 1, 1),
        effective_to=date(2020, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2020.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2019",
        value=6_826.0,
        unit="CHF",
        tax_year=2019,
        effective_from=date(2019, 1, 1),
        effective_to=date(2019, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2019.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2018",
        value=6_768.0,
        unit="CHF",
        tax_year=2018,
        effective_from=date(2018, 1, 1),
        effective_to=date(2018, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2018.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2017",
        value=6_768.0,
        unit="CHF",
        tax_year=2017,
        effective_from=date(2017, 1, 1),
        effective_to=date(2017, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2017.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="pillar3a.historical_limits.2016",
        value=6_768.0,
        unit="CHF",
        tax_year=2016,
        effective_from=date(2016, 1, 1),
        effective_to=date(2016, 12, 31),
        source_url=_OFAS_3A_URL,
        source_title="OPP3 art. 7 — OFAS publication annuelle",
        source_type="ordinance",
        description="Plafond 3a (avec LPP) pour l'année 2016.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # LPP — Prévoyance professionnelle (2e pilier)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="lpp.entry_threshold",
        value=22_680.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 7",
        source_type="law",
        description="Salaire annuel minimum pour être soumis à la LPP (seuil d'accès).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.coordination_deduction",
        value=26_460.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 8",
        source_type="law",
        description="Déduction de coordination. Salaire coordonné = brut - déduction.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.min_coordinated_salary",
        value=3_780.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 8 al. 2",
        source_type="law",
        description="Salaire coordonné minimum assuré.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.max_coordinated_salary",
        value=64_260.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 8 al. 1",
        source_type="law",
        description="Salaire coordonné maximum assuré.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.max_insured_salary",
        value=90_720.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 8 al. 1",
        source_type="law",
        description="Salaire annuel maximum assuré LPP.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.conversion_rate",
        value=0.068,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 14 al. 2",
        source_type="law",
        description="Taux de conversion minimum LPP (6.8%). Capital -> rente annuelle.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.min_interest_rate",
        value=1.25,
        unit="percent",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="OPP2 — Conseil fédéral",
        source_type="ordinance",
        description="Taux d'intérêt minimum LPP (fixé par le Conseil fédéral).",
        reviewed_at=_REVIEWED,
        notes=(
            "Maintenu à 1.25% pour 2026 par décision du Conseil fédéral "
            "du 2025-11-05 (recommandation Commission LPP 10 voix contre "
            "6) — vérifié admin.ch le 2026-07-24. Le Conseil fédéral "
            "réexamine le taux au moins tous les deux ans (LPP art. 15 "
            "al. 3) — re-vérifier avant toute utilisation pour une "
            "année ultérieure."
        ),
    ),
    RegulatoryParameter(
        key="lpp.bonification.25_34",
        value=0.07,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 16",
        source_type="law",
        description="Taux de bonification de vieillesse 25-34 ans : 7% du salaire coordonné.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.bonification.35_44",
        value=0.10,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 16",
        source_type="law",
        description="Taux de bonification de vieillesse 35-44 ans : 10% du salaire coordonné.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.bonification.45_54",
        value=0.15,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 16",
        source_type="law",
        description="Taux de bonification de vieillesse 45-54 ans : 15% du salaire coordonné.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.bonification.55_65",
        value=0.18,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 16",
        source_type="law",
        description="Taux de bonification de vieillesse 55-65 ans : 18% du salaire coordonné.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.conversion_rate_complementaire",
        value=0.058,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="Pratique caisses complémentaires",
        source_type="estimate",
        description="Taux de conversion surobligatoire INDICATIF : fixé librement par chaque caisse (aucune valeur légale). Hypothèse éditable, jamais à présenter comme réglementaire (audit -zaw 2026-07-23).",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # EPL — Encouragement à la propriété du logement (LPP art. 30c)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="lpp.epl_minimum",
        value=20_000.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="OEPL art. 5 (retrait EPL minimum)",
        source_type="ordinance",
        description="Montant minimum pour un retrait EPL.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lpp.epl_buyback_lock_years",
        value=3.0,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_LPP_URL,
        source_title="LPP art. 79b al. 3",
        source_type="law",
        description="Délai (3 ans) pendant lequel un retrait en capital (dont EPL) est bloqué après un rachat LPP volontaire — art. 79b al. 3. NB : le blocage EPL→rachat (art. 79b al. 4) dure jusqu'au remboursement, pas 3 ans.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # AVS — Assurance-vieillesse et survivants (1er pilier)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="avs.max_monthly_pension",
        value=2_520.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34",
        source_type="law",
        description="Rente AVS maximale individuelle mensuelle.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.min_monthly_pension",
        value=1_260.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34",
        source_type="law",
        description="Rente AVS minimale individuelle mensuelle (50% de la rente max).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.couple_max_monthly",
        value=3_780.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 35",
        source_type="law",
        description="Rente AVS maximale pour un couple marié mensuelle (150% de la rente max individuelle).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.echelle44",
        value=[
            # Doc OFAS 318.117.011 « Tables des rentes 2025 » p. 20
            # (échelle 44, rente vieillesse 1/1), valable dès 1.1.2025 et
            # inchangé en 2026 (OFAS « Montants dès le 1.1.2026 »).
            # 51 paliers, pas RAMD 1'512 ; borne = « jusqu'à ».
            [15120, 1260], [16632, 1293], [18144, 1326], [19656, 1358],
            [21168, 1391], [22680, 1424], [24192, 1457], [25704, 1489],
            [27216, 1522], [28728, 1555], [30240, 1588], [31752, 1620],
            [33264, 1653], [34776, 1686], [36288, 1719], [37800, 1751],
            [39312, 1784], [40824, 1817], [42336, 1850], [43848, 1882],
            [45360, 1915], [46872, 1935], [48384, 1956], [49896, 1976],
            [51408, 1996], [52920, 2016], [54432, 2036], [55944, 2056],
            [57456, 2076], [58968, 2097], [60480, 2117], [61992, 2137],
            [63504, 2157], [65016, 2177], [66528, 2197], [68040, 2218],
            [69552, 2238], [71064, 2258], [72576, 2278], [74088, 2298],
            [75600, 2318], [77112, 2339], [78624, 2359], [80136, 2379],
            [81648, 2399], [83160, 2419], [84672, 2439], [86184, 2460],
            [87696, 2480], [89208, 2500], [90720, 2520],
        ],
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="OFAS doc 318.117.011 Tables des rentes 2025 p.20 (échelle 44) — valable 2026",
        source_type="law",
        description="Échelle 44 — table de correspondance RAMD annuel → rente mensuelle AVS. "
        "Mise à jour tous les 2 ans par le Conseil fédéral (indice mixte).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.max_annual_pension",
        value=30_240.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34",
        source_type="law",
        description="Rente AVS maximale annuelle individuelle (2'520 x 12).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.contribution_rate_employee",
        value=0.053,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 5",
        source_type="law",
        description="Taux de cotisation AVS/AI/APG part salarié : 5.3% (total 10.6%).",
        reviewed_at=_REVIEWED,
        notes=(
            "COMBINÉ AVS+AI+APG (AVS pur 8.7% + AI 1.4% + APG 0.5% = "
            "10.6% paritaire). Ne JAMAIS additionner avec "
            "ai.contribution_rate_* ni apg.contribution_rate_* — ils y "
            "sont déjà inclus (beads MINT_nosync-b9c, verdict A -zaw)."
        ),
    ),
    RegulatoryParameter(
        key="avs.contribution_rate_total",
        value=0.106,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 5",
        source_type="law",
        description="Taux de cotisation AVS/AI/APG total (salarié + employeur) : 10.6%.",
        reviewed_at=_REVIEWED,
        notes=(
            "COMBINÉ AVS+AI+APG (AVS pur 8.7% + AI 1.4% + APG 0.5% = "
            "10.6% paritaire). Ne JAMAIS additionner avec "
            "ai.contribution_rate_* ni apg.contribution_rate_* — ils y "
            "sont déjà inclus (beads MINT_nosync-b9c, verdict A -zaw)."
        ),
    ),
    RegulatoryParameter(
        key="avs.full_contribution_years",
        value=44.0,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 29ter",
        source_type="law",
        description="Nombre d'années de cotisation pour une rente complète.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.reference_age_men",
        value=65.0,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 21",
        source_type="law",
        description="Âge de référence AVS pour les hommes.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.reference_age_women",
        value=64.5,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 21 (réforme AVS 21)",
        source_type="law",
        description=(
            "Âge de référence AVS pour les femmes : SCALAIRE TRANSITOIRE "
            "64.5 (cohorte 1962, retraites prises en 2026). NE PAS consommer "
            "dans un moteur — l'âge "
            "dépend de la COHORTE (réforme AVS 21 : <=1960 64 ; 1961 "
            "64+3 mois ; 1962 64+6 mois ; 1963 64+9 mois ; 1964+ 65). "
            "Utiliser avs_reference_age(birth_year, is_female) backend / "
            "avsReferenceAge(birthYear, isFemale) Dart (beads -xx9)."
        ),
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.anticipation_reduction",
        value=0.068,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 40",
        source_type="law",
        description="Réduction par année d'anticipation de la rente AVS : 6.8%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.deferral_supplement.1",
        value=0.052,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 39",
        source_type="law",
        description="Supplément de rente pour 1 an d'ajournement : +5.2%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.deferral_supplement.2",
        value=0.108,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 39",
        source_type="law",
        description="Supplément de rente pour 2 ans d'ajournement : +10.8%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.deferral_supplement.3",
        value=0.171,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 39",
        source_type="law",
        description="Supplément de rente pour 3 ans d'ajournement : +17.1%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.deferral_supplement.4",
        value=0.240,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 39",
        source_type="law",
        description="Supplément de rente pour 4 ans d'ajournement : +24.0%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.deferral_supplement.5",
        value=0.315,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 39",
        source_type="law",
        description="Supplément de rente pour 5 ans d'ajournement : +31.5%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.retiree_franchise_monthly",
        value=1_400.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 4",
        source_type="law",
        description="Franchise AVS pour retraités actifs, mensuelle.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.retiree_franchise_annual",
        value=16_800.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 4",
        source_type="law",
        description="Franchise AVS pour retraités actifs, annuelle.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.survivor_factor",
        value=0.80,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 23-24",
        source_type="law",
        description="Facteur rente de survivant (80% de la rente du défunt).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.ramd_min",
        value=15_120.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34",
        source_type="law",
        description="RAMD minimum (revenu annuel moyen déterminant). Rente = min si salaire <= RAMD_MIN.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.ramd_max",
        value=90_720.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34",
        source_type="law",
        description="RAMD maximum. Rente = max si salaire >= RAMD_MAX.",
        reviewed_at=_REVIEWED,
    ),
    # 13th pension
    RegulatoryParameter(
        key="avs.13th_pension_active",
        value=1.0,
        unit="boolean",
        effective_from=date(2026, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34 (nouveau), art. constitutionnel 112 al. 4bis",
        source_type="law",
        description="13ème rente AVS active (true=1.0). Premier versement décembre 2026.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.13th_pension_start_year",
        value=2026.0,
        unit="years",
        effective_from=date(2026, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34 (nouveau)",
        source_type="law",
        description="Année du premier versement de la 13ème rente AVS.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.13th_pension_factor",
        value=13.0 / 12.0,
        unit="ratio",
        effective_from=date(2026, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 34 (nouveau)",
        source_type="law",
        description="Facteur multiplicateur 13ème rente (13/12 = 1.0833...).",
        reviewed_at=_REVIEWED,
    ),
    # AVS volontaire (expatriés)
    RegulatoryParameter(
        key="avs.voluntary_contribution_min",
        value=530.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 2",
        source_type="law",
        description="Cotisation AVS/AI/APG annuelle minimale des personnes sans activité lucrative (Mémento 2.03, 2025/2026).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.voluntary_contribution_max",
        value=26_500.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 2",
        source_type="law",
        description="Cotisation AVS/AI/APG annuelle maximale des personnes sans activité lucrative (50 x 530, Mémento 2.03, 2025/2026).",
        reviewed_at=_REVIEWED,
    ),
    # AVS indépendants
    RegulatoryParameter(
        key="avs.min_contribution_independent",
        value=530.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAVS art. 8",
        source_type="law",
        description="Cotisation AVS minimale annuelle pour indépendants.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="avs.independent_min_income_threshold",
        value=10_100.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_CONTRIBUTIONS_URL,
        source_title="LAVS art. 8",
        source_type="law",
        description="Seuil de revenu en dessous duquel la cotisation minimale s'applique.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # AI — Assurance-invalidité (LAI)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="ai.contribution_rate_employee",
        value=0.007,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAI art. 3",
        source_type="law",
        description="Taux de cotisation AI part salarié : 0.7% (total 1.4%).",
        reviewed_at=_REVIEWED,
        notes=(
            "Déjà INCLUS dans avs.contribution_rate_* (taux combiné "
            "AVS+AI+APG) — clé séparée pour référence/affichage "
            "uniquement, ne pas additionner (beads MINT_nosync-b9c)."
        ),
    ),
    RegulatoryParameter(
        key="ai.contribution_rate_total",
        value=0.014,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAI art. 3",
        source_type="law",
        description="Taux de cotisation AI total : 1.4%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ai.full_pension_monthly",
        value=2_520.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAI art. 28",
        source_type="law",
        description="Rente AI entière mensuelle (= rente AVS max). Degré invalidité >= 70%.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # APG — Allocations pour perte de gain (LAPG)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="apg.contribution_rate_employee",
        value=0.0025,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAPG art. 27",
        source_type="law",
        description="Taux de cotisation APG part salarié : 0.25% (total 0.5%).",
        reviewed_at=_REVIEWED,
        notes=(
            "Déjà INCLUS dans avs.contribution_rate_* (taux combiné "
            "AVS+AI+APG) — clé séparée pour référence/affichage "
            "uniquement, ne pas additionner (beads MINT_nosync-b9c)."
        ),
    ),
    RegulatoryParameter(
        key="apg.contribution_rate_total",
        value=0.005,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAPG art. 27",
        source_type="law",
        description="Taux de cotisation APG total : 0.5%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="apg.maternity_days",
        value=98.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAPG art. 16d",
        source_type="law",
        description="Durée du congé maternité : 98 jours = 14 semaines.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="apg.maternity_rate",
        value=0.80,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAPG art. 16f",
        source_type="law",
        description="Taux d'indemnité de maternité : 80% du salaire.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="apg.paternity_days",
        value=10.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LAPG art. 16i",
        source_type="law",
        description="Durée du congé paternité : 10 jours.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # AC — Assurance-chômage (LACI)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="ac.max_insured_salary",
        value=148_200.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 3",
        source_type="law",
        description="Plafond du salaire assuré AC.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.contribution_rate_employee",
        value=0.011,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 3",
        source_type="law",
        description="Taux de cotisation AC part salarié : 1.1% (total 2.2%).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.contribution_rate_total",
        value=0.022,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 3",
        source_type="law",
        description="Taux de cotisation AC total : 2.2%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.solidarity_rate_employee",
        value=0.005,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 3",
        source_type="law",
        description="Cotisation de solidarité AC part salarié : 0.5% (au-dessus du plafond).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.solidarity_rate_total",
        value=0.01,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 3",
        source_type="law",
        description="Cotisation de solidarité AC total : 1.0%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.benefit_rate_standard",
        value=0.70,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 22",
        source_type="law",
        description="Taux d'indemnité chômage standard : 70%.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.benefit_rate_family",
        value=0.80,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_OFAS_AVS_URL,
        source_title="LACI art. 22",
        source_type="law",
        description="Taux d'indemnité chômage avec charges de famille : 80%.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # LAMal — Assurance-maladie obligatoire
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="lamal.copay_rate",
        value=0.10,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url="https://www.bag.admin.ch/bag/fr/home/versicherungen/krankenversicherung.html",
        source_title="OAMal art. 103 (participation aux coûts)",
        source_type="law",
        description="Quote-part : 10% des frais au-dessus de la franchise.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lamal.copay_cap_adult",
        value=700.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url="https://www.bag.admin.ch/bag/fr/home/versicherungen/krankenversicherung.html",
        source_title="LAMal art. 64 al. 2",
        source_type="law",
        description="Quote-part maximale annuelle adultes >= 26 ans.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="lamal.copay_cap_child",
        value=350.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url="https://www.bag.admin.ch/bag/fr/home/versicherungen/krankenversicherung.html",
        source_title="LAMal art. 64 al. 4",
        source_type="law",
        description="Quote-part maximale annuelle enfants < 18 ans.",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # Mortgage — Pratique bancaire suisse (ASB / FINMA)
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="mortgage.theoretical_rate",
        value=0.05,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_VZ_TENUE_URL,
        source_title="Pratique bancaire suisse — test de tenue des charges (convention de place)",
        source_type="estimate",
        description="Taux d'intérêt théorique pour le calcul de capacité (5%).",
        reviewed_at=_REVIEWED,
        notes=_PRATIQUE_TENUE_NOTE,
    ),
    RegulatoryParameter(
        key="mortgage.amortization_rate",
        value=0.01,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ASB_HYPO_URL,
        source_title="ASB — Directives exigences minimales financements hypothécaires (rév. 2023, en vigueur 01.01.2025)",
        source_type="estimate",
        description="Taux d'amortissement annuel — approximation pratique (1%).",
        reviewed_at=_REVIEWED,
        notes=(
            "La règle ASB réelle n'est pas 1 %/an : amortir la dette "
            "jusqu'à 2/3 de la valeur de nantissement en 15 ans au plus "
            "(linéaire). 1 %/an approxime le cas 80 % -> 2/3 "
            "(13,4 points / 15 ans)."
        ),
    ),
    RegulatoryParameter(
        key="mortgage.maintenance_rate",
        value=0.01,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_VZ_TENUE_URL,
        source_title="Pratique bancaire suisse — test de tenue des charges (convention de place)",
        source_type="estimate",
        description="Taux de frais accessoires annuels (entretien, assurance) : 1%.",
        reviewed_at=_REVIEWED,
        notes=_PRATIQUE_TENUE_NOTE,
    ),
    RegulatoryParameter(
        key="mortgage.max_charge_ratio",
        value=1.0 / 3.0,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_VZ_TENUE_URL,
        source_title="Pratique bancaire suisse — test de tenue des charges (convention de place)",
        source_type="estimate",
        description="Ratio maximal des charges par rapport au revenu brut (règle du 1/3).",
        reviewed_at=_REVIEWED,
        notes=_PRATIQUE_TENUE_NOTE,
    ),
    RegulatoryParameter(
        key="mortgage.min_equity",
        value=0.20,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_VZ_TENUE_URL,
        source_title="Pratique bancaire suisse — test de tenue des charges (convention de place)",
        source_type="estimate",
        description="Part minimale de fonds propres (20% du prix d'achat).",
        reviewed_at=_REVIEWED,
        notes=_PRATIQUE_TENUE_NOTE,
    ),
    RegulatoryParameter(
        key="mortgage.max_2nd_pillar",
        value=0.10,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ASB_HYPO_URL,
        source_title="ASB — Directives exigences minimales (fonds propres hors 2e pilier, rév. 2023)",
        source_type="circular",
        description="Part maximale du 2e pilier dans les fonds propres (10% du prix d'achat).",
        reviewed_at=_REVIEWED,
    ),

    # ─────────────────────────────────────────────────────────────────
    # Capital withdrawal tax — Default rate + progressive brackets
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="capital_tax.default_rate",
        value=0.065,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_LIFD_ART38_URL,
        source_title="Fallback effectif médian — approximation (LIFD art. 38 = 1/5 du barème art. 36, pas un taux plat)",
        source_type="estimate",
        description="Taux par défaut de l'impôt sur le retrait de capital (fallback canton inconnu).",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.married_discount",
        value=0.85,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Facteur uniforme legacy — approximation (le traitement marié varie par canton)",
        source_type="estimate",
        description="Réduction d'impôt pour les couples mariés (facteur uniforme legacy).",
        reviewed_at=_REVIEWED,
        notes=(
            "Aucun rabais marié uniforme n'existe en droit fédéral — le "
            "calcul canonique v2 utilise les coefficients PAR CANTON "
            "(MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON, ex. ZH 0.73, audit "
            "swiss-brain 2026-04-18 Q5) via estimate_capital_withdrawal_tax. "
            "Clé conservée pour compat du chemin override."
        ),
    ),
    RegulatoryParameter(
        key="capital_tax.bracket.0_100k",
        value=1.00,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Multiplicateur forfaitaire legacy — approximation (art. 38 LIFD = 1/5 du barème progressif, pas une échelle plate)",
        source_type="estimate",
        description="Multiplicateur tranche 0-100k CHF pour impôt sur retrait de capital.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.bracket.100k_200k",
        value=1.15,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Multiplicateur forfaitaire legacy — approximation (art. 38 LIFD = 1/5 du barème progressif, pas une échelle plate)",
        source_type="estimate",
        description="Multiplicateur tranche 100-200k CHF pour impôt sur retrait de capital.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.bracket.200k_500k",
        value=1.30,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Multiplicateur forfaitaire legacy — approximation (art. 38 LIFD = 1/5 du barème progressif, pas une échelle plate)",
        source_type="estimate",
        description="Multiplicateur tranche 200-500k CHF pour impôt sur retrait de capital.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.bracket.500k_1m",
        value=1.50,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Multiplicateur forfaitaire legacy — approximation (art. 38 LIFD = 1/5 du barème progressif, pas une échelle plate)",
        source_type="estimate",
        description="Multiplicateur tranche 500k-1M CHF pour impôt sur retrait de capital.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.bracket.1m_plus",
        value=1.70,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Multiplicateur forfaitaire legacy — approximation (art. 38 LIFD = 1/5 du barème progressif, pas une échelle plate)",
        source_type="estimate",
        description="Multiplicateur tranche 1M+ CHF pour impôt sur retrait de capital.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),

    # ─────────────────────────────────────────────────────────────────
    # Capital withdrawal tax — 26 cantonal base rates
    # ─────────────────────────────────────────────────────────────────
    RegulatoryParameter(
        key="capital_tax.cantonal.ZH", value=0.065, unit="ratio", jurisdiction="ZH",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy ZH — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Zürich.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.BE", value=0.075, unit="ratio", jurisdiction="BE",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy BE — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Bern.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.LU", value=0.055, unit="ratio", jurisdiction="LU",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy LU — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Luzern.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.UR", value=0.050, unit="ratio", jurisdiction="UR",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy UR — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Uri.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.SZ", value=0.040, unit="ratio", jurisdiction="SZ",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy SZ — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Schwyz.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.OW", value=0.045, unit="ratio", jurisdiction="OW",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy OW — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Obwalden.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.NW", value=0.040, unit="ratio", jurisdiction="NW",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy NW — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Nidwalden.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.GL", value=0.055, unit="ratio", jurisdiction="GL",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy GL — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Glarus.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.ZG", value=0.035, unit="ratio", jurisdiction="ZG",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy ZG — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Zug.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.FR", value=0.070, unit="ratio", jurisdiction="FR",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LICD FR", source_type="estimate",
        description="Taux de base impôt retrait capital — Fribourg.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.SO", value=0.065, unit="ratio", jurisdiction="SO",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy SO — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Solothurn.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.BS", value=0.075, unit="ratio", jurisdiction="BS",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy BS — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Basel-Stadt.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.BL", value=0.065, unit="ratio", jurisdiction="BL",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy BL — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Basel-Landschaft.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.SH", value=0.060, unit="ratio", jurisdiction="SH",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy SH — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Schaffhausen.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.AR", value=0.055, unit="ratio", jurisdiction="AR",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy AR — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Appenzell Ausserrhoden.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.AI", value=0.045, unit="ratio", jurisdiction="AI",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy AI — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Appenzell Innerrhoden.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.SG", value=0.060, unit="ratio", jurisdiction="SG",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy SG — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — St. Gallen.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.GR", value=0.055, unit="ratio", jurisdiction="GR",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy GR — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Graubünden.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.AG", value=0.060, unit="ratio", jurisdiction="AG",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy AG — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Aargau.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.TG", value=0.055, unit="ratio", jurisdiction="TG",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="Taux plat legacy TG — approximation (barème cantonal réel progressif)", source_type="estimate",
        description="Taux de base impôt retrait capital — Thurgau.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.TI", value=0.065, unit="ratio", jurisdiction="TI",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LT TI", source_type="estimate",
        description="Taux de base impôt retrait capital — Ticino.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.VD", value=0.080, unit="ratio", jurisdiction="VD",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LI VD", source_type="estimate",
        description="Taux de base impôt retrait capital — Vaud.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.VS", value=0.060, unit="ratio", jurisdiction="VS",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LF VS", source_type="estimate",
        description="Taux de base impôt retrait capital — Valais.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.NE", value=0.070, unit="ratio", jurisdiction="NE",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LCdir NE", source_type="estimate",
        description="Taux de base impôt retrait capital — Neuchâtel.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.GE", value=0.075, unit="ratio", jurisdiction="GE",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LIPP GE", source_type="estimate",
        description="Taux de base impôt retrait capital — Genève.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    RegulatoryParameter(
        key="capital_tax.cantonal.JU", value=0.065, unit="ratio", jurisdiction="JU",
        effective_from=date(2025, 1, 1), source_url=_ESTV_CAPITAL_SIM_URL,
        source_title="LIFD art. 38 + LI JU", source_type="estimate",
        description="Taux de base impôt retrait capital — Jura.",
        reviewed_at=_REVIEWED,
        notes=_LEGACY_CAPITAL_NOTE,
    ),
    # ── AC durée des indemnités — barème LACI art. 27 (beads -4za) ──
    # L'audit -zaw a trouvé le mapping mois→jours FAUX côté mobile (18 mois
    # servaient 260 au lieu de 400) : les descriptions ci-dessous portent le
    # barème officiel exact, verrouillé des deux côtés.
    RegulatoryParameter(
        key="ac.days_12_months",
        value=260.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url="https://www.arbeit.swiss/secoalv/fr/home/menue/stellensuchende/arbeitslos-was-tun/taggelder.html",
        source_title="LACI art. 27 al. 2 let. a",
        source_type="law",
        description="Indemnités de chômage : 12 mois de cotisation donnent droit à 260 indemnités journalières.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.days_18_months",
        value=400.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url="https://www.arbeit.swiss/secoalv/fr/home/menue/stellensuchende/arbeitslos-was-tun/taggelder.html",
        source_title="LACI art. 27 al. 2 let. b",
        source_type="law",
        description="Indemnités de chômage : 18 mois de cotisation donnent droit à 400 indemnités journalières.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.days_22_months_senior",
        value=520.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url="https://www.arbeit.swiss/secoalv/fr/home/menue/stellensuchende/arbeitslos-was-tun/taggelder.html",
        source_title="LACI art. 27 al. 2 let. c",
        source_type="law",
        description="Indemnités de chômage : 22 mois de cotisation ET (âge >= 55 ans OU invalidité >= 40%) donnent droit à 520 indemnités journalières.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.days_under25_cap",
        value=200.0,
        unit="days",
        effective_from=date(2025, 1, 1),
        source_url="https://www.arbeit.swiss/secoalv/fr/home/menue/stellensuchende/arbeitslos-was-tun/taggelder.html",
        source_title="LACI art. 27 (plafond jeunes)",
        source_type="law",
        description="Plafond jeunes : les assurés de moins de 25 ans SANS obligation d'entretien sont limités à 200 indemnités journalières.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.senior_age_threshold",
        value=55.0,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url="https://www.arbeit.swiss/secoalv/fr/home/menue/stellensuchende/arbeitslos-was-tun/taggelder.html",
        source_title="LACI art. 27 al. 2 let. c",
        source_type="law",
        description="Âge charnière pour les 520 indemnités : 55 ans (combiné à 22 mois de cotisation).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="ac.enhanced_rate_threshold",
        value=3797.0,
        unit="CHF",
        effective_from=date(2025, 1, 1),
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/1205_1205_1205/fr",
        source_title="OACI art. 33 (seuil 70%/80%)",
        source_type="ordinance",
        description="Gain assuré mensuel sous lequel l'indemnité passe à 80% (au lieu de 70%). Le 80% s'applique AUSSI avec obligation d'entretien ou invalidité >= 40%, indépendamment du salaire.",
        reviewed_at=_REVIEWED,
    ),
    # ── Hypothèses de projection (beads MINT_nosync-7vx, verdict D -zaw) ──
    # HYPOTHÈSES PRODUIT, pas des paramètres légaux (source_type="estimate").
    # Enregistrées pour la provenance datée + la cohérence mobile (les
    # fallbacks Dart reg('projection.*') de social_insurance.dart doivent
    # rester identiques — verrou test_regulatory_registry).
    RegulatoryParameter(
        key="projection.avs_indexation_rate",
        value=0.01,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url="https://www.eak.admin.ch/fr/augmentation-des-rentes-avsai-de-29-pourcent-au-1er-janvier-2025",
        source_title="LAVS art. 33ter (indice mixte) — lissage produit",
        source_type="estimate",
        description="Indexation AVS supposée : 1%/an. Lissage long terme de l'indice mixte (dernière adaptation +2.9% au 1.1.2025, ≈1.45%/an lissé — cadence récente supérieure, à surveiller). Hypothèse produit DÉFENDABLE, pas une valeur légale.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="projection.inflation_rate",
        value=0.015,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url="https://www.snb.ch/en/snb-explained/price-stability",
        source_title="Cible BNS stabilité des prix 0-2% — hypothèse prudente-haute",
        source_type="estimate",
        description="Inflation supposée : 1.5%/an. Dans la bande BNS 0-2% ; ~2.5x la moyenne CH 1994-2024 (≈0.6%) — prudent-haut (surestimer l'inflation protège l'adéquation de la projection). Hypothèse produit, réviser annuellement.",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="projection.life_expectancy",
        value=87.0,
        unit="years",
        effective_from=date(2025, 1, 1),
        source_url="https://www.bfs.admin.ch/bfs/fr/home/statistiques/population/naissances-deces/esperance-vie.html",
        source_title="Tables de mortalité OFS — espérance de vie à 65 ans",
        source_type="estimate",
        description="Espérance de vie de planification : 87 ans. Espérance à 65 ans ≈ 85-89 ans (OFS) ; 87 = médiane prudente. Validée PR #968 (reference_ofs_mortality_table_2023.md).",
        reviewed_at=_REVIEWED,
    ),
    RegulatoryParameter(
        key="projection.safe_withdrawal_rate",
        value=0.04,
        unit="ratio",
        effective_from=date(2025, 1, 1),
        source_url="https://www.aaii.com/journal/199802/feature.pdf",
        source_title="Règle des 4% — Bengen 1994 / Trinity Study 1998",
        source_type="estimate",
        description="Taux de retrait supposé : 4%/an. Benchmark reconnu mais US-centré (horizon 30 ans) ; en contexte suisse 3-3.5% serait plus prudent — hypothèse ÉDITABLE par l'utilisateur, présentée en scénarios (NEVER #8), jamais comme garantie de durabilité.",
        reviewed_at=_REVIEWED,
    ),
]


# ══════════════════════════════════════════════════════════════════════════════
# Singleton Registry
# ══════════════════════════════════════════════════════════════════════════════


class RegulatoryRegistry:
    """In-memory registry of Swiss financial regulatory parameters.

    Singleton — use RegulatoryRegistry.instance() to access.

    Methods:
        get(key, jurisdiction, effective_on) → RegulatoryParameter
        get_value(key, jurisdiction, effective_on) → float
        get_all(category) → list[RegulatoryParameter]
        check_freshness(max_age_days) → list[RegulatoryParameter]
        keys() → list[str]
    """

    _instance: RegulatoryRegistry | None = None

    def __init__(self) -> None:
        self._params: dict[str, list[RegulatoryParameter]] = {}
        for p in _PARAMETERS:
            self._params.setdefault(p.key, []).append(p)

    @classmethod
    def instance(cls) -> RegulatoryRegistry:
        """Return the singleton instance (created on first call)."""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    @classmethod
    def _reset(cls) -> None:
        """Reset singleton (for testing only)."""
        cls._instance = None

    def get(
        self,
        key: str,
        jurisdiction: str = "CH",
        effective_on: Optional[date] = None,
    ) -> Optional[RegulatoryParameter]:
        """Look up a parameter by key, jurisdiction, and effective date.

        Args:
            key: Dotted parameter key (e.g. "pillar3a.max_with_lpp").
            jurisdiction: "CH" for federal, or canton code.
            effective_on: Date to check; None = today.

        Returns:
            The matching RegulatoryParameter, or None if not found.
        """
        candidates = self._params.get(key, [])
        check_date = effective_on or date.today()

        # Filter by jurisdiction and active date
        matches = [
            p for p in candidates
            if p.jurisdiction == jurisdiction and p.is_active(check_date)
        ]
        if not matches:
            # Fallback: try without date filter (for historical parameters)
            matches = [p for p in candidates if p.jurisdiction == jurisdiction]

        if not matches:
            return None

        # Return the most recently effective parameter
        return max(matches, key=lambda p: p.effective_from)

    def get_value(
        self,
        key: str,
        jurisdiction: str = "CH",
        effective_on: Optional[date] = None,
    ) -> Optional[float]:
        """Convenience: return just the value, or None if not found."""
        param = self.get(key, jurisdiction, effective_on)
        return param.value if param else None

    def get_all(self, category: Optional[str] = None) -> list[RegulatoryParameter]:
        """Return all parameters, optionally filtered by category prefix.

        Args:
            category: Key prefix filter (e.g. "avs", "lpp", "pillar3a").
                      None = return all parameters.

        Returns:
            List of matching parameters.
        """
        all_params = [p for params in self._params.values() for p in params]
        if category:
            prefix = category.lower() + "."
            return [p for p in all_params if p.key.lower().startswith(prefix)]
        return all_params

    def check_freshness(
        self,
        max_age_days: int = 90,
        as_of: Optional[date] = None,
    ) -> list[RegulatoryParameter]:
        """Return parameters that are stale (reviewed_at older than max_age_days).

        Args:
            max_age_days: Maximum number of days since last review.
            as_of: Date to evaluate freshness against. Defaults to today.

        Returns:
            List of stale parameters needing review.
        """
        stale = []
        for params in self._params.values():
            for p in params:
                if p.is_stale(max_age_days, on_date=as_of):
                    stale.append(p)
        return stale

    def keys(self) -> list[str]:
        """Return all unique parameter keys."""
        return sorted(self._params.keys())

    def count(self) -> int:
        """Return total number of parameters (including historical variants)."""
        return sum(len(v) for v in self._params.values())

    def version_hash(self, on_date: Optional[date] = None) -> str:
        """SHA-256 hex digest of the active parameter set at ``on_date``.

        Hotfix B 2026-05-17 — stamps every persisted projection with a
        deterministic fingerprint of the regulatory snapshot that produced
        it. Required by LSFin advice-documentation obligations so a future
        audit can reconstruct the inputs to a given projection.

        The hash is stable across runs given identical _PARAMETERS and
        identical ``on_date``. Adding a new parameter with a future
        ``effective_from`` does NOT change hashes for past dates (the new
        param is not ``is_active(past_date)``).

        Args:
            on_date: Date at which to evaluate the active parameter set;
                None means today.

        Returns:
            64-character SHA-256 hex digest.
        """
        import hashlib
        import json

        check_date = on_date or date.today()
        active: list[tuple[str, str, str, str]] = []
        for params in self._params.values():
            for p in params:
                if p.is_active(check_date):
                    active.append((
                        p.key,
                        p.jurisdiction,
                        p.effective_from.isoformat() if p.effective_from else "",
                        repr(p.value),  # handles floats, ints, and list values (avs.echelle44)
                    ))
        active.sort()
        canonical = json.dumps(active, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
