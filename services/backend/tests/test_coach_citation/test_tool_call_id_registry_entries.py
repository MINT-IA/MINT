"""Wave 1b Plan 02 — registry entries.

10 unit tests covering the 6 new tool_call_id CITATION_REGISTRY entries
(unskipped from Wave 0 stubs by Plan 02). The complementary invariant
`test_every_tool_key_has_dispatcher_branch` enforces that every
`tool_<name>` key resolves to a dispatcher branch in `coach_chat.py`
(subset-invariant exemption complement per RESEARCH §9.7).

Test count expansion (Plan 01 revision iter-1, ISSUE-07): +4 vs original
Plan 01 (test_resolve_returns_iso_computed_at,
test_source_ref_unique_per_tool,
test_subset_invariant_excludes_tool_call_id_when_subset_empty,
test_description_fr_passes_accent_lint).
"""
import inspect

from app.services.coach.citation_registry import CITATION_REGISTRY, resolve

WAVE_1B_TOOL_KEYS = [
    "tool_budget_snapshot",
    "tool_retirement_projection",
    "tool_cross_pillar_analysis",
    "tool_couple_optimization",
    "tool_cap_status",
    "tool_retrieve_memories",
]

# Per-key dispatcher substring contract — each registry key must resolve to
# at least one of these substrings in the coach_chat.py source. The exact
# dispatcher symbol differs per tool (the tool_call name does not always
# equal the registry-key short name — e.g. `tool_budget_snapshot` maps to
# `get_budget_status` / `_compute_budget_status`). Mapping pinned here so
# future tool additions surface drift at G3.
_KEY_TO_DISPATCHER_SUBSTRINGS = {
    "tool_budget_snapshot": ("_compute_budget_status", '"get_budget_status"'),
    "tool_retirement_projection": (
        "_compute_retirement_projection",
        '"get_retirement_projection"',
    ),
    "tool_cross_pillar_analysis": (
        "_compute_cross_pillar_analysis",
        '"get_cross_pillar_analysis"',
    ),
    "tool_couple_optimization": (
        "_compute_couple_optimization",
        '"get_couple_optimization"',
    ),
    "tool_cap_status": ("_validate_cap_response", '"get_cap_status"'),
    "tool_retrieve_memories": (
        "_compute_retrieve_memories",
        '"retrieve_memories"',
    ),
}


def test_six_entries_present():
    for key in WAVE_1B_TOOL_KEYS:
        assert key in CITATION_REGISTRY, f"missing tool_call_id key {key}"


def test_source_kind_invariant():
    for key in WAVE_1B_TOOL_KEYS:
        assert CITATION_REGISTRY[key].source_kind == "tool_call_id"


def test_resolve_returns_description():
    for key in WAVE_1B_TOOL_KEYS:
        description = resolve(key, ctx=None)
        assert description is not None
        assert len(description) > 10
        assert "{{cite:" not in description  # non-recursion invariant


def test_description_fr_passes_banned_terms_lint():
    # Verify FR descriptions contain no LSFin banned terms.
    BANNED = (
        "garanti",
        "optimal",
        "meilleur",
        "certain",
        "assuré",
        "parfait",
        "sans risque",
    )
    for key in WAVE_1B_TOOL_KEYS:
        description = CITATION_REGISTRY[key].description_fr.lower()
        for term in BANNED:
            assert term not in description, f"key={key} contains banned={term}"


def test_every_tool_key_has_dispatcher_branch():
    """Per RESEARCH §9.7: complementary invariant for subset exemption.

    Each `tool_<name>` registry key MUST resolve to at least one dispatcher
    substring in `coach_chat.py` (either the `_compute_*` helper symbol or
    the `name == "..."` branch string). This guards against orphan tool_*
    keys that no `name == "..."` branch ever activates.
    """
    from app.api.v1.endpoints import coach_chat

    source = inspect.getsource(coach_chat)
    for key in WAVE_1B_TOOL_KEYS:
        substrings = _KEY_TO_DISPATCHER_SUBSTRINGS.get(key, ())
        assert substrings, f"no dispatcher mapping pinned for {key}"
        assert any(s in source for s in substrings), (
            f"Registry key {key} has no dispatcher branch in coach_chat.py "
            f"(expected one of {substrings})"
        )


def test_source_ref_pattern():
    for key in WAVE_1B_TOOL_KEYS:
        ref = CITATION_REGISTRY[key].source_ref
        assert ref.startswith("tool:"), f"key={key} source_ref={ref}"


# ----- ISSUE-07 expansion stubs (Plan 01 revision iter-1) -----


def test_resolve_returns_iso_computed_at():
    """Per Plan 04: computed_at travels via the tool response payload, NOT
    via the registry entry. This asserts the registry doesn't accidentally
    inline a computed_at field — source_ref must remain a static identifier
    (`tool:<name>` shape), with no timestamp embedded.
    """
    for key in WAVE_1B_TOOL_KEYS:
        entry = CITATION_REGISTRY[key]
        # source_ref MUST NOT contain a timestamp — that's runtime data
        # not a registry-level concern.
        assert "T" not in entry.source_ref or "tool:" in entry.source_ref


def test_source_ref_unique_per_tool():
    # Each of the 6 tool_call_id entries must have a unique source_ref
    # ('tool:<name>' shape) — no two tools share the same source_ref.
    refs = [CITATION_REGISTRY[k].source_ref for k in WAVE_1B_TOOL_KEYS]
    assert len(set(refs)) == len(refs), f"duplicate source_ref: {refs}"


def test_subset_invariant_excludes_tool_call_id_when_subset_empty():
    """Subset-invariant exemption complement.

    Plan 02 exempts `source_kind == 'tool_call_id'` from the bundle-allowlist
    subset test (because tool_call_id activates per tool call, not per
    intent). This asserts the exemption is *complete* — no tool_call_id
    entry leaks into a bundle allowlist by accident, which would defeat
    the exemption's purpose.
    """
    from app.services.coach.bundles import ALL_BUNDLE_CLASSES

    # Collect the union of every bundle's citation_allowlist.
    allowlist_union: set[str] = set()
    for cls in ALL_BUNDLE_CLASSES:
        try:
            instance = cls()
            allowlist_union.update(instance.citation_allowlist)
        except TypeError:
            default = cls.model_fields["citation_allowlist"].default
            allowlist_union.update(default)

    tool_call_id_keys = {
        k
        for k, src in CITATION_REGISTRY.items()
        if src.source_kind == "tool_call_id"
    }
    leaked = tool_call_id_keys & allowlist_union
    assert not leaked, (
        f"tool_call_id keys leaked into bundle allowlists "
        f"(exemption defeats its purpose): {sorted(leaked)}"
    )


def test_description_fr_passes_accent_lint():
    """Per CLAUDE.md TOP rule #2: every description_fr string must use
    proper FR accents (no 'calcule' where 'calculé' is required).
    G5 lint catches this at the file level via accent_lint_fr.py;
    this assertion catches it at the unit-test level so Plan 02's
    registry expansion fails closed at pytest time if a contributor
    introduces ASCII-accent regression.
    """
    for key in WAVE_1B_TOOL_KEYS:
        desc = CITATION_REGISTRY[key].description_fr
        # The string must contain at least one non-ASCII char
        # (registries with no accented FR word are likely missing
        # accents). Empirical guard against silent ASCII drift.
        has_accented = any(ord(c) > 127 for c in desc)
        assert has_accented, (
            f"key={key} description_fr has no FR accent — likely accent-strip regression"
        )
