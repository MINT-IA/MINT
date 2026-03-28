"""
Simulateur d'impact financier du mariage en Suisse (LIFD, CC, LAVS, LPP).

Calcule la comparaison fiscale celibataire vs marie, simule les regimes
matrimoniaux et estime les rentes de survivant.

Sources:
    - LIFD art. 9 al. 1 (imposition commune des epoux)
    - LIFD art. 33 al. 2 (deduction double activite: CHF 2'800)
    - LIFD art. 35 al. 1 let. c (deduction personnes mariees: CHF 2'700)
    - LIFD art. 33 al. 1 let. d (deduction assurances maries: CHF 3'600)
    - LIFD art. 36 (baremes IFD)
    - LAVS art. 29sexies (bonifications pour taches educatives / splitting)
    - LPP art. 19 (rente de veuve/veuf = 60% de la rente assuree)
    - LAVS art. 24 (rente de survivant AVS = 80% de la rente du defunt)
    - CC art. 181 (participation aux acquets — regime ordinaire)
    - CC art. 221 (communaute de biens)
    - CC art. 247 (separation de biens)

Sprint S22 — Evenements de vie : Famille.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ton canton, de ta situation personnelle et du bareme communal. "
    "Ne constitue pas un conseil fiscal ou juridique (LSFin/LLCA). "
    "Consulte un ou une specialiste."
)

# ---------------------------------------------------------------------------
# Constantes fiscales mariage (2025/2026)
# ---------------------------------------------------------------------------

# Deduction double activite (LIFD art. 33 al. 2)
DEDUCTION_DOUBLE_ACTIVITE = 2_800.0  # CHF

# Deduction personnes mariees (LIFD art. 35 al. 1 let. c)
DEDUCTION_MARIES = 2_700.0  # CHF

# Deduction assurances — maries (LIFD art. 33 al. 1 let. d)
DEDUCTION_ASSURANCES_MARIES = 3_600.0  # CHF
# Deduction assurances — celibataires (LIFD art. 33 al. 1 let. d)
DEDUCTION_ASSURANCES_CELIBATAIRE = 1_800.0  # CHF

# Deduction par enfant (LIFD art. 35 al. 1 let. a)
DEDUCTION_PAR_ENFANT = 6_700.0  # CHF

# ---------------------------------------------------------------------------
# Baremes IFD simplifies (LIFD art. 36, 2024)
# Format: [(seuil_cumulatif_CHF, taux_marginal_pourcent)]
# ---------------------------------------------------------------------------

IFD_BRACKETS_SINGLE = [
    (14_500, 0.0), (31_600, 0.77), (41_400, 0.88), (55_200, 2.64),
    (72_500, 2.97), (78_100, 5.94), (103_600, 6.60), (134_600, 8.80),
    (176_000, 11.00), (755_200, 13.20), (float("inf"), 11.50),
]

IFD_BRACKETS_MARRIED = [
    (28_300, 0.0), (50_900, 1.0), (58_400, 2.0), (75_300, 3.0),
    (90_300, 4.0), (103_400, 5.0), (114_700, 6.0), (124_200, 7.0),
    (131_700, 8.0), (137_300, 9.0), (141_200, 10.0), (143_100, 11.0),
    (145_000, 12.0), (895_900, 13.0), (float("inf"), 11.50),
]

# Multiplicateur cantonal estime (canton -> addon rate)
# Source: estimations swiss-brain basees sur les taux des chefs-lieux, 2024
CANTON_MULTIPLIERS = {
    "ZH": 1.30, "BE": 1.36, "LU": 1.25, "BS": 1.33,
    "VD": 1.38, "GE": 1.41, "ZG": 1.22, "FR": 1.37,
    "VS": 1.34, "NE": 1.39, "JU": 1.40, "SZ": 1.24,
    "AG": 1.30, "SG": 1.30, "TI": 1.35, "GR": 1.32,
    "TG": 1.28, "BL": 1.33, "AR": 1.28, "AI": 1.26,
    "GL": 1.30, "SH": 1.32, "OW": 1.25, "NW": 1.24,
    "UR": 1.28, "SO": 1.32,
}
_DEFAULT_CANTON_MULTIPLIER = 1.32

# ---------------------------------------------------------------------------
# Rente de survivant (LAVS art. 24, LPP art. 19)
# ---------------------------------------------------------------------------

# AVS: rente de veuve/veuf = 80% de la rente du defunt (LAVS art. 24)
AVS_SURVIVOR_FACTOR = 0.80

# LPP: rente de veuve/veuf = 60% de la rente assuree (LPP art. 19)
LPP_SURVIVOR_FACTOR = 0.60


def _calculate_ifd_tax(revenu_imposable: float, brackets: list) -> float:
    """Calcule l'impot federal direct (IFD) par tranches progressives.

    Source: LIFD art. 36.
    """
    if revenu_imposable <= 0:
        return 0.0
    tax = 0.0
    prev_threshold = 0.0
    for threshold, rate_pct in brackets:
        if revenu_imposable <= prev_threshold:
            break
        taxable_in_bracket = min(revenu_imposable, threshold) - prev_threshold
        if taxable_in_bracket > 0:
            tax += taxable_in_bracket * (rate_pct / 100)
        prev_threshold = threshold
    return round(tax, 2)


def _estimate_total_tax(revenu_imposable: float, brackets: list, canton: str) -> float:
    """Estime l'impot total (IFD + cantonal + communal).

    Utilise le multiplicateur cantonal comme approximation.
    """
    ifd = _calculate_ifd_tax(revenu_imposable, brackets)
    multiplier = CANTON_MULTIPLIERS.get(canton, _DEFAULT_CANTON_MULTIPLIER)
    return round(ifd * multiplier, 2)


@dataclass
class FiscalComparison:
    """Resultat de la comparaison fiscale celibataire vs marie."""
    impot_celibataires_total: float      # Impot total en tant que 2 celibataires
    impot_maries_total: float            # Impot total en tant que couple marie
    difference: float                     # Negatif = bonus, positif = penalite
    est_penalite_mariage: bool           # True si les maries paient plus
    detail_celibataire_1: float          # Impot celibataire personne 1
    detail_celibataire_2: float          # Impot celibataire personne 2
    revenus_cumules: float               # Revenu total combine
    deductions_mariage: float            # Total des deductions specifiques au mariage
    chiffre_choc: str                    # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class RegimeMatrimonial:
    """Resultat de la simulation de regime matrimonial."""
    regime: str                          # "participation_acquets", "separation_biens", "communaute_biens"
    description: str                     # Description pedagogique du regime
    part_conjoint_1: float               # Part patrimoine conjoint 1 en cas de dissolution
    part_conjoint_2: float               # Part patrimoine conjoint 2 en cas de dissolution
    patrimoine_total: float              # Patrimoine total du couple
    explication: str                     # Explication de la repartition
    sources: List[str] = field(default_factory=list)


@dataclass
class SurvivorBenefits:
    """Resultat de l'estimation des rentes de survivant."""
    rente_survivant_avs_mensuelle: float     # Rente AVS survivant mensuelle
    rente_survivant_avs_annuelle: float      # Rente AVS survivant annuelle
    rente_survivant_lpp_mensuelle: float     # Rente LPP survivant mensuelle
    rente_survivant_lpp_annuelle: float      # Rente LPP survivant annuelle
    total_survivant_mensuel: float           # Total mensuel
    total_survivant_annuel: float            # Total annuel
    chiffre_choc: str                        # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class ChecklistMariage:
    """Checklist actionable pour les futurs maries."""
    items: List[str]                       # Liste des actions recommandees
    priorite_haute: List[str]              # Actions urgentes
    priorite_moyenne: List[str]            # Actions importantes
    priorite_basse: List[str]              # Actions de confort
    chiffre_choc: str                      # Chiffre choc pedagogique
    disclaimer: str                        # Avertissement legal
    sources: List[str] = field(default_factory=list)


