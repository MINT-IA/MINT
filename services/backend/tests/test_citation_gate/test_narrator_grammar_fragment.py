"""Phase 94.1 Wave 4 — narrator citation-grammar fragment tests.

Pins the contract of the new `app.services.coach.citation_grammar` module
+ the flag-conditional inclusion in both narrator paths (legacy
`build_narrator_system_prompt` AND bundle compiler `compile_bundles`).

Per `94.1-01-PLAN.md` Task 2 must-haves :

1. The fragment is included in `build_narrator_system_prompt(...)` output
   when `COACH_CITATION_GATE_ENABLED=True` (legacy path covers eval
   harness via `tools.eval_narrator._build_system_prompt_for_fixture`
   `prompt_builder='legacy'`).
2. The fragment is included in `build_narrator_system_prompt_from_bundles(
   intents=set(), ctx=None)` output when the flag is True (active prod
   path).
3. All 18 keys from `CITATION_REGISTRY` appear in the rendered fragment
   (introspection coupling — if a key is added later, this test fails
   until the prompt builder picks it up).
4. The fragment includes ≥1 verbatim `{{cite:<key>}}` example AND ≥1
   fallback example (« je n'ai pas cette donnée pour l'instant »).
5. The grammar bundle does NOT inflate `_DECLARED_SLOTS` (no new
   single-brace `{slot}` placeholders introduced).

All flag toggles use `monkeypatch` on env var + `app.core.config.settings`
so each test is hermetic (no env var bleed across the suite).
"""
from __future__ import annotations

import re

import pytest

from app.services.coach.bundles.citation_grammar import CitationGrammarBundle
from app.services.coach.citation_grammar import (
    CITATION_GRAMMAR_FRAGMENT,
    _build_citation_grammar_fragment,
)
from app.services.coach.citation_registry import CITATION_REGISTRY


# ---------------------------------------------------------------------------
# Helper — flag toggle context (env var + live settings)
# ---------------------------------------------------------------------------


def _flip_gate_flag(monkeypatch: pytest.MonkeyPatch, value: bool) -> None:
    """Set COACH_CITATION_GATE_ENABLED on env + live settings to `value`.

    Mirrors the dual-write pattern in `tools.eval_narrator._run_eval` so
    both the legacy path (env-var read) and the bundle path (settings
    attribute read) pick up the change.
    """
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "true" if value else "false")
    from app.core.config import settings as _settings
    monkeypatch.setattr(_settings, "COACH_CITATION_GATE_ENABLED", value)


# ---------------------------------------------------------------------------
# Test 1 — fragment text invariants (importability + structural)
# ---------------------------------------------------------------------------


def test_fragment_is_nonempty_str_with_grammar_header():
    """`CITATION_GRAMMAR_FRAGMENT` is a non-empty FR string with the
    « DOCTRINE — GRAMMAIRE DE CITATION » header. Sanity check + smoke
    importability of the new module.
    """
    assert isinstance(CITATION_GRAMMAR_FRAGMENT, str)
    assert len(CITATION_GRAMMAR_FRAGMENT) > 100, (
        f"fragment too short ({len(CITATION_GRAMMAR_FRAGMENT)} chars) — "
        f"expected ≥100 chars covering header + keys + examples + rules"
    )
    assert "DOCTRINE — GRAMMAIRE DE CITATION" in CITATION_GRAMMAR_FRAGMENT, (
        "fragment missing the closed-world doctrine header"
    )


def test_fragment_lists_all_24_registry_keys():
    """Coupling : every key in CITATION_REGISTRY appears in the fragment
    text (so the narrator sees the closed-world vocabulary). If a future
    PR adds a registry key, this test fails until the prompt builder is
    re-run / the fragment is regenerated. Defensive against orphan keys
    (Phase 94.1 must-have #1).

    Wave 1b Plan 03 — re-tightened from the Plan 02 split (18 non-tool +
    6 tool sub-baseline) to the unified 24-key total because Plan 03 wires
    `tool_*` keys into the grammar fragment via auto-iteration over
    `CITATION_REGISTRY.keys()`. The non-tool sub-baseline of 18 (Phase 94
    Wave 0 baseline) is preserved as a regression check so a count drift
    in the regulatory surface surfaces here independently of the tool
    surface.
    """
    missing: list[str] = []
    for key in CITATION_REGISTRY.keys():
        # The fragment renders each key as `{{cite:<key>}}` inside backticks.
        if f"{{{{cite:{key}}}}}" not in CITATION_GRAMMAR_FRAGMENT:
            missing.append(key)
    assert not missing, (
        f"{len(missing)} CITATION_REGISTRY key(s) missing from grammar "
        f"fragment : {missing[:5]}..."
    )
    # Phase 94 Wave 0 + Wave 1b Plan 02 cumulative count : 18 non-tool +
    # 6 tool_call_id = 24 total. Drift in either sub-bucket surfaces here.
    non_tool_keys = [
        k
        for k, src in CITATION_REGISTRY.items()
        if src.source_kind != "tool_call_id"
    ]
    tool_keys = [
        k
        for k, src in CITATION_REGISTRY.items()
        if src.source_kind == "tool_call_id"
    ]
    assert len(non_tool_keys) == 18, (
        f"CITATION_REGISTRY non-tool drift : expected 18 keys (Phase 94 "
        f"Wave 0 baseline), got {len(non_tool_keys)}. Update both the "
        f"registry and this assertion when intentional."
    )
    assert len(tool_keys) == 6, (
        f"CITATION_REGISTRY tool_call_id drift : expected 6 keys (Wave 1b "
        f"Plan 02 baseline), got {len(tool_keys)}. Update both the "
        f"registry and this assertion when intentional."
    )
    assert len(CITATION_REGISTRY) == 24, (
        f"CITATION_REGISTRY total drift : expected 24 keys (18 non-tool + "
        f"6 tool_call_id), got {len(CITATION_REGISTRY)}."
    )


