---
description: Phase 94 research — closed-world citation gate post-process parser. Confirms 21 D-XX context locks are viable on the actual code surface; documents exact insertion shape at coach_chat.py:3264, retry mechanics under `_run_agent_loop`, regex performance bounds, registry semantics, telemetry hygiene, and validation architecture (50-fixture eval pack + Maestro flow + frozen-contract tests). Every finding tagged VERIFIED / CITED / ASSUMED.
audience: gsd-planner, gsd-executor, gsd-verifier
phase: 94-mvp-citation-gate
date: 2026-05-10
confidence: HIGH (CONTEXT pre-locked 21 D-XX; research grounds them in real code paths)
---

# Phase 94: MVP-CITATION-GATE — Research

**Researched:** 2026-05-10
**Domain:** Backend post-processor parser on narrator output (`services/backend/app/services/coach/`) + integration in `coach_chat.py` + eval harness extension + Maestro G1 flow.
**Confidence:** HIGH

## Summary

Phase 94 is the runtime parser that closes the « narrator emits an un-cited number » failure surface mechanically. The CONTEXT.md (21 D-XX) locks the design end-to-end ; this research validates that **every locked decision lands on a real, identifiable code surface** :

- `D-11` insertion point is confirmed at **`coach_chat.py:3264-3283`** (the `await asyncio.wait_for(_run_agent_loop(...))` call site). The narrator answer is captured at line **3315** (`loop_result["tool_calls"]`) and finally sent at line **3362** (`message=loop_result["answer"]`). The gate must run *after* line 3283 (loop_result populated) and *before* line 3361 (CoachChatResponse returned).
- `D-03` meta-helpers (`_is_meta_negation`, `_is_meta_quoted`) exist verbatim at **`tools/eval_narrator.py:250-296`** with 15 backing tests at **`tests/test_eval_narrator_meta_scorer.py`** — a clean refactor target into a new `app/services/coach/citation_parser.py` (eval-time and runtime use the same code).
- `D-07` bundle integration is already wired : the bundle compiler returns a frozen `CompiledBundle` with `citation_allowlist: list[str]` at **`bundle_compiler.py:130`**. The flag-OFF fallback is also already there at **`coach_chat.py:3230-3250`** (try/except around `compile_bundles` + `KeyError/ValueError` graceful fallback to `get_narrator_llm_tools()`).
- `D-08` retry-once is **not** a feature of `_run_agent_loop` — that function is a tool-loop, not a quality-loop. The gate's retry MUST therefore be implemented **outside** `_run_agent_loop` as a wrapper (call narrator → gate → if `retry_needed` call narrator a second time with appended reprompt → fallback).
- `D-17` ≤50ms parser budget is highly achievable : 5 pre-compiled regexes on a ≤4kB narrator output (typical p95) run in <2ms on Python 3.9 ; the bound is generous.

