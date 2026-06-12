"""Phase 93.5 Plan 02 Task 1 — bundle_compiler unit tests.

Covers :
- D-02 intent → bundle mapping
- D-09 always-on (compliance-narrator + life-event-router)
- D-11 fragment composition (always-on first + separator)
- D-12 dedup (tools, citations, bundles)
- D-13 drop priority (right-to-left, never always-on)
- D-14 empty-intent path (only always-on)
- H4 undeclared-slot guard (post-assembly regex scan → ValueError)
- T-93.5-06 invariant : `_DROP_PRIORITY ∩ _ALWAYS_ON == set()`
"""
from __future__ import annotations

import pytest

from app.services.coach.bundle_compiler import (
    CompiledBundle,
    _ALLOWED_INTENTS,
    _ALWAYS_ON,
    _DECLARED_SLOTS,
    _DROP_PRIORITY,
    _FRAGMENT_SEPARATOR,
    _SINGLE_BRACE_SLOT,
    _TOKEN_BUDGET,
    compile_bundles,
)
from app.services.coach.bundles import (
    ComplianceNarratorBundle,
    IndependentTaxBundle,
    LifeEventRouterBundle,
    Pillar3aOptimizerBundle,
    SuccessionDivorceBundle,
)


@pytest.fixture(autouse=True)
def _citation_gate_off(monkeypatch):
    """These tests pin the BASE bundle-composition algorithm (drop priority,
    budget, dedup, always-on ordering) independent of the citation grammar.

    mint-grounded-coach-m1 Plan 07 ACTIVATED the citation gate by default, so
    `compile_bundles` now appends the always-on `citation-grammar` bundle when
    `COACH_CITATION_GATE_ENABLED` is True (bundle_compiler.py). To keep these
    composition assertions stable against the base set, the gate is forced OFF
    here. The gate-ON citation-grammar addition is covered by
    tests/test_citation_gate/ (intent-scoped grammar + narrator fragment).
    """
    from app.core.config import settings

    monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", False)


# ---------------------------------------------------------------------------
# Module-level invariants (T-93.5-06)
# ---------------------------------------------------------------------------


def test_drop_priority_never_includes_always_on():
    """T-93.5-06 — defensive invariant : the drop list MUST be disjoint from
    the always-on list, otherwise an overflow could silently dethrone
    `compliance-narrator` (LSFin doctrine) or `life-event-router` (keyboard
    map). Enforced at module-import time via `assert` ; this test pins it."""
    assert set(_DROP_PRIORITY).isdisjoint(set(_ALWAYS_ON))


def test_declared_slots_match_legacy_seven():
    """H4 — bundle compiler's _DECLARED_SLOTS must mirror the canonical
    7-slot set provided by `_build_prompt` at claude_coach_service.py:789."""
    assert _DECLARED_SLOTS == frozenset({
        "banned_terms",
        "regional_identity",
        "lifecycle_awareness",
        "plan_awareness",
        "check_in_protocol",
        "safe_mode_protocol",
        "routing_rules",
    })


def test_token_budget_constant():
    """D-13 — hard cap is 8'000 tokens."""
    assert _TOKEN_BUDGET == 8_000


def test_allowed_intents_match_six_enum():
    """D-01 — heuristic intent value space is the same 6-enum as
    ExtractorOutput.intents."""
    assert _ALLOWED_INTENTS == frozenset(
        {"retirement", "taxes", "housing", "debt", "family", "career"}
    )


# ---------------------------------------------------------------------------
# Type / shape contract
# ---------------------------------------------------------------------------


def test_compile_bundles_returns_compiled_bundle():
    """Type-check the return value."""
    out = compile_bundles(intents=set())
    assert isinstance(out, CompiledBundle)
    assert isinstance(out.prompt, str)
    assert isinstance(out.allowed_tools, list)
    assert isinstance(out.citation_allowlist, list)
    assert isinstance(out.activated_bundles, list)
    assert isinstance(out.estimated_tokens, int)
    assert isinstance(out.dropped_bundles, list)


def test_compile_bundles_is_frozen_dataclass():
    """`CompiledBundle` is a frozen dataclass — mutation must raise."""
    out = compile_bundles(intents=set())
    with pytest.raises((AttributeError, Exception)):
        out.prompt = "tampered"  # type: ignore[misc]


# ---------------------------------------------------------------------------
# D-09 + D-14 always-on
# ---------------------------------------------------------------------------


