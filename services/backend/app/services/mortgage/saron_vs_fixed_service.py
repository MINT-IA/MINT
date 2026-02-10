"""
SARON vs Fixed-rate mortgage comparator.

Compares the total cost of a SARON-based mortgage versus a fixed-rate
mortgage over a given duration, with multiple SARON scenarios.

Key concepts:
- SARON (Swiss Average Rate Overnight): variable rate, adjusted quarterly
- Fixed rate: locked for the entire duration (2, 5, 7, 10, 15 years)
- SARON mortgage = SARON compound rate + bank margin (~0.8-1.2%)
- Three default scenarios: stable, rising, falling

Note: This is a simplified educational model. Actual SARON compounding
uses daily rates. We use annualized approximations.

Sources:
    - Conventions bancaires suisses sur les hypotheques SARON
    - SIX Swiss Exchange (taux SARON de reference)

Sprint S17 — Mortgage & Real Estate.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en financement immobilier au sens de la LSFin. "
    "Les taux utilises sont des valeurs educatives et ne representent pas "
    "des offres reelles. Les taux futurs sont imprevisibles. "
    "Consultez un ou une specialiste hypothecaire pour une analyse personnalisee."
)

# Default indicative rates (educational, 2026 estimates)
TAUX_DEFAUT = {
    "saron_compose": 0.0125,   # SARON compound rate ~1.25%
    "marge_banque": 0.0080,    # Bank margin ~0.80%
    "fixe_2_ans": 0.0190,
    "fixe_5_ans": 0.0220,
    "fixe_7_ans": 0.0235,
    "fixe_10_ans": 0.0250,
    "fixe_15_ans": 0.0270,
}

# Default SARON scenarios
SCENARIOS_DEFAUT = {
    "stable": {"label": "Taux stable", "variation_annuelle": 0.0},
    "hausse": {"label": "Hausse progressive", "variation_annuelle": 0.0025},
    "baisse": {"label": "Baisse progressive", "variation_annuelle": -0.0015},
}


@dataclass
class GrapheEntry:
    """Single year entry for the comparison chart."""
    annee: int
    mensualite_fixe: float
    mensualite_saron: float


@dataclass
class ChiffreChoc:
    """Shock figure with amount and explanatory text."""
    montant: float
    texte: str


@dataclass
class ScenarioResult:
    """Result for a single SARON scenario."""
    nom: str
    label: str
    cout_total_interets: float     # Total interest paid (CHF)
    mensualite_moyenne: float      # Average monthly payment (CHF)
    mensualite_min: float          # Minimum monthly payment (CHF)
    mensualite_max: float          # Maximum monthly payment (CHF)
    difference_vs_fixe: float      # Difference vs fixed rate (CHF, negative = cheaper)
    graphe_data: List[GrapheEntry]


@dataclass
class SaronVsFixedResult:
    """Complete result of the SARON vs Fixed comparison."""

    # Fixed rate
    taux_fixe: float
    cout_total_fixe: float         # Total interest cost for fixed rate (CHF)
    mensualite_fixe: float         # Monthly payment for fixed rate (CHF)

    # SARON scenarios
    scenarios: List[ScenarioResult]

    # Best scenario summary
    meilleur_scenario: str
    economie_max: float            # Max savings vs fixed (CHF)

    # Shock figure
    chiffre_choc: ChiffreChoc

    # Input metadata
    montant_hypothecaire: float
    duree_ans: int
    taux_saron_actuel: float
    marge_banque: float

    # Compliance
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class SaronVsFixedService:
    """Compare SARON vs fixed-rate mortgage costs.

    Simulates the total interest cost over the duration for:
    - A fixed-rate mortgage (constant payments)
    - A SARON mortgage under multiple scenarios (stable, rising, falling)

    The comparison is interest-only (no amortization) for simplicity,
    which is the most common Swiss mortgage structure for the 1st rank.

    Sources:
        - Conventions bancaires suisses
        - SIX Swiss Exchange (SARON reference)
    """

    def compare(
        self,
        montant_hypothecaire: float,
        duree_ans: int = 10,
        taux_saron_actuel: Optional[float] = None,
        marge_banque: Optional[float] = None,
        scenarios_saron: Optional[List[Dict]] = None,
        taux_fixe: Optional[float] = None,
    ) -> SaronVsFixedResult:
        """Compare SARON vs fixed-rate mortgage.

        Args:
            montant_hypothecaire: Mortgage amount (CHF).
            duree_ans: Duration in years (1-30).
            taux_saron_actuel: Current SARON compound rate (default ~1.25%).
            marge_banque: Bank margin on SARON (default ~0.80%).
            scenarios_saron: Custom SARON scenarios [{annee, taux}, ...] per scenario.
            taux_fixe: Fixed rate for comparison. If None, auto-selected by duration.

        Returns:
            SaronVsFixedResult with full comparison.
        """
        # Sanitize inputs
        montant_hypothecaire = max(0.0, montant_hypothecaire)
        duree_ans = max(1, min(30, duree_ans))

        if taux_saron_actuel is None:
            taux_saron_actuel = TAUX_DEFAUT["saron_compose"]
        taux_saron_actuel = max(0.0, min(0.10, taux_saron_actuel))

        if marge_banque is None:
            marge_banque = TAUX_DEFAUT["marge_banque"]
        marge_banque = max(0.0, min(0.05, marge_banque))

        if taux_fixe is None:
            taux_fixe = self._select_fixed_rate(duree_ans)
        taux_fixe = max(0.0, min(0.10, taux_fixe))

        # 1. Fixed rate calculation
        interets_annuels_fixe = montant_hypothecaire * taux_fixe
        mensualite_fixe = round(interets_annuels_fixe / 12, 2)
        cout_total_fixe = round(interets_annuels_fixe * duree_ans, 2)

        # 2. SARON scenarios
        scenario_defs = self._build_scenarios(taux_saron_actuel, marge_banque, duree_ans)
        scenario_results: List[ScenarioResult] = []

        for nom, sdef in scenario_defs.items():
            result = self._simulate_scenario(
                nom=nom,
                label=sdef["label"],
                taux_initial=taux_saron_actuel + marge_banque,
                variation_annuelle=sdef["variation_annuelle"],
                montant=montant_hypothecaire,
                duree=duree_ans,
                mensualite_fixe=mensualite_fixe,
                cout_total_fixe=cout_total_fixe,
            )
            scenario_results.append(result)

        # 3. Best scenario (most savings vs fixed)
        meilleur = min(scenario_results, key=lambda s: s.cout_total_interets)
        economie_max = round(cout_total_fixe - meilleur.cout_total_interets, 2)

        # 4. Chiffre choc
        if economie_max > 0:
            chiffre_choc = ChiffreChoc(
                montant=economie_max,
                texte=(
                    f"Dans le meilleur scenario ({meilleur.label}), le SARON "
                    f"te ferait economiser {economie_max:,.0f} CHF sur {duree_ans} ans "
                    f"par rapport au taux fixe."
                ),
            )
        else:
            surcharge = abs(economie_max)
            chiffre_choc = ChiffreChoc(
                montant=surcharge,
                texte=(
                    f"Meme dans le meilleur scenario SARON, le taux fixe est "
                    f"plus avantageux de {surcharge:,.0f} CHF sur {duree_ans} ans. "
                    f"Le fixe offre aussi la securite de mensualites constantes."
                ),
            )

        # 5. Sources
        sources = [
            "Conventions bancaires suisses sur les hypotheques SARON",
            "SIX Swiss Exchange (taux SARON de reference)",
            "Taux indicatifs a titre educatif — ne representent pas des offres reelles",
        ]

        return SaronVsFixedResult(
            taux_fixe=taux_fixe,
            cout_total_fixe=cout_total_fixe,
            mensualite_fixe=mensualite_fixe,
            scenarios=scenario_results,
            meilleur_scenario=meilleur.nom,
            economie_max=economie_max,
            chiffre_choc=chiffre_choc,
            montant_hypothecaire=montant_hypothecaire,
            duree_ans=duree_ans,
            taux_saron_actuel=taux_saron_actuel,
            marge_banque=marge_banque,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _select_fixed_rate(self, duree_ans: int) -> float:
        """Select the appropriate fixed rate for the given duration."""
        if duree_ans <= 3:
            return TAUX_DEFAUT["fixe_2_ans"]
        elif duree_ans <= 6:
            return TAUX_DEFAUT["fixe_5_ans"]
        elif duree_ans <= 8:
            return TAUX_DEFAUT["fixe_7_ans"]
        elif duree_ans <= 12:
            return TAUX_DEFAUT["fixe_10_ans"]
        else:
            return TAUX_DEFAUT["fixe_15_ans"]

    def _build_scenarios(
        self,
        taux_saron: float,
        marge: float,
        duree: int,
    ) -> Dict:
        """Build the default SARON scenarios."""
        return {
            "stable": {
                "label": "Taux stable",
                "variation_annuelle": 0.0,
            },
            "hausse": {
                "label": "Hausse progressive (+0.25%/an)",
                "variation_annuelle": 0.0025,
            },
            "baisse": {
                "label": "Baisse progressive (-0.15%/an)",
                "variation_annuelle": -0.0015,
            },
        }

    def _simulate_scenario(
        self,
        nom: str,
        label: str,
        taux_initial: float,
        variation_annuelle: float,
        montant: float,
        duree: int,
        mensualite_fixe: float,
        cout_total_fixe: float,
    ) -> ScenarioResult:
        """Simulate a single SARON scenario."""
        mensualites: List[float] = []
        graphe: List[GrapheEntry] = []
        cout_total = 0.0

        for annee in range(1, duree + 1):
            taux_annee = max(0.0, taux_initial + variation_annuelle * (annee - 1))
            interets_annee = montant * taux_annee
            mensualite = round(interets_annee / 12, 2)
            mensualites.append(mensualite)
            cout_total += interets_annee

            graphe.append(GrapheEntry(
                annee=annee,
                mensualite_fixe=mensualite_fixe,
                mensualite_saron=mensualite,
            ))

        cout_total = round(cout_total, 2)
        mensualite_moyenne = round(sum(mensualites) / len(mensualites), 2) if mensualites else 0.0
        mensualite_min = round(min(mensualites), 2) if mensualites else 0.0
        mensualite_max = round(max(mensualites), 2) if mensualites else 0.0

        return ScenarioResult(
            nom=nom,
            label=label,
            cout_total_interets=cout_total,
            mensualite_moyenne=mensualite_moyenne,
            mensualite_min=mensualite_min,
            mensualite_max=mensualite_max,
            difference_vs_fixe=round(cout_total - cout_total_fixe, 2),
            graphe_data=graphe,
        )
