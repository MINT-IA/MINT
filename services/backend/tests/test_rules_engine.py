"""
Tests for rules engine (pure financial calculations).
"""

import pytest

from app.services.rules_engine import (
    calculate_compound_interest,
    calculate_leasing_opportunity_cost,
    calculate_pillar3a_tax_benefit,
    calculate_consumer_credit,
    calculate_debt_risk_score,
    calculate_marginal_tax_rate,
    compute_rente_vs_capital,
    MAX_RATE_CASH_CREDIT,
)


class TestCompoundInterest:
    """Tests for compound interest calculations."""

    def test_basic_compound_interest(self):
        """Test basic compound interest calculation."""
        result = calculate_compound_interest(
            principal=10000,
            monthly_contribution=0,
            annual_rate=5.0,
            years=10,
        )
        # 10000 * (1.05)^10 ≈ 16288.95
        assert result["finalValue"] > 16000
        assert result["finalValue"] < 16500
        assert result["totalInvested"] == 10000
        assert result["gains"] > 6000

    def test_compound_with_monthly_contributions(self):
        """Test compound interest with monthly contributions."""
        result = calculate_compound_interest(
            principal=0,
            monthly_contribution=500,
            annual_rate=5.0,
            years=20,
        )
        # Total invested = 500 * 240 = 120000
        assert result["totalInvested"] == 120000
        # With 5% compound, should be significantly more
        assert result["finalValue"] > 200000
        assert result["gains"] > 80000

    def test_zero_rate(self):
        """Test with zero interest rate."""
        result = calculate_compound_interest(
            principal=1000,
            monthly_contribution=100,
            annual_rate=0,
            years=5,
        )
        # Should just sum up
        assert result["finalValue"] == 1000 + 100 * 60
        assert result["gains"] == 0


class TestLeasingOpportunityCost:
    """Tests for leasing opportunity cost calculations."""

    def test_basic_leasing_cost(self):
        """Test basic leasing opportunity cost."""
        result = calculate_leasing_opportunity_cost(
            monthly_payment=400,
            duration_months=48,
            alternative_annual_rate=5.0,
        )
        assert result["totalLeasingCost"] == 400 * 48
        assert "5y" in result["opportunityCost"]
        assert "10y" in result["opportunityCost"]
        assert "20y" in result["opportunityCost"]
        # 10 year opportunity cost should be signicant (around 14000)
        assert result["opportunityCost"]["10y"] > 10000


class TestPillar3aTaxBenefit:
    """Tests for 3a tax benefit calculations."""

    def test_basic_3a_benefit(self):
        """Test basic 3a tax benefit calculation."""
        result = calculate_pillar3a_tax_benefit(
            annual_contribution=7056,
            marginal_tax_rate=0.25,
            years=30,
            annual_return=4.0,
        )
        # Annual tax saved = 7056 * 0.25 = 1764
        assert result["annualTaxSaved"] == 1764.0
        # Total tax saved over 30 years
        assert result["totalTaxSavedOverPeriod"] == 1764 * 30
        # Total contributions
        assert result["totalContributions"] == 7056 * 30
        # Final value with compound should be significant
        assert result["potentialFinalValue"] > 400000


