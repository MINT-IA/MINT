"""GroundingPack registry stub — Phase 93.5 placeholder for Phase 95.

Phase 95 DAG-INVALIDATION will populate `GROUNDING_PACK_KEYS_REGISTRY`
with the canonical Swiss-financial citation keys consumed by Phase 94's
citation-gate via the `{{cite:<key>}}` placeholder contract.

Source : `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` N1.

Until Phase 95 lands, the registry is intentionally empty :
- Bundles' `citation_allowlist` entries carry inline
  `# TODO Phase 95 — pending GroundingPack registry` comments.
- `tests/bundles/test_bundle_contract.py::test_bundle_citation_allowlist_subset_of_grounding_pack`
  is xfail until the registry is non-empty.

The contract for Phase 95 :
- Each entry is a stable, kebab- or snake-case key (e.g. `r3a_ceiling_2026`).
- Keys map to a deterministic `GroundingPackEntry` (value, source, asof,
  source_url) that the citation-gate substitutes at runtime.
- Entry removal is a breaking change ; entries are deprecated, not deleted.
"""
from __future__ import annotations


GROUNDING_PACK_KEYS_REGISTRY: frozenset[str] = frozenset()


__all__ = ["GROUNDING_PACK_KEYS_REGISTRY"]
