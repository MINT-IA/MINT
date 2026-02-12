"""
Simulateur d'impact financier de la naissance/parentalite en Suisse.

Calcule les APG maternite/paternite, allocations familiales cantonales,
deductions fiscales enfants et impact sur la carriere (lacunes LPP + 3a).

Sources:
    - LAPG art. 16d-16h (allocation maternite: 14 sem., 80%, max CHF 220/j)
    - LAPG art. 16i-16l (allocation paternite: 2 sem., 80%, max CHF 220/j)
    - LAFam art. 3 (allocations familiales: CHF 200-300/mois selon canton)
    - LIFD art. 35 al. 1 let. a (deduction par enfant: CHF 6'700)
    - LIFD art. 33 al. 1 let. hbis (frais de garde: max CHF 25'500)
    - LPP art. 7-8 (salaire coordonne, bonifications de vieillesse)
    - OPP 2 (ordonnance LPP, salaire minimum / seuil d'entree)

Sprint S22 — Evenements de vie : Famille.
"""

from dataclasses import dataclass, field
from typing import Dict, List

from app.constants.social_insurance import (
    LPP_SEUIL_ENTREE as _LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION as _LPP_DEDUCTION_COORDINATION,
    LPP_BONIFICATIONS_VIEILLESSE,
    PILIER_3A_PLAFOND_AVEC_LPP,
    get_lpp_bonification_rate,
)


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ton canton, de ton employeur et de ta situation personnelle. "
    "Ne constitue pas un conseil fiscal ou juridique (LSFin/LLCA). "
    "Consulte un ou une specialiste."
)

# ---------------------------------------------------------------------------
# APG Maternite / Paternite (2025/2026)
# ---------------------------------------------------------------------------

# Maternite (LAPG art. 16d-16h)
APG_MATERNITE_SEMAINES = 14         # 14 semaines
APG_MATERNITE_JOURS = 98            # 98 jours calendaires
APG_TAUX = 0.80                     # 80% du salaire
APG_MAX_JOUR = 220.0                # Max CHF 220/jour

# Paternite (LAPG art. 16i-16l)
APG_PATERNITE_SEMAINES = 2          # 2 semaines
APG_PATERNITE_JOURS_OUVRABLES = 10  # 10 jours ouvrables
APG_PATERNITE_JOURS_CALENDAIRES = 14  # 14 jours calendaires pour le calcul APG

# ---------------------------------------------------------------------------
# Allocations familiales par canton (LAFam art. 3, CHF/mois, 2025)
# ---------------------------------------------------------------------------

ALLOCATIONS_ENFANT_PAR_CANTON: Dict[str, float] = {
    "GE": 300.0, "VD": 300.0, "VS": 305.0, "NE": 220.0, "FR": 265.0,
    "BE": 230.0, "ZH": 200.0, "BS": 200.0, "LU": 210.0, "AG": 200.0,
    "SG": 200.0, "TI": 200.0, "GR": 220.0, "SO": 200.0, "TG": 200.0,
    "BL": 200.0, "AR": 200.0, "AI": 200.0, "GL": 200.0, "SH": 200.0,
    "ZG": 300.0, "SZ": 200.0, "OW": 200.0, "NW": 200.0, "UR": 200.0,
    "JU": 275.0,
}

# Allocation de formation: montant supplementaire (LAFam art. 3 al. 1 let. b)
ALLOCATION_FORMATION_SUPPLEMENT = 50.0  # CHF de plus que l'allocation enfant en general

# Ages limites
AGE_LIMITE_ENFANT = 16       # Allocation pour enfant: 0-16 ans
AGE_LIMITE_FORMATION = 25    # Allocation de formation: 16-25 ans

# ---------------------------------------------------------------------------
# Deductions fiscales enfant (LIFD, 2025/2026)
# ---------------------------------------------------------------------------

# Deduction par enfant (LIFD art. 35 al. 1 let. a)
DEDUCTION_PAR_ENFANT = 6_700.0  # CHF