class TestConsumerCredit:
    """Tests for consumer credit calculations."""

    def test_basic_consumer_credit(self):
        """Test basic consumer credit calculation."""
        result = calculate_consumer_credit(
            amount=10000,
            duration_months=24,
            annual_rate=9.9,
        )
        # Monthly payment should be around 460 CHF
        assert result["monthlyPayment"] > 450
        assert result["monthlyPayment"] < 480
        # Total interest should be around 1000 CHF
        assert result["totalInterest"] > 900
        assert result["totalInterest"] < 1200
        # Total cost = amount + interest
        assert result["totalCost"] == 10000 + result["totalInterest"]
        # No rate warning at 9.9% (below 10%)
        assert result["rateWarning"] is False

    def test_rate_warning_at_max(self):
        """Test rate warning when at or above legal max."""
        result = calculate_consumer_credit(
            amount=5000,
            duration_months=12,
            annual_rate=10.0,  # At legal max
        )
        assert result["rateWarning"] is True
        assert result["legalMaxRate"] == MAX_RATE_CASH_CREDIT

    def test_rate_warning_above_max(self):
        """Test rate warning when above legal max."""
        result = calculate_consumer_credit(
            amount=5000,
            duration_months=12,
            annual_rate=12.0,  # Above legal max
        )
        assert result["rateWarning"] is True

    def test_zero_rate_credit(self):
        """Test credit with 0% rate."""
        result = calculate_consumer_credit(
            amount=6000,
            duration_months=12,
            annual_rate=0,
        )
        assert result["monthlyPayment"] == 500  # 6000 / 12
        assert result["totalInterest"] == 0
        assert result["totalCost"] == 6000

    def test_credit_with_fees(self):
        """Test credit with additional fees."""
        result = calculate_consumer_credit(
            amount=10000,
            duration_months=24,
            annual_rate=5.0,
            fees=200,
        )
        # Total cost should include fees
        assert result["totalCost"] == 10000 + result["totalInterest"] + 200

    def test_invalid_duration(self):
        """Test with invalid duration."""
        result = calculate_consumer_credit(
            amount=1000,
            duration_months=0,
            annual_rate=5.0,
        )
        assert "error" in result


class TestDebtRiskScore:
    """Tests for debt risk score calculations."""

    def test_low_risk_score(self):
        """Test low risk profile (0-1 factors)."""
        result = calculate_debt_risk_score(
            has_regular_overdrafts=False,
            has_multiple_credits=False,
            has_late_payments=False,
            has_debt_collection=False,
            has_impulsive_buying=True,
            has_gambling_habit=False,
        )
        assert result["riskScore"] == 1
        assert result["riskLevel"] == "low"
        assert len(result["recommendations"]) >= 1
        assert result["hasGamblingRisk"] is False

    def test_medium_risk_score(self):
        """Test medium risk profile (2-3 factors)."""
        result = calculate_debt_risk_score(
            has_regular_overdrafts=True,
            has_multiple_credits=True,
            has_late_payments=False,
            has_debt_collection=False,
            has_impulsive_buying=False,
            has_gambling_habit=False,
        )
        assert result["riskScore"] == 2
        assert result["riskLevel"] == "medium"
        assert any("budget" in r.lower() for r in result["recommendations"])

    def test_high_risk_score(self):
        """Test high risk profile (4+ factors)."""
        result = calculate_debt_risk_score(
            has_regular_overdrafts=True,
            has_multiple_credits=True,
            has_late_payments=True,
            has_debt_collection=True,
            has_impulsive_buying=False,
            has_gambling_habit=False,
        )
        assert result["riskScore"] == 4
        assert result["riskLevel"] == "high"
        assert any("consulter" in r.lower() for r in result["recommendations"])

    def test_gambling_specific_recommendation(self):
        """Test that gambling triggers specific recommendation."""
        result = calculate_debt_risk_score(
            has_regular_overdrafts=False,
            has_multiple_credits=False,
            has_late_payments=False,
            has_debt_collection=False,
            has_impulsive_buying=False,
            has_gambling_habit=True,
        )
        assert result["hasGamblingRisk"] is True
        assert any("jeu" in r.lower() for r in result["recommendations"])

    def test_max_risk_score(self):
        """Test maximum risk score (all factors)."""
        result = calculate_debt_risk_score(
            has_regular_overdrafts=True,
            has_multiple_credits=True,
            has_late_payments=True,
            has_debt_collection=True,
            has_impulsive_buying=True,
            has_gambling_habit=True,
        )
        assert result["riskScore"] == 6
        assert result["riskLevel"] == "high"
        assert result["hasGamblingRisk"] is True


