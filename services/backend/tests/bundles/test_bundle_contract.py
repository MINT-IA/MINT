"""Bundle contract invariants — Phase 93.5 Wave 0 (Plan 93.5-01 Task 2).

Mirror of `tests/test_extractor_schema.py` (Phase 91 frozen+forbid+invariant
precedent). All 10 tests below MUST stay green for the bundle layer to be
considered contract-stable. The xfail on `_subset_of_grounding_pack` lifts
once Phase 95 populates `GROUNDING_PACK_KEYS_REGISTRY`.

Threats covered :
- T-93.5-01 : Pydantic config tampering (`test_all_bundles_are_frozen`,
              `test_all_bundles_forbid_extra`,
              `test_bundle_instances_are_immutable_via_attribute`).
- T-93.5-03 : Import-time DoS (`test_all_bundles_importable` —
              instantiation under pytest discovery).
- T-93.5-04 : Undeclared 8th slot (`test_bundle_no_undeclared_slots`).
- D-20 lock : tool registry drift (`test_bundle_allowed_tools_subset_of_narrator_registry`).
"""
from __future__ import annotations

import re

import pytest
from pydantic import ValidationError

from app.services.coach.bundles import (
    ALL_BUNDLE_CLASSES,
    BundleBase,
    ComplianceNarratorBundle,
)
from app.services.coach.coach_tools import get_narrator_llm_tools
from app.services.coach.grounding_pack import GROUNDING_PACK_KEYS_REGISTRY


# Canonical 7-slot set declared by `_build_prompt`
# (claude_coach_service.py:789-797). Bundle prompt fragments may reference
# only these 7 names ; an 8th `{slot}` would raise KeyError at format time.
_LEGACY_DECLARED_SLOTS = frozenset(
    {
        "banned_terms",
        "regional_identity",
        "lifecycle_awareness",
        "plan_awareness",
        "check_in_protocol",
        "safe_mode_protocol",
        "routing_rules",
    }
)

# Single-brace `{slot}`. Negative-lookbehind/lookahead ignores `{{cite:<key>}}`
# (Phase 94 placeholder, double-brace) which the citation-gate substitutes
# AFTER `_build_prompt` runs.
_SLOT_RE = re.compile(r"(?<!\{)\{(\w+)\}(?!\})")

# Banned-LSFin keywords expected verbatim in compliance-narrator's fragment.
# The narrator LLM must SEE them to refuse them (CONTEXT D-09 + Pitfall 4).
_BANNED_KEYWORDS = ["garanti", "optimal", "meilleur", "certain", "assure", "sans risque", "parfait"]


# ---------------------------------------------------------------------------
# Importability + Pydantic config invariants
# ---------------------------------------------------------------------------

def test_all_bundles_importable():
    """Each bundle module imports + instantiates without raising (T-93.5-03)."""
    assert len(ALL_BUNDLE_CLASSES) == 6
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        assert isinstance(instance, BundleBase)


def test_all_bundles_are_frozen():
    """`model_config["frozen"] is True` on every subclass (T-93.5-01)."""
    for cls in ALL_BUNDLE_CLASSES:
        assert cls.model_config.get("frozen") is True, cls.__name__


def test_all_bundles_forbid_extra():
    """`model_config["extra"] == "forbid"` rejects unknown fields (T-93.5-01)."""
    for cls in ALL_BUNDLE_CLASSES:
        assert cls.model_config.get("extra") == "forbid", cls.__name__
        with pytest.raises(ValidationError):
            cls.model_validate({**cls().model_dump(), "extra_field": "boom"})


def test_bundle_instances_are_immutable_via_attribute():
    """Direct attribute assignment is rejected by frozen=True (T-93.5-01)."""
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        with pytest.raises(ValidationError):
            instance.allowed_tools = ["evil"]  # type: ignore[misc]


# ---------------------------------------------------------------------------
# Tool registry + citation registry invariants
# ---------------------------------------------------------------------------

def test_bundle_allowed_tools_subset_of_narrator_registry():
    """Every `allowed_tools` ⊆ get_narrator_llm_tools() (D-20)."""
    registry_names = {tool["name"] for tool in get_narrator_llm_tools()}
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        invented = set(instance.allowed_tools) - registry_names
        assert not invented, f"{cls.__name__} invented tool names: {invented}"


def test_bundle_citation_allowlist_subset_of_grounding_pack():
    """`citation_allowlist` ⊆ GROUNDING_PACK_KEYS_REGISTRY.

    Wave 0 contract : registry is intentionally empty (Phase 95 populates).
    This xfails until then ; do NOT mark `strict=True`.
    """
    if not GROUNDING_PACK_KEYS_REGISTRY:
        pytest.xfail("GroundingPack registry not populated until Phase 95")
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        invented = set(instance.citation_allowlist) - GROUNDING_PACK_KEYS_REGISTRY
        assert not invented, f"{cls.__name__} invented citation keys: {invented}"


# ---------------------------------------------------------------------------
# Naming + slot-fidelity invariants
# ---------------------------------------------------------------------------

def test_bundle_names_match_kebab_convention():
    """Each `name` matches `^[a-z][a-z0-9-]+$` ; all 6 names are unique."""
    name_re = re.compile(r"^[a-z][a-z0-9-]+$")
    seen: set[str] = set()
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        assert name_re.match(instance.name), f"{cls.__name__}: bad name {instance.name!r}"
        assert instance.name not in seen, f"duplicate name {instance.name!r}"
        seen.add(instance.name)


def test_bundle_no_undeclared_slots():
    """Every single-brace `{slot}` ⊆ _LEGACY_DECLARED_SLOTS (T-93.5-04).

    The compiler in Plan 93.5-02 will enforce this at compile time too
    (defense-in-depth), but the unit test gives faster feedback.
    """
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        slots_used = set(_SLOT_RE.findall(instance.prompt_fragment))
        undeclared = slots_used - _LEGACY_DECLARED_SLOTS
        assert not undeclared, f"{cls.__name__} uses undeclared slot(s): {undeclared}"


# ---------------------------------------------------------------------------
# Compliance bundle banned-term presence + size sanity
# ---------------------------------------------------------------------------

def test_compliance_bundle_contains_banned_terms_keywords():
    """compliance-narrator must LIST ≥3 banned LSFin terms verbatim.

    The narrator LLM must read them in its system prompt to refuse them
    (CONTEXT D-09). Without this listing the bundle would lose its
    primary doctrine purpose.
    """
    fragment = ComplianceNarratorBundle().prompt_fragment.lower()
    hits = [kw for kw in _BANNED_KEYWORDS if kw in fragment]
    assert len(hits) >= 3, f"compliance-narrator only mentions {hits} (need ≥3)"


def test_bundle_prompt_fragment_minimum_size():
    """No bundle ships an empty stub — every fragment ≥100 chars."""
    for cls in ALL_BUNDLE_CLASSES:
        instance = cls()
        assert len(instance.prompt_fragment) >= 100, (
            f"{cls.__name__} fragment too small: {len(instance.prompt_fragment)} chars"
        )
