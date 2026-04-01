"""
Scenarios endpoint — create and list simulation scenarios.
Persisted in PostgreSQL via ScenarioModel.
"""

import uuid
from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.profile_model import ProfileModel
from app.models.scenario import ScenarioModel
from app.models.user import User
from pydantic import UUID4
from app.schemas.scenario import Scenario, ScenarioCreate, ScenarioKind, PaginatedScenariosResponse
from app.constants.social_insurance import PILIER_3A_PLAFOND_AVEC_LPP
from app.services.rules_engine import (
    calculate_compound_interest,
    calculate_leasing_opportunity_cost,
    calculate_pillar3a_tax_benefit,
    compute_rente_vs_capital,
)

router = APIRouter()


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
            annual_contribution=inputs.get("annualContribution", PILIER_3A_PLAFOND_AVEC_LPP),
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
        return {"message": "Scenario type not yet implemented", "inputs": inputs}


@router.post("", response_model=Scenario)
@limiter.limit("10/minute")
def create_scenario(
    request: Request,
    scenario_create: ScenarioCreate,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> Scenario:
    """Create a new scenario with computed outputs. Persisted in DB."""
    scenario_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    outputs = _compute_scenario_outputs(scenario_create.kind, scenario_create.inputs)

    # Persist to DB
    row = ScenarioModel(
        id=str(scenario_id),
        profile_id=str(scenario_create.profileId),
        kind=scenario_create.kind.value,
        inputs=scenario_create.inputs,
        outputs=outputs,
        created_at=now,
    )
    db.add(row)
    db.commit()

    return Scenario(
        id=scenario_id,
        profileId=scenario_create.profileId,
        kind=scenario_create.kind,
        inputs=scenario_create.inputs,
        outputs=outputs,
        createdAt=now,
    )


@router.get("/{profile_id}", response_model=PaginatedScenariosResponse)
@limiter.limit("30/minute")
def list_scenarios(
    request: Request,
    profile_id: UUID4,
    limit: int = Query(default=50, ge=1, le=200, description="Nombre max de resultats"),
    offset: int = Query(default=0, ge=0, description="Offset pour la pagination"),
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> PaginatedScenariosResponse:
    """List all scenarios for a profile (paginated, ordered by creation date desc). Reads from DB."""
    # P0-2: Verify profile ownership before returning scenarios
    profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(profile_id),
        ProfileModel.user_id == current_user.id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Count total before pagination
    total = db.query(ScenarioModel).filter(
        ScenarioModel.profile_id == str(profile_id)
    ).count()

    rows = db.query(ScenarioModel).filter(
        ScenarioModel.profile_id == str(profile_id)
    ).order_by(ScenarioModel.created_at.desc()).offset(offset).limit(limit).all()

    return PaginatedScenariosResponse(
        items=[
            Scenario(
                id=row.id,
                profileId=row.profile_id,
                kind=row.kind,
                inputs=row.inputs or {},
                outputs=row.outputs or {},
                createdAt=row.created_at,
            )
            for row in rows
        ],
        total=total,
        limit=limit,
        offset=offset,
    )
