"""Mobile↔Backend differential harness — CALC-01 (CONTEXT 92.5 D-01..D-07).

Spawns the Dart binary calc_harness_dart ONCE per pytest session
(fixture-scoped subprocess), pipes the 80 fixtures from
calc_diff_v1.jsonl as JSONL on stdin, parses JSONL on stdout, and
asserts each row's per-axis output matches the existing Python helper
within tolerance per CONTEXT D-06.

Mobile is the canonical source per ADR-20260223. When divergence
exceeds tolerance, the failure-comment template at
.github/workflows/calc-rigor-failure-comment.md (added by plan 92.5-04)
explains : « Mobile (canonique) : X, Backend (sous test) : Y, divergence :
|X-Y| > tolerance ».

NEVER re-implement Dart calculators in Python here. Tests target
existing helpers in app/constants/social_insurance.py only — full port
deferred to backlog 999.4 / Phase 92.6 (CONTEXT D-03). Per CLAUDE.md §4
NEVER #3.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from app.constants.social_insurance import (
    get_ai_rente_monthly,
    get_lpp_bonification_rate,
    rente_from_ramd,
)
from app.services.fiscal.cantonal_comparator import (
    estimate_capital_withdrawal_tax,
)

# ──────────────────────────────────────────────────────────────────────
# Tolerances per CONTEXT D-06 (ROADMAP §92.5 success criterion #1).
# DO NOT relax without an ADR. Tightening is fine.
# ──────────────────────────────────────────────────────────────────────
TOL_RENTE_CHF = 1.0           # AVS / AI / LPP rentes — D-06 : rentes ±1 CHF.
TOL_CANTON_TAX_CHF = 5.0      # Canton tax — D-06 : canton tax ±5 CHF.
TOL_RATIO = 0.05              # Small ratios (LPP bonification rate) — D-06 : ±0.05.

REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURE_PATH = (
    REPO_ROOT
    / "services/backend/tests/fixtures/calc_diff_v1.jsonl"
)
DART_BIN_DEFAULT = REPO_ROOT / "build" / "calc_harness_dart"
# CI-overridable via env: workflow can set CALC_HARNESS_BIN=/tmp/calc_harness_dart.
DART_BIN = Path(os.environ.get("CALC_HARNESS_BIN", str(DART_BIN_DEFAULT)))


def _python_capital_tax(canton: str, amount: float, married: bool) -> float:
    """Python-side computation matching Dart RetirementTaxCalculator.capitalWithdrawalTax.

    Modèle canonique v2 ``estimate_capital_withdrawal_tax`` (IFD art. 38 +
    interpolation ESTV cantonal ; état civil marié interpole
    ``CANTONAL_CAPITAL_TAX_MARRIED_CHF``) — miroir exact du Dart
    ``estimateCapitalWithdrawalTaxV2``. Le rabais forfaitaire par canton a
    été supprimé (triage AnnAssign #1095). NEVER re-implements brackets here
    (CLAUDE.md §4 NEVER #3, ADR-20260223).
    """
    return estimate_capital_withdrawal_tax(amount, canton, is_married=married)


@pytest.fixture(scope="session")
def fixtures() -> list[dict]:
    """Load the frozen 80-fixture matrix (CONTEXT D-08)."""
    assert FIXTURE_PATH.exists(), f"fixture file missing: {FIXTURE_PATH}"
    rows = [
        json.loads(line)
        for line in FIXTURE_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    assert len(rows) == 80, f"expected 80 fixtures per CONTEXT D-08, got {len(rows)}"
    return rows


@pytest.fixture(scope="session")
def dart_outputs(fixtures: list[dict]) -> dict[str, dict]:
    """Spawn the Dart binary ONCE, pipe all fixtures, collect outputs by id."""
    if not DART_BIN.exists():
        pytest.skip(
            f"Dart binary not built at {DART_BIN}. "
            "Run: cd apps/mobile && dart compile exe tools/calc_harness/main.dart "
            f"-o {DART_BIN}",
        )
    payload = "\n".join(json.dumps(f) for f in fixtures) + "\n"
    proc = subprocess.run(
        [str(DART_BIN)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert proc.returncode == 0, (
        f"calc_harness_dart exited {proc.returncode}\nstderr: {proc.stderr}"
    )
    outs: dict[str, dict] = {}
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        outs[row["id"]] = row
    assert len(outs) == len(fixtures), "Dart binary dropped or duplicated rows"
    return outs


@pytest.mark.parametrize(
    "axis",
    [
        "capital_withdrawal_tax",
        "lpp_bonification_rate",
        "avs_rente_from_ramd",
        "ai_rente_monthly",
    ],
)
def test_axis_within_tolerance(
    fixtures: list[dict],
    dart_outputs: dict[str, dict],
    axis: str,
) -> None:
    """For each fixture, assert |Mobile (canonique) − Backend (sous test)| ≤ tolerance."""
    failures: list[str] = []
    for fx in fixtures:
        mobile = dart_outputs[fx["id"]][axis]
        if axis == "capital_withdrawal_tax":
            backend = _python_capital_tax(
                canton=fx["canton"],
                amount=fx["capital_withdrawal_amount"],
                married=(fx["marital_status"] == "married"),
            )
            tol = TOL_CANTON_TAX_CHF
        elif axis == "lpp_bonification_rate":
            backend = get_lpp_bonification_rate(fx["age"])
            tol = TOL_RATIO
        elif axis == "avs_rente_from_ramd":
            backend = rente_from_ramd(fx["gross_annual_salary"])
            tol = TOL_RENTE_CHF
        elif axis == "ai_rente_monthly":
            backend = get_ai_rente_monthly(fx["ai_disability_degree"])
            tol = TOL_RENTE_CHF
        else:
            raise AssertionError(f"unknown axis {axis}")
        diff = abs(mobile - backend)
        if diff > tol:
            failures.append(
                # Failure-message format per CONTEXT 92.5 specifics line 169 :
                # « Mobile (canonique) : X, Backend (sous test) : Y, divergence : |X-Y| > tolerance ».
                f"id={fx['id']} axis={axis} "
                f"Mobile (canonique)={mobile} Backend (sous test)={backend} "
                f"divergence={diff} tolerance={tol}",
            )
    assert not failures, (
        "Differential divergences (Mobile canonique vs Backend sous test) :\n"
        + "\n".join(failures)
    )
