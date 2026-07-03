"""
Scenarios endpoint — create and list simulation scenarios.
Persisted in PostgreSQL via ScenarioModel.
"""

import uuid
from datetime import datetime, timezone
from typing import Optional
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
from app.services.mortgage.affordability_service import AffordabilityService
from app.services.succession_property_transmission import (
    REQUIRED_INPUTS as SUCCESSION_REQUIRED_INPUTS,
    compute_property_transmission_scenario,
)

router = APIRouter()

_SCENARIO_DISCLAIMER = (
    "Cet outil est éducatif et ne remplace pas une analyse financière, "
    "fiscale ou juridique adaptée à la situation concrète. Les résultats "
    "sont des estimations ou des triages à confirmer avec un spécialiste."
)
_SCENARIO_SOURCES = [
    "LPP/LAVS/OPP3: bases légales suisses selon le type de scénario",
    "LSFin art. 3: information financière, pas mandat d'analyse individuelle",
]
_SCENARIO_COMMON_SOURCES = [
    "LSFin art. 3: information financière, pas mandat d'analyse individuelle",
]

SUCCESSION_PROVENANCE_REQUIRED_INPUTS = (
    *SUCCESSION_REQUIRED_INPUTS,
    "canton",
    "cashPaidByRecipient",
    "mortgageAssumedByRecipient",
    "recipientRelationship",
    "retainedRight",
    "avancementHoirie",
)
_SUCCESSION_PROVENANCE_ALLOWED_SOURCES = {
    "estimated",
    "userInput",
    "crossValidated",
    "certificate",
    "openBanking",
    "system",
}
_SUCCESSION_PROVENANCE_ALLOWED_CONFIDENCE = {
    "none",
    "low",
    "medium",
    "high",
}
_SUCCESSION_COMPOSED_INPUTS = {
    "parentAnnualRetirementIncome",
    "parentAnnualLivingCosts",
}
_MORTGAGE_SOURCES = [
    "Circulaire FINMA 2017/5 (hypotheques residentielles)",
    "Directives ASB sur l'octroi hypothecaire",
    "OPP2 art. 5 (EPL: fonds propres immobiliers)",
    "Taux theorique de 5% utilise pour le calcul de capacite",
]


def _numeric_input(inputs: dict, *keys: str) -> tuple[float, bool]:
    for key in keys:
        if key not in inputs:
            continue
        value = inputs[key]
        if isinstance(value, bool):
            return 0.0, False
        if isinstance(value, (int, float)):
            return float(value), True
        return 0.0, False
    return 0.0, False


def _string_input(inputs: dict, *keys: str, default: str = "") -> str:
    for key in keys:
        value = inputs.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return default


def _missing_mortgage_output(missing_inputs: list[str]) -> dict:
    return {
        "status": "missing_data",
        "missingInputs": missing_inputs,
        "affordability": None,
        "equity": None,
        "warnings": [
            {
                "code": "missing_required_mortgage_inputs",
                "fields": missing_inputs,
                "message": (
                    "MINT doit collecter ces donnees avant de calculer une "
                    "capacite hypothecaire educative."
                ),
            }
        ],
        "scenarioConfidence": "low",
        "scenarioConfidenceRationale": {
            "basis": "missing_required_inputs",
            "axes": {
                "completeness": "missing_data",
                "accuracy": "not_computed",
                "freshness": "not_evaluated",
                "understanding": "data_quest_required",
            },
        },
        "sources": list(_MORTGAGE_SOURCES),
    }


