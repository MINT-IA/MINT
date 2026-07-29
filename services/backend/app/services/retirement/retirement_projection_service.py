"""Wave 1a D-02 — server-side orchestrator for get_retirement_projection.

Chains the 3 existing retirement services:
  - AvsEstimationService     (monthly AVS rente from age + salary)
  - LppConversionService     (LPP capital + monthly conversion at retirement)
  - RetirementBudgetService  (budget reconciliation at retirement age)

NO calculation logic re-implementation per CLAUDE.md rule 4
(financial_core reuse mandatory). This module ORCHESTRATES only.

Real API signatures verified 2026-05-14 by panel
(obs-54a6659a6008b907, obs-a5f5f19baeb3119b):
  AvsEstimationService().estimate(current_age, retirement_age=65, is_couple=False,
                                   annees_lacunes=0, life_expectancy=87, gross_salary=0.0)
    -> AvsEstimation(.rente_mensuelle, .rente_annuelle, ...)
  LppConversionService().compare(capital_lpp, canton="ZH", retirement_age=65,
                                  life_expectancy=87, taux_marginal_revenu=0.25)
    -> LppConversionResult(.option_rente_nette_mensuelle, .option_capital_net,
                            .capital_total, ...)
  RetirementBudgetService().reconcile(avs_mensuel, lpp_mensuel, capital_3a_net,
                                       autres_revenus, depenses_mensuelles,
                                       revenu_pre_retraite, is_couple=False)
    -> RetirementBudget(.total_revenus_mensuels, .solde_mensuel,
                         .taux_remplacement, ...)
    NOTE: .taux_remplacement is PERCENT (0-100), NOT a 0-1 ratio.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from app.services.retirement.avs_estimation_service import AvsEstimationService
from app.services.retirement.lpp_conversion_service import LppConversionService
from app.services.retirement.retirement_budget_service import (
    RetirementBudgetService,
)


@dataclass(frozen=True)
class RetirementProjection:
    """Output of RetirementProjectionService.compute.

    Numerics-only payload — NO French strings, NO formatting. Consumed by
    `_compute_retirement_projection` in coach_chat.py which wraps it in
    `RetirementProjectionResponse` (Pydantic v2 camelCase) for the
    server-side path, or falls back to `_format_retirement_projection`
    when the flag is OFF.
    """
    # Ratio 0.0-1.0 (computed = budget.taux_remplacement / 100). NOT a percent.
    # Critical unit fix per panel obs-a5f5f19baeb3119b C4 — RetirementBudget
    # publishes taux_remplacement as a percent (0-100) so the orchestrator
    # divides by 100 before returning.
    replacement_ratio: float
    # Monthly AVS rente (CHF) — NOT annual; matches legacy formatter expectation.
    avs_rente: Decimal
    # LPP capital at retirement age (forward-projected, net of withdrawal tax).
    # None when no LPP avoir on the profile (panel obs-a5f5f19baeb3119b H3).
    lpp_capital: Optional[Decimal]
    # Total monthly retirement income (AVS + LPP rente net + mensualised 3a + other).
    monthly_retirement_income: Decimal
    # current_monthly_income - monthly_retirement_income (CHF/month, can be negative).
    monthly_gap: Decimal
    # Pre-retirement monthly income (from profile.monthlyIncome).
    current_monthly_income: Decimal


def _q(v) -> Decimal:
    """Quantize to 2-decimal Decimal with ROUND_HALF_UP.

    Matches the inputs_hash.py:51 quantization recipe so hash and Decimal
    fields stay coherent across the dispatcher.
    """
    if v is None:
        return Decimal("0.00")
    return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _age_from_birth_year(birth_year) -> Optional[int]:
    """Compute current age from birth year (matches overview.py helper)."""
    if not birth_year:
        return None
    try:
        return date.today().year - int(birth_year)
    except (TypeError, ValueError):
        return None


class RetirementProjectionService:
    """Pure orchestrator. No state, no side effects.

    Canonical chain reference: services/backend/app/api/v1/endpoints/overview.py
    lines 200-246 (chains AVS + LPP with forward-projection). Plan-02 extends
    that pattern by chaining Budget reconciliation onto AVS + LPP outputs.
    """

    # Default product assumptions per Wave 1a (documented in CONTEXT, may
    # become user-editable in Wave 2). All defaults match overview.py canon.
    DEFAULT_RETIREMENT_AGE = 65
    DEFAULT_LIFE_EXPECTANCY = 87
    # Expense fallback: when profile.monthlyExpenses is missing, assume
    # 70% of pre-retirement income (canonical replacement-rate target).
    DEFAULT_EXPENSE_RATIO = 0.70
    LPP_REAL_RETURN_RATE = 1.02   # matches overview.py:231 forward-projection
    LPP_INSURED_CONTRIB_RATE = 0.18  # matches overview.py:231

    @staticmethod
    def compute(profile_data: dict) -> RetirementProjection:
        # camelCase keys (Flutter <-> backend contract).
        birth_year = profile_data.get("birthYear")
        current_age = _age_from_birth_year(birth_year)
        household_type = profile_data.get("householdType")
        is_couple = household_type == "couple"
        canton = profile_data.get("canton") or "ZH"
        avoir_lpp = profile_data.get("avoirLpp")
        lpp_insured = profile_data.get("lppInsuredSalary") or 0.0
        avs_contrib_years = profile_data.get("avsContributionYears")
        pillar3a_balance = profile_data.get("pillar3aBalance") or 0.0
        monthly_income = profile_data.get("monthlyIncome")
        monthly_expenses = profile_data.get("monthlyExpenses")
        desired_retirement_age = (
            profile_data.get("desiredRetirementAge")
            or RetirementProjectionService.DEFAULT_RETIREMENT_AGE
        )

        # Validate minimum inputs — need age + at least one income source.
        if current_age is None or (avoir_lpp is None and monthly_income is None):
            raise ValueError("retirement projection inputs missing")

        # 1. AVS estimate (chain step 1 — overview.py:207).
        annees_lacunes = 0
        if avs_contrib_years is not None:
            try:
                annees_lacunes = max(0, 44 - int(avs_contrib_years))
            except (TypeError, ValueError):
                annees_lacunes = 0
        avs = AvsEstimationService().estimate(
            current_age=current_age,
            retirement_age=desired_retirement_age,
            is_couple=is_couple,
            annees_lacunes=annees_lacunes,
            life_expectancy=RetirementProjectionService.DEFAULT_LIFE_EXPECTANCY,
            gross_salary=float((monthly_income or 0.0) * 12),
        )

        # 2. LPP forward-projection + compare (chain step 2 — matches
        # overview.py:226-246 verbatim for the projection formula).
        lpp_capital_net: Optional[Decimal] = None
        lpp_rente_mensuelle_net = 0.0
        if avoir_lpp is not None and float(avoir_lpp) > 0:
            years_to_retirement = max(0, desired_retirement_age - current_age)
            projected_capital = (
                float(avoir_lpp)
                * (RetirementProjectionService.LPP_REAL_RETURN_RATE ** years_to_retirement)
                + float(lpp_insured)
                * RetirementProjectionService.LPP_INSURED_CONTRIB_RATE
                * years_to_retirement
            )
            lpp = LppConversionService().compare(
                capital_lpp=projected_capital,
                canton=canton,
                retirement_age=desired_retirement_age,
                life_expectancy=RetirementProjectionService.DEFAULT_LIFE_EXPECTANCY,
                # Review #989 : ne PAS injecter le flat 0.25 — None laisse la
                # convention canonique (modèle v2) taxer la rente ; le flat
                # neutralisait le fix -amq sur le parcours coach/projection.
            )
            lpp_capital_net = _q(lpp.option_capital_net)
            lpp_rente_mensuelle_net = lpp.option_rente_nette_mensuelle

        # 3. Retirement budget reconcile (chain step 3 — plan-02 is the
        # first caller of this branch from the coach surface).
        current_monthly = float(monthly_income or 0.0)
        depenses = float(
            monthly_expenses
            if monthly_expenses is not None
            else current_monthly * RetirementProjectionService.DEFAULT_EXPENSE_RATIO
        )
        budget = RetirementBudgetService().reconcile(
            avs_mensuel=avs.rente_mensuelle,
            lpp_mensuel=lpp_rente_mensuelle_net,
            capital_3a_net=float(pillar3a_balance),
            autres_revenus=0.0,
            depenses_mensuelles=depenses,
            revenu_pre_retraite=current_monthly,
            is_couple=is_couple,
        )

        # Convert percent (0-100) to ratio (0.0-1.0). Critical unit fix
        # per panel obs-54a6659a6008b907 concern #6 and obs-a5f5f19baeb3119b C4.
        replacement_ratio = float(budget.taux_remplacement) / 100.0

        monthly_retirement = _q(budget.total_revenus_mensuels)
        current_monthly_q = _q(current_monthly)
        return RetirementProjection(
            replacement_ratio=replacement_ratio,
            avs_rente=_q(avs.rente_mensuelle),
            lpp_capital=lpp_capital_net,
            monthly_retirement_income=monthly_retirement,
            monthly_gap=current_monthly_q - monthly_retirement,
            current_monthly_income=current_monthly_q,
        )
