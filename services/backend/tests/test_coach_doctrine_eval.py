"""Wave 6.5 — doctrine eval fixture.

Validates that reference responses crafted under the amended MINT
information doctrine pass ≥80% of mechanical checks. Reference answers
are kept in `tests/fixtures/coach_doctrine_eval.json`; any future drift
in `app/services/coach/doctrine_checks.py` will immediately show up here.

This test does NOT call the live LLM. It enforces the *specification*:
"the amended rule should produce responses that pass these checks, and
the crafted goldens prove the specification is self-consistent."

A second entry point (`bench_coach_live.py` — out of CI) will run the
actual coach against the same fixture when we need live grading.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.coach.doctrine_checks import (
    QuestionMeta,
    score_response,
)

FIXTURE_PATH = (
    Path(__file__).parent / "fixtures" / "coach_doctrine_eval.json"
)

# Gate: crafted responses must pass every single check. The 80% target
# in the wave plan applies to LIVE LLM output (bench), not to the
# reference goldens — references are the ceiling, not the average.
REFERENCE_MIN_SCORE = 100.0

# When aggregated across all 10 fixtures, the population still must score
# 100% on the reference set; anything less means we shipped a bad golden.
POPULATION_MIN_SCORE = 100.0


def _load_fixture() -> list[dict]:
    with FIXTURE_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    return data["fixtures"]


FIXTURES = _load_fixture()


@pytest.mark.parametrize("case", FIXTURES, ids=[f["id"] for f in FIXTURES])
def test_reference_response_passes_doctrine(case: dict) -> None:
    meta = QuestionMeta(
        archetype=case["meta"]["archetype"],
        life_event=case["meta"]["life_event"],
        irreversible=case["meta"]["irreversible"],
        existential=case["meta"]["existential"],
    )
    report = score_response(case["doctrine_response"], meta)
    failures = report.failures()
    assert not failures, (
        f"{case['id']}: {len(failures)} check(s) failed — "
        + "; ".join(f"{c.name}: {c.reason}" for c in failures)
        + f"\n\nResponse was:\n{case['doctrine_response']}"
    )
    assert report.score >= REFERENCE_MIN_SCORE, (
        f"{case['id']}: score {report.score:.0f} < {REFERENCE_MIN_SCORE}"
    )


def test_reference_population_passes_80_pct_gate() -> None:
    """Even if individual tests above passed, assert population gate
    independently. This is the same number we'll use on live coach output."""
    scores: list[float] = []
    for case in FIXTURES:
        meta = QuestionMeta(**case["meta"])
        report = score_response(case["doctrine_response"], meta)
        scores.append(report.score)

    avg = sum(scores) / len(scores)
    assert avg >= POPULATION_MIN_SCORE, (
        f"population avg {avg:.1f}% < {POPULATION_MIN_SCORE}% gate"
    )


def test_fixture_coverage_matches_adversarial_categories() -> None:
    """Adversarial panel demanded: 3 existential, 2 non-swiss archetype,
    2 irreversible, 3 standard. Guard against silent regression of the
    fixture."""
    existential = [f for f in FIXTURES if f["meta"]["existential"]]
    irreversible = [f for f in FIXTURES if f["meta"]["irreversible"]]
    non_swiss = [
        f for f in FIXTURES if f["meta"]["archetype"] != "swiss_native"
    ]
    standard = [
        f
        for f in FIXTURES
        if not f["meta"]["existential"]
        and not f["meta"]["irreversible"]
        and f["meta"]["archetype"] == "swiss_native"
    ]
    assert len(existential) >= 3, f"need ≥3 existential, got {len(existential)}"
    assert len(irreversible) >= 2, f"need ≥2 irreversible, got {len(irreversible)}"
    assert len(non_swiss) >= 2, f"need ≥2 non-swiss archetype, got {len(non_swiss)}"
    assert len(standard) >= 3, f"need ≥3 standard baseline, got {len(standard)}"
