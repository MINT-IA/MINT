"""Property transmission scenario for succession planning.

This module turns the Raiffeisen-style article pattern into a deterministic
educational scenario: transmitting a family home before death has to be
checked in a fixed order: parents' retirement affordability, family
equalization, then cantonal tax/formalities.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any


DEFAULT_SCENARIO_KEY = "article_raiffeisen_transmission_logement"

DISCLAIMER = (
    "Information éducative. Les montants sont des estimations indicatives "
    "basées sur les données fournies. Elles ne remplacent pas une analyse "
    "notariale, fiscale ou patrimoniale adaptée à la situation concrète."
)

SOURCES = [
    "Article partenaire Raiffeisen: transmettre son logement, répercussions patrimoine/prévoyance/succession",
    "ch.ch: impôt sur les donations, pas d'impôt fédéral, règles cantonales",
    "CC art. 457-462: parts légales",
    "CC art. 470-471: réserves héréditaires depuis 2023",
    "CC art. 626: rapport des donations / avancement d'hoirie",
    "CC art. 745 ss: usufruit",
    "CC art. 776 ss: droit d'habitation",
    "Formalités cantonales: acte authentique et registre foncier pour l'immobilier",
]

REQUIRED_INPUTS = (
    "propertyMarketValue",
    "mortgageBalance",
    "parentLiquidAssets",
    "parentAnnualRetirementIncome",
    "parentAnnualLivingCosts",
    "heirsCount",
)
REQUIRED_TEXT_INPUTS = (
    "canton",
)
CRITICAL_ASSUMPTIONS = (
    "cashPaidByRecipient",
    "mortgageAssumedByRecipient",
    "recipientRelationship",
    "retainedRight",
    "avancementHoirie",
)

FRESHNESS_TRACKED_INPUTS = (
    "propertyMarketValue",
    "mortgageBalance",
    "parentLiquidAssets",
    "parentAnnualRetirementIncome",
    "parentAnnualLivingCosts",
)
SOURCE_DATE_STALE_AFTER_DAYS = 365


def _has_numeric_input(inputs: dict[str, Any], key: str) -> bool:
    value = inputs.get(key)
    if value is None or isinstance(value, bool):
        return False
    try:
        float(value)
    except (TypeError, ValueError):
        return False
    return True


def _missing_required_inputs(inputs: dict[str, Any]) -> list[str]:
    missing = [key for key in REQUIRED_INPUTS if not _has_numeric_input(inputs, key)]
    missing.extend(key for key in REQUIRED_TEXT_INPUTS if not _has_text_input(inputs, key))
    return missing


def _has_text_input(inputs: dict[str, Any], key: str) -> bool:
    value = inputs.get(key)
    return isinstance(value, str) and bool(value.strip())


def _has_bool_input(inputs: dict[str, Any], key: str) -> bool:
    return isinstance(inputs.get(key), bool)


def _has_critical_assumption(inputs: dict[str, Any], key: str) -> bool:
    if key in ("cashPaidByRecipient", "mortgageAssumedByRecipient"):
        return _has_numeric_input(inputs, key)
    if key == "avancementHoirie":
        return _has_bool_input(inputs, key)
    return _has_text_input(inputs, key)


def _missing_critical_assumptions(inputs: dict[str, Any]) -> list[str]:
    return [
        key for key in CRITICAL_ASSUMPTIONS if not _has_critical_assumption(inputs, key)
    ]


def _assumption_value(inputs: dict[str, Any], key: str) -> Any:
    if not _has_critical_assumption(inputs, key):
        return None
    if key in ("cashPaidByRecipient", "mortgageAssumedByRecipient"):
        return _round_money(_num(inputs, key))
    return inputs[key]


def _assumptions_summary(inputs: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        key: {
            "status": "explicit" if _has_critical_assumption(inputs, key) else "missing",
            "value": _assumption_value(inputs, key),
        }
        for key in CRITICAL_ASSUMPTIONS
    }


def _num(inputs: dict[str, Any], key: str, default: float = 0.0) -> float:
    value = inputs.get(key, default)
    if value is None:
        return default
    if isinstance(value, bool):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _int(inputs: dict[str, Any], key: str, default: int = 0) -> int:
    value = inputs.get(key, default)
    if value is None:
        return default
    if isinstance(value, bool):
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _round_money(value: float) -> int:
    return int(round(value))


def _round_years(value: float) -> float:
    return round(value, 2)


def _private_input_provenance(inputs: dict[str, Any]) -> dict[str, Any]:
    provenance = inputs.get("_inputProvenance")
    return provenance if isinstance(provenance, dict) else {}


def _as_of_date(inputs: dict[str, Any]) -> date:
    raw = inputs.get("_freshnessAsOf")
    if isinstance(raw, str):
        try:
            return datetime.fromisoformat(raw.replace("Z", "+00:00")).date()
        except ValueError:
            pass
    return date.today()


def _source_date(meta: Any) -> date | None:
    if not isinstance(meta, dict):
        return None
    raw = meta.get("source_date") or meta.get("sourceDate")
    if not isinstance(raw, str) or not raw.strip():
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def _freshness_summary(inputs: dict[str, Any], missing_inputs: list[str]) -> dict[str, Any]:
    if missing_inputs:
        return {
            "status": "missing_required_inputs",
            "datedInputs": [],
            "missingSourceDates": [
                key for key in FRESHNESS_TRACKED_INPUTS if key not in missing_inputs
            ],
            "staleInputs": [],
            "asOfDate": _as_of_date(inputs).isoformat(),
        }

    provenance = _private_input_provenance(inputs)
    as_of = _as_of_date(inputs)
    dated_inputs: list[str] = []
    missing_source_dates: list[str] = []
    stale_inputs: list[str] = []

    for key in FRESHNESS_TRACKED_INPUTS:
        source_date = _source_date(provenance.get(key))
        if source_date is None:
            missing_source_dates.append(key)
            continue
        dated_inputs.append(key)
        if (as_of - source_date).days > SOURCE_DATE_STALE_AFTER_DAYS:
            stale_inputs.append(key)

    if stale_inputs:
        status = "stale_source_dates"
    elif missing_source_dates and dated_inputs:
        status = "partial_source_dates"
    elif missing_source_dates:
        status = "missing_source_dates"
    else:
        status = "current_source_dates"

    return {
        "status": status,
        "datedInputs": dated_inputs,
        "missingSourceDates": missing_source_dates,
        "staleInputs": stale_inputs,
        "asOfDate": as_of.isoformat(),
    }


def _retained_right_label(retained_right: str) -> str:
    labels = {
        "none": "Aucun droit réservé",
        "habitation": "Droit d'habitation",
        "usufruct": "Usufruit",
        "usufruit": "Usufruit",
    }
    return labels.get(retained_right, retained_right)


def _retained_right_notes(retained_right: str) -> list[str]:
    if retained_right == "habitation":
        return [
            "Le droit d'habitation permet aux parents de rester dans le logement.",
            "Il est personnel: il ne se transmet pas et ne permet en principe pas de louer le bien.",
            "La charge fiscale et les frais doivent être vérifiés selon le canton et l'acte.",
        ]
    if retained_right in ("usufruct", "usufruit"):
        return [
            "L'usufruit permet d'habiter le logement ou de percevoir le revenu locatif.",
            "L'usufruitier supporte typiquement davantage de charges courantes que le titulaire d'un simple droit d'habitation.",
            "La valeur fiscale de l'usufruit dépend notamment de l'âge et du canton.",
        ]
    return [
        "Sans droit réservé, les parents doivent clarifier leur futur logement et leurs coûts de vie.",
    ]


def _retirement_affordability(
    annual_income: float,
    annual_costs: float,
    liquidity_after_transfer: float,
) -> dict[str, Any]:
    annual_margin = annual_income - annual_costs
    coverage_years = (
        liquidity_after_transfer / annual_costs
        if annual_costs > 0
        else 99.0
    )

    reasons: list[str] = []
    if annual_margin < 0:
        reasons.append(
            "Les coûts annuels dépassent le revenu de retraite indiqué."
        )
    if coverage_years < 3:
        reasons.append(
            "La réserve liquide après transfert couvre moins de trois ans de coûts."
        )

    status = "ok"
    if annual_margin < 0 or coverage_years < 3:
        status = "needs_review"

    return {
        "rank": 1,
        "status": status,
        "annualMargin": _round_money(annual_margin),
        "liquidityCoverageYears": _round_years(coverage_years),
        "reasons": reasons,
    }


def _family_equalization(
    economic_transfer_value: float,
    heirs_count: int,
    liquidity_after_transfer: float,
    avancement_hoirie: bool | None,
) -> dict[str, Any]:
    if heirs_count <= 1:
        return {
            "rank": 2,
            "status": "not_applicable",
            "immediateEqualizationNeedPerOtherHeir": 0,
            "immediateEqualizationGap": 0,
            "notes": [
                "Aucun autre héritier indiqué: le risque d'égalisation familiale n'est pas chiffré ici.",
            ],
        }

    need_per_other_heir = economic_transfer_value / heirs_count
    other_heirs_count = max(0, heirs_count - 1)
    total_equalization_need = need_per_other_heir * other_heirs_count
    gap = max(0.0, total_equalization_need - liquidity_after_transfer)
    status = "ok" if gap <= 0 else "at_risk"

    if avancement_hoirie is None:
        report_note = (
            "Le statut d'avancement d'hoirie ou de dispense de rapport doit être confirmé."
        )
    elif avancement_hoirie:
        report_note = (
            "L'avancement d'hoirie doit être documenté pour le partage successoral futur."
        )
    else:
        report_note = (
            "Une dispense de rapport doit être explicite et reste limitée par les réserves."
        )

    notes = [
        report_note,
        "L'enjeu pratique est de savoir si les autres héritiers peuvent être traités de façon équitable.",
    ]

    return {
        "rank": 2,
        "status": status,
        "immediateEqualizationNeedPerOtherHeir": _round_money(need_per_other_heir),
        "immediateEqualizationNeedTotal": _round_money(total_equalization_need),
        "immediateEqualizationGap": _round_money(gap),
        "notes": notes,
    }


def _cantonal_tax(canton: str, relationship: str, retained_right: str) -> dict[str, Any]:
    notes = [
        "Il n'existe pas d'impôt fédéral sur les donations; les règles sont cantonales.",
        "Le bénéficiaire paie en principe l'impôt sur les donations.",
        "Pour un immeuble, le canton de situation du bien et la commune doivent être vérifiés.",
    ]
    if relationship == "descendant":
        notes.append(
            "Les descendants sont souvent exonérés ou faiblement imposés, mais il existe des exceptions cantonales."
        )
    if retained_right in ("habitation", "usufruct", "usufruit"):
        notes.append(
            "Un droit d'habitation ou un usufruit peut modifier la valeur fiscale et les personnes imposées."
        )

    return {
        "rank": 3,
        "canton": canton,
        "requiresCantonalReview": True,
        "notes": notes,
    }


def _scenario_confidence_rationale(
    requires_input_completion: bool,
    missing_inputs: list[str],
    missing_assumptions: list[str],
    validation_warnings: list[dict[str, Any]],
    inputs: dict[str, Any],
    freshness: dict[str, Any] | None = None,
) -> dict[str, Any]:
    missing_required = [key for key in missing_inputs if key in REQUIRED_INPUTS]
    missing_required.extend(key for key in missing_inputs if key in REQUIRED_TEXT_INPUTS)
    freshness = freshness or _freshness_summary(inputs, missing_required)
    if missing_required:
        completeness = "none"
        basis = "missing_required_inputs"
    elif freshness["staleInputs"]:
        completeness = "low"
        basis = "stale_source_dates"
    elif missing_assumptions:
        completeness = "low"
        basis = "missing_critical_assumptions"
    elif validation_warnings:
        completeness = "medium"
        basis = "validation_needs_confirmation"
    else:
        completeness = "medium"
        basis = "required_inputs_present"

    return {
        "basis": basis,
        "axes": {
            "completeness": completeness,
            "accuracy": (
                "needs_bank_or_notary_confirmation"
                if validation_warnings
                else "source_dependent"
            ),
            "freshness": freshness["status"],
            "understanding": "educational_triage",
        },
        "missingInputs": missing_inputs,
        "missingAssumptions": missing_assumptions,
        "validationWarnings": validation_warnings,
        "sourceDateSummary": freshness,
        "limits": [
            "Scenario confidence is not a legal decision.",
            "Accuracy depends on document quality and specialist review.",
            "Freshness depends on source dates and updated mortgage/pension values.",
        ],
    }


def _mortgage_validation_warnings(inputs: dict[str, Any]) -> list[dict[str, Any]]:
    mortgage_known = _has_numeric_input(inputs, "mortgageBalance")
    assumed_known = _has_numeric_input(inputs, "mortgageAssumedByRecipient")
    if not mortgage_known or not assumed_known:
        return [
            {
                "field": "mortgageAssumedByRecipient",
                "code": "mortgage_assumption_confirmation_required",
                "message": (
                    "La reprise hypothécaire doit être confirmée avec la banque "
                    "et le notaire avant de chiffrer le transfert."
                ),
            }
        ]

    mortgage_balance = _num(inputs, "mortgageBalance")
    mortgage_assumed = _num(inputs, "mortgageAssumedByRecipient")
    if 0 <= mortgage_assumed <= mortgage_balance:
        return []
    return [
        {
            "field": "mortgageAssumedByRecipient",
            "code": "mortgage_assumption_out_of_range",
            "message": (
                "La reprise hypothécaire indiquée doit être comprise entre 0 CHF "
                "et le solde hypothécaire connu, puis confirmée avec la banque "
                "et le notaire."
            ),
        }
    ]


def compute_property_transmission_scenario(inputs: dict[str, Any]) -> dict[str, Any]:
    """Compute the educational property-transmission scenario.

    Expected input keys are camelCase because they come from the public
    scenarios API.
    """
    scenario_key = inputs.get("scenarioKey") or DEFAULT_SCENARIO_KEY
    canton = str(inputs["canton"]).upper() if _has_text_input(inputs, "canton") else "unknown"
    relationship = (
        str(inputs["recipientRelationship"])
        if _has_critical_assumption(inputs, "recipientRelationship")
        else "unknown"
    )
    retained_right = (
        str(inputs["retainedRight"])
        if _has_critical_assumption(inputs, "retainedRight")
        else "unknown"
    )
    avancement_hoirie = (
        bool(inputs["avancementHoirie"])
        if _has_critical_assumption(inputs, "avancementHoirie")
        else None
    )

    property_value = _num(inputs, "propertyMarketValue")
    mortgage_balance = _num(inputs, "mortgageBalance")
    cash_paid = (
        _num(inputs, "cashPaidByRecipient")
        if _has_critical_assumption(inputs, "cashPaidByRecipient")
        else None
    )
    mortgage_assumed = (
        _num(inputs, "mortgageAssumedByRecipient")
        if _has_critical_assumption(inputs, "mortgageAssumedByRecipient")
        else None
    )
    parent_liquid_assets = _num(inputs, "parentLiquidAssets")
    annual_income = _num(inputs, "parentAnnualRetirementIncome")
    annual_costs = _num(inputs, "parentAnnualLivingCosts")
    heirs_count = max(0, _int(inputs, "heirsCount"))

    property_equity = max(0.0, property_value - mortgage_balance)
    economic_transfer_value = (
        max(0.0, property_value - cash_paid - mortgage_assumed)
        if cash_paid is not None and mortgage_assumed is not None
        else None
    )
    parent_liquidity_after_transfer = (
        parent_liquid_assets + cash_paid if cash_paid is not None else None
    )

    retirement = _retirement_affordability(
        annual_income,
        annual_costs,
        parent_liquidity_after_transfer or 0.0,
    )
    equalization = _family_equalization(
        economic_transfer_value or 0.0,
        heirs_count,
        parent_liquidity_after_transfer or 0.0,
        avancement_hoirie,
    )
    missing_required_inputs = _missing_required_inputs(inputs)
    missing_assumptions = _missing_critical_assumptions(inputs)
    missing_inputs = [*missing_required_inputs, *missing_assumptions]
    validation_warnings = _mortgage_validation_warnings(inputs)
    freshness = _freshness_summary(inputs, missing_required_inputs)
    inputs_needing_reconfirmation = list(freshness["staleInputs"])
    requires_input_completion = bool(missing_inputs or inputs_needing_reconfirmation)
    if requires_input_completion:
        if missing_inputs:
            missing_note = (
                "Données requises manquantes avant modélisation: "
                + ", ".join(missing_inputs)
            )
            retirement = {
                **retirement,
                "status": "missing_data",
                "reasons": [missing_note, *retirement.get("reasons", [])],
            }
            equalization = {
                **equalization,
                "status": "missing_data",
                "notes": [missing_note, *equalization.get("notes", [])],
            }
        if inputs_needing_reconfirmation:
            stale_note = (
                "Données à reconfirmer car les dates sources sont anciennes: "
                + ", ".join(inputs_needing_reconfirmation)
            )
            retirement = {
                **retirement,
                "reasons": [*retirement.get("reasons", []), stale_note],
            }
            equalization = {
                **equalization,
                "notes": [*equalization.get("notes", []), stale_note],
            }
    if validation_warnings:
        confirmation_note = (
            "La reprise hypothécaire doit être vérifiée avec la banque et le notaire."
        )
        retirement = {
            **retirement,
            "reasons": [*retirement.get("reasons", []), confirmation_note],
        }
        equalization = {
            **equalization,
            "notes": [*equalization.get("notes", []), confirmation_note],
        }

    if missing_required_inputs:
        scenario_confidence = "none"
    elif inputs_needing_reconfirmation:
        scenario_confidence = "low"
    elif missing_assumptions or validation_warnings:
        scenario_confidence = "low"
    else:
        scenario_confidence = "medium"

    return {
        "scenarioKey": scenario_key,
        "scenarioKind": "succession",
        "scenarioConfidence": scenario_confidence,
        "scenarioConfidenceRationale": _scenario_confidence_rationale(
            requires_input_completion,
            missing_inputs,
            missing_assumptions,
            validation_warnings,
            inputs,
            freshness,
        ),
        "requiresInputCompletion": requires_input_completion,
        "missingInputs": missing_inputs,
        "missingAssumptions": missing_assumptions,
        "inputsNeedingReconfirmation": inputs_needing_reconfirmation,
        "assumptions": _assumptions_summary(inputs),
        "validationWarnings": validation_warnings,
        "modelScope": {
            "classification": "educational_triage",
            "notLegalPartition": True,
            "requiresSpecialistReview": True,
            "unmodelledLegalFactors": [
                "statut du conjoint ou partenaire enregistré",
                "régime matrimonial et liquidation préalable",
                "parts légales et réserves héréditaires de chaque héritier",
                "testament, pacte successoral ou dispense de rapport",
                "valeur et composition de l'ensemble de la succession",
                "lien de parenté exact et règles fiscales cantonales applicables",
            ],
        },
        "articleThesis": (
            "Transmettre un logement n'est pas seulement un geste familial: "
            "c'est une décision qui touche la retraite des parents, l'équité "
            "entre héritiers, la fiscalité cantonale et les formalités immobilières."
        ),
        "computed": {
            "propertyMarketValue": _round_money(property_value),
            "mortgageBalance": _round_money(mortgage_balance),
            "propertyEquity": _round_money(property_equity),
            "cashPaidByRecipient": (
                _round_money(cash_paid) if cash_paid is not None else None
            ),
            "mortgageAssumedByRecipient": (
                _round_money(mortgage_assumed)
                if mortgage_assumed is not None
                else None
            ),
            "economicTransferValue": (
                _round_money(economic_transfer_value)
                if economic_transfer_value is not None
                else None
            ),
            "parentLiquidityAfterTransfer": (
                _round_money(parent_liquidity_after_transfer)
                if parent_liquidity_after_transfer is not None
                else None
            ),
            "annualRetirementMargin": retirement["annualMargin"],
        },
        "retirementAffordability": retirement,
        "familyEqualization": equalization,
        "cantonalTax": _cantonal_tax(canton, relationship, retained_right),
        "retainedRight": {
            "type": retained_right,
            "label": _retained_right_label(retained_right),
            "notes": _retained_right_notes(retained_right),
        },
        "variants": [
            {
                "key": "market_sale",
                "label": "Vente au prix de marché",
                "mainTradeoff": "Liquidité parentale plus claire, fiscalité immobilière souvent plus visible.",
            },
            {
                "key": "advance_inheritance",
                "label": "Avancement d'hoirie",
                "mainTradeoff": "Transmission familiale anticipée, avec rapport successoral à documenter.",
            },
            {
                "key": "mixed_donation",
                "label": "Donation mixte",
                "mainTradeoff": "Prix réduit pour l'enfant, mais besoin de clarifier l'égalité entre héritiers.",
            },
            {
                "key": "retained_habitation_or_usufruct",
                "label": "Droit d'habitation ou usufruit",
                "mainTradeoff": "Maintien possible dans le logement, avec effets fiscaux et charges à modéliser.",
            },
        ],
        "formalities": [
            "Faire estimer la valeur du bien par une base documentée.",
            "Chiffrer l'hypothèque reprise et les flux de liquidité.",
            "Vérifier la capacité de retraite des parents avant l'effet fiscal.",
            "Documenter l'avancement d'hoirie ou la dispense de rapport.",
            "Passer par un notaire pour l'acte immobilier.",
            "Inscrire le transfert et les droits réels au registre foncier.",
        ],
        "nextQuestions": [
            "Quelle est la valeur de marché documentée du logement ?",
            "Quel solde hypothécaire serait repris par l'enfant ?",
            "Les parents conservent-ils un droit d'habitation ou un usufruit ?",
            "Combien d'héritiers doivent être pris en compte ?",
            "La réserve de liquidité des parents reste-t-elle suffisante après le transfert ?",
        ],
        "disclaimer": DISCLAIMER,
        "sources": SOURCES,
    }
