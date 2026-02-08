"""
Scenarios endpoint - create and list simulation scenarios.
MVP: In-memory storage (no persistence).
"""

import uuid
from datetime import datetime
from typing import Dict, List
from fastapi import APIRouter
from pydantic import UUID4
from app.schemas.scenario import Scenario, ScenarioCreate, ScenarioKind
from app.services.rules_engine import (
    calculate_compound_interest,
    calculate_leasing_opportunity_cost,
    calculate_pillar3a_tax_benefit,
    compute_rente_vs_capital,
)

router = APIRouter()

# In-memory store for MVP
_scenarios: Dict[UUID4, Scenario] = {}


def _compute_scenario_outputs(kind: ScenarioKind, inputs: dict) -> dict:
    """Compute outputs based on scenario kind and inputs."""
    if kind == ScenarioKind.compound_interest:
        return calculate_compound_interest(
            principal=inputs.get("principal", 0),
            monthly_contribution=inputs.get("monthlyContribution", 0),
            annual_rate=inputs.get("annualRate", 5.0),
            years=inputs.get("years", 10),
        )
    elif kind == ScenarioKind.leasing:
        return calculate_leasing_opportunity_cost(
            monthly_payment=inputs.get("monthlyPayment", 400),
            duration_months=inputs.get("durationMonths", 48),
            alternative_annual_rate=inputs.get("alternativeRate", 5.0),
        )
    elif kind == ScenarioKind.pillar3a:
        return calculate_pillar3a_tax_benefit(
            annual_contribution=inputs.get("annualContribution", 7056),
            marginal_tax_rate=inputs.get("marginalTaxRate", 0.25),
            years=inputs.get("years", 30),
            annual_return=inputs.get("annualReturn", 4.0),
        )
    elif kind == ScenarioKind.rente_vs_capital:
        return compute_rente_vs_capital(
            avoir_obligatoire=inputs.get("avoirObligatoire", 0),
            avoir_surobligatoire=inputs.get("avoirSurobligatoire", 0),
            taux_conversion_surob=inputs.get("tauxConversionSurob", 0.05),
            age_retraite=inputs.get("ageRetraite", 65),
            canton=inputs.get("canton", "ZH"),
            statut_civil=inputs.get("statutCivil", "single"),
        )
    else:
        # Other scenario types return inputs as-is for now
        return {"message": "Scenario type not yet implemented", "inputs": inputs}


@router.post("", response_model=Scenario)
def create_scenario(scenario_create: ScenarioCreate) -> Scenario:
    """Create a new scenario with computed outputs."""
    scenario_id = uuid.uuid4()
    now = datetime.utcnow()

    outputs = _compute_scenario_outputs(scenario_create.kind, scenario_create.inputs)

    scenario = Scenario(
        id=scenario_id,
        profileId=scenario_create.profileId,
        kind=scenario_create.kind,
        inputs=scenario_create.inputs,
        outputs=outputs,
        createdAt=now,
    )
    _scenarios[scenario_id] = scenario
    return scenario


@router.get("/{profile_id}", response_model=List[Scenario])
def list_scenarios(profile_id: UUID4) -> List[Scenario]:
    """List all scenarios for a profile."""
    return [s for s in _scenarios.values() if s.profileId == profile_id]
