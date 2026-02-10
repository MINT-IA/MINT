"""
Direct vs Indirect amortization comparator.

Swiss-specific concept:
- Direct (Direktamortisation): repay mortgage directly -> debt decreases,
  interest decreases, tax deductions decrease over time.
- Indirect (Indirekte Amortisation): contribute to a pledged 3a account
  instead -> debt stays CONSTANT, interest stays constant, deductions are
  MAXIMIZED (mortgage interest + 3a deduction), and capital grows in 3a.

The indirect method is often more tax-efficient over the long term.

Sources:
    - OPP3 art. 1 (3e pilier lie)
    - LIFD art. 33 al. 1 let. a (deduction interets passifs)
    - LIFD art. 33 al. 1 let. e (deduction 3a)
    - Pratique bancaire suisse (amortissement indirect)

Sprint S17 — Mortgage & Real Estate.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en financement immobilier ni en prevoyance au sens de la "
    "LSFin. L'amortissement indirect implique des risques (le rendement 3a "
    "peut varier). Consultez un ou une specialiste pour une analyse personnalisee."
)

# 3a annual contribution limit (salarie affilie LPP, 2025/2026)
PLAFOND_3A_SALARIE = 7_258


@dataclass
class GrapheEntry:
    """Single year entry for the comparison chart."""
    annee: int
    dette_direct: float
    dette_indirect: float
    capital_3a: float
    cout_cumule_direct: float
    cout_cumule_indirect: float


@dataclass
class ChiffreChoc:
    """Shock figure with amount and explanatory text."""
    montant: float
    texte: str


@dataclass
class AmortDirectResult:
    """Result for direct amortization."""
    dette_finale: float
    interets_payes_total: float
    deduction_fiscale_cumulee: float
    cout_net_total: float


@dataclass
class AmortIndirectResult:
    """Result for indirect amortization."""
    dette_finale: float             # Stays constant
    interets_payes_total: float     # Constant interest payments
    deduction_fiscale_cumulee: float  # Interest + 3a deductions
    capital_3a_cumule: float        # 3a capital at end
    cout_net_total: float


@dataclass
class AmortizationComparisonResult:
    """Complete result of the direct vs indirect comparison."""

    # Direct
    direct: AmortDirectResult

    # Indirect
    indirect: AmortIndirectResult

    # Difference
    difference_nette: float    # Positive = indirect is cheaper
    methode_avantageuse: str   # "direct" or "indirect"

    # Shock figure
    chiffre_choc: ChiffreChoc

    # Graph data
    graphe_data: List[GrapheEntry]

    # Input metadata
    montant_hypothecaire: float
    taux_interet: float
    duree_ans: int
    versement_annuel: float
    taux_marginal_imposition: float
    rendement_3a: float
    canton: str

    # Compliance
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class AmortizationService:
    """Compare direct vs indirect mortgage amortization.

    Direct: annual payment reduces the mortgage debt directly.
    Indirect: annual payment goes to a pledged 3a account; the mortgage
    debt stays unchanged until the 3a capital is used to repay at maturity.

    The fiscal advantage of indirect amortization comes from:
    1. Constant (higher) mortgage interest deduction
    2. Additional 3a tax deduction
    3. Potential 3a investment returns (tax-free growth)

    Sources:
        - OPP3 art. 1 (3a)
        - LIFD art. 33 (deductions)
        - Pratique bancaire suisse
    """

    def compare(
        self,
        montant_hypothecaire: float,
        taux_interet: float,
        duree_ans: int = 15,
        versement_annuel_amortissement: float = 0.0,
        taux_marginal_imposition: float = 0.30,
        rendement_3a: float = 0.02,
        canton: str = "ZH",
    ) -> AmortizationComparisonResult:
        """Compare direct vs indirect amortization.

        Args:
            montant_hypothecaire: Initial mortgage amount (CHF).
            taux_interet: Mortgage interest rate (0-1), e.g. 0.02 for 2%.
            duree_ans: Duration in years (1-40).
            versement_annuel_amortissement: Annual amortization payment (CHF).
            taux_marginal_imposition: Marginal tax rate (0-1).
            rendement_3a: Expected annual return on 3a investment (0-1).
            canton: Canton code (for context).

        Returns:
            AmortizationComparisonResult with full comparison.
        """
        # Sanitize inputs
        montant_hypothecaire = max(0.0, montant_hypothecaire)
        taux_interet = max(0.0, min(0.10, taux_interet))
        duree_ans = max(1, min(40, duree_ans))
        taux_marginal = max(0.0, min(0.50, taux_marginal_imposition))
        rendement_3a = max(-0.05, min(0.10, rendement_3a))
        canton = (canton.upper() if canton else "ZH")[:2]

        # Default versement: 1% of mortgage (common practice)
        if versement_annuel_amortissement <= 0:
            versement_annuel_amortissement = montant_hypothecaire * 0.01

        # Cap at 3a limit for indirect comparison
        versement_indirect_3a = min(versement_annuel_amortissement, PLAFOND_3A_SALARIE)

        # ---- DIRECT AMORTIZATION ----
        direct = self._simulate_direct(
            montant=montant_hypothecaire,
            taux=taux_interet,
            duree=duree_ans,
            versement=versement_annuel_amortissement,
            taux_marginal=taux_marginal,
        )

        # ---- INDIRECT AMORTIZATION ----
        indirect = self._simulate_indirect(
            montant=montant_hypothecaire,
            taux=taux_interet,
            duree=duree_ans,
            versement_3a=versement_indirect_3a,
            taux_marginal=taux_marginal,
            rendement_3a=rendement_3a,
        )

        # ---- COMPARISON ----
        difference = round(direct.cout_net_total - indirect.cout_net_total, 2)
        methode_avantageuse = "indirect" if difference > 0 else "direct"

        # ---- GRAPH DATA ----
        graphe = self._build_graph(
            montant=montant_hypothecaire,
            taux=taux_interet,
            duree=duree_ans,
            versement_direct=versement_annuel_amortissement,
            versement_3a=versement_indirect_3a,
            taux_marginal=taux_marginal,
            rendement_3a=rendement_3a,
        )

        # ---- CHIFFRE CHOC ----
        if difference > 0:
            chiffre_choc = ChiffreChoc(
                montant=abs(difference),
                texte=(
                    f"L'amortissement indirect te fait economiser "
                    f"{abs(difference):,.0f} CHF sur {duree_ans} ans "
                    f"par rapport a l'amortissement direct."
                ),
            )
        elif difference < 0:
            chiffre_choc = ChiffreChoc(
                montant=abs(difference),
                texte=(
                    f"L'amortissement direct est plus avantageux de "
                    f"{abs(difference):,.0f} CHF sur {duree_ans} ans dans ce scenario."
                ),
            )
        else:
            chiffre_choc = ChiffreChoc(
                montant=0.0,
                texte=(
                    "Les deux methodes sont equivalentes dans ce scenario. "
                    "L'indirect offre davantage de flexibilite."
                ),
            )

        # ---- SOURCES ----
        sources = [
            "OPP3 art. 1 (3e pilier lie — amortissement indirect)",
            "LIFD art. 33 al. 1 let. a (deduction des interets hypothecaires)",
            "LIFD art. 33 al. 1 let. e (deduction des cotisations 3a)",
            "Pratique bancaire suisse (amortissement direct vs indirect)",
        ]

        return AmortizationComparisonResult(
            direct=direct,
            indirect=indirect,
            difference_nette=difference,
            methode_avantageuse=methode_avantageuse,
            chiffre_choc=chiffre_choc,
            graphe_data=graphe,
            montant_hypothecaire=montant_hypothecaire,
            taux_interet=taux_interet,
            duree_ans=duree_ans,
            versement_annuel=versement_annuel_amortissement,
            taux_marginal_imposition=taux_marginal,
            rendement_3a=rendement_3a,
            canton=canton,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _simulate_direct(
        self,
        montant: float,
        taux: float,
        duree: int,
        versement: float,
        taux_marginal: float,
    ) -> AmortDirectResult:
        """Simulate direct amortization."""
        dette = montant
        total_interets = 0.0
        total_deduction_fiscale = 0.0

        for _ in range(duree):
            interets = dette * taux
            total_interets += interets

            # Tax deduction on interest only (no 3a deduction in direct)
            deduction = interets * taux_marginal
            total_deduction_fiscale += deduction

            # Reduce the debt
            dette = max(0.0, dette - versement)

        cout_net = round(total_interets - total_deduction_fiscale, 2)

        return AmortDirectResult(
            dette_finale=round(dette, 2),
            interets_payes_total=round(total_interets, 2),
            deduction_fiscale_cumulee=round(total_deduction_fiscale, 2),
            cout_net_total=cout_net,
        )

    def _simulate_indirect(
        self,
        montant: float,
        taux: float,
        duree: int,
        versement_3a: float,
        taux_marginal: float,
        rendement_3a: float,
    ) -> AmortIndirectResult:
        """Simulate indirect amortization via pledged 3a."""
        # Debt stays constant
        dette = montant
        interets_annuels = dette * taux
        total_interets = interets_annuels * duree

        # Tax deductions: mortgage interest + 3a contributions
        total_deduction = 0.0
        capital_3a = 0.0

        for _ in range(duree):
            # Deduction = interest deduction + 3a deduction
            deduction = (interets_annuels + versement_3a) * taux_marginal
            total_deduction += deduction

            # 3a capital grows
            capital_3a = (capital_3a + versement_3a) * (1 + rendement_3a)

        capital_3a = round(capital_3a, 2)

        # Net cost = total interest - total tax savings - 3a capital gain
        # The 3a capital will be used to repay at maturity,
        # but we show net cost as: interest paid - tax savings
        # (3a capital offsets future repayment, so it's a benefit)
        total_verse_3a = versement_3a * duree
        gain_3a = capital_3a - total_verse_3a

        cout_net = round(total_interets - total_deduction - gain_3a, 2)

        return AmortIndirectResult(
            dette_finale=round(dette, 2),
            interets_payes_total=round(total_interets, 2),
            deduction_fiscale_cumulee=round(total_deduction, 2),
            capital_3a_cumule=capital_3a,
            cout_net_total=cout_net,
        )

    def _build_graph(
        self,
        montant: float,
        taux: float,
        duree: int,
        versement_direct: float,
        versement_3a: float,
        taux_marginal: float,
        rendement_3a: float,
    ) -> List[GrapheEntry]:
        """Build year-by-year graph data for both methods."""
        entries: List[GrapheEntry] = []
        dette_direct = montant
        dette_indirect = montant
        capital_3a = 0.0
        cout_cumule_direct = 0.0
        cout_cumule_indirect = 0.0

        for annee in range(1, duree + 1):
            # Direct: interest on reducing balance
            interets_direct = dette_direct * taux
            deduction_direct = interets_direct * taux_marginal
            cout_net_direct = interets_direct - deduction_direct
            cout_cumule_direct += cout_net_direct
            dette_direct = max(0.0, dette_direct - versement_direct)

            # Indirect: interest on constant balance + 3a growth
            interets_indirect = dette_indirect * taux
            deduction_indirect = (interets_indirect + versement_3a) * taux_marginal
            capital_3a = (capital_3a + versement_3a) * (1 + rendement_3a)
            total_verse_3a = versement_3a * annee
            gain_3a_ytd = capital_3a - total_verse_3a
            cout_net_indirect_ytd = (interets_indirect * annee
                                     - deduction_indirect * annee
                                     - gain_3a_ytd)
            cout_cumule_indirect = round(cout_net_indirect_ytd, 2)

            entries.append(GrapheEntry(
                annee=annee,
                dette_direct=round(dette_direct, 2),
                dette_indirect=round(dette_indirect, 2),
                capital_3a=round(capital_3a, 2),
                cout_cumule_direct=round(cout_cumule_direct, 2),
                cout_cumule_indirect=cout_cumule_indirect,
            ))

        return entries
