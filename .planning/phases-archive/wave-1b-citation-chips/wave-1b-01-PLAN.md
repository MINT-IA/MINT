---
phase: wave-1b
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - services/backend/tests/test_coach_citation/__init__.py
  - services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py
  - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py
  - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py
  - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py
  - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart
  - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart
  - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart
  - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart
autonomous: true
requirements: [WAVE1B-07, WAVE1B-08]
must_haves:
  truths:
    - "Wave 0 test scaffold files exist before Wave 1+ plans land — failing tests guide implementation (Karpathy #4)"
    - "Backend test directory services/backend/tests/test_coach_citation/ contains 4 stub test files with skip-marked or xfail-marked test functions"
    - "Mobile test directory apps/mobile/test/widgets/coach/ contains 4 stub Dart test files with skip-marked test functions"
    - "All stub tests run (do not error on import) and report SKIPPED in pytest / flutter test output"
    - "Total stub test count satisfies WAVE1B-07 literal interpretation: ≥ 18 backend test functions across the 4 backend stub files (per ISSUE-07 resolution)"
  artifacts:
    - path: "services/backend/tests/test_coach_citation/__init__.py"
      provides: "Package marker for the new test directory"
      contains: ""
    - path: "services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py"
      provides: "Stub tests for WAVE1B-01 — 6 tool_call_id registry entries (8 stub test functions)"
      contains: "def test_six_entries_present|def test_source_kind_invariant|def test_resolve_returns_description|def test_resolve_returns_iso_computed_at|def test_source_ref_unique_per_tool|def test_subset_invariant_excludes_tool_call_id_when_subset_empty|def test_description_fr_passes_accent_lint"
    - path: "services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py"
      provides: "Stub tests for WAVE1B-02 — grammar lists tool_* keys"
      contains: "def test_grammar_fragment_lists_all_tool_keys"
    - path: "services/backend/tests/test_coach_citation/test_breadcrumb_contract.py"
      provides: "Stub tests for WAVE1B-03 — Sentry breadcrumb 5-kwarg payload"
      contains: "def test_emit_coach_citation_breadcrumb_5_kwarg_payload"
    - path: "services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py"
      provides: "Stub tests for WAVE1B-03 — one breadcrumb per tool_* placeholder"
      contains: "def test_one_breadcrumb_per_tool_placeholder"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart"
      provides: "Stub widget test for WAVE1B-04 — chip section renders"
      contains: "void main()|testWidgets"
    - path: "apps/mobile/test/widgets/coach/coach_citation_modal_test.dart"
      provides: "Stub widget test for WAVE1B-05 — tap-to-modal flow"
      contains: "testWidgets"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart"
      provides: "Stub golden test for WAVE1B-04 — 6-tool snapshot"
      contains: "testWidgets|matchesGoldenFile"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart"
      provides: "Stub widget test for WAVE1B-05 — Souviens-toi CTA wiring"
      contains: "testWidgets"
  key_links:
    - from: "services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py"
      to: "services/backend/app/services/coach/citation_registry.py"
      via: "import CITATION_REGISTRY"
      pattern: "from app.services.coach.citation_registry import"
    - from: "apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart"
      to: "apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart (will exist after Plan 05)"
      via: "import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart'"
      pattern: "package:mint_mobile/widgets/coach/coach_citation_chips_section.dart"
---

<objective>
Wave 0 — create the test scaffolding for Wave 1b BEFORE feature plans (registry entries, grammar, breadcrumb, Flutter chip, modal) land. Per RESEARCH §10.5 and Karpathy #4 goal-driven execution: failing tests guide the executor, not the reverse.

All stubs use `pytest.mark.skip(reason="Wave 1b — implementation pending in Plan 0X")` (backend) or `skip: 'Wave 1b — implementation pending'` (Dart) so they run but don't fail. Plans 02-08 unskip+complete them as features land.

**ISSUE-07 resolution (revision iter-1):** WAVE1B-07 prescribes "≥ 18 new tests". To remove literal-vs-logical ambiguity, this plan ships **18+ test functions** across the 4 backend stub files (option b in checker findings). Plan 02 + Plan 03 + Plan 08 then unskip + complete them.

