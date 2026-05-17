"""Phase 97 W7 cycle #9 — B018 REPRO + LOCK.

Asserts `GROUNDING_PACK_KEYS_REGISTRY` is the full set of `CITATION_REGISTRY.keys()`
(not the empty `frozenset()` stub left in Phase 95 W2). When this test fires RED,
the Phase 95 bundle-contract test « all bundle citation keys must exist in the
registry » silently xfails because every key lookup against an empty frozenset
returns False — hiding any future key drift.

Permanent regression guard : if a future PR ever resets
GROUNDING_PACK_KEYS_REGISTRY to the empty frozenset (e.g. during a cleanup or
refactor), this test fails and the PR is blocked.
"""

from __future__ import annotations

from app.services.coach.citation_registry import CITATION_REGISTRY
from app.services.coach.grounding_pack import GROUNDING_PACK_KEYS_REGISTRY


def test_grounding_pack_keys_registry_is_full_citation_registry_keys() -> None:
    """B018 RED → GREEN gate.

    Pre-fix : `GROUNDING_PACK_KEYS_REGISTRY = frozenset()` → this test FAILS
    with `set() != frozenset({'max_3a_2026', 'lpp_coordination_amount', ...})`.

    Post-fix : `GROUNDING_PACK_KEYS_REGISTRY = frozenset(CITATION_REGISTRY.keys())`
    → this test PASSES.
    """
    expected: frozenset[str] = frozenset(CITATION_REGISTRY.keys())
    assert GROUNDING_PACK_KEYS_REGISTRY == expected, (
        "B018 regression : GROUNDING_PACK_KEYS_REGISTRY is not the full "
        f"CITATION_REGISTRY.keys() set ({len(expected)} keys expected, "
        f"got {len(GROUNDING_PACK_KEYS_REGISTRY)} keys)"
    )


def test_grounding_pack_keys_registry_is_a_frozenset() -> None:
    """Type guard : the immutable frozenset contract is preserved post-fix."""
    assert isinstance(GROUNDING_PACK_KEYS_REGISTRY, frozenset)


def test_grounding_pack_keys_registry_non_empty() -> None:
    """Sanity guard : the registry must have at least 1 key (Phase 94 baseline
    is 18 keys ; if this hits 0, something has regressed catastrophically)."""
    assert len(GROUNDING_PACK_KEYS_REGISTRY) > 0, (
        "B018 regression : GROUNDING_PACK_KEYS_REGISTRY is empty — Phase 94 "
        "citation_registry should expose 18 keys minimum"
    )


def test_grounding_pack_keys_registry_intersects_citation_registry() -> None:
    """Cross-reference : every key in GROUNDING_PACK_KEYS_REGISTRY must be
    resolvable via CITATION_REGISTRY (no orphan keys)."""
    for key in GROUNDING_PACK_KEYS_REGISTRY:
        assert key in CITATION_REGISTRY, (
            f"B018 regression : orphan key '{key}' in "
            "GROUNDING_PACK_KEYS_REGISTRY not present in CITATION_REGISTRY"
        )
