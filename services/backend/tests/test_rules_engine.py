"""
Tests for rules engine (pure financial calculations).
"""

from app.services.rules_engine import (
    calculate_compound_interest,
    calculate_leasing_opportunity_cost,
    calculate_pillar3a_tax_benefit,
    calculate_consumer_credit,
    calculate_debt_risk_score,
    calculate_marginal_tax_rate,
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
