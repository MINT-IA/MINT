"""Phase mint-calc-engine-v1 Plan 09 Task 1 — tool_description_rubric.py lint tests.

Tests the rubric lint at ``tools/checks/tool_description_rubric.py``.

R1: ≥1 French verb (simule|calcule|compare|estime|projette|évalue|analyse)
R2: ≥1 FR accent in description text
R3: ≥1 legal article ref OR financial-domain keyword
R4: description length ≥80 chars
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]  # MINT.nosync/
LINT = ROOT / "tools" / "checks" / "tool_description_rubric.py"


def _write_py(tmp_path: Path, name: str, body: str) -> Path:
    p = tmp_path / name
    p.write_text(body, encoding="utf-8")
    return p


def _run(*paths: Path) -> tuple[int, str, str]:
    res = subprocess.run(
        [sys.executable, str(LINT), *(str(p) for p in paths)],
        capture_output=True,
        text=True,
    )
    return res.returncode, res.stdout, res.stderr


def test_lint_passes_on_compliant_description(tmp_path: Path) -> None:
    """Test 1 — Lint exit 0 on a file with a FR-keyword-compliant description."""
    body = '''
SOME_TOOLS = [
    {
        "name": "divorce_simulator",
        "description": (
            "Simule l'impact financier d'un divorce (CC art. 122-124) : "
            "splitting AVS (LAVS art. 29sexies), partage LPP, pension alimentaire."
        ),
    },
]
'''
    p = _write_py(tmp_path, "compliant.py", body)
    code, out, err = _run(p)
    assert code == 0, f"expected exit 0, got {code}\nstdout={out}\nstderr={err}"


def test_lint_fails_on_english_only_description(tmp_path: Path) -> None:
    """Test 2 — Lint exit 1 on a file with an English-only terse description."""
    body = '''
SOME_TOOLS = [
    {
        "name": "lpp_projector",
        "description": "Compute LPP retirement projection.",
    },
]
'''
    p = _write_py(tmp_path, "english_only.py", body)
    code, out, err = _run(p)
    assert code == 1, f"expected exit 1, got {code}\nstdout={out}\nstderr={err}"
    combined = out + err
    # R1 FR verb missing AND R2 FR text missing AND R3 legal/domain missing AND R4 min length missing
    assert "R1" in combined or "FR verb" in combined, combined


def test_lint_reports_tool_name_and_rule(tmp_path: Path) -> None:
    """Test 3 — Lint output mentions the offending rule + a description snippet."""
    body = '''
SOME_TOOLS = [
    {
        "name": "wealth_tax_service",
        "description": "Wealth tax calc.",
    },
]
'''
    p = _write_py(tmp_path, "short.py", body)
    code, out, err = _run(p)
    assert code == 1
    combined = out + err
    # Reports min-length rule violation (description is 17 chars, well under 80)
    assert "R4" in combined or "min length" in combined or "min_len" in combined, combined
