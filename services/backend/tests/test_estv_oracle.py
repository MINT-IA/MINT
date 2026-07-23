"""ESTV oracle pytest matcher — CALC-03 (CONTEXT 92.5 D-11/D-12/D-14).

Per fixture vector v in `tests/fixtures/estv_oracle_2025.jsonl`:
  Compare MINT computed canton tax vs ESTV expected_tax_chf.
  Tolerance: TOL_CHF = +/-5 CHF (CONTEXT 92.5 D-14, same as differential
  canton tax tolerance from CONTEXT 92.5 D-06).

If MINT and ESTV disagree -> test FAILS (never silently passes).
If fixture is empty (0 vectors) -> all tests SKIP with an explanatory
message — the fixture is populated only after Julien runs the manual
Playwright capture utility (CONTEXT 92.5 D-11, 0-trust protocol §9).

Per-vector behaviour:
  * `expected_tax_chf is None` (scaffold-only)  -> SKIP per vector
  * `expected_tax_chf is float`                  -> assert |MINT-ESTV| <= TOL_CHF

NEVER re-implements `_calculate_*()` mirrors of the Dart `financial_core/`
calculators (CLAUDE.md §4 NEVER #3, ADR-20260223). Uses ONLY the existing
helpers in `app/constants/social_insurance.py`.

CONTEXT 92.5 D-13 freshness flag is enforced by `tools/checks/estv_oracle_freshness.py`,
NOT by this pytest module — the test still runs against whatever data is
present (stale or fresh). Staleness is a WARN, not a FAIL.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.constants.social_insurance import (
    married_capital_tax_discount_for,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT,
    calculate_progressive_capital_tax,
)

# Tolerance per CONTEXT 92.5 D-14 (same as differential canton tax tolerance from D-06).
TOL_CHF = 5.0

# parents[0] = tests/, parents[1] = backend/, parents[2] = services/, parents[3] = MINT.nosync/
REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURE_PATH = REPO_ROOT / "services/backend/tests/fixtures/estv_oracle_2025.jsonl"


def _load_vectors() -> list[dict]:
    if not FIXTURE_PATH.exists():
        return []
    text = FIXTURE_PATH.read_text(encoding="utf-8").strip()
    if not text:
        return []
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def _mint_capital_tax_for(vector: dict) -> float:
    """Compute MINT's expected canton capital tax for the vector.

    Uses the existing canonical helper. Combines:
      base_rate := TAUX_IMPOT_RETRAIT_CAPITAL[canton]   (or DEFAULT fallback)
      discount  := married_capital_tax_discount_for(canton)  (only when married,
                   per-canton table — beads -ku6, ex-0.85 scalar)
      tax       := calculate_progressive_capital_tax(amount, base * discount)

    NEVER re-implements brackets here (CLAUDE.md §4 NEVER #3, ADR-20260223).

    NOTE: This compares CAPITAL tax. For income-tax ESTV vectors, the
    matcher will need to compose `cantonal_comparator.py`'s effective
    rates with FEDERAL_BRACKETS — but that wiring is OUT-OF-SCOPE for
    the MVP scaffold (the 50-vector matrix in CONTEXT 92.5 D-12 mixes
    income and capital cases ; the first Julien capture run will reveal
    which matchers we need). For now, vectors with `gross_income_chf` are
    treated as capital-withdrawal stand-ins (income == capital surrogate)
    until the operator refines the schema.
    """
    canton = vector["canton"]
    married = vector["marital_status"] == "married"
    amount = float(vector["gross_income_chf"])  # surrogate ; see docstring
    base = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton, TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT)
    rate = base * (married_capital_tax_discount_for(canton) if married else 1.0)
    return calculate_progressive_capital_tax(amount, rate)


@pytest.fixture(scope="session")
def vectors() -> list[dict]:
    return _load_vectors()


def test_oracle_fixture_present_or_skip(vectors: list[dict]) -> None:
    """Sanity guard: skip the suite cleanly when the fixture is empty.

    Per CONTEXT 92.5 §0-trust : the fixture only contains real data after
    Julien's manual Playwright capture run. CI must not silently green-pass
    when no vectors exist — it skips with an explanatory reason.
    """
    if not vectors:
        pytest.skip(
            "ESTV oracle fixture empty — run "
            "`python3 -m tests.scripts.capture_estv_oracle "
            "--output tests/fixtures/estv_oracle_2025.jsonl` "
            "(from services/backend/) to populate. Manual annual cadence ; "
            "see services/backend/tests/scripts/README.md for details.",
        )
    assert len(vectors) > 0


@pytest.mark.parametrize("idx", range(50))
def test_mint_matches_estv(vectors: list[dict], idx: int) -> None:
    """Per-vector matcher: |MINT - ESTV| <= TOL_CHF (CONTEXT 92.5 D-14)."""
    if not vectors or idx >= len(vectors):
        pytest.skip("vector not present yet (fixture under-populated)")
    v = vectors[idx]
    if v.get("expected_tax_chf") is None:
        pytest.skip(
            f"vector {v['id']} has expected_tax_chf=null (scaffold-only) ; "
            "populate via Playwright capture run.",
        )
    mint = _mint_capital_tax_for(v)
    estv = float(v["expected_tax_chf"])
    diff = abs(mint - estv)
    assert diff <= TOL_CHF, (
        f"ESTV oracle divergence on {v['id']}: "
        f"canton={v['canton']} gross={v['gross_income_chf']} "
        f"MINT={mint:.2f} ESTV={estv:.2f} |MINT-ESTV|={diff:.2f} "
        f"> tolerance ±{TOL_CHF} CHF (CONTEXT 92.5 D-14). "
        f"Likely cause: stale federal/cantonal constant in "
        f"app/constants/social_insurance.py — verify and update."
    )