def _compute_mortgage_scenario(inputs: dict) -> dict:
    income, income_present = _numeric_input(
        inputs,
        "incomeGrossYearly",
        "revenuBrutAnnuel",
        "grossAnnualIncome",
    )
    liquid_assets, liquid_present = _numeric_input(
        inputs,
        "patrimoine.epargneLiquide",
        "liquidAssets",
        "epargneDisponible",
    )
    property_value, property_present = _numeric_input(
        inputs,
        "targetPropertyValue",
        "prixAchat",
    )
    pillar3a_assets, _ = _numeric_input(
        inputs,
        "pillar3aAssets",
        "patrimoine.avoir3a",
        "avoir3a",
    )
    lpp_assets, _ = _numeric_input(
        inputs,
        "lppAssets",
        "patrimoine.avoirLppTotal",
        "avoirLpp",
    )
    canton = _string_input(inputs, "canton", default="ZH").upper()[:2]

    missing: list[str] = []
    if not income_present or income <= 0:
        missing.append("incomeGrossYearly")
    if not liquid_present:
        missing.append("patrimoine.epargneLiquide")
    if not property_present or property_value <= 0:
        missing.append("targetPropertyValue")
    if missing:
        return _missing_mortgage_output(missing)

    result = AffordabilityService().calculate_affordability(
        revenu_brut_annuel=income,
        epargne_disponible=liquid_assets,
        avoir_3a=pillar3a_assets,
        avoir_lpp=lpp_assets,
        prix_achat=property_value,
        canton=canton,
    )
    if result.capacite_ok and result.fonds_propres_suffisants:
        status = "affordable"
    elif not result.fonds_propres_suffisants:
        status = "insufficient_equity"
    else:
        status = "insufficient_income"

    equity_required = property_value * 0.20
    return {
        "status": status,
        "missingInputs": [],
        "affordability": {
            "capacityOk": result.capacite_ok,
            "equityOk": result.fonds_propres_suffisants,
            "chargesRatio": result.ratio_charges,
            "monthlyTheoreticalCharges": result.charges_mensuelles_theoriques,
            "maxAccessiblePrice": round(result.prix_max_accessible),
            "targetPropertyValue": round(result.prix_achat),
            "mortgageAmount": round(result.montant_hypothecaire),
            "canton": result.canton,
        },
        "equity": {
            "total": round(result.fonds_propres_total),
            "required": round(equity_required),
            "missing": round(max(0.0, equity_required - result.fonds_propres_total)),
            "liquidAssets": round(liquid_assets),
            "pillar3aUsed": round(result.detail_fonds_propres["avoir_3a"]),
            "lppUsed": round(result.detail_fonds_propres["avoir_lpp"]),
        },
        "premierEclairage": {
            "amount": round(result.premier_eclairage.montant),
            "text": result.premier_eclairage.texte,
        },
        "checklist": result.checklist,
        "warnings": [
            {"code": "mortgage_alert", "message": alert}
            for alert in result.alertes
        ],
        "scenarioConfidence": "medium",
        "scenarioConfidenceRationale": {
            "basis": "swiss_affordability_calculator",
            "axes": {
                "completeness": "required_inputs_present",
                "accuracy": "educational_bank_rule_estimate",
                "freshness": "input_provenance_dependent",
                "understanding": "explain_capacity_and_equity",
            },
        },
        "sources": result.sources or list(_MORTGAGE_SOURCES),
    }


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
    elif kind == ScenarioKind.succession:
        return compute_property_transmission_scenario(inputs)
    elif kind == ScenarioKind.mortgage:
        return _compute_mortgage_scenario(inputs)
    else:
        return {"message": "Scenario type not yet implemented", "inputs": inputs}


def _scenario_enhanced_confidence(kind: ScenarioKind, outputs: dict) -> dict:
    scenario_confidence = outputs.get("scenarioConfidence", "estimated")
    rationale = outputs.get(
        "scenarioConfidenceRationale",
        {
            "basis": "estimated_outputs",
            "axes": {
                "completeness": "input_dependent",
                "accuracy": "input_provenance_dependent",
                "freshness": "not_evaluated",
                "understanding": "educational_projection",
            },
        },
    )
    return {
        "label": "à confirmer",
        "scenarioKind": kind.value,
        "scenarioConfidence": scenario_confidence,
        "rangePolicy": "projected_numbers_require_ranges_or_confidence_band",
        "rationale": rationale,
    }


def _scenario_sources(outputs: dict) -> list[str]:
    output_sources = outputs.get("sources")
    if not isinstance(output_sources, list) or not output_sources:
        return list(_SCENARIO_SOURCES)

    merged: list[str] = []
    for source in [*output_sources, *_SCENARIO_COMMON_SOURCES]:
        if isinstance(source, str) and source not in merged:
            merged.append(source)
    return merged


def _public_inputs(stored_inputs: Optional[dict]) -> dict:
    return {
        key: value
        for key, value in (stored_inputs or {}).items()
        if not key.startswith("_")
    }


