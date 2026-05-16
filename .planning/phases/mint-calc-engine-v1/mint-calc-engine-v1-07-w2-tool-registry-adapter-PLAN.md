---
phase: mint-calc-engine-v1
plan: 07
wave: 2
title: W2 — ToolRegistryAdapter Protocol + 3 concrete adapters (D-CE-01)
type: execute
depends_on: [01, 05]
files_modified:
  - services/backend/app/services/coach/tool_registry/__init__.py
  - services/backend/app/services/coach/tool_registry/adapter.py
  - services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
  - services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py
  - services/backend/app/services/coach/tool_registry/manual_subset_adapter.py
  - services/backend/app/services/coach/tool_registry/factory.py
  - services/backend/tests/test_tool_registry_adapter.py
  - services/backend/tests/test_anthropic_defer_loading_adapter.py
  - services/backend/tests/test_skill_bundle_only_adapter.py
  - services/backend/tests/test_manual_subset_adapter.py
  - services/backend/tests/test_tool_registry_factory.py
autonomous: true
requirements: [D-CE-01, D-CE-02]
estimated_duration: 5
must_haves:
  truths:
    - "ToolRegistryAdapter Protocol defined with `register_tools(turn_context) -> list[ToolDefinition]` + `latency_tier(tool_name) -> Literal['L1','L2','L3']` (vendor-agnostic abstraction)"
    - "AnthropicDeferLoadingAdapter registers 5 chip-emitters with defer_loading=false (always-on L1) + 52 long-tail with defer_loading=true + tool_search_tool_bm25_20251119 declaration"
    - "SkillBundleOnlyAdapter falls back to bundle-compiled prompts (all 57 registered, no Tool Search)"
    - "ManualSubsetAdapter filters per intent via existing `_TOOL_ELIGIBLE_INTENTS` (Wave 1c-A2 heritage)"
    - "factory.py reads `TOOL_REGISTRY_ADAPTER` env var (default `anthropic_defer_loading`) and instantiates the right adapter"
  artifacts:
    - path: services/backend/app/services/coach/tool_registry/adapter.py
      provides: "Protocol + ToolDefinition TypedDict"
      min_lines: 40
    - path: services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
      provides: "5 always-on chip-emitters + 52 deferred + tool_search_tool_bm25_20251119"
      min_lines: 80
  key_links:
    - from: services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
      to: services/backend/app/calculators/_registry.py
      via: "REGISTRY for 52 long-tail tool definitions"
      pattern: "from app.calculators import REGISTRY"
    - from: services/backend/app/services/coach/tool_registry/factory.py
      to: env var TOOL_REGISTRY_ADAPTER
      via: "os.getenv selector"
      pattern: "TOOL_REGISTRY_ADAPTER"
---

<objective>
Ship the vendor-agnostic `ToolRegistryAdapter` Protocol + 3 concrete adapters per D-CE-01. Mitigates Anthropic-only vendor lock-in concern (D-CE-01 founder refinement 2026-05-16). Calculator definitions stay provider-agnostic ; the LLM provider is interchangeable plumbing.

Purpose: D-CE-01. Day-1 abstraction with 3 adapters so future Anthropic deprecation / provider pivot has minimal code surface to swap.

Output: 1 Protocol + 3 adapter implementations + 1 factory + 5 test files.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/calculators/_registry.py
@services/backend/app/services/coach/coach_tools.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/bundle_compiler.py
</context>

<interfaces>
<!-- Protocol + adapter shapes from CONTEXT D-CE-01 + RESEARCH §Q-A -->

```python
# adapter.py
from typing import Protocol, Literal, TypedDict, Any

class ToolDefinition(TypedDict, total=False):
    name: str
    description: str
    input_schema: dict[str, Any]
    defer_loading: bool   # Anthropic-specific, ignored by other adapters
    type: str              # for tool_search_tool_bm25_20251119

class ToolRegistryAdapter(Protocol):
    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]: ...
    def latency_tier(self, tool_name: str) -> Literal["L1", "L2", "L3"]: ...
```