def test_empty_intent_emits_always_on_only():
    """D-14 — when intents == set(), only the 2 always-on bundles fire."""
    out = compile_bundles(intents=set())
    assert out.activated_bundles == ["compliance-narrator", "life-event-router"]
    assert out.dropped_bundles == []
    # Always-on alone is ≥2k tokens (compliance + life-event-router stubs from Wave 0).
    assert out.estimated_tokens >= 1000


def test_always_on_present_on_every_intent_combo():
    """D-09 — both always-on bundles appear in EVERY combination."""
    for intent in ("retirement", "taxes", "housing", "debt", "family", "career"):
        out = compile_bundles(intents={intent})
        assert "compliance-narrator" in out.activated_bundles, intent
        assert "life-event-router" in out.activated_bundles, intent


def test_always_on_first_in_order():
    """D-11 — always-on bundles MUST appear before intent-driven ones in the
    activated list (their fragments must be read first by the narrator)."""
    out = compile_bundles(intents={"retirement", "taxes"})
    idx_compliance = out.activated_bundles.index("compliance-narrator")
    idx_life_event = out.activated_bundles.index("life-event-router")
    idx_pillar3a = out.activated_bundles.index("pillar3a-optimizer")
    assert idx_compliance < idx_pillar3a
    assert idx_life_event < idx_pillar3a


# ---------------------------------------------------------------------------
# D-02 intent → bundle mapping
# ---------------------------------------------------------------------------


def test_retirement_intent_activates_pillar3a_and_lpp():
    """D-02 — retirement → {pillar3a-optimizer, lpp-projector}."""
    out = compile_bundles(intents={"retirement"})
    assert "pillar3a-optimizer" in out.activated_bundles
    assert "lpp-projector" in out.activated_bundles


def test_taxes_intent_activates_tax_and_pillar3a():
    """D-02 — taxes → {tax-explainer, pillar3a-optimizer}."""
    out = compile_bundles(intents={"taxes"})
    assert "tax-explainer" in out.activated_bundles
    assert "pillar3a-optimizer" in out.activated_bundles


def test_housing_intent_activates_mortgage_and_tax():
    out = compile_bundles(intents={"housing"})
    assert "mortgage-stressor" in out.activated_bundles
    assert "tax-explainer" in out.activated_bundles


def test_debt_intent_activates_mortgage_and_compliance():
    """D-02 — debt → {mortgage-stressor, compliance-narrator}. The compliance
    bundle is already always-on, so debt MUST NOT double it."""
    out = compile_bundles(intents={"debt"})
    assert "mortgage-stressor" in out.activated_bundles
    # Compliance appears exactly ONCE (always-on dedup vs intent mapping).
    assert out.activated_bundles.count("compliance-narrator") == 1


def test_family_intent_activates_life_event_and_compliance():
    """family → {life-event-router, compliance-narrator, succession-divorce}.

    Pre-Plan-08 : both were always-on → no new entries beyond the always-on
    baseline. Plan 08 (D-CE-03 Override #2) added SuccessionDivorceBundle
    to the `family` intent so the narrator can surface CC art. 122-124 +
    CC art. 462 + CC art. 467-469 + LAVS art. 29sexies citation grammar.
    """
    out = compile_bundles(intents={"family"})
    assert sorted(out.activated_bundles) == sorted(
        ["compliance-narrator", "life-event-router", "succession-divorce"]
    )


def test_career_intent_activates_lpp_and_life_event_router():
    out = compile_bundles(intents={"career"})
    assert "lpp-projector" in out.activated_bundles
    # life-event-router already always-on, no double count.
    assert out.activated_bundles.count("life-event-router") == 1


# ---------------------------------------------------------------------------
# D-12 dedup
# ---------------------------------------------------------------------------


def test_multi_intent_dedup_pillar3a():
    """D-12 — `{retirement, taxes}` both map to pillar3a-optimizer ; it
    must appear exactly once in the activated list."""
    out = compile_bundles(intents={"retirement", "taxes"})
    assert out.activated_bundles.count("pillar3a-optimizer") == 1


def test_multi_intent_dedup_tax_explainer():
    """`{taxes, housing}` both map to tax-explainer ; it must appear once."""
    out = compile_bundles(intents={"taxes", "housing"})
    assert out.activated_bundles.count("tax-explainer") == 1


def test_tools_are_unioned_and_sorted():
    """D-12 — allowed_tools is union, dedup, sorted."""
    out = compile_bundles(intents={"retirement"})
    assert out.allowed_tools == sorted(set(out.allowed_tools))
    # pillar3a + lpp both use get_retirement_projection → appears once.
    assert out.allowed_tools.count("get_retirement_projection") == 1


