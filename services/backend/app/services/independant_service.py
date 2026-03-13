"""
Independant (Self-Employed Worker) Service.

Provides analysis of social security coverage, contribution calculations,
and protection gap identification for self-employed workers in Switzerland.

Sources:
    - LAVS art. 8 (cotisations independants: ~10.6%, bareme degressif)
    - LAVS art. 9 (revenu determinant)
    - OPP3 art. 7 (3a grand plafond: 20% du revenu net, max 35'280 CHF)
    - LPP art. 4 (affiliation volontaire pour independants)
    - LAA art. 4 (assurance accident obligatoire salaries, facultative independants)
    - LCA (assurance IJM: perte de gain maladie, pas d'obligation legale)
    - LAPG art. 1a (allocations perte de gain: service militaire, maternite)

Ethical requirements:
    - Gender-neutral language throughout
    - NEVER use "garanti", "assure" (sens de garantie), "certain"
    - All recommendations include a source reference
    - Mandatory disclaimer on every response
"""

from dataclasses import dataclass
from typing import List

from app.constants.social_insurance import (
    AVS_AGE_REFERENCE_HOMME as RETIREMENT_AGE,
    AVS_BAREME_DEGRESSIF_PLAFOND as AVS_DEGRESSIVE_UPPER,
    AVS_COTISATION_MIN_INDEPENDANT as AVS_MINIMUM_CONTRIBUTION,
    AVS_COTISATION_TOTAL as AVS_FULL_RATE,
    AVS_SEUIL_REVENU_MIN_INDEPENDANT as AVS_MINIMUM_INCOME_THRESHOLD,
    PILIER_3A_PLAFOND_AVEC_LPP as PLAFOND_3A_SALARIE,
    PILIER_3A_PLAFOND_SANS_LPP as PLAFOND_3A_INDEPENDANT_MAX,
    PILIER_3A_TAUX_REVENU_SANS_LPP as PLAFOND_3A_INDEPENDANT_TAUX,
)


# ---------------------------------------------------------------------------
# Local estimation constants (not legal constants — keep here)
# ---------------------------------------------------------------------------

# IJM (indemnite journaliere maladie) estimated cost
# Typical: ~1-3% of insured salary for 720 days coverage
IJM_ESTIMATE_RATE = 0.02  # 2% as middle estimate

# LAA (accident insurance) estimated cost
# Typical: ~1-2% of insured salary for non-professional accident
LAA_ESTIMATE_RATE = 0.015  # 1.5% estimate

