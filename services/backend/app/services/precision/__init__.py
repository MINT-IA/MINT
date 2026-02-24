"""
Precision module — Sprint S41: Guided Precision Entry.

Provides contextual help, cross-validation, smart defaults, and progressive
precision prompts to improve the quality of user-entered financial data.

Components:
    - PrecisionModels: FieldHelp, CrossValidationAlert, SmartDefault, PrecisionPrompt, PrecisionResult
    - PrecisionService: get_field_help(), cross_validate(), compute_smart_defaults(), get_precision_prompts()

Sources:
    - LPP art. 7, 8, 15-16 (prevoyance professionnelle)
    - LAVS art. 29ter, 34 (duree cotisation, rente)
    - OPP3 art. 7 (plafond 3a)
    - LIFD art. 38 (imposition du capital)
"""

from app.services.precision.precision_models import (
    FieldHelp,
    CrossValidationAlert,
    SmartDefault,
    PrecisionPrompt,
    PrecisionResult,
)
from app.services.precision.precision_service import (
    get_field_help,
    cross_validate,
    compute_smart_defaults,
    get_precision_prompts,
)

__all__ = [
    "FieldHelp",
    "CrossValidationAlert",
    "SmartDefault",
    "PrecisionPrompt",
    "PrecisionResult",
    "get_field_help",
    "cross_validate",
    "compute_smart_defaults",
    "get_precision_prompts",
]