Anthropic adapter request shape per RESEARCH §Q-A lines 160-202:
```python
tools = [
    # 5 chip-emitters: defer_loading: false
    {"name": "get_budget_status", "description": "...", "input_schema": {...}},
    # ... 4 more
    # 52 long-tail: defer_loading: true
    {"name": "divorce_simulator", "description": "...", "input_schema": {...}, "defer_loading": True},
    # ... 51 more
    # Tool Search itself:
    {"type": "tool_search_tool_bm25_20251119", "name": "tool_search_tool_bm25"},
]
# header: anthropic-beta = tool-search-tool-2025-10-19
```

L1 = 5 always-on chip-emitters: `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization` (per CONTEXT D-CE-01 + W0 audit row 46-50).
L2 = main-narrative tools (e.g. simulators).
L3 = rare long-tail (e.g. quasi-resident edge cases).
</interfaces>

<tasks>

<task id="W2-01-01" type="auto" tdd="true">
  <name>Task 1: Protocol + ToolDefinition contract</name>
  <files>services/backend/app/services/coach/tool_registry/__init__.py, services/backend/app/services/coach/tool_registry/adapter.py, services/backend/tests/test_tool_registry_adapter.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-01
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-A
    - services/backend/app/services/coach/__init__.py (current exports pattern)
  </read_first>
  <behavior>
    - Test 1: `from app.services.coach.tool_registry import ToolRegistryAdapter, ToolDefinition, LatencyTier` succeeds.
    - Test 2: A class implementing both methods satisfies the Protocol structurally (use `isinstance(obj, ToolRegistryAdapter)` — Pydantic Protocol uses `runtime_checkable`).
    - Test 3: `ToolDefinition` accepts the Anthropic-shape kwargs (`defer_loading` optional, `type` optional for tool_search declaration).
  </behavior>
  <action>
    Create `services/backend/app/services/coach/tool_registry/__init__.py`:
    ```python
    """Phase mint-calc-engine-v1 W2 — D-CE-01 vendor-agnostic tool registry."""
    from app.services.coach.tool_registry.adapter import (
        ToolRegistryAdapter,
        ToolDefinition,
        LatencyTier,
    )
    __all__ = ["ToolRegistryAdapter", "ToolDefinition", "LatencyTier"]
    ```

    Create `adapter.py`:
    ```python
    from typing import Any, Literal, Protocol, TypedDict, runtime_checkable

    LatencyTier = Literal["L1", "L2", "L3"]

    class ToolDefinition(TypedDict, total=False):
        name: str
        description: str
        input_schema: dict[str, Any]
        defer_loading: bool   # Anthropic-specific
        type: str              # tool_search declaration

    @runtime_checkable
    class ToolRegistryAdapter(Protocol):
        """Vendor-agnostic abstraction. Implementations: Anthropic / SkillBundle / Manual."""

        def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
            """Return the tools array for the current turn."""
            ...

        def latency_tier(self, tool_name: str) -> LatencyTier:
            """Inform Flutter rendering surface (L1 chip / L2-L3 narrative loader)."""
            ...
    ```

    Write 3 tests in `test_tool_registry_adapter.py`. Use a minimal `class _Stub: def register_tools(self, ctx): return []; def latency_tier(self, name): return "L1"` to verify Protocol satisfaction.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_tool_registry_adapter.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - Module importable: `python3 -c "from app.services.coach.tool_registry import ToolRegistryAdapter, ToolDefinition, LatencyTier; print('OK')"`
    - `grep -c "@runtime_checkable" services/backend/app/services/coach/tool_registry/adapter.py` returns 1
    - 3 tests green
  </acceptance_criteria>
  <done>Protocol shipped</done>
</task>

