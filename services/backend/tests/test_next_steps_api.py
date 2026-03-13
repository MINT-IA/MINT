"""
Tests for Next Steps API endpoints.

POST /api/v1/next-steps/calculate — recommandations personnalisees.

Covers:
    - Young employee -> includes firstJob
    - has_debt=true -> debtCrisis first (priority 1)
    - age >= 55 -> includes retirement
    - unemployed -> includes jobLoss
    - concubinage -> includes concubinage
    - independent -> includes selfEmployment
    - Response has max 5 steps
    - Response includes disclaimer + sources
    - Each step has route, icon_name, life_event
    - camelCase serialization
    - Edge cases
"""



API_URL = "/api/v1/next-steps/calculate"


def _base_payload(**overrides):
    """Build a valid next steps payload with sensible defaults."""
    base = {
        "age": 30,
        "civilStatus": "single",
        "childrenCount": 0,
        "employmentStatus": "employee",
        "monthlyNetIncome": 6000.0,
        "canton": "ZH",
        "has3a": False,
        "hasPensionFund": True,
        "hasDebt": False,
        "hasRealEstate": False,
        "hasInvestments": False,
    }
    base.update(overrides)
    return base


class TestNextStepsBasicRules:
    """Tests for the core recommendation rules."""

    def test_young_employee_gets_first_job(self, client):
        """Young employee (age <= 28) should get firstJob recommendation."""
        payload = _base_payload(age=25)
        resp = client.post(API_URL, json=payload)
        assert resp.status_code == 200
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "firstJob" in events

    def test_debt_always_first_priority(self, client):
        """has_debt=true -> debtCrisis should be priority 1 and first in list."""
        payload = _base_payload(hasDebt=True)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert data["steps"][0]["lifeEvent"] == "debtCrisis"
        assert data["steps"][0]["priority"] == 1

    def test_age_55_includes_retirement(self, client):
        """Age >= 55 should include retirement recommendation."""
        payload = _base_payload(age=58)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "retirement" in events

    def test_unemployed_includes_job_loss(self, client):
        """Unemployed status should include jobLoss recommendation."""
        payload = _base_payload(employmentStatus="unemployed")
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "jobLoss" in events

    def test_concubinage_includes_concubinage(self, client):
        """Concubinage civil status should include concubinage recommendation."""
        payload = _base_payload(civilStatus="concubinage")
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "concubinage" in events

    def test_independent_includes_self_employment(self, client):
        """Independent employment should include selfEmployment recommendation."""
        payload = _base_payload(employmentStatus="independent")
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "selfEmployment" in events


class TestNextStepsResponseStructure:
    """Tests for response structure and constraints."""

    def test_max_5_steps(self, client):
        """Response should have at most 5 steps."""
        # Trigger many rules at once
        payload = _base_payload(
            age=60,
            civilStatus="single",
            childrenCount=2,
            hasDebt=True,
            monthlyNetIncome=8000.0,
            canton="GE",  # high-tax canton
        )
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        assert len(data["steps"]) <= 5

    def test_each_step_has_required_fields(self, client):
        """Each step should have life_event, title, reason, priority, route, icon_name."""
        payload = _base_payload(hasDebt=True)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        for step in data["steps"]:
            assert "lifeEvent" in step
            assert "title" in step
            assert "reason" in step
            assert "priority" in step
            assert "route" in step
            assert "iconName" in step

    def test_routes_start_with_slash(self, client):
        """All routes should start with /."""
        payload = _base_payload(hasDebt=True)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        for step in data["steps"]:
            assert step["route"].startswith("/"), f"Route does not start with /: {step['route']}"

    def test_steps_sorted_by_priority(self, client):
        """Steps should be sorted by priority (1 = highest)."""
        payload = _base_payload(
            age=60,
            hasDebt=True,
            childrenCount=2,
        )
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        priorities = [s["priority"] for s in data["steps"]]
        assert priorities == sorted(priorities)


class TestNextStepsCompliance:
    """Tests for compliance fields."""

    def test_response_includes_disclaimer(self, client):
        """Response must include disclaimer mentioning LSFin."""
        resp = client.post(API_URL, json=_base_payload())
        data = resp.json()
        assert "disclaimer" in data
        assert "LSFin" in data["disclaimer"]

    def test_response_includes_sources(self, client):
        """Response must include legal sources."""
        resp = client.post(API_URL, json=_base_payload())
        data = resp.json()
        assert "sources" in data
        assert len(data["sources"]) >= 3


class TestNextStepsEdgeCases:
    """Tests for edge cases."""

    def test_missing_required_field_returns_422(self, client):
        """POST with missing required field returns 422."""
        payload = {"age": 30}
        resp = client.post(API_URL, json=payload)
        assert resp.status_code == 422

    def test_high_income_non_owner_gets_housing(self, client):
        """High income non-owner should get housingPurchase recommendation."""
        payload = _base_payload(monthlyNetIncome=8000.0, hasRealEstate=False)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "housingPurchase" in events

    def test_owner_gets_housing_sale(self, client):
        """Real estate owner should get housingSale recommendation."""
        payload = _base_payload(hasRealEstate=True, monthlyNetIncome=3000.0)
        resp = client.post(API_URL, json=payload)
        data = resp.json()
        events = [s["lifeEvent"] for s in data["steps"]]
        assert "housingSale" in events
