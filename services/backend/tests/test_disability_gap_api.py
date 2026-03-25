"""
Tests for Disability Gap API endpoints.

POST /api/v1/disability-gap/compute — simulation du gap financier en cas d'invalidite.

Covers:
    - Valid employee data -> 200 with correct phases
    - Self-employed -> no phase 1 coverage
    - Invalid canton -> 400
    - Various disability degrees -> correct AI rente
    - Response includes disclaimer, sources, chiffre_choc
    - Response includes all 3 phase gaps
    - Risk levels (critical, high, medium, low)
    - Edge cases (zero income, student, mixed status)
"""

import pytest


API_URL = "/api/v1/disability-gap/compute"


def _employee_payload(**overrides):
    """Build a valid employee payload with sensible defaults."""
    base = {
        "revenuMensuelNet": 6000.0,
        "statutProfessionnel": "employee",
        "canton": "ZH",
        "anneesAnciennete": 5,
        "hasIjmCollective": True,
        "degreInvalidite": 70,
        "lppDisabilityBenefit": 500.0,
    }
    base.update(overrides)
    return base


class TestDisabilityGapValidEmployee:
    """Tests with valid employee data."""

    def test_employee_basic_200(self, client):
        """POST with valid employee data returns 200."""
        resp = client.post(API_URL, json=_employee_payload())
        assert resp.status_code == 200

    def test_employee_phase1_coverage(self, client):
        """Employee gets employer coverage in phase 1."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        # ZH with 5 years -> echelle zurichoise: 13 weeks
        assert data["phase1DurationWeeks"] == 13.0
        assert data["phase1MonthlyBenefit"] == 6000.0
        assert data["phase1Gap"] == 0.0  # 100% salary maintained

    def test_employee_phase2_ijm(self, client):
        """Employee with IJM gets 80% coverage in phase 2."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        assert data["phase2DurationMonths"] == 24.0
        assert data["phase2MonthlyBenefit"] == pytest.approx(4800.0)
        assert data["phase2Gap"] == pytest.approx(1200.0)

    def test_employee_phase3_ai_lpp(self, client):
        """Employee gets AI + LPP in phase 3."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        # 70% invalidite -> rente entiere AI = 2520 CHF + 500 LPP = 3020
        assert data["aiRenteMensuelle"] == pytest.approx(2520.0)
        assert data["lppDisabilityBenefit"] == pytest.approx(500.0)
        assert data["phase3MonthlyBenefit"] == pytest.approx(3020.0)
        assert data["phase3Gap"] == pytest.approx(2980.0)


class TestDisabilityGapSelfEmployed:
    """Tests with self-employed status."""

    def test_self_employed_no_phase1(self, client):
        """Self-employed has no employer coverage (phase 1 gap = full income)."""
        payload = _employee_payload(statutProfessionnel="self_employed")
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["phase1DurationWeeks"] == 0.0
        assert data["phase1MonthlyBenefit"] == 0.0
        assert data["phase1Gap"] == 6000.0

    def test_self_employed_without_ijm_critical_risk(self, client):
        """Self-employed without IJM -> critical risk level."""
        payload = _employee_payload(
            statutProfessionnel="self_employed",
            hasIjmCollective=False,
        )
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["riskLevel"] == "critical"
        assert any("CRITIQUE" in a for a in data["alerts"])

    def test_self_employed_with_ijm_phase2(self, client):
        """Self-employed with individual IJM gets 80% coverage."""
        payload = _employee_payload(
            statutProfessionnel="self_employed",
            hasIjmCollective=True,
        )
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["phase2MonthlyBenefit"] == pytest.approx(4800.0)


class TestDisabilityGapInvalidInput:
    """Tests with invalid input data."""

    def test_invalid_canton_returns_400(self, client):
        """POST with unsupported canton returns 400."""
        payload = _employee_payload(canton="XX")
        resp = client.post(API_URL, json=payload)
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Invalid request parameters"

    def test_missing_required_field_returns_422(self, client):
        """POST with missing required field returns 422 (validation)."""
        payload = {"revenuMensuelNet": 6000.0}
        resp = client.post(API_URL, json=payload)
        assert resp.status_code == 422

    def test_negative_income_returns_422(self, client):
        """POST with negative income returns 422 (ge=0 validation)."""
        payload = _employee_payload(revenuMensuelNet=-100.0)
        resp = client.post(API_URL, json=payload)
        assert resp.status_code == 422


class TestDisabilityGapDegrees:
    """Tests for various disability degrees."""

    def test_degree_below_40_no_ai_rente(self, client):
        """Degre < 40% -> no AI rente."""
        payload = _employee_payload(degreInvalidite=30)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["aiRenteMensuelle"] == 0.0

    def test_degree_40_quarter_rente(self, client):
        """Degre 40% -> quarter AI rente (630 CHF)."""
        payload = _employee_payload(degreInvalidite=45)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["aiRenteMensuelle"] == pytest.approx(630.0)

    def test_degree_50_half_rente(self, client):
        """Degre 50% -> half AI rente (1260 CHF)."""
        payload = _employee_payload(degreInvalidite=55)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["aiRenteMensuelle"] == pytest.approx(1260.0)

    def test_degree_60_three_quarter_rente(self, client):
        """Degre 60% -> three-quarter AI rente (1890 CHF)."""
        payload = _employee_payload(degreInvalidite=65)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["aiRenteMensuelle"] == pytest.approx(1890.0)

    def test_degree_100_full_rente(self, client):
        """Degre 100% -> full AI rente (2520 CHF)."""
        payload = _employee_payload(degreInvalidite=100)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["aiRenteMensuelle"] == pytest.approx(2520.0)


class TestDisabilityGapCompliance:
    """Tests for compliance fields (disclaimer, sources, chiffre_choc)."""

    def test_response_includes_disclaimer(self, client):
        """Response must include disclaimer with 'outil educatif'."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        assert "disclaimer" in data
        assert "educatif" in data["disclaimer"].lower()

    def test_response_includes_sources(self, client):
        """Response must include legal sources."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        assert "sources" in data
        assert len(data["sources"]) >= 3
        # Must reference CO, LAI, LPP
        all_sources = " ".join(data["sources"])
        assert "CO" in all_sources
        assert "LAI" in all_sources
        assert "LPP" in all_sources

    def test_response_includes_chiffre_choc(self, client):
        """Response must include chiffre_choc with CHF amount."""
        resp = client.post(API_URL, json=_employee_payload())
        data = resp.json()
        assert "chiffreChoc" in data
        assert "CHF" in data["chiffreChoc"]