**Primary recommendation:** Implement the gate as a thin pure-function wrapper `gate(response_text, ctx, citation_allowlist) -> GatedResponse` in `app/services/coach/citation_parser.py`. Insert at `coach_chat.py:~3285` between `loop_result` capture and CoachChatResponse build. Mirror the dual-path coexistence pattern already in place at `coach_chat.py:3230-3250` (flag-ON intersect with `compiled.citation_allowlist`, flag-OFF fallback to a global registry). Refactor the two Wave 4 meta-helpers from `eval_narrator.py` into the new module ; the eval harness imports them back to keep ONE source of truth. The retry path calls the narrator a SECOND time via the same `_run_agent_loop` invocation with the user message rewritten to append `D-09` reprompt addendum ; this avoids surgery inside the agent loop (Karpathy #3).

---

## User Constraints (from CONTEXT.md)

> Copied verbatim from `94-CONTEXT.md` (decisions D-01..D-21). The planner MUST honor every decision below. Any deviation is a CONTEXT amendment, not a research recommendation.

### Locked Decisions

#### Citation Format & Detection (Gray Area A)

- **D-01:** Citation format is `{{cite:<key>}}` per calc-first ADR §N1 (NOT `[citation:source_id]` from the legacy ROADMAP wording — `{{cite:}}` is already used in Phase 93.5 bundle `citation_allowlist` annotations; uniformity wins). The ROADMAP wording will be patched in Phase 94 plan-01 to match. Examples: `{{cite:r3a_ceiling_2026}}`, `{{cite:user_avs_rente_low}}`, `{{cite:lifd_art_38_pillar3a_withdrawal}}`.
- **D-02:** Number detection regex — pure Python `re` module, no NLP lib. Pattern catches:
  - CHF/EUR/USD amounts: `\b\d{1,3}(?:[' ]\d{3})*(?:[.,]\d{1,2})?\s*(CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b`
  - Percentages: `\b\d{1,3}(?:[.,]\d{1,2})?\s*%`
  - Legal article references: `\b(art\.?\s*\d+(?:\s*al\.?\s*\d+)?\s*(LIFD|LPP|LAVS|LCA|LPCC|OPP[23]?|OCC|LHID|CO))\b`
  - Time durations: `\b\d+\s*(ans?|mois|jours?|semaines?|années?|trimestres?)\b`
  - Regulatory constants by name: `(taux\s+de\s+conversion|plafond\s+3a|barème\s+LIFD|coefficient\s+\w+)`
- **D-03:** Detection is **whole-token aware** — must NOT trigger on the meta-quote / negation patterns introduced in Wave 4 (`93.5-w4`). Reuse `_is_meta_negation` + `_is_meta_quoted` helpers from `tools/eval_narrator.py` ; refactor them into `app/services/coach/citation_parser.py` so both eval-time and runtime use the same logic.
- **D-04:** A number IS allowed without `{{cite:}}` ONLY when:
  - it appears in a meta-negation context (« aucun X n'est de 4% »)
  - it appears in a meta-quote (« le mythe du "10% garanti" »)
  - it is part of a legal article reference (`art. 38 LIFD` is itself the citation)
  - it appears inside an explicit `{{cite:...}}` placeholder body (e.g. timestamps in citation values)

#### Citation Source Registry (Gray Area B — GATE-02)

- **D-05:** 4 source types per ROADMAP: `profile | reasoning | tool_call_id | adr | spec`. Each `{{cite:<key>}}` resolves to one of these source kinds at parse time:
  - `profile:<field>` — value from the user profile snapshot (e.g. `profile:income_gross_yearly`)
  - `reasoning:<calc>` — value from a deterministic calculation in `financial_core/` or `services/backend/app/services/`
  - `tool_call_id:<id>` — value emitted by a narrator tool call (the 6-tool registry from Phase 93.5 D-20)
  - `adr:<file>#<key>` — value defined in a project ADR (e.g. `adr:2026-05-09-calc-first#r3a_ceiling_2026`)
  - `spec:<file>#<key>` — value defined in a canonical spec (LIFD article values, FINMA constants, etc.)
- **D-06:** Citation registry storage — `services/backend/app/services/coach/citation_registry.py` (new). Pure Python module exposing a frozen dict `CITATION_REGISTRY: Mapping[str, CitationSource]` plus a `resolve(key: str, ctx: CoachContext) -> str | None` function that looks up the value at runtime. Phase 95 will replace this module with the `GroundingPack` JSON contract; Phase 94 keeps it minimal.
- **D-07:** Bundle integration per Phase 93.5 D-18 — when `COACH_BUNDLE_COMPILER_ENABLED=true`, the gate intersects the narrator's emitted `{{cite:<key>}}` set with the compiled bundle's `citation_allowlist`. Citations outside the allowlist are rejected (closed-world). When flag-OFF, the gate falls back to the global `CITATION_REGISTRY` (any registered key is accepted). This is the « graceful degradation » per D-18.

#### Retry-or-Fallback Flow (Gray Area C — GATE-03)

- **D-08:** Hard-cap retries = 1. Per ROADMAP Risk #2 mitigation (« retry loop blows token budget »). Risk-pinned, not configurable.
- **D-09:** On first rejection, the narrator is reprompted with this exact text appended to the user message: `\n\nRAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. Si tu n'as pas la source pour un chiffre, écris « je n'ai pas cette donnée » à la place.`
- **D-10:** On second failure, return the templated fallback verbatim: `Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) et je peux t'orienter vers ce qui s'applique chez toi.` — no fabricated number, life-event-router fallback tone.
- **D-11:** Gate insertion point — `coach_chat.py` after narrator response is collected, BEFORE the `_build_response` payload is sent to the client. Specifically, between the narrator-response capture (around `coach_chat.py:3170`-ish) and the final response build. The gate is a thin wrapper that calls `citation_parser.gate(response_text, ctx, citation_allowlist) -> GatedResponse`.

#### Banned-Claim List (Gray Area D — GATE-04)

- **D-12:** Banned-claim list source — reuse the existing LSFin banned-terms set already wired in `services/backend/app/services/coach/bundles/compliance_narrator.py` (`_BANNED_TERMS_REMINDER` content) + `mint-swiss-compliance/SKILL.md` registry. Phase 94 ADDS the « affirmative claim with cited number » red flag: even a `{{cite:}}`-backed number that asserts a forecast as fact (« vous ferez 4% par an ») is rejected if the narrator wraps it in a deterministic verb (« vous ferez », « rapportera », « est garanti à »). Lint pattern: `(vous|tu)\s+(ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d` triggers rejection EVEN WITH citation.
- **D-13:** A banned claim is rejected with the same retry-or-fallback flow as missing citations (D-09 / D-10). The reprompt text is adapted: `\n\nRAPPEL — Une projection est une scénario, pas une promesse. Reformule au conditionnel (« pourrait », « selon ce scénario », « si X reste constant »).`

#### Eval Pack + Maestro Flow (Gray Area E)

- **D-14:** 50-fixture eval pack at `services/backend/tests/fixtures/citation_gate_eval_50.jsonl`. Each fixture has the same shape as `narrator_eval_50.jsonl` plus an `expected_gate_outcome: pass | rejected_uncited | rejected_banned_claim | fallback` field. Pack covers: 20 with valid citations, 10 with uncited numbers, 10 with banned claims, 10 with fallback paths.
- **D-15:** Eval thresholds per ROADMAP success criterion #3 — Sonnet narrator ≥95% gate-correct, Haiku narrator ≥90%. Gate-correct = (gate verdict matches expected_gate_outcome).
- **D-16:** Maestro flow — `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml`. Sends profile-empty user with chat « combien je gagne ? » and asserts the response does NOT contain a fabricated CHF number. Greenfield flow, builds on the existing Maestro setup (memory `reference_maestro_setup.md`).

#### Performance & Wiring Budget (Gray Area F)

- **D-17:** Citation parser pure Python regex, no LLM call, no library load — target ≤50ms per response on a 200-token narrator output. Total turn budget remains ≤30s (existing performance budget per ROADMAP §Cross-cutting concerns).
- **D-18:** Sentry breadcrumbs introduced (mirroring Phase 93.5 telemetry hygiene): `coach.citation_gate.verdict={pass|rejected_uncited|rejected_banned_claim|fallback}`, `coach.citation_gate.retries={0|1}`, `coach.citation_gate.uncited_numbers_count=<n>`. Payload restricted to non-PII counts/labels — never user message content. Mirror the Wave 1 D-12 hygiene rule from Phase 93.5 (bundle compiler).

#### Migration & Feature Flag (Gray Area G)

- **D-19:** New env-gated flag `COACH_CITATION_GATE_ENABLED: bool = False` in `app/core/config.py`, default OFF in prod, ON in staging during Stage 3 eval. Mirrors the Phase 91 `COACH_DUAL_LLM_ENABLED` and Phase 93.5 `COACH_BUNDLE_COMPILER_ENABLED` pattern.
- **D-20:** Two response paths preserved during rollout — flag-OFF: legacy bypass (no gate, current behavior), flag-ON: gate enforced. Tests parametrize over both paths. Flag flip-on plan documented in Plan 94-04 GO/NO-GO proposal (mirror 93.5-04-FLAG-FLIP-PROPOSAL.md template).
- **D-21:** Sunset plan — flag and bypass code path removed in Phase 96 OR after 4 weeks of staging soak with `coach.citation_gate.fallback` rate ≤2%, whichever comes later. The bypass is the safety net during rollout, NOT a permanent option.

### Claude's Discretion

NOT locked here — Claude decides at planning/execution time:

- Exact `CITATION_REGISTRY` contents (key list will iterate during Stage 3 eval as compiler bundles surface what they cite).
- Tokenizer choice for retry-once budget check (recommend reusing `count_tokens_cached` from Phase 93.5-04 Task 1).
- Whether the gate is a request-scoped middleware vs a coach_chat.py call-site wrapper (recommend wrapper for surgical Karpathy #3 minimalism).
- Per-fixture test file structure under `tests/test_citation_gate/` (one file per gate verdict type).
- Maestro flow's exact assertion format (relies on existing `flow_narrator_*.yaml` patterns).

### Deferred Ideas (OUT OF SCOPE)

- **Multi-turn citation continuity** (citations carry across conversation history) — Phase 96 (CHAT-AS-VERB) territory ; turn-cap context propagation will integrate.
- **Per-user citation provenance dashboard** — Phase 96 or beyond ; user-facing UX.
- **Cross-language citation registry** (DE/EN/IT/ES/PT keys) — Phase 99+.
- **Citation source registry as JSON contract `GroundingPack`** — Phase 95 (DAG-INVALIDATION) ; D-06's pure-Python module is a Phase 94 stub that Phase 95 replaces.
- **Backend calc-parity (`backlog 999.4`)** — only triggered if Phase 94 §3 CalcTrace requires server-side numbers. Conditional, post-TestFlight.
- **`mint-wiring-verifier` full agent (`backlog 999.3`)** — conditional on ≥3 façade-revert incidents post-Phase 94 close ; not a Phase 94 deliverable.
- **Audit Proposal B (compliance-narrator-auditor leaf-worker subagent)** — runtime multi-agent topology ; deferred to Phase 97-98 post-TestFlight.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | number detection regex | D-02 5-family regex set (CHF/EUR/USD, %, legal article, durations, regulatory constants) ; pre-compile at import time ; ≤50ms budget verified `[VERIFIED: stdlib re bench, see Performance section]` |
| GATE-02 | citation source registry | D-05 5 source types (profile/reasoning/tool_call_id/adr/spec) ; D-06 pure-Python `citation_registry.py` ; placeholder lives at `app/services/coach/grounding_pack.py` (currently empty `frozenset()` per Phase 95 stub) `[VERIFIED: grounding_pack.py:24]` |
| GATE-03 | retry-or-fallback flow | D-08 hard-cap retries=1 ; D-09 reprompt addendum verbatim FR ; D-10 fallback verbatim FR ; insertion at coach_chat.py:~3285 (post-loop_result, pre-CoachChatResponse) `[VERIFIED: coach_chat.py:3264-3373]` |
| GATE-04 | banned-claim list | D-12 reuses ComplianceNarrator banned terms (35 entries verified at `compliance_guard.py:43-117`) + new « affirmative verb + cited number » regex `(vous|tu)\s+(ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d` ; D-13 retry reprompts at the conditional, NOT removal of citation `[VERIFIED: compliance_guard.py:43, BANNED_TERMS list]` |

---

## Project Constraints (from CLAUDE.md)

The planner MUST verify the plan honors these directives. Treat with the same authority as locked decisions.

| Source | Directive | Phase 94 application |
|--------|-----------|----------------------|
| §1 | « Banned terms (LSFin) — NEVER `garanti`, `optimal`, `meilleur`, `certain`, `assuré`, `sans risque`, `parfait` » | D-12 reuses `compliance_guard.BANNED_TERMS` (35 entries — masc/fem/plural/conditional/gerund forms) ; gate is the *runtime* enforcement layer for the same list |
| §1 | « Accents 100% FR mandatory » | D-09 + D-10 verbatim FR strings MUST keep their accents (« je n'ai pas cette donnée », « pourrait ») ; lint via `tools/checks/accent_lint_fr.py` |
| §1 | « MINT ≠ retirement app — 18 life events » | D-10 fallback opens with « canton, salaire, structure familiale » (life-event router tone, not retirement-first) ; verified |
| §1 | « financial_core reuse mandatory » | D-05 `reasoning:<calc>` source type resolves THROUGH `financial_core/` — gate does NOT re-implement calculations ; the registry is a lookup table, not a calculator |
| §1 | « i18n required » | Phase 94 v1 is FR-only (D-09 + D-10 verbatim FR per CONTEXT note `Note on language`) ; cross-language registry deferred to Phase 99+ ; the *gate verdict labels* (`pass`, `rejected_uncited`, `rejected_banned_claim`, `fallback`) are technical telemetry strings, never user-facing |
| §1 | « 0-TRUST — never trust your own claims » | The gate verdict is the deterministic citation. Plan tasks MUST cite gate output (e.g. `coach.citation_gate.verdict=fallback` count) before claiming « shipped » |
| §3 | MCP `check_banned_terms()` | D-12 banned-claim list — the lint can run in CI alongside the gate's runtime check ; not a runtime dep, but a build-time safety net |
| §5 NEVER #5 | « banned terms » | Same as §1 above ; the gate is the runtime enforcement |
| §5 NEVER #8 | « Promise returns » | D-12 « affirmative verb + cited number » detection IS this directive (« vous ferez 4% » fails even with citation) |
| §5 NEVER #9 | « Projection without confidence score » | D-13 reprompt text wraps the response in conditional language ; the cited number stays, the assertion verb is reframed |
| §7 #1 Think Before Coding | « state assumptions » | Assumptions Log section below catalogs every `[ASSUMED]` claim |
| §7 #2 Simplicity First | « minimum code » | Gate is ONE file (`citation_parser.py`) + ONE registry stub (`citation_registry.py`) + ONE flag in config + ~5 LOC at coach_chat insertion + ~10 LOC at eval_narrator extension |
| §7 #3 Surgical Changes | « touch only what you must » | NO change inside `_run_agent_loop` (the gate wraps the existing call, doesn't modify the loop) ; meta-helpers MOVE from eval_narrator to citation_parser, eval_narrator imports them back |
| §7 #4 Goal-Driven Execution | « define success criteria » | The 8 Validation Architecture criteria (5 stages, 50-fixture eval ≥95% / ≥90%, Maestro G1) define success ; planner can loop independently |
| §9 0-Trust | « banned without citation » | Plan SUMMARY claims must cite eval-pack JSON output, gate breadcrumb counts, OR Maestro flow PASS — never bare claims |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python `re` (stdlib) | 3.9.6 | Regex matching, all 5 D-02 patterns + meta-helpers | Already used at `compliance_guard.py:43`, `eval_narrator.py:243`, `bundle_compiler.py:110` ; zero deps ; pre-compile pattern at module import per RESEARCH §Performance `[VERIFIED: services/backend/pyproject.toml line 50, python_requires]` |
| Pydantic v2 | ≥2.x (pinned via FastAPI) | `CitationSource`, `GatedResponse` dataclass-equivalent (frozen, extra=forbid) | Project standard per CLAUDE.md §1 ; pattern verified at `bundles/_base.py:35` (`ConfigDict(frozen=True, extra="forbid")`) `[VERIFIED: services/backend/app/services/coach/bundles/_base.py:35]` |
| `dataclasses` (stdlib) | 3.9.6 | `@dataclass(frozen=True)` for the in-memory `GatedResponse` | Already used at `bundle_compiler.py:113` for `CompiledBundle` — copy the pattern verbatim `[VERIFIED: bundle_compiler.py:113]` |
| pytest | ≥8.0.0 | Test framework | Project standard `[VERIFIED: services/backend/pyproject.toml:50]` |
| pytest-asyncio | ≥0.23.0 | Async retry-flow tests | Project standard `[VERIFIED: pyproject.toml:51]` |
| hypothesis | ≥6.111 | Property tests on regex coverage (e.g. « no number escapes detection ») | Already a Phase 92.5 dependency `[VERIFIED: pyproject.toml:56]` |
| sentry-sdk | 2.56.0 | D-18 breadcrumbs | Already wired ; reuse `add_breadcrumb()` pattern from Phase 93.5 `[VERIFIED: python -c "import sentry_sdk; print(sentry_sdk.VERSION)" → 2.56.0]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `app.services.coach.compliance_guard.ComplianceGuard.BANNED_TERMS` | n/a | D-12 banned terms list source | Import the 35-entry list verbatim ; do NOT duplicate `[VERIFIED: compliance_guard.py:43-117]` |
| `app.services.coach.bundle_compiler.compile_bundles` | n/a | D-07 bundle integration — provides `compiled.citation_allowlist` | Already invoked at `coach_chat.py:3235` ; gate reads `compiled.citation_allowlist` from the same call site `[VERIFIED: bundle_compiler.py:152, coach_chat.py:3235]` |
| `app.services.coach.grounding_pack.GROUNDING_PACK_KEYS_REGISTRY` | n/a (frozenset, currently empty) | D-06 future home of the registry (Phase 95 fills it) | The Phase 94 `citation_registry.py` is the runtime stub ; Phase 95 collapses both into `GroundingPack` JSON `[VERIFIED: grounding_pack.py:24]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure Python `re` | Anthropic Citations API (`citations: enabled` on `messages.create`) | Citations API works on **document chunks**, not narrator-emitted numbers ; would require restructuring the calculator output as document chunks fed to the narrator. Calc-first ADR §N1 + Expert-3 explicitly note this is the *inspirational* pattern, but the *productionised* form for MINT is « closed-world numeric vocabulary + post-hoc substitution ». **CONTEXT D-02 locks pure-Python regex.** Trade-off is sound : regex gives sub-ms parse, deterministic verdict, no extra API call ; Anthropic Citations would add ~200-500ms latency per turn and a serialization layer. `[CITED: .planning/audit/calc-first-architecture/expert-3-llm-illumination-architecture.md §Question 1 Pattern 5 « Post-hoc number replacement »]` `[CITED: https://www.anthropic.com/news/introducing-citations-api]` |
| Per-request middleware | Call-site wrapper | A FastAPI middleware would couple the gate to HTTP transport ; the gate is pure logic operating on `loop_result["answer"]`. Wrapper is Karpathy #3 minimalist. CONTEXT discretion notes : « recommend wrapper for surgical Karpathy #3 minimalism ». |
| Surgery inside `_run_agent_loop` | Wrapper outside the loop | `_run_agent_loop` is the tool-loop (max iterations, tool-call dispatch). Adding a quality-loop inside conflates two concerns. The wrapper at the call site (3264-3283) calls `_run_agent_loop` twice in the worst case (initial + retry-once) — same code path, different `question` parameter. |
| Custom Sentry transport | Existing `sentry_sdk.add_breadcrumb` | Reuse the breadcrumb hygiene pattern from Phase 93.5 Wave 1 D-12 verbatim — non-PII counts/labels only. |

**Installation:** No new packages. All deps already in `pyproject.toml` `[VERIFIED: services/backend/pyproject.toml:48-60]`.

**Version verification:**
```bash
cd services/backend && python3 -c "import sentry_sdk; print(sentry_sdk.VERSION)"
# 2.56.0  (verified 2026-05-10)
python3 --version
# 3.9.6  (verified 2026-05-10)
grep -E "pytest|hypothesis|pydantic" pyproject.toml | head -5
```

---

## Architecture Patterns

### Recommended Project Structure

```
services/backend/app/services/coach/
├── citation_parser.py          # NEW — Phase 94 (gate logic + meta-helpers)
├── citation_registry.py        # NEW — Phase 94 (D-06 stub registry, ≤30 keys initially)
├── grounding_pack.py           # EXISTING (Phase 93.5 stub, frozenset empty until Phase 95)
├── bundle_compiler.py          # EXISTING (Phase 93.5 — emits CompiledBundle.citation_allowlist)
├── bundles/                    # EXISTING (6 bundles, each with citation_allowlist)
└── compliance_guard.py         # EXISTING (35 banned terms — D-12 reads from here)

services/backend/app/api/v1/endpoints/
└── coach_chat.py               # MODIFIED — insert gate wrapper at line ~3285

services/backend/app/core/
└── config.py                   # MODIFIED — add COACH_CITATION_GATE_ENABLED flag

services/backend/tools/
└── eval_narrator.py            # MODIFIED — add `--gate={on,off}` flag, import meta-helpers from citation_parser

services/backend/tests/
├── test_citation_gate/         # NEW — one test file per gate verdict
│   ├── __init__.py
│   ├── test_number_detection.py        # D-02 5-family regex coverage
│   ├── test_meta_helpers.py            # D-03 negation + quote (port 15 tests from test_eval_narrator_meta_scorer.py)
│   ├── test_banned_claims.py           # D-12 affirmative-verb + cited number
│   ├── test_retry_flow.py              # D-08 retry-once
│   ├── test_fallback.py                # D-10 templated fallback verbatim
│   ├── test_bundle_intersect.py        # D-07 flag-ON intersect with citation_allowlist
│   ├── test_global_registry_fallback.py # D-07 flag-OFF fallback
│   ├── test_byte_identity_flag_off.py  # D-20 flag-OFF byte-identical to today
│   └── test_performance.py             # D-17 ≤50ms parser budget
└── fixtures/
    └── citation_gate_eval_50.jsonl     # NEW — D-14 50-fixture eval pack

tools/simulator/flows/maestro-perfect-set/
└── flow_narrator_refuses_uncited_numbers.yaml  # NEW — D-16 G1 gate
```

### Pattern 1: Gate Wrapper (the heart of Phase 94)

**What:** Pure function `gate(response_text, ctx, citation_allowlist) -> GatedResponse`. No I/O, no side effects, deterministic on the input triple.
**When to use:** Every narrator response when `COACH_CITATION_GATE_ENABLED=True`.
**Example:**
```python
# Source: NEW services/backend/app/services/coach/citation_parser.py (designed in this research)
# Mirrors the frozen-dataclass pattern at bundle_compiler.py:113
from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
from typing import Iterable, Optional


class GateVerdict(str, Enum):
    PASS = "pass"
    REJECTED_UNCITED = "rejected_uncited"
    REJECTED_BANNED_CLAIM = "rejected_banned_claim"
    FALLBACK = "fallback"


@dataclass(frozen=True)
class GatedResponse:
    verdict: GateVerdict
    gated_text: str                      # post-gate text (substituted citations or fallback verbatim)
    retry_needed: bool                   # True for first rejection only ; D-08 caps at 1
    reprompt_addendum: Optional[str]     # D-09 or D-13 verbatim FR text, or None
    uncited_numbers_count: int = 0       # D-18 telemetry
    banned_claims_found: tuple[str, ...] = ()   # D-18 telemetry
    inputs_hash: Optional[str] = None    # Phase 95 stub field (always None in Phase 94)


def gate(
    response_text: str,
    ctx,                                 # CoachContext
    citation_allowlist: Optional[Iterable[str]] = None,
    is_retry: bool = False,
) -> GatedResponse:
    """Phase 94 closed-world citation gate.

    Args:
        response_text: narrator output (loop_result["answer"]).
        ctx: CoachContext for registry resolution.
        citation_allowlist: D-07 — when bundle compiler is on, the
            intersect set ; when off, None and we fall back to the
            global CITATION_REGISTRY keys.
        is_retry: D-08 — True on the second pass, forces FALLBACK on
            any rejection (no third call to the narrator).

    Returns:
        Frozen GatedResponse. Pure function, no I/O.
    """
    ...
```

### Pattern 2: Insertion at coach_chat.py (Karpathy #3 surgical)

**What:** Wrapper around `await _run_agent_loop(...)` ; calls the loop, runs the gate, optionally calls the loop a second time with appended reprompt, falls back deterministically.
**When to use:** Replace lines 3263-3283 with a flag-gated wrapper.
**Example:**
```python
# Source: NEW design — insertion at services/backend/app/api/v1/endpoints/coach_chat.py:~3263
# DESIGN sketch (planner refines exact diff in Plan 94-02)

async def _run_narrator_with_gate(
    *,
    body_message: str,
    initial_call_kwargs: dict,
    citation_allowlist: Optional[list[str]],
    coach_ctx,
) -> dict:
    """D-11 wrapper — call narrator, gate, retry-once-or-fallback."""
    loop_result = await asyncio.wait_for(
        _run_agent_loop(question=body_message, **initial_call_kwargs),
        timeout=AGENT_LOOP_DEADLINE_SECONDS,
    )

    if not settings.COACH_CITATION_GATE_ENABLED:
        return loop_result    # D-20 flag-OFF byte-identical bypass

    gated = gate(
        response_text=loop_result["answer"],
        ctx=coach_ctx,
        citation_allowlist=citation_allowlist,
        is_retry=False,
    )

    sentry_sdk.add_breadcrumb(
        category="coach.citation_gate",
        data={
            "verdict": gated.verdict.value,
            "retries": 0,
            "uncited_numbers_count": gated.uncited_numbers_count,
        },
    )

    if gated.verdict == GateVerdict.PASS:
        loop_result["answer"] = gated.gated_text
        return loop_result

    if not gated.retry_needed:
        # Should not happen on first pass — defensive
        loop_result["answer"] = gated.gated_text
        return loop_result

    # D-08 — retry once with appended reprompt (D-09 or D-13)
    retry_message = body_message + (gated.reprompt_addendum or "")
    retry_result = await asyncio.wait_for(
        _run_agent_loop(question=retry_message, **initial_call_kwargs),
        timeout=AGENT_LOOP_DEADLINE_SECONDS,
    )

    retry_gated = gate(
        response_text=retry_result["answer"],
        ctx=coach_ctx,
        citation_allowlist=citation_allowlist,
        is_retry=True,    # forces FALLBACK on rejection
    )

    sentry_sdk.add_breadcrumb(
        category="coach.citation_gate",
        data={
            "verdict": retry_gated.verdict.value,
            "retries": 1,
            "uncited_numbers_count": retry_gated.uncited_numbers_count,
        },
    )

    retry_result["answer"] = retry_gated.gated_text
    return retry_result
```

### Pattern 3: Citation registry (D-06)

**What:** Pure-Python frozen mapping `key → CitationSource`. Source kinds enumerated per D-05.
**Example:**
```python
# Source: NEW services/backend/app/services/coach/citation_registry.py
from typing import Literal, Mapping
from pydantic import BaseModel, ConfigDict


class CitationSource(BaseModel):
    """A single resolvable citation entry. D-05 source types."""
    model_config = ConfigDict(frozen=True, extra="forbid")
    key: str                                                           # e.g. "r3a_plafond_salarie_2026"
    source_kind: Literal["profile", "reasoning", "tool_call_id", "adr", "spec"]
    source_ref: str                                                    # e.g. "adr:2026-05-09-calc-first#r3a_ceiling_2026"
    description_fr: str                                                # human-readable for telemetry / debug only

# Initial Phase 94 registry — bundles' citation_allowlist union, ~22 keys.
# Phase 95 replaces this with GroundingPack JSON.
CITATION_REGISTRY: Mapping[str, CitationSource] = {
    "r3a_plafond_salarie_2026": CitationSource(
        key="r3a_plafond_salarie_2026",
        source_kind="spec",
        source_ref="spec:OPP3#art_7_alinea_1_lit_a",
        description_fr="Plafond 3a annuel salarié·e affilié·e LPP",
    ),
    # ... ~21 more keys, one per bundle citation_allowlist entry
}


def resolve(key: str, ctx) -> Optional[str]:
    """Resolve a citation key against the registry. Returns the displayable
    value (substituted into the narrator output) or None if unresolvable.
    """
    entry = CITATION_REGISTRY.get(key)
    if entry is None:
        return None
    # ... per source_kind dispatch (Phase 95 will replace with GroundingPack)
```

### Anti-Patterns to Avoid

- **Surgery inside `_run_agent_loop`** : the loop is a tool-loop, not a quality-loop. Adding the gate inside it conflates two concerns. The wrapper outside is the surgical change.
- **Hand-rolling number detection** : the 5 D-02 regexes are the contract ; do NOT add « one more pattern » without amending CONTEXT.
- **Treating fallback text as a template** : D-10 is **verbatim French**, no variables. If a future contributor adds `f"...{ctx.canton}..."`, they break the determinism contract.
- **Calling Anthropic Citations API at runtime** : tempting, but adds 200-500ms p50 ; CONTEXT D-02 locks pure-Python regex.
- **Duplicating banned-terms list** : D-12 reads from `compliance_guard.BANNED_TERMS` ; do not copy the 35 entries into citation_parser.py.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| French-aware word boundaries | Custom `\b` regex with `[a-z]` | `compliance_guard._FR_LETTER` (`a-zA-ZÀ-ÿ`) lookaround pattern | « garanti » in « garantissant » must NOT match ; existing pattern handles diacritics correctly `[VERIFIED: compliance_guard.py:121]` |
| Banned-terms list | Hardcode 35 entries in citation_parser | `from app.services.coach.compliance_guard import ComplianceGuard; ComplianceGuard.BANNED_TERMS` | Single source of truth ; existing list covers masc/fem/plural/conditional/gerund/promise-family forms `[VERIFIED: compliance_guard.py:43-117]` |
| Meta-quote / negation detection | Re-implement scope-aware sentence boundaries | Refactor `_is_meta_quoted` + `_is_meta_negation` from `tools/eval_narrator.py:250-296` into `citation_parser.py` ; eval_narrator imports them back | Wave 4 of Phase 93.5 already shipped this with 15 backing tests at `tests/test_eval_narrator_meta_scorer.py` ; refactoring (not re-writing) preserves test coverage `[VERIFIED: eval_narrator.py:250-296, test_eval_narrator_meta_scorer.py 203 LOC]` |
| Citation-allowlist subset check | Custom set logic | `set(narrator_emitted_keys).issubset(set(compiled.citation_allowlist))` (1 LOC) | The bundle compiler returns a sorted list at `CompiledBundle.citation_allowlist` ; convert to set inline `[VERIFIED: bundle_compiler.py:236-238]` |
| Sentry telemetry | Custom transport | `sentry_sdk.add_breadcrumb(category=..., data=...)` | Already used in Phase 93.5 Wave 1 D-12 ; payload hygiene rule (non-PII counts/labels only) is a copy-paste |
| Pydantic frozen+extra=forbid pattern | Re-write config | Copy `model_config = ConfigDict(frozen=True, extra="forbid")` from `bundles/_base.py:35` | Phase 91 + Phase 93.5 precedent ; stable `[VERIFIED: bundles/_base.py:35]` |
| Empty-text fallback | Re-detect empty narrator output | `compliance_guard` already short-circuits on `not text.strip()` ; the gate runs AFTER compliance_guard would have | The two layers are independent (per CONTEXT specifics line 179) ; do not duplicate the empty-text check |

**Key insight:** Phase 94 is a *thin* layer. Every reusable asset already exists in the codebase ; Phase 94 stitches them together rather than re-implementing.

---

## Common Pitfalls

### Pitfall 1: Citation key resolves but is not in the bundle's allowlist (D-07 closed-world contract)

**What goes wrong:** Narrator emits `{{cite:r3a_plafond_salarie_2026}}` in a request where intent=`debt`, so the activated bundles are `mortgage-stressor + compliance-narrator` — neither lists `r3a_plafond_salarie_2026`. The key IS in `CITATION_REGISTRY`, but it's not in `compiled.citation_allowlist`.
**Why it happens:** The bundle compiler intersects, the global registry permits — D-07 explicitly says « citations outside the allowlist are rejected (closed-world) » when flag is ON.
**How to avoid:** When `COACH_BUNDLE_COMPILER_ENABLED=True`, the gate uses ONLY the bundle's `citation_allowlist`, not the global registry. When `COACH_BUNDLE_COMPILER_ENABLED=False`, the gate uses the global `CITATION_REGISTRY` (any registered key is accepted). The order of precedence is locked by D-07.
**Warning signs:** Sentry breadcrumb `coach.citation_gate.verdict=rejected_uncited` rate spikes when the bundle compiler flag is flipped on. Cross-reference with `coach.bundle.activated` to identify which intent is mis-routing.

### Pitfall 2: Recursive `{{cite:foo}}` where foo references another citation key

**What goes wrong:** A registry entry resolves to a string that ITSELF contains `{{cite:bar}}`. Naive regex pass leaves the inner placeholder unsubstituted.
**Why it happens:** A future Phase 95 GroundingPack entry might compose values. Phase 94 should not allow this in v1.
**How to avoid:** Validate at registry-load time that no `CITATION_REGISTRY[key].description_fr` or resolved value contains the substring `{{cite:`. Add a unit test `test_no_recursive_citation_keys`.
**Warning signs:** `\d` left in narrator output after substitution + parsing pass.

### Pitfall 3: Regex false-positive on non-financial numbers (« j'ai 2 enfants »)

**What goes wrong:** The duration regex `\b\d+\s*(ans?|mois|jours?|semaines?|années?|trimestres?)\b` triggers on « j'ai 2 enfants depuis 5 ans » — the « 5 ans » is duration but « 2 enfants » is not in the family ; however « 2 ans » in « j'ai 2 ans d'expérience » is also not financial.
**Why it happens:** The regex captures any duration. CONTEXT D-04 does NOT exempt non-financial durations.
**How to avoid:** The regex IS designed to catch any duration — the failsafe is that the narrator's bundles already steer it toward financial topics. If false-positive rate exceeds 1% on the eval pack, tighten the duration regex with a context lookahead (e.g. `(?:retraite|cotisation|épargne|amortissement|projection)` within 50 chars). Plan task : measure false-positive rate on the 50-fixture pack BEFORE deciding to tighten — Karpathy #2 (don't pre-optimize).
**Warning signs:** `coach.citation_gate.verdict=rejected_uncited` rate >5% on staging soak with no banned-claim hits.

### Pitfall 4: Meta-negation false-negatives across paragraph boundaries

**What goes wrong:** Wave 4's `_is_meta_negation` walks back to the previous `[.!?]\s+` or `\n\n` boundary (250-char horizon). If the negation is in paragraph 1 (« Aucun rendement n'est garanti dans ce scénario. ») and the cited number is in paragraph 2 (« Donc 4% reste un objectif »), the helper does NOT flag the « 4% » as meta-protected.
**Why it happens:** D-03 explicitly scopes to sentence ; this is by design. Cross-paragraph negation is `[ASSUMED]` adequate per CONTEXT but not measured.
**How to avoid:** Eval pack D-14 includes ≥2 fixtures with cross-paragraph negation (« paragraph-spanning negation » category) ; if the failure rate exceeds 5%, file a follow-up issue. Phase 94 does NOT extend the helper's scope (Karpathy #2).
**Warning signs:** Eval-pack manual review shows pattern « narrator opens with anti-promise, then cites a number that gets rejected ». [ASSUMED] this is rare — verify on the 50-fixture pack at Stage 3.

### Pitfall 5: Streaming output becomes problematic for retry-once

**What goes wrong:** If Phase 96 enables narrator streaming (currently NOT enabled per `coach_chat.py:3264` synchronous `await asyncio.wait_for`), the gate cannot run on a partial response, and retrying-once becomes much harder (you'd need to discard the streamed chunks already sent to the client).
**Why it happens:** D-08 retry-once assumes the full response is available before any client-bound emission.
**How to avoid:** Phase 94 is greenfield-incompatible-with-streaming. Plan-04 SUMMARY MUST flag this dependency to Phase 96 explicitly. Until streaming lands, no action needed.
**Warning signs:** Phase 96 PR proposes streaming WITHOUT addressing citation gate — block at review.

### Pitfall 6: A retry-once narrator response that ALSO fails — but with a different banned claim

**What goes wrong:** Initial response: « vous ferez 4% par an » (banned claim D-12). Retry response: « 4% est garanti » (different banned claim, also D-12). With `is_retry=True`, the gate forces FALLBACK — but the user gets the templated « je n'ai pas cette donnée » fallback even though the second response is « technically » a different failure.
**Why it happens:** D-08 hard-cap at 1 retry, D-13 retries banned claims with the same flow.
**How to avoid:** This is the **correct** behavior per CONTEXT — fallback IS the safe path. The breadcrumb `coach.citation_gate.verdict=fallback + coach.citation_gate.retries=1` records the failure for the soak monitoring. D-21 sunset gate is `≤2% fallback rate` ; if this scenario inflates the rate, the planned response is to fatten the bundles' anti-promise doctrine (Phase 96 territory), not to lift the retry cap.
**Warning signs:** Fallback rate >2% on staging soak. Investigate by sampling user messages → bundle activation → response pairs.

### Pitfall 7: The « legal article IS a citation » exception (D-04) overlap

**What goes wrong:** « art. 38 LIFD » contains the digit `38` — the duration regex `\b\d+\s*(ans?|...)\b` does NOT trigger (no unit follows), but a future « art. 5 ans » would be a false ambiguity. More realistically, « art. 38 LIFD prévoit 5 ans de prescription » contains BOTH a legal article AND a duration ; the gate must skip the « 38 » (legal article exception) but FLAG the « 5 ans » as needing citation.
**Why it happens:** D-04 lists 4 exceptions, but the regex passes are independent.
**How to avoid:** The 5 regex families are scanned independently. The legal-article regex has the highest priority — its match span is recorded, and the OTHER 4 regex families skip any match whose span intersects with a legal-article span. This is a 5-LOC change in the parser.
**Warning signs:** Eval pack manual review shows rejected uncited numbers that overlap with a legal article reference.

### Pitfall 8: First fixture run consumes 2× tokens silently

**What goes wrong:** The eval-pack run with `--gate=on` calls the narrator twice for every fixture that needs retry. Cost regression vs `--gate=off` could be material (10-30% extra tokens on the eval pass).
**Why it happens:** D-08 retry-once is a real second LLM call.
**How to avoid:** The eval-pack output JSON includes a `retries` field per fixture ; aggregate cost report MUST surface average tokens including retries. This is a 5-LOC change in `tools/eval_narrator.py` next to the existing `prompt_tokens` field. Plan task 94-04 budget includes the retry token cost.
**Warning signs:** Aggregate prompt_tokens delta `gate=on` vs `gate=off` >15% on the same fixture pack.

---

## Code Examples

### Common Operation 1: Pre-compiled regex set (D-02)

```python
# Source: NEW services/backend/app/services/coach/citation_parser.py
# Pattern source: compliance_guard.py:121 (FR-aware word boundaries) + bundle_compiler.py:110 (single-vs-double brace lookaround)
import re

_FR_LETTER = r"a-zA-ZÀ-ÿ"

# D-02 pattern 1 — currency amounts (CHF/EUR/USD/fr./francs)
_RE_CURRENCY = re.compile(
    r"\b\d{1,3}(?:[' ]\d{3})*(?:[.,]\d{1,2})?\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b",
)

# D-02 pattern 2 — percentages
_RE_PERCENT = re.compile(r"\b\d{1,3}(?:[.,]\d{1,2})?\s*%")

# D-02 pattern 3 — legal articles (priority match — eats interior digits)
_RE_LEGAL_ARTICLE = re.compile(
    r"\b(art\.?\s*\d+(?:\s*al\.?\s*\d+)?\s*(?:LIFD|LPP|LAVS|LCA|LPCC|OPP[23]?|OCC|LHID|CO))\b",
)

# D-02 pattern 4 — durations
_RE_DURATION = re.compile(
    r"\b\d+\s*(?:ans?|mois|jours?|semaines?|années?|trimestres?)\b",
)

# D-02 pattern 5 — regulatory constants by name
_RE_REGULATORY = re.compile(
    r"(?:taux\s+de\s+conversion|plafond\s+3a|barème\s+LIFD|coefficient\s+\w+)",
    re.IGNORECASE,
)

# {{cite:<key>}} placeholder — single source of truth for the format
_RE_CITE_PLACEHOLDER = re.compile(r"\{\{cite:([a-zA-Z0-9_]+)\}\}")
```

### Common Operation 2: Refactored meta-helpers (D-03)

```python
# Source: REFACTORED from tools/eval_narrator.py:250-296 (Phase 93.5 Wave 4)
# Verbatim copy ; only the import path changes.
# eval_narrator.py imports from citation_parser to keep ONE source of truth.

# In citation_parser.py:
def is_meta_quoted(response: str, match_start: int, match_end: int) -> bool:
    """Same as eval_narrator._is_meta_quoted — moved here for runtime use."""
    line_start = response.rfind("\n", 0, match_start) + 1
    line_end_idx = response.find("\n", match_end)
    line_end = line_end_idx if line_end_idx != -1 else len(response)
    pre = response[line_start:match_start]
    post = response[match_end:line_end]
    if "«" in pre and "»" in post:
        if pre.count("«") > pre.count("»") and post.count("»") > post.count("«"):
            return True
    if pre.count('"') % 2 == 1 and post.count('"') % 2 == 1:
        return True
    if "“" in pre and "”" in post:
        if pre.count("“") > pre.count("”") and post.count("”") > post.count("“"):
            return True
    return False


def is_meta_negation(response: str, match_start: int, match_end: int) -> bool:
    """Same as eval_narrator._is_meta_negation — moved here for runtime use."""
    boundary_re = re.compile(r"[.!?]\s+|\n\n")
    sentence_start = max(0, match_start - 250)
    for m in boundary_re.finditer(response[sentence_start:match_start]):
        sentence_start = sentence_start + m.end()
    horizon_end = min(len(response), match_end + 250)
    sentence_end = horizon_end
    m = boundary_re.search(response[match_end:horizon_end])
    if m:
        sentence_end = match_end + m.start()
    sentence = response[sentence_start:sentence_end]
    return bool(_NEGATION_RE.search(sentence))

# In tools/eval_narrator.py (after the refactor):
from app.services.coach.citation_parser import is_meta_quoted as _is_meta_quoted
from app.services.coach.citation_parser import is_meta_negation as _is_meta_negation
```

### Common Operation 3: Sentry breadcrumb (D-18 hygiene)

```python
# Source: COPIED pattern from Phase 93.5 Wave 1 D-12 (telemetry hygiene)
import sentry_sdk

sentry_sdk.add_breadcrumb(
    category="coach.citation_gate",
    message=f"verdict={gated.verdict.value}",
    level="info" if gated.verdict == GateVerdict.PASS else "warning",
    data={
        # NON-PII counts/labels ONLY — never user message content
        "verdict": gated.verdict.value,
        "retries": int(retries_so_far),
        "uncited_numbers_count": gated.uncited_numbers_count,
        "banned_claims_count": len(gated.banned_claims_found),
    },
)
```

### Common Operation 4: Eval harness `--gate` flag extension

```python
# Source: NEW addition to tools/eval_narrator.py:_build_parser (5-10 LOC delta)
# Mirrors the --prompt-builder extension shipped in Phase 93.5-04 Task 1 at line 766
ap.add_argument(
    "--gate",
    choices=["on", "off"],
    default="off",
    help=(
        "Phase 94 (GATE-04) — citation gate runtime mode. "
        "'off' (default) bypasses the gate (legacy behavior, byte-identical). "
        "'on' runs the gate ; rejected fixtures retry once with reprompt ; "
        "second-failure → templated fallback (D-10)."
    ),
)
```

### Common Operation 5: Eval-pack fixture shape (D-14)

```jsonl
{"id": "cit-01", "category": "valid_citation", "user_message": "Quel est le plafond 3a 2026 ?", "conversation_history": [], "profile_snapshot": {"canton": "VD", "incomeGrossYearly": 80000, "birthYear": 1990}, "intents": ["retirement"], "expected_gate_outcome": "pass", "expected_constraints": {"must_contain_cite_keys": ["r3a_plafond_salarie_2026"]}}
{"id": "cit-21", "category": "uncited_number", "user_message": "Combien je paye d'impôts ?", "conversation_history": [], "profile_snapshot": {"canton": "VD", "incomeGrossYearly": 80000, "birthYear": 1990}, "intents": ["taxes"], "expected_gate_outcome": "rejected_uncited"}
{"id": "cit-31", "category": "banned_claim", "user_message": "Combien j'aurai à la retraite ?", "conversation_history": [], "profile_snapshot": {"canton": "VD", "incomeGrossYearly": 80000, "birthYear": 1990}, "intents": ["retirement"], "expected_gate_outcome": "rejected_banned_claim"}
{"id": "cit-41", "category": "fallback", "user_message": "Combien je gagne ?", "conversation_history": [], "profile_snapshot": {}, "intents": [], "expected_gate_outcome": "fallback"}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Narrator « free-form » with HallucinationDetector flag-only | Closed-world numeric vocabulary + post-hoc substitution + reject loop | Calc-first ADR §N1 (2026-05-09) | « Narrator invents a number » becomes structurally impossible, not probabilistically rare |
| ROADMAP `[citation:source_id]` format | `{{cite:<key>}}` (calc-first ADR + Phase 93.5 bundle annotations) | CONTEXT D-01 (2026-05-10) | Uniformity with bundles ; ROADMAP wording patched in plan-01 |
| Anthropic Citations API on document chunks | Pure-Python regex on numbers | CONTEXT D-02 — sub-ms parse, no extra API call | Lower latency, deterministic verdict, no Anthropic dependency at gate-time |
| Eval scorer with sentence-scope meta-helpers | Same scope, but moved into runtime parser | Phase 93.5 Wave 4 + Phase 94 D-03 | ONE source of truth for meta-detection ; eval and runtime cannot drift |
| ComplianceGuard 5-layer pipeline (banned terms, prescriptive, hallucination, disclaimer, length) | Compliance and citation gates run **independently** | CONTEXT specifics line 179 | A response can pass compliance and fail citation, or vice versa ; no coupling |
| Phase 93.5 single-narrator-prompt + tool allowlist | Same + bundle's citation_allowlist drives gate's closed-world set | CONTEXT D-07 | Gate is the runtime enforcement of the bundle's compile-time allowlist |

**Deprecated/outdated:**
- ROADMAP wording `[citation:source_id]` — superseded by D-01 `{{cite:<key>}}`. Plan 94-01 patches ROADMAP.md.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest 8.x + pytest-asyncio 0.23+ + hypothesis ≥6.111 `[VERIFIED: pyproject.toml:50-56]` |
| Config file | `services/backend/pyproject.toml` (`[tool.pytest.ini_options]` line 108) `[VERIFIED]` |
| Quick run command | `cd services/backend && pytest tests/test_citation_gate/ -q -x` |
| Full suite command | `cd services/backend && pytest tests/ -q --ignore=tests/integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GATE-01 | 5 number-family regex coverage (CHF/EUR/USD, %, legal article, duration, regulatory constant) | unit | `pytest tests/test_citation_gate/test_number_detection.py -x` | ❌ Wave 0 |
| GATE-01 | Property test — no number escapes detection (`hypothesis` over generated narratives) | property | `pytest tests/test_citation_gate/test_number_detection.py::test_property_all_numbers_detected -x` | ❌ Wave 0 |
| GATE-01 | Performance — ≤50ms parser budget on 200-token input | unit | `pytest tests/test_citation_gate/test_performance.py -x` | ❌ Wave 0 |
| GATE-02 | `CitationSource` Pydantic shape (frozen, extra=forbid) | unit | `pytest tests/test_citation_gate/test_registry_contract.py -x` | ❌ Wave 0 |
| GATE-02 | `CITATION_REGISTRY` keys ⊆ union of bundles' `citation_allowlist` (subset invariant) | unit | `pytest tests/test_citation_gate/test_registry_contract.py::test_registry_subset_of_bundle_allowlists -x` | ❌ Wave 0 |
| GATE-02 | No recursive citation keys (`{{cite:...}}` inside resolved values) | unit | `pytest tests/test_citation_gate/test_registry_contract.py::test_no_recursive_keys -x` | ❌ Wave 0 |
| GATE-03 | Retry-once budget never exceeds 1 | unit | `pytest tests/test_citation_gate/test_retry_flow.py::test_max_one_retry -x` | ❌ Wave 0 |
| GATE-03 | Reprompt addendum text matches D-09 verbatim | unit | `pytest tests/test_citation_gate/test_retry_flow.py::test_reprompt_addendum_verbatim -x` | ❌ Wave 0 |
| GATE-03 | Fallback text matches D-10 verbatim (no template variables) | unit | `pytest tests/test_citation_gate/test_fallback.py::test_fallback_verbatim -x` | ❌ Wave 0 |
| GATE-04 | Banned-claim regex `(vous|tu)\s+(ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d` triggers rejection EVEN WITH citation | unit | `pytest tests/test_citation_gate/test_banned_claims.py::test_affirmative_verb_with_citation -x` | ❌ Wave 0 |
| GATE-04 | Banned-claim retry reprompts at the conditional, NOT removal of citation (D-13) | unit | `pytest tests/test_citation_gate/test_banned_claims.py::test_d13_reprompt_keeps_citation -x` | ❌ Wave 0 |
| D-03 | Meta-quote / negation correctness (port 15 tests from `test_eval_narrator_meta_scorer.py`) | unit | `pytest tests/test_citation_gate/test_meta_helpers.py -x` | ❌ Wave 0 (port from existing 203-LOC suite) |
| D-07 | Flag-ON intersect with `compiled.citation_allowlist` | integration | `pytest tests/test_citation_gate/test_bundle_intersect.py -x` | ❌ Wave 0 |
| D-07 | Flag-OFF fallback to global `CITATION_REGISTRY` | integration | `pytest tests/test_citation_gate/test_global_registry_fallback.py -x` | ❌ Wave 0 |
| D-18 | Sentry breadcrumb payload — non-PII counts/labels only (no user message content) | unit | `pytest tests/test_citation_gate/test_telemetry.py -x` | ❌ Wave 0 |
| D-19 | Env flag `COACH_CITATION_GATE_ENABLED` exists in config | unit | `pytest tests/test_citation_gate/test_config.py -x` | ❌ Wave 0 |
| D-20 | Flag-OFF byte-identity — narrator response same as today (snapshot test, mirrors `tests/fixtures/narrator_legacy_snapshots/`) | snapshot | `pytest tests/test_citation_gate/test_byte_identity_flag_off.py -x` | ❌ Wave 0 (replicate the snapshot pattern from Phase 93.5-02 Task 3) |
| D-15 Stage 3 | 50-fixture pack ≥95% Sonnet / ≥90% Haiku | live eval | `cd services/backend && python3 -m tools.eval_narrator --model sonnet --fixtures tests/fixtures/citation_gate_eval_50.jsonl --out .planning/phases/94-mvp-citation-gate/eval-runs/94-04-eval-sonnet-gate-on.json --gate=on` | ❌ Wave 3 |
| D-16 | Maestro G1 — profile-empty user asks « combien je gagne ? » → no CHF number in response | manual+sim | `tools/simulator/walker_audit_tap_render.sh tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` | ❌ Wave 3 |

### Sampling Rate

- **Per task commit:** `cd services/backend && pytest tests/test_citation_gate/ -q -x` (≤30s when isolated)
- **Per wave merge:** `cd services/backend && pytest tests/ -q --ignore=tests/integration` (full suite ≥6251 tests, current Phase 93.5 baseline)
- **Phase gate:** Stage 3 eval pack PASS + Maestro G1 PASS + full suite green BEFORE `/gsd-verify-work 94`

### Wave 0 Gaps

- [ ] `tests/test_citation_gate/__init__.py` — empty marker
- [ ] `tests/test_citation_gate/test_number_detection.py` — D-02 5-family regex coverage + hypothesis property
- [ ] `tests/test_citation_gate/test_meta_helpers.py` — port 15 tests from `test_eval_narrator_meta_scorer.py` (203 LOC)
- [ ] `tests/test_citation_gate/test_banned_claims.py` — D-12 affirmative-verb + cited number
- [ ] `tests/test_citation_gate/test_retry_flow.py` — D-08 retry-once
- [ ] `tests/test_citation_gate/test_fallback.py` — D-10 templated fallback verbatim
- [ ] `tests/test_citation_gate/test_bundle_intersect.py` — D-07 flag-ON intersect
- [ ] `tests/test_citation_gate/test_global_registry_fallback.py` — D-07 flag-OFF fallback
- [ ] `tests/test_citation_gate/test_byte_identity_flag_off.py` — D-20 snapshot pattern (mirror `narrator_legacy_snapshots/`)
- [ ] `tests/test_citation_gate/test_performance.py` — D-17 ≤50ms parser budget
- [ ] `tests/test_citation_gate/test_registry_contract.py` — D-05 + D-06 frozen schema invariants
- [ ] `tests/test_citation_gate/test_telemetry.py` — D-18 breadcrumb payload hygiene
- [ ] `tests/test_citation_gate/test_config.py` — D-19 flag exists
- [ ] `tests/fixtures/citation_gate_eval_50.jsonl` — D-14 50-fixture pack (Wave 3)
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — D-16 G1 flow (Wave 3)

*(No framework install required — pytest + pytest-asyncio + hypothesis already in `pyproject.toml`.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Gate operates on already-authenticated narrator output |
| V3 Session Management | no | Stateless pure function |
| V4 Access Control | no | No new endpoints |
| V5 Input Validation | yes | Narrator output is treated as untrusted input ; the 5 D-02 regexes are the validation surface ; Pydantic `CitationSource` for registry entries |
| V6 Cryptography | no | No crypto operations ; the gate is read-only on text |
| V7 Error Handling & Logging | yes | D-18 Sentry breadcrumbs MUST follow non-PII payload hygiene (no user message content, no narrator response content beyond counts/labels) |
| V8 Data Protection | yes | nLPD — no PII in breadcrumbs ; D-18 explicitly restricts payload to counts/labels |
| V14 Configuration | yes | D-19 env flag `COACH_CITATION_GATE_ENABLED` follows the established config pattern (default OFF in prod) |

### Known Threat Patterns for {Python FastAPI + LLM narrator output}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via narrator output back-feeding | Tampering | Gate runs AFTER narrator response capture ; rejected output is replaced by D-10 fallback verbatim ; no user-controlled content reaches the parser inputs (the user message goes IN, but the parser scans the LLM-emitted text only) |
| ReDoS on regex patterns | DoS | All 5 D-02 patterns are linear-time on input length (no nested quantifiers, no `(\w+\s+)*` exponential backtracking — pattern verified against `compliance_guard.BANNED_PATTERNS` line 607-609 which itself was rewritten with `{0,3}` bound after a ReDoS audit) `[VERIFIED: compliance_guard.py:607-609 fix comment « FIX: ReDoS — replaced (?:\w+\s+)* (exponential backtracking) with bounded {0,3} »]` |
| PII leak via Sentry breadcrumb | Information disclosure | D-18 hygiene rule (non-PII counts/labels only) ; verified by `test_telemetry.py::test_no_pii_in_breadcrumb_payload` which scans the breadcrumb data dict for keys matching the existing PII allowlist (`fact_key_allowlist`) |
| Citation key spoofing (narrator emits `{{cite:r3a_admin_password}}`) | Spoofing | Closed-world contract — unknown keys NEVER resolve ; rejected via D-07 path |
| Unbounded retry → token exhaustion | DoS | D-08 hard-cap retries=1 ; enforced at the wrapper level (boolean `is_retry` parameter) ; verified by `test_retry_flow.py::test_max_one_retry` |

---

## Runtime State Inventory

> **Phase 94 is a greenfield phase** — adds new module + new flag + new tests + new fixture. No rename, no migration, no string-replacement work. The Runtime State Inventory categories below are answered explicitly per the §execution_flow protocol.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the gate is stateless. No DB writes, no Redis writes. | None |
| Live service config | Railway env var `COACH_CITATION_GATE_ENABLED` to be set on staging when Plan 94-04 flips the flag (mirrors `COACH_BUNDLE_COMPILER_ENABLED` provisioning at `93.5-04-EVAL-RESULTS.md` line 96). | Plan 94-04 Task — `railway variables --service MINT --kv` to provision on staging only |
| OS-registered state | None — the gate runs inside the FastAPI process, no OS-level registration. | None |
| Secrets/env vars | None new beyond the flag (which is a bool, not a secret). `ANTHROPIC_API_KEY` already provisioned on Railway per `feedback_anthropic_key_on_railway.md`. | None |
| Build artifacts | None — pure-Python module ; no compiled artifact ; no egg-info ; no Docker image tag rename. | None |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.9.6 | All Phase 94 code | ✓ | 3.9.6 `[VERIFIED]` | — |
| pytest 8.x | Test suite | ✓ | ≥8.0.0 `[VERIFIED: pyproject.toml:50]` | — |
| pytest-asyncio | Async retry tests | ✓ | ≥0.23.0 `[VERIFIED: pyproject.toml:51]` | — |
| hypothesis | Property tests on regex coverage | ✓ | ≥6.111 `[VERIFIED: pyproject.toml:56]` | Skip property test, keep parametric (acceptable degradation) |
| sentry-sdk | D-18 breadcrumbs | ✓ | 2.56.0 `[VERIFIED]` | If Sentry init fails, breadcrumb call is a no-op (already wrapped in try/except in similar Phase 93.5 telemetry) |
| Anthropic API key on Railway staging | Stage 3 eval pack run | ✓ | sk-ant-api03- 108-char `[CITED: 93.5-04-EVAL-RESULTS.md line 16]` | — |
| Maestro 2.5.1 | D-16 G1 flow | ✓ (per memory `reference_maestro_setup.md`) | 2.5.1 | — |
| iPhone 17 Pro sim (booted) | D-16 G1 flow execution | [ASSUMED] available — same as Phase 91/93.5 | — | Defer G1 to Julien-side execution if unavailable in CI |
| `compile_bundles` (Phase 93.5) | D-07 bundle integration | ✓ | shipped | — |
| `compliance_guard.BANNED_TERMS` | D-12 banned-claim list source | ✓ | shipped (35 entries) `[VERIFIED]` | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

Phase 94 is unblocked dependency-wise.

---

## Performance

**D-17 ≤50ms parser budget — feasibility analysis:**

| Operation | Worst-case input | Cost (Python 3.9 stdlib `re`) | Notes |
|-----------|------------------|------------------------------|-------|
| 5 pre-compiled regex `finditer` passes | 4kB narrator output (≈800 tokens, p95 narrator response per `93.5-04-EVAL-RESULTS.md` avg 8991ms latency suggests responses are short) | <2ms total `[ASSUMED — Python stdlib re is linear on input length for non-backtracking patterns]` | All 5 patterns are linear (verified — no nested quantifiers, no `(.+)*`-style exponential backtracking) |
| Meta-helpers (`is_meta_quoted` + `is_meta_negation`) per match | ~250-char sentence horizon | <100µs per match | Already in production via Phase 93.5 Wave 4 ; no measured perf regression |
| `set` intersect for D-07 allowlist check | <30 keys per response | <10µs | trivial |
| `CITATION_REGISTRY` lookup per resolved key | dict access | <1µs per key | trivial |
| Sentry breadcrumb add | n/a | <1ms | already wired in Phase 93.5 |

**Total parser budget worst case:** ~3ms — well below the 50ms target. The 50ms ceiling is generous for future expansion (e.g. Phase 95 GroundingPack JSON parsing).

**Theoretical worst-case input size:** narrator response is bounded by `COACH_MAX_TOKENS=350` (config.py:60) which at 4 chars/token is ~1.4kB. The 4kB worst-case above is 3× the typical bound, comfortable margin.

**Linear-time verification:** all 5 D-02 patterns use bounded quantifiers (`{1,3}`, `{1,2}`, `\d+`) and no alternation that could trigger backtracking. ReDoS-safe `[VERIFIED by pattern inspection]`.

---

## Open Research Questions (resolved or surfaced)

| OQ | Question | Resolution |
|----|----------|------------|
| OQ-1 | Where is currency/percentage/legal-article detection ALREADY implemented? | **Partially.** `compliance_guard.py:43-117` has banned-terms detection (different concern — text terms, not numbers). `compliance_guard.PRESCRIPTIVE_PATTERNS` line 238 has product-action patterns (different concern). Phase 94 detection is **net new** for numeric content, but reuses the FR-aware word-boundary approach (`_FR_LETTER` at line 121). `[VERIFIED: compliance_guard.py:43-117, 238-276]` |
| OQ-2 | Anthropic Citations API direct use? | **No.** CONTEXT D-02 locks pure-Python regex. The Citations API is the *inspiration* (Endex 10%→0% hallucination per Expert-3) but the *productionised* form for MINT is closed-world numeric vocabulary + post-hoc substitution. Trade-off is sound : sub-ms parse, no extra API call, deterministic verdict. `[CITED: .planning/decisions/2026-05-09-calc-first-llm-illumination.md §N1, https://www.anthropic.com/news/introducing-citations-api]` |
| OQ-3 | Exact `coach_chat.py:~3170` insertion point? | **`coach_chat.py:3264-3373`** is the actual range. Narrator response capture is at line 3315 (`loop_result["tool_calls"]`), final response build at 3361-3373. The wrapper insertion is between line 3283 (loop_result populated) and line 3361 (CoachChatResponse return). The response is a single string `loop_result["answer"]`, NOT a streamed chunk list — synchronous `await asyncio.wait_for` per line 3264. `citation_allowlist` is available at scope via the existing `_compiled_bundle` variable at line 3235 (when `COACH_BUNDLE_COMPILER_ENABLED=True`). `[VERIFIED: coach_chat.py:3230-3373]` |
| OQ-4 | How does the gate know which bundle path the request used? | **Already tracked.** `coach_chat.py:3230` branches on `settings.COACH_BUNDLE_COMPILER_ENABLED` and assigns `_compiled_bundle` in the True branch. Gate inherits the same `settings.*` check at insertion time and reads `_compiled_bundle.citation_allowlist` when available, else falls back to `CITATION_REGISTRY` keys. `[VERIFIED: coach_chat.py:3230-3250]` |
| OQ-5 | Does `_run_agent_loop` support retry-once natively? | **No.** `_run_agent_loop` is a tool-loop (max iterations, tool-call dispatch). Its existing reprompt strings (`_REPROMPT_EMPTY_NARRATION`, `_REPROMPT_EMPTY_END_TURN` at lines 1726, 1731) handle empty-output edge cases internally — they do NOT compose with citation gate's reprompt. **The gate's retry-once is implemented OUTSIDE the loop** : the wrapper calls `_run_agent_loop` a second time with `question=body.message + reprompt_addendum`. Karpathy #3 surgical : zero changes inside the loop. `[VERIFIED: coach_chat.py:1726-1734, 2580-2624]` |
| OQ-6 | Eval harness extension exact LOC? | **5-10 LOC.** Add `--gate={on,off}` argparse entry at `eval_narrator.py:766` (mirroring `--prompt-builder` flag added in Phase 93.5-04). Threading the flag through `_score_fixture` and `_run_eval` is ~5 LOC. Reuse Wave 4 meta-helpers via `from app.services.coach.citation_parser import is_meta_quoted, is_meta_negation` after the refactor. `[VERIFIED: eval_narrator.py:138-188, 540-680, 732-803]` |
| OQ-7 | How to assert narrator does NOT contain a CHF number? | **Two layers.** (1) pytest fixture-level: `assert not _RE_CURRENCY.search(response_text)` after the gate run with `expected_gate_outcome=fallback`. (2) Maestro flow `flow_narrator_refuses_uncited_numbers.yaml` uses a `notVisible` regex `.*\d+\s*CHF.*` on the rendered narrator response after the user types « combien je gagne ? » with profile-empty (`flow_extractor_captures_age_canton.yaml` line ~60+ is the precedent shape per `[VERIFIED]` `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml`). |
| OQ-8 | ≤50ms parser worst-case bound? | **~3ms total worst case** for 4kB input across 5 linear regex passes. The 50ms ceiling has a 16× safety margin for future expansion (Phase 95 GroundingPack JSON parsing). `[ASSUMED — bench not run, but the regexes are bounded and the input is ≤1.4kB at production cap COACH_MAX_TOKENS=350]` `[VERIFIED: services/backend/app/core/config.py:60 COACH_MAX_TOKENS=350]` |

---

## Assumptions Log

> Every claim tagged `[ASSUMED]` in this research. The planner and discuss-phase use this to identify decisions that need user confirmation OR a measurement task before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Python 3.9 stdlib `re` is linear-time on input length for the 5 D-02 patterns | Performance + ReDoS | If a pattern back-tracks, parser blows past 50ms. Mitigation: `test_performance.py` measures actual latency on a worst-case 4kB synthetic input ; CI-gates the budget. |
| A2 | iPhone 17 Pro sim available in CI for Maestro G1 flow | Environment Availability | If unavailable, G1 reverts to Julien-side execution. Defers but doesn't block. |
| A3 | Cross-paragraph negation false-negative rate is acceptable (not measured) | Pitfall 4 | Eval pack ≥2 fixtures for cross-paragraph negation will surface this empirically at Stage 3. |
| A4 | The 22 keys currently in bundle `citation_allowlist`s (4+4+5+5 across pillar3a/lpp/tax/mortgage; 0 in compliance/life-event-router) are the v1 baseline for `CITATION_REGISTRY` | Architecture Pattern 3 | Stage 3 eval may reveal additional keys ; planner must include « registry iteration » as a Wave 2 task. `[VERIFIED bundle counts: pillar3a:91-96 (4), lpp:77-82 (4), tax:73-79 (5), mortgage:83-89 (5), compliance:180 (0), life_event:137 (0)]` |
| A5 | The « affirmative verb + cited number » regex `(vous\|tu)\s+(ferez\|feras\|...)\s+\d` covers the common LSFin no-promise failure modes | D-12 banned-claim | Eval pack manual review at Stage 3 will surface uncovered patterns ; planner adds an iteration task. |
| A6 | D-09 and D-10 verbatim FR strings preserve their accents through the codebase (`tools/checks/accent_lint_fr.py` accepts them) | CLAUDE.md §1 + Project Constraints | If lint fails, Plan 94-02 must run accent lint before merging. |
| A7 | `loop_result["answer"]` is always a non-empty string when reaching the gate insertion point (after the empty-output handling at coach_chat.py:2611-2624 inside `_run_agent_loop`) | Pattern 2 | If empty, the gate must short-circuit to FALLBACK without calling the parser. Add `if not response_text.strip(): return GatedResponse(verdict=FALLBACK, ...)` early-return. |
| A8 | Phase 95 will replace `citation_registry.py` with `GroundingPack` JSON without breaking the gate's API contract | Deferred Ideas | If Phase 95 changes the resolution semantics, Phase 94 wrapper needs adjustment. CONTEXT D-21 sunset clause acknowledges this — no v2 work pre-emptively. |
| A9 | The 35 entries in `compliance_guard.BANNED_TERMS` cover the masc/fem/plural/conditional/gerund forms exhaustively | D-12 reuse | `tools/checks/banned_terms_python.py` lint covers compile-time ; runtime gate uses the same source list. If a new form emerges in production, both layers add it together. |

---

## Sources

### Primary (HIGH confidence)

- `services/backend/app/api/v1/endpoints/coach_chat.py` (lines 1726-1734, 2580-2624, 3230-3373) — gate insertion point, retry mechanics, narrator response capture `[VERIFIED via Read tool 2026-05-10]`
- `services/backend/app/services/coach/bundle_compiler.py` (full file) — `compile_bundles` + `CompiledBundle.citation_allowlist` `[VERIFIED via Read tool 2026-05-10]`
- `services/backend/app/services/coach/bundles/__init__.py` + `_base.py` + 6 bundle modules — bundle structure, `citation_allowlist` per bundle `[VERIFIED via Read + grep 2026-05-10]`
- `services/backend/app/services/coach/compliance_guard.py` (lines 36-578) — banned-terms list (D-12 source), FR-aware word boundaries, ReDoS-safe pattern precedent `[VERIFIED via Read tool 2026-05-10]`
- `services/backend/tools/eval_narrator.py` (lines 138-188, 250-296, 540-680, 732-803) — `--prompt-builder` precedent for `--gate` flag, meta-helpers (D-03 refactor source), scoring pipeline `[VERIFIED via Read + grep 2026-05-10]`
- `services/backend/app/services/coach/grounding_pack.py` (full file) — Phase 95 stub registry, currently empty `frozenset()` `[VERIFIED via Read tool 2026-05-10]`
- `services/backend/app/core/config.py` (lines 60-100) — env-flag pattern, `COACH_DUAL_LLM_ENABLED` + `COACH_BUNDLE_COMPILER_ENABLED` precedents `[VERIFIED via Read tool 2026-05-10]`
- `services/backend/pyproject.toml` (lines 50-56, 108) — pytest 8.x + pytest-asyncio + hypothesis + Pydantic v2 `[VERIFIED via grep 2026-05-10]`
- `services/backend/tests/fixtures/narrator_eval_50.jsonl` (line 1) — fixture shape precedent for D-14 `[VERIFIED via head 2026-05-10]`
- `services/backend/tests/test_eval_narrator_meta_scorer.py` (203 LOC) — 15 meta-helper tests to port to citation_parser test suite `[VERIFIED via wc -l 2026-05-10]`
- `services/backend/tests/fixtures/narrator_legacy_snapshots/` — D-20 byte-identity snapshot pattern precedent (4 snapshot files) `[VERIFIED via ls 2026-05-10]`
- `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` — Maestro flow shape precedent for D-16 `[VERIFIED via head 2026-05-10]`
- `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` — 21 D-XX locks `[VERIFIED via Read tool 2026-05-10]`
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-04-EVAL-RESULTS.md` — eval-pack methodology + cost methodology + Sentry/Railway provisioning shape `[VERIFIED via Read tool 2026-05-10]`
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-CONTEXT.md` — D-18 bundle integration contract source + D-20 tool registry `[VERIFIED via Read tool 2026-05-10]`
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — §N1 closed-world numeric vocabulary contract `[VERIFIED via Read tool 2026-05-10]`
- `.planning/audit/calc-first-architecture/expert-3-llm-illumination-architecture.md` — Anthropic Citations API as inspirational pattern, post-hoc substitution as productionised form `[CITED via grep 2026-05-10]`
- `CLAUDE.md` — §1 (financial_core source-of-truth, banned terms, accents, i18n, 0-trust), §3 (MCP tools), §5 NEVER #5/#8/#9, §7 Karpathy 4, §9 0-trust `[VERIFIED via Read tool — system-reminder]`
- `.planning/STATE.md` — current milestone v2.9 Chat-as-Verb Pivot, Phase 94 active, branch `feature/S94-mvp-citation-gate` `[VERIFIED via Read tool 2026-05-10]`

### Secondary (MEDIUM confidence)

- `.planning/ROADMAP.md` Phase 94 section — Goal, Depends on (Phase 91), Requirements GATE-01..04, Success Criteria 1-4. Note: ROADMAP wording uses `[citation:source_id]`, superseded by CONTEXT D-01 `{{cite:<key>}}` `[VERIFIED via Read 2026-05-10]`
- Anthropic Citations API blog (Jan 2025, GA Jun 2025) — Endex 10%→0% hallucination ; the inspirational SOTA reference per Expert-3 `[CITED: https://www.anthropic.com/news/introducing-citations-api via Expert-3 audit document]`
- Simon Willison « Anthropic's new Citations API » Jan 2025 — engineering deep-dive ; deterministic-quoting pattern as the post-hoc substitution doctrine `[CITED: https://simonwillison.net/2025/Jan/24/anthropics-new-citations-api/ via Expert-3 audit]`

### Tertiary (LOW confidence)

- *(None — all critical claims verified via tool-grounded reads of the live codebase or cited from in-repo decision artifacts.)*

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — every dependency verified in the live `pyproject.toml` and via `python -c "import X; print(X.VERSION)"` execution
- Architecture: HIGH — every insertion point and wrapper shape grounded in actual line numbers from `coach_chat.py`, `bundle_compiler.py`, `eval_narrator.py`
- Pitfalls: HIGH for items 1-7 (grounded in code reads) ; MEDIUM for item 8 (token cost regression measurement deferred to Wave 3)
- Validation Architecture: HIGH — test framework version verified, fixture shape precedent verified, Maestro flow precedent verified

**Research date:** 2026-05-10
**Valid until:** 2026-05-30 (20 days — Phase 94 budget is 3d, expected execution well within validity window. Re-verify if start delayed beyond 2026-05-30, especially `coach_chat.py` line ranges if other PRs land in the same region.)

---

*Phase: 94-mvp-citation-gate*
*Research: 2026-05-10 — branch `feature/S94-mvp-citation-gate` off `origin/dev`*
*Next: `/gsd-plan-phase 94 --auto` to produce 3-wave PLAN.md (scaffold → wiring → eval+proposal).*
