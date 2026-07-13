"""G1-AVS-03 — quarantine unofficial AVS gap effects in the backend.

A residence/declaration year count is not an official AVS scale or amount.
Until the compensation office has supplied that result, the backend may only
help the user obtain/review the CI; it must not turn ``yearsAbroad`` or
``yearsInCh`` into a pension, CHF loss, or personal reduction.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from app.services.precision.precision_service import (
    get_field_help,
    get_precision_prompts,
)
from app.services.rag.faq_service import FaqService


BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_ROOT.parents[1]

# Deterministic inventory of the dangerous backend contracts found by the
# Swiss-domain review.  Keeping the exact symbols/claims here makes a later
# reintroduction fail loudly instead of relying on a reviewer to remember them.
FORBIDDEN_BACKEND_CLAIMS = {
    "app/api/v1/endpoints/expat.py": (
        'router.post("/avs-gap"',
        "def estimate_avs_gap",
        "AVSGapRequest",
        "AVSGapResponse",
    ),
    "app/schemas/expat.py": (
        "class AVSGapRequest",
        "class AVSGapResponse",
        "rente_estimee_mensuelle",
        "reduction_mensuelle",
        "reduction_annuelle",
    ),
    "app/services/expat/expat_service.py": (
        "class AVSGapResult",
        "def estimate_avs_gap",
        "AVS_REDUCTION_PAR_ANNEE_LACUNE",
        "Rente estimee = rente max",
    ),
}


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"yearsAbroad": None, "yearsInCh": None},
        {"yearsAbroad": 0, "yearsInCh": 0},
        {"yearsAbroad": 2, "yearsInCh": 42},
        {"yearsAbroad": 4, "yearsInCh": 40},
        {"yearsAbroad": 9, "yearsInCh": 35},
        # A cohort/sex hint cannot make a gap-only pricing request sufficient.
        {"yearsAbroad": 4, "yearsInCh": 39, "birthYear": 1960, "sex": "female"},
        {"yearsAbroad": 4, "yearsInCh": 40, "birthYear": 1964, "sex": "female"},
        {"yearsAbroad": 4, "yearsInCh": 40, "birthYear": 1964, "sex": "male"},
    ],
)
def test_gap_only_api_is_retired_instead_of_pricing_a_personal_pension(client, payload):
    response = client.post("/api/v1/expat/avs-gap", json=payload)

    assert response.status_code == 404
    assert response.json() == {"detail": "Not Found"}


def test_dangerous_gap_pricing_contracts_are_absent_from_production_backend():
    for relative_path, forbidden_claims in FORBIDDEN_BACKEND_CLAIMS.items():
        source = (BACKEND_ROOT / relative_path).read_text(encoding="utf-8")
        for claim in forbidden_claims:
            assert claim not in source, f"{relative_path} still exposes {claim!r}"

    for openapi_name in ("mint.openapi.canonical.json", "openapi.json"):
        openapi = (REPO_ROOT / "tools/openapi" / openapi_name).read_text(
            encoding="utf-8"
        )
        assert '"/api/v1/expat/avs-gap"' not in openapi
        assert '"AVSGapRequest"' not in openapi
        assert '"AVSGapResponse"' not in openapi


def test_avs_precision_help_never_infers_a_pension_from_age_or_years():
    fallback = get_field_help("avs_contribution_years").fallback_estimation
    normalized = fallback.casefold()

    assert "extrait" in normalized
    assert "caisse" in normalized
    assert "age - 20" not in normalized
    assert "44 ans" not in normalized
    assert "rente avs pleine" not in normalized
    assert "au franc près" not in normalized


def test_avs_precision_prompt_promises_ci_review_not_a_gap_priced_pension():
    prompts = get_precision_prompts("retirement_projection", {})
    prompt = next(
        item for item in prompts if item.field_needed == "avs_contribution_years"
    )
    copy = f"{prompt.prompt_text} {prompt.impact_text}".casefold()

    assert "extrait" in copy
    assert "caisse" in copy
    assert "au franc près" not in copy
    assert "2.3%" not in copy
    assert "détermine ta rente" not in copy


def test_avs_gap_faq_is_count_only_and_defers_the_official_effect_to_the_caisse():
    faq = FaqService.by_id("faq_lacunes_avs_couts")

    assert faq is not None
    normalized = faq.answer.casefold()
    assert "extrait" in normalized
    assert "caisse" in normalized
    assert "1/44" not in normalized
    assert "chf" not in normalized
    assert "rente supplémentaire" not in normalized
    assert "rentabilis" not in normalized
