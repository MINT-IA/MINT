---
phase: wave-1c-coach-tool-dispatch-rca
wave: A2
parent_waves: [A, A1]
depends_on:
  - wave-1c-A-PLAN.md   # PR #634 sha bc020925 MERGED 2026-05-15T17:01:05Z
  - wave-1c-A1-PLAN.md  # PR #637 sha 363a4ce8 MERGED 2026-05-15T18:56:12Z
autonomous: true
files_modified:
  - services/backend/app/api/v1/endpoints/coach_chat.py
wave1c_decisions_addressed: [D-08, D-09, D-10, D-11, D-12]
branch: feature/wave-1c-A2-rag-suppression-tool-eligible
target_branch: dev
must_haves:
  truths:
    - "When detected_intents intersects {retirement, taxes, debt, housing, family, career} AND `stripped_tools` contains at least one of {get_retirement_projection, get_budget_status, get_cross_pillar_analysis, get_couple_optimization, get_cap_status}, the orchestrator.query is called with n_results=0 — meaning context_chunks=[] reaches LLMClient._build_augmented_message, which already short-circuits to passthrough (line 157-158)."
    - "Net effect: the « Contexte de la base de connaissances MINT » prefix + the 3 redirect chunks (« consulte ahv-iv.ch », « certificat LPP », « extrait de compte ») disappear from the user message. The user's actual question becomes the only thing in the message."
    - "Educational queries (no tool-eligible intent OR no tool-eligible tool advertised) preserve current RAG behavior (n_results=5)."
    - "PR Wave A2 merges to dev only AFTER CI green; dev→staging follows; orchestrator re-runs probe."
  artifacts:
    - path: services/backend/app/api/v1/endpoints/coach_chat.py
      provides: "_TOOL_ELIGIBLE_INTENTS frozenset + _TOOL_ELIGIBLE_TOOL_NAMES frozenset at module level (sister to _INTENT_KEYWORDS); n_results parameter threaded through _call_with_fallback (added to signature, default 5); call-site at line ~3510 computes n_results based on detected_intents ∩ _TOOL_ELIGIBLE_INTENTS AND stripped_tools ∩ _TOOL_ELIGIBLE_TOOL_NAMES; orchestrator.query receives n_results=0 when both intersections are non-empty."
      exports: ["_TOOL_ELIGIBLE_INTENTS", "_TOOL_ELIGIBLE_TOOL_NAMES"]
  key_links:
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py:_run_agent_loop call site (~line 3510)"
      to: "_call_with_fallback(n_results=...)"
      pattern: "n_results computed inline as `0 if (detected_intents & _TOOL_ELIGIBLE_INTENTS and any(t.get('name') in _TOOL_ELIGIBLE_TOOL_NAMES for t in (stripped_tools or []))) else 5`"
    - from: "_call_with_fallback(n_results=...)"
      to: "orchestrator.query(n_results=...)"
      pattern: "kwarg threaded through _do_query closure"
---

<objective>
Cut the RAG retrieval when the user's intent maps to an available tool. This kills the « consulte ahv-iv.ch » redirect signal that beat 3 doctrine iterations (Wave A + A1), without touching the doctrine, position, or `tool_choice` knobs. The architectural recommendation came from `architect-review` panel agent (engram obs id 86): the cleanest insertion is at the orchestration layer in `_run_agent_loop`, where intent classification + tool advertisement are both already available, with no signature changes downstream — `LLMClient._build_augmented_message` at line 157-158 already returns `user_message` unchanged when `context_chunks` is empty.

This plan is the SHORT-TERM step (A) of the wiki-direction pivot Julien locked in 2026-05-15:
- A2 (this plan) — cut legacy RAG for tool-eligible intents.
- A3 (separate plan, post-A2 probe) — audit `get_*` tools for required inputs + missing_fields handshake (narrator asks user → save to wiki → re-invoke).
- RAG → Wiki migration — separate phase, post-Wave 1c.