def test_fragment_includes_verbatim_examples_and_fallback():
    """Fragment must show ≥1 cited-number example AND ≥1 fallback
    example. Verbatim phrasing matches D-09 / D-10 style.
    """
    # Cited example — the verbatim `{{cite:r3a_plafond_salarie_2026}}` is
    # the canonical example in `94.1-01-PLAN.md` content blueprint.
    assert "{{cite:r3a_plafond_salarie_2026}}" in CITATION_GRAMMAR_FRAGMENT, (
        "fragment missing the verbatim cited-number example"
    )
    # Fallback phrasing — the narrator's no-key fallback string MUST be
    # quoted verbatim in the fragment so the LLM sees the exact text it
    # should emit when no key applies.
    assert "je n'ai pas cette donnée" in CITATION_GRAMMAR_FRAGMENT, (
        "fragment missing the verbatim « je n'ai pas cette donnée » "
        "fallback phrasing (D-10 style)"
    )


def test_fragment_does_not_introduce_new_single_brace_slots():
    """The bundle compiler's H4 guard (`_DECLARED_SLOTS` at
    `bundle_compiler.py:97-105`) raises ValueError on undeclared
    single-brace `{slot}` patterns. The grammar fragment uses ONLY
    double-brace `{{cite:<key>}}` placeholders ; this test confirms no
    single-brace `{...}` slot leaks in.
    """
    # Single-brace `{slot}` pattern (mirrors `_SINGLE_BRACE_SLOT` regex
    # at `bundle_compiler.py:110`).
    single_brace = re.compile(r"(?<!\{)\{(\w+)\}(?!\})")
    matches = set(single_brace.findall(CITATION_GRAMMAR_FRAGMENT))
    assert not matches, (
        f"grammar fragment introduced unexpected single-brace `{{slot}}` "
        f"placeholder(s) : {sorted(matches)}. Use only `{{{{cite:<key>}}}}` "
        f"double-brace form to stay below the H4 declared-slot guard."
    )


def test_fragment_builder_is_pure_and_deterministic():
    """`_build_citation_grammar_fragment()` is a pure function — calling
    it twice returns the same string (sanity for module-import-time cache
    contract).
    """
    a = _build_citation_grammar_fragment()
    b = _build_citation_grammar_fragment()
    assert a == b
    assert a == CITATION_GRAMMAR_FRAGMENT


# ---------------------------------------------------------------------------
# Test 2 — legacy narrator path picks up the fragment when flag is ON
# ---------------------------------------------------------------------------