<task id="W2-01-02" type="auto" tdd="true">
  <name>Task 2: AnthropicDeferLoadingAdapter (DEFAULT)</name>
  <files>services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py, services/backend/tests/test_anthropic_defer_loading_adapter.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-A (Anthropic Tool Search shape lines 160-247)
    - services/backend/app/services/coach/coach_tools.py:637-722 (5 chip-emitter descriptions)
    - services/backend/app/calculators/_registry.py (Plan 05 — 52 long-tail metadata)
  </read_first>
  <behavior>
    - Test 1: `adapter.register_tools({})` returns list with ≥6 entries (5 chip-emitters + ≥1 long-tail + tool_search_tool_bm25).
    - Test 2: 5 chip-emitters have `defer_loading=False` (or key absent — Anthropic default False).
    - Test 3: All non-chip-emitter calc tools have `defer_loading=True`.
    - Test 4: List contains exactly 1 entry with `type="tool_search_tool_bm25_20251119"`.
    - Test 5: `latency_tier("get_budget_status")` returns `"L1"`. `latency_tier("divorce_simulator")` returns `"L2"` (or `"L3"` — magic-comment driven). Unknown tool name returns `"L2"` (default).
  </behavior>
  <action>
    ```python
    # anthropic_defer_loading_adapter.py
    from typing import Any
    from app.calculators import REGISTRY
    from app.services.coach.tool_registry.adapter import ToolDefinition, LatencyTier

    _ALWAYS_ON_TOOLS = frozenset([
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    ])

    _TOOL_SEARCH_DECLARATION: ToolDefinition = {
        "type": "tool_search_tool_bm25_20251119",
        "name": "tool_search_tool_bm25",
    }

    _BETA_HEADER = "tool-search-tool-2025-10-19"

    class AnthropicDeferLoadingAdapter:
        def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
            tools: list[ToolDefinition] = []
            # Always-on chip-emitters
            for name in _ALWAYS_ON_TOOLS:
                tools.append(self._chip_emitter_definition(name))
            # Long-tail deferred
            for name, meta in REGISTRY.items():
                if name in _ALWAYS_ON_TOOLS:
                    continue
                tools.append({
                    "name": name,
                    "description": self._description_for(meta),
                    "input_schema": self._input_schema_for(meta),
                    "defer_loading": True,
                })
            tools.append(_TOOL_SEARCH_DECLARATION)
            return tools

        def latency_tier(self, tool_name: str) -> LatencyTier:
            if tool_name in _ALWAYS_ON_TOOLS:
                return "L1"
            meta = REGISTRY.get(tool_name)
            if meta is None:
                return "L2"
            return meta.get("output_type", "L2") if meta.get("output_type") in ("L1", "L2", "L3") else "L2"

        def _chip_emitter_definition(self, name: str) -> ToolDefinition:
            # Source descriptions from coach_tools.py:637-722
            ...

        def _description_for(self, meta) -> str: ...
        def _input_schema_for(self, meta) -> dict: ...

        @property
        def beta_header(self) -> str:
            return _BETA_HEADER
    ```

    Tests in `test_anthropic_defer_loading_adapter.py` — 5 tests from `<behavior>`.

    Description sourcing: read existing descriptions from `services/backend/app/services/coach/coach_tools.py:637-722` for the 5 chip-emitters. For the 52 long-tail, use the registry's `name` + a templated FR description (« <name>: <life_events_served> ») as v1 — Plan 09 (W2-03 description rubric) rewrites these to LSFin-quality FR keyword discipline.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_anthropic_defer_loading_adapter.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "tool_search_tool_bm25_20251119" services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` returns ≥1
    - `grep -c "_ALWAYS_ON_TOOLS" services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` returns ≥1
    - 5 tests green
  </acceptance_criteria>
  <done>Anthropic adapter shipped</done>
</task>

