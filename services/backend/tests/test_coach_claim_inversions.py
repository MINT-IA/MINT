"""Inversion eval — deterministic RED proof of the coach's definitional blind spot.

Phase: mint-grounded-coach-m1 / Plan 01 (fixture-first gate, CONTEXT décision 3).

WHAT THIS PROVES (deterministically, no live LLM — CLAUDE.md §9):
    The live coach guard is `ComplianceGuard.validate()` (compliance_guard.py:355).
    It inspects banned terms (L1), prescriptive patterns (L2), and numeric
    hallucinations (L3). NONE inspect the MEANING of a definitional sentence.
    A sentence with no number and no banned/prescriptive token passes every layer.
    The "rachat = sortir ton capital" inversion (it is the OPPOSITE — a rachat is
    paying IN, LPP art. 79b) is exactly this class. Audit refs:
      - .planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md §HOLE-1
      - .planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md §P0
      - W1-cadre-50 WTF-W1-01 (device-proven rachat inversion)

WHY THE SUITE IS GREEN TODAY:
    `test_inversions_are_blocked` is xfail(strict=True): the guard does NOT block
    inversions today, so the test fails its "should-be-blocked" assertion and is
    recorded as XFAIL (expected failure = green CI). When Plan 04 wires the
    deterministic claim-checker into ComplianceGuard, the assertion will start
    passing and strict-xfail will flip it to XPASS-as-failure — forcing us to
    delete the xfail marker. That flip IS the regression anchor.

    `test_guard_passes_inversion_today` documents the hole as a *passing* test:
    it asserts the guard's TODAY behaviour (is_compliant=True, use_fallback=False
    on an inverted definition). It will start FAILING the day the hole is closed —
    a second, redundant tripwire (delete it together with the xfail marker in 04).

    The HYGIENE self-test guarantees every fixture string trips neither L1 nor L2,
    so Plan 02's L1/L2 hardening cannot flip the xfail cases to XPASS for the WRONG
    reason. The RED proof must isolate the DEFINITIONAL hole only.

Capture the `pytest -rx` line for `test_inversions_are_blocked` (rachat case) as the
deterministic RED citation in the SUMMARY.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.coach.coach_models import ComponentType
from app.services.coach.compliance_guard import ComplianceGuard

FIXTURE_PATH = Path(__file__).parent / "fixtures" / "inversions_eval.jsonl"


# ── Fixture loader ──────────────────────────────────────────────────────────
def _load_cases() -> list[dict]:
    lines = FIXTURE_PATH.read_text(encoding="utf-8").splitlines()
    return [json.loads(line) for line in lines if line.strip()]


CASES = _load_cases()
CASE_IDS = [c["id"] for c in CASES]


# ── Deterministic inversion scorer (substring-based, NO LLM judge) ───────────
def output_contains_inversion(output: str, forbidden_substrings: list[str]) -> bool:
    """True iff the coach output contains a known-inversion fragment.

    Pure substring containment — deterministic and reproducible (CLAUDE.md §9).
    This is the semantic analogue of `hallucination_detector` for numbers:
    it operates on the closed-world set of known inversion strings, not on a
    probabilistic judge.
    """
    low = output.lower()
    return any(sub.lower() in low for sub in forbidden_substrings)


def guard_flags(text: str) -> bool:
    """True iff ComplianceGuard.validate() would withhold/flag this text.

    A flagged output is one the live path would NOT ship as-is: either it is
    non-compliant (violations recorded) or it forces the templated fallback.
    """
    guard = ComplianceGuard()
    result = guard.validate(text, component_type=ComponentType.general)
    return (not result.is_compliant) or result.use_fallback


def case_inversions(case: dict) -> list[str]:
    """Inversion sentences that, fed as coach output, SHOULD be flagged."""
    return list(case["known_inversions"])


# ── Coverage / integrity guards (cheap fixture tripwires) ───────────────────
def test_fixture_has_enough_cases() -> None:
    assert len(CASES) >= 15, f"need >=15 inversion cases, got {len(CASES)}"


def test_fixture_includes_rachat_lpp() -> None:
    keys = {c["concept_key"] for c in CASES}
    assert "rachat_lpp" in keys, (
        "the device-proven rachat-inversion (Exhibit A) MUST be in the fixture"
    )


def test_fixture_schema_complete() -> None:
    required = {
        "id",
        "concept_key",
        "question_fr",
        "canonical_relation_fr",
        "known_inversions",
        "forbidden_substrings",
    }
    for c in CASES:
        assert required <= set(c), f"{c.get('id')}: missing keys {required - set(c)}"
        assert c["known_inversions"], f"{c['id']}: empty known_inversions"
        assert c["forbidden_substrings"], f"{c['id']}: empty forbidden_substrings"


@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_scorer_hooks_match_known_inversions(case: dict) -> None:
    """Each forbidden_substring must appear in at least one known_inversion —
    otherwise the deterministic scorer hook is dead and can never fire."""
    blob = " ".join(case["known_inversions"]).lower()
    for sub in case["forbidden_substrings"]:
        assert sub.lower() in blob, (
            f"{case['id']}: forbidden_substring {sub!r} not present in any "
            f"known_inversion — dead scorer hook"
        )


# ── HYGIENE self-test ───────────────────────────────────────────────────────
# Every fixture string must trip NEITHER L1 (banned terms) NOR L2 (prescriptive
# patterns). This guarantees the RED proof isolates the DEFINITIONAL hole and
# that Plan 02's L1/L2 hardening cannot flip the xfail-strict cases to XPASS for
# the wrong reason.
def _all_strings(case: dict) -> list[str]:
    return (
        [case["question_fr"], case["canonical_relation_fr"]]
        + list(case["known_inversions"])
        + list(case["forbidden_substrings"])
    )


@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_fixture_strings_are_guard_neutral(case: dict) -> None:
    """No fixture string may trip L1 banned-terms or L2 prescriptive patterns."""
    guard = ComplianceGuard()
    for s in _all_strings(case):
        banned = guard._check_banned_terms(s)
        prescriptive = guard._check_prescriptive(s)
        assert not banned, (
            f"{case['id']}: fixture string trips L1 banned terms {banned}: {s!r} — "
            f"rewrite to guard-neutral French (Plan 02 would block it for the "
            f"WRONG reason and flip the xfail case to XPASS)"
        )
        assert not prescriptive, (
            f"{case['id']}: fixture string trips L2 prescriptive {prescriptive}: {s!r} — "
            f"rewrite to a descriptive (non-imperative) form"
        )


# ── RED reality: the guard PASSES inversions today (documents the hole) ─────
@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_guard_passes_inversion_today(case: dict) -> None:
    """TODAY (RED reality): for every known-inversion fed as coach output, the
    live guard reports is_compliant=True and use_fallback=False — i.e. it does
    NOT catch the inverted definition. This is the deterministic proof of the
    definitional blind spot (audit 01 §HOLE-1 / audit 04 §P0).

    RED→GREEN flip note: when Plan 04 wires the claim-checker into
    ComplianceGuard, the guard will start flagging these inversions and THIS
    test will begin to FAIL. Delete it together with the xfail marker on
    test_inversions_are_blocked when the claim-checker lands.
    """
    guard = ComplianceGuard()
    for inversion in case_inversions(case):
        # Sanity: the inversion text actually carries its forbidden substring,
        # so the deterministic scorer would fire on it.
        assert output_contains_inversion(inversion, case["forbidden_substrings"]), (
            f"{case['id']}: inversion {inversion!r} lacks any forbidden_substring"
        )
        result = guard.validate(inversion, component_type=ComponentType.general)
        assert result.is_compliant is True, (
            f"{case['id']}: guard already flags {inversion!r} "
            f"(violations={result.violations}). The hole may be closed — if so, "
            f"remove this RED-reality test and the xfail marker below."
        )
        assert result.use_fallback is False, (
            f"{case['id']}: guard already forces fallback on {inversion!r}. "
            f"The hole may be closed — update this test and remove the xfail."
        )


# ── RED proof (strict xfail): the guard SHOULD block inversions ─────────────
@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
@pytest.mark.xfail(
    strict=True,
    reason="RED proof — claim-checker not yet wired; Plan 04 flips this to PASS",
)
def test_inversions_are_blocked(case: dict) -> None:
    """The CONTRACT: a coach output asserting an inverted Swiss definition MUST
    be flagged by the live guard (the way an uncited number is). Today no
    claim-checker exists, so the guard ships the inversion unflagged and this
    assertion FAILS — recorded as XFAIL (green CI). Plan 04 wires the
    deterministic claim-checker into ComplianceGuard; this test then PASSES and
    strict-xfail forces removal of the marker. That flip is the regression
    anchor that would have caught WTF-W1-01 ("rachat = retirer ton capital").
    """
    for inversion in case_inversions(case):
        assert guard_flags(inversion), (
            f"{case['id']}: the guard did NOT flag the inverted definition "
            f"{inversion!r} — definitional blind spot (audit 01 §HOLE-1)"
        )
