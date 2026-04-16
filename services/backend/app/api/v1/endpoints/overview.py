"""Aperçu financier — single aggregator endpoint.

/overview/me answers one question: "qu'est-ce que MINT sait de moi,
qu'est-ce que ça implique, et qu'est-ce qui manque pour un diagnostic
complet ?". It is the backend source of truth for the Aperçu financier
screen and the Today screen's header card.

Design: pure aggregation — no side effects, no writes. Reads
ProfileModel.data, runs AVS/LPP/3a calculators when the user has enough
fields for each axis, and returns a structured payload with:

  • identity:    age, canton, household, goal
  • income:      net/gross monthly/yearly (whatever was provided)
  • patrimoine:  wealth, savings, LPP avoir, 3a balance
  • prevoyance:  AVS estimate, LPP rente/capital options, 3a buyback room
  • assurances_sociales: rente invalidité / conjoint / enfant if known
  • dettes:      has_debt, total_debt
  • couple:      partial/complete flag + spouse facts if entered
  • completeness: 0.0–1.0 index + list of missing_fields (profile_gaps)
  • alertes:     pedagogical warnings (LPP art. 7 inconsistency, etc.)

Completeness is weighted: identity > income > LPP > 3a > patrimoine.
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.profile_model import ProfileModel
from app.models.user import User
from app.services.retirement import (
    AvsEstimationService,
    LppConversionService,
)

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Response schema ─────────────────────────────────────────────────


class OverviewSection(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    present: bool = False
    missing_fields: list[str] = Field(default_factory=list)
    values: dict[str, Any] = Field(default_factory=dict)


class OverviewResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    identity: OverviewSection
    income: OverviewSection
    patrimoine: OverviewSection
    prevoyance: OverviewSection
    assurances_sociales: OverviewSection
    dettes: OverviewSection
    couple: OverviewSection
    budget: OverviewSection

    completeness_index: float = Field(..., ge=0.0, le=1.0)
    profile_gaps: list[str]
    alertes: list[str]
    premier_eclairage: str


# ── Section weights for completeness index ──────────────────────────


_SECTION_WEIGHTS = {
    "identity": 0.18,
    "income": 0.18,
    "patrimoine": 0.13,
    "prevoyance": 0.18,
    "assurances_sociales": 0.08,
    "dettes": 0.08,
    "couple": 0.05,
    "budget": 0.12,  # budget feeds the daily steady-state loop
}

_REQUIRED_BY_SECTION = {
    "identity": ["birthYear", "canton", "householdType", "goal"],
    "income": ["incomeNetMonthly"],  # at least one income signal
    "patrimoine": ["totalSavings"],
    "prevoyance": ["lppInsuredSalary", "avoirLpp", "pillar3aAnnual"],
    "assurances_sociales": ["renteInvaliditeAnnuelle"],
    "dettes": ["hasDebt"],
    "couple": [],  # only required if householdType = couple
    "budget": [],  # presence depends on whether budget has been set up
}


# ── Helpers ────────────────────────────────────────────────────────


def _age_from_birth_year(year: Optional[int]) -> Optional[int]:
    if not year:
        return None
    return max(0, date.today().year - int(year))


def _compute_section(
    data: dict,
    required: list[str],
    extra_values: dict[str, Any],
) -> OverviewSection:
    missing = [k for k in required if data.get(k) in (None, "")]
    present = len(required) == 0 or not missing
    values = {k: data.get(k) for k in required if data.get(k) is not None}
    values.update(extra_values)
    return OverviewSection(
        present=present, missing_fields=missing, values=values
    )


def _build_identity(data: dict) -> OverviewSection:
    age = _age_from_birth_year(data.get("birthYear"))
    return _compute_section(
        data,
        _REQUIRED_BY_SECTION["identity"],
        {"age": age} if age else {},
    )


def _build_income(data: dict) -> OverviewSection:
    # Accept either monthly or yearly, net or gross — only one required.
    has_any = any(
        data.get(k) is not None
        for k in (
            "incomeNetMonthly",
            "incomeGrossMonthly",
            "incomeNetYearly",
            "incomeGrossYearly",
        )
    )
    values = {
        k: data[k]
        for k in (
            "incomeNetMonthly",
            "incomeGrossMonthly",
            "incomeNetYearly",
            "incomeGrossYearly",
            "employmentStatus",
            "employmentRate",
        )
        if data.get(k) is not None
    }
    return OverviewSection(
        present=has_any,
        missing_fields=[] if has_any else ["incomeNetMonthly"],
        values=values,
    )


def _build_patrimoine(data: dict) -> OverviewSection:
    values = {
        k: data[k]
        for k in (
            "totalSavings",
            "savingsMonthly",
            "wealthEstimate",
            "avoirLpp",
            "pillar3aBalance",
        )
        if data.get(k) is not None
    }
    return OverviewSection(
        present=bool(values),
        missing_fields=[] if values else ["totalSavings"],
        values=values,
    )


def _build_prevoyance(data: dict) -> OverviewSection:
    values: dict[str, Any] = {
        k: data[k]
        for k in (
            "lppInsuredSalary",
            "avoirLpp",
            "lppBuybackMax",
            "pillar3aAnnual",
            "pillar3aBalance",
            "has2ndPillar",
        )
        if data.get(k) is not None
    }

    age = _age_from_birth_year(data.get("birthYear"))
    canton = data.get("canton") or "ZH"
    is_couple = data.get("householdType") == "couple"

    # Run AVS estimate if we have age
    if age and 18 <= age <= 70:
        try:
            avs = AvsEstimationService().estimate(
                current_age=age,
                retirement_age=65,
                is_couple=is_couple,
                annees_lacunes=data.get("avsContributionYears")
                and max(0, 44 - int(data["avsContributionYears"]))
                or 0,
                life_expectancy=87,
            )
            values["avsRenteMensuelle"] = round(avs.rente_mensuelle)
            values["avsRenteAnnuelle"] = round(avs.rente_annuelle)
            if avs.rente_couple_mensuelle is not None:
                values["avsRenteCoupleMensuelle"] = round(
                    avs.rente_couple_mensuelle
                )
        except Exception as exc:  # defensive: calculator must never break overview
            logger.info("AVS estimate skipped: %s", exc)

    # Run LPP compare if we have a plausible projected capital
    avoir = data.get("avoirLpp") or 0
    if avoir and avoir > 10_000 and age:
        # Crude projection forward to 65 at 2% real return + insured salary*2%
        years_to_65 = max(0, 65 - age)
        insured = data.get("lppInsuredSalary") or 0
        projected = avoir * ((1.02) ** years_to_65) + insured * 0.18 * years_to_65
        try:
            lpp = LppConversionService().compare(
                capital_lpp=projected,
                canton=canton,
                retirement_age=65,
                life_expectancy=87,
            )
            values["lppProjectedCapital"] = round(projected)
            values["lppRenteMensuelleNette"] = round(
                lpp.option_rente_nette_mensuelle
            )
            values["lppCapitalNet"] = round(lpp.option_capital_net)
            values["lppBreakevenAge"] = lpp.breakeven_age
        except Exception as exc:
            logger.info("LPP compare skipped: %s", exc)

    missing = [
        k
        for k in ("lppInsuredSalary", "avoirLpp", "pillar3aAnnual")
        if data.get(k) in (None, "")
    ]
    return OverviewSection(
        present=bool(values), missing_fields=missing, values=values
    )


def _build_assurances_sociales(data: dict) -> OverviewSection:
    values = {
        k: data[k]
        for k in (
            "renteInvaliditeAnnuelle",
            "renteConjointAnnuelle",
            "renteEnfantAnnuelle",
            "capitalDeces",
        )
        if data.get(k) is not None
    }
    return OverviewSection(
        present=bool(values),
        missing_fields=[]
        if values
        else ["renteInvaliditeAnnuelle (lire du certificat LPP)"],
        values=values,
    )


def _build_dettes(data: dict) -> OverviewSection:
    has_debt = data.get("hasDebt")
    values: dict[str, Any] = {}
    if has_debt is not None:
        values["hasDebt"] = has_debt
    if data.get("totalDebt") is not None:
        values["totalDebt"] = data["totalDebt"]
    return OverviewSection(
        present=has_debt is not None,
        missing_fields=[] if has_debt is not None else ["hasDebt"],
        values=values,
    )


def _build_budget(data: dict) -> OverviewSection:
    """Surface budget summary in the overview without re-running CRUD."""
    raw = data.get("budget") or {}
    income_override = raw.get("income_monthly")
    profile_income = data.get("incomeNetMonthly")
    if income_override is not None:
        income = float(income_override)
    elif profile_income is not None:
        income = float(profile_income)
    else:
        income = 0.0
    fixed_lines = raw.get("fixed_lines") or []
    total_fixed = round(sum(float(l.get("amount", 0)) for l in fixed_lines), 2)
    var_t = float(raw.get("variable_target_monthly") or 0)
    sav_t = float(raw.get("savings_target_monthly") or 0)
    free_margin = round(income - total_fixed - var_t - sav_t, 2)
    savings_rate = round(sav_t / income, 4) if income > 0 else 0.0

    has_budget_setup = bool(fixed_lines) or sav_t > 0 or var_t > 0
    values: dict[str, Any] = {}
    if has_budget_setup:
        values = {
            "incomeMonthly": income,
            "totalFixedMonthly": total_fixed,
            "variableTargetMonthly": var_t,
            "savingsTargetMonthly": sav_t,
            "freeMarginMonthly": free_margin,
            "savingsRate": savings_rate,
            "linesCount": len(fixed_lines),
        }
    missing = [] if has_budget_setup else ["budget (PUT /api/v1/budget/me)"]
    return OverviewSection(
        present=has_budget_setup, missing_fields=missing, values=values
    )


def _build_couple(data: dict) -> OverviewSection:
    is_couple = data.get("householdType") in ("couple", "concubine", "family")
    if not is_couple:
        return OverviewSection(present=True, missing_fields=[], values={})
    values = {
        k: data[k]
        for k in (
            "spouseBirthYear",
            "spouseIncomeNetMonthly",
            "spouseAvsContributionYears",
            "householdGrossIncome",
        )
        if data.get(k) is not None
    }
    # Tag partial/complete based on spouse income presence
    status = "complete" if data.get("spouseIncomeNetMonthly") else "partial"
    values["status"] = status
    missing = (
        []
        if data.get("spouseIncomeNetMonthly")
        else ["spouseIncomeNetMonthly"]
    )
    return OverviewSection(
        present=True, missing_fields=missing, values=values
    )


def _compute_alertes(data: dict) -> list[str]:
    alertes: list[str] = []
    # LPP art. 7: salaried > 22'680 CHF/yr must have 2nd pillar
    emp = data.get("employmentStatus")
    gross = data.get("incomeGrossYearly")
    if (
        emp in ("salarie", "employee")
        and gross
        and gross > 22_680
        and data.get("has2ndPillar") is False
    ):
        alertes.append(
            "Salarié au-delà de 22'680 CHF/an — l'affiliation LPP est obligatoire. "
            "Vérifier avec l'employeur (LPP art. 7)."
        )
    # 3a cap for independent without LPP = 36'288, else 7'258
    p3a = data.get("pillar3aAnnual")
    has_lpp = data.get("has2ndPillar")
    if p3a and has_lpp is True and p3a > 7_258:
        alertes.append(
            "Versement 3a supérieur au plafond salarié avec LPP (7'258 CHF/an). "
            "Tout dépassement n'est pas déductible fiscalement."
        )
    if p3a and has_lpp is False and p3a > 36_288:
        alertes.append(
            "Versement 3a supérieur au plafond indépendant sans LPP "
            "(36'288 CHF/an, soit 20% du revenu net)."
        )
    # Debt flag without amount
    if data.get("hasDebt") is True and data.get("totalDebt") is None:
        alertes.append(
            "Dettes déclarées mais montant inconnu. Partage le total "
            "pour que MINT puisse prioriser (stratégie avalanche ou "
            "snowball selon le cas)."
        )
    return alertes


def _premier_eclairage(
    identity: OverviewSection,
    income: OverviewSection,
    prevoyance: OverviewSection,
    completeness: float,
) -> str:
    if completeness < 0.30:
        return (
            "On vient de commencer. Dis-moi ton âge, ton canton et ton "
            "salaire net — on pourra déjà sortir une première projection."
        )
    age = identity.values.get("age")
    canton = identity.values.get("canton")
    rente_lpp = prevoyance.values.get("lppRenteMensuelleNette")
    rente_avs = prevoyance.values.get("avsRenteMensuelle")
    if rente_lpp and rente_avs:
        total = rente_lpp + rente_avs
        return (
            f"À 65 ans, ta projection tourne autour de {total:.0f} CHF/mois "
            f"(AVS + LPP). Dis-moi tes dépenses cibles pour qu'on évalue "
            f"si c'est suffisant ou s'il faut combler."
        )
    if age and canton:
        return (
            f"{age} ans, {canton} — on a le squelette. Prochaine étape : "
            "renseigner ton LPP et ton 3a pour que je projette ta retraite."
        )
    return "Chaque info que tu partages me permet d'être plus précis."


# ── Endpoint ───────────────────────────────────────────────────────


@router.get("/me", response_model=OverviewResponse)
@limiter.limit("30/minute")
def get_overview_me(
    request: Request,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> OverviewResponse:
    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == current_user.id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )
    data = dict(profile.data) if profile and profile.data else {}

    sections = {
        "identity": _build_identity(data),
        "income": _build_income(data),
        "patrimoine": _build_patrimoine(data),
        "prevoyance": _build_prevoyance(data),
        "assurances_sociales": _build_assurances_sociales(data),
        "dettes": _build_dettes(data),
        "couple": _build_couple(data),
        "budget": _build_budget(data),
    }

    completeness = sum(
        _SECTION_WEIGHTS[name] * (1.0 if sec.present else 0.0)
        for name, sec in sections.items()
    )

    gaps: list[str] = []
    for name, sec in sections.items():
        for f in sec.missing_fields:
            gaps.append(f"{name}.{f}")

    alertes = _compute_alertes(data)
    eclairage = _premier_eclairage(
        sections["identity"], sections["income"],
        sections["prevoyance"], completeness,
    )

    return OverviewResponse(
        identity=sections["identity"],
        income=sections["income"],
        patrimoine=sections["patrimoine"],
        prevoyance=sections["prevoyance"],
        assurances_sociales=sections["assurances_sociales"],
        dettes=sections["dettes"],
        couple=sections["couple"],
        budget=sections["budget"],
        completeness_index=round(completeness, 2),
        profile_gaps=gaps,
        alertes=alertes,
        premier_eclairage=eclairage,
    )
