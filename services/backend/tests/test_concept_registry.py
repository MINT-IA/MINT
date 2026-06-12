"""Concept registry — closed-world Swiss definition pages (WS-B, audit 04 §3.a).

Phase: mint-grounded-coach-m1 / Plan 04 (Task 1, TDD).

WHAT THIS GUARDS:
    The concept registry is the SINGLE source of canonical Swiss financial
    definitions for the coach — a curated wiki (per project decision
    project_user_profile_wiki), NOT vector-soup. It mirrors the frozen-Mapping
    pattern of citation_registry.py (MappingProxyType + dataclass + resolve()).

    Closed-world invariant: every concept_key the Plan 01 inversion fixtures
    reference MUST resolve to a page, so the claim-checker (Task 2) can map each
    fixture to its canonical definition + known inversions.

    Doctrine: every FR string carries correct accents (accent_lint_fr) and no
    banned LSFin term (CLAUDE.md TOP rule 1) — the registry is the source of
    truth a user reads.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.concept_registry import (
    CONCEPT_REGISTRY,
    ConceptPage,
    resolve,
)

FIXTURE_PATH = (
    Path(__file__).parent / "fixtures" / "inversions_eval.jsonl"
)


def _fixture_concept_keys() -> set[str]:
    lines = FIXTURE_PATH.read_text(encoding="utf-8").splitlines()
    return {json.loads(line)["concept_key"] for line in lines if line.strip()}


# ── Size / shape ─────────────────────────────────────────────────────────────
def test_registry_has_at_least_15_pages() -> None:
    assert len(CONCEPT_REGISTRY) >= 15, (
        f"need >=15 P0 concept pages, got {len(CONCEPT_REGISTRY)}"
    )


def test_every_page_is_a_concept_page() -> None:
    for key, page in CONCEPT_REGISTRY.items():
        assert isinstance(page, ConceptPage), f"{key}: not a ConceptPage"
        assert page.concept_key == key, (
            f"{key}: page.concept_key={page.concept_key!r} mismatches map key"
        )


def test_every_page_is_fully_populated() -> None:
    for key, page in CONCEPT_REGISTRY.items():
        assert page.canonical_fr.strip(), f"{key}: empty canonical_fr"
        assert page.source_title.strip(), f"{key}: empty source_title"
        assert page.known_inversions, f"{key}: empty known_inversions"
        assert page.not_this_fr, f"{key}: empty not_this_fr"


# ── rachat_lpp — the device-proven Exhibit A concept ─────────────────────────
def test_rachat_lpp_page_present_and_correct() -> None:
    page = CONCEPT_REGISTRY.get("rachat_lpp")
    assert page is not None, "rachat_lpp MUST be in the registry (Exhibit A)"
    # Canonical = paying IN, déductible LPP art. 79b.
    low = page.canonical_fr.lower()
    assert "verser" in low or "versement" in low, (
        "rachat_lpp canonical must describe paying INTO the caisse"
    )
    assert "79b" in page.source_title or "79b" in page.source_url, (
        "rachat_lpp source must cite LPP art. 79b"
    )
    # Known inversions cover the device-proven 'retirer / retrait / sortir'.
    inv_blob = " ".join(page.known_inversions + page.not_this_fr).lower()
    assert "retirer" in inv_blob, "rachat_lpp must list 'retirer' as an inversion"
    assert "retrait" in inv_blob, "rachat_lpp must list 'retrait' as an inversion"
    assert "sortir" in inv_blob, "rachat_lpp must list 'sortir' as an inversion"


# ── Closed-world: every fixture concept_key resolves ─────────────────────────
def test_registry_is_superset_of_fixture_keys() -> None:
    fixture_keys = _fixture_concept_keys()
    registry_keys = set(CONCEPT_REGISTRY)
    missing = fixture_keys - registry_keys
    assert not missing, (
        f"registry is not a superset of the Plan 01 fixtures — "
        f"unmapped concept_keys: {sorted(missing)}"
    )


@pytest.mark.parametrize("key", sorted(_fixture_concept_keys()))
def test_each_fixture_key_resolves(key: str) -> None:
    page = resolve(key)
    assert page is not None, f"fixture concept_key {key!r} does not resolve"
    assert isinstance(page, ConceptPage)


def test_resolve_unknown_key_returns_none() -> None:
    assert resolve("not_a_real_concept_xyz") is None


# ── Frozen: runtime mutation raises (MappingProxyType) ───────────────────────
def test_registry_is_frozen() -> None:
    with pytest.raises(TypeError):
        CONCEPT_REGISTRY["new_key"] = None  # type: ignore[index]


def test_concept_page_is_frozen() -> None:
    page = CONCEPT_REGISTRY["rachat_lpp"]
    with pytest.raises(Exception):
        page.canonical_fr = "mutated"  # type: ignore[misc]


# ── Doctrine: no banned LSFin term in any FR string ──────────────────────────
def _all_fr_strings(page: ConceptPage) -> list[str]:
    return (
        [page.canonical_fr, page.source_title]
        + list(page.not_this_fr)
        + list(page.known_inversions)
    )


@pytest.mark.parametrize("key", sorted(CONCEPT_REGISTRY))
def test_no_banned_term_in_canonical_or_source(key: str) -> None:
    """The canonical definition + source + 'not_this' prose a user reads must
    not contain a banned LSFin term. known_inversions are deliberately wrong
    educational counter-examples, so they are scanned for banned terms too —
    they must stay descriptive, not prescriptive/promising."""
    guard = ComplianceGuard()
    page = CONCEPT_REGISTRY[key]
    for s in _all_fr_strings(page):
        banned = guard._check_banned_terms(s)
        assert not banned, f"{key}: banned term {banned} in registry string: {s!r}"
