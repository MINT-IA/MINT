"""
Debt repayment planner — avalanche vs snowball strategies.

Calculates a month-by-month repayment plan for multiple debts using
either the avalanche (highest rate first) or snowball (smallest balance
first) strategy. Compares both to show the trade-off between optimal
(avalanche) and psychologically motivating (snowball).

Sources:
    - LCD (Loi sur le credit a la consommation) — taux max legal
    - LP art. 93 (minimum vital insaisissable)

Sprint S16 — Gap G6: Prevention dette.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un avis financier ou juridique. Les projections sont basees sur les "
    "donnees fournies et supposent des conditions stables. Consultez un ou "
    "une specialiste en desendettement pour une analyse personnalisee."
)


@dataclass
class DebtItem:
    """A single debt to repay."""
    nom: str
    montant: float          # Remaining balance (CHF)
    taux: float             # Annual interest rate (0-1)
    mensualite_min: float   # Minimum monthly payment (CHF)


@dataclass
class MonthlyEntry:
    """A single month in the repayment plan."""
    mois: int               # Month number (1-based)
    dette_nom: str          # Name of debt being targeted
    paiement: float         # Payment this month (CHF)
    dont_interets: float    # Interest portion (CHF)
    dont_capital: float     # Principal portion (CHF)
    solde_restant: float    # Remaining balance after payment (CHF)


@dataclass
class DebtPayoffEntry:
    """Summary of when a specific debt is paid off."""
    nom: str
    mois_liberation: int     # Month when this debt is fully paid off
    total_interets: float    # Total interest paid on this debt (CHF)
    montant_initial: float   # Initial balance (CHF)


@dataclass
class RepaymentPlanResult:
    """Complete result of a repayment plan."""

    strategie: str                # "avalanche" or "boule_de_neige"
    duree_mois: int               # Total months to become debt-free
    total_interets: float         # Total interest paid (CHF)
    total_rembourse: float        # Total amount repaid (CHF)
    plan_mensuel: List[MonthlyEntry]  # Month-by-month plan (first 12 + last month)
    payoffs: List[DebtPayoffEntry]    # When each debt is paid off

    # Metadata
    budget_mensuel: float
    nb_dettes: int

    # Compliance
    chiffre_choc: str
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


@dataclass
class RepaymentComparisonResult:
    """Comparison of avalanche vs snowball strategies."""

    avalanche: RepaymentPlanResult
    boule_de_neige: RepaymentPlanResult

    # Delta
    difference_interets: float     # Avalanche saves this much in interest (CHF)
    difference_mois: int           # Avalanche is this many months faster

    # Compliance
    chiffre_choc: str
    disclaimer: str = DISCLAIMER


class RepaymentService:
    """Plan debt repayment using avalanche or snowball strategy.

    Strategies:
    - Avalanche: pay minimum on all debts, extra goes to highest rate first.
      Mathematically optimal (minimizes interest paid).
    - Snowball (boule de neige): pay minimum on all, extra goes to smallest
      balance first. Psychologically motivating (quick wins).

    The service compares both and shows the trade-off.

    Sources:
        - LCD (Loi sur le credit a la consommation)
        - LP art. 93 (minimum vital)
    """

    MAX_MONTHS = 600  # Safety limit: 50 years

    def plan_repayment(
        self,
        dettes: List[dict],
        budget_mensuel_remboursement: float,
        strategie: str = "avalanche",
    ) -> RepaymentPlanResult:
        """Plan a debt repayment schedule.

        Args:
            dettes: List of debts, each with {nom, montant, taux, mensualite_min}.
            budget_mensuel_remboursement: Total monthly budget for debt repayment (CHF).
            strategie: "avalanche" or "boule_de_neige".

        Returns:
            RepaymentPlanResult with month-by-month plan.
        """
        # Parse debts
        debt_items = [
            DebtItem(
                nom=d.get("nom", f"Dette {i+1}"),
                montant=max(0.0, float(d.get("montant", 0))),
                taux=max(0.0, min(0.30, float(d.get("taux", 0)))),
                mensualite_min=max(0.0, float(d.get("mensualite_min", 0))),
            )
            for i, d in enumerate(dettes)
        ]

        # Filter out zero-balance debts
        debt_items = [d for d in debt_items if d.montant > 0]

        if not debt_items:
            return self._empty_result(strategie, budget_mensuel_remboursement)

        budget = max(0.0, budget_mensuel_remboursement)

        # Ensure budget covers at least all minimum payments
        total_min = sum(d.mensualite_min for d in debt_items)
        if budget < total_min:
            budget = total_min

        # Sort debts by strategy
        if strategie == "boule_de_neige":
            debt_items.sort(key=lambda d: d.montant)  # Smallest balance first
        else:
            debt_items.sort(key=lambda d: d.taux, reverse=True)  # Highest rate first

        # Simulate month by month
        balances = {d.nom: d.montant for d in debt_items}
        plan: List[MonthlyEntry] = []
        payoffs: List[DebtPayoffEntry] = []
        total_interest = 0.0
        interest_per_debt = {d.nom: 0.0 for d in debt_items}
        initial_amounts = {d.nom: d.montant for d in debt_items}

        mois = 0
        while any(b > 0.01 for b in balances.values()) and mois < self.MAX_MONTHS:
            mois += 1
            remaining_budget = budget

            # 1. Pay minimums on all active debts
            payments = {}
            for d in debt_items:
                if balances[d.nom] <= 0.01:
                    continue
                # Monthly interest
                monthly_rate = d.taux / 12
                interest = round(balances[d.nom] * monthly_rate, 2)
                interest_per_debt[d.nom] += interest
                total_interest += interest

                payment = min(d.mensualite_min, balances[d.nom] + interest)
                payments[d.nom] = {"paiement": payment, "interets": interest}
                remaining_budget -= payment

            # 2. Extra budget goes to priority debt (per strategy)
            for d in debt_items:
                if balances[d.nom] <= 0.01:
                    continue
                if remaining_budget <= 0:
                    break

                extra = min(remaining_budget, balances[d.nom] + payments[d.nom]["interets"] - payments[d.nom]["paiement"])
                if extra > 0:
                    payments[d.nom]["paiement"] += extra
                    remaining_budget -= extra

            # 3. Apply payments and record entries
            for d in debt_items:
                if d.nom not in payments:
                    continue

                p = payments[d.nom]
                paiement = p["paiement"]
                interets = p["interets"]
                capital = round(paiement - interets, 2)
                capital = max(0.0, capital)

                balances[d.nom] = round(balances[d.nom] - capital, 2)
                if balances[d.nom] < 0.01:
                    balances[d.nom] = 0.0

                plan.append(MonthlyEntry(
                    mois=mois,
                    dette_nom=d.nom,
                    paiement=round(paiement, 2),
                    dont_interets=interets,
                    dont_capital=capital,
                    solde_restant=balances[d.nom],
                ))

                # Check if debt is paid off
                if balances[d.nom] <= 0 and d.nom not in [p.nom for p in payoffs]:
                    payoffs.append(DebtPayoffEntry(
                        nom=d.nom,
                        mois_liberation=mois,
                        total_interets=round(interest_per_debt[d.nom], 2),
                        montant_initial=initial_amounts[d.nom],
                    ))

        total_interest = round(total_interest, 2)
        total_rembourse = round(sum(initial_amounts.values()) + total_interest, 2)

        # Chiffre choc
        strat_label = "avalanche" if strategie == "avalanche" else "boule de neige"
        chiffre_choc = (
            f"Libere de toutes tes dettes dans {mois} mois "
            f"({total_interest:,.0f} CHF d'interets avec la strategie {strat_label})"
        ).replace(",", "'")

        # Keep only a summary of the plan (first 12 months + last month)
        plan_summary = [e for e in plan if e.mois <= 12 or e.mois == mois]

        sources = [
            "LCD (Loi sur le credit a la consommation — taux max legal)",
            "LP art. 93 (minimum vital insaisissable)",
            "SchKG (Loi sur la poursuite et faillite)",
        ]

        return RepaymentPlanResult(
            strategie=strategie,
            duree_mois=mois,
            total_interets=total_interest,
            total_rembourse=total_rembourse,
            plan_mensuel=plan_summary,
            payoffs=payoffs,
            budget_mensuel=budget,
            nb_dettes=len(debt_items),
            chiffre_choc=chiffre_choc,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def compare_strategies(
        self,
        dettes: List[dict],
        budget_mensuel_remboursement: float,
    ) -> RepaymentComparisonResult:
        """Compare avalanche vs snowball strategies.

        Args:
            dettes: List of debts.
            budget_mensuel_remboursement: Monthly repayment budget (CHF).

        Returns:
            RepaymentComparisonResult with both plans and delta.
        """
        avalanche = self.plan_repayment(dettes, budget_mensuel_remboursement, "avalanche")
        boule = self.plan_repayment(dettes, budget_mensuel_remboursement, "boule_de_neige")

        diff_interets = round(boule.total_interets - avalanche.total_interets, 2)
        diff_mois = boule.duree_mois - avalanche.duree_mois

        chiffre_choc = (
            f"Libere de toutes tes dettes dans {avalanche.duree_mois} mois "
            f"({diff_interets:,.0f} CHF d'interets economises avec la strategie avalanche)"
        ).replace(",", "'")

        return RepaymentComparisonResult(
            avalanche=avalanche,
            boule_de_neige=boule,
            difference_interets=diff_interets,
            difference_mois=diff_mois,
            chiffre_choc=chiffre_choc,
            disclaimer=DISCLAIMER,
        )

    def _empty_result(self, strategie: str, budget: float) -> RepaymentPlanResult:
        """Return an empty result when there are no debts."""
        return RepaymentPlanResult(
            strategie=strategie,
            duree_mois=0,
            total_interets=0.0,
            total_rembourse=0.0,
            plan_mensuel=[],
            payoffs=[],
            budget_mensuel=budget,
            nb_dettes=0,
            chiffre_choc="Aucune dette a rembourser — felicitations!",
            sources=[],
            disclaimer=DISCLAIMER,
        )