<task id="W2-01-03" type="auto" tdd="true">
  <name>Task 3: SkillBundleOnlyAdapter (FALLBACK)</name>
  <files>services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py, services/backend/tests/test_skill_bundle_only_adapter.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-01 fallback
    - services/backend/app/services/coach/bundle_compiler.py (existing compile_bundles entrypoint)
  </read_first>
  <behavior>
    - Test 1: `adapter.register_tools({"intents": ["retirement"]})` returns ALL 57 calc tools (no defer_loading, no Tool Search Tool — accepts context-bloat per D-CE-01 fallback rationale).
    - Test 2: No `defer_loading=True` keys in returned list.
    - Test 3: No `tool_search_tool_bm25` entry.
    - Test 4: `latency_tier` returns same as Anthropic adapter (consistent across adapters).
  </behavior>
  <action>
    ```python
    # skill_bundle_only_adapter.py
    from typing import Any
    from app.calculators import REGISTRY
    from app.services.coach.tool_registry.adapter import ToolDefinition, LatencyTier
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import _ALWAYS_ON_TOOLS

    class SkillBundleOnlyAdapter:
        """Fallback adapter — all 57 always-on via bundle-compiled prompts."""

        def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
            tools: list[ToolDefinition] = []
            for name, meta in REGISTRY.items():
                tools.append({
                    "name": name,
                    "description": meta.get("description", name),
                    "input_schema": {},
                })
            return tools

        def latency_tier(self, tool_name: str) -> LatencyTier:
            if tool_name in _ALWAYS_ON_TOOLS:
                return "L1"
            meta = REGISTRY.get(tool_name)
            return meta.get("output_type", "L2") if meta else "L2"
    ```

    4 tests in `test_skill_bundle_only_adapter.py`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_skill_bundle_only_adapter.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
    - `grep -c "defer_loading" services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py` returns 0 (no defer_loading on this adapter)
    - `grep -c "tool_search_tool_bm25" services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py` returns 0
  </acceptance_criteria>
  <done>Fallback adapter shipped</done>
</task>

<task id="W2-01-04" type="auto" tdd="true">
  <name>Task 4: ManualSubsetAdapter (BACKUP)</name>
  <files>services/backend/app/services/coach/tool_registry/manual_subset_adapter.py, services/backend/tests/test_manual_subset_adapter.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-01 backup
    - services/backend/app/api/v1/endpoints/coach_chat.py:1564-1573 (`_TOOL_ELIGIBLE_INTENTS` — Wave 1c-A2 heritage)
    - services/backend/app/api/v1/endpoints/coach_chat.py:944-963 (`_classify_user_intent`)
  </read_first>
  <behavior>
    - Test 1: `turn_context={"user_intents": ["retirement"]}` returns only the tools allowlisted for `retirement` intent (subset).
    - Test 2: `turn_context={"user_intents": []}` returns ONLY the 5 chip-emitters (defaults).
    - Test 3: `latency_tier` consistent with other adapters.
  </behavior>
  <action>
    ```python
    # manual_subset_adapter.py
    from typing import Any
    from app.calculators import REGISTRY
    from app.services.coach.tool_registry.adapter import ToolDefinition, LatencyTier
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import _ALWAYS_ON_TOOLS

    # Per-intent tool allowlist — Wave 1c-A2 heritage extended.
    _PER_INTENT_TOOLS: dict[str, frozenset[str]] = {
        "retirement": frozenset({"avs_estimation", "lpp_projector", "rachat_echelonne"}),
        "taxes":      frozenset({"wealth_tax", "succession_simulator", "fiscal_estimate"}),
        "housing":    frozenset({"affordability", "saron_vs_fixed", "epl_combined"}),
        "debt":       frozenset({"debt_ratio", "repayment_service"}),
        "family":     frozenset({"naissance_service", "mariage", "divorce_simulator"}),
        "career":     frozenset({"unemployment_calculator", "expat_service"}),
    }

    class ManualSubsetAdapter:
        def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
            intents = turn_context.get("user_intents", [])
            # Always include chip-emitters
            included: set[str] = set(_ALWAYS_ON_TOOLS)
            for intent in intents:
                included.update(_PER_INTENT_TOOLS.get(intent, set()))
            return [{"name": n, "description": REGISTRY.get(n, {}).get("description", n), "input_schema": {}}
                    for n in included if n in REGISTRY or n in _ALWAYS_ON_TOOLS]

        def latency_tier(self, tool_name: str) -> LatencyTier:
            if tool_name in _ALWAYS_ON_TOOLS:
                return "L1"
            meta = REGISTRY.get(tool_name)
            return meta.get("output_type", "L2") if meta else "L2"
    ```

    3 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_manual_subset_adapter.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 3 tests green
    - `grep -c "_PER_INTENT_TOOLS" services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` returns ≥1
  </acceptance_criteria>
  <done>Backup adapter shipped</done>
