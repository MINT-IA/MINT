"""
LAMal Franchise Optimizer Service.

Calculates the optimal health insurance franchise based on estimated
health expenses and current premium. Compares all franchise levels
and finds the break-even points.

Sources:
    - LAMal art. 62-64 (franchise et quote-part)
    - OAMal (ordonnance sur l'assurance-maladie)
    - BAG data 2024 (approximate premium differences)

MINT is un outil educatif. Ce service ne constitue pas un conseil
en assurance au sens de la LSFin/LCA.
"""

from dataclasses import dataclass, field
from typing import List, Optional


# ---------------------------------------------------------------------------
# Constants (LAMal art. 62-64, OAMal)
# ---------------------------------------------------------------------------

FRANCHISE_LEVELS_ADULT = [300, 500, 1000, 1500, 2000, 2500]
FRANCHISE_LEVELS_CHILD = [0, 100, 200, 300, 400, 500, 600]

# Quote-part: 10% of costs above franchise
QUOTE_PART_RATE = 0.10
QUOTE_PART_CAP_ADULT = 700.0   # CHF/year
QUOTE_PART_CAP_CHILD = 350.0   # CHF/year

# Approximate premium savings vs franchise 300 (based on BAG 2024 data)
# These are percentage savings on the annual premium.
SAVINGS_VS_300_ADULT = {
    300: 0.00,
    500: 0.05,
    1000: 0.13,
    1500: 0.19,
    2000: 0.24,
    2500: 0.28,
}

# Children: approximate savings vs franchise 0
SAVINGS_VS_0_CHILD = {
    0: 0.00,
    100: 0.02,
    200: 0.04,
    300: 0.06,
    400: 0.08,
    500: 0.10,
    600: 0.12,
}

# Franchise change deadline
FRANCHISE_CHANGE_DEADLINE = "30 novembre"

DISCLAIMER = (
    "Ces calculs sont fournis a titre educatif et indicatif. "
    "Les primes varient selon le canton, l'assureur et le modele d'assurance. "
    "MINT ne constitue pas un conseil en assurance au sens de la LCA. "
    "Comparez les offres sur priminfo.admin.ch avant toute decision."
)


# ---------------------------------------------------------------------------
# Input / Output dataclasses
# ---------------------------------------------------------------------------

@dataclass
class LamalFranchiseInput:
    """Input for franchise optimization."""
    prime_mensuelle_base: float   # Monthly premium at franchise 300 (adult) or 0 (child)
    depenses_sante_annuelles: float  # Estimated annual health expenses
    age_category: str = "adult"   # "adult" or "child"