# Degressive rates (simplified brackets for independant AVS calculation)
# Kept local because AVS_BAREME_INDEPENDANT in social_insurance.py uses
# a different (more precise) bracket structure with non-marginal rates.
AVS_DEGRESSIVE_BRACKETS = [
    (9_800, 17_600, 0.048),
    (17_601, 21_400, 0.051),
    (21_401, 23_800, 0.054),
    (23_801, 28_600, 0.057),
    (28_601, 33_400, 0.060),
    (33_401, 38_200, 0.064),
    (38_201, 43_000, 0.068),
    (43_001, 47_800, 0.074),
    (47_801, 52_600, 0.080),
    (52_601, 58_800, 0.092),
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class IndependantInput:
    """Input data for self-employed worker analysis."""
    revenu_net: float              # Net income from self-employment
    age: int
    a_lpp_volontaire: bool         # Has voluntary LPP affiliation
    a_3a: bool                     # Has a 3a account
    a_ijm: bool                    # Has IJM (income protection insurance)
    a_laa: bool                    # Has LAA (accident insurance)
    canton: str                    # Canton code


@dataclass
class IndependantResult:
    """Result of self-employed worker analysis."""
    cotisations_avs: float
    plafond_3a_grand: float
    cout_protection_totale: float
    lacunes_couverture: List[dict]
    recommandations: List[dict]
    urgences: List[dict]
    checklist: List[dict]
    disclaimer: str


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Cette analyse est indicative et basee sur des taux moyens. "
    "Les cotisations AVS exactes dependent de votre caisse de compensation. "
    "Les primes IJM et LAA varient selon l'assureur et votre activite. "
    "Consultez votre caisse de compensation et un courtier en assurances "
    "pour des montants precis."
)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class IndependantService:
    """Analyse la situation sociale et de prevoyance des independants.

    Calcule les cotisations AVS, identifie les lacunes de couverture,
    et recommande les protections necessaires. Langage neutre, aucun
    terme banni.
    """

    def calculate_avs_contribution(self, revenu_net: float) -> float:
        """Calculate AVS contribution for self-employed (LAVS art. 8).

        Uses degressive scale for low incomes, full rate above threshold.

        Args:
            revenu_net: Annual net income from self-employment.

        Returns:
            Annual AVS contribution in CHF.
        """
        if revenu_net <= 0:
            return 0.0

        if revenu_net < AVS_MINIMUM_INCOME_THRESHOLD:
            return AVS_MINIMUM_CONTRIBUTION

        if revenu_net > AVS_DEGRESSIVE_UPPER:
            return round(revenu_net * AVS_FULL_RATE, 2)

        # Apply degressive scale
        for lower, upper, rate in AVS_DEGRESSIVE_BRACKETS:
            if lower <= revenu_net <= upper:
                return round(revenu_net * rate, 2)

        # Fallback: should not reach here, but use full rate
        return round(revenu_net * AVS_FULL_RATE, 2)

    def calculate_3a_plafond(self, revenu_net: float) -> float:
        """Calculate 3a grand plafond for self-employed without LPP.

        OPP3 art. 7: 20% of net income, max 35'280 CHF.

        Args:
            revenu_net: Annual net income.

        Returns:
            Maximum 3a contribution in CHF.
        """
        if revenu_net <= 0:
            return 0.0
        plafond = revenu_net * PLAFOND_3A_INDEPENDANT_TAUX
        return round(min(plafond, PLAFOND_3A_INDEPENDANT_MAX), 2)

    def estimate_ijm_cost(self, revenu_net: float) -> float:
        """Estimate IJM (income protection) insurance cost.

        Typical range: 1-3% of insured income for 720 days coverage.
        Uses 2% as middle estimate.

        Args:
            revenu_net: Annual net income.

        Returns:
            Estimated annual IJM premium in CHF.
        """
        return round(revenu_net * IJM_ESTIMATE_RATE, 2)

    def estimate_laa_cost(self, revenu_net: float) -> float:
        """Estimate LAA (accident insurance) cost.

        Typical range: 1-2% of insured income for non-professional accident.
        Uses 1.5% as middle estimate.

        Args:
            revenu_net: Annual net income.

        Returns:
            Estimated annual LAA premium in CHF.
        """
        return round(revenu_net * LAA_ESTIMATE_RATE, 2)

    def analyze(self, input_data: IndependantInput) -> IndependantResult:
        """Run comprehensive analysis for self-employed worker.

        Args:
            input_data: IndependantInput with worker details.

        Returns:
            IndependantResult with contributions, gaps, and recommendations.
        """
        revenu = input_data.revenu_net
        age = input_data.age

        # --- AVS contribution ---
        cotisations_avs = self.calculate_avs_contribution(revenu)

        # --- 3a plafond ---
        if input_data.a_lpp_volontaire:
            # With voluntary LPP: regular 3a plafond applies
            plafond_3a = PLAFOND_3A_SALARIE
        else:
            # Without LPP: grand plafond
            plafond_3a = self.calculate_3a_plafond(revenu)

        # --- Protection cost simulator ---
        ijm_cost = self.estimate_ijm_cost(revenu)
        laa_cost = self.estimate_laa_cost(revenu)
        cout_3a = plafond_3a  # Maximum annual 3a contribution

        cout_protection_totale = round(
            cotisations_avs + ijm_cost + laa_cost + cout_3a, 2
        )

        # --- Coverage gaps ---
        lacunes: List[dict] = []

        if not input_data.a_lpp_volontaire:
            lacunes.append({
                "type": "lpp",
                "titre": "Pas de LPP (2e pilier)",
                "description": (
                    "En tant qu'independant, vous n'avez pas de LPP obligatoire. "
                    "Votre prevoyance retraite repose uniquement sur l'AVS "
                    "(1er pilier) et le 3e pilier. L'AVS seule ne couvre "
                    "qu'environ 40-60% du dernier revenu."
                ),
                "severite": "haute",
                "source": "LPP art. 4",
            })

        if not input_data.a_ijm:
            lacunes.append({
                "type": "ijm",
                "titre": "Pas d'assurance perte de gain maladie (IJM)",
                "description": (
                    "LACUNE CRITIQUE: en cas de maladie, vous n'avez aucune "
                    "couverture de remplacement de revenu. Contrairement aux "
                    "salaries, il n'y a pas d'obligation legale pour "
                    "l'employeur. Une maladie de longue duree peut avoir "
                    "des consequences financieres severes."
                ),
                "severite": "critique",
                "source": "LCA (pas d'obligation legale pour independants)",
            })

        if not input_data.a_laa:
            lacunes.append({
                "type": "laa",
                "titre": "Pas d'assurance accident (LAA)",
                "description": (
                    "En tant qu'independant, l'assurance accident n'est pas "
                    "obligatoire. Vous n'etes couvert que par votre assurance "
                    "maladie de base (LAMal) en cas d'accident, ce qui peut "
                    "etre insuffisant pour la perte de gain."
                ),
                "severite": "haute",
                "source": "LAA art. 4",
            })

        if not input_data.a_3a:
            lacunes.append({
                "type": "3a",
                "titre": "Pas de 3e pilier",
                "description": (
                    f"Vous n'avez pas de 3e pilier. En tant qu'independant "
                    f"sans LPP, le 3a est votre principal outil de "
                    f"prevoyance complementaire. Le plafond est de "
                    f"CHF {plafond_3a:,.0f}/an."
                ),
                "severite": "haute",
                "source": "OPP3 art. 7",
            })

        # --- Urgences ---
        urgences: List[dict] = []

        if not input_data.a_ijm:
            urgences.append({
                "id": "ijm_urgence",
                "titre": "Souscrire une assurance perte de gain maladie",
                "description": (
                    "PRIORITE ABSOLUE: sans IJM, une maladie de quelques "
                    "semaines peut mettre en peril votre activite et vos "
                    "finances. Souscrivez une couverture d'au moins 720 jours "
                    "avec un delai d'attente de 30-60 jours."
                ),
                "cout_estime_annuel": ijm_cost,
                "source": "LCA, bonne pratique",
                "priorite": "critique",
            })

        if not input_data.a_laa:
            urgences.append({
                "id": "laa_urgence",
                "titre": "Souscrire une assurance accident privee",
                "description": (
                    "En cas d'accident, la LAMal couvre les soins mais pas "
                    "la perte de gain. Souscrivez une assurance accident "
                    "privee pour couvrir le risque de perte de revenu."
                ),
                "cout_estime_annuel": laa_cost,
                "source": "LAA art. 4",
                "priorite": "haute",
            })

        # --- Recommendations ---
        recommandations: List[dict] = []

        if not input_data.a_lpp_volontaire:
            recommandations.append({
                "id": "lpp_volontaire",
                "titre": "Affiliation LPP volontaire",
                "description": (
                    "Envisagez une affiliation volontaire a une fondation "
                    "de prevoyance. Cela vous donne acces au 2e pilier, "
                    "avec des cotisations deductibles fiscalement et une "
                    "meilleure prevoyance retraite."
                ),
                "source": "LPP art. 4",
                "priorite": "haute",
            })

        recommandations.append({
            "id": "maximiser_3a",
            "titre": "Maximiser le 3e pilier",
            "description": (
                f"Versez le maximum annuel dans votre 3e pilier: "
                f"CHF {plafond_3a:,.0f}. "
                f"{'(grand plafond: 20% du revenu net, sans LPP)' if not input_data.a_lpp_volontaire else '(plafond salarie, avec LPP volontaire)'}. "
                f"L'economie fiscale est significative."
            ),
            "source": "OPP3 art. 7, LIFD art. 33",
            "priorite": "haute",
        })

        if age >= 40 and not input_data.a_lpp_volontaire:
            recommandations.append({
                "id": "bilan_prevoyance",
                "titre": "Bilan de prevoyance complet",
                "description": (
                    f"A {age} ans, il reste {max(0, RETIREMENT_AGE - age)} "
                    f"annees avant la retraite. Sans 2e pilier, votre "
                    f"prevoyance est limitee. Un bilan complet permet "
                    f"d'identifier les actions correctives possibles."
                ),
                "source": "LPP art. 4, LAVS art. 8",
                "priorite": "haute",
            })

        recommandations.append({
            "id": "caisse_compensation",
            "titre": "Verifier l'inscription a la caisse de compensation",
            "description": (
                "Assurez-vous d'etre inscrit aupres d'une caisse de "
                "compensation AVS. Les cotisations sont obligatoires "
                "et calculees sur votre revenu net. Un retard peut "
                "entrainer des interets moratoires."
            ),
            "source": "LAVS art. 8-9",
            "priorite": "moyenne",
        })

        # --- Checklist ---
        checklist: List[dict] = [
            {
                "item": "Inscription caisse de compensation AVS",
                "statut": "a_verifier",
                "source": "LAVS art. 8",
            },
            {
                "item": "Cotisations AVS a jour",
                "statut": "a_verifier",
                "source": "LAVS art. 8",
                "montant_estime": cotisations_avs,
            },
            {
                "item": "Assurance perte de gain maladie (IJM)",
                "statut": "ok" if input_data.a_ijm else "manquant",
                "source": "LCA",
            },
            {
                "item": "Assurance accident (LAA)",
                "statut": "ok" if input_data.a_laa else "manquant",
                "source": "LAA art. 4",
            },
            {
                "item": "2e pilier (LPP volontaire)",
                "statut": "ok" if input_data.a_lpp_volontaire else "manquant",
                "source": "LPP art. 4",
            },
            {
                "item": "3e pilier (3a)",
                "statut": "ok" if input_data.a_3a else "manquant",
                "source": "OPP3 art. 7",
                "plafond": plafond_3a,
            },
        ]

        return IndependantResult(
            cotisations_avs=cotisations_avs,
            plafond_3a_grand=plafond_3a,
            cout_protection_totale=cout_protection_totale,
            lacunes_couverture=lacunes,
            recommandations=recommandations,
            urgences=urgences,
            checklist=checklist,
            disclaimer=DISCLAIMER,
        )
