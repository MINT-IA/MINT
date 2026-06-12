"""Claim-checker — deterministic definitional-inversion detector (WS-B/E).

Phase: mint-grounded-coach-m1 / Plan 04 (Task 2, TDD).

WHAT THIS GUARDS:
    `check_claims(text)` is the semantic analogue of the numeric hallucination
    detector: a closed-world detector over CONCEPT_REGISTRY that flags a coach
    output asserting an INVERTED definition of a registry concept (« un rachat,
    c'est retirer ton capital »). It is deterministic — substring/pattern only,
    no LLM judge (CLAUDE.md §9: verifying probabilistic output with a
    probabilistic tool is not verification).

    Driven by the same Plan 01 eval fixtures as the inversion RED proof: for each
    fixture, every known inversion MUST be flagged and the canonical definition
    MUST NOT be flagged (no false positive on correct prose).
"""

from __future__ import annotations

import json
import time
from pathlib import Path

import pytest

from app.services.coach.claim_checker import ClaimViolation, check_claims
from app.services.coach.coach_models import ComponentType
from app.services.coach.compliance_guard import ComplianceGuard

FIXTURE_PATH = Path(__file__).parent / "fixtures" / "inversions_eval.jsonl"


def _load_cases() -> list[dict]:
    lines = FIXTURE_PATH.read_text(encoding="utf-8").splitlines()
    return [json.loads(line) for line in lines if line.strip()]


CASES = _load_cases()
CASE_IDS = [c["id"] for c in CASES]


# ── The canonical example from the plan behaviour spec ───────────────────────
def test_rachat_inversion_is_flagged() -> None:
    violations = check_claims(
        "un rachat c'est retirer ton capital du 2e pilier"
    )
    assert violations, "the rachat inversion must be flagged"
    assert any(v.concept_key == "rachat_lpp" for v in violations)
    v = next(v for v in violations if v.concept_key == "rachat_lpp")
    assert isinstance(v, ClaimViolation)
    assert v.matched_inversion, "violation must carry the matched inversion marker"
    assert v.snippet, "violation must carry a snippet"


def test_rachat_canonical_is_not_flagged() -> None:
    violations = check_claims(
        "un rachat c'est verser dans ta caisse de pension"
    )
    assert not violations, (
        f"the canonical rachat definition must NOT be flagged, got {violations}"
    )


# ── Fixture-driven: every inversion flagged, every canonical clean ───────────
@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_every_inversion_is_flagged(case: dict) -> None:
    for inversion in case["known_inversions"]:
        violations = check_claims(inversion)
        assert violations, (
            f"{case['id']}: claim-checker did NOT flag the inversion "
            f"{inversion!r}"
        )
        assert any(v.concept_key == case["concept_key"] for v in violations), (
            f"{case['id']}: flagged but not attributed to {case['concept_key']!r} "
            f"(got {[v.concept_key for v in violations]})"
        )


@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_canonical_definition_is_not_flagged(case: dict) -> None:
    violations = check_claims(case["canonical_relation_fr"])
    assert not violations, (
        f"{case['id']}: FALSE POSITIVE — the canonical definition "
        f"{case['canonical_relation_fr']!r} was flagged: "
        f"{[(v.concept_key, v.matched_inversion) for v in violations]}"
    )


# ── False-positive guard: normal educational prose must pass ─────────────────
NEUTRAL_PROSE = [
    "Tu pourrais envisager un rachat LPP cette année ; l'effet dépend de ta "
    "tranche d'imposition.",
    "Le pilier 3a et le pilier 3b répondent à des besoins différents — on peut "
    "en parler si tu veux.",
    "Une lacune de prévoyance se comble souvent par un rachat, mais ce n'est pas "
    "la seule piste.",
    "Le taux de conversion transforme ton capital LPP en rente ; il a baissé ces "
    "dernières années.",
    "Rien n'est garanti dans une projection de retraite ; ce sont des scénarios.",
    "Bonjour, comment puis-je t'aider aujourd'hui ?",
]


@pytest.mark.parametrize("text", NEUTRAL_PROSE)
def test_neutral_prose_is_not_flagged(text: str) -> None:
    violations = check_claims(text)
    assert not violations, (
        f"FALSE POSITIVE on neutral prose {text!r}: "
        f"{[(v.concept_key, v.matched_inversion) for v in violations]}"
    )


def test_empty_and_none_safe() -> None:
    assert check_claims("") == []
    assert check_claims("   ") == []


# ── Performance: closed-world scan over all fixtures in <2s ──────────────────
def test_runs_over_all_fixtures_under_2s() -> None:
    blob = "\n".join(
        inv for c in CASES for inv in c["known_inversions"]
    )
    start = time.perf_counter()
    for _ in range(50):
        check_claims(blob)
    elapsed = time.perf_counter() - start
    assert elapsed < 2.0, f"claim-checker too slow: {elapsed:.3f}s for 50 passes"


# ── Task 3: ComplianceGuard blocking-layer integration ───────────────────────
# The claim-checker is wired into ComplianceGuard as a blocking layer (after L2):
# a definitional inversion sets use_fallback=True with a 'definition_inversion'
# fallback reason; a canonical definition still passes.
def test_guard_blocks_rachat_inversion() -> None:
    guard = ComplianceGuard()
    result = guard.validate(
        "Un rachat LPP, c'est sortir ton capital du 2e pilier avant l'heure.",
        component_type=ComponentType.general,
    )
    assert result.use_fallback is True, (
        "ComplianceGuard must force fallback on a definitional inversion"
    )
    assert result.is_compliant is False
    # The user-facing violation names the inverted concept + its marker.
    assert any(
        "rachat_lpp" in v and "invers" in v.lower() for v in result.violations
    ), f"expected a rachat_lpp inversion violation, got {result.violations}"
    # On fallback, the inverted text is NOT shipped (sanitized_text empty).
    assert result.sanitized_text == ""


def test_guard_passes_rachat_canonical() -> None:
    guard = ComplianceGuard()
    result = guard.validate(
        "Un rachat LPP, c'est verser de l'argent dans ta caisse de pension, "
        "avec un effet fiscal déductible.",
        component_type=ComponentType.general,
    )
    assert result.use_fallback is False, (
        f"the canonical rachat definition must pass, violations={result.violations}"
    )


@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_guard_blocks_every_fixture_inversion(case: dict) -> None:
    guard = ComplianceGuard()
    for inversion in case["known_inversions"]:
        result = guard.validate(inversion, component_type=ComponentType.general)
        assert result.use_fallback is True, (
            f"{case['id']}: ComplianceGuard did NOT block inversion {inversion!r}"
        )


@pytest.mark.parametrize("case", CASES, ids=CASE_IDS)
def test_guard_passes_every_fixture_canonical(case: dict) -> None:
    """No false positive: the canonical definition of every fixture concept must
    pass the guard (the claim-checker layer must not block correct prose)."""
    guard = ComplianceGuard()
    result = guard.validate(
        case["canonical_relation_fr"], component_type=ComponentType.general
    )
    assert result.use_fallback is False, (
        f"{case['id']}: FALSE POSITIVE — canonical definition blocked, "
        f"violations={result.violations}"
    )