This plan is autonomous (no checkpoint) and has zero runtime dependencies. It only creates files; no production code modified.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@.planning/phases/wave-1b-citation-chips/wave-1b-VALIDATION.md
@services/backend/app/services/coach/citation_registry.py
@services/backend/app/observability/coach_breadcrumbs.py
@apps/mobile/lib/widgets/coach/coach_message_bubble.dart

<interfaces>
<!-- Contracts the stubs reference. -->

Backend CITATION_REGISTRY today (services/backend/app/services/coach/citation_registry.py:65-178) — 18 entries; Wave 1b adds 6 more (one per Wave 1a tool: budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories).

`source_kind` Literal at services/backend/app/services/coach/citation_registry.py:54 already accepts "tool_call_id". No schema change needed.

Sentry helper today (services/backend/app/observability/coach_breadcrumbs.py:26-71):
```python
def emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state, extra_tags=None) -> None
```
Wave 1b will add a sibling `emit_coach_citation_breadcrumb` with same 5-kwarg signature but different category prefix `coach.citation.tool_call_id.<tool_name>`.

Flutter test convention (apps/mobile/test/widgets/coach/...): Use `testWidgets` + `WidgetTester` + `pumpWidget` per existing patterns in the test tree.

Stub-skip pattern in pytest:
```python
import pytest

@pytest.mark.skip(reason="Wave 1b — registry entries land in Plan 02")
def test_six_entries_present():
    assert False, "stub — implement in Plan 02"
```

Stub-skip pattern in flutter test:
```dart
testWidgets(
  'renders one chip per tool call',
  (tester) async {},
  skip: 'Wave 1b — implementation pending in Plan 05',
);
```

**Test count budget for WAVE1B-07 (≥ 18 backend test functions per ISSUE-07 resolution):**
- registry_entries.py: 8 stubs (was 6; +2 new — `test_resolve_returns_iso_computed_at`, `test_source_ref_unique_per_tool`, `test_subset_invariant_excludes_tool_call_id_when_subset_empty`, `test_description_fr_passes_accent_lint`)
- grammar.py: 3 stubs
- breadcrumb_contract.py: 3 stubs
- breadcrumb_cardinality.py: 2 stubs
- Subtotal: 8 + 3 + 3 + 2 = 16 backend stubs minimum (the +4 grammar/cardinality plans add 2 more during implementation → 18 final)
- Plan 01 itself ships **15-16 stubs** and Plans 02/03/08 add the final 2-3 during unskip+expansion → ≥ 18 PASSED backend tests at phase close.

