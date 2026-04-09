"""
Adversarial N4/N5 ComplianceGuard regression suite (Phase 11 — VOICE-08).

Loads `tools/compliance/adversarial_n4_n5.json` and asserts that ComplianceGuard
delivers the expected verdict (pass/block) for each of the 50 phrases.

Failure modes tested (per plan 11-04 D-08):
    - imperative_no_hedge        (e.g. "Tu dois racheter ton 2e pilier maintenant.")
    - banned_term_high_register  (e.g. "optimal", "parfait", "meilleur")
    - prescription_drift         (e.g. named products, ISINs, "achète X")
    - shame_vector               (e.g. social comparison, age shaming)
    - absolute_claim             (e.g. "garanti", "certain", "sans risque")

Any mismatch between `expected_verdict` and the guard's actual decision = test
failure = red build. This protects against silent regression of the high-register
voice gates added in plan 11-04.

The fixture is test-only and never reachable from runtime code (T-11-06 mitigation).
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

import pytest

from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.coach_models import ComponentType


# ── Fixture path ────────────────────────────────────────────────────────────
# Repo layout: services/backend/tests/compliance/test_adversarial_n4_n5.py
#              ^^^^ this file
#              tools/compliance/adversarial_n4_n5.json  (4 levels up from here)
_REPO_ROOT = Path(__file__).resolve().parents[4]
_FIXTURE_PATH = _REPO_ROOT / "tools" / "compliance" / "adversarial_n4_n5.json"


def _load_phrases() -> list[dict]:
    assert _FIXTURE_PATH.exists(), f"Adversarial fixture missing at {_FIXTURE_PATH}"
    with _FIXTURE_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)
    phrases = data.get("phrases", [])
    assert isinstance(phrases, list), "phrases must be a list"
    return phrases


_PHRASES = _load_phrases()


# ── Structural sanity ──────────────────────────────────────────────────────
def test_fixture_has_exactly_50_phrases():
    assert len(_PHRASES) == 50, f"expected 50 phrases, got {len(_PHRASES)}"


def test_fixture_split_25_n4_25_n5():
    n4 = sum(1 for p in _PHRASES if p["level"] == "N4")
    n5 = sum(1 for p in _PHRASES if p["level"] == "N5")
    assert n4 == 25, f"expected 25 N4 phrases, got {n4}"
    assert n5 == 25, f"expected 25 N5 phrases, got {n5}"


def test_fixture_has_pass_and_block_per_level():
    """Both N4 and N5 must contain both pass and block entries (precision + recall)."""
    by_level = defaultdict(lambda: defaultdict(int))
    for p in _PHRASES:
        by_level[p["level"]][p["expected_verdict"]] += 1
    for level in ("N4", "N5"):
        assert by_level[level]["pass"] >= 5, (
            f"{level} needs ≥5 pass entries (got {by_level[level]['pass']})"
        )
        assert by_level[level]["block"] >= 5, (
            f"{level} needs ≥5 block entries (got {by_level[level]['block']})"
        )


def test_fixture_categories_covered():
    """All 5 failure categories must appear (D-08)."""
    required = {
        "imperative_no_hedge",
        "banned_term_high_register",
        "prescription_drift",
        "shame_vector",
        "absolute_claim",
    }
    seen = {p["failure_category"] for p in _PHRASES if p["failure_category"] != "none"}
    missing = required - seen
    assert not missing, f"missing failure categories: {missing}"


# ── The actual adversarial gate ─────────────────────────────────────────────
def _verdict_for(guard: ComplianceGuard, phrase: dict) -> str:
    """Run the guard against an adversarial phrase at its target level.

    Returns "block" if the guard would discard the LLM output (use_fallback=True
    or non-compliant), else "pass".
    """
    result = guard.validate(
        llm_output=phrase["text_fr"],
        context=None,
        component_type=ComponentType.general,
        user_id="adversarial-suite",
        cursor_level=phrase["level"],
    )
    if result.use_fallback or not result.is_compliant:
        return "block"
    return "pass"


@pytest.mark.parametrize("phrase", _PHRASES, ids=lambda p: p["id"])
def test_adversarial_phrase_verdict(phrase: dict):
    guard = ComplianceGuard()
    actual = _verdict_for(guard, phrase)
    expected = phrase["expected_verdict"]
    assert actual == expected, (
        f"{phrase['id']} ({phrase['level']}, {phrase['failure_category']}): "
        f"expected {expected}, got {actual}. Text: {phrase['text_fr']!r}"
    )


def test_per_category_pass_rate_report(capsys):
    """Print per-category pass rate (informational, always passes if individual tests pass).

    This produces a per-category summary the executor surfaces in the SUMMARY.md.
    """
    guard = ComplianceGuard()
    by_cat: dict[str, dict[str, int]] = defaultdict(
        lambda: {"correct": 0, "total": 0}
    )
    for phrase in _PHRASES:
        cat = phrase["failure_category"] or "none"
        by_cat[cat]["total"] += 1
        actual = _verdict_for(guard, phrase)
        if actual == phrase["expected_verdict"]:
            by_cat[cat]["correct"] += 1

    lines = ["", "ComplianceGuard adversarial pass rate by category:"]
    for cat in sorted(by_cat.keys()):
        c = by_cat[cat]
        pct = 100.0 * c["correct"] / c["total"] if c["total"] else 0.0
        lines.append(f"  {cat:30s} {c['correct']:2d}/{c['total']:2d}  ({pct:5.1f}%)")
    print("\n".join(lines))

    # All-or-nothing: every category must be 100% (otherwise the parametrized
    # tests above would already have failed).
    for cat, c in by_cat.items():
        assert c["correct"] == c["total"], (
            f"category {cat}: {c['correct']}/{c['total']} — regression"
        )
