---
phase: mint-calc-engine-v1
plan: 10
wave: 2
title: W2 — CoachToolResponse V2 with latency_tier (Parallel Change V1→V2 per D-CE-19)
type: execute
depends_on: [01, 07]
files_modified:
  - services/backend/app/models/coach_tools/_response.py
  - services/backend/app/models/coach_tools/__init__.py
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_coach_tool_response_v2.py
  - services/backend/tests/test_coach_tool_response_migration.py
autonomous: true
requirements: [D-CE-04, D-CE-19, Concern-B]
estimated_duration: 5
must_haves:
  truths:
    - "`CoachToolResponseV2` envelope with `latency_tier: Literal['L1','L2','L3']` field shipped"
    - "V1 (current A3 envelope) still works; V2 is opt-in via per-tool emission"
    - "5 chip-emitters migrated from V1 → V2 (all carry `latency_tier='L1'`)"
    - "Parallel Change pattern documented: V1 retired in a SEPARATE follow-up PR (Plan 11 or post-phase)"
    - "Flutter Concern B doctrine documented: chip surface (L1) vs narrative loader surface (L2/L3) routing"
  artifacts:
    - path: services/backend/app/models/coach_tools/_response.py
      provides: "CoachToolOkV2 + CoachToolIncompleteV2 + CoachToolPolicyBlockedV2 + CoachToolResponseV2 with latency_tier — alongside V1"
      contains: "latency_tier"
    - path: services/backend/tests/test_coach_tool_response_migration.py
      provides: "Asserts V1 and V2 envelopes both work simultaneously (Parallel Change invariant)"
      min_lines: 60
  key_links:
    - from: services/backend/app/services/coach/coach_tools.py
      to: services/backend/app/models/coach_tools/_response.py
      via: "5 chip-emitters import CoachToolOkV2 and emit with latency_tier='L1'"
      pattern: "CoachToolOkV2|latency_tier"
---

<objective>
Concern B + D-CE-19 Parallel Change — extend `CoachToolResponse` envelope with `latency_tier: Literal["L1","L2","L3"]` field. Flutter routes responses to chip surface (L1, sub-500ms) vs narrative loader (L2-L3, 2-8s).

Tool Search Tool (Plan 09) adds 200-400ms on rare-intent first turn → MUST land in L2-L3 budget. Without the field, Flutter has no signal to differentiate surfaces.

Purpose: D-CE-04 envelope evolution + D-CE-19 Parallel Change pattern (V1 retire in separate PR, not this one). Migration cost ≤200 LOC ≤1 day per panel proof.

Output: V2 envelope alongside V1 + 5 chip-emitter migration + Parallel Change invariant test.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/models/coach_tools/_response.py
@services/backend/app/services/coach/coach_tools.py
@services/backend/app/services/coach/tool_registry/adapter.py
</context>

<interfaces>
<!-- V1 (existing A3, from Plan 01 cherry-pick or merge): -->
```python
CoachToolOk(status="ok", data={...})
CoachToolIncomplete(status="incomplete", missing_fields=[...], hint_fr="...")
CoachToolPolicyBlocked(status="policy_blocked", reason_code="...", message_fr="...")
CoachToolResponse = RootModel[Annotated[Union[Ok|Incomplete|PolicyBlocked], discriminator="status"]]
```

<!-- V2 (this plan, ADDITIVE NOT REPLACING): -->
```python
CoachToolOkV2(status="ok", data={...}, latency_tier="L1" | "L2" | "L3")
CoachToolIncompleteV2(status="incomplete", missing_fields=[...], hint_fr="...", latency_tier="L1")
CoachToolPolicyBlockedV2(status="policy_blocked", reason_code="...", message_fr="...", latency_tier="L1")
CoachToolResponseV2 = RootModel[Annotated[Union[OkV2|IncompleteV2|PolicyBlockedV2], discriminator="status"]]
```

<!-- Coach-side dispatcher MUST accept BOTH V1 and V2 (Parallel Change rule) for 1 release: -->
```python
# coach_chat.py union: Union[CoachToolResponse, CoachToolResponseV2]
```
</interfaces>

<tasks>

