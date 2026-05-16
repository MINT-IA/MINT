---
name: handoff-2026-05-16-calc-engine-v1
description: Session handoff 2026-05-16 → next session. State after Phase 96 KILL + calc-engine-v1 cadrage + 6-panel synthesis + W0 audit complete. Hypothèse C confirmed 86%. Wave 1 scope locked at "ALL REST endpoints, severity 3 first". A3 plan locked, awaiting /gsd-execute-phase. First action to type next session = §"FIRST COMMAND" below.
---

# Session handoff — 2026-05-16 → next session

## TLDR (read this first)

- **Phase 96 KILLED** (chat-as-verb pivot is dead). Direction restored : chat-first + widgets explorables inline ("Coach didactique vivant").
- **mint-calc-engine-v1 = next milestone** (v2.10 Lucidité Engine). 20 D-CE-XX decisions locked by 6 expert panels (11 overrides of prior PM recommendations).
- **W0 audit complete** : hypothesis C confirmed at 86 % (49/57 calculators ship WRONG numbers because `_user.profile` is never read at REST endpoints). 12 severity-3 blockers shipping wrong tax brackets to ~15-30 % of users by canton TODAY.
- **A3 plan locked** at sha `2e1060a5`, 7 tasks, 1848 lines, awaiting `/gsd-execute-phase` to ship the missing-fields handshake on 5 chip-emitters.
- **Vendor-agnostic refinement** : Anthropic Tool Search Tool wrapped behind `ToolRegistryAdapter` (3 adapters, env-flag-switched).

## State of the branch (dev)

Recent commits :

```
200c3297  docs(calc-engine-v1): W0 audit complete — hypothesis C confirmed 86%
cd916424  docs(calc-engine-v1): D-CE-01 refinement — vendor-agnostic ToolRegistryAdapter
06d02311  docs(calc-engine-v1): 6-panel synthesis — 11 overrides + 6 critical findings
facc2565  docs(calc-engine-v1): KILL Phase 96 chat-as-verb + open mint-calc-engine-v1 discuss-phase
2e1060a5  docs(wave-1c-A3): lock missing-fields handshake PLAN.md (7 tasks, 2 revision iters green)
```

## Decisions locked (source-of-truth ADRs)

Read in this order if resuming cold :
1. `.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md` — the 20 D-CE-XX decisions table + the 11 overrides + 6 missed findings. **Single most important doc**.
2. `.planning/decisions/2026-05-16-calc-engine-matrix.md` — 11-category coverage matrix (57 ✅ / 4 ⚠️ / 3 ❌) + hypothesis C audit plan + 4-level lucidité framework.
3. `.planning/decisions/2026-05-16-phase-96-killed.md` — what was killed, what was preserved (Phases 91 / 93.5 / 94 / 95 survive).
4. `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` — 57 calc rows, severity 0-3, severity-3 blockers list.
5. `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md` — locked plan ready for `/gsd-execute-phase`.
6. `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` — the 2026-05-14 PAUSE decision that preceded the 2026-05-16 KILL.

## Engram observations to recall