class TestMarginalTaxRate:
    """Tests for marginal tax rate (IFD + cantonal estimation)."""

    def test_zh_100k_single(self):
        """ZH medium tax: IFD marginal 6.60% + ZH 30% = ~36.6% -> clamped."""
        rate = calculate_marginal_tax_rate("ZH", 100000, "single")
        assert 0.28 <= rate <= 0.40

    def test_ge_100k_single(self):
        """GE high tax: IFD marginal 6.60% + GE 41% = ~47.6% -> clamped 0.45."""
        rate = calculate_marginal_tax_rate("GE", 100000, "single")
        assert 0.35 <= rate <= 0.45

    def test_lu_100k_single(self):
        """LU low tax: IFD marginal 6.60% + LU 25% = ~31.6%."""
        rate = calculate_marginal_tax_rate("LU", 100000, "single")
        assert 0.20 <= rate <= 0.35

    def test_ge_higher_than_lu(self):
        """GE should always be higher than LU for same income."""
        rate_ge = calculate_marginal_tax_rate("GE", 100000)
        rate_lu = calculate_marginal_tax_rate("LU", 100000)
        assert rate_ge > rate_lu

    def test_canton_actually_matters(self):
        """Le canton ne doit PLUS être ignoré."""
        rate_zh = calculate_marginal_tax_rate("ZH", 100000)
        rate_ge = calculate_marginal_tax_rate("GE", 100000)
        assert rate_zh != rate_ge

    def test_low_income_floor(self):
        """Very low income should still return at least 0.10."""
        rate = calculate_marginal_tax_rate("ZG", 20000, "single")
        assert rate >= 0.10

    def test_very_high_income_ceiling(self):
        """Very high income should be clamped at 0.45."""
        rate = calculate_marginal_tax_rate("GE", 1000000, "single")
        assert rate <= 0.45

    def test_married_lower_than_single(self):
        """Married bracket starts higher, so marginal rate should differ."""
        rate_single = calculate_marginal_tax_rate("ZH", 80000, "single")
        rate_married = calculate_marginal_tax_rate("ZH", 80000, "married")
        # At 80k, single is in 5.94% IFD bracket, married is in 3.0% bracket
        assert rate_married < rate_single

    def test_unknown_canton_uses_default(self):
        """Unknown canton should use default multiplier, not crash."""
        rate = calculate_marginal_tax_rate("XX", 100000, "single")
        assert 0.10 <= rate <= 0.45


