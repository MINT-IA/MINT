"""Unit tests for tools/voice_corpus/krippendorff_runner.py (Phase 11 Plan 11-05).

Loads the synthetic high-agreement fixture (5 testers × 50 phrases, ~8% noise)
and asserts:
  * overall α is high (≥ 0.80) and within bootstrap CI
  * all four ship gates pass
  * the runner exits 0 in --no-write mode
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from tools.voice_corpus.krippendorff_runner import (  # noqa: E402
    bootstrap_alpha,
    evaluate_gates,
    load_frozen_phrases,
    load_tester_output,
)

FIXTURE = REPO_ROOT / "tools/voice_corpus/sample_tester_output.json"
FROZEN = REPO_ROOT / "tools/voice_corpus/frozen_phrases_v1.json"


@pytest.fixture(scope="module")
def ratings():
    return load_tester_output(FIXTURE)


@pytest.fixture(scope="module")
def phrases():
    return load_frozen_phrases(FROZEN)


def test_fixture_shape(ratings):
    assert len(ratings) == 5
    for tid, items in ratings.items():
        assert tid.startswith("tester_")
        assert len(items) == 50
        assert all(v in {"N1", "N2", "N3", "N4", "N5"} for v in items.values())


def test_bootstrap_alpha_high_agreement(ratings):
    point, lo, hi = bootstrap_alpha(ratings, n=200, seed=42)
    assert point >= 0.80, f"expected α ≥ 0.80 on synthetic fixture, got {point:.4f}"
    assert lo <= point <= hi


def test_all_gates_pass(ratings, phrases):
    result = evaluate_gates(ratings, phrases)
    assert result["gate_overall"], result
    assert result["gate_n4"], result
    assert result["gate_n5"], result
    assert result["all_pass"]
    assert result["alpha_n4"] >= 0.67
    assert result["alpha_n5"] >= 0.67


def test_runner_cli_exits_zero(tmp_path):
    out_md = tmp_path / "VOICE_CURSOR_TEST.md"
    proc = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "tools/voice_corpus/krippendorff_runner.py"),
            str(FIXTURE),
            "--output-md",
            str(out_md),
        ],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    assert out_md.exists()
    body = out_md.read_text(encoding="utf-8")
    assert "Ship-gate verdict: **PASS**" in body
    assert "α overall" in body


def test_load_tester_output_wrapped_form(tmp_path):
    p = tmp_path / "wrapped.json"
    p.write_text(
        json.dumps(
            {
                "levels": ["N1", "N2", "N3", "N4", "N5"],
                "ratings": {"a": {"x": "N3"}, "b": {"x": "N3"}},
            }
        )
    )
    r = load_tester_output(p)
    assert r == {"a": {"x": "N3"}, "b": {"x": "N3"}}