def test_legacy_path_includes_fragment_when_flag_on(monkeypatch: pytest.MonkeyPatch):
    """`build_narrator_system_prompt(ctx=None, language='fr', cash_level=3)`
    appends the grammar fragment when `COACH_CITATION_GATE_ENABLED=true`.

    This is the path the eval harness exercises (per `tools/eval_narrator.py
    :182` `prompt_builder='legacy'`). Without this, the live re-eval
    cannot measure the fattened prompt.
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt,
    )
    out = build_narrator_system_prompt(ctx=None, language="fr", cash_level=3)
    assert "DOCTRINE — GRAMMAIRE DE CITATION" in out, (
        "legacy narrator path did NOT pick up the grammar fragment when "
        "COACH_CITATION_GATE_ENABLED=true"
    )
    # Sanity : the full fragment is appended (not just a fragment of it).
    assert CITATION_GRAMMAR_FRAGMENT in out, (
        "fragment is included partially — full append contract broken"
    )


def test_legacy_path_byte_identity_preserved_when_flag_off(
    monkeypatch: pytest.MonkeyPatch,
):
    """When `COACH_CITATION_GATE_ENABLED=false`, the legacy narrator path
    does NOT include the grammar fragment. This is the byte-identity
    invariant that protects the 5×2 snapshots pinned by
    `test_byte_identity_flag_off.py` and
    `test_flag_off_byte_identical_to_snapshot`.
    """
    _flip_gate_flag(monkeypatch, False)
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt,
    )
    out = build_narrator_system_prompt(ctx=None, language="fr", cash_level=3)
    assert "DOCTRINE — GRAMMAIRE DE CITATION" not in out, (
        "legacy narrator path leaked the grammar fragment with the flag OFF "
        "— byte-identity invariant broken"
    )


# ---------------------------------------------------------------------------
# Test 3 — bundle path picks up the fragment when flag is ON
# ---------------------------------------------------------------------------


def test_bundle_path_includes_fragment_when_flag_on(
    monkeypatch: pytest.MonkeyPatch,
):
    """`build_narrator_system_prompt_from_bundles(intents=set(), ctx=None)`
    includes the grammar fragment when `COACH_CITATION_GATE_ENABLED=true`,
    even with EMPTY intent set (always-on regardless of intent per Phase
    94.1 architecture).
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt_from_bundles,
    )
    out = build_narrator_system_prompt_from_bundles(
        intents=set(), ctx=None, language="fr", cash_level=3
    )
    assert "DOCTRINE — GRAMMAIRE DE CITATION" in out, (
        "bundle narrator path did NOT pick up the grammar fragment with "
        "empty intents and flag ON — always-on contract broken"
    )


def test_bundle_path_skips_fragment_when_flag_off(
    monkeypatch: pytest.MonkeyPatch,
):
    """`build_narrator_system_prompt_from_bundles` does NOT include the
    grammar bundle when the flag is OFF. Preserves the
    `test_empty_intent_emits_always_on_only` invariant
    (`activated_bundles == ['compliance-narrator', 'life-event-router']`).
    """
    _flip_gate_flag(monkeypatch, False)
    from app.services.coach.bundle_compiler import compile_bundles
    out = compile_bundles(intents=set())
    assert out.activated_bundles == [
        "compliance-narrator",
        "life-event-router",
    ], (
        "bundle compiler activated_bundles drifted with flag OFF : "
        f"{out.activated_bundles!r} — Phase 93.5 invariant broken"
    )
    assert "citation-grammar" not in out.activated_bundles


# ---------------------------------------------------------------------------
# Test 4 — bundle compiler activated_bundles when flag ON
# ---------------------------------------------------------------------------


def test_compile_bundles_appends_citation_grammar_when_flag_on(
    monkeypatch: pytest.MonkeyPatch,
):
    """`compile_bundles(intents=set())` returns 3 activated bundles when
    `COACH_CITATION_GATE_ENABLED=true` : compliance, life-event-router,
    citation-grammar (in that order — compliance first per D-09).
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.bundle_compiler import compile_bundles
    out = compile_bundles(intents=set())
    assert out.activated_bundles == [
        "compliance-narrator",
        "life-event-router",
        "citation-grammar",
    ], (
        f"flag-ON bundle list drift : {out.activated_bundles!r}"
    )


def test_compile_bundles_no_double_inclusion_under_intent(
    monkeypatch: pytest.MonkeyPatch,
):
    """Flag-ON + intent={'retirement'} : citation-grammar appears EXACTLY
    once (not double-counted by the dedup logic).
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.bundle_compiler import compile_bundles
    out = compile_bundles(intents={"retirement"})
    assert out.activated_bundles.count("citation-grammar") == 1, (
        f"citation-grammar bundle appears {out.activated_bundles.count('citation-grammar')} "
        f"times in {out.activated_bundles!r} — dedup broken"
    )


# ---------------------------------------------------------------------------
# Test 5 — bundle config invariants (Pydantic v2 frozen + extra=forbid)
# ---------------------------------------------------------------------------


def test_citation_grammar_bundle_pydantic_invariants():
    """`CitationGrammarBundle` honors the BundleBase config (frozen +
    extra=forbid) so future drift fails at instantiation.
    """
    bundle = CitationGrammarBundle()
    assert bundle.name == "citation-grammar"
    assert bundle.allowed_tools == [], (
        "citation-grammar bundle is doctrine-only ; allowed_tools must "
        "stay empty per Phase 94.1 spec"
    )
    assert bundle.citation_allowlist == [], (
        "citation-grammar bundle TEACHES the grammar ; citation_allowlist "
        "must stay empty (the registry is the source of truth)"
    )
    # Pydantic v2 frozen contract — assignment after instantiation raises.
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        bundle.name = "mutated"  # type: ignore[misc]
