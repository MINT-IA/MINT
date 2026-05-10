"""ESTV oracle Playwright headless capture — CALC-03 (CONTEXT 92.5 D-11/D-12).

Captures 50 (input_profile, expected_tax) vectors from
`swisstaxcalculator.estv.admin.ch` per CONTEXT D-12:
  5 cantons (ZH, VD, GE, BE, BS) x 5 marital/income combos x 2 ages = 50.

Manual run by Julien at each ESTV publication cycle (Nov-Dec).
Produces / updates `services/backend/tests/fixtures/estv_oracle_2025.jsonl`.

Why manual: the ESTV calculator is a JS-rendered SPA with anti-bot
heuristics ; running this in CI would (a) require a Playwright runtime
in CI (heavy), (b) hit ESTV from a headless GitHub IP repeatedly (likely
to be rate-limited or blocked), (c) drift if ESTV updates the page
structure (silent test failure). Annual manual cadence solves all three.

Usage:
  pip install ".[oracle]" && playwright install chromium
  python3 -m tests.scripts.capture_estv_oracle --output \\
    tests/fixtures/estv_oracle_2025.jsonl

Or scaffold-only (no Playwright runtime, emits 50 skeleton vectors with
expected_tax_chf=null) — useful for first commit / smoke tests:
  python3 -m tests.scripts.capture_estv_oracle --scaffold-only --output /tmp/foo.jsonl

The script is idempotent: re-running overwrites the JSONL with fresh
vectors. After capture, commit the file with prefix `fix(estv-oracle):`
per CONTEXT D-10 lifecycle rule.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# CANTONS, MARITAL_INCOME_COMBOS, AGES are the locked CONTEXT D-12 matrix.
CANTONS: list[str] = ["ZH", "VD", "GE", "BE", "BS"]
MARITAL_INCOME_COMBOS: list[dict[str, Any]] = [
    {"marital_status": "single", "gross_income": 60_000, "label": "single_60k"},
    {"marital_status": "single", "gross_income": 100_000, "label": "single_100k"},
    {"marital_status": "married", "gross_income": 100_000, "label": "married_100k"},
    {"marital_status": "married", "gross_income": 150_000, "label": "married_150k"},
    {"marital_status": "married", "gross_income": 200_000, "label": "married_200k"},
]
AGES: list[int] = [40, 60]

ESTV_URL = "https://swisstaxcalculator.estv.admin.ch/#/calculator/income-wealth-tax"


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _vector_id(canton: str, combo: dict[str, Any], age: int) -> str:
    return f"{canton}__{combo['label']}__age{age}"


def _placeholder_vector(canton: str, combo: dict[str, Any], age: int) -> dict[str, Any]:
    """Return a vector skeleton with expected_tax_chf=None for executor.

    The actual capture step (Playwright navigate + form fill + read result)
    must be filled in by the operator on first run. This is intentionally
    a SCAFFOLD — automated form filling on the ESTV SPA is brittle and
    must be hand-tuned by Julien against the live site.
    """
    return {
        "id": _vector_id(canton, combo, age),
        "canton": canton,
        "marital_status": combo["marital_status"],
        "gross_income_chf": combo["gross_income"],
        "age": age,
        "expected_tax_chf": None,            # populated by Playwright capture
        "expected_capture_date": _now_iso(),  # ISO YYYY-MM-DD ; freshness lint reads this
        "source_url": ESTV_URL,
        "source_label": combo["label"],
    }


def _build_matrix() -> list[dict[str, Any]]:
    vectors: list[dict[str, Any]] = []
    for canton in CANTONS:
        for combo in MARITAL_INCOME_COMBOS:
            for age in AGES:
                vectors.append(_placeholder_vector(canton, combo, age))
    assert len(vectors) == 50, f"matrix should yield 50 vectors, got {len(vectors)}"
    return vectors


def _write_jsonl(path: Path, vectors: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(v) + "\n" for v in vectors),
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="ESTV oracle Playwright capture (manual).")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("services/backend/tests/fixtures/estv_oracle_2025.jsonl"),
        help="Output JSONL path.",
    )
    parser.add_argument(
        "--scaffold-only",
        action="store_true",
        help=(
            "Skip Playwright. Emit 50 vector skeletons with expected_tax_chf=None. "
            "Use this on first CI run to seed the file with the locked matrix shape."
        ),
    )
    args = parser.parse_args()

    vectors = _build_matrix()

    if args.scaffold_only:
        _write_jsonl(args.output, vectors)
        print(
            f"[scaffold] wrote {len(vectors)} skeleton vectors to {args.output}",
            file=sys.stderr,
        )
        return 0

    # Real Playwright path — requires `pip install ".[oracle]"` + `playwright install chromium`.
    try:
        from playwright.sync_api import sync_playwright  # type: ignore[import-not-found]
    except ImportError:
        print(
            "[error] playwright not installed. Run: "
            "pip install '.[oracle]' && playwright install chromium",
            file=sys.stderr,
        )
        return 2

    captured: list[dict[str, Any]] = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 MINT-OracleCapture/1.0 (julien.battaglia@gmail.com)",
            locale="fr-CH",
        )
        page = context.new_page()
        for v in vectors:
            # NOTE: form-filling logic is BRITTLE and depends on ESTV SPA.
            # On first run, Julien must inspect ESTV DOM via:
            #   page.goto(ESTV_URL); page.pause()  # opens Playwright Inspector
            # and replace the placeholder selector strings below with the
            # actual canton-dropdown / income-input / age-input / marital-radio
            # selectors observed live. This is by design — annual manual
            # capture is the trade-off chosen in CONTEXT D-11.
            page.goto(ESTV_URL, wait_until="networkidle")
            # TODO(operator): fill canton, income, marital, age via real selectors.
            # TODO(operator): click compute button, wait for result panel.
            # TODO(operator): parse result CHF text -> v["expected_tax_chf"] = float(...)
            captured.append(v)
        browser.close()

    _write_jsonl(args.output, captured)
    print(f"[capture] wrote {len(captured)} vectors to {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
