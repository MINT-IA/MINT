"""
Service FAQ MINT — RAG v2.

Base de questions-réponses structurées couvrant les 10 parcours
Swiss Core Journeys. Chaque entrée est liée à une catégorie,
des références légales et un canton optionnel.

Toutes les réponses respectent:
- Ton éducatif (jamais prescriptif)
- Termes bannis absents (pas de "garanti", "optimal", etc.)
- Langage conditionnel ("pourrait", "envisager")
- Disclaimer éducatif (LSFin)

Sprint S67 — RAG v2 Knowledge Pipeline.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)

from app.services.rag.knowledge_catalog import KnowledgeCategory

# ---------------------------------------------------------------------------
# Compliance constants
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Ces FAQ sont fournies à titre éducatif uniquement. "
    "Elles ne constituent pas un conseil financier, fiscal ou juridique (LSFin). "
    "Pour une situation personnelle, consulte un·e spécialiste."
)

# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class FaqEntry:
    """A single FAQ entry."""

    id: str
    question: str
    answer: str
    category: KnowledgeCategory
    legal_refs: list[str] = field(default_factory=list)
    canton: Optional[str] = None
    tags: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# FAQ data — 50+ entries covering the 10 Swiss Core Journeys
# ---------------------------------------------------------------------------

_FAQ_DATA: list[FaqEntry] = [
    # =======================================================================
    # Journey 1 — Retraite & projection
    # =======================================================================
    FaqEntry(
        id="faq_retraite_age_legal",
        question="À quel âge puis-je prendre ma retraite en Suisse?",
        answer=(
            "En Suisse, l'âge légal de retraite AVS est actuellement de 65 ans pour les hommes "
            "et 65 ans pour les femmes (harmonisé depuis la réforme AVS 21). "
            "Il est possible d'anticiper la rente AVS de 1 à 2 ans (à partir de 63 ans), "
            "avec une réduction permanente de la rente. À l'inverse, l'ajournement jusqu'à 5 ans "
            "augmente le montant. Pour le 2e pilier (LPP), la retraite anticipée est possible "
            "dès 58 ans selon le règlement de ta caisse de pension."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 21", "LAVS art. 40", "LPP art. 13 al. 2"],
        tags=["retraite", "avs", "age", "anticipation"],
    ),
    FaqEntry(
        id="faq_rente_avs_montant",
        question="Quel sera le montant de ma rente AVS?",
        answer=(
            "La rente AVS dépend du nombre d'années de cotisation (44 ans = rente complète) "
            "et de ton revenu annuel moyen déterminant (RAMD). "
            "La rente minimale est de CHF 1'260/mois, la maximale de CHF 2'520/mois (2025/2026). "
            "Pour un couple, le total est plafonné à 150% de la rente maximale (CHF 3'780/mois). "
            "Tu peux consulter ton extrait de compte AVS sur le portail ahv-iv.ch "
            "pour obtenir une estimation personnalisée."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 34", "LAVS art. 35", "LAVS art. 29bis"],
        tags=["rente", "avs", "montant", "calcul"],
    ),
    FaqEntry(
        id="faq_taux_remplacement",
        question="Quel est le taux de remplacement à la retraite?",
        answer=(
            "En Suisse, l'objectif légal est un taux de remplacement de 60% du dernier salaire "
            "grâce à la combinaison AVS + LPP. En pratique, ce taux varie selon le salaire. "
            "Pour les revenus proches du salaire médian (~CHF 80'000/an), il peut dépasser 60%. "
            "Pour les salaires élevés (>CHF 150'000/an), il peut descendre sous 50% "
            "car le LPP obligatoire ne couvre que le salaire coordonné. "
            "Le pilier 3a permet de combler une partie du gap."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LPP art. 1 al. 2", "LAVS art. 1"],
        tags=["remplacement", "retraite", "objectif", "gap"],
    ),
    FaqEntry(
        id="faq_13e_rente_avs",
        question="Qu'est-ce que la 13e rente AVS et quand entre-t-elle en vigueur?",
        answer=(
            "La 13e rente AVS a été acceptée en votation populaire en mars 2024. "
            "Elle correspond à un versement supplémentaire équivalent à un mois de rente "
            "par année. L'entrée en vigueur est prévue pour le 1er janvier 2026. "
            "Le montant exact sera versé en décembre ou réparti sur l'année selon "
            "les modalités définies par le Conseil fédéral."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 40quater (nouveau)", "Votation 3.3.2024"],
        tags=["13e rente", "avs", "2026", "nouveau"],
    ),
    FaqEntry(
        id="faq_lacunes_avs",
        question="Comment combler des lacunes dans mes cotisations AVS?",
        answer=(
            "Des lacunes AVS se créent pour des années sans activité lucrative ou sans résidence "
            "en Suisse. Tu peux les combler par des cotisations rétroactives dans un délai "
            "de 5 ans (art. 16 al. 3 LAVS). Au-delà, les lacunes sont définitives. "
            "Les cotisations volontaires sont possibles pour les personnes résidant à l'étranger "
            "(LAVS art. 2). Un rachat de lacunes est particulièrement avantageux si les années "
            "manquantes correspondent à des années à faible revenu."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 16 al. 3", "LAVS art. 2", "RAVS art. 42"],
        tags=["lacunes", "avs", "rachat", "cotisations"],
    ),
    # =======================================================================
    # Journey 2 — LPP & caisse de pension
    # =======================================================================
    FaqEntry(
        id="faq_lpp_rachat_avantage",
        question="Un rachat LPP est-il toujours avantageux?",
        answer=(
            "Un rachat LPP peut offrir un double avantage: déduction fiscale immédiate du montant "
            "racheté (LIFD art. 33), et amélioration de la rente future. "
            "Cependant, plusieurs points méritent attention: "
            "1) Les sommes rachetées ne peuvent pas être retirées en capital dans les 3 ans "
            "qui suivent (art. 79b al. 3 LPP); "
            "2) L'avantage fiscal dépend de ton taux marginal d'imposition; "
            "3) Si une retraite anticipée est planifiée, le délai de blocage s'applique. "
            "Il convient d'évaluer la situation globale avant d'agir."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 79b", "LIFD art. 33 al. 1 let. d"],
        tags=["rachat", "lpp", "fiscal", "avantage"],
    ),
    FaqEntry(
        id="faq_lpp_taux_conversion",
        question="Que signifie le taux de conversion LPP de 6.8%?",
        answer=(
            "Le taux de conversion LPP obligatoire est de 6.8% (art. 14 LPP). "
            "Cela signifie que pour CHF 100'000 d'avoir de vieillesse obligatoire, "
            "tu reçois CHF 6'800/an (soit CHF 567/mois) de rente viagère. "
            "Ce taux s'applique uniquement à la part obligatoire. "
            "La part surobligatoire peut avoir un taux de conversion inférieur "
            "fixé par le règlement de ta caisse."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 14", "LPP art. 15"],
        tags=["taux", "conversion", "rente", "lpp"],
    ),
    FaqEntry(
        id="faq_lpp_capital_vs_rente",
        question="Vaut-il mieux prendre le capital LPP ou la rente?",
        answer=(
            "Ce choix dépend de plusieurs facteurs: espérance de vie, situation familiale, "
            "autres revenus, tolérance au risque. "
            "La rente offre une sécurité à vie, mais s'éteint au décès (selon règlement). "
            "Le capital permet une flexibilité maximale mais implique une gestion autonome "
            "et une taxation séparée au retrait (LIFD art. 38, environ 1/5 du taux ordinaire). "
            "Une option mixte est souvent possible (partiel en rente, partiel en capital). "
            "Cette décision est irréversible — il est utile d'en discuter avec un·e spécialiste."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 37", "LIFD art. 38", "LIFD art. 22"],
        tags=["capital", "rente", "lpp", "arbitrage", "choix"],
    ),
    FaqEntry(
        id="faq_lpp_epl",
        question="Puis-je utiliser mon 2e pilier pour acheter un logement?",
        answer=(
            "Oui, via l'encouragement à la propriété du logement (EPL, LPP art. 30a ss). "
            "Deux options: retrait anticipé (taxé séparément, art. 38 LIFD) ou mise en gage "
            "(permet d'obtenir un crédit sans impôt immédiat). "
            "Conditions: résidence principale uniquement, montant minimum CHF 20'000 (OPP2 art. 5). "
            "Le retrait EPL réduit la rente future et peut créer une lacune fiscale. "
            "En cas de mise en gage, les fonds restent dans la caisse et continuent à fructifier."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 30a ss", "OPP2 art. 5", "LIFD art. 38"],
        tags=["epl", "logement", "lpp", "retrait", "gage"],
    ),
    FaqEntry(
        id="faq_lpp_divorce",
        question="Que se passe-t-il avec mon 2e pilier en cas de divorce?",
        answer=(
            "En cas de divorce, les avoirs de prévoyance professionnelle accumulés "
            "pendant le mariage sont partagés à parts égales entre les époux (CC art. 122). "
            "Cela concerne l'avoir au moment du mariage jusqu'à celui du divorce. "
            "Le partage est obligatoire, sauf convention contraire approuvée par le juge. "
            "Pour les rentes déjà en cours, des règles spécifiques s'appliquent (CC art. 124)."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["CC art. 122 ss", "LFLP art. 22", "CC art. 124"],
        tags=["divorce", "lpp", "partage", "mariage"],
    ),
    FaqEntry(
        id="faq_lpp_libre_passage",
        question="Que se passe-t-il avec mon LPP si je perds mon emploi?",
        answer=(
            "En cas de départ (chômage, expatriation, travail indépendant), "
            "ta prestation de sortie LPP est transférée sur un compte ou une police de libre passage. "
            "Ces fonds continuent à être investis et sont exonérés d'impôt. "
            "Le compte de libre passage peut être retiré à la retraite, ou réintégré dans "
            "une nouvelle caisse lors d'un prochain emploi. "
            "Attention: en cas de résidence à l'étranger hors UE/AELE, "
            "un retrait anticipé est possible mais soumis à taxation."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LFLP art. 2 ss", "LFLP art. 4", "OLP art. 12"],
        tags=["libre passage", "lpp", "chômage", "emploi"],
    ),
    # =======================================================================
    # Journey 3 — Pilier 3a
    # =======================================================================
    FaqEntry(
        id="faq_3a_plafond_2025",
        question="Quel est le plafond de versement pilier 3a en 2025/2026 ?",
        answer=(
            "Pour 2025/2026, les plafonds du pilier 3a sont : "
            "- Salarié avec LPP: CHF 7'258/an "
            "- Indépendant sans LPP: 20% du revenu net, maximum CHF 36'288/an. "
            "Les versements sont déductibles du revenu imposable (LIFD art. 33 al. 1 let. e). "
            "Il est possible d'ouvrir plusieurs comptes 3a pour optimiser les retraits futurs "
            "(fractionnement pour limiter l'impôt)."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7", "LIFD art. 33 al. 1 let. e"],
        tags=["3a", "plafond", "2025", "déduction"],
    ),
    FaqEntry(
        id="faq_3a_retrait_conditions",
        question="Quand puis-je retirer mon pilier 3a?",
        answer=(
            "Le pilier 3a peut être retiré dans les cas suivants (OPP3 art. 3): "
            "- 5 ans avant l'âge de référence AVS (dès 60 ans pour les hommes ; 59 ans pour les femmes nées avant 1964, 60 ans dès 1964) "
            "- Achat d'un logement principal (EPL) "
            "- Début d'une activité indépendante "
            "- Départ définitif de Suisse (si hors UE/AELE) "
            "- Invalidité permanente ou décès. "
            "Le retrait est taxé séparément au 1/5 du taux ordinaire (LIFD art. 38). "
            "Il est conseillé d'étaler les retraits sur plusieurs années."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 3", "LIFD art. 38"],
        tags=["3a", "retrait", "conditions", "taxation"],
    ),
    FaqEntry(
        id="faq_3a_retroactif",
        question="Puis-je verser le 3a rétroactivement pour les années passées?",
        answer=(
            "Depuis 2025, une nouvelle règlementation permet des versements rétroactifs "
            "pour les années où le plafond n'a pas été atteint, selon des conditions précises "
            "(OPP3 art. 7 al. 1bis). "
            "Cette mesure est destinée principalement aux personnes ayant eu une interruption "
            "d'activité (maternité, maladie, etc.). "
            "Les montants rétroactifs sont également déductibles fiscalement pour l'année "
            "de versement. Consulte les modalités auprès de ta fondation 3a."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7 al. 1bis (modif. 2025)"],
        tags=["3a", "rétroactif", "2025", "lacunes"],
    ),
    FaqEntry(
        id="faq_3a_titres_vs_compte",
        question="Vaut-il mieux un 3a en compte ou en titres?",
        answer=(
            "Un 3a en compte offre une sécurité totale du capital mais un rendement faible "
            "(proche du taux d'intérêt de référence). "
            "Un 3a en titres (fonds d'actions) offre un potentiel de rendement supérieur "
            "sur le long terme mais avec des fluctuations. "
            "Pour un horizon de 10 ans ou plus, les titres pourraient offrir un meilleur "
            "rendement net d'inflation. Pour moins de 5 ans, le compte est plus sûr. "
            "La part en actions peut aller jusqu'à 100% dans certains fonds (OPP3 art. 55)."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 55 ss"],
        tags=["3a", "titres", "compte", "rendement", "risque"],
    ),
    FaqEntry(
        id="faq_3a_plusieurs_comptes",
        question="Pourquoi ouvrir plusieurs comptes pilier 3a?",
        answer=(
            "Ouvrir plusieurs comptes 3a (jusqu'à 5 est courant) permet d'étaler les retraits "
            "sur plusieurs années. Comme le retrait est taxé séparément, "
            "fractionner sur 5 ans permet de réduire la taxation totale "
            "(application plusieurs fois du taux le plus bas). "
            "Par exemple, retirer CHF 50'000/an pendant 5 ans est souvent moins taxé "
            "que retirer CHF 250'000 en une seule fois."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["LIFD art. 38", "OPP3 art. 3"],
        tags=["3a", "comptes multiples", "fractionnement", "optimisation fiscale"],
    ),
    # =======================================================================
    # Journey 4 — Fiscal
    # =======================================================================
    FaqEntry(
        id="faq_deduction_3a_impot",
        question="De combien puis-je réduire mes impôts grâce au pilier 3a?",
        answer=(
            "La déduction 3a réduit ton revenu imposable, pas directement l'impôt. "
            "L'économie dépend de ton taux marginal d'imposition. "
            "Exemple: pour un contribuable à Zurich avec un revenu de 100'000 CHF, "
            "un versement de CHF 7'258 (plafond 2025/2026) peut générer une économie fiscale "
            "de CHF 2'000 à CHF 2'800 selon canton et commune. "
            "L'impact est plus fort pour les hauts revenus (taux marginal élevé) "
            "et dans les cantons à taux élevé comme GE ou VD."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 33 al. 1 let. e", "LHID art. 7"],
        tags=["3a", "déduction", "impôt", "économie fiscale"],
    ),
    FaqEntry(
        id="faq_impot_rente_avs",
        question="La rente AVS est-elle imposable?",
        answer=(
            "Oui, la rente AVS est entièrement imposable comme revenu ordinaire (LIFD art. 22). "
            "Elle s'ajoute aux autres revenus (rente LPP, fortune, etc.) pour le calcul "
            "de l'impôt sur le revenu. "
            "À noter: les rentes LPP sont également imposables à 100% (LIFD art. 22). "
            "En revanche, un capital retiré du LPP est taxé séparément, une seule fois, "
            "au retrait (LIFD art. 38) et non annuellement."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 22", "LIFD art. 38"],
        tags=["avs", "rente", "imposition", "revenu"],
    ),
    FaqEntry(
        id="faq_impot_fortune",
        question="Qu'est-ce que l'impôt sur la fortune et comment est-il calculé?",
        answer=(
            "L'impôt sur la fortune est prélevé annuellement sur la valeur nette de tes actifs "
            "(immobilier, comptes, titres, 2e pilier sous certaines conditions) moins les dettes. "
            "Il est uniquement cantonal (pas fédéral). "
            "Les taux varient fortement selon le canton: très bas à Zoug (~0.5%) "
            "contre plus élevé à Genève (~0.8-1%). "
            "La fortune nette inférieure à CHF 100'000-200'000 est souvent exonérée."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LHID art. 13 ss"],
        tags=["fortune", "impôt", "cantonal", "actifs"],
    ),
    FaqEntry(
        id="faq_deduction_hypotheque",
        question="Puis-je déduire les intérêts de mon hypothèque?",
        answer=(
            "Oui, les intérêts passifs sur une hypothèque sont déductibles du revenu imposable "
            "(LIFD art. 33 al. 1 let. a). "
            "Cependant, les intérêts déductibles sont limités au rendement brut de la fortune "
            "plus CHF 50'000. "
            "Par ailleurs, si tu es propriétaire, la valeur locative de ton bien "
            "est ajoutée à ton revenu imposable (LIFD art. 21). "
            "L'impact net dépend de l'hypothèque restante et de la valeur locative."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIFD art. 33 al. 1 let. a", "LIFD art. 21 al. 1 let. b"],
        tags=["hypothèque", "intérêts", "déduction", "immobilier"],
    ),
    FaqEntry(
        id="faq_impot_succession",
        question="Y a-t-il un impôt sur les successions en Suisse?",
        answer=(
            "L'impôt sur les successions est uniquement cantonal (il n'existe pas au niveau fédéral). "
            "La grande majorité des cantons exonèrent les héritiers en ligne directe "
            "(enfants, petits-enfants, conjoint·e). "
            "Exceptions notables: VD et NE taxent certaines successions même en ligne directe. "
            "Les autres héritiers (frères/sœurs, partenaires non mariés) sont souvent taxés. "
            "Il est conseillé de vérifier les règles du canton de résidence du défunt."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LHID art. 7 (compétence cantonale exclusivement)"],
        tags=["succession", "héritage", "impôt", "cantonal"],
    ),
    FaqEntry(
        id="faq_canton_zg_fiscalite",
        question="Pourquoi Zoug est-il considéré comme un paradis fiscal?",
        answer=(
            "Le canton de Zoug a le taux d'imposition cantonal+communal le plus bas de Suisse "
            "pour les personnes physiques (~22-23% de taux effectif). "
            "Plusieurs raisons: coefficient fiscal cantonal très bas, "
            "impôt sur la fortune très modéré (~0.5%), et pas d'impôt sur les successions "
            "en ligne directe. "
            "Ces avantages ont attiré de nombreuses holdings internationales et résidents aisés. "
            "Un déménagement à Zoug peut représenter une économie significative "
            "pour les hauts revenus."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["StG ZG § 1 ss", "LHID art. 1"],
        canton="ZG",
        tags=["zoug", "fiscalité", "canton", "optimisation"],
    ),
    # =======================================================================
    # Journey 5 — Hypothèque & immobilier
    # =======================================================================
    FaqEntry(
        id="faq_mortgage_capacite",
        question="Comment calculer ma capacité hypothécaire?",
        answer=(
            "La capacité hypothécaire suisse repose sur la règle du tiers (FINMA circ. 2019/1): "
            "les charges annuelles (intérêt théorique 5% + amortissement 1% + frais 1%) "
            "ne doivent pas dépasser 1/3 du revenu brut. "
            "Exemple: Pour un bien à CHF 1'000'000, les charges annuelles = "
            "CHF 50'000 (intérêts) + CHF 10'000 (amort.) + CHF 10'000 (frais) = CHF 70'000. "
            "Il faut donc un revenu brut d'au moins CHF 210'000/an. "
            "En plus, apport propre minimum de 20% (max 10% du 2e pilier)."
        ),
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["FINMA circ. 2019/1"],
        tags=["hypothèque", "capacité", "tiers", "calcul"],
    ),
    FaqEntry(
        id="faq_mortgage_taux_fixe_variable",
        question="Taux fixe ou SARON pour mon hypothèque?",
        answer=(
            "L'hypothèque à taux fixe offre une prévisibilité totale des charges sur la durée "
            "choisie (1 à 15 ans). Elle est recommandée en période de taux bas "
            "pour sécuriser les conditions actuelles. "
            "Le SARON (anciennement Libor) fluctue avec les taux du marché. "
            "En période de taux élevés, il peut descendre, mais comporte un risque "
            "de hausse. Une stratégie mixte (part fixe + part SARON) est possible. "
            "Le choix dépend de ta tolérance au risque et de tes projections de revenus."
        ),
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["CO art. 312 ss"],
        tags=["hypothèque", "taux fixe", "saron", "stratégie"],
    ),
    FaqEntry(
        id="faq_mortgage_amortissement",
        question="Dois-je amortir mon hypothèque rapidement?",
        answer=(
            "L'amortissement indirect via le pilier 3a est souvent plus avantageux "
            "que l'amortissement direct. "
            "Avec l'amortissement indirect: tu gardes une dette élevée (déduction des intérêts), "
            "tu verses dans ton 3a (déduction fiscale), et au retrait, tu rembourses l'hypothèque. "
            "L'obligation légale: rembourser jusqu'à 65% de la valeur du bien en 15 ans "
            "pour la 2e hypothèque. La 1re hypothèque (66,67% de la valeur) n'est pas "
            "soumise à obligation d'amortissement selon les normes ASB."
        ),
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["FINMA circ. 2019/1 ch. 61 ss"],
        tags=["amortissement", "hypothèque", "3a", "indirect"],
    ),
    FaqEntry(
        id="faq_mortgage_epl_lpp",
        question="Puis-je utiliser mon LPP pour financer mon logement?",
        answer=(
            "Oui, l'encouragement à la propriété (EPL) permet d'utiliser le 2e pilier "
            "pour financer un logement principal. "
            "Deux options: retrait anticipé (taxé comme un capital LPP, art. 38 LIFD) "
            "ou mise en gage (pas d'impôt immédiat, crédit hypothécaire). "
            "Montant minimum pour un retrait: CHF 20'000. "
            "Attention: le retrait réduit ta future rente de retraite. "
            "En cas de vente du bien, les fonds doivent être réintégrés dans la caisse."
        ),
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["LPP art. 30a ss", "OPP2 art. 5"],
        tags=["epl", "lpp", "logement", "financement"],
    ),
    FaqEntry(
        id="faq_mortgage_location_propriete",
        question="Vaut-il mieux louer ou acheter en Suisse?",
        answer=(
            "En Suisse, le marché locatif est très développé (~58% de locataires). "
            "Acheter est avantageux si: tu restes plus de 10 ans, les taux sont bas, "
            "et tu peux constituer l'apport (20%). "
            "Louer est souvent plus flexible et préserve la liquidité du capital. "
            "Sur le plan fiscal, la propriété implique la valeur locative imposable, "
            "mais permet des déductions (intérêts, entretien). "
            "Dans les grandes villes (GE, ZH), l'achat est très coûteux et la rentabilité "
            "locative est souvent meilleure."
        ),
        category=KnowledgeCategory.MORTGAGE,
        legal_refs=["LIFD art. 21", "FINMA circ. 2019/1"],
        tags=["location", "propriété", "choix", "immobilier"],
    ),
    # =======================================================================
    # Journey 6 — Famille & événements de vie
    # =======================================================================
    FaqEntry(
        id="faq_mariage_impots",
        question="Mon mariage va-t-il changer ma situation fiscale?",
        answer=(
            "En Suisse, les époux sont imposés ensemble (imposition commune, LIFD art. 9). "
            "Le barème pour couples mariés est différent du barème des célibataires. "
            "Pour deux revenus similaires, la pression fiscale combinée peut être "
            "parfois supérieure à celle de deux célibataires (pénalité du mariage). "
            "À l'inverse, pour un seul revenu dans le ménage, le barème marié peut être "
            "plus avantageux. Des déductions supplémentaires pour couples avec enfants s'appliquent."
        ),
        category=KnowledgeCategory.FAMILY,
        legal_refs=["LIFD art. 9", "CC art. 159 ss"],
        tags=["mariage", "impôts", "couple", "barème"],
    ),
    FaqEntry(
        id="faq_concubinage_risques",
        question="Quels sont les risques financiers du concubinage?",
        answer=(
            "En Suisse, le concubinage n'est pas reconnu légalement comme le mariage. "
            "Risques principaux: "
            "1) Pas de droit à une rente de veuf/veuve AVS en cas de décès (LAVS art. 23 = uniquement pour mariés) "
            "2) Pas de partage automatique du LPP sauf désignation explicite (LPP art. 20a) "
            "3) Pas de déduction fiscale commune "
            "4) Pas de droit à l'héritage sans testament "
            "5) Impôt sur les successions élevé pour non-mariés dans de nombreux cantons. "
            "Un testament et une clause de bénéficiaire LPP sont des précautions importantes."
        ),
        category=KnowledgeCategory.FAMILY,
        legal_refs=["LAVS art. 23", "LPP art. 20a", "CC art. 481 ss"],
        tags=["concubinage", "risques", "décès", "protection"],
    ),
    FaqEntry(
        id="faq_divorce_patrimoine",
        question="Comment se passe le partage du patrimoine lors d'un divorce?",
        answer=(
            "En Suisse, le régime matrimonial par défaut est la participation aux acquêts (CC art. 196). "
            "Au divorce, les acquêts (biens acquis pendant le mariage) sont partagés à 50/50. "
            "Les biens propres (héritages, donations, biens antérieurs) restent à leur propriétaire. "
            "En plus du patrimoine, le LPP accumulé pendant le mariage est partagé (CC art. 122). "
            "Pour les époux ayant opté pour un autre régime (séparation de biens), "
            "les règles de partage sont différentes."
        ),
        category=KnowledgeCategory.FAMILY,
        legal_refs=["CC art. 196 ss", "CC art. 122 ss"],
        tags=["divorce", "partage", "patrimoine", "régime matrimonial"],
    ),
    FaqEntry(
        id="faq_naissance_conge_parental",
        question="À quelles aides financières ai-je droit à la naissance d'un enfant?",
        answer=(
            "À la naissance, plusieurs aides sont disponibles: "
            "- Congé maternité: 14 semaines à 80% du salaire, max CHF 220/jour (LAPG art. 16b) "
            "- Congé paternité: 2 semaines à 80% du salaire (depuis 2021) "
            "- Allocations familiales: CHF 215-265/mois selon canton et âge de l'enfant "
            "- Subsides LAMal possibles selon revenus "
            "- Déduction fiscale pour frais de garde (max selon LIFD art. 33 al. 3). "
            "Certains cantons (VD, GE) ont des congés parentaux plus étendus."
        ),
        category=KnowledgeCategory.FAMILY,
        legal_refs=["LAPG art. 16b ss", "LAFam art. 3", "LIFD art. 33 al. 3"],
        tags=["naissance", "congé", "allocations", "famille"],
    ),
    # =======================================================================
    # Journey 7 — Emploi & transitions professionnelles
    # =======================================================================
    FaqEntry(
        id="faq_independant_charges",
        question="Quelles charges sociales dois-je payer en tant qu'indépendant?",
        answer=(
            "En tant qu'indépendant·e, tu paies l'intégralité des charges AVS/AI/APG "
            "(environ 10% du revenu, barème dégressif sous CHF 57'400, LAVS art. 9). "
            "Tu n'es pas soumis·e au LPP obligatoire mais peux t'y affilier volontairement "
            "ou maximiser le 3a (jusqu'à CHF 36'288/an). "
            "L'assurance chômage (LACI) n'est pas obligatoire pour les indépendants. "
            "La prévoyance invalidité via une assurance privée est fortement recommandée "
            "car la protection LAI de base peut être insuffisante."
        ),
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LAVS art. 9 ss", "LPP art. 44", "LACI art. 2"],
        tags=["indépendant", "charges sociales", "avs", "prévoyance"],
    ),
    FaqEntry(
        id="faq_chomage_indemnite",
        question="Combien touche-t-on au chômage en Suisse?",
        answer=(
            "Les indemnités journalières de chômage sont de 70% du dernier salaire assuré "
            "(80% avec enfants ou proche d'une invalidité). "
            "Le salaire assuré est plafonné à CHF 148'200/an (gain maximal assuré LAA). "
            "La durée d'indemnisation dépend de la durée de cotisation: "
            "max 520 jours (2 ans) pour une cotisation de 18+ mois sur les 2 dernières années. "
            "Il faut avoir cotisé au moins 12 mois dans les 2 ans précédant le chômage (LACI art. 8)."
        ),
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LACI art. 8 ss", "LACI art. 27", "LACI art. 23"],
        tags=["chômage", "indemnité", "durée", "conditions"],
    ),
    FaqEntry(
        id="faq_retraite_anticipee_couts",
        question="Quels sont les coûts d'une retraite anticipée?",
        answer=(
            "Une retraite anticipée a plusieurs coûts: "
            "1) AVS: anticipation = réduction permanente de 6.8% par année (max 2 ans) "
            "2) LPP: capital plus faible (moins d'années de cotisation) et parfois taux de conversion réduit "
            "3) Années sans cotisation = lacunes AVS et LPP "
            "4) Plus longue période à financer avec le même capital "
            "Il faut généralement disposer d'un capital 3a/LPP/épargne suffisant "
            "pour couvrir les années de bridge. Une simulation sur MINT peut modéliser "
            "l'impact selon ton profil."
        ),
        category=KnowledgeCategory.EMPLOYMENT,
        legal_refs=["LAVS art. 40", "LPP art. 13 al. 2"],
        tags=["retraite anticipée", "coûts", "avs", "lpp"],
    ),
    FaqEntry(
        id="faq_temps_partiel_lpp",
        question="Mon travail à temps partiel affecte-t-il ma prévoyance LPP?",
        answer=(
            "Oui. Le salaire coordonné LPP est calculé comme: "
            "salaire annuel - déduction de coordination (CHF 26'460 en 2025/2026). "
            "Pour un temps partiel à 50%, si ton salaire est de CHF 40'000, "
            "ton salaire coordonné LPP est CHF 13'540 seulement. "
            "Les bonifications de vieillesse (art. 16 LPP) sont calculées sur ce montant réduit. "
            "Certains employeurs appliquent une déduction de coordination réduite au prorata "
            "du temps de travail — renseigne-toi auprès de ta caisse."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 8", "LPP art. 16"],
        tags=["temps partiel", "lpp", "coordonné", "impact"],
    ),
    # =======================================================================
    # Journey 8 — Succession & patrimoine
    # =======================================================================
    FaqEntry(
        id="faq_heritage_reserves",
        question="Quelle part de mon patrimoine puis-je léguer librement?",
        answer=(
            "Le CC suisse (art. 470) prévoit des réserves héréditaires pour certains héritiers: "
            "- Enfants: 1/2 de la part légale "
            "- Conjoint·e/partenaire enregistré·e: 1/4 de la part légale. "
            "La quotité disponible (ce que tu peux donner librement) représente "
            "le solde après déduction des réserves. "
            "Exemple: avec 2 enfants, ta quotité disponible est 1/2 de ton patrimoine. "
            "Note: depuis 2023, les réserves héréditaires ont été réduites (réforme CC)."
        ),
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 470 ss", "CC art. 196 ss (réforme 2023)"],
        tags=["héritage", "réserves", "testament", "succession"],
    ),
    FaqEntry(
        id="faq_testament_formes",
        question="Comment rédiger un testament valable en Suisse?",
        answer=(
            "En Suisse, un testament peut prendre deux formes principales: "
            "1) Testament olographe: entièrement manuscrit, daté et signé (CC art. 505). "
            "Pas besoin de notaire, mais risque de contestation si mal rédigé. "
            "2) Testament public: rédigé devant notaire avec 2 témoins (CC art. 499). "
            "Plus solide juridiquement. "
            "Un testament rédigé sur ordinateur sans signature manuscrite n'est PAS valable. "
            "Il est conseillé de le déposer auprès du registre cantonal ou d'une banque."
        ),
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 498 ss", "CC art. 505"],
        tags=["testament", "formes", "rédaction", "valide"],
    ),
    FaqEntry(
        id="faq_donation_impot",
        question="Puis-je donner de l'argent à mes enfants sans payer d'impôts?",
        answer=(
            "Les donations sont soumises à l'impôt dans certains cantons "
            "(pas à l'IFD — impôt fédéral direct). "
            "La plupart des cantons exonèrent les donations directes aux enfants. "
            "Exceptions: VD taxe les donations importantes, même aux enfants. "
            "Pour les autres héritiers (partenaires non mariés, neveux, amis), "
            "l'impôt sur les donations peut être élevé. "
            "Une donation à titre d'avancement d'hoirie peut réduire les tensions successorales."
        ),
        category=KnowledgeCategory.ESTATE,
        legal_refs=["CC art. 239 ss", "LHID art. 7"],
        tags=["donation", "enfants", "impôt", "succession"],
    ),
    # =======================================================================
    # Journey 9 — Assurance & protection
    # =======================================================================
    FaqEntry(
        id="faq_lamal_franchise",
        question="Comment choisir ma franchise LAMal?",
        answer=(
            "La franchise LAMal est la part des frais médicaux annuels à ta charge "
            "avant que l'assurance intervienne. "
            "Franchises disponibles: 300 (obligatoire), 500, 1'000, 1'500, 2'000, 2'500 CHF. "
            "Plus la franchise est élevée, plus la prime mensuelle est basse. "
            "Si tu vas rarement chez le médecin, une franchise élevée est souvent avantageuse. "
            "À noter: en plus de la franchise, la quote-part est de 10% des frais "
            "jusqu'à un maximum de CHF 700/an (adultes)."
        ),
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAMal art. 61 ss", "LAMal art. 64 ss"],
        tags=["lamal", "franchise", "prime", "santé"],
    ),
    FaqEntry(
        id="faq_subsides_lamal",
        question="Ai-je droit à des subsides pour l'assurance maladie?",
        answer=(
            "Les subsides LAMal sont des réductions de prime accordées par les cantons "
            "aux personnes à revenu modeste. "
            "Critères: dépendent du canton (revenu imposable, fortune, situation familiale). "
            "Depuis 2024, les cantons ont l'obligation de couvrir au moins les primes "
            "des ménages dont les primes dépassent 10% du revenu. "
            "Demande à formuler auprès de l'office cantonal compétent. "
            "Les subsides peuvent représenter plusieurs centaines de CHF/mois."
        ),
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAMal art. 65", "LAMal art. 65a (modif. 2024)"],
        tags=["subsides", "lamal", "prime", "aide"],
    ),
    FaqEntry(
        id="faq_assurance_vie",
        question="Quelle est la différence entre assurance-vie et pilier 3a?",
        answer=(
            "Le pilier 3a est une épargne retraite déductible fiscalement (OPP3), "
            "réglementée et avec des avantages fiscaux clairs. "
            "L'assurance-vie (LCA) est un contrat d'assurance qui peut inclure "
            "une composante épargne, mais aussi une couverture en cas de décès/invalidité. "
            "Une assurance-vie 3a (assurance liée) combine les deux. "
            "Avantage de l'assurance-vie: protection décès/invalidité intégrée. "
            "Inconvénient: souplesse limitée, frais souvent plus élevés qu'un compte 3a bancaire."
        ),
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LCA art. 1 ss", "OPP3 art. 1 ss"],
        tags=["assurance-vie", "3a", "différence", "protection"],
    ),
    # =======================================================================
    # Journey 10 — Expatriés & mobilité internationale
    # =======================================================================
    FaqEntry(
        id="faq_expat_avs",
        question="Comment fonctionne l'AVS pour les expatriés?",
        answer=(
            "Si tu viens d'un pays UE/AELE, les périodes de cotisation dans ces pays "
            "peuvent être totalisées avec tes années en Suisse pour atteindre les 44 ans "
            "nécessaires à une rente complète (Règlement UE 883/2004). "
            "Pour les pays hors UE/AELE avec convention (certains pays africains, Turquie, etc.), "
            "des règles spécifiques s'appliquent. "
            "Sans convention, les lacunes de cotisation peuvent être comblées "
            "rétroactivement dans un délai de 5 ans seulement."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 18a", "Reg. UE 883/2004"],
        tags=["expatrié", "avs", "totalisation", "périodes"],
    ),
    FaqEntry(
        id="faq_expat_us_fatca",
        question="Je suis citoyen·ne américain·e en Suisse — y a-t-il des implications fiscales?",
        answer=(
            "Les citoyen·ne·s américain·e·s sont soumis·es à l'impôt US sur leur revenu mondial, "
            "même en résidant en Suisse (principe de la citizenship-based taxation). "
            "La convention de double imposition CH-USA (CDI) évite en principe une double imposition. "
            "FATCA oblige les banques suisses à déclarer les comptes de résidents US à l'IRS. "
            "Le pilier 3a peut ne pas bénéficier du même traitement fiscal aux USA "
            "que chez les Suisses. La situation FATCA/PFIC est complexe: "
            "un·e spécialiste en fiscalité internationale est fortement recommandé·e."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["CDI USA-Suisse", "FATCA", "LIFD art. 3 ss"],
        tags=["expat", "usa", "fatca", "double imposition"],
    ),
    FaqEntry(
        id="faq_expat_depart_lpp",
        question="Que faire de mon LPP si je quitte définitivement la Suisse?",
        answer=(
            "En cas de départ définitif vers un pays hors UE/AELE, "
            "tu peux retirer l'intégralité de ton avoir LPP. "
            "Le retrait est soumis à un impôt à la source en Suisse (LIFD art. 96 ss). "
            "Pour les pays UE/AELE, seule la part surobligatoire peut être retirée; "
            "la part obligatoire reste bloquée jusqu'à l'âge de retraite. "
            "En cas de retour futur en Suisse, des règles de réintégration s'appliquent."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LFLP art. 25f", "LIFD art. 96 ss"],
        tags=["expat", "départ", "lpp", "retrait"],
    ),
    FaqEntry(
        id="faq_frontalier_imposition",
        question="Comment suis-je imposé·e en tant que frontalier·ère?",
        answer=(
            "Les frontaliers sont en général imposés à la source dans le canton de travail "
            "(LIFD art. 83 ss), selon des taux d'imposition à la source. "
            "Des accords spécifiques existent avec la France, l'Allemagne et l'Italie. "
            "Exemple France-Suisse: les frontaliers résidant dans les cantons limitrophes "
            "sont imposés en France (CDI révisée 2023). "
            "Les droits aux rentes AVS et LPP s'accumulent normalement si tu cotises en Suisse."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["CDI France-Suisse", "LIFD art. 83 ss"],
        tags=["frontalier", "imposition", "source", "international"],
    ),
    FaqEntry(
        id="faq_retrait_lpp_surobligatoire",
        question="Puis-je retirer uniquement la part surobligatoire de mon LPP?",
        answer=(
            "En principe, le capital LPP peut être retiré en totalité sous certaines conditions. "
            "Si ton règlement de caisse le permet, il est possible de demander uniquement "
            "la part surobligatoire en capital et de conserver la part obligatoire en rente. "
            "Cette stratégie peut être fiscalement avantageuse dans certains cas. "
            "La distinction obligatoire/surobligatoire est indiquée dans ton certificat de prévoyance annuel."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 37 al. 4", "LPP art. 62 ss"],
        tags=["lpp", "surobligatoire", "retrait partiel", "stratégie"],
    ),
    # =======================================================================
    # Additional FAQs — general / cross-category
    # =======================================================================
    FaqEntry(
        id="faq_taux_interet_lpp",
        question="Quel est le taux d'intérêt minimal légal applicable à mon LPP ?",
        answer=(
            "Le taux d'intérêt minimal LPP est fixé chaque année par le Conseil fédéral. "
            "Pour 2025/2026, il est de 1.25% sur la part obligatoire (LPP art. 15). "
            "Certaines caisses offrent un taux supérieur sur la part surobligatoire "
            "(ton certificat annuel indique le taux appliqué). "
            "Ce taux ne doit pas être confondu avec le taux de conversion de 6.8% "
            "qui détermine la rente à la retraite."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 15", "LPP art. 12 (taux minimal)"],
        tags=["lpp", "taux intérêt", "minimal", "avoir vieillesse"],
    ),
    FaqEntry(
        id="faq_simulation_retraite",
        question="Comment estimer mes revenus à la retraite?",
        answer=(
            "Pour estimer tes revenus de retraite en Suisse, tu peux: "
            "1) Commander un extrait de compte AVS sur ahv-iv.ch "
            "2) Consulter ton certificat LPP annuel (projection à 65 ans) "
            "3) Additionner les potentiels retraits 3a "
            "4) Ajouter tout revenu complémentaire (loyers, rente étrangère, etc.). "
            "Un outil de simulation comme MINT permet de modéliser différents scénarios "
            "(anticipation, rachat LPP, capital vs rente) avec une estimation de la confiance."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LPP art. 24", "LAVS art. 30"],
        tags=["simulation", "retraite", "estimation", "revenus"],
    ),
    FaqEntry(
        id="faq_lacunes_avs_couts",
        question="Combien coûte le rachat d'une année de lacune AVS?",
        answer=(
            "Le coût d'un rachat de lacune AVS dépend du revenu déterminant. "
            "Pour les salariés, la cotisation annuelle est de 10.6% du salaire AVS. "
            "Pour une personne ayant un revenu moyen (~CHF 80'000/an), "
            "racheter une lacune coûte environ CHF 4'200-5'000. "
            "Cependant, l'avantage en rente représente 1/44e de la différence entre rente max et min, "
            "soit environ CHF 28/mois de rente supplémentaire, à vie. "
            "Ce rachat peut se rentabiliser en moins de 15 ans selon l'espérance de vie."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 8", "LAVS art. 16 al. 3"],
        tags=["lacunes", "avs", "rachat", "coût"],
    ),
    FaqEntry(
        id="faq_couple_retraite_strategie",
        question="Quelle stratégie de retraite pour un couple en Suisse?",
        answer=(
            "Pour un couple, plusieurs optimisations sont possibles: "
            "1) Décaler les retraites de 1 à 3 ans pour maximiser les rentes AVS individuelles "
            "2) Coordonner les retraits 3a pour étaler la taxation "
            "3) Évaluer si le capital LPP d'un époux est mieux géré ensemble "
            "4) Anticiper le plafonnement à 150% de la rente AVS maximale. "
            "La rente de couple est plafonnée à CHF 3'780/mois (2025/2026). "
            "Il est utile de modéliser plusieurs scénarios avant de décider."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 35", "LAVS art. 40", "LPP art. 37"],
        tags=["couple", "retraite", "stratégie", "coordination"],
    ),
    FaqEntry(
        id="faq_3a_employeur",
        question="Mon employeur peut-il verser dans mon pilier 3a?",
        answer=(
            "Non — contrairement au LPP (2e pilier), le pilier 3a est strictement personnel. "
            "Seul le titulaire du compte peut y effectuer des versements. "
            "L'employeur ne peut pas contribuer directement à ton 3a. "
            "En revanche, certains employeurs proposent des versements supplémentaires "
            "dans le 2e pilier (plan surobligatoire), qui peuvent être plus avantageux "
            "que le 3a pour les hauts revenus."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7"],
        tags=["3a", "employeur", "versement", "règles"],
    ),
    FaqEntry(
        id="faq_scpi_swiss",
        question="Peut-on investir dans l'immobilier indirect en Suisse?",
        answer=(
            "En Suisse, l'investissement immobilier indirect est possible via: "
            "1) Fonds de placement immobiliers (cotés ou non-cotés) "
            "2) Actions de sociétés immobilières (ex: PSP Swiss Property, Swiss Prime Site) "
            "3) Fondations de placement LPP (uniquement pour les institutionnels). "
            "Les fonds immobiliers suisses cotés bénéficient souvent d'une exonération "
            "d'impôt anticipé sur les distributions (selon statut du fonds). "
            "Ils permettent d'investir dans l'immobilier suisse sans les contraintes "
            "de la propriété directe (hypothèque, entretien, valeur locative)."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LPCC art. 1 ss", "LIFD art. 21"],
        tags=["immobilier indirect", "fonds", "investissement", "suisse"],
    ),
    FaqEntry(
        id="faq_avs_expatriee_cotisations_volontaires",
        question="Puis-je cotiser volontairement à l'AVS depuis l'étranger?",
        answer=(
            "Oui, les ressortissants suisses résidant dans un pays sans convention avec la Suisse "
            "peuvent cotiser volontairement à l'AVS (LAVS art. 2). "
            "Les conditions: avoir cotisé à l'AVS avant le départ, "
            "et résider dans un pays hors UE/AELE. "
            "Les cotisations volontaires permettent de maintenir une couverture AVS "
            "et d'éviter des lacunes. Les taux sont fixés selon le revenu ou la fortune."
        ),
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 2", "RAVS art. 140 ss"],
        tags=["expat", "avs", "cotisations volontaires", "étranger"],
    ),
    FaqEntry(
        id="faq_rente_invalidite",
        question="Quelle protection en cas d'invalidité?",
        answer=(
            "En Suisse, la protection en cas d'invalidité est assurée par 3 piliers: "
            "1) AI (assurance invalidité fédérale): rente AI proportionnelle au taux d'invalidité, "
            "versée si le taux dépasse 40% (LAI art. 28) "
            "2) LPP: rente d'invalidité LPP si invalidité > 40% (LPP art. 23 ss) "
            "3) Assurances privées: indemnités journalières, assurance-vie avec couverture invalidité. "
            "Pour les indépendants, la protection de base AI peut être très limitée "
            "— une assurance complémentaire est souvent nécessaire."
        ),
        category=KnowledgeCategory.INSURANCE,
        legal_refs=["LAI art. 28", "LPP art. 23 ss", "LAA art. 18"],
        tags=["invalidité", "ai", "protection", "rente"],
    ),
    FaqEntry(
        id="faq_pilier_3b",
        question="Qu'est-ce que le pilier 3b?",
        answer=(
            "Le pilier 3b est la prévoyance libre (non réglementée). "
            "Il comprend tout ce qui ne rentre pas dans le pilier 3a: "
            "épargne bancaire ordinaire, actions, immobilier personnel, "
            "assurance-vie non liée (3b), etc. "
            "Contrairement au 3a, les versements dans le 3b ne sont pas déductibles fiscalement "
            "(sauf assurances-vie dans certains cantons). "
            "Le 3b offre une totale flexibilité mais sans avantage fiscal immédiat."
        ),
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 (ne s'applique pas au 3b)"],
        tags=["3b", "prévoyance libre", "épargne", "différence 3a"],
    ),
    FaqEntry(
        id="faq_impot_dividendes",
        question="Comment sont imposés les dividendes en Suisse?",
        answer=(
            "Les dividendes d'actions suisses sont soumis à l'impôt anticipé (35%) "
            "prélevé à la source par la société (LIA art. 4). "
            "Ce montant peut être récupéré dans la déclaration fiscale si tu résides en Suisse. "
            "Les dividendes sont intégrés dans le revenu imposable (LIFD art. 20). "
            "Pour les actions dans un 3a, les dividendes sont exonérés pendant la durée du placement. "
            "Les dividendes d'actions étrangères peuvent être soumis à un impôt retenu "
            "à l'étranger, partiellement récupérable selon la convention fiscale applicable."
        ),
        category=KnowledgeCategory.FISCAL,
        legal_refs=["LIA art. 4", "LIFD art. 20"],
        tags=["dividendes", "impôt anticipé", "actions", "imposition"],
    ),
    FaqEntry(
        id="faq_rachat_lpp_blocage_3_ans",
        question="Pourquoi ne puis-je pas retirer mon LPP dans les 3 ans après un rachat?",
        answer=(
            "La loi LPP (art. 79b al. 3) prévoit que les sommes rachetées dans la caisse "
            "ne peuvent pas être versées en capital pendant les 3 ans qui suivent le rachat. "
            "Cette règle vise à éviter que des contribuables rachètent uniquement "
            "pour bénéficier de la déduction fiscale puis retirent immédiatement le capital. "
            "Si tu prévois de prendre ta retraite dans moins de 3 ans, "
            "un rachat LPP suivi d'un retrait en capital n'est donc pas possible."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 79b al. 3"],
        tags=["rachat", "lpp", "blocage", "3 ans", "règle"],
    ),
    FaqEntry(
        id="faq_caisse_pension_rendement",
        question="Comment évaluer la performance de ma caisse de pension?",
        answer=(
            "Critères à vérifier dans ton certificat de prévoyance annuel: "
            "1) Taux d'intérêt crédité sur l'avoir vieillesse (vs taux minimal LPP) "
            "2) Degré de couverture (doit être > 100%) "
            "3) Taux de conversion appliqué à la retraite "
            "4) Réserves de fluctuation (indique la solidité de la caisse) "
            "5) Allocation stratégique (part en actions vs obligations). "
            "Les rapports annuels des caisses sont publics. "
            "Une caisse bien gérée devrait offrir un taux supérieur au minimum légal."
        ),
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 50 ss", "OPP2 art. 44"],
        tags=["caisse de pension", "rendement", "évaluation", "certificat"],
    ),
]


# ---------------------------------------------------------------------------
# FaqService
# ---------------------------------------------------------------------------


class FaqService:
    """Structured FAQ service for the MINT RAG pipeline."""

    @staticmethod
    def all_faqs() -> list[FaqEntry]:
        """Return all FAQ entries."""
        return list(_FAQ_DATA)

    @staticmethod
    def by_category(cat: KnowledgeCategory) -> list[FaqEntry]:
        """Return FAQs filtered by category."""
        return [f for f in _FAQ_DATA if f.category == cat]

    @staticmethod
    def by_canton(canton: str) -> list[FaqEntry]:
        """Return FAQs specific to a canton (case-insensitive)."""
        upper = canton.upper()
        return [f for f in _FAQ_DATA if f.canton == upper]

    @staticmethod
    def search(query: str) -> list[FaqEntry]:
        """
        Search FAQs by keyword in question, answer, or tags.

        Case-insensitive. Returns FAQs with at least one match.

        Args:
            query: Search string (words separated by spaces).

        Returns:
            List of matching FaqEntry objects, ordered by relevance (match count).
        """
        if not query or not query.strip():
            return []

        terms = [t.lower() for t in re.split(r"\s+", query.strip()) if t]
        scored: list[tuple[int, FaqEntry]] = []

        for faq in _FAQ_DATA:
            searchable = (
                faq.question.lower()
                + " " + faq.answer.lower()
                + " " + " ".join(faq.tags).lower()
            )
            score = sum(1 for term in terms if term in searchable)
            if score > 0:
                scored.append((score, faq))

        scored.sort(key=lambda x: x[0], reverse=True)

        # P3-A readiness metric: track recall quality for vector store trigger.
        # When top_score / n_terms < 0.5 on > 20% of queries, migrate to vector.
        n_terms = max(len(terms), 1)
        top_score = scored[0][0] / n_terms if scored else 0.0
        logger.info(
            "faq_search query=%r results=%d top_score=%.2f n_terms=%d",
            query[:50],
            len(scored),
            top_score,
            n_terms,
        )

        return [faq for _, faq in scored]

    @staticmethod
    def by_id(faq_id: str) -> FaqEntry | None:
        """Return a single FAQ by its ID, or None if not found."""
        for faq in _FAQ_DATA:
            if faq.id == faq_id:
                return faq
        return None

    @staticmethod
    def by_tag(tag: str) -> list[FaqEntry]:
        """Return FAQs that have a given tag (case-insensitive)."""
        lower = tag.lower()
        return [f for f in _FAQ_DATA if lower in [t.lower() for t in f.tags]]