# Deduction frais de garde (LIFD art. 33 al. 1 let. hbis)
DEDUCTION_FRAIS_GARDE_MAX = 25_500.0  # CHF

# ---------------------------------------------------------------------------
# Impact LPP (LPP art. 7-8, OPP2)
# ---------------------------------------------------------------------------

# Seuil d'entree LPP (salaire annuel minimum, 2025)
LPP_SEUIL_ENTREE = 22_680.0  # CHF/an

# Deduction de coordination (2025)
LPP_DEDUCTION_COORDINATION = 26_460.0  # CHF/an

# Taux de bonification LPP par tranche d'age (LPP art. 16)
LPP_BONIFICATION_TAUX = {
    (25, 34): 0.07,   # 7% du salaire coordonne
    (35, 44): 0.10,   # 10%
    (45, 54): 0.15,   # 15%
    (55, 65): 0.18,   # 18%
}

# Plafond 3a employe (2025)
PLAFOND_3A = 7_258.0  # CHF/an


@dataclass
class CongeParental:
    """Resultat du calcul APG conge maternite/paternite."""
    type_conge: str                      # "maternite" ou "paternite"
    duree_semaines: int                  # Nombre de semaines
    duree_jours: int                     # Nombre de jours
    salaire_journalier: float            # Salaire journalier (base)
    apg_journalier: float                # APG journalier (80%, plafonne)
    apg_total: float                     # Total APG sur toute la duree
    perte_revenu: float                  # Difference salaire - APG
    est_plafonne: bool                   # True si le max est atteint
    chiffre_choc: str                    # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class AllocationsFamiliales:
    """Resultat de l'estimation des allocations familiales."""
    canton: str                          # Code canton
    nb_enfants: int                      # Nombre d'enfants
    allocation_mensuelle_par_enfant: Dict[int, float]  # age_enfant -> montant mensuel
    total_mensuel: float                 # Total mensuel pour tous les enfants
    total_annuel: float                  # Total annuel
    detail: List[str]                    # Detail par enfant
    sources: List[str] = field(default_factory=list)


@dataclass
class ImpactFiscalEnfant:
    """Resultat du calcul de l'impact fiscal des enfants."""
    nb_enfants: int                          # Nombre d'enfants
    deduction_enfants: float                 # Deduction totale enfants (CHF)
    deduction_frais_garde: float             # Deduction frais de garde (CHF)
    deduction_totale: float                  # Total deductions (CHF)
    economie_impot_estimee: float            # Economie d'impot estimee (CHF)
    chiffre_choc: str                        # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class CareerGapProjection:
    """Resultat de la projection d'impact d'une interruption de carriere."""
    duree_interruption_mois: int             # Duree en mois
    salaire_annuel: float                    # Salaire de reference (CHF)
    perte_lpp_annuelle: float                # Perte annuelle de bonification LPP (CHF)
    perte_lpp_totale: float                  # Perte LPP totale sur la duree (CHF)
    perte_3a_annuelle: float                 # Perte potentielle 3a par annee sans revenu
    perte_3a_totale: float                   # Perte 3a totale sur la duree
    perte_revenu_totale: float               # Perte totale de revenu
    chiffre_choc: str                        # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class ChecklistNaissance:
    """Checklist actionable pour les futurs parents."""
    items: List[str]                       # Liste des actions recommandees
    priorite_haute: List[str]              # Actions urgentes (delais legaux)
    priorite_moyenne: List[str]            # Actions importantes
    priorite_basse: List[str]              # Actions de confort / optimisation
    chiffre_choc: str                      # Chiffre choc pedagogique
    disclaimer: str                        # Avertissement legal
    sources: List[str] = field(default_factory=list)


def _get_lpp_bonification_rate(age: int) -> float:
    """Retourne le taux de bonification LPP pour un age donne.

    Source: LPP art. 16.
    """
    for (age_min, age_max), rate in LPP_BONIFICATION_TAUX.items():
        if age_min <= age <= age_max:
            return rate
    return 0.0


