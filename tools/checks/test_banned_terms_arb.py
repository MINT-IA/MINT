"""Self-tests for tools/checks/banned_terms_arb.py.

Runs in pure-Python (no Flutter / no pytest dep). Invoked from CI as
`python3 tools/checks/test_banned_terms_arb.py` and prints PASS/FAIL.
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import importlib.util

THIS = Path(__file__).resolve()
LINT_PATH = THIS.parent / "banned_terms_arb.py"

spec = importlib.util.spec_from_file_location("banned_terms_arb", LINT_PATH)
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


def _expect(name, cond, detail=""):
    if cond:
        print(f"  PASS — {name}")
        return True
    print(f"  FAIL — {name}{(' :: ' + detail) if detail else ''}")
    return False


def main():
    n_pass = 0
    n_total = 0

    # ── FR ──
    n_total += 1
    n_pass += _expect(
        "FR positive « garantit » → flagged",
        len(_scan("fr", {"k": "L'AVS garantit un revenu de base à la retraite."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "FR negation « pas de taux garanti » → allowed",
        len(_scan("fr", {"k": "Pas de taux de conversion garanti — projection en capital."})) == 0,
    )

    n_total += 1
    n_pass += _expect(
        "FR « ne sont pas garantis » two-clause negation → allowed",
        len(_scan("fr", {"k": "Les rendements ne sont pas garantis. Hypothèses pédagogiques."})) == 0,
    )

    n_total += 1
    n_pass += _expect(
        "FR @meta block ignored",
        len(_scan("fr", {"@k": {"description": "garantit"}})) == 0,
    )

    # ── EN ──
    n_total += 1
    n_pass += _expect(
        "EN positive « guarantees » → flagged",
        len(_scan("en", {"k": "AVS guarantees a basic retirement income."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "EN « not guaranteed » → allowed",
        len(_scan("en", {"k": "Educational projection — results not guaranteed."})) == 0,
    )

    # ── DE ──
    n_total += 1
    n_pass += _expect(
        "DE positive « garantiert » → flagged",
        len(_scan("de", {"k": "Die AHV garantiert ein Grundeinkommen im Ruhestand."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "DE « nicht garantiert » → allowed",
        len(_scan("de", {"k": "Bildungsprojektion. Ergebnisse nicht garantiert."})) == 0,
    )

    n_total += 1
    n_pass += _expect(
        "DE « kein garantierter » → allowed",
        len(_scan("de", {"k": "1e-Plan erkannt. Kein garantierter Umwandlungssatz."})) == 0,
    )

    # ── ES ──
    n_total += 1
    n_pass += _expect(
        "ES positive « garantiza » → flagged",
        len(_scan("es", {"k": "El AVS garantiza un ingreso básico en la jubilación."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "ES « sin tasa garantizada » → allowed",
        len(_scan("es", {"k": "Sin tasa de conversión garantizada — proyección solo en capital."})) == 0,
    )

    # ── IT ──
    n_total += 1
    n_pass += _expect(
        "IT positive « garantisce » → flagged",
        len(_scan("it", {"k": "L'AVS garantisce un reddito di base in pensione."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "IT « nessun ... garantito » → allowed",
        len(_scan("it", {"k": "Nessun tasso di conversione garantito — proiezione solo in capitale."})) == 0,
    )

    # ── PT ──
    n_total += 1
    n_pass += _expect(
        "PT positive « garante » → flagged",
        len(_scan("pt", {"k": "O AVS garante um rendimento básico na reforma."})) == 1,
    )

    n_total += 1
    n_pass += _expect(
        "PT « não garante » → allowed",
        len(_scan("pt", {"k": "O desempenho passado não garante resultados futuros."})) == 0,
    )

    print(f"\n{n_pass}/{n_total} tests passed")
    return 0 if n_pass == n_total else 1


if __name__ == "__main__":
    sys.exit(main())
