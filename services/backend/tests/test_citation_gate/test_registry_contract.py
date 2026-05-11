"""Phase 94 Wave 0 — citation_registry contract tests (GATE-02).

Pins :
- CITATION_REGISTRY is a frozen Mapping (rejects mutation).
- CitationSource enforces Literal source_kind + extra=forbid (Pydantic v2).
- No recursive citation keys (registry value MUST NOT contain `{{cite:` substring).
- Subset invariant — every CITATION_REGISTRY key is also in at least one
  bundle's `citation_allowlist` (no orphan registry entries).
- Skeleton imports succeed (parser + registry public API).

Plan-checker iter 1 M1 fix : the bundles package exports
`ALL_BUNDLE_CLASSES: list[type[BundleBase]]`, NOT a dict named
`BUNDLE_REGISTRY`. The subset test instantiates each class (or falls back
to `model_fields["citation_allowlist"].default`) to read the allowlist.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.services.coach.bundles import ALL_BUNDLE_CLASSES
from app.services.coach.citation_parser import (
    GateVerdict,
    GatedResponse,
    gate,
    is_meta_negation,
    is_meta_quoted,
)
from app.services.coach.citation_registry import (
    CITATION_REGISTRY,
    CitationSource,
    resolve,
)


# ---------------------------------------------------------------------------
# Parser skeleton importability — pinned per Plan task 1 done criteria
# ---------------------------------------------------------------------------


def test_parser_public_api_importable():
    """Skeleton importables : gate, GatedResponse, GateVerdict + meta helpers."""
    assert callable(gate)
    assert GatedResponse is not None
    assert GateVerdict.PASS == "pass"
    assert GateVerdict.REJECTED_UNCITED == "rejected_uncited"
    assert GateVerdict.REJECTED_BANNED_CLAIM == "rejected_banned_claim"
    assert GateVerdict.FALLBACK == "fallback"
    assert callable(is_meta_quoted)
    assert callable(is_meta_negation)


def test_gate_skeleton_returns_pass_on_plain_text():
    """Wave 0 skeleton — empty body returns PASS verdict for non-empty inputs."""
    out = gate(response_text="hello", ctx=None, citation_allowlist=None, is_retry=False)
    assert isinstance(out, GatedResponse)
    assert out.verdict == GateVerdict.PASS
    assert out.gated_text == "hello"
    assert out.retry_needed is False
    assert out.reprompt_addendum is None
    assert out.uncited_numbers_count == 0
    assert out.banned_claims_found == ()
    assert out.inputs_hash is None  # Phase 95 stub field


def test_gate_skeleton_empty_input_returns_fallback():
    """Empty / whitespace-only input → FALLBACK verdict."""
    out = gate(response_text="", ctx=None, citation_allowlist=None, is_retry=False)
    assert out.verdict == GateVerdict.FALLBACK
    out2 = gate(response_text="   \n  ", ctx=None, citation_allowlist=None, is_retry=False)
    assert out2.verdict == GateVerdict.FALLBACK


# ---------------------------------------------------------------------------
# Registry contract — Pydantic v2 frozen + extra=forbid
# ---------------------------------------------------------------------------


def test_registry_nonempty_and_seeded():
    """Wave 0 seed ≥ 18 keys (union of bundle citation_allowlists)."""
    assert isinstance(CITATION_REGISTRY, dict) or hasattr(CITATION_REGISTRY, "__getitem__")
    assert len(CITATION_REGISTRY) >= 18, (
        f"Wave 0 seed too small : got {len(CITATION_REGISTRY)} keys, expected ≥18 "
        f"(union of pillar3a + lpp + tax + mortgage bundle allowlists)"
    )


def test_citation_source_literal_source_kind():
    """`source_kind` is Literal-validated — `invalid` raises ValidationError."""
    with pytest.raises(ValidationError):
        CitationSource(
            key="x",
            source_kind="invalid",  # type: ignore[arg-type]
            source_ref="y",
            description_fr="z",
        )


def test_citation_source_extra_forbid():
    """Extra fields raise ValidationError (frozen+extra=forbid)."""
    with pytest.raises(ValidationError):
        CitationSource(
            key="x",
            source_kind="spec",
            source_ref="y",
            description_fr="z",
            extra_field="bad",  # type: ignore[call-arg]
        )


def test_citation_source_frozen():
    """Frozen — assignment after construction raises ValidationError."""
    src = CitationSource(
        key="x",
        source_kind="spec",
        source_ref="y",
        description_fr="z",
    )
    with pytest.raises(ValidationError):
        src.key = "mutated"  # type: ignore[misc]


def test_citation_source_accepts_all_5_source_kinds():
    """All 5 D-05 source kinds accepted : profile, reasoning, tool_call_id, adr, spec."""
    for kind in ("profile", "reasoning", "tool_call_id", "adr", "spec"):
        src = CitationSource(
            key=f"k_{kind}",
            source_kind=kind,  # type: ignore[arg-type]
            source_ref="ref",
            description_fr="desc",
        )
        assert src.source_kind == kind


# ---------------------------------------------------------------------------
# No recursive keys — registry value MUST NOT contain `{{cite:` substring
# ---------------------------------------------------------------------------


def test_no_recursive_keys():
    """Defensive : `description_fr` and `source_ref` MUST NOT contain `{{cite:`.

    Threat T-94-02 mitigation — frozen registry + future entries cannot
    accidentally introduce recursive citation references that would loop
    through `resolve()` indefinitely.
    """
    for key, src in CITATION_REGISTRY.items():
        assert "{{cite:" not in src.description_fr, (
            f"Registry key {key!r} has recursive `{{cite:}}` in description_fr"
        )
        assert "{{cite:" not in src.source_ref, (
            f"Registry key {key!r} has recursive `{{cite:}}` in source_ref"
        )


# ---------------------------------------------------------------------------
# Subset invariant — every registry key is in at least one bundle's allowlist
# ---------------------------------------------------------------------------


def _bundle_allowlist_union() -> set[str]:
    """Compute union of `citation_allowlist` across ALL_BUNDLE_CLASSES.

    Bundle classes have `citation_allowlist` as a Pydantic field default.
    Try zero-arg instantiation first ; fall back to `model_fields[...].default`.
    """
    union: set[str] = set()
    for cls in ALL_BUNDLE_CLASSES:
        try:
            instance = cls()
            union.update(instance.citation_allowlist)
        except TypeError:
            default = cls.model_fields["citation_allowlist"].default
            union.update(default)
    return union


def test_registry_subset_of_bundle_allowlists():
    """Every CITATION_REGISTRY key MUST be in at least one bundle's allowlist.

    Threat T-94-04 mitigation — orphan registry entries (keys not referenced
    by any bundle) cannot be emitted by the narrator and therefore never
    resolved at runtime ; they are dead code that masks the closed-world
    contract.
    """
    allowlist_union = _bundle_allowlist_union()
    orphans = set(CITATION_REGISTRY.keys()) - allowlist_union
    assert not orphans, (
        f"CITATION_REGISTRY has {len(orphans)} orphan keys not in any bundle "
        f"citation_allowlist : {sorted(orphans)[:5]}..."
    )


# ---------------------------------------------------------------------------
# resolve() Wave 0 stub behavior
# ---------------------------------------------------------------------------


def test_resolve_unknown_key_returns_none():
    """Unknown keys → None (caller decides how to handle)."""
    assert resolve("definitely_not_a_real_key_12345", ctx=None) is None


def test_resolve_known_key_returns_description():
    """Known key → description_fr (Wave 0 placeholder ; Phase 95 dispatches)."""
    sample_key = next(iter(CITATION_REGISTRY.keys()))
    out = resolve(sample_key, ctx=None)
    assert out == CITATION_REGISTRY[sample_key].description_fr
    assert isinstance(out, str)
    assert len(out) > 0