</task>

<task id="W2-01-05" type="auto" tdd="true">
  <name>Task 5: factory.py env-flag selector + Sentry init</name>
  <files>services/backend/app/services/coach/tool_registry/factory.py, services/backend/tests/test_tool_registry_factory.py</files>
  <read_first>
    - services/backend/app/services/coach/tool_registry/{adapter.py,anthropic_defer_loading_adapter.py,skill_bundle_only_adapter.py,manual_subset_adapter.py}
    - services/backend/app/core/config.py (env var pattern)
  </read_first>
  <behavior>
    - Test 1: `get_tool_registry_adapter()` with `TOOL_REGISTRY_ADAPTER` unset returns `AnthropicDeferLoadingAdapter` instance (default).
    - Test 2: `TOOL_REGISTRY_ADAPTER=skill_bundle_only` returns `SkillBundleOnlyAdapter`.
    - Test 3: `TOOL_REGISTRY_ADAPTER=manual_subset` returns `ManualSubsetAdapter`.
    - Test 4: Invalid value falls back to default + Sentry breadcrumb (or warning log).
  </behavior>
  <action>
    ```python
    # factory.py
    import os
    import logging
    from app.services.coach.tool_registry.adapter import ToolRegistryAdapter
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import AnthropicDeferLoadingAdapter
    from app.services.coach.tool_registry.skill_bundle_only_adapter import SkillBundleOnlyAdapter
    from app.services.coach.tool_registry.manual_subset_adapter import ManualSubsetAdapter

    _DEFAULT = "anthropic_defer_loading"
    _logger = logging.getLogger(__name__)

    _REGISTRY: dict[str, type] = {
        "anthropic_defer_loading": AnthropicDeferLoadingAdapter,
        "skill_bundle_only":       SkillBundleOnlyAdapter,
        "manual_subset":           ManualSubsetAdapter,
    }


    def get_tool_registry_adapter() -> ToolRegistryAdapter:
        name = os.getenv("TOOL_REGISTRY_ADAPTER", _DEFAULT)
        cls = _REGISTRY.get(name)
        if cls is None:
            _logger.warning(
                f"Unknown TOOL_REGISTRY_ADAPTER={name!r} ; falling back to {_DEFAULT}"
            )
            cls = _REGISTRY[_DEFAULT]
        return cls()
    ```

    4 tests in `test_tool_registry_factory.py` using `monkeypatch.setenv`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_tool_registry_factory.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
    - `python3 -c "from app.services.coach.tool_registry.factory import get_tool_registry_adapter; a = get_tool_registry_adapter(); print(type(a).__name__)"` prints `AnthropicDeferLoadingAdapter`
  </acceptance_criteria>
  <done>Factory selector live with sane fallback</done>
</task>