<task id="W2-04-01" type="auto" tdd="true">
  <name>Task 1: V2 envelope classes (additive to V1)</name>
  <files>services/backend/app/models/coach_tools/_response.py, services/backend/app/models/coach_tools/__init__.py, services/backend/tests/test_coach_tool_response_v2.py</files>
  <read_first>
    - services/backend/app/models/coach_tools/_response.py (current V1 envelope — DO NOT MODIFY V1 classes)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Concern B
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-19 Parallel Change pattern
    - services/backend/app/services/coach/tool_registry/adapter.py (LatencyTier type)
  </read_first>
  <behavior>
    - Test 1: `CoachToolOkV2(data={"foo": 1}, latency_tier="L1")` constructs.
    - Test 2: `CoachToolOkV2(data={"foo": 1})` raises ValidationError — `latency_tier` is REQUIRED.
    - Test 3: `CoachToolOkV2(data={...}, latency_tier="L4")` raises ValidationError — only L1/L2/L3.
    - Test 4: `CoachToolResponseV2.model_validate({"status": "ok", "data": {...}, "latencyTier": "L1"})` succeeds with camelCase alias.
    - Test 5: `model_dump(by_alias=True)` produces `latencyTier` (camelCase) NOT `latency_tier`.
    - Test 6: V1 still importable and constructible — `from app.models.coach_tools import CoachToolOk; CoachToolOk(data={}); print('V1 still works')`.
    - Test 7 (Parallel Change coexistence invariant — D-CE-19): V1 and V2 envelopes coexist in the same module + can be imported simultaneously. V1 stays a discriminated union on `status` ; V2 is a SEPARATE RootModel also discriminated on `status` but with the added `latencyTier` field on `CoachToolOkV2`. They are NOT unioned together (Pydantic can't discriminate between V1 and V2 by `status` alone since both use the same status values). The test asserts (a) `from app.models.coach_tools import CoachToolResponse, CoachToolResponseV2` succeeds without import error, (b) both envelopes round-trip independently (V1 dict → V1 model → V1 dict equal ; same for V2), (c) V2 with extra `latencyTier` field rejects when validated by V1 (or vice-versa via `extra="forbid"` boundary).
  </behavior>
  <action>
    APPEND to `services/backend/app/models/coach_tools/_response.py` (DO NOT modify V1 classes — Parallel Change rule):

    ```python
    # ─────── Parallel Change V2 (Phase mint-calc-engine-v1 W2-04) ───────
    # D-CE-19 Parallel Change pattern. V2 ships alongside V1.
    # V1 retired in a SEPARATE follow-up PR (Plan 11 or post-phase).
    # Migration budget: ≤200 LOC ≤1 day.

    from typing import Literal

    LatencyTier = Literal["L1", "L2", "L3"]


    class CoachToolOkV2(_Base):
        status: Literal["ok"] = "ok"
        data: dict[str, Any]
        latency_tier: LatencyTier = Field(..., description="L1=chip <500ms, L2-L3=narrative loader 2-8s")


    class CoachToolIncompleteV2(_Base):
        status: Literal["incomplete"] = "incomplete"
        missing_fields: list[str] = Field(..., min_length=1)
        hint_fr: str = Field(..., min_length=10)
        latency_tier: LatencyTier = Field(default="L1", description="Incomplete always L1 (sub-500ms 422 envelope).")

        @field_validator("missing_fields")
        @classmethod
        def _cap_missing_fields_v2(cls, v: list[str]) -> list[str]:
            if len(v) > _MAX_MISSING_FIELDS:
                raise ValueError(
                    f"missing_fields capped at {_MAX_MISSING_FIELDS} per D-A3-01"
                )
            return v


    class CoachToolPolicyBlockedV2(_Base):
        status: Literal["policy_blocked"] = "policy_blocked"
        reason_code: str
        message_fr: str
        latency_tier: LatencyTier = Field(default="L1")


    CoachToolResponseV2 = RootModel[
        Annotated[
            Union[CoachToolOkV2, CoachToolIncompleteV2, CoachToolPolicyBlockedV2],
            Field(discriminator="status"),
        ]
    ]
    ```

    Update `__init__.py` to ALSO export V2 (keep V1 exports):
    ```python
    from app.models.coach_tools._response import (
        CoachToolOk,
        CoachToolIncomplete,
        CoachToolPolicyBlocked,
        CoachToolResponse,
        # V2
        CoachToolOkV2,
        CoachToolIncompleteV2,
        CoachToolPolicyBlockedV2,
        CoachToolResponseV2,
        LatencyTier,
    )
    ```

    7 tests in `test_coach_tool_response_v2.py`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_tool_response_v2.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "class CoachToolOkV2" services/backend/app/models/coach_tools/_response.py` returns 1
    - `grep -c "latency_tier" services/backend/app/models/coach_tools/_response.py` returns ≥3
    - V1 classes UNCHANGED: `git diff services/backend/app/models/coach_tools/_response.py` shows only ADDITIONS (no V1 class modifications)
    - 7 V2 tests green
    - V1 tests still green: `cd services/backend && python3 -m pytest tests/ -q -k "test_coach_tool_response or test_a3_envelope" 2>&1 | tail -3`
  </acceptance_criteria>
  <done>V2 envelope shipped alongside V1</done>
</task>

<task id="W2-04-02" type="auto" tdd="true">
  <name>Task 2: Migrate 5 chip-emitters from V1 → V2 (latency_tier="L1")</name>
  <files>services/backend/app/services/coach/coach_tools.py</files>
  <read_first>
    - services/backend/app/services/coach/coach_tools.py:637-722 (5 chip-emitter implementations)
    - services/backend/app/models/coach_tools/_response.py (V1 + V2 envelopes)
    - services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py (_ALWAYS_ON_TOOLS set)
  </read_first>
  <behavior>
    - Test 1: Each of 5 chip-emitters (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`) returns a `CoachToolOkV2` (or `CoachToolIncompleteV2`) with `latency_tier="L1"`.
    - Test 2: Return values json-serialize with `latencyTier` key (camelCase).
    - Test 3: Existing tool contract tests (`test_get_budget_status` etc., from Wave 1a Plan 03-04) still pass — V2 envelope is shape-additive, existing assertions on `data["..."]` still work.
  </behavior>
  <action>
    For each of 5 chip-emitters in `coach_tools.py`, change return type:

    ```python
    # BEFORE
    from app.models.coach_tools import CoachToolOk
    def get_budget_status(profile, ...) -> dict:
        return CoachToolOk(data={"monthly_surplus": 1200, ...}).model_dump(by_alias=True)

    # AFTER
    from app.models.coach_tools import CoachToolOkV2
    def get_budget_status(profile, ...) -> dict:
        return CoachToolOkV2(
            data={"monthly_surplus": 1200, ...},
            latency_tier="L1",
        ).model_dump(by_alias=True)
    ```

    Same for `CoachToolIncomplete → CoachToolIncompleteV2` (with `latency_tier="L1"` as default).

    DO NOT touch the `data` content — that stays unchanged. Only the wrapper class + the new `latency_tier="L1"` literal.

    Coach dispatcher in `coach_chat.py` MUST accept BOTH envelopes (Union[CoachToolResponse, CoachToolResponseV2]) for at least 1 release. Surgical patch:
    ```python
    # coach_chat.py — dispatcher accepts both
    Envelope = Union[CoachToolResponse, CoachToolResponseV2]
    ```
    Find where the dispatcher validates the envelope (likely in `_execute_internal_tool`) and update the type hint.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_tools/ -q -x 2>&1 | tail -3 ; cd services/backend && python3 -m pytest tests/test_coach_tool_response_v2.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "CoachToolOkV2\|CoachToolIncompleteV2" services/backend/app/services/coach/coach_tools.py` returns ≥10 (5 chip-emitters × ≥2 envelope variants)
    - `grep -c 'latency_tier="L1"' services/backend/app/services/coach/coach_tools.py` returns ≥5
    - All 5 chip-emitter contract tests (Wave 1a Plans 03-04 legacy) still pass
    - 3 V2 migration tests green
    - V1 still importable: `python3 -c "from app.models.coach_tools import CoachToolOk; CoachToolOk(data={})"` exits 0
  </acceptance_criteria>
  <done>5 chip-emitters on V2, dispatcher accepts both</done>
</task>

<task id="W2-04-03" type="auto" tdd="true">
  <name>Task 3: Parallel Change invariant test</name>
  <files>services/backend/tests/test_coach_tool_response_migration.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-19
    - .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md (existing A3 envelope tests)
  </read_first>
  <behavior>
    - Test 1: Both V1 and V2 are exposed via `app.models.coach_tools`.
    - Test 2: A coach dispatcher Union type can accept both `CoachToolOk` (V1) and `CoachToolOkV2` (V2) payloads as JSON envelopes.
    - Test 3: Backwards-compat — existing test fixtures using V1 envelope still parse correctly.
    - Test 4: A live API endpoint (pick `/api/v1/coach/chat` or one of the chip-emitter contract endpoints) returns V2 envelope when called.
    - Test 5: Migration count tracker — `assert <count of files using V1> + <count of files using V2> > 0` (proof that V2 is actually used somewhere, V1 still allowed).
  </behavior>
  <action>
    ```python
    # tests/test_coach_tool_response_migration.py
    """D-CE-19 Parallel Change invariant: V1 and V2 coexist for 1+ release."""
    import pytest

    from app.models.coach_tools import (
        CoachToolOk, CoachToolIncomplete, CoachToolResponse,
        CoachToolOkV2, CoachToolIncompleteV2, CoachToolResponseV2,
    )


    def test_both_envelopes_exported():
        # V1 exports
        assert CoachToolOk is not None
        # V2 exports
        assert CoachToolOkV2 is not None


    def test_v1_envelope_still_parses():
        ok = CoachToolOk(data={"foo": 1})
        assert ok.status == "ok"


    def test_v2_envelope_has_latency_tier():
        okv2 = CoachToolOkV2(data={"foo": 1}, latency_tier="L1")
        assert okv2.latency_tier == "L1"


    def test_v2_camelcase_serialization():
        okv2 = CoachToolOkV2(data={"x": 1}, latency_tier="L2")
        dumped = okv2.model_dump(by_alias=True)
        assert "latencyTier" in dumped


    def test_dispatcher_union_accepts_both():
        # Simulate Union[V1, V2] resolution
        from typing import Union
        Envelope = Union[CoachToolResponse, CoachToolResponseV2]
        # V1 JSON
        from app.models.coach_tools import CoachToolResponse
        v1 = CoachToolResponse.model_validate({"status": "ok", "data": {"x": 1}})
        assert v1.root.status == "ok"
        # V2 JSON
        v2 = CoachToolResponseV2.model_validate({"status": "ok", "data": {"x": 1}, "latencyTier": "L1"})
        assert v2.root.latency_tier == "L1"
    ```
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_tool_response_migration.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 5 tests green
    - Parallel Change invariant proven: both V1 and V2 coexist functionally
  </acceptance_criteria>
  <done>Parallel Change green</done>
</task>

<task id="W2-04-99" type="auto" tdd="false">
  <name>Task 4: Full suite + Flutter doctrine note + engram</name>
  <files>(verification + engram + doc)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Concern B + D-CE-06 (Flutter UX-only)
  </read_first>
  <action>
    Add Flutter-side doctrine note in this plan's SUMMARY (D-CE-06 Flutter UX-only — backend ships the field, Flutter implementation is later):

    > **Flutter Concern B routing doctrine** (deferred to a follow-up Flutter plan or W4):
    > - V2 envelope contains `latencyTier: "L1" | "L2" | "L3"`.
    > - `latencyTier == "L1"` → render as chip in `CoachCitationChipsSection` (sub-500ms).
    > - `latencyTier in ("L2", "L3")` → render with `MintNarrativeLoader` 2-8s.
    > - Existing chip emitters (V1) are also routed L1 (default for backwards-compat).
    > - Flutter consumer doc: `apps/mobile/lib/services/coach/coach_response_router.dart`.

    Engram save:
    - `topic_key: calc_engine:w2:coach_tool_response_v2_latency_tier`
    - `type: architecture`
    - `prior_finding_refs: [Plan 01 obs (A3 envelope), Plan 07 obs (adapter latency_tier method), #103 panel synthesis Concern B]`
    - Content: « CoachToolResponse V2 envelope shipped with `latency_tier`. Parallel Change pattern: V1 + V2 coexist. 5 chip-emitters migrated to V2. Coach dispatcher Union[V1, V2]. V1 retirement deferred to follow-up PR (≤200 LOC). Flutter routing doctrine documented for downstream consumer plan. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
    - Flutter doctrine note in SUMMARY
  </acceptance_criteria>
  <done>W2-04 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-10-01 | Tampering | latency_tier client manipulation | accept | latency_tier is SERVER-EMITTED, never client-input. Server controls the value per Concern B routing logic. |
| T-mint-calc-10-02 | Spoofing | V1 envelope masquerading as V2 | accept | Both envelopes are server-emitted ; no client can spoof either. Tests 4-5 prove coexistence. |
| T-mint-calc-10-03 | DoS | new field bloat | accept | `latency_tier` adds 2-3 bytes per response. Negligible. |
| T-mint-calc-10-04 | LSFin compliance | latency_tier semantics | accept | The field is a technical UX hint, not a financial claim. No LSFin surface change. |
</threat_model>

<success_criteria>
- V2 envelope shipped alongside V1 (Parallel Change green)
- 5 chip-emitters migrated, full suite green
- Migration budget honored: ≤200 LOC net diff (verify: `git diff --stat`)
- Engram observation persisted
- Flutter routing doctrine in SUMMARY for downstream consumer plan
</success_criteria>

<risks>
- **V1 retirement is OUT OF SCOPE for Plan 10.** Per D-CE-19 Parallel Change: V1 retires in a SEPARATE PR (Plan 11 or post-phase). DO NOT delete V1 in this plan — that would defeat the migration safety.
- **Coach dispatcher Union may not type-check.** Pydantic Union[RootModel, RootModel] works but may need careful discriminator. Test 5 of Task 3 explicitly verifies both envelopes parse via Union.
- **Flutter implementation is NOT in this plan.** Flutter v2 router consumer is in a future Flutter plan (post-W4). Track as TODO. Plan W4-03 (parity lint) is the closest pending Flutter touchpoint.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-10-w2-coach-tool-response-v2-SUMMARY.md` including Parallel Change diff stats + Flutter doctrine + V1 retirement TODO.
</output>
