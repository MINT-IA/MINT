"""Wave 1b Plan 02 — registry entries.

8 stub tests, each marked skip with reason. Plan 02 unskips + implements.

Test count expansion (Plan 01 revision iter-1, ISSUE-07): +4 stubs vs
original Plan 01 (test_resolve_returns_iso_computed_at,
test_source_ref_unique_per_tool,
test_subset_invariant_excludes_tool_call_id_when_subset_empty,
test_description_fr_passes_accent_lint).
"""
import pytest

from app.services.coach.citation_registry import CITATION_REGISTRY, resolve

WAVE_1B_TOOL_KEYS = [
    "tool_budget_snapshot",
    "tool_retirement_projection",
    "tool_cross_pillar_analysis",
    "tool_couple_optimization",
    "tool_cap_status",
    "tool_retrieve_memories",
]


@pytest.mark.skip(reason="Wave 1b — entries land in Plan 02")
def test_six_entries_present():
    for key in WAVE_1B_TOOL_KEYS:
        assert key in CITATION_REGISTRY, f"missing tool_call_id key {key}"


@pytest.mark.skip(reason="Wave 1b — entries land in Plan 02")
def test_source_kind_invariant():
    for key in WAVE_1B_TOOL_KEYS:
        assert CITATION_REGISTRY[key].source_kind == "tool_call_id"


@pytest.mark.skip(reason="Wave 1b — entries land in Plan 02")
def test_resolve_returns_description():
    for key in WAVE_1B_TOOL_KEYS:
        description = resolve(key, ctx=None)
        assert description is not None
        assert len(description) > 10
        assert "{{cite:" not in description  # non-recursion invariant


@pytest.mark.skip(reason="Wave 1b — entries land in Plan 02")
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


@pytest.mark.skip(
    reason="Wave 1b — every tool_* key has a dispatcher branch (subset invariant complement)"
)
def test_every_tool_key_has_dispatcher_branch():
    # Per RESEARCH §9.7: complementary invariant for the subset exemption.
    from app.api.v1.endpoints.coach_chat import _compute_budget_status  # noqa: F401

    # Plan 02 expands this to grep coach_chat.py for _compute_<name> per tool key.
    assert True


@pytest.mark.skip(reason="Wave 1b — source_ref naming pattern (tool:<name>)")
def test_source_ref_pattern():
    for key in WAVE_1B_TOOL_KEYS:
        ref = CITATION_REGISTRY[key].source_ref
        assert ref.startswith("tool:"), f"key={key} source_ref={ref}"


# ----- ISSUE-07 expansion stubs (Plan 01 revision iter-1) -----


@pytest.mark.skip(
    reason=(
        "Wave 1b — Plan 04 surfaces computed_at via the response payload; "
        "this asserts the FORMAT (ISO 8601 string) at the registry helper "
        "level for the 4 tools that have it natively + the 2 synthetic-hash "
        "tools post-Q9 resolution"
    )
)
def test_resolve_returns_iso_computed_at():
    # Plan 04 audit pins where computed_at travels (route a or b).
    # Plan 02 + Plan 04 collectively make this pass.
    # For Plan 01, this is a stub asserting the registry doesn't
    # accidentally inline a computed_at field (it travels via the
    # response payload, not the registry entry).
    for key in WAVE_1B_TOOL_KEYS:
        entry = CITATION_REGISTRY[key]
        # source_ref MUST NOT contain a timestamp — that's runtime data
        # not a registry-level concern.
        assert "T" not in entry.source_ref or "tool:" in entry.source_ref


@pytest.mark.skip(reason="Wave 1b — source_ref uniqueness invariant")
def test_source_ref_unique_per_tool():
    # Each of the 6 tool_call_id entries must have a unique source_ref
    # ('tool:<name>' shape) — no two tools share the same source_ref.
    refs = [CITATION_REGISTRY[k].source_ref for k in WAVE_1B_TOOL_KEYS]
    assert len(set(refs)) == len(refs), f"duplicate source_ref: {refs}"


@pytest.mark.skip(reason="Wave 1b — subset invariant exemption complement")
def test_subset_invariant_excludes_tool_call_id_when_subset_empty():
    # Plan 02 exempts source_kind=='tool_call_id' from the bundle-allowlist
    # subset test (because tool_call_id activates per tool call, not per
    # intent). This asserts the exemption is *complete* — no tool_call_id
    # entry leaks into a bundle allowlist by accident, which would defeat
    # the exemption's purpose.
    # Concrete shape: every CITATION_REGISTRY entry with
    # source_kind=='tool_call_id' is NOT in any bundle.citation_allowlist.
    # Plan 02 implements + unskips after wiring the bundles helper.
    assert True  # stub — implement in Plan 02


@pytest.mark.skip(reason="Wave 1b — FR description accent lint at unit-test level")
def test_description_fr_passes_accent_lint():
    # Per CLAUDE.md TOP rule #2: every description_fr string must use
    # proper FR accents (no 'calcule' where 'calculé' is required).
    # G5 lint catches this at the file level via accent_lint_fr.py;
    # this assertion catches it at the unit-test level so Plan 02's
    # registry expansion fails closed at pytest time if a contributor
    # introduces ASCII-accent regression.
    for key in WAVE_1B_TOOL_KEYS:
        desc = CITATION_REGISTRY[key].description_fr
        # The string must contain at least one non-ASCII char
        # (registries with no accented FR word are likely missing
        # accents). Empirical guard against silent ASCII drift.
        has_accented = any(ord(c) > 127 for c in desc)
        assert has_accented, (
            f"key={key} description_fr has no FR accent — likely accent-strip regression"
        )