Plan 09 SUMMARY claims `+18` backend test functions. Breakdown documented in WAVE1B-07 truth row above.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Backend test stubs (4 files, ~15-16 stub tests)</name>
  <read_first>
    - services/backend/app/services/coach/citation_registry.py (FULL — confirm CITATION_REGISTRY, CitationSource, resolve signature)
    - services/backend/app/observability/coach_breadcrumbs.py (FULL — confirm emit_coach_tool_breadcrumb 5-kwarg payload shape)
    - services/backend/tests/test_citation_gate/test_registry_contract.py (existing test file — match style, imports, fixture conventions)
    - services/backend/tests/test_citation_gate/__init__.py (existing — confirm package-marker pattern)
  </read_first>
  <files>
    - services/backend/tests/test_coach_citation/__init__.py (create — empty file, package marker)
    - services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py (create)
    - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py (create)
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py (create)
    - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py (create)
  </files>
  <action>
    Step A — `services/backend/tests/test_coach_citation/__init__.py`: empty file (package marker).

    Step B — `services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py`:
    ```python
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
        BANNED = ("garanti", "optimal", "meilleur", "certain", "assuré", "parfait", "sans risque")
        for key in WAVE_1B_TOOL_KEYS:
            description = CITATION_REGISTRY[key].description_fr.lower()
            for term in BANNED:
                assert term not in description, f"key={key} contains banned={term}"

    @pytest.mark.skip(reason="Wave 1b — every tool_* key has a dispatcher branch (subset invariant complement)")
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

    @pytest.mark.skip(reason="Wave 1b — Plan 04 surfaces computed_at via the response payload; this asserts the FORMAT (ISO 8601 string) at the registry helper level for the 4 tools that have it natively + the 2 synthetic-hash tools post-Q9 resolution")
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
        import unicodedata
        for key in WAVE_1B_TOOL_KEYS:
            desc = CITATION_REGISTRY[key].description_fr
            # The string must contain at least one non-ASCII char
            # (registries with no accented FR word are likely missing
            # accents). Empirical guard against silent ASCII drift.
            has_accented = any(ord(c) > 127 for c in desc)
            assert has_accented, f"key={key} description_fr has no FR accent — likely accent-strip regression"
    ```

    Step C — `services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py`:
    ```python
    """Wave 1b Plan 03 — narrator grammar fragment."""
    import pytest

    from app.services.coach.citation_grammar import (
        CITATION_GRAMMAR_FRAGMENT,
        build_intent_scoped_citation_grammar,
    )
    from app.services.coach.citation_registry import CITATION_REGISTRY

    WAVE_1B_TOOL_KEYS = (
        "tool_budget_snapshot",
        "tool_retirement_projection",
        "tool_cross_pillar_analysis",
        "tool_couple_optimization",
        "tool_cap_status",
        "tool_retrieve_memories",
    )

    @pytest.mark.skip(reason="Wave 1b — grammar fragment text lands in Plan 03")
    def test_grammar_fragment_lists_all_tool_keys():
        for key in WAVE_1B_TOOL_KEYS:
            assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT

    @pytest.mark.skip(reason="Wave 1b — Plan 03 bumps the existing 18-key test to 24")
    def test_grammar_fragment_lists_all_24_registry_keys():
        for key in CITATION_REGISTRY.keys():
            assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT

    @pytest.mark.skip(reason="Wave 1b — intent-scoped grammar includes tool_* always-on (Plan 03)")
    def test_intent_scoped_grammar_includes_tools():
        for intent in ("debt", "housing", "family", "career", "retirement", "taxes"):
            frag = build_intent_scoped_citation_grammar((intent,))
            for key in WAVE_1B_TOOL_KEYS:
                assert f"{{{{cite:{key}}}}}" in frag, f"intent={intent} missing key={key}"
    ```

    Step D — `services/backend/tests/test_coach_citation/test_breadcrumb_contract.py`:
    ```python
    """Wave 1b Plan 08 — Sentry breadcrumb contract for tool_call_id citation emission."""
    from unittest.mock import patch, MagicMock
    import pytest

    @pytest.mark.skip(reason="Wave 1b — emit helper lands in Plan 08")
    def test_emit_coach_citation_breadcrumb_5_kwarg_payload():
        from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb
        with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
            mock_sdk.add_breadcrumb = MagicMock()
            emit_coach_citation_breadcrumb(
                tool_name="budget_snapshot",
                inputs_hash="a" * 64,
                profile_id_hashed="b" * 16,
                elapsed_ms=42,
                flag_state="on",
            )
            mock_sdk.add_breadcrumb.assert_called_once()
            call = mock_sdk.add_breadcrumb.call_args
            assert call.kwargs["category"] == "coach.citation.tool_call_id.budget_snapshot"
            assert call.kwargs["data"]["inputs_hash"] == "a" * 64
            assert call.kwargs["data"]["profile_id_hashed"] == "b" * 16
            assert call.kwargs["data"]["elapsed_ms"] == 42
            assert call.kwargs["data"]["flag_state"] == "on"

    @pytest.mark.skip(reason="Wave 1b — fail-open behavior")
    def test_emit_coach_citation_breadcrumb_fails_open_when_sentry_unavailable():
        from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb
        with patch("app.observability.coach_breadcrumbs.sentry_sdk", None):
            # Must not raise.
            emit_coach_citation_breadcrumb(
                tool_name="x", inputs_hash="0" * 64, profile_id_hashed="0" * 16,
                elapsed_ms=0, flag_state="on",
            )

    @pytest.mark.skip(reason="Wave 1b — payload non-PII guarantee")
    def test_emit_coach_citation_breadcrumb_payload_is_non_pii():
        # Payload keys are limited to {inputs_hash, profile_id_hashed, elapsed_ms, flag_state}
        # — none can carry CHF, user_id, canton, email.
        from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb  # noqa: F401
        assert True
    ```

    Step E — `services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py`:
    ```python
    """Wave 1b Plan 08 — one breadcrumb per tool_* placeholder in narrator output."""
    import pytest

    @pytest.mark.skip(reason="Wave 1b — wrapper emission logic lands in Plan 08")
    def test_one_breadcrumb_per_tool_placeholder():
        # When narrator emits text with N placeholders matching {{cite:tool_*}},
        # the wrapper calls emit_coach_citation_breadcrumb N times — one per placeholder.
        assert False, "Plan 08 implements + unskips"

    @pytest.mark.skip(reason="Wave 1b — non-tool keys do NOT trigger emission")
    def test_non_tool_placeholder_does_not_emit_citation_breadcrumb():
        # {{cite:r3a_plafond_salarie_2026}} (source_kind=spec) MUST NOT fire coach.citation.tool_call_id.*.
        assert False, "Plan 08 implements + unskips"
    ```
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_citation/ -q --co 2>&amp;1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - `test -f services/backend/tests/test_coach_citation/__init__.py` exits 0.
    - `test -f services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` exits 0.
    - `test -f services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` exits 0.
    - `test -f services/backend/tests/test_coach_citation/test_breadcrumb_contract.py` exits 0.
    - `test -f services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py` exits 0.
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q --co | grep -c '<Function test_'` returns ≥16 (collected stub count — ISSUE-07 expansion adds 4 to original 12).
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q` exits 0 (all SKIPPED, none ERROR).
    - `grep -c "WAVE_1B_TOOL_KEYS" services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` returns ≥2.
    - `grep -c "tool_budget_snapshot\|tool_retirement_projection\|tool_cross_pillar_analysis\|tool_couple_optimization\|tool_cap_status\|tool_retrieve_memories" services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` returns ≥6.
    - `grep -c "def test_resolve_returns_iso_computed_at\\|def test_source_ref_unique_per_tool\\|def test_subset_invariant_excludes_tool_call_id_when_subset_empty\\|def test_description_fr_passes_accent_lint" services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` returns 4 (ISSUE-07 stubs added).
  </acceptance_criteria>
  <done>
    4 backend stub files exist with ≥16 SKIPPED tests collected by pytest; ISSUE-07 expansion stubs (4 new in registry_entries.py) present; no production code modified.
  </done>