def _validate_scenario_provenance(scenario_create: ScenarioCreate) -> None:
    if scenario_create.kind != ScenarioKind.succession:
        return
    missing = [
        key
        for key in SUCCESSION_PROVENANCE_REQUIRED_INPUTS
        if key in scenario_create.inputs and key not in scenario_create.inputProvenance
    ]
    if missing:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "missing_input_provenance",
                "fields": missing,
            },
        )

    invalid_fields: dict[str, list[str]] = {}

    def add_invalid(reason: str, key: str) -> None:
        invalid_fields.setdefault(reason, []).append(key)

    for key in SUCCESSION_PROVENANCE_REQUIRED_INPUTS:
        if key not in scenario_create.inputs:
            continue
        meta = scenario_create.inputProvenance.get(key)
        if not isinstance(meta, dict):
            add_invalid("missing_source", key)
            add_invalid("missing_confidence", key)
            add_invalid("missing_source_date", key)
            continue

        source = meta.get("source")
        if not isinstance(source, str) or not source.strip():
            add_invalid("missing_source", key)
        elif source not in _SUCCESSION_PROVENANCE_ALLOWED_SOURCES:
            add_invalid("invalid_source", key)

        confidence = meta.get("confidence")
        if not isinstance(confidence, str) or not confidence.strip():
            add_invalid("missing_confidence", key)
        elif confidence not in _SUCCESSION_PROVENANCE_ALLOWED_CONFIDENCE:
            add_invalid("invalid_confidence", key)

        if "source_date" not in meta and "sourceDate" not in meta:
            add_invalid("missing_source_date", key)

        if key in _SUCCESSION_COMPOSED_INPUTS:
            derived_from = meta.get("derived_from") or meta.get("derivedFrom")
            if not isinstance(derived_from, list) or not derived_from:
                add_invalid("missing_derived_from", key)

    if invalid_fields:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "invalid_input_provenance",
                "fields": invalid_fields,
            },
        )


@router.post("", response_model=Scenario)
@limiter.limit("10/minute")
def create_scenario(
    request: Request,
    scenario_create: ScenarioCreate,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> Scenario:
    """Create a new scenario with computed outputs. Persisted in DB."""
    profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(scenario_create.profileId),
        ProfileModel.user_id == current_user.id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    _validate_scenario_provenance(scenario_create)

    scenario_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    compute_inputs = {
        **scenario_create.inputs,
        "_inputProvenance": scenario_create.inputProvenance,
    }
    outputs = _compute_scenario_outputs(scenario_create.kind, compute_inputs)
    stored_inputs = {
        **scenario_create.inputs,
        "_inputProvenance": scenario_create.inputProvenance,
        "_scenarioId": scenario_create.scenarioId or str(scenario_id),
        "_profileOwnerId": scenario_create.profileOwnerId or current_user.id,
    }

    # Persist to DB
    row = ScenarioModel(
        id=str(scenario_id),
        profile_id=str(scenario_create.profileId),
        kind=scenario_create.kind.value,
        inputs=stored_inputs,
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
        inputProvenance=scenario_create.inputProvenance,
        scenarioId=scenario_create.scenarioId or str(scenario_id),
        profileOwnerId=scenario_create.profileOwnerId or current_user.id,
        outputs=outputs,
        createdAt=now,
        confidenceMode="educational",
        enhancedConfidence=_scenario_enhanced_confidence(
            scenario_create.kind,
            outputs,
        ),
        disclaimer=_SCENARIO_DISCLAIMER,
        sources=_scenario_sources(outputs),
    )


@router.get("/{profile_id}", response_model=PaginatedScenariosResponse)
@limiter.limit("30/minute")
def list_scenarios(
    request: Request,
    profile_id: UUID4,
    limit: int = Query(default=50, ge=1, le=200, description="Nombre max de résultats"),
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
                inputs=_public_inputs(row.inputs),
                inputProvenance=(row.inputs or {}).get("_inputProvenance", {}),
                scenarioId=(row.inputs or {}).get("_scenarioId"),
                profileOwnerId=(row.inputs or {}).get("_profileOwnerId"),
                outputs=row.outputs or {},
                createdAt=row.created_at,
                confidenceMode="educational",
                enhancedConfidence=_scenario_enhanced_confidence(
                    ScenarioKind(row.kind),
                    row.outputs or {},
                ),
                disclaimer=_SCENARIO_DISCLAIMER,
                sources=_scenario_sources(row.outputs or {}),
            )
            for row in rows
        ],
        total=total,
        limit=limit,
        offset=offset,
    )