Search keys for `mem_search` :
- `calc_engine:hypothesis_c:audit_confirmed_2026_05_16` (obs #108 — Wave 1 scope locks ALL endpoints)
- `calc_engine:tool_registry:vendor_agnostic_adapter` (obs #103 — Anthropic decoupling pattern)
- `calc_engine:panel_synthesis:2026_05_16` (panel verdicts source)
- `calc_engine:inventory_audit:2026_05_16` (matrix correction — 57 not 4)
- `calc_engine:real_profile_grounding:hypothesis_c` (obs #97 — original arbitrage.py evidence)
- `milestone:v2_9:phase_96_status` (obs #95 — Phase 96 KILL)
- `coach:tool_use:missing_fields_handshake:wave_a3:context_landed` (Wave 1c-A3 CONTEXT origin)
- `coach:tool_use:missing_fields_handshake:wave_a3:scope_correction` (obs #94 — A3 5-not-6 chip-emitters)

The W0 audit agent also saved obs #104-107 (per-calc findings).

## What's pending (priority order)

### PR-1 — Wave 1 PR-1 : grounding fix on 12 severity-3 endpoints (RECOMMENDED first)

**Why first** : these 12 endpoints SHIP WRONG NUMBERS to ~15-30 % of users by canton TODAY. Genevois user querying rachat LPP gets VD tax brackets. Frontalier user querying wealth tax may crash. **This is incident-level, not improvement-level.**

Surfaces (per W0 matrix top of severity-3 list) :
1. `services/backend/app/services/lpp_deep/rachat_echelonne_service.py` (+ caller endpoint)
2. `services/backend/app/services/fiscal/wealth_tax_service.py` (+ caller endpoint)
3. `services/backend/app/services/succession_simulator.py` (+ caller endpoint)
4. `services/backend/app/services/family/concubinage_service.py` (+ caller endpoint)
5. (+ 8 others in W0 matrix)

Fix pattern (per D-CE-06 + D-CE-07 + D-CE-08, ~30 LOC per endpoint) :

```python
@router.post("/...")
def endpoint(
    body: RequestSchema,
    profile: dict = Depends(get_profile_filled),  # new shared dependency
):
    resolved = _resolve_defaults(profile, body.model_dump(), RequestSchema)
    missing = _required_profile_fields_missing(resolved, RequestSchema)
    if missing:
        raise raise_incomplete_as_422(
            CoachToolIncomplete(
                missing_fields=missing,
                hint_fr=...,
            )
        )
    return _compute(**resolved)
```

Plus the new shared utilities :
- `services/backend/app/core/profile_resolver.py` — `get_profile_filled` + `_resolve_defaults` + `_required_profile_fields_missing` + `raise_incomplete_as_422`
- Schema metadata pattern : `canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})`

Recommend a single GSD phase or 1-PR-per-batch wave for the 12 sev-3 endpoints. Open the discuss-phase for `mint-calc-engine-v1` formally after to lock W1/W2/W3/W4 wave structure.

### PR-2 — Wave 1c-A3 execution (parallel-shippable)

A3 plan is locked. Coach tools (5 chip-emitters) are already 5/5 profile-grounded per W0 audit — so A3 doesn't conflict with the sev-3 endpoint fixes. Different surfaces.

Command :
```
/gsd-execute-phase wave-1c-A3-missing-fields-handshake
```

This spawns `gsd-executor` agent which implements the 7 tasks per `wave-1c-A3-PLAN.md`. Pre-push panel (5 agents per D-A3-10) runs before the PR opens.

### After PR-1 + PR-2 land : mint-calc-engine-v1 CONTEXT.md + W1 plan

Generate `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md` from :
- The 20 D-CE-XX decisions (panel synthesis ADR)
- The W0 audit matrix findings
- Vendor-agnostic D-CE-01 refinement

Then `/gsd-plan-phase mint-calc-engine-v1` to launch W1 (registry + lucidity payloads + further grounding).

## What's running in background

Nothing currently. W0 audit agent completed at session end (id `a1ef5ca9...`, terminated). Findings in W0 matrix.

## FIRST COMMAND to type in next session

If you want to ship the sev-3 incident-fix first :

```
/gsd-discuss-phase mint-calc-engine-v1
```

This formally opens the discuss-phase. The 20 D-CE-XX decisions are already locked from this session's panel synthesis, so it should mostly produce the CONTEXT.md mechanically + lock W1 scope at "12 sev-3 endpoints first, ALL endpoints W1 total". Or — alternatively, if you want me to act as PM and just open the PR-1 directly without re-running the discuss-phase (since the 20 D-CE-XX are already locked) :

```
Open a feature branch feature/calc-engine-v1-w1-pr1-severity-3-grounding from dev and start implementing the 12 severity-3 endpoint fixes per the W0 matrix top-12, using the get_profile_filled / _resolve_defaults / CoachToolIncomplete pattern locked in D-CE-06/07/08.
```

If you want to ship A3 first instead :

```
/gsd-execute-phase wave-1c-A3-missing-fields-handshake
```

## Hard constraints (CLAUDE.md repeats)

- LSFin banned terms (« garanti / optimal / meilleur / certain / assuré / sans risque / parfait »).
- Verbes interdits extension per D-CE-16 (« tu devrais / recommandé / il faut / le choix le plus avisé »...).
- 100 % accents FR mandatory.
- financial_core/ is source-of-truth for calculator logic — never re-implement `_calculate*()` in services.
- Conventional commits (feat / fix / docs / chore) + squash merge per CLAUDE.md §4.
- Lefthook gates : memory-retention + wiki-lint + banned-terms + arb-parity not bypassed.
- 0-TRUST § 9 : « shipped / ready / works / validated / green » require deterministic citation in same message. PR opened ≠ shipped.

## Counter-arguments and data gaps

**Counter-argument 1 :** « Handoff doc adds context overhead at session start — wouldn't a session-summary engram suffice? »
- Rebuttal : the next session starts cold (compaction / new conversation). `mem_context` returns recent observations but the FULL decision matrix (20 D-CE + 6 findings + W0 severity breakdown) doesn't fit in observation snippets. A single 200-line handoff doc + a list of ADR paths is more reliable than 9+ engram recalls.

**Counter-argument 2 :** « PR-1 sev-3 fix should NOT go ahead without W1 plan-phase first. »
- Rebuttal : the W0 audit + 20 D-CE-XX panel verdicts already specify the fix pattern (Q-06 / Q-07 / Q-08). A formal `/gsd-plan-phase` would re-derive what's already locked. Acceptable shortcut for incident-level fixes — but I (Claude) should open the discuss-phase to formalize for completeness if Julien prefers GSD discipline.

**Data gaps :**
- Did NOT verify the 12 severity-3 endpoints are ALL still in production today vs. some being deprecated / unrouted. Spot-check `routes.py` registration before opening PR-1.
- Did NOT measure baseline latency impact of the new `get_profile_filled` Depends. Expect <5 ms but instrumentation should be added in PR-1 (mint_calc_invoke_total counter).
- A3 PLAN has 1848 lines — first command of next session should re-read it before executing.

## Session-end checklist (this session)

- [x] Phase 96 KILL ADR + ROADMAP update committed
- [x] calc-engine-matrix ADR committed
- [x] 6-panel synthesis ADR committed (with vendor-agnostic refinement)
- [x] W0 audit matrix committed
- [x] Wave 1c-A3 PLAN.md locked + committed (sha 2e1060a5)
- [x] 8+ engram observations saved (#94-108 range)
- [x] HANDOFF.md (this file) written
- [x] HANDOFF.md committed (sha 84a2cf78)
- [x] mem_session_summary saved
- [x] Wave 1c-A3 EXECUTED 6/7 tasks (see addendum below)

---

## ADDENDUM 2026-05-16 — Wave 1c-A3 execution complete (6/7 tasks)

`gsd-executor` agent ran 30 min and returned `EXECUTION COMPLETE` (6/7 tasks). A3.7 (pre-push panel + PR open + post-merge verification) explicitly deferred to next session per executor prompt boundary.

### Branch state

- Branch : `feature/wave-1c-A3-missing-fields-handshake`
- Based on dev sha `84a2cf78`
- 7 commits ahead of dev, 1380 insertions / 6 deletions across 12 files
- Working tree clean

### Commits on branch (oldest → newest)

```
a55b5469  feat(wave-1c-A3): CoachToolResponse Pydantic v2 envelope (D-A3-01)
de3e44d1  feat(wave-1c-A3): MISSING_FIELDS_INSTRUCTION_FR + 5 chip-emitter description rewrites (D-A3-02)
baac3870  feat(wave-1c-A3): citation_grammar.py pointer to per-tool description (D-A3-02)
792c27e2  feat(wave-1c-A3): _extract_avs_years + _EXTRACTORS update — anchor-mandatory (D-A3-03, I-01+I-07)
dcb79cfd  feat(wave-1c-A3): dispatcher + turn-local cache + same-turn upsert + fallback + tool_results in return dict (D-A3-03, D-A3-06, I-01/I-02/I-04/I-05/I-09)
e1656e8a  test(wave-1c-A3): 4 pytest artifacts (flat tests/ convention) + Maestro flow per D-A3-05 (I-06+I-08)
59883a89  docs(wave-1c-A3): SUMMARY.md — 6/7 tasks committed, ready for orchestrator pre-push panel + PR open
```

### Test results (executor self-report, spot-checked)

- `pytest <4 new A3 test files> -q` → **exit 0, 38 passed**
- Full backend suite `pytest services/backend/tests/ -q` → **exit 0, 6970 passed / 0 failed / 62 skipped / 1 xfailed** (was 6932 pre-A3, +38 net-new)
- `python3 -c "...MISSING_FIELDS_INSTRUCTION_FR.format(...)"` → exit 0 (I-03 format-smoke)
- `accent_lint_fr.py` on all 5 backend files → exit 0 each
- `banned_terms_python.py` on 5 backend files → exit 1 BUT only 2 pre-existing hits (coach_tools.py:377 + :846 from pre-A3 commits b7782086 + 37209ed1) ; **0 net-new banned terms introduced by A3**

### Files modified (12)

- `services/backend/app/models/coach_tools/_response.py` — created (76 lines, `CoachToolResponse` RootModel)
- `services/backend/app/services/coach/coach_tools.py` — +59 lines (5 chip-emitter descriptions + `MISSING_FIELDS_INSTRUCTION_FR`)
- `services/backend/app/services/coach/citation_grammar.py` — +10 lines (TOP/BOTTOM MANDATE pointer)
- `services/backend/app/services/coach/profile_extractor.py` — +63 lines (`_extract_avs_years` + `_EXTRACTORS` update)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — +388 / -6 lines (dispatcher rewrite + turn-local cache + Step 6a `tool_results` exposure + fallback)
- `services/backend/tests/test_coach_tools_missing_fields_instruction.py` — created (D-A3-05 #3)
- `services/backend/tests/test_coach_chat_missing_fields_handshake.py` — created (D-A3-05 #1)
- `services/backend/tests/test_coach_chat_narrator_asks_on_incomplete.py` — created (D-A3-05 #2, mock-Anthropic round-trip)
- `services/backend/tests/test_coach_chat_handshake_persistence.py` — created (D-A3-05 #4)
- `services/backend/tests/test_agent_loop.py` — +2 lines (Rule 1 legacy-alias fix)
- `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` — created (148 lines, D-A3-05 #5, 5 sub-scenarios)
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-SUMMARY.md` — created (222 lines)

### Checker iter 1 fixes all applied

I-01 (AVS-extractor anchor-mandatory), I-02 (verbatim _compute signatures), I-03 (.format() smoke), I-04 (no new db.commit), I-05 (tool_results in return dict), I-06 (mock-Anthropic test), I-07 (comma-boundary regex), I-08 (Maestro explainer comment), I-09 (family → number_of_children), I-10 (test inventory done), I-11 (panel severity ladder in PR body template).

### Decisions honored

D-A3-01 ✓ / D-A3-02 ✓ / D-A3-03 ✓ / D-A3-04 ✓ (5 not 6, off-by-2 corrected) / D-A3-05 ✓ (5 artifacts) / D-A3-06 ✓ (server-side floor wired) / D-A3-07 ✓ (financial_core reuse) / D-A3-08 ✓ (branch + commits) / D-A3-09 partial (G4 + G5 pre-push satisfied ; G1+G2+G3 post-merge) / D-A3-10 deferred to orchestrator / D-A3-11 noted in PR-body.

### Deferred to next session

1. **Pre-push 5-agent panel D-A3-10** : spawn in parallel `security-auditor` + `qa-expert` + `ai-engineer` + `prompt-engineer` + `architect-review` on the 7 commits + SUMMARY.md. I-11 severity ladder : BLOCKED/CRITICAL → fix mandatory ; MAJOR → fix or PR-body deferral ; MINOR/SUGGESTION → acknowledge + ship.
2. **PR open** : `gh pr create --base dev --title "feat(wave-1c-A3): missing-fields handshake on 5 chip-emitters" --body "..."` — after panel CLEAN + Julien explicit confirmation.
3. **G3** : `gh pr checks <N> --watch` until green.
4. **Squash-merge** : `gh pr merge --squash --delete-branch`.
5. **dev→staging bundle PR** for G1 Maestro + G2 Julien.
6. **`wave-1c-A3-VERIFICATION-REPORT.html`** per memory `feedback_html_evidence_report`.
7. **Engram mem_save** : panel verdicts + merge sha as one group of `prior_finding_refs`.

### FIRST COMMAND for next session (A3 ship-finish path)

```
Read .planning/HANDOFF-2026-05-16-calc-engine-v1.md (especially the
2026-05-16 A3 addendum at the bottom).
Then verify the feature/wave-1c-A3-missing-fields-handshake branch is at
expected state (7 commits ahead of dev, sha 59883a89 as HEAD).
Then spawn the pre-push 5-agent panel D-A3-10 in PARALLEL :
- security-auditor (LSFin banned-terms scan + LSFin lucidité grammar)
- qa-expert (regression coverage + 5-artifact test floor review)
- ai-engineer (Pydantic v2 CoachToolResponse contract review)
- prompt-engineer (5 per-tool description rewrites + MANDATE pointer review)
- architect-review (financial_core reuse + anti-facade + single-transaction discipline)
Apply I-11 severity ladder. After panel CLEAN, prompt Julien for
explicit confirmation, then gh pr create against dev with the PR body
template from wave-1c-A3-SUMMARY.md.
```

### Alternative first command (skip A3 panel, jump to sev-3 incident fix)

If you prefer the sev-3 incident-fix takes priority over A3 ship-finish (per panel F + my prior PM recommendation), the alternative first command is the « PR-1 sev-3 grounding fixes » prompt at the top of this HANDOFF (line ~95). A3 branch waits on `feature/wave-1c-A3-missing-fields-handshake`, no rebase debt for ~1 week.

### 0-trust note

- Nothing shipped to dev or staging. A3 is on a feature branch only.
- No PR opened yet.
- Tests pass on the FEATURE BRANCH, not on dev. Once squash-merged, dev re-run will validate.
- The 2 pre-existing banned_terms hits (coach_tools.py:377 + :846) are documented baseline noise NOT introduced by A3 — flagged for separate cleanup PR if cosmetic priority.