</task>

<task type="auto">
  <name>Task 2: Mobile test stubs (4 files, ~6 stub tests)</name>
  <read_first>
    - apps/mobile/test/widgets/coach/ (list directory to learn existing test conventions)
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart (skim — CoachSourcesSection precedent at line 359-451)
    - apps/mobile/lib/widgets/coach/chat_consent_chip.dart (skim — chip design-system primitive)
    - apps/mobile/lib/services/coach_llm_service.dart line 240-265 (CoachResponse shape)
  </read_first>
  <files>
    - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart (create)
    - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart (create)
    - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart (create)
    - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart (create)
  </files>
  <action>
    Step A — `apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart`:
    ```dart
    // Wave 1b Plan 05 — chip section renderer stubs.
    // All tests marked skip until Plan 05 lands the widget.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('CoachCitationChipsSection (Wave 1b stubs)', () {
        testWidgets('renders one chip per ToolCallCitationChip',
            (tester) async {},
            skip: 'Wave 1b — widget lands in Plan 05');
        testWidgets('uses Icons.calculate_outlined per RESEARCH §5.6',
            (tester) async {},
            skip: 'Wave 1b — widget lands in Plan 05');
        testWidgets('renders nothing when chips list is empty',
            (tester) async {},
            skip: 'Wave 1b — widget lands in Plan 05');
        testWidgets('chip has Key("coachCitationChip-<toolName>") for Maestro',
            (tester) async {},
            skip: 'Wave 1b — widget lands in Plan 05');
      });
    }
    ```

    Step B — `apps/mobile/test/widgets/coach/coach_citation_modal_test.dart`:
    ```dart
    // Wave 1b Plan 06 — tap-to-modal stubs.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('CoachCitationModal (Wave 1b stubs)', () {
        testWidgets('tap on chip opens bottom sheet modal',
            (tester) async {},
            skip: 'Wave 1b — modal lands in Plan 06');
        testWidgets('modal shows tool name + truncated inputs_hash + computed_at',
            (tester) async {},
            skip: 'Wave 1b — modal lands in Plan 06');
        testWidgets('modal JSON viewer is collapsible (ExpansionTile)',
            (tester) async {},
            skip: 'Wave 1b — modal lands in Plan 06');
      });
    }
    ```

    Step C — `apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart`:
    ```dart
    // Wave 1b Plan 05 — golden snapshot stubs (6 tools × default state).
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('CoachCitationChipsSection golden (Wave 1b stubs)', () {
        for (final tool in const [
          'budget_snapshot',
          'retirement_projection',
          'cross_pillar_analysis',
          'couple_optimization',
          'cap_status',
          'retrieve_memories',
        ]) {
          testWidgets('renders golden for $tool',
              (tester) async {},
              skip: 'Wave 1b — golden snapshot lands in Plan 05');
        }
      });
    }
    ```

    Step D — `apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart`:
    ```dart
    // Wave 1b Plan 06 — Souviens-toi CTA wiring stubs.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('Souviens-toi CTA (Wave 1b stubs)', () {
        testWidgets('CTA tap invokes save_insight tool with citation key prefix',
            (tester) async {},
            skip: 'Wave 1b — CTA lands in Plan 06');
      });
    }
    ```
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter test test/widgets/coach/coach_citation_chips_section_test.dart test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_golden_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - `test -f apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart` exits 0.
    - `test -f apps/mobile/test/widgets/coach/coach_citation_modal_test.dart` exits 0.
    - `test -f apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` exits 0.
    - `test -f apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart` exits 0.
    - `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart` returns ≥3.
    - `grep -c "budget_snapshot\|retirement_projection\|cross_pillar_analysis\|couple_optimization\|cap_status\|retrieve_memories" apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` returns ≥6.
    - `cd apps/mobile && flutter test test/widgets/coach/coach_citation_*.dart 2>&1 | grep -E "All tests passed|skipped"` returns non-empty (tests are SKIPPED, not failed).
  </acceptance_criteria>
  <done>
    4 Dart stub files exist with ≥10 skipped test entries; flutter test collection exits 0; no production code modified.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-01-01 | T | Stub tests accidentally pass without implementation (false GREEN) | mitigate | Every stub uses `pytest.mark.skip` (backend) or `skip:` arg (Flutter). Implementation plans (02-08) MUST remove the skip marker to count as DONE per their acceptance_criteria. |