@dataclass
class LamalFranchiseResult:
    """Result of franchise optimization."""
    comparaison: List[dict] = field(default_factory=list)
    franchise_optimale: int = 300
    break_even_points: List[dict] = field(default_factory=list)
    recommandations: List[dict] = field(default_factory=list)
    alerte_delai: str = ""
    disclaimer: str = ""


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class LamalFranchiseOptimizer:
    """Optimize LAMal franchise based on health expenses.

    For each franchise level, calculates the total annual cost:
      total = prime_annuelle * (1 - savings) + franchise_effective + quote_part

    Where:
      - franchise_effective = min(depenses_sante, franchise_level)
      - quote_part = min((depenses - franchise) * 10%, cap) if depenses > franchise else 0
    """

    def optimize(self, input_data: LamalFranchiseInput) -> LamalFranchiseResult:
        """Run the franchise optimization.

        Args:
            input_data: User's premium and health expense data.

        Returns:
            LamalFranchiseResult with comparison, optimal franchise, and recommendations.
        """
        is_child = input_data.age_category == "child"
        franchise_levels = FRANCHISE_LEVELS_CHILD if is_child else FRANCHISE_LEVELS_ADULT
        savings_table = SAVINGS_VS_0_CHILD if is_child else SAVINGS_VS_300_ADULT
        quote_part_cap = QUOTE_PART_CAP_CHILD if is_child else QUOTE_PART_CAP_ADULT

        prime_annuelle_base = input_data.prime_mensuelle_base * 12
        depenses = input_data.depenses_sante_annuelles

        # Calculate total cost for each franchise level
        comparaison = []
        ref_franchise = franchise_levels[0]  # Reference franchise (300 for adults, 0 for children)

        for franchise in franchise_levels:
            savings_pct = savings_table.get(franchise, 0.0)
            prime_annuelle = prime_annuelle_base * (1 - savings_pct)

            franchise_effective = min(depenses, franchise)
            if depenses > franchise:
                quote_part = min(
                    (depenses - franchise) * QUOTE_PART_RATE,
                    quote_part_cap,
                )
            else:
                quote_part = 0.0

            cout_total = prime_annuelle + franchise_effective + quote_part

            # Economy vs reference franchise (300 for adults, 0 for children)
            ref_savings = savings_table.get(ref_franchise, 0.0)
            ref_prime = prime_annuelle_base * (1 - ref_savings)
            ref_franchise_eff = min(depenses, ref_franchise)
            if depenses > ref_franchise:
                ref_qp = min(
                    (depenses - ref_franchise) * QUOTE_PART_RATE,
                    quote_part_cap,
                )
            else:
                ref_qp = 0.0
            ref_total = ref_prime + ref_franchise_eff + ref_qp

            economie = ref_total - cout_total

            comparaison.append({
                "franchise": franchise,
                "prime_annuelle": round(prime_annuelle, 2),
                "franchise_effective": round(franchise_effective, 2),
                "quote_part": round(quote_part, 2),
                "cout_total": round(cout_total, 2),
                "economie_vs_ref": round(economie, 2),
            })

        # Find optimal franchise (lowest total cost)
        optimal_entry = min(comparaison, key=lambda x: x["cout_total"])
        franchise_optimale = optimal_entry["franchise"]

        # Calculate break-even points
        break_even_points = self._calc_break_even_points(
            prime_annuelle_base, franchise_levels, savings_table, quote_part_cap
        )

        # Generate recommendations
        recommandations = self._generate_recommendations(
            depenses, franchise_optimale, is_child, prime_annuelle_base
        )

        # Deadline alert
        alerte_delai = (
            f"Rappel : le changement de franchise doit etre communique "
            f"a votre assureur avant le {FRANCHISE_CHANGE_DEADLINE} "
            f"pour l'annee suivante (LAMal art. 62)."
        )

        return LamalFranchiseResult(
            comparaison=comparaison,
            franchise_optimale=franchise_optimale,
            break_even_points=break_even_points,
            recommandations=recommandations,
            alerte_delai=alerte_delai,
            disclaimer=DISCLAIMER,
        )

    def _calc_break_even_points(
        self,
        prime_annuelle_base: float,
        franchise_levels: List[int],
        savings_table: dict,
        quote_part_cap: float,
    ) -> List[dict]:
        """Calculate break-even points between consecutive franchise levels.

        For each pair (franchise_basse, franchise_haute), find the health expense
        amount where both franchises produce the same total cost.

        The break-even is the expense level where switching from the lower to the
        higher franchise becomes beneficial. Below this level, the higher franchise
        is cheaper (lower premiums outweigh higher out-of-pocket). Above it, the
        lower franchise is cheaper.

        Returns:
            List of break-even dicts with franchise_basse, franchise_haute, seuil_depenses.
        """
        break_even_points = []

        for i in range(len(franchise_levels) - 1):
            f_low = franchise_levels[i]
            f_high = franchise_levels[i + 1]

            seuil = self._find_break_even(
                prime_annuelle_base, f_low, f_high,
                savings_table, quote_part_cap,
            )
            if seuil is not None:
                break_even_points.append({
                    "franchise_basse": f_low,
                    "franchise_haute": f_high,
                    "seuil_depenses": round(seuil, 0),
                })

        return break_even_points

    def _find_break_even(
        self,
        prime_base: float,
        f_low: int,
        f_high: int,
        savings_table: dict,
        qp_cap: float,
    ) -> Optional[float]:
        """Find the expense level where f_low and f_high have equal total cost.

        Uses a simple iterative approach: scan expenses from 0 to a reasonable max
        to find where cost_low crosses cost_high.

        Returns:
            The break-even expense amount, or None if not found.
        """
        s_low = savings_table.get(f_low, 0.0)
        s_high = savings_table.get(f_high, 0.0)

        prime_low = prime_base * (1 - s_low)
        prime_high = prime_base * (1 - s_high)

        # Premium savings from choosing f_high over f_low
        premium_savings = prime_low - prime_high  # positive: f_high is cheaper in premiums

        if premium_savings <= 0:
            return None

        # For expenses in [f_low, f_high]:
        #   cost_low = prime_low + expenses + (0 or small QP if expenses > f_low)
        #   cost_high = prime_high + expenses + 0
        # Wait, let me think more carefully.

        # cost(franchise, expenses) = prime + franchise_eff + quote_part
        # franchise_eff = min(expenses, franchise)
        # quote_part = min((expenses - franchise) * 0.10, cap) if expenses > franchise else 0

        # We look for the expense where cost_low == cost_high
        # Since costs are piecewise linear, we can check segments analytically.

        # At very low expenses (< f_low): both have franchise_eff = expenses, QP = 0
        #   cost_low = prime_low + expenses
        #   cost_high = prime_high + expenses
        #   cost_high < cost_low always (premium savings) => f_high is always better
        #   No crossover in this region.

        # At expenses in [f_low, f_high]:
        #   cost_low = prime_low + f_low + (expenses - f_low) * 0.10 [if not capped]
        #   cost_high = prime_high + expenses
        #   Setting equal: prime_low + f_low + (exp - f_low)*0.10 = prime_high + exp
        #   prime_low - prime_high + f_low + 0.10*exp - 0.10*f_low = exp
        #   premium_savings + 0.9*f_low + 0.10*exp = exp
        #   premium_savings + 0.9*f_low = 0.90*exp
        #   exp = (premium_savings + 0.9*f_low) / 0.90

        # Check segment [f_low, f_high] first (no QP cap for cost_low)
        # Check if the QP for cost_low would be capped:
        qp_at_f_high_for_low = (f_high - f_low) * QUOTE_PART_RATE
        low_qp_capped_in_segment = qp_at_f_high_for_low > qp_cap

        if not low_qp_capped_in_segment:
            # Simple case: QP not capped in this segment
            candidate = (premium_savings + 0.9 * f_low) / 0.90
            if f_low <= candidate <= f_high:
                return candidate

        # If QP capped or candidate out of range, try other segments
        # Use numerical approach for robustness
        max_expenses = max(f_high * 3, 20000)
        step = 10
        prev_diff = None
        for exp_x10 in range(0, int(max_expenses * 10), int(step * 10)):
            exp = exp_x10 / 10.0
            cost_low = self._total_cost(prime_base, f_low, s_low, exp, qp_cap)
            cost_high = self._total_cost(prime_base, f_high, s_high, exp, qp_cap)
            diff = cost_low - cost_high  # positive means f_high is cheaper

            if prev_diff is not None and prev_diff > 0 and diff <= 0:
                # Crossover found between exp - step and exp
                # Refine with smaller step
                for fine_x100 in range(int((exp - step) * 100), int(exp * 100)):
                    fine_exp = fine_x100 / 100.0
                    c_low = self._total_cost(prime_base, f_low, s_low, fine_exp, qp_cap)
                    c_high = self._total_cost(prime_base, f_high, s_high, fine_exp, qp_cap)
                    if c_low <= c_high:
                        return fine_exp
                return exp

            prev_diff = diff

        return None

    def _total_cost(
        self,
        prime_base: float,
        franchise: int,
        savings_pct: float,
        expenses: float,
        qp_cap: float,
    ) -> float:
        """Calculate total annual cost for a given franchise and expense level."""
        prime = prime_base * (1 - savings_pct)
        franchise_eff = min(expenses, franchise)
        if expenses > franchise:
            qp = min((expenses - franchise) * QUOTE_PART_RATE, qp_cap)
        else:
            qp = 0.0
        return prime + franchise_eff + qp

    def _generate_recommendations(
        self,
        depenses: float,
        franchise_optimale: int,
        is_child: bool,
        prime_annuelle_base: float,
    ) -> List[dict]:
        """Generate recommendations based on the optimization result.

        All recommendations include a legal source reference.
        """
        recommandations = []
        category = "enfant" if is_child else "adulte"

        if not is_child:
            if depenses < 500:
                recommandations.append({
                    "id": "lamal_low_expenses",
                    "titre": "Franchise elevee recommandee",
                    "description": (
                        f"Avec des depenses de sante estimees a {depenses:.0f} CHF/an, "
                        f"une franchise elevee ({franchise_optimale} CHF) permet "
                        f"de reduire vos primes. L'economie annuelle peut etre "
                        f"significative si vous etes en bonne sante."
                    ),
                    "source": "LAMal art. 62, OAMal art. 93-95",
                    "priorite": "haute",
                })
            elif depenses > 3000:
                recommandations.append({
                    "id": "lamal_high_expenses",
                    "titre": "Franchise basse recommandee",
                    "description": (
                        f"Avec des depenses de sante estimees a {depenses:.0f} CHF/an, "
                        f"une franchise basse ({franchise_optimale} CHF) limite "
                        f"vos couts totaux. La prime plus elevee est compensee "
                        f"par des frais a charge plus faibles."
                    ),
                    "source": "LAMal art. 62, OAMal art. 93-95",
                    "priorite": "haute",
                })
            else:
                recommandations.append({
                    "id": "lamal_medium_expenses",
                    "titre": "Franchise intermediaire a evaluer",
                    "description": (
                        f"Avec des depenses de sante estimees a {depenses:.0f} CHF/an, "
                        f"la franchise optimale calculee est de {franchise_optimale} CHF. "
                        f"Comparez les offres de votre assureur pour confirmer."
                    ),
                    "source": "LAMal art. 62, OAMal art. 93-95",
                    "priorite": "moyenne",
                })

        # Always recommend comparing on priminfo
        recommandations.append({
            "id": "lamal_compare_priminfo",
            "titre": "Comparer les primes sur priminfo.admin.ch",
            "description": (
                "Le comparateur officiel de l'OFSP permet de comparer "
                "les primes de tous les assureurs pour votre canton et "
                "votre modele d'assurance (medecin de famille, HMO, telmed)."
            ),
            "source": "LAMal art. 61, OFSP",
            "priorite": "haute",
        })

        # Reminder about complementary insurance
        recommandations.append({
            "id": "lamal_complementaire",
            "titre": "Dissocier base et complementaire",
            "description": (
                "L'assurance de base (LAMal) peut etre changee chaque annee. "
                "Les assurances complementaires (LCA) sont independantes et "
                "peuvent etre gardees chez un autre assureur."
            ),
            "source": "LAMal art. 7, LCA",
            "priorite": "moyenne",
        })

        return recommandations
