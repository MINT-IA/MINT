"""Phase 95 — D-08 entries-keyspace ⊆ CITATION_REGISTRY (no drift).

Wave 1b Plan 02 — bumped the count expectation from 18 to 24 to track
the 6 new `tool_call_id` entries (one per Wave 1a server-side tool).
The non-tool baseline remains 18 keys (Phase 94 Wave 0 baseline).
"""
from __future__ import annotations

from app.services.coach.citation_registry import CITATION_REGISTRY


def test_citation_registry_has_18_keys():
    # Phase 94 Wave 0 baseline = 18 keys (union of pillar3a + lpp + tax +
    # mortgage bundle allowlists). Wave 1b Plan 02 adds 6 `tool_call_id`
    # entries (one per Wave 1a server-side tool) for a total of 24.
    assert len(CITATION_REGISTRY) == 24
    # Pin the Wave 0 non-tool sub-baseline so a drift in the
    # spec/reasoning-kind subset surfaces here regardless of Wave 1b's
    # tool_call_id growth.
    non_tool = [
        k
        for k, src in CITATION_REGISTRY.items()
        if src.source_kind != "tool_call_id"
    ]
    assert len(non_tool) == 18


def test_pack_keys_must_be_subset_of_registry():
    # Drift detector : if Wave 2 emitter introduces a pack key not in
    # the registry, the double-lookup silently falls back to None and
    # narrator quality degrades unnoticed (R3 from RESEARCH §Pitfalls).
    # This test runs against a synthetic emitted-key list so the
    # invariant is codified before the emitter ships.
    registry_keys = set(CITATION_REGISTRY.keys())
    sample_emitted_keys = {
        "r3a_plafond_salarie_2026",
        "lpp_taux_conv_obligatoire_2026",
        "lifd_art_38_taux_reduit",
    }
    drift = sample_emitted_keys - registry_keys
    assert not drift, f"Pack-only keys (no registry fallback): {drift}"