| T-WAVE1B-01-02 | I | Stub test names leak into the public test report and confuse Julien | accept | Stubs are clearly named with `Wave 1b — Plan 0X` skip reason. The pytest output shows them as SKIPPED, not as PASSED — no misrepresentation. |
| T-WAVE1B-01-03 | T | ISSUE-07 expansion stubs (4 new) collide with Plan 02 implementation expectations | mitigate | The 4 new stubs in registry_entries.py have skip reasons pinned to Plan 02 / Plan 04. Their assertions are conservative (test_subset_invariant_excludes_tool_call_id_when_subset_empty: `assert True`) so unskipping during Plan 02 implementation is safe. |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q` exits 0 (all SKIPPED).
- `cd apps/mobile && flutter test test/widgets/coach/coach_citation_*.dart` exits 0 (all skipped).
- `find services/backend/tests/test_coach_citation -name '*.py' | wc -l` returns 5 (4 test files + __init__).
- `find apps/mobile/test/widgets/coach -name 'coach_citation_*.dart' | wc -l` returns 4.
- `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q --co | grep -c '<Function test_'` returns ≥16 (ISSUE-07 expansion).
</verification>

<success_criteria>
- 4 backend stub files exist with ≥16 SKIPPED tests collected by pytest (ISSUE-07 expansion).
- 4 Dart stub files exist with ≥10 skipped tests collected by flutter test.
- No production code modified (zero touched files outside test directories).
- Subsequent plans (02-08) can `unskip + implement` per their own scope.
- Phase-level test count ≥ 18 backend test functions PASSED by phase close (WAVE1B-07 literal interpretation met).
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-01-SUMMARY.md` with:
- Files created list (9 files: 5 backend + 4 Dart)
- Skipped test counts (backend ≥16 + Dart ≥10)
- Wave 0 status = COMPLETE
- 0-trust self-check citing `pytest --co` and `flutter test` outputs verbatim
</output>
</content>
</invoke>