class NaissanceService:
    """Simulateur d'impact financier de la naissance en droit suisse.

    Regles cles:
    - APG maternite: 14 semaines, 80% du salaire, max CHF 220/jour (LAPG art. 16d-16h)
    - APG paternite: 2 semaines, 80% du salaire, max CHF 220/jour (LAPG art. 16i-16l)
    - Allocations familiales: CHF 200-300/mois selon canton (LAFam art. 3)
    - Deduction fiscale par enfant: CHF 6'700 (LIFD art. 35 al. 1 let. a)
    - Deduction frais de garde: max CHF 25'500 (LIFD art. 33 al. 1 let. hbis)
    - Interruption de carriere = lacunes LPP + perte de capacite 3a
    """

    def simulate_conge_parental(
        self,
        salaire_mensuel: float,
        is_mother: bool = True,
    ) -> CongeParental:
        """Calcule les APG pour un conge maternite ou paternite.

        Args:
            salaire_mensuel: Salaire mensuel brut (CHF).
            is_mother: True pour maternite, False pour paternite.

        Returns:
            CongeParental avec le detail.
        """
        type_conge = "maternite" if is_mother else "paternite"

        if is_mother:
            duree_semaines = APG_MATERNITE_SEMAINES
            duree_jours = APG_MATERNITE_JOURS
        else:
            duree_semaines = APG_PATERNITE_SEMAINES
            duree_jours = APG_PATERNITE_JOURS_CALENDAIRES

        # Salaire journalier = salaire annuel / 360 (methode APG)
        salaire_annuel = salaire_mensuel * 12
        salaire_journalier = round(salaire_annuel / 360, 2)

        # APG = 80% du salaire journalier, max CHF 220/jour
        apg_brut = salaire_journalier * APG_TAUX
        apg_journalier = round(min(apg_brut, APG_MAX_JOUR), 2)
        est_plafonne = apg_brut > APG_MAX_JOUR

        apg_total = round(apg_journalier * duree_jours, 2)
        perte_revenu = round((salaire_journalier * duree_jours) - apg_total, 2)

        if is_mother:
            chiffre_choc = (
                f"Conge maternite : {duree_semaines} semaines a "
                f"CHF {apg_journalier:,.0f}/jour = CHF {apg_total:,.0f} au total. "
                f"Perte de revenu estimee: CHF {perte_revenu:,.0f}."
            )
        else:
            chiffre_choc = (
                f"Conge paternite : {duree_semaines} semaines a "
                f"CHF {apg_journalier:,.0f}/jour = CHF {apg_total:,.0f} au total. "
                f"Perte de revenu estimee: CHF {perte_revenu:,.0f}."
            )

        sources = [
            "LAPG art. 16d-16h (allocation maternite: 14 sem., 80%, max CHF 220/j)",
            "LAPG art. 16i-16l (allocation paternite: 2 sem., 80%, max CHF 220/j)",
        ]

        return CongeParental(
            type_conge=type_conge,
            duree_semaines=duree_semaines,
            duree_jours=duree_jours,
            salaire_journalier=salaire_journalier,
            apg_journalier=apg_journalier,
            apg_total=apg_total,
            perte_revenu=perte_revenu,
            est_plafonne=est_plafonne,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def estimate_allocations(
        self,
        canton: str,
        nb_enfants: int,
        ages_enfants: List[int],
    ) -> AllocationsFamiliales:
        """Estime les allocations familiales cantonales.

        Args:
            canton: Code canton (2 lettres).
            nb_enfants: Nombre d'enfants.
            ages_enfants: Liste des ages des enfants.

        Returns:
            AllocationsFamiliales avec le detail.
        """
        alloc_base = ALLOCATIONS_ENFANT_PAR_CANTON.get(canton, 200.0)
        alloc_formation = alloc_base + ALLOCATION_FORMATION_SUPPLEMENT

        allocation_par_enfant: Dict[int, float] = {}
        detail: List[str] = []
        total_mensuel = 0.0

        for i, age in enumerate(ages_enfants[:nb_enfants]):
            if age < AGE_LIMITE_ENFANT:
                montant = alloc_base
                type_alloc = "allocation pour enfant"
            elif age < AGE_LIMITE_FORMATION:
                montant = alloc_formation
                type_alloc = "allocation de formation"
            else:
                montant = 0.0
                type_alloc = "aucune (> 25 ans)"

            allocation_par_enfant[age] = montant
            total_mensuel += montant
            detail.append(
                f"Enfant {i + 1} ({age} ans): CHF {montant:,.0f}/mois ({type_alloc})"
            )

        total_annuel = round(total_mensuel * 12, 2)
        total_mensuel = round(total_mensuel, 2)

        sources = [
            "LAFam art. 3 (allocations familiales: CHF 200-300/mois selon canton)",
            f"Canton {canton}: CHF {alloc_base:,.0f}/mois (enfant), CHF {alloc_formation:,.0f}/mois (formation)",
        ]

        return AllocationsFamiliales(
            canton=canton,
            nb_enfants=nb_enfants,
            allocation_mensuelle_par_enfant=allocation_par_enfant,
            total_mensuel=total_mensuel,
            total_annuel=total_annuel,
            detail=detail,
            sources=sources,
        )

    def calculate_impact_fiscal_enfant(
        self,
        revenu_imposable: float,
        taux_marginal: float,
        nb_enfants: int,
        frais_garde: float = 0.0,
    ) -> ImpactFiscalEnfant:
        """Calcule l'economie fiscale liee aux deductions enfants.

        Args:
            revenu_imposable: Revenu imposable annuel (CHF).
            taux_marginal: Taux marginal d'imposition (decimal, ex: 0.30 = 30%).
            nb_enfants: Nombre d'enfants a charge.
            frais_garde: Frais de garde annuels effectifs (CHF).

        Returns:
            ImpactFiscalEnfant avec le detail.
        """
        deduction_enfants = DEDUCTION_PAR_ENFANT * nb_enfants
        deduction_garde = min(frais_garde, DEDUCTION_FRAIS_GARDE_MAX)
        deduction_totale = deduction_enfants + deduction_garde

        # Economie = deduction * taux marginal
        economie = round(deduction_totale * taux_marginal, 2)

        chiffre_choc = (
            f"Avec {nb_enfants} enfant(s), tu peux deduire "
            f"CHF {deduction_totale:,.0f} de ton revenu imposable. "
            f"Economie estimee: ~CHF {economie:,.0f}/an."
        )

        sources = [
            "LIFD art. 35 al. 1 let. a (deduction par enfant: CHF 6'700)",
            "LIFD art. 33 al. 1 let. hbis (frais de garde: max CHF 25'500)",
        ]

        return ImpactFiscalEnfant(
            nb_enfants=nb_enfants,
            deduction_enfants=deduction_enfants,
            deduction_frais_garde=deduction_garde,
            deduction_totale=deduction_totale,
            economie_impot_estimee=economie,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def project_career_gap(
        self,
        salaire_annuel: float,
        duree_interruption_mois: int,
        age: int = 35,
    ) -> CareerGapProjection:
        """Projette l'impact d'une interruption de carriere sur la prevoyance.

        Args:
            salaire_annuel: Salaire annuel brut de reference (CHF).
            duree_interruption_mois: Duree de l'interruption en mois.
            age: Age de la personne au moment de l'interruption.

        Returns:
            CareerGapProjection avec le detail.
        """
        # LPP: salaire coordonne = salaire - deduction de coordination
        salaire_coordonne = max(0, salaire_annuel - LPP_DEDUCTION_COORDINATION)
        taux_bonification = _get_lpp_bonification_rate(age)
        bonification_annuelle = salaire_coordonne * taux_bonification

        # Perte LPP prorata sur la duree
        perte_lpp_annuelle = round(bonification_annuelle, 2)
        perte_lpp_totale = round(bonification_annuelle * duree_interruption_mois / 12, 2)

        # 3a: si interruption, pas de revenu = pas de versement possible
        # (le 3a necessite un revenu soumis AVS)
        annees_interruption = duree_interruption_mois / 12
        perte_3a_annuelle = PLAFOND_3A
        perte_3a_totale = round(PLAFOND_3A * annees_interruption, 2)

        # Perte de revenu
        perte_revenu_totale = round(salaire_annuel * duree_interruption_mois / 12, 2)

        chiffre_choc = (
            f"Une interruption de {duree_interruption_mois} mois = "
            f"~CHF {perte_lpp_totale:,.0f} de bonifications LPP perdues + "
            f"~CHF {perte_3a_totale:,.0f} de versements 3a manques. "
            f"Impact total sur la prevoyance: ~CHF {perte_lpp_totale + perte_3a_totale:,.0f}."
        )

        sources = [
            "LPP art. 16 (bonifications de vieillesse: 7-18% du salaire coordonne)",
            "LPP art. 8 (salaire coordonne = salaire - deduction de coordination)",
            f"OPP2 (deduction de coordination 2025: CHF {LPP_DEDUCTION_COORDINATION:,.0f})",
            f"LIFD (plafond 3a 2025: CHF {PLAFOND_3A:,.0f})",
        ]

        return CareerGapProjection(
            duree_interruption_mois=duree_interruption_mois,
            salaire_annuel=salaire_annuel,
            perte_lpp_annuelle=perte_lpp_annuelle,
            perte_lpp_totale=perte_lpp_totale,
            perte_3a_annuelle=perte_3a_annuelle,
            perte_3a_totale=perte_3a_totale,
            perte_revenu_totale=perte_revenu_totale,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def checklist_naissance(
        self,
        civil_status: str = "celibataire",
        canton: str = "ZH",
        has_3a: bool = False,
        has_lpp: bool = True,
    ) -> ChecklistNaissance:
        """Retourne une checklist actionable pour les futurs parents.

        Personnalisee selon la situation (etat civil, canton, 3a, LPP).

        Args:
            civil_status: Etat civil ("celibataire", "marie", "concubin").
            canton: Code canton (2 lettres).
            has_3a: True si tu as un 3e pilier.
            has_lpp: True si tu es affilie·e a une caisse de pension.

        Returns:
            ChecklistNaissance avec les actions recommandees par priorite.
        """
        alloc_base = ALLOCATIONS_ENFANT_PAR_CANTON.get(canton, 200.0)

        # --- Priorite haute : delais legaux stricts ---
        priorite_haute = [
            "Inscrire la naissance a l'etat civil dans les 3 jours suivant "
            "l'accouchement (CC art. 252). L'hopital peut s'en charger, mais verifie.",
            "Demander les allocations familiales (LAFam art. 3) aupres de ton "
            f"employeur ou de ta caisse de compensation — montant: CHF {alloc_base:,.0f}/mois "
            f"dans le canton {canton}",
            "Annoncer le conge maternite APG a ton employeur (14 semaines, 80% du salaire, "
            "max CHF 220/jour — LAPG art. 16d-16h)",
            "Annoncer le conge paternite APG a l'employeur du pere (2 semaines, 80% du salaire, "
            "max CHF 220/jour — LAPG art. 16i-16l). A prendre dans les 6 mois suivant la naissance.",
            "Inscrire le bebe a l'assurance maladie (LAMal art. 3) dans les 3 mois "
            "suivant la naissance — retroactif au jour de la naissance. "
            "Apres 3 mois, tu perds la couverture retroactive!",
        ]

        # --- Priorite moyenne : prevoyance et administratif ---
        priorite_moyenne = []

        # Personnalisation etat civil
        if civil_status == "celibataire" or civil_status == "concubin":
            priorite_moyenne.append(
                "Reconnaissance de paternite a l'etat civil (si non marie) — "
                "peut etre faite avant ou apres la naissance (CC art. 260)"
            )
            priorite_moyenne.append(
                "Demander l'autorite parentale conjointe (si concubins) aupres de "
                "l'Office de protection de l'enfant (CC art. 298a)"
            )

        # Personnalisation LPP
        if has_lpp:
            priorite_moyenne.append(
                "Mettre a jour les beneficiaires de ta caisse de pension (LPP) — "
                "verifier que tes enfants figurent comme beneficiaires "
                "pour la rente d'orphelin (LPP art. 20)"
            )

        # Personnalisation 3a
        if has_3a:
            priorite_moyenne.append(
                "Verifier les beneficiaires de ton pilier 3a — "
                "tes enfants peuvent figurer dans l'ordre des beneficiaires"
            )

        priorite_moyenne.append(
            "Adapter ton budget familial — un enfant coute en moyenne "
            "CHF 1'200 a 1'500/mois en Suisse (alimentation, couches, creche, etc.)"
        )

        # --- Priorite basse : optimisation ---
        priorite_basse = [
            "Calculer l'impact fiscal de l'enfant — deduction de CHF 6'700 par enfant "
            "(LIFD art. 35 al. 1 let. a) + frais de garde max CHF 25'500 "
            "(LIFD art. 33 al. 1 let. hbis)",
        ]

        if civil_status == "marie" and has_3a:
            priorite_basse.append(
                "Couple marie avec 3a : les deux conjoints peuvent cotiser au 3e pilier "
                f"(CHF {PLAFOND_3A:,.0f} chacun si salarie·e avec LPP), "
                "ce qui double les deductions fiscales"
            )
        elif not has_3a:
            priorite_basse.append(
                "Envisager l'ouverture d'un 3e pilier — les deductions fiscales "
                f"(max CHF {PLAFOND_3A:,.0f}/an) aident a compenser les depenses supplementaires"
            )

        priorite_basse.append(
            "Anticiper l'impact d'une eventuelle reduction de temps de travail "
            "sur la prevoyance (LPP + 3a) — utilise notre simulateur 'career gap'"
        )
        priorite_basse.append(
            "Consulter un ou une specialiste pour un bilan prevoyance familiale complet"
        )

        items = priorite_haute + priorite_moyenne + priorite_basse

        # Chiffre choc personnalise
        nb_items = len(items)
        nb_haute = len(priorite_haute)
        chiffre_choc = (
            f"L'arrivee d'un enfant implique {nb_items} demarches cles, dont {nb_haute} "
            f"avec des delais legaux stricts (3 jours pour l'etat civil, 3 mois pour la LAMal, "
            f"6 mois pour le conge paternite). "
            f"Les allocations familiales representent CHF {alloc_base * 12:,.0f}/an "
            f"dans le canton {canton}."
        )

        sources = [
            "CC art. 252 (inscription naissance a l'etat civil — delai 3 jours)",
            "CC art. 260 (reconnaissance de paternite)",
            "CC art. 298a (autorite parentale conjointe pour parents non maries)",
            "LAPG art. 16d-16h (conge maternite: 14 sem., 80%, max CHF 220/j)",
            "LAPG art. 16i-16l (conge paternite: 2 sem., 80%, max CHF 220/j)",
            "LAFam art. 3 (allocations familiales cantonales)",
            "LAMal art. 3 (obligation d'assurance — inscription bebe dans les 3 mois)",
            "LIFD art. 35 al. 1 let. a (deduction par enfant: CHF 6'700)",
        ]

        return ChecklistNaissance(
            items=items,
            priorite_haute=priorite_haute,
            priorite_moyenne=priorite_moyenne,
            priorite_basse=priorite_basse,
            chiffre_choc=chiffre_choc,
            disclaimer=DISCLAIMER,
            sources=sources,
        )