def test_citations_are_unioned_and_sorted():
    out = compile_bundles(intents={"retirement", "taxes"})
    assert out.citation_allowlist == sorted(set(out.citation_allowlist))


# ---------------------------------------------------------------------------
# D-11 fragment composition
# ---------------------------------------------------------------------------


def test_prompt_uses_fragment_separator():
    """D-11 — fragments joined by '\\n\\n---\\n\\n'."""
    out = compile_bundles(intents={"retirement"})
    assert _FRAGMENT_SEPARATOR in out.prompt
    # On {retirement} we have 4 bundles → 3 separators.
    assert out.prompt.count(_FRAGMENT_SEPARATOR) == len(out.activated_bundles) - 1


def test_prompt_compliance_first_byte_position():
    """D-11 — compliance-narrator's prompt fragment must appear first in
    the assembled prompt (it owns {banned_terms} doctrine)."""
    out = compile_bundles(intents={"retirement"})
    assert out.prompt.find(ComplianceNarratorBundle().prompt_fragment) == 0


# ---------------------------------------------------------------------------
# Defensive normalization
# ---------------------------------------------------------------------------


def test_invalid_intent_silently_ignored():
    """`_classify_user_intent` cannot produce these strings, but if a future
    caller did, the compiler must not crash — just emit always-on only."""
    out = compile_bundles(intents={"nonsense", "totally_invented"})
    assert out.activated_bundles == ["compliance-narrator", "life-event-router"]


def test_intents_accept_set_or_list_or_frozenset():
    """The signature uses `Iterable[str]` — `set` / `list` / `frozenset`
    must all yield the same output (deterministic, sorted internally)."""
    a = compile_bundles(intents={"retirement", "taxes"})
    b = compile_bundles(intents=["retirement", "taxes"])
    c = compile_bundles(intents=frozenset({"retirement", "taxes"}))
    assert a.activated_bundles == b.activated_bundles == c.activated_bundles
    assert a.allowed_tools == b.allowed_tools == c.allowed_tools


def test_unions_are_deterministic_across_input_orderings():
    """Sorted internally — order of input set has no effect on output."""
    a = compile_bundles(intents=["retirement", "taxes"])
    b = compile_bundles(intents=["taxes", "retirement"])
    assert a.activated_bundles == b.activated_bundles
    assert a.prompt == b.prompt


# ---------------------------------------------------------------------------
# D-13 token budget enforcement (parametric ≥6 combinations + simulated overflow)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("intents", [
    set(),
    {"retirement"},
    {"taxes"},
    {"housing"},
    {"debt"},
    {"family"},
    {"career"},
    {"retirement", "taxes"},
    {"housing", "taxes"},
    {"retirement", "career", "family"},
    {"retirement", "taxes", "housing", "debt", "family", "career"},  # all 6
])
def test_compile_bundles_respects_token_budget(intents):
    """D-13 — `estimated_tokens <= 8000` on 11 representative intent combos."""
    out = compile_bundles(intents=intents)
    assert out.estimated_tokens <= _TOKEN_BUDGET, (
        f"Budget overflow on intents={intents!r} : "
        f"{out.estimated_tokens} > {_TOKEN_BUDGET}. "
        f"Activated={out.activated_bundles}, dropped={out.dropped_bundles}."
    )


def test_always_on_never_dropped_even_if_overflow_simulated(monkeypatch):
    """T-93.5-06 — patch _TOKEN_BUDGET to 100 so EVERYTHING droppable gets
    dropped ; always-on must remain in `activated_bundles`."""
    import app.services.coach.bundle_compiler as bc
    monkeypatch.setattr(bc, "_TOKEN_BUDGET", 100)
    out = bc.compile_bundles(intents={"retirement", "taxes", "housing", "debt"})
    # All 4 droppable bundle classes attempted, none of the 2 always-on dropped.
    assert "compliance-narrator" in out.activated_bundles
    assert "life-event-router" in out.activated_bundles
    # All 4 droppable classes were dropped.
    assert set(out.dropped_bundles) >= {
        "MortgageStressorBundle",
        "TaxExplainerBundle",
        "LppProjectorBundle",
        "Pillar3aOptimizerBundle",
    }
    # The dropped list MUST NOT contain any always-on class.
    assert "ComplianceNarratorBundle" not in out.dropped_bundles
    assert "LifeEventRouterBundle" not in out.dropped_bundles


