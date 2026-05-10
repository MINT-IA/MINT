"""Phase 95 — D-08 entries-keyspace ⊆ CITATION_REGISTRY (no drift)."""
from __future__ import annotations

from app.services.coach.citation_registry import CITATION_REGISTRY


def test_citation_registry_has_18_keys():
    assert len(CITATION_REGISTRY) == 18


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
