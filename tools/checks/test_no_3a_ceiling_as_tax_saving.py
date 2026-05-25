"""Self-tests for tools/checks/no_3a_ceiling_as_tax_saving.py."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

THIS = Path(__file__).resolve()
LINT_PATH = THIS.parent / "no_3a_ceiling_as_tax_saving.py"

spec = importlib.util.spec_from_file_location("no_3a_ceiling_as_tax_saving", LINT_PATH)
assert spec and spec.loader
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


def _arb(content: dict) -> Path:
    f = tempfile.NamedTemporaryFile(
        mode="w", suffix=".arb", delete=False, encoding="utf-8"
    )
    json.dump(content, f, ensure_ascii=False)
    f.flush()
    return Path(f.name)


def _scan(locale: str, content: dict):
    return lint.scan_locale(_arb(content), locale)


def _expect(name: str, cond: bool) -> int:
    if cond:
        print(f"  PASS - {name}")
        return 1
    print(f"  FAIL - {name}")
    return 0


def main() -> int:
    n_pass = 0
    cases = {
        "FR ceiling labelled as tax saving is flagged": (
            "fr",
            {"k": "Ton 3a : CHF 0 cette annee. 7258 CHF d'économie d'impôt en jeu."},
            1,
        ),
        "FR spaced ceiling labelled as tax saving is flagged": (
            "fr",
            {"k": "Jusqu'a 7'258 CHF/an d'économies d'impôts - des maintenant."},
            1,
        ),
        "FR deductible wording is allowed": (
            "fr",
            {"k": "Jusqu'a 7'258 CHF/an deductibles - des ton premier emploi."},
            0,
        ),
        "FR separate estimated tax saving is allowed": (
            "fr",
            {"k": "Jusqu'a 7'258 CHF deductibles. Économie fiscale estimee : CHF 1'800."},
            0,
        ),
        "EN ceiling labelled as tax saving is flagged": (
            "en",
            {"k": "7,258 CHF/year in tax savings from your first job."},
            1,
        ),
        "Independent ceiling labelled as tax saving is flagged": (
            "en",
            {"k": "36'288 CHF in tax savings may be available."},
            1,
        ),
        "ARB metadata is ignored": (
            "fr",
            {"@k": {"description": "7258 CHF d'economie d'impot"}},
            0,
        ),
    }
    for name, (locale, content, expected) in cases.items():
        n_pass += _expect(name, len(_scan(locale, content)) == expected)

    n_total = len(cases)
    print(f"\n{n_pass}/{n_total} tests passed")
    return 0 if n_pass == n_total else 1


if __name__ == "__main__":
    sys.exit(main())
