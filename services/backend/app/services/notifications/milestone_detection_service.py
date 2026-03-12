"""
Milestone Detection Service — Sprint S36.

Compares current vs previous financial snapshot to detect newly crossed milestones.

COMPLIANCE:
    - NEVER use social comparison ("top 20% des Suisses" -> BANNED)
    - NEVER guarantee future outcomes ("tu es securise" -> BANNED)
    - Always factual: what was achieved, what it means concretely
    - All text in French (informal "tu")
    - CHF formatted with Swiss apostrophe (1'820)

Sources:
    - OPP3 art. 7 (plafond 3a : 7'258 CHF)
    - LPP art. 79b (rachat LPP)
    - LSFin art. 3 (obligation d'information)
"""

from datetime import datetime
from typing import List

from app.constants.social_insurance import PILIER_3A_PLAFOND_AVEC_LPP
from app.services.notifications.notification_models import (
    DetectedMilestone,
    MilestoneCheckResult,
    MilestoneType,
)

# 3a plafond salarie 2025/2026
THREE_A_PLAFOND_SALARIE = PILIER_3A_PLAFOND_AVEC_LPP


def _format_chf(amount: float) -> str:
    """Format a CHF amount with Swiss apostrophe grouping."""
    rounded = round(amount)
    if rounded < 0:
        return f"-{_format_chf(-amount)}"
    s = str(rounded)
    parts: List[str] = []
    while len(s) > 3:
        parts.append(s[-3:])
        s = s[:-3]
    parts.append(s)
    return "\u2019".join(reversed(parts))


def _crossed_threshold(current_val: float, previous_val: float, threshold: float) -> bool:
    """Return True if threshold was crossed upward between previous and current."""
    return current_val >= threshold and previous_val < threshold