Output: 1 PR on new branch `feature/wave-1c-A2-rag-suppression-tool-eligible` targeting `dev`, ~30 LOC net diff, 1 file. Tests for the new gating ship in this same PR (small scope).
</objective>

<execution_context>
Backend-only PR. No Flutter touch. No prompt copy edit (no LSFin / accent concerns; the only French strings touched are constant names and code comments).

Pre-push panel: NOT REQUIRED for this PR — the panel was already convened upstream (engram obs ids 82/83/84/85/86) and converged on this exact architectural surface (architect-review's verdict). Run lints + pytest before push as usual.

The narrator path goes through `app.services.rag.llm_client.LLMClient` (not `services/llm/router.py` per the false D-06.3 assumption). Filter signal is already plumbed: `_classify_user_intent` runs at line 3922 of coach_chat.py, returns `detected_intents` set; this set is passed to `_run_agent_loop` at line 3641 (already in scope at the call site).
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A1-PLAN.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/user_message_a1_2105.txt
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/rag/llm_client.py
@services/backend/app/services/rag/orchestrator.py

<diagnosis_evidence>
Wave A1 deployed to staging at 2026-05-15T19:04:51Z (sha 472c9aa7). MANDATE at 3 positions in system prompt confirmed via WAVE1C_PAYLOAD log (50.6%, 67.4%, 99.2%). Probe response: `citationChips: None`, `toolCalls: None`, message « Je vais calculer ta projection... » — same deferral pattern as Wave A.

User message dump (`.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/user_message_a1_2105.txt`): 1486 chars total. Of those, 1366 chars are RAG-prepended educational chunks. Three chunks all literally tell the model « consulte ahv-iv.ch / certificat LPP / extrait de compte ». The 120 actual question chars sit at the END.

Sonnet 4.5 follows the most-actionable, most-recent instruction. The « go consult external » directive in the user message wins against the system-prompt MANDATE (per `prompt-engineer` engram obs id 83 + `nlp-engineer` obs id 84 citations to FaithEval ICLR 2025 + Context-faithful Prompting EMNLP 2023). Doctrine prompts cannot beat counterfactual context.

This plan removes the competing signal at its source — the orchestration layer that already knows about both intent and tools.
</diagnosis_evidence>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task A2.1 — Add _TOOL_ELIGIBLE_INTENTS + _TOOL_ELIGIBLE_TOOL_NAMES frozensets at module level</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1500-1565 (`_INTENT_KEYWORDS` definition + `_classify_user_intent` — confirm the canonical 6 intent labels: debt, housing, family, career, retirement, taxes)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 269-340 (CITATION_REGISTRY equivalent) — find or grep for `get_retirement_projection`, `get_budget_status`, etc. tool names to confirm canonical naming
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 4000-4030 (where `tools = ...` is assembled before the agent loop) — confirm tool dict shape (each item has `name` key)
  </read_first>
  <behavior>
    - Test 1: `from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_INTENTS` returns a frozenset.
    - Test 2: `_TOOL_ELIGIBLE_INTENTS` contains at minimum {"retirement"} (the proven-broken case from the probe). Recommended full set: {"retirement", "taxes", "debt", "housing", "family", "career"} — same 6 labels as `_INTENT_KEYWORDS` keys, since each maps to a life-event tool.
    - Test 3: `from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_TOOL_NAMES` returns a frozenset containing at minimum {"get_retirement_projection", "get_budget_status", "get_cross_pillar_analysis", "get_couple_optimization", "get_cap_status"}.
    - Test 4: lints exit 0 on the touched file.
  </behavior>
  <action>
    Place these constants ADJACENT to `_INTENT_KEYWORDS` (around line 1500-1565 in the same module). Keep them as `frozenset` (immutable, hashable, idiomatic for "this is a closed allowlist").

    ```python
    # Wave 1c-A2 (2026-05-15) — gating set for the orchestration-layer RAG cut.
    # When detected_intents intersects this set AND the agent-loop tools include
    # at least one entry from _TOOL_ELIGIBLE_TOOL_NAMES, n_results is set to 0
    # (RAG retrieval is suppressed) so the « Contexte de la base de connaissances
    # MINT » preamble + redirect chunks don't beat the system-prompt tool_use
    # MANDATE. See `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A2-
    # PLAN.md` and engram obs id 81 (RAG-context root cause) + obs id 86
    # (architect-review surface verdict).
    _TOOL_ELIGIBLE_INTENTS: frozenset[str] = frozenset({
        "retirement",  # → get_retirement_projection (proven broken in probe)
        "taxes",       # → get_3a_cap / cross_pillar deductions
        "debt",        # → cross_pillar consolidation / amortization scenarios
        "housing",     # → cross_pillar (LPP retrait pour résidence)
        "family",      # → couple_optimization
        "career",      # → cross_pillar (LPP rachat)
    })

    _TOOL_ELIGIBLE_TOOL_NAMES: frozenset[str] = frozenset({
        "get_retirement_projection",
        "get_budget_status",
        "get_cross_pillar_analysis",
        "get_couple_optimization",
        "get_cap_status",
        # NOTE: retrieve_memories is NOT in this set — it's a Wave 1b memory
        # retrieval tool, not a financial calculation. Its presence in the
        # advertised tools should NOT trigger RAG suppression.
    })
    ```
  </action>
  <acceptance_criteria>
    - `python3 -c "from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_INTENTS, _TOOL_ELIGIBLE_TOOL_NAMES; assert 'retirement' in _TOOL_ELIGIBLE_INTENTS; assert 'get_retirement_projection' in _TOOL_ELIGIBLE_TOOL_NAMES"` exits 0 (run from `services/backend`).
    - Both constants are `frozenset[str]`.
    - Lints exit 0 on coach_chat.py.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -c "from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_INTENTS, _TOOL_ELIGIBLE_TOOL_NAMES; assert isinstance(_TOOL_ELIGIBLE_INTENTS, frozenset) and isinstance(_TOOL_ELIGIBLE_TOOL_NAMES, frozenset); assert 'retirement' in _TOOL_ELIGIBLE_INTENTS and 'get_retirement_projection' in _TOOL_ELIGIBLE_TOOL_NAMES"</automated>
  </verify>
  <done>
    Both frozensets exist + importable + contain the minimum required entries.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A2.2 — Thread n_results kwarg through _call_with_fallback → _do_query → orchestrator.query</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2141-2212 (current `_call_with_fallback` signature + body — confirm it does NOT currently take n_results, and that orchestrator.query is called with default n_results=5)
    - services/backend/app/services/rag/orchestrator.py lines 37-100 (`query` method signature — confirm `n_results: int = 5` is the existing kwarg)
  </read_first>
  <behavior>
    - Test 1: `_call_with_fallback` signature includes `n_results: int = 5` kwarg (default preserves current behavior for non-tool-eligible intents).
    - Test 2: The kwarg is passed through to `_do_query` closure → `orchestrator.query(n_results=...)`.
    - Test 3: Default behavior unchanged — call `_call_with_fallback(orchestrator, ..., n_results=5)` and assert it's threaded through.
    - Test 4: All existing call sites of `_call_with_fallback` continue to work (default n_results=5 if not specified).
    - Test 5: Backend pytest exits 0 (no regression).
  </behavior>
  <action>
    1. Modify `_call_with_fallback` signature at line 2141 to add `n_results: int = 5` after `conversation_history`. Update the docstring's "Args" section to document the new kwarg.

    2. Inside the function body, modify `_do_query` closure at lines 2186-2199 to pass `n_results=n_results` to `orchestrator.query`:

       ```python
       async def _do_query(q_model: str, q_history):
           return await orchestrator.query(
               question=question,
               api_key=api_key,
               provider=provider,
               model=q_model,
               profile_context=profile_context,
               language=language,
               tools=tools,
               system_prompt=system_prompt,
               user_id=user_id,
               conversation_history=q_history,
               n_results=n_results,  # Wave 1c-A2 plumbing
           )
       ```
  </action>
  <acceptance_criteria>
    - `grep -E "n_results.*=.*n_results" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 line in `_do_query`.
    - `grep -E "n_results: int = 5" services/backend/app/api/v1/endpoints/coach_chat.py` returns 1 line in `_call_with_fallback` signature.
    - Backend pytest full suite exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/ -q -x | tail -3</automated>
  </verify>
  <done>
    n_results kwarg threaded through, all existing call sites still work, no regression.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A2.3 — Compute n_results at agent loop call site based on detected_intents ∩ tool eligibility</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 3490-3530 (the existing call site of `_call_with_fallback` inside `_run_agent_loop`)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 3430-3460 (the `_run_agent_loop` signature — confirm `detected_intents` is in scope)
    - services/backend/app/api/v1/endpoints/coach_chat.py around line 4030 (where `stripped_tools` is built)
  </read_first>
  <behavior>
    - Test 1: When `detected_intents ∩ _TOOL_ELIGIBLE_INTENTS` is non-empty AND `stripped_tools` contains at least one entry whose `name` is in `_TOOL_ELIGIBLE_TOOL_NAMES`, the call site computes `n_results = 0` and passes it to `_call_with_fallback`.
    - Test 2: Otherwise, `n_results = 5` (default preserved).
    - Test 3: A new unit test in `services/backend/tests/test_coach_chat_tool_use_gate.py` mocks the inputs and asserts the gating logic.
    - Test 4: Backend pytest exits 0.
  </behavior>
  <action>
    1. Insert n_results computation at line ~3505 (just before the `_call_with_fallback` invocation), inside the agent-loop iteration:

       ```python
       # Wave 1c-A2 — RAG suppression for tool-eligible intents.
       # When the user's intent maps to an advertised tool, suppress legacy
       # RAG retrieval so its « consulte ahv-iv.ch » redirect chunks don't
       # beat the system-prompt tool_use MANDATE. The empty-context_chunks
       # path in LLMClient._build_augmented_message (line 157-158) is a
       # passthrough — the user message reaches the LLM unaugmented.
       _intent_match = bool((detected_intents or set()) & _TOOL_ELIGIBLE_INTENTS)
       _tool_match = any(
           (t.get("name") if isinstance(t, dict) else None) in _TOOL_ELIGIBLE_TOOL_NAMES
           for t in (stripped_tools or [])
       )
       _n_results_for_call = 0 if (_intent_match and _tool_match) else 5
       if _n_results_for_call == 0:
           logger.info(
               "wave1c_a2: RAG suppressed for tool-eligible intent — "
               "user=%s intents=%s tools=%s",
               (str(user_id)[:8] + "...") if user_id else "anon",
               sorted((detected_intents or set()) & _TOOL_ELIGIBLE_INTENTS),
               sorted([t.get("name") for t in (stripped_tools or [])
                       if isinstance(t, dict)
                       and t.get("name") in _TOOL_ELIGIBLE_TOOL_NAMES]),
           )

       result, degraded_meta = await asyncio.wait_for(
           _call_with_fallback(
               orchestrator,
               question=current_question,
               api_key=api_key,
               provider=provider,
               model=model,
               profile_context=profile_context,
               language=language,
               tools=stripped_tools,
               system_prompt=system_prompt,
               user_id=user_id,
               conversation_history=iter_history,
               n_results=_n_results_for_call,  # Wave 1c-A2
           ),
           timeout=AGENT_ITERATION_TIMEOUT_SECONDS,
       )
       ```

    2. Add unit test in `services/backend/tests/test_coach_chat_tool_use_gate.py`:

       ```python
       def test_tool_eligible_intents_frozenset_includes_retirement():
           from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_INTENTS
           assert "retirement" in _TOOL_ELIGIBLE_INTENTS
           assert isinstance(_TOOL_ELIGIBLE_INTENTS, frozenset)


       def test_tool_eligible_tool_names_includes_retirement_projection():
           from app.api.v1.endpoints.coach_chat import _TOOL_ELIGIBLE_TOOL_NAMES
           assert "get_retirement_projection" in _TOOL_ELIGIBLE_TOOL_NAMES
           assert "retrieve_memories" not in _TOOL_ELIGIBLE_TOOL_NAMES, (
               "retrieve_memories is a Wave 1b memory tool, not a financial "
               "calculation; it must NOT trigger RAG suppression"
           )


       def test_call_with_fallback_accepts_n_results_kwarg():
           import inspect
           from app.api.v1.endpoints.coach_chat import _call_with_fallback
           sig = inspect.signature(_call_with_fallback)
           assert "n_results" in sig.parameters
           assert sig.parameters["n_results"].default == 5
       ```
  </action>
  <acceptance_criteria>
    - `grep -E "_n_results_for_call" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2 lines (compute + pass).
    - The 3 new unit tests pass.
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0 with no regression vs Wave A1 baseline (6927 + 3 new = 6930 expected).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_chat_tool_use_gate.py tests/ -q | tail -5</automated>
  </verify>
  <done>
    Gating logic in place at the call site, unit tests pass, no regression.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task A2.4 — Open PR feature/wave-1c-A2-rag-suppression-tool-eligible → dev, monitor CI, merge on green</name>
  <files></files>
  <read_first>
    - CLAUDE.md §9 (0-trust)
    - Engram memory `feedback_pre_push_checklist`
    - Engram memory `feedback_no_wakeup_active_polling`
    - Engram memory `feedback_public_repo_discipline`
  </read_first>
  <behavior>
    - Pre-push: full pytest + lints exit 0.
    - PR opened on `feature/wave-1c-A2-rag-suppression-tool-eligible` → `dev`.
    - CI polled inline; merge on green via `gh pr merge --squash --delete-branch`.
    - dev → staging bundle PR opened.
    - 0-trust language in PR body: « PR opened » NOT « shipped » / « ready » / « works ».
  </behavior>
  <action>
    Same pattern as Wave A1's A1.4. Branch off `origin/dev`. Pre-push: pytest + lints. Push + PR (HEREDOC body — describe the architectural pivot from doctrine to orchestration-layer gating, cite engram obs ids 81/86 + the panel synthesis, name Wave A3 as the next planned step for missing-fields handshake). Poll CI inline. Merge on green. Open dev→staging bundle PR (orchestrator merges).

    PR title: `fix(wave-1c-A2): cut legacy RAG retrieval for tool-eligible intents (orchestration-layer gate)`

    PR body must mention:
    - Why doctrine fixes (Wave A + A1) failed: `_build_augmented_message` prepends RAG chunks that beat the system-prompt MANDATE per FaithEval / Context-faithful Prompting literature.
    - What this PR changes: 30-LOC orchestration-layer gate; uses existing `detected_intents` + `stripped_tools` to compute `n_results=0` when intent ∩ tool advertised. Empty-context_chunks path in `LLMClient._build_augmented_message:157-158` already short-circuits.
    - What this PR does NOT do: doesn't touch tool_choice (stays auto), doesn't touch the doctrine MANDATE (stays in place + harmless), doesn't touch the runtime gate or Sentry breadcrumb from Wave A.
    - Wave A3 (next plan) will audit `get_*` tools for required user-data inputs, add `missing_fields` handshake so narrator asks user → save to wiki → re-invoke (per Julien's wiki-direction reframe 2026-05-15).
    - 0-trust caveat per CLAUDE.md §9.5.
  </action>
  <acceptance_criteria>
    - PR Wave A2 MERGED to `dev` with non-null mergedAt.
    - dev→staging bundle PR opened.
    - All CI jobs `pass` at merge.
  </acceptance_criteria>
  <verify>
    <automated>echo "verified inline by orchestrator post-merge"</automated>
  </verify>
  <done>
    Wave A2 PR is MERGED to `dev`. dev→staging bundle PR opened (orchestrator handles re-probe + decision).
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-A2-01 | DoS | accidental n_results=0 for non-tool-eligible queries | mitigate | Default preserved at 5; gate requires BOTH intent ∩ tool match. Unit tests lock the conditional. |
| T-wave-1c-A2-02 | Quality regression | educational queries lose RAG context | accept | Educational queries by definition have no tool-eligible intent; gate doesn't fire. If a future intent classifier mislabels an educational query as `retirement`, RAG cuts AND the tool fails (no missing-fields handshake yet) → the narrator falls back to its own knowledge. Less ideal than RAG, but safer than the current loop. Wave A3 missing-fields handshake closes this gap. |
| T-wave-1c-A2-03 | Tampering | orchestration-layer gate disables RAG for actual user-supplied life-event keywords | accept | The intent classifier is heuristic (`_INTENT_KEYWORDS`), not user-controlled. Adversarial keywords like « retraite » in an unrelated question are a known false-positive of the classifier (orthogonal to A2). |
</threat_model>

<verification>
## Wave A2 close-out checks (run by orchestrator post-PR merge)

- G1 (live probe via curl per wave-1c-A-PLAN.md §verification) — orchestrator runs after dev→staging merges + Railway redeploys. Expected for the proven-broken question (« Quelle sera ma rente AVS et LPP… »):
  - **PRIMARY GOAL**: WAVE1C_PAYLOAD log shows the user message is the user's question ALONE (no « Contexte de la base de connaissances MINT » prefix, no « consulte ahv-iv.ch » chunks).
  - **DESIRED GOAL**: `toolCalls != null` (Sonnet actually invokes `get_retirement_projection`).
  - **ACCEPTABLE INTERMEDIATE**: Sonnet asks the user for missing data inputs (e.g. « quel est ton âge ? combien d'années de cotisation AVS ? quel est le solde de ton LPP ? ») WITHOUT redirecting to ahv-iv.ch. This validates the RAG-cut while signaling Wave A3 is needed.
- G3 (dev CI green) — `gh pr checks <N>` shows ALL jobs pass.
- G4 (regression suite) — `cd services/backend && python3 -m pytest tests/ -q` exits 0 with ≥6930 passing.
- G5 (LSFin + accent lint) — exit 0.

## Outcome branches

- **If probe shows toolCalls != null + chips render** → Wave B is unblocked. Orchestrator spawns Wave B executor.
- **If probe shows narrator asks for missing data instead of redirecting** → Wave A2 is mechanically successful (RAG cut works); Wave A3 (`get_*` tools missing-fields handshake + narrator save-to-wiki loop) is the next wave; Wave B blocked until A3.
- **If probe shows narrator STILL redirects to ahv-iv.ch** → either a) intent classifier didn't fire for this question (verify via WAVE1C_PAYLOAD inspection), or b) some other RAG path bypassed the gate. Wave A2.1 patch.
</verification>

<success_criteria>
- All 4 tasks A2.1–A2.4 executed.
- Branch `feature/wave-1c-A2-rag-suppression-tool-eligible` created from `origin/dev`.
- Each code task committed individually.
- wave-1c-A2-PLAN.md committed.
- Backend pytest + LSFin + accent lints exit 0.
- PR opened on `feature/wave-1c-A2-rag-suppression-tool-eligible` → `dev`, CI polled inline, merged via squash.
- dev → staging bundle PR opened.

**Wave A2 does NOT claim « shipped » or « works ».** Per CLAUDE.md §9.5, this is « PR opened + dev-merged ». The « works » claim is owned by the orchestrator's post-deploy live probe re-run + the WAVE1C_PAYLOAD log inspection (PRIMARY GOAL above).
</success_criteria>

<output>
After Wave A2 completes, this PLAN.md's status is « MERGED TO DEV — AWAITING LIVE PROBE RE-RUN ». The orchestrator handles dev→staging merge + Railway poll + probe + WAVE1C_PAYLOAD log inspection + decision (Wave B fire vs Wave A3 missing-fields handshake vs Wave A2.1 patch). Do NOT create a SUMMARY.md — the orchestrator composes the combined wave-1c-SUMMARY.md at phase close-out.
</output>