class TestRenteVsCapital:
    """Tests for compute_rente_vs_capital (LPP rente vs capital withdrawal).

    Test values computed by swiss-brain (Python script) based on:
    - LPP art. 14 al. 2 (taux conversion 6.8%)
    - LIFD art. 38 (imposition capital prévoyance)
    """

    def test_marc_zh_single_500k(self):
        """Marc: 65 ans, ZH, single, 200k oblig + 300k surob, taux surob 5.0%."""
        r = compute_rente_vs_capital(200_000, 300_000, 0.05, 65, "ZH", "single")
        assert r["rente_annuelle"] == pytest.approx(28_600, abs=1)
        assert r["rente_mensuelle"] == pytest.approx(2_383.33, abs=1)
        assert r["impot_retrait"] == pytest.approx(40_000, abs=1)
        assert r["capital_net"] == pytest.approx(460_000, abs=1)
        # Prudent 1%: capital runs out before 85
        assert r["scenarios"]["prudent"]["capital_85"] == pytest.approx(0, abs=1)
        assert r["scenarios"]["prudent"]["break_even_age"] == pytest.approx(82.6, abs=0.2)
        # Central 3%: surplus at 85
        assert r["scenarios"]["central"]["capital_85"] == pytest.approx(55_094, abs=500)
        assert r["scenarios"]["central"]["break_even_age"] == pytest.approx(87.0, abs=0.5)
        # Optimiste 5%: large surplus at 85
        assert r["scenarios"]["optimiste"]["capital_85"] == pytest.approx(268_184, abs=500)
        assert r["scenarios"]["optimiste"]["break_even_age"] == pytest.approx(97.8, abs=0.5)

    def test_sophie_vd_married_250k(self):
        """Sophie: 64 ans, VD, married, 150k oblig + 100k surob, taux surob 4.5%."""
        r = compute_rente_vs_capital(150_000, 100_000, 0.045, 64, "VD", "married")
        assert r["rente_annuelle"] == pytest.approx(14_700, abs=1)
        assert r["impot_retrait"] == pytest.approx(17_500, abs=1)
        assert r["capital_net"] == pytest.approx(232_500, abs=1)
        assert r["scenarios"]["prudent"]["break_even_age"] == pytest.approx(81.2, abs=0.2)
        assert r["scenarios"]["central"]["capital_85"] == pytest.approx(6_895, abs=500)
        assert r["scenarios"]["optimiste"]["capital_85"] == pytest.approx(118_637, abs=500)

    def test_pierre_ge_single_1m(self):
        """Pierre: 65 ans, GE, single, 400k oblig + 600k surob, taux surob 5.5%."""
        r = compute_rente_vs_capital(400_000, 600_000, 0.055, 65, "GE", "single")
        assert r["rente_annuelle"] == pytest.approx(60_200, abs=1)
        assert r["impot_retrait"] == pytest.approx(105_000, abs=1)
        assert r["capital_net"] == pytest.approx(895_000, abs=1)
        # Even central doesn't last to 85
        assert r["scenarios"]["central"]["capital_85"] == pytest.approx(0, abs=1)
        assert r["scenarios"]["central"]["break_even_age"] == pytest.approx(84.8, abs=0.5)
        assert r["scenarios"]["optimiste"]["capital_85"] == pytest.approx(365_794, abs=500)

    def test_anna_bs_married_100k(self):
        """Anna: 64 ans, BS, married, 80k oblig + 20k surob, taux surob 4.0%."""
        r = compute_rente_vs_capital(80_000, 20_000, 0.04, 64, "BS", "married")
        assert r["rente_annuelle"] == pytest.approx(6_240, abs=1)
        assert r["impot_retrait"] == pytest.approx(6_000, abs=1)
        assert r["capital_net"] == pytest.approx(94_000, abs=1)
        assert r["scenarios"]["prudent"]["break_even_age"] == pytest.approx(80.4, abs=0.2)
        assert r["scenarios"]["optimiste"]["capital_85"] == pytest.approx(36_976, abs=500)

    def test_thomas_lu_single_500k(self):
        """Thomas: 65 ans, LU, single, 300k oblig + 200k surob, taux surob 5.2%."""
        r = compute_rente_vs_capital(300_000, 200_000, 0.052, 65, "LU", "single")
        assert r["rente_annuelle"] == pytest.approx(30_800, abs=1)
        assert r["impot_retrait"] == pytest.approx(30_000, abs=1)
        assert r["capital_net"] == pytest.approx(470_000, abs=1)
        assert r["scenarios"]["central"]["capital_85"] == pytest.approx(13_113, abs=500)
        assert r["scenarios"]["optimiste"]["capital_85"] == pytest.approx(219_955, abs=500)

    def test_unsupported_canton_raises(self):
        """Unsupported canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton/statut non supporté"):
            compute_rente_vs_capital(100_000, 50_000, 0.05, 65, "TI", "single")

    def test_threshold_boundary(self):
        """Capital at exactly 500k threshold should use high rate."""
        r = compute_rente_vs_capital(250_000, 250_000, 0.05, 65, "ZH", "single")
        # 500k exactly -> taux >= 500k -> 8%
        assert r["impot_retrait"] == pytest.approx(40_000, abs=1)