<task id="W2-01-99" type="auto" tdd="false">
  <name>Task 6: Full suite + engram + W2-04 dependency note</name>
  <files>(verification + engram)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract
  </read_first>
  <action>
    Full suite + lints. Engram save:
    - `topic_key: calc_engine:w2:tool_registry_adapter_protocol`
    - `type: architecture`
    - `prior_finding_refs: [Plan 01 obs, Plan 05 registry obs, panel synthesis #103, founder refinement obs #103]`
    - Content: « 3-adapter pattern shipped : Anthropic defer_loading default + SkillBundleOnly fallback + ManualSubset backup. Env-flag `TOOL_REGISTRY_ADAPTER` selects. Tool Search Tool beta header `tool-search-tool-2025-10-19` declared. Vendor lock-in mitigation ready. Coach orchestrator integration in W2-04 + W2-03 description rewrites + W2-05 staging pilot. »

    Note for Plan 10 (W2-04): the `latency_tier` field on `CoachToolResponse` envelope V2 is the consumer for `ToolRegistryAdapter.latency_tier()`. Wire when Plan 10 lands.

    NOTE: this plan does NOT wire the adapter into `coach_chat.py` yet — that's Plan 10 (W2-04 latency_tier V2 envelope) + the narrator system-prompt builder integration. W2-01 ships the ABSTRACTION + 3 implementations, not the wire-up.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_tool_registry_adapter.py tests/test_anthropic_defer_loading_adapter.py tests/test_skill_bundle_only_adapter.py tests/test_manual_subset_adapter.py tests/test_tool_registry_factory.py -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - All 5 adapter test files green
    - Full backend suite green (no regression)
    - Engram observation persisted
  </acceptance_criteria>
  <done>3-adapter pattern + factory shipped. Ready for Plan 10 wire-up + W2-03 rewrites.</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-07-01 | Information disclosure | tool description text | mitigate | Descriptions are public-ish (visible in Anthropic responses). FR keyword discipline (Plan 09 rewrite) avoids leak of internal naming. No user data in tool registry. |
| T-mint-calc-07-02 | Tampering | env var manipulation | accept | `TOOL_REGISTRY_ADAPTER` is operator-controlled via Railway env. Same trust level as other env vars. Invalid value falls back to default. |
| T-mint-calc-07-03 | DoS | 57 tools blown into prompt | mitigate | DefaultAnthropicAdapter uses `defer_loading: true` for 52 — only 5 chip-emitters + tool_search_tool_bm25 are always present. SkillBundleOnly adapter accepts the bloat as explicit fallback tradeoff. |
| T-mint-calc-07-04 | Spoofing | adapter swap mid-session | accept | Adapter is selected at factory-instantiation time (per-process). Operator-controlled. No per-user override. |
| T-mint-calc-07-05 | LSFin | tool descriptions | mitigate | Plan 09 rewrites all descriptions per Concern A rubric. v1 descriptions in Plan 07 are templated (`<name>: <life_events>`), banned-terms lint runs on touched files. |
</threat_model>

<success_criteria>
- 3 adapter implementations + Protocol + factory
- 5 test files, all green
- `TOOL_REGISTRY_ADAPTER` env var documented in operator notes
- Engram observation with prior_finding_refs to Plan 01, Plan 05, #103
</success_criteria>

<risks>
- **Adapter not wired into `coach_chat.py` yet.** Plan 10 + Plan 09 are the consumers. W2-01 is the SCAFFOLDING. Documented explicitly.
- **Description quality.** v1 templated descriptions (`<name>: <life_events>`) may NOT surface in Tool Search top-3 for FR queries. That's what Plan 09 (Concern A rewrites) fixes. Acceptable for Plan 07 ship.
- **Anthropic Tool Search beta header.** Hardcoded as `tool-search-tool-2025-10-19`. If Anthropic ships v2026-XX, only `AnthropicDeferLoadingAdapter.beta_header` property needs update. Other adapters are immune.
- **Cache invalidation.** Defer-loaded tools are cache-preserving per RESEARCH §Q-A. No prompt-cache bust call needed in adapter.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-07-w2-tool-registry-adapter-SUMMARY.md`. Include:
- Engram obs_id
- Adapter implementation count
- Wire-up dependency: Plan 10 (W2-04 latency_tier envelope V2)
- Plan 09 dependency: Concern A description rewrites needed before staging pilot
</output>