def test_drop_order_is_right_to_left(monkeypatch):
    """D-13 — drop priority is mortgage → tax → lpp → pillar3a.
    Set budget just below {compliance + life-event + pillar3a} so only the
    last bundle (pillar3a) survives among intent-driven ones."""
    import app.services.coach.bundle_compiler as bc
    # Compute thresholds dynamically so this test is robust to fragment-fattening.
    base_chars = (
        len(ComplianceNarratorBundle().prompt_fragment)
        + len(LifeEventRouterBundle().prompt_fragment)
        + len(Pillar3aOptimizerBundle().prompt_fragment)
        + 3 * len(bc._FRAGMENT_SEPARATOR)
    )
    # Just enough room for always-on + pillar3a.
    monkeypatch.setattr(bc, "_TOKEN_BUDGET", base_chars // 4 + 5)
    out = bc.compile_bundles(intents={"housing", "taxes", "retirement"})
    # Activated = always-on + pillar3a (last in drop order). Mortgage, tax, lpp dropped.
    assert "pillar3a-optimizer" in out.activated_bundles
    # Dropped FIRST in mortgage → tax → lpp order.
    drop_idx = {name: i for i, name in enumerate(out.dropped_bundles)}
    if "MortgageStressorBundle" in drop_idx and "TaxExplainerBundle" in drop_idx:
        assert drop_idx["MortgageStressorBundle"] < drop_idx["TaxExplainerBundle"]
    if "TaxExplainerBundle" in drop_idx and "LppProjectorBundle" in drop_idx:
        assert drop_idx["TaxExplainerBundle"] < drop_idx["LppProjectorBundle"]


# ---------------------------------------------------------------------------
# H4 undeclared-slot guard
# ---------------------------------------------------------------------------


def test_undeclared_slot_regex_detects():
    """H4 — `_SINGLE_BRACE_SLOT` regex finds single-brace slots and ignores
    `{{cite:<key>}}` Phase-94 placeholders (double-brace)."""
    text = (
        "Hello {banned_terms} and {{cite:r3a_2026}} but also {invented_slot}"
    )
    slots = set(_SINGLE_BRACE_SLOT.findall(text))
    assert "banned_terms" in slots
    assert "invented_slot" in slots
    # Double-brace `{{cite:...}}` is not a slot.
    assert "cite:r3a_2026" not in slots
    # `cite:r3a_2026` doesn't match \w+ anyway (contains `:`), but verify
    # the canonical Phase 94 form is excluded by lookbehind/lookahead too.
    text2 = "{{cite:foo}}"
    assert _SINGLE_BRACE_SLOT.findall(text2) == []
    assert "invented_slot" not in _DECLARED_SLOTS


def test_compile_bundles_real_assembly_has_only_declared_slots():
    """H4 — after real bundle assembly, every single-brace slot is in the
    canonical 7-set (defense-in-depth on top of Plan 93.5-01 Task 2's
    per-bundle invariant)."""
    out = compile_bundles(intents={"retirement", "taxes", "housing", "debt"})
    slots = set(_SINGLE_BRACE_SLOT.findall(out.prompt))
    assert slots <= _DECLARED_SLOTS, (
        f"compile_bundles emitted undeclared slots : {slots - _DECLARED_SLOTS}"
    )


def test_compile_bundles_rejects_undeclared_slot(monkeypatch):
    """H4 — patch the assembly path to inject an 8th slot ; compile_bundles
    must raise ValueError BEFORE handing the prompt to `_build_prompt`."""
    import app.services.coach.bundle_compiler as bc

    real_assemble = bc._assemble

    def _poisoned_assemble(bundles):
        prompt, _ = real_assemble(bundles)
        prompt += "\n\nUndeclared : {fake_slot_xyz}\n"
        return prompt, len(prompt) // 4

    monkeypatch.setattr(bc, "_assemble", _poisoned_assemble)

    with pytest.raises(ValueError, match="undeclared slot"):
        bc.compile_bundles(intents={"retirement"})


# ---------------------------------------------------------------------------
# Sanity : full coverage of D-20 tool registry on a wide intent set
# ---------------------------------------------------------------------------


def test_allowed_tools_is_subset_of_d20_canonical_six():
    """D-20 — every emitted tool name from the canonical 7 Wave 0/2 bundles
    must be in the canonical 6-name narrator-tool registry
    (coach_tools.py:637-730).

    Plan 08 (D-CE-03) adds 2 evidence-gap bundles (IndependentTaxBundle +
    SuccessionDivorceBundle) whose `allowed_tools` are PLACEHOLDER names
    awaiting Plan 09 W2-03 (LSFin description rewrite + REGISTRY canonical
    naming review). The legacy D-20 subset invariant continues to hold for
    the 7 Wave 0/2 bundles ; the 2 new bundles are explicitly exempted
    from this test until Plan 09 wires them through the narrator registry.
    """
    canonical = {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
        "get_regulatory_constant",
    }
    # Plan 08 placeholder tools — to be reconciled by Plan 09 W2-03.
    plan_08_placeholder_tools = (
        set(IndependentTaxBundle().allowed_tools)
        | set(SuccessionDivorceBundle().allowed_tools)
    )
    out = compile_bundles(
        intents={"retirement", "taxes", "housing", "debt", "family", "career"}
    )
    # Subtract Plan 08 placeholders ; what's left must be in the canonical six.
    legacy_tools = set(out.allowed_tools) - plan_08_placeholder_tools
    assert legacy_tools <= canonical, (
        f"D-20 violation : legacy Wave 0/2 bundles leaked tools outside the "
        f"canonical 6-name registry : {legacy_tools - canonical}"
    )


# ---------------------------------------------------------------------------
# Plan 08 W2-02-03 — IndependentTaxBundle + SuccessionDivorceBundle wire-up
# ---------------------------------------------------------------------------


def test_taxes_intent_includes_independent_tax_bundle():
    """D-CE-03 — `taxes` intent activates IndependentTaxBundle alongside
    TaxExplainerBundle and Pillar3aOptimizerBundle."""
    out = compile_bundles(intents={"taxes"})
    assert "independent-tax" in out.activated_bundles
    assert "tax-explainer" in out.activated_bundles
    assert "pillar3a-optimizer" in out.activated_bundles


def test_family_intent_includes_succession_divorce_bundle():
    """D-CE-03 — `family` intent activates SuccessionDivorceBundle alongside
    the always-on LifeEventRouterBundle and ComplianceNarratorBundle."""
    out = compile_bundles(intents={"family"})
    assert "succession-divorce" in out.activated_bundles
    assert "life-event-router" in out.activated_bundles
    assert "compliance-narrator" in out.activated_bundles


def test_career_intent_includes_independent_tax_bundle():
    """D-CE-03 — `career` intent activates IndependentTaxBundle alongside
    LppProjectorBundle (and the always-on LifeEventRouterBundle)."""
    out = compile_bundles(intents={"career"})
    assert "independent-tax" in out.activated_bundles
    assert "lpp-projector" in out.activated_bundles


def test_drop_priority_lists_new_bundles_first():
    """RESEARCH §Q-F lines 945-953 — under token-budget pressure the 2 new
    Plan 08 bundles drop FIRST (right-most in budget terms = leftmost in
    list per the right-to-left dropping semantics of bundle_compiler)."""
    from app.services.coach.bundle_compiler import _DROP_PRIORITY
    # Both new bundles MUST be in _DROP_PRIORITY (otherwise they couldn't drop).
    assert IndependentTaxBundle in _DROP_PRIORITY
    assert SuccessionDivorceBundle in _DROP_PRIORITY
    # IndependentTaxBundle is listed FIRST in _DROP_PRIORITY.
    assert _DROP_PRIORITY.index(IndependentTaxBundle) == 0
    # SuccessionDivorceBundle is listed SECOND.
    assert _DROP_PRIORITY.index(SuccessionDivorceBundle) == 1


def test_drop_priority_disjoint_from_always_on_after_plan_08():
    """T-93.5-06 — module-import-time invariant preserved after Plan 08
    extends _DROP_PRIORITY with 2 new bundles."""
    from app.services.coach.bundle_compiler import _ALWAYS_ON, _DROP_PRIORITY
    assert set(_DROP_PRIORITY).isdisjoint(set(_ALWAYS_ON))


def test_family_intent_compiled_includes_divorce_simulator_tool():
    """End-to-end — when `family` intent is active, `compile_bundles`
    returns a CompiledBundle whose `allowed_tools` includes
    `divorce_simulator` (proves SuccessionDivorceBundle wired in)."""
    out = compile_bundles(intents={"family"})
    assert "divorce_simulator" in out.allowed_tools
    assert "succession_simulator" in out.allowed_tools
    assert "concubinage_succession" in out.allowed_tools