class MilestoneDetectionService:
    """Detects milestones by comparing current vs previous snapshot.

    All methods are pure functions (no side effects, no I/O).
    """

    def detect_milestones(
        self,
        current: dict,
        previous: dict,
        check_in_streak: int = 0,
        arbitrage_count: int = 0,
    ) -> MilestoneCheckResult:
        """Compare current vs previous snapshot and detect new milestones.

        Args:
            current: Current financial snapshot dict. Expected keys:
                - months_liquidity (float)
                - three_a_contribution (float)
                - lpp_buyback_completed (bool)
                - fri_total (float)
                - patrimoine (float)
                - tax_saving_3a (float, optional — for celebration text)
            previous: Previous financial snapshot dict (same keys, or empty dict).
            check_in_streak: Number of consecutive monthly check-ins.
            arbitrage_count: Number of arbitrage actions completed.

        Returns:
            MilestoneCheckResult with list of newly detected milestones.
        """
        milestones: List[DetectedMilestone] = []
        now = datetime.now()

        # --- Extract values with safe defaults ---
        curr_liquidity = float(current.get("months_liquidity", 0))
        prev_liquidity = float(previous.get("months_liquidity", 0))

        curr_3a = float(current.get("three_a_contribution", 0))
        prev_3a = float(previous.get("three_a_contribution", 0))

        curr_lpp_buyback = bool(current.get("lpp_buyback_completed", False))
        prev_lpp_buyback = bool(previous.get("lpp_buyback_completed", False))

        curr_fri = float(current.get("fri_total", 0))
        prev_fri = float(previous.get("fri_total", 0))

        curr_patrimoine = float(current.get("patrimoine", 0))
        prev_patrimoine = float(previous.get("patrimoine", 0))

        curr_tax_saving = float(current.get("tax_saving_3a", 0))

        prev_arbitrage = int(previous.get("arbitrage_count", 0))
        prev_streak = int(previous.get("check_in_streak", 0))

        # ------------------------------------------------------------------
        # Emergency fund milestones
        # ------------------------------------------------------------------
        if _crossed_threshold(curr_liquidity, prev_liquidity, 3.0):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.emergency_fund_3_months,
                    celebration_text=(
                        f"Reserve de liquidite : {curr_liquidity:.1f} mois. "
                        f"L\u2019equivalent de 3 mois de charges."
                    ),
                    concrete_value=f"{curr_liquidity:.1f} mois",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_liquidity, prev_liquidity, 6.0):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.emergency_fund_6_months,
                    celebration_text=(
                        f"Reserve de liquidite : {curr_liquidity:.1f} mois. "
                        f"L\u2019equivalent de 6 mois de charges."
                    ),
                    concrete_value=f"{curr_liquidity:.1f} mois",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # 3a plafond
        # ------------------------------------------------------------------
        if _crossed_threshold(curr_3a, prev_3a, THREE_A_PLAFOND_SALARIE):
            saving_text = _format_chf(curr_tax_saving) if curr_tax_saving > 0 else "variable"
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.three_a_max_reached,
                    celebration_text=(
                        f"Plafond 3a atteint \u2014 CHF 7\u2019258. "
                        f"Economie fiscale estimee : ~CHF {saving_text}."
                    ),
                    concrete_value="CHF 7\u2019258",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # LPP buyback
        # ------------------------------------------------------------------
        if curr_lpp_buyback and not prev_lpp_buyback:
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.lpp_buyback_completed,
                    celebration_text=(
                        "Rachat LPP effectue. "
                        "Deduction fiscale applicable cette annee (LPP art. 79b)."
                    ),
                    concrete_value="rachat LPP",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # FRI milestones
        # ------------------------------------------------------------------
        fri_delta = curr_fri - prev_fri
        if fri_delta >= 10.0 and prev_fri > 0:
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.fri_improved_10_points,
                    celebration_text=(
                        f"Score de solidite : +{fri_delta:.0f} points. "
                        f"De {prev_fri:.0f} a {curr_fri:.0f}/100."
                    ),
                    concrete_value=f"+{fri_delta:.0f} points",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_fri, prev_fri, 50.0):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.fri_above_50,
                    celebration_text=(
                        f"Score de solidite : {curr_fri:.0f}/100. "
                        f"Au-dessus du seuil de 50."
                    ),
                    concrete_value=f"{curr_fri:.0f}/100",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_fri, prev_fri, 70.0):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.fri_above_70,
                    celebration_text=(
                        f"Score de solidite : {curr_fri:.0f}/100. "
                        f"Au-dessus du seuil de 70."
                    ),
                    concrete_value=f"{curr_fri:.0f}/100",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_fri, prev_fri, 85.0):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.fri_above_85,
                    celebration_text=(
                        f"Score de solidite : {curr_fri:.0f}/100. "
                        f"Au-dessus du seuil de 85."
                    ),
                    concrete_value=f"{curr_fri:.0f}/100",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # Patrimoine milestones
        # ------------------------------------------------------------------
        if _crossed_threshold(curr_patrimoine, prev_patrimoine, 50_000):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.patrimoine_50k,
                    celebration_text=(
                        f"Patrimoine estime : CHF {_format_chf(curr_patrimoine)}. "
                        f"Seuil de CHF 50\u2019000 franchi."
                    ),
                    concrete_value=f"CHF {_format_chf(curr_patrimoine)}",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_patrimoine, prev_patrimoine, 100_000):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.patrimoine_100k,
                    celebration_text=(
                        f"Patrimoine estime : CHF {_format_chf(curr_patrimoine)}. "
                        f"Seuil de CHF 100\u2019000 franchi."
                    ),
                    concrete_value=f"CHF {_format_chf(curr_patrimoine)}",
                    detected_at=now,
                )
            )

        if _crossed_threshold(curr_patrimoine, prev_patrimoine, 250_000):
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.patrimoine_250k,
                    celebration_text=(
                        f"Patrimoine estime : CHF {_format_chf(curr_patrimoine)}. "
                        f"Seuil de CHF 250\u2019000 franchi."
                    ),
                    concrete_value=f"CHF {_format_chf(curr_patrimoine)}",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # Arbitrage
        # ------------------------------------------------------------------
        if arbitrage_count >= 1 and prev_arbitrage < 1:
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.first_arbitrage_completed,
                    celebration_text=(
                        f"Premier arbitrage complete. "
                        f"{arbitrage_count} action(s) realisee(s)."
                    ),
                    concrete_value=f"{arbitrage_count} arbitrage(s)",
                    detected_at=now,
                )
            )

        # ------------------------------------------------------------------
        # Check-in streaks
        # ------------------------------------------------------------------
        if check_in_streak >= 6 and prev_streak < 6:
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.check_in_streak_6_months,
                    celebration_text=(
                        f"{check_in_streak} check-ins consecutifs. "
                        f"6 mois de suivi regulier."
                    ),
                    concrete_value=f"{check_in_streak} check-ins",
                    detected_at=now,
                )
            )

        if check_in_streak >= 12 and prev_streak < 12:
            milestones.append(
                DetectedMilestone(
                    milestone_type=MilestoneType.check_in_streak_12_months,
                    celebration_text=(
                        f"{check_in_streak} check-ins consecutifs. "
                        f"12 mois de suivi regulier."
                    ),
                    concrete_value=f"{check_in_streak} check-ins",
                    detected_at=now,
                )
            )

        return MilestoneCheckResult(new_milestones=milestones)
