"""
Arbitrage Models — Dataclasses for rente vs capital and allocation annuelle.

Sprint S32 — Arbitrage Phase 1.

These models define the input/output contracts for arbitrage comparisons:
- YearlySnapshot: year-by-year patrimony evolution
- TrajectoireOption: a single option trajectory (rente, capital, mixed, 3a, etc.)
- ArbitrageResult: complete comparison result with compliance fields

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - OPP3 art. 7 (plafond 3a)
"""

from dataclasses import dataclass
from typing import Dict, List, Optional


@dataclass
class YearlySnapshot:
    """Year-by-year snapshot of patrimony evolution.

    Tracks net worth, cashflow, and cumulative tax delta
    for a given option at a given year.
    """

    year: int
    net_patrimony: float        # Total net worth at year-end
    annual_cashflow: float      # Net in/out that year
    cumulative_tax_delta: float  # vs baseline


@dataclass
class TrajectoireOption:
    """A single option trajectory in an arbitrage comparison.

    Each option represents a different financial strategy
    (full rente, full capital, mixed, 3a, rachat LPP, etc.)
    with its year-by-year evolution and terminal value.
    """

    id: str                     # "full_rente", "full_capital", "mixed", etc.
    label: str                  # User-facing label (French)
    trajectory: List[YearlySnapshot]
    terminal_value: float       # End-of-horizon net patrimony
    cumulative_tax_impact: float  # Total tax paid/saved over horizon


@dataclass
class ArbitrageResult:
    """Complete result of an arbitrage comparison.

    Contains all options with trajectories, breakeven analysis,
    sensitivity analysis, and mandatory compliance fields.
    """

    options: List[TrajectoireOption]
    breakeven_year: int          # Year when curves cross (-1 if never)
    chiffre_choc: str            # Single most striking delta
    display_summary: str         # One-sentence summary (French, informal)
    hypotheses: List[str]        # ALWAYS explicit -- user can modify
    disclaimer: str              # ALWAYS present
    sources: List[str]           # Legal references
    confidence_score: float      # 0-100
    sensitivity: Dict[str, float]  # Key: parameter name, Value: impact of +/-1%


def compute_terminal_spread(options: List[TrajectoireOption]) -> float:
    """Compute the spread between best and worst terminal values.

    Used as the Tornado hero metric for arbitrage modules so each variable
    impact is measured against the same target.
    """
    if len(options) < 2:
        return 0.0
    terminal_values = [o.terminal_value for o in options]
    return max(terminal_values) - min(terminal_values)


def add_tornado_sensitivity(
    sensitivity: Dict[str, float],
    key: str,
    *,
    base_value: float,
    low_value: float,
    high_value: float,
    assumption_low: Optional[float] = None,
    assumption_high: Optional[float] = None,
) -> None:
    """Add standardized Tornado entries into the sensitivity map.

    Keeps backward compatibility via `sensitivity[key]` while adding explicit
    low/high/base/swing values for chart reconstruction on mobile.
    """
    swing = abs(high_value - low_value)
    sensitivity[key] = round(swing, 2)
    sensitivity[f"tornado_{key}_base"] = round(base_value, 2)
    sensitivity[f"tornado_{key}_low"] = round(low_value, 2)
    sensitivity[f"tornado_{key}_high"] = round(high_value, 2)
    sensitivity[f"tornado_{key}_swing"] = round(swing, 2)

    if assumption_low is not None:
        sensitivity[f"tornado_{key}_assumption_low"] = round(assumption_low, 6)
    if assumption_high is not None:
        sensitivity[f"tornado_{key}_assumption_high"] = round(assumption_high, 6)