class MariageService:
    """Simulateur d'impact financier du mariage en droit suisse.

    Regles cles:
    - Imposition commune obligatoire pour les couples maries (LIFD art. 9 al. 1)
    - Deduction double activite: CHF 2'800 (LIFD art. 33 al. 2)
    - Deduction maries: CHF 2'700 (LIFD art. 35 al. 1 let. c)
    - Deduction assurances maries: CHF 3'600 vs CHF 1'800 celibataire (LIFD art. 33 al. 1 let. d)
    - Penalite du mariage: quand 2 revenus combines = taux marginal plus eleve
    - AVS splitting 50/50 des annees de cotisation (LAVS art. 29sexies)
    - LPP rente de survivant = 60% (LPP art. 19)
    """

    def compare_fiscal_impact(
        self,
        revenu_1: float,
        revenu_2: float,
        canton: str = "ZH",
        enfants: int = 0,
    ) -> FiscalComparison:
        """Compare l'impot en tant que 2 celibataires vs couple marie.

        Args:
            revenu_1: Revenu imposable annuel de la personne 1 (CHF).
            revenu_2: Revenu imposable annuel de la personne 2 (CHF).
            canton: Code canton (2 lettres).
            enfants: Nombre d'enfants a charge.

        Returns:
            FiscalComparison avec le detail de la comparaison.
        """
        # --- Celibataires ---
        # Simplification: child deduction split 50/50 between unmarried parents.
        # In reality, LIFD art. 35 assigns the deduction to the custodial parent.
        # This is acceptable for educational comparison (marriage vs single scenario).
        deduction_enfant_chacun = DEDUCTION_PAR_ENFANT * enfants / 2 if enfants > 0 else 0
        ri_1_single = max(0, revenu_1 - DEDUCTION_ASSURANCES_CELIBATAIRE - deduction_enfant_chacun)
        ri_2_single = max(0, revenu_2 - DEDUCTION_ASSURANCES_CELIBATAIRE - deduction_enfant_chacun)

        impot_1 = _estimate_total_tax(ri_1_single, IFD_BRACKETS_SINGLE, canton)
        impot_2 = _estimate_total_tax(ri_2_single, IFD_BRACKETS_SINGLE, canton)
        total_celibataires = round(impot_1 + impot_2, 2)

        # --- Maries ---
        revenu_combine = revenu_1 + revenu_2
        deductions_mariage = DEDUCTION_MARIES + DEDUCTION_ASSURANCES_MARIES
        if revenu_1 > 0 and revenu_2 > 0:
            deductions_mariage += DEDUCTION_DOUBLE_ACTIVITE  # double activite
        deductions_mariage += DEDUCTION_PAR_ENFANT * enfants

        ri_marie = max(0, revenu_combine - deductions_mariage)
        total_maries = _estimate_total_tax(ri_marie, IFD_BRACKETS_MARRIED, canton)

        difference = round(total_maries - total_celibataires, 2)
        est_penalite = difference > 0

        if est_penalite:
            chiffre_choc = (
                f"Penalite du mariage : tu paierais ~CHF {abs(difference):,.0f}/an "
                f"de plus en impots en te mariant. Revenus combines: CHF {revenu_combine:,.0f}"
            )
        else:
            chiffre_choc = (
                f"Bonus du mariage : tu economiserais ~CHF {abs(difference):,.0f}/an "
                f"d'impots en te mariant. Revenus combines: CHF {revenu_combine:,.0f}"
            )

        sources = [
            "LIFD art. 9 al. 1 (imposition commune des epoux)",
            "LIFD art. 33 al. 2 (deduction double activite: CHF 2'800)",
            "LIFD art. 35 al. 1 let. c (deduction maries: CHF 2'700)",
            "LIFD art. 33 al. 1 let. d (deduction assurances: CHF 3'600 maries)",
            "LIFD art. 36 (baremes IFD celibataire/marie)",
        ]

        return FiscalComparison(
            impot_celibataires_total=total_celibataires,
            impot_maries_total=total_maries,
            difference=difference,
            est_penalite_mariage=est_penalite,
            detail_celibataire_1=impot_1,
            detail_celibataire_2=impot_2,
            revenus_cumules=revenu_combine,
            deductions_mariage=deductions_mariage,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def simulate_regime_matrimonial(
        self,
        patrimoine_1: float,
        patrimoine_2: float,
        regime: str = "participation_acquets",
    ) -> RegimeMatrimonial:
        """Simule la repartition du patrimoine selon le regime matrimonial.

        Regimes supportes:
        - participation_acquets (defaut, CC art. 181): chacun garde ses
          biens propres + partage 50/50 des acquets
        - separation_biens (CC art. 247): chacun garde tout
        - communaute_biens (CC art. 221): tout est mis en commun, partage 50/50

        Args:
            patrimoine_1: Patrimoine total de la personne 1 (CHF).
            patrimoine_2: Patrimoine total de la personne 2 (CHF).
            regime: Type de regime matrimonial.

        Returns:
            RegimeMatrimonial avec la repartition.
        """
        total = patrimoine_1 + patrimoine_2

        if regime == "separation_biens":
            part_1 = patrimoine_1
            part_2 = patrimoine_2
            description = (
                "Separation de biens (CC art. 247) : chaque conjoint conserve "
                "l'integralite de son patrimoine. Aucune mise en commun."
            )
            explication = (
                f"Conjoint 1 garde CHF {patrimoine_1:,.0f}. "
                f"Conjoint 2 garde CHF {patrimoine_2:,.0f}. "
                f"Pas de partage."
            )
            sources = ["CC art. 247 (separation de biens)"]

        elif regime == "communaute_biens":
            part_1 = total / 2
            part_2 = total / 2
            description = (
                "Communaute de biens (CC art. 221) : tous les biens sont mis en "
                "commun et partages a parts egales (50/50) en cas de dissolution."
            )
            explication = (
                f"Patrimoine total CHF {total:,.0f} divise en 2 = "
                f"CHF {part_1:,.0f} chacun."
            )
            sources = ["CC art. 221 (communaute de biens)"]

        else:  # participation_acquets (defaut)
            # Simplification: assumes all patrimoine is acquêts (gains during
            # marriage). True "biens propres" (pre-marriage assets + inheritances
            # + donations, CC art. 198) distinction requires pre-marriage asset
            # data not available in current profile. The 50/50 split on total
            # patrimoine is therefore a worst-case educational scenario.
            # CC art. 196-220 (participation aux acquêts).
            part_1 = total / 2
            part_2 = total / 2
            description = (
                "Participation aux acquets (CC art. 196-220) : regime ordinaire par "
                "defaut. En theorie, chacun garde ses biens propres (herites, recus par "
                "donation, apportes avant le mariage — CC art. 198) et seuls les acquets "
                "(biens acquis pendant le mariage) sont partages 50/50."
            )
            explication = (
                f"Simplification: MINT ne dispose pas de la repartition biens propres/acquets. "
                f"L'estimation considere la totalite du patrimoine "
                f"(CHF {total:,.0f}) comme acquets et le divise en 2 = "
                f"CHF {part_1:,.0f} chacun. "
                f"Si tu possedes des biens propres (heritage, biens d'avant mariage), "
                f"ta part reelle serait plus elevee."
            )
            sources = [
                "CC art. 196-220 (participation aux acquets — regime ordinaire)",
                "CC art. 198 (definition des biens propres)",
            ]

        return RegimeMatrimonial(
            regime=regime,
            description=description,
            part_conjoint_1=round(part_1, 2),
            part_conjoint_2=round(part_2, 2),
            patrimoine_total=round(total, 2),
            explication=explication,
            sources=sources,
        )

    def estimate_survivor_benefits(
        self,
        rente_lpp: float,
        rente_avs: float,
    ) -> SurvivorBenefits:
        """Estime les rentes de survivant en cas de deces du conjoint.

        Args:
            rente_lpp: Rente LPP mensuelle du defunt (CHF).
            rente_avs: Rente AVS mensuelle du defunt (CHF).

        Returns:
            SurvivorBenefits avec le detail.
        """
        # AVS: 80% de la rente du defunt (LAVS art. 24)
        surv_avs_mensuel = round(rente_avs * AVS_SURVIVOR_FACTOR, 2)
        surv_avs_annuel = round(surv_avs_mensuel * 12, 2)

        # LPP: 60% de la rente assuree (LPP art. 19)
        surv_lpp_mensuel = round(rente_lpp * LPP_SURVIVOR_FACTOR, 2)
        surv_lpp_annuel = round(surv_lpp_mensuel * 12, 2)

        total_mensuel = round(surv_avs_mensuel + surv_lpp_mensuel, 2)
        total_annuel = round(surv_avs_annuel + surv_lpp_annuel, 2)

        chiffre_choc = (
            f"En cas de deces de ton conjoint, tu recevrais environ "
            f"CHF {total_mensuel:,.0f}/mois (AVS {surv_avs_mensuel:,.0f} + "
            f"LPP {surv_lpp_mensuel:,.0f}). "
            f"C'est {round(total_mensuel / (rente_avs + rente_lpp) * 100) if (rente_avs + rente_lpp) > 0 else 0}% "
            f"de la rente actuelle."
        )

        sources = [
            "LAVS art. 24 (rente de survivant AVS = 80% de la rente du defunt)",
            "LPP art. 19 (rente de veuve/veuf = 60% de la rente assuree)",
        ]

        return SurvivorBenefits(
            rente_survivant_avs_mensuelle=surv_avs_mensuel,
            rente_survivant_avs_annuelle=surv_avs_annuel,
            rente_survivant_lpp_mensuelle=surv_lpp_mensuel,
            rente_survivant_lpp_annuelle=surv_lpp_annuel,
            total_survivant_mensuel=total_mensuel,
            total_survivant_annuel=total_annuel,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def checklist_mariage(
        self,
        has_3a: bool = False,
        has_lpp: bool = True,
        has_property: bool = False,
        canton: str = "ZH",
    ) -> ChecklistMariage:
        """Retourne une checklist actionable pour les futurs maries.

        Personnalisee selon la situation (3a, LPP, propriete, canton).

        Args:
            has_3a: True si tu as un 3e pilier.
            has_lpp: True si tu es affilie·e a une caisse de pension.
            has_property: True si tu possedes un bien immobilier.
            canton: Code canton (2 lettres).

        Returns:
            ChecklistMariage avec les actions recommandees par priorite.
        """
        # --- Priorite haute : demarches obligatoires et urgentes ---
        priorite_haute = [
            "Fixer la date et demander un rendez-vous a l'etat civil (delai: ~2 mois avant)",
            "Choisir le regime matrimonial — par defaut: participation aux acquets (CC art. 181). "
            "Si tu veux un autre regime, un contrat de mariage notarie est necessaire AVANT la ceremonie",
            "Annoncer le changement d'etat civil a ton employeur (impact sur le certificat de salaire et les cotisations)",
            "Planifier la declaration fiscale commune des l'annee du mariage (LIFD art. 9 al. 1)",
        ]

        # --- Priorite moyenne : assurances et prevoyance ---
        priorite_moyenne = [
            "Verifier ta police d'assurance maladie (LAMal) — le mariage ne change pas ta prime, "
            "mais c'est un bon moment pour comparer les franchises en couple",
            "Mettre a jour les beneficiaires de ton assurance RC menage (couvrir les deux conjoints)",
        ]

        # Personnalisation LPP
        if has_lpp:
            priorite_moyenne.append(
                "Mettre a jour le beneficiaire LPP aupres de ta caisse de pension — "
                "ton conjoint est automatiquement beneficiaire (LPP art. 19-20), "
                "mais verifie que les informations sont a jour"
            )

        # Personnalisation 3a
        if has_3a:
            priorite_moyenne.append(
                "Mettre a jour le beneficiaire de ton pilier 3a aupres de ton prestataire — "
                "en tant que marie·e, l'ordre des beneficiaires change (conjoint en premier)"
            )

        # Personnalisation propriete
        if has_property:
            priorite_moyenne.append(
                "Adapter le contrat hypothecaire si necessaire — informer ta banque du mariage. "
                "Verifier la copropriete vs propriete commune"
            )

        priorite_moyenne.append(
            "Rediger ou mettre a jour ton testament — le mariage modifie la reserve "
            "hereditaire de ton conjoint (CC art. 462: 1/2 de la succession en pleine propriete "
            "ou 1/4 en pleine propriete + 1/2 en usufruit)"
        )

        # --- Priorite basse : optimisation et confort ---
        priorite_basse = [
            "Commander de nouvelles pieces d'identite (passeport, CI) si changement de nom",
            "Informer ta banque, tes assurances et ton bailleur du changement d'etat civil",
            "Evaluer l'impact fiscal avec notre simulateur — selon vos revenus, "
            f"le mariage peut creer un bonus ou une penalite fiscale (canton: {canton})",
            "Consulter un ou une specialiste pour un bilan patrimonial complet avant le mariage",
        ]

        items = priorite_haute + priorite_moyenne + priorite_basse

        # Chiffre choc personnalise
        nb_items = len(items)
        nb_haute = len(priorite_haute)
        chiffre_choc = (
            f"Le mariage implique {nb_items} demarches cles, dont {nb_haute} "
            f"a effectuer avant ou juste apres la ceremonie. "
            f"Le regime matrimonial par defaut (participation aux acquets) s'applique "
            f"automatiquement si tu ne fais rien — a toi de verifier que ca te convient."
        )

        sources = [
            "CC art. 159-251 (droit du mariage, regimes matrimoniaux)",
            "CC art. 181 (participation aux acquets — regime ordinaire)",
            "CC art. 462 (droit successoral du conjoint survivant)",
            "LIFD art. 9 al. 1 (imposition commune des epoux des l'annee du mariage)",
            "LPP art. 19-20 (rente de survivant pour le conjoint)",
            "LAMal (assurance maladie — pas d'impact direct du mariage sur la prime)",
        ]

        return ChecklistMariage(
            items=items,
            priorite_haute=priorite_haute,
            priorite_moyenne=priorite_moyenne,
            priorite_basse=priorite_basse,
            chiffre_choc=chiffre_choc,
            disclaimer=DISCLAIMER,
            sources=sources,
        )
