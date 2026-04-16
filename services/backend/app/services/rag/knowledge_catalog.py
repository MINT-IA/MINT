"""
Catalogue des sources de connaissance MINT — RAG v2.

Centralise toutes les sources documentaires utilisees par le pipeline RAG.
Organise par categorie (AVS, LPP, fiscal, cantonal…), avec references legales,
dates de mise a jour et couverture cantonale.

Sources legales:
    - LAVS (1er pilier), LPP (2e pilier), OPP3 (3e pilier)
    - LIFD (impot federal direct), LHID (harmonisation intercantonale)
    - LAMal (assurance maladie), CO (code des obligations)
    - FINMA circulaires

Sprint S67 — RAG v2 Knowledge Pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from enum import Enum
from typing import Optional


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------


class KnowledgeCategory(str, Enum):
    """Categories for knowledge sources."""

    AVS = "avs"
    LPP = "lpp"
    PILLAR_3A = "pillar_3a"
    FISCAL = "fiscal"
    MORTGAGE = "mortgage"
    INSURANCE = "insurance"
    FAMILY = "family"
    EMPLOYMENT = "employment"
    ESTATE = "estate"
    CANTONAL = "cantonal"


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class KnowledgeSource:
    """A single knowledge source in the catalog."""

    id: str
    title: str
    category: KnowledgeCategory
    legal_refs: list[str]
    last_updated: date
    language: str
    canton: Optional[str] = None  # None = federal, "VS" = cantonal


# ---------------------------------------------------------------------------
# Catalog data
# ---------------------------------------------------------------------------

_FEDERAL_SOURCES: list[KnowledgeSource] = [
    # -----------------------------------------------------------------------
    # AVS — 1er pilier
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="avs_rente_calcul_fr",
        title="Calcul de la rente AVS — methode et cotisations",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 21", "LAVS art. 29bis", "LAVS art. 30"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_rente_couple_fr",
        title="Rente AVS couple — plafonnement 150%",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 35", "LAVS art. 36"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_lacunes_rachat_fr",
        title="Lacunes AVS et possibilites de rachat",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 16 al. 3", "RAVS art. 42"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_anticipation_fr",
        title="Anticipation et ajournement de la rente AVS",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 40", "LAVS art. 39"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_taux_cotisation_fr",
        title="Taux de cotisation AVS 2025/2026",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 8", "LAVS art. 9"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_13e_rente_fr",
        title="13e rente AVS — entrée en vigueur 2026",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 40quater (nouveau)"],
        last_updated=date(2025, 6, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_indépendants_fr",
        title="AVS pour indépendants — barème dégressif",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 9", "RAVS art. 17 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_sans_activite_lucrative_fr",
        title="AVS — personnes sans activité lucrative",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 10", "RAVS art. 28"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_expat_totalisation_fr",
        title="AVS et expatriés — totalisation des périodes UE/AELE",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 18a", "Reg. UE 883/2004"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_rente_invalidite_fr",
        title="Rente AI et coordination AVS",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 20", "LAI art. 28"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_veuvage_fr",
        title="Rente de veuf/veuve et orphelins AVS",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 23 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="avs_cotisation_max_fr",
        title="Rente AVS maximale 2025/2026 — CHF 2'520/mois",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 34"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # LPP — 2e pilier
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="lpp_bonifications_vieillesse_fr",
        title="Bonifications de vieillesse LPP — 7/10/15/18%",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 16"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_taux_conversion_fr",
        title="Taux de conversion LPP 6.8% — calcul de la rente",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 14", "LPP art. 15"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_rachat_fr",
        title="Rachat LPP — avantages fiscaux et limites",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 79b", "LIFD art. 33 al. 1 let. d"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_capital_rente_fr",
        title="Capital vs rente LPP — arbitrage et taxation",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 37", "LIFD art. 38", "LIFD art. 22"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_retrait_anticipe_epl_fr",
        title="Encouragement à la propriété du logement — EPL",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 30a ss", "OPP2 art. 5"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_prestation_sortie_fr",
        title="Prestation de sortie — changement d'employeur",
        category=KnowledgeCategory.LPP,
        legal_refs=["LFLP art. 2 ss", "LPP art. 17"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_seuil_acces_fr",
        title="Seuil d'accès LPP 2025/2026 — CHF 22'680",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 7", "LPP art. 8"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_part_obligatoire_surobligatoire_fr",
        title="Part obligatoire vs surobligatoire LPP",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 62 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_invalidite_fr",
        title="Rente d'invalidité LPP et coordination LAA",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 23 ss", "LAA art. 18"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_divorce_partage_fr",
        title="Partage du 2e pilier en cas de divorce",
        category=KnowledgeCategory.LPP,
        legal_refs=["CC art. 122 ss", "LFLP art. 22"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_independants_fr",
        title="LPP pour indépendants — affiliation facultative",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 44 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="lpp_compte_de_libre_passage_fr",
        title="Compte de libre passage — gestion et rendements",
        category=KnowledgeCategory.LPP,
        legal_refs=["LFLP art. 4", "OLP art. 12"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Pilier 3a
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="3a_plafond_salarie_fr",
        title="Pilier 3a — plafond salarié 2025/2026 : CHF 7'258",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7", "LIFD art. 33 al. 1 let. e"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_plafond_independant_fr",
        title="Pilier 3a — plafond indépendant 2025/2026 : 20% / max CHF 36'288",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7 al. 1 let. b"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_retrait_fr",
        title="Retrait pilier 3a — conditions et taxation",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 3", "LIFD art. 38"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_retroactif_fr",
        title="Versements rétroactifs pilier 3a — règlement 2025",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7 al. 1bis (modif. 2025)"],
        last_updated=date(2025, 6, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_fractionnement_fr",
        title="Fractionnement des retraits 3a sur plusieurs années",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["LIFD art. 38", "OPP3 art. 3"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_investissement_fr",
        title="Pilier 3a en titres — rendement et risque",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 55 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_divorce_fr",
        title="Pilier 3a et divorce — partage",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["CC art. 122 al. 2", "OPP3 art. 3c"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="3a_achat_immobilier_fr",
        title="Pilier 3a et achat immobilier — retrait anticipé",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 3 al. 1 let. c"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Fiscal
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="fiscal_taux_marginal_fr",
        title="Taux marginal d'imposition — calcul et optimisation",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 36", "LHID art. 7"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_retrait_capital_fr",
        title="Imposition séparée du capital LPP — barème art. 38",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 38"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_deductions_fr",
        title="Déductions fiscales principales — vue d'ensemble",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 26 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_frontalier_fr",
        title="Imposition à la source — frontaliers et permis G",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 83 ss", "CDI France-Suisse"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_impot_fortune_fr",
        title="Impôt sur la fortune — cantons et seuils",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LHID art. 13 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_impot_succession_fr",
        title="Impôt sur les successions — cantons concernés",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LHID art. 7 (compétence cantonale)"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_revenu_rente_fr",
        title="Imposition des rentes — AVS, LPP, rentes viagères",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 22", "LIFD art. 23"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="fiscal_expat_fatca_fr",
        title="FATCA et double imposition — expatriés US en Suisse",
        category=KnowledgeCategory.FISCAL,
        legal_refs=["CDI USA-Suisse", "FATCA"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Hypothèque
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="mortgage_capacite_fr",
        title="Capacité hypothécaire — règle du tiers FINMA",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["FINMA circ. 2019/1", "CO art. 312 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="mortgage_amortissement_fr",
        title="Amortissement hypothécaire — 1re et 2e hypothèque",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["FINMA circ. 2019/1 ch. 61 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="mortgage_epl_fr",
        title="EPL — retrait ou mise en gage du 2e pilier pour l'immobilier",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["LPP art. 30a ss", "OPP2 art. 5"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="mortgage_renouvellement_fr",
        title="Renouvellement hypothécaire — taux fixe vs variable",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["CO art. 312 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="mortgage_deductions_fiscales_fr",
        title="Déductions fiscales liées à la propriété",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["LIFD art. 32 al. 2", "LIFD art. 33 al. 1 let. a"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="mortgage_valeur_locative_fr",
        title="Valeur locative — calcul et imposition",
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["LIFD art. 21 al. 1 let. b"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Assurance
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="insurance_lamal_fr",
        title="LAMal — franchise, primes et subsides cantonaux",
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAMal art. 61 ss", "LAMal art. 64 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="insurance_lca_vie_fr",
        title="Assurance-vie — différences avec le 3e pilier",
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LCA art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="insurance_laa_fr",
        title="LAA — couverture accidents et maladies professionnelles",
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAA art. 1 ss", "LAA art. 18"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="insurance_indemnite_journaliere_fr",
        title="Indemnités journalières — maladie et accident",
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAPG art. 1 ss", "CO art. 324a"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Famille
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="family_mariage_fr",
        title="Mariage — impacts fiscaux et patrimoniaux",
        category=KnowledgeCategory.FAMILY,
        legal_refs=["CC art. 159 ss", "LIFD art. 9"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="family_divorce_fr",
        title="Divorce — partage LPP, 3a, et AVS",
        category=KnowledgeCategory.FAMILY,
        legal_refs=["CC art. 122 ss", "LFLP art. 22", "LAVS art. 29sexies"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="family_concubinage_fr",
        title="Concubinage — risques patrimoniaux et protection",
        category=KnowledgeCategory.FAMILY,
        legal_refs=["CC art. 481 ss", "LPP art. 20a"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="family_naissance_fr",
        title="Naissance — allocations, congé parental, frais garde",
        category=KnowledgeCategory.FAMILY,
        legal_refs=["LAPG art. 16b ss", "LAFam art. 3"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="family_garde_enfants_deduction_fr",
        title="Déduction pour frais de garde — plafond 2025/2026",
        category=KnowledgeCategory.FAMILY,
        legal_refs=["LIFD art. 33 al. 3"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Emploi
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="employment_chomage_fr",
        title="Chômage — indemnités, durée, conditions",
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LACI art. 8 ss", "LACI art. 27"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="employment_independant_statut_fr",
        title="Statut d'indépendant — charges sociales et protection",
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LAVS art. 9 ss", "LPP art. 44"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="employment_retraite_anticipee_fr",
        title="Retraite anticipée — coûts et alternatives",
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LAVS art. 40", "LPP art. 13 al. 2"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="employment_travail_partiel_fr",
        title="Travail à temps partiel — impact AVS et LPP",
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LPP art. 8", "LAVS art. 8"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # -----------------------------------------------------------------------
    # Succession / Patrimoine
    # -----------------------------------------------------------------------
    KnowledgeSource(
        id="estate_heritage_fr",
        title="Héritage — réserves héréditaires et quotités disponibles",
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 470 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="estate_testament_fr",
        title="Testament — formes, contenu et limites",
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 498 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="estate_donation_fr",
        title="Donation — impôts et implications patrimoniales",
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 239 ss", "LHID art. 7 (compétence cantonale)"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="estate_pacte_successoral_fr",
        title="Pacte successoral — alternatives au testament",
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 512 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
]

# ---------------------------------------------------------------------------
# Cantonal sources — 11 major cantons
# ---------------------------------------------------------------------------

_CANTONAL_SOURCES: list[KnowledgeSource] = [
    # ZH
    KnowledgeSource(
        id="cantonal_zh_impot_fr",
        title="Canton de Zurich — impôt cantonal et communal",
        category=KnowledgeCategory.CANTONAL,
        canton="ZH",
        legal_refs=["StG ZH § 16 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_zh_lamal_fr",
        title="Canton de Zurich — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="ZH",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_zh_immobilier_fr",
        title="Canton de Zurich — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="ZH",
        legal_refs=["Code civil cantonal ZH"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # BE
    KnowledgeSource(
        id="cantonal_be_impot_fr",
        title="Canton de Berne — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="BE",
        legal_refs=["StG BE art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_be_lamal_fr",
        title="Canton de Berne — subsides LAMal et primes",
        category=KnowledgeCategory.CANTONAL,
        canton="BE",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_be_caisse_retraite_fr",
        title="Canton de Berne — caisse de pension cantonale (BPK)",
        category=KnowledgeCategory.CANTONAL,
        canton="BE",
        legal_refs=["LPP art. 11"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # VD
    KnowledgeSource(
        id="cantonal_vd_impot_fr",
        title="Canton de Vaud — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="VD",
        legal_refs=["LI VD art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_vd_lamal_fr",
        title="Canton de Vaud — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="VD",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_vd_immobilier_fr",
        title="Canton de Vaud — marché immobilier Lausanne/Romandie",
        category=KnowledgeCategory.CANTONAL,
        canton="VD",
        legal_refs=["Code civil cantonal VD"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # GE
    KnowledgeSource(
        id="cantonal_ge_impot_fr",
        title="Canton de Genève — impôt cantonal (taux élevé)",
        category=KnowledgeCategory.CANTONAL,
        canton="GE",
        legal_refs=["LIPM GE art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ge_lamal_fr",
        title="Canton de Genève — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="GE",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ge_immobilier_fr",
        title="Canton de Genève — marché immobilier (loyer le plus élevé)",
        category=KnowledgeCategory.CANTONAL,
        canton="GE",
        legal_refs=["Code civil cantonal GE"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # VS
    KnowledgeSource(
        id="cantonal_vs_impot_fr",
        title="Canton du Valais — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="VS",
        legal_refs=["LF VS art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_vs_lamal_fr",
        title="Canton du Valais — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="VS",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_vs_immobilier_fr",
        title="Canton du Valais — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="VS",
        legal_refs=["Code civil cantonal VS"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # TI
    KnowledgeSource(
        id="cantonal_ti_impot_fr",
        title="Canton du Tessin — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="TI",
        legal_refs=["LIFD TI art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ti_lamal_fr",
        title="Canton du Tessin — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="TI",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ti_frontalier_fr",
        title="Canton du Tessin — frontaliers et imposition source",
        category=KnowledgeCategory.CANTONAL,
        canton="TI",
        legal_refs=["CDI Italie-Suisse", "LIFD art. 83 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # ZG
    KnowledgeSource(
        id="cantonal_zg_impot_fr",
        title="Canton de Zoug — impôt cantonal (taux le plus bas)",
        category=KnowledgeCategory.CANTONAL,
        canton="ZG",
        legal_refs=["StG ZG § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_zg_domiciliation_fr",
        title="Canton de Zoug — optimisation fiscale par domiciliation",
        category=KnowledgeCategory.CANTONAL,
        canton="ZG",
        legal_refs=["LIFD art. 3 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_zg_immobilier_fr",
        title="Canton de Zoug — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="ZG",
        legal_refs=["Code civil cantonal ZG"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # BS
    KnowledgeSource(
        id="cantonal_bs_impot_fr",
        title="Canton de Bâle-Ville — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="BS",
        legal_refs=["StG BS § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_bs_lamal_fr",
        title="Canton de Bâle-Ville — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="BS",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_bs_frontalier_fr",
        title="Canton de Bâle-Ville — frontaliers Allemagne/France",
        category=KnowledgeCategory.CANTONAL,
        canton="BS",
        legal_refs=["CDI Allemagne-Suisse", "CDI France-Suisse"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # LU
    KnowledgeSource(
        id="cantonal_lu_impot_fr",
        title="Canton de Lucerne — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="LU",
        legal_refs=["StG LU § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_lu_lamal_fr",
        title="Canton de Lucerne — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="LU",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_lu_immobilier_fr",
        title="Canton de Lucerne — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="LU",
        legal_refs=["Code civil cantonal LU"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # AG
    KnowledgeSource(
        id="cantonal_ag_impot_fr",
        title="Canton d'Argovie — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="AG",
        legal_refs=["StG AG § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ag_lamal_fr",
        title="Canton d'Argovie — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="AG",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_ag_immobilier_fr",
        title="Canton d'Argovie — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="AG",
        legal_refs=["Code civil cantonal AG"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # SG
    KnowledgeSource(
        id="cantonal_sg_impot_fr",
        title="Canton de Saint-Gall — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="SG",
        legal_refs=["StG SG art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_sg_lamal_fr",
        title="Canton de Saint-Gall — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="SG",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_sg_immobilier_fr",
        title="Canton de Saint-Gall — marché immobilier",
        category=KnowledgeCategory.CANTONAL,
        canton="SG",
        legal_refs=["Code civil cantonal SG"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # FR
    KnowledgeSource(
        id="cantonal_fr_impot_fr",
        title="Canton de Fribourg — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="FR",
        legal_refs=["LIF FR art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    KnowledgeSource(
        id="cantonal_fr_lamal_fr",
        title="Canton de Fribourg — subsides LAMal",
        category=KnowledgeCategory.CANTONAL,
        canton="FR",
        legal_refs=["LAMal art. 65"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # SO
    KnowledgeSource(
        id="cantonal_so_impot_fr",
        title="Canton de Soleure — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="SO",
        legal_refs=["StG SO § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # GR
    KnowledgeSource(
        id="cantonal_gr_impot_fr",
        title="Canton des Grisons — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="GR",
        legal_refs=["StG GR art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # NE
    KnowledgeSource(
        id="cantonal_ne_impot_fr",
        title="Canton de Neuchâtel — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="NE",
        legal_refs=["LCdir NE art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # JU
    KnowledgeSource(
        id="cantonal_ju_impot_fr",
        title="Canton du Jura — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="JU",
        legal_refs=["LIRPP JU art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # UR
    KnowledgeSource(
        id="cantonal_ur_impot_fr",
        title="Canton d'Uri — impôt cantonal (taux bas)",
        category=KnowledgeCategory.CANTONAL,
        canton="UR",
        legal_refs=["StG UR § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # SZ
    KnowledgeSource(
        id="cantonal_sz_impot_fr",
        title="Canton de Schwytz — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="SZ",
        legal_refs=["StG SZ § 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
    # NW
    KnowledgeSource(
        id="cantonal_nw_impot_fr",
        title="Canton de Nidwald — impôt cantonal",
        category=KnowledgeCategory.CANTONAL,
        canton="NW",
        legal_refs=["StG NW art. 1 ss"],
        last_updated=date(2025, 1, 1),
        language="fr",
    ),
]

# Merge all sources
_ALL_SOURCES: list[KnowledgeSource] = _FEDERAL_SOURCES + _CANTONAL_SOURCES


# ---------------------------------------------------------------------------
# KnowledgeCatalog
# ---------------------------------------------------------------------------


class KnowledgeCatalog:
    """Central catalog of all MINT knowledge sources."""

    @staticmethod
    def all_sources() -> list[KnowledgeSource]:
        """Return all registered knowledge sources."""
        return list(_ALL_SOURCES)

    @staticmethod
    def by_category(cat: KnowledgeCategory) -> list[KnowledgeSource]:
        """Return sources filtered by category."""
        return [s for s in _ALL_SOURCES if s.category == cat]

    @staticmethod
    def by_canton(canton: str) -> list[KnowledgeSource]:
        """Return sources for a specific canton (case-insensitive)."""
        upper = canton.upper()
        return [s for s in _ALL_SOURCES if s.canton == upper]

    @staticmethod
    def federal_sources() -> list[KnowledgeSource]:
        """Return only federal (non-cantonal) sources."""
        return [s for s in _ALL_SOURCES if s.canton is None]

    @staticmethod
    def outdated(cutoff_date: date) -> list[KnowledgeSource]:
        """Return sources whose last_updated is before cutoff_date."""
        return [s for s in _ALL_SOURCES if s.last_updated < cutoff_date]

    @staticmethod
    def unique_cantons() -> list[str]:
        """Return list of cantons that have at least one source."""
        return sorted({s.canton for s in _ALL_SOURCES if s.canton is not None})
