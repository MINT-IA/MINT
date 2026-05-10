---
gsd_state_version: 1.0
milestone: v2.9
milestone_name: Chat-as-Verb Pivot
status: verifying
stopped_at: Completed 94.1-01-PLAN.md — narrator-prompt fattening landed at FAIL bucket (Sonnet 20% gate-correct, Haiku 20%, thresholds NOT MET ; orchestrator decides 94.2)
last_updated: "2026-05-10T21:39:36.091Z"
last_activity: 2026-05-10
progress:
  total_phases: 11
  completed_phases: 4
  total_plans: 23
  completed_plans: 18
  percent: 78
---

# GSD State: MINT v2.9 — Chat-as-Verb Pivot

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19) + .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md (active milestone, 7 phases).

**Core value:** MINT is 70% structured wiki + simulators, 30% narration. The pivot kills the chat-tab as destination, makes cards the home, turns chat into a verb invocable from card-actions ("explique / simule / rassure-moi") with 3-turn cap, citation gate on every emitted number, and DAG invalidation on stale projections.

**North-star metric:** Turns/user/week DOWN, DAU UP, quarter over quarter.

**Current focus:** Phase 94 — mvp-citation-gate

## Strategic Frame (per MILESTONE-CHAT-AS-VERB-2026-05-09)

- **Doctrine:** the wiki is the asset ; chat is a precision tool, not a destination ; every number carries a citation chip ; narrator LLM is mathematically incapable of emitting an un-cited number.
- **Source:** 4-expert panel synthesis 2026-05-09 (Cleo strategist + Karpathy architect + adversarial agent + UI auditor) + code base audit 2026-05-09 (52 fields wiki, 17 simulators, coach text-first) + PO directive « MINT n'est pas un chat. Wiki + simulations + minimum chat livraison. »
- **5-gate exit contract per phase:** G1 Maestro flow / G2 device by Julien / G3 dev CI green / G4 regression suite / G5 LSFin+accent+ARB lint.
- **Critical path:** ~14 days with parallel UI track (90-92-93) and architecture track (91-94-95-96).

## Current Position

Phase: 95
Plan: Not started
Status: Plan 94-03 Tasks 1-3 landed ; Task 4 checkpoint:human-verify awaits Julien GO/NO-GO/PARTIAL signal
Last activity: 2026-05-10
Next:

  1. **Julien GO/NO-GO** on `94-03-FLAG-FLIP-PROPOSAL.md` :
     - `approved` → Wave 4 opens (narrator-prompt placeholder syntax + re-eval)
     - `approved staging-only` → permanent staging-only, no prod-flip
     - `not approved — issue: <description>` → revision mode
  2. `/gsd-verify-work 94` → 5-gate exit contract close (G2 device + G3 dev CI pending)

## Plan 94-01 Receipt (Wave 0 close, 2026-05-10)

- Files created : 9 (parser, registry, 6 test files, __init__.py)
- Files modified : 3 (config.py, eval_narrator.py, 94-VALIDATION.md)
- Tests added : 106 (Wave 0) + 0 regressions
- Full backend suite : 6372 passed, 62 skipped, 1 xfailed in 107.21s
- Commits : 033b8445 (T1) → 668df0de (T2) → 2a729c3d (T3)
- Duration : 13m 18s
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-01-SUMMARY.md

## Plan 94-02 Receipt (Wave 1 close, 2026-05-10)

- Files created : 7 (test_retry_flow, test_fallback, test_banned_claims, test_bundle_intersect, test_global_registry_fallback, test_telemetry, test_gate_performance)
- Files modified : 4 (citation_parser.py, coach_chat.py, test_number_detection.py, 94-VALIDATION.md)
- Tests added : ≈ 64 (Wave 1) + 0 regressions
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.60s (Wave 0 baseline 6372 → +64 net new)
- Commits : 1d9b44f1 (T1 — fatten gate body) → 13230885 (T2 — wire wrapper) → final docs commit
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-02-SUMMARY.md
- Karpathy #3 surgical : ZERO edits inside `_run_agent_loop` (lines 1726-2624) — diff 114+/18- concentrated at narrator handler scope
- H1 fix iter 1 : `_compiled_bundle: "CompiledBundle | None" = None` initialized BEFORE bundle-compiler branch ; wrapper safe on every code path
- M2 fix iter 1 : 3 documented v1 banned-claim regex false-negatives codified (3rd-person + infinitive + LSFin « garanti » → compliance_guard)
- M3 fix iter 1 : D-04#4 placeholder-body strip — 3 regression tests in test_number_detection.py
- H3 fix iter 1 : end-to-end gate() p95 ≤ 50ms / max ≤ 80ms on 4 kB FR realistic narrative (test_gate_performance.py)
- Flag default OFF in prod (D-19/D-20) ; flag-OFF byte-identity preserved (6 snapshot tests still green)
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94-03 Receipt (Wave 2 close-pending, 2026-05-10)

- Files created : 8 (citation_gate_eval_50.jsonl, flow_narrator_refuses_uncited_numbers.yaml, 3 eval-run JSONs, EVAL-RESULTS, FLAG-FLIP-PROPOSAL, deferred-items, SUMMARY)
- Files modified : 2 (tools/eval_narrator.py +215 LOC, .token_count_cache.json +1 entry)
- Tests added : 0 (Plan 03 deliverables are CLI flag + fixture pack + Maestro flow + docs — gate logic tested in Waves 0+1, total 170 unit tests)
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.09s (no regression vs Wave 1 baseline 6436)
- Commits (T1+T2+T3) : 937e3bba (T1 — --gate flag + 50-fixture pack) → f00fb693 (T2 — Maestro smoke flow + staging Railway + 3 live evals) → close-out docs commit
- Duration : ≈55 min execution + LLM API wait time
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-03-SUMMARY.md
- **STAGE 3 FINDING** : Sonnet gate_correct=3/50 (6%), Haiku 7/50 (14%) — both FAR below D-15 ≥95%/≥90% thresholds. Root cause : narrator system prompt does not teach `{{cite:<key>}}` placeholder syntax → gate (correctly per D-02..D-13) rejects naked numbers → 60-80% fallback rate. Mechanical, not a gate-logic bug. Wave 4 fattens narrator prompt → re-evals.
- **Maestro G1** : smoke-level PASS exit 0 (16-17s) on anonymous surface ; gate verification deferred to Wave 4 because anonymous_chat.py has NO gate wrapper today (deferred-items.md D1).
- **Staging Railway** : COACH_CITATION_GATE_ENABLED=true SET 2026-05-10T19:09:03Z on service MINT env staging ; prod env variable absent (config.py default False).
- **Recommendation** : NO-GO + PARTIAL (staging-only, Wave 4 narrator prompt fattening, re-eval). Awaits Julien GO/NO-GO/PARTIAL signal at Task 4 checkpoint.
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94.1-01 Receipt (Wave 4 narrator-prompt fattening, 2026-05-10)

- Files created : 7 (citation_grammar.py, bundles/citation_grammar.py, test_narrator_grammar_fragment.py, 94.1-01-PLAN.md, 94.1-EVAL-DELTA.md, 2 eval-run JSONs, 94.1-SUMMARY.md)
- Files modified : 5 (bundles/__init__.py, bundle_compiler.py +17 LOC, claude_coach_service.py +35 LOC, tools/eval_narrator.py +45 LOC, 94-03-FLAG-FLIP-PROPOSAL.md +1 section)
- Tests added : 12 (tests/test_citation_gate/test_narrator_grammar_fragment.py — fragment importability, 18-key coupling, verbatim examples, no new {slot}, builder purity, legacy path flag-on/off byte-identity, bundle path flag-on/off, compiler activated_bundles, dedup, Pydantic invariants)
- Full backend suite : 6448 passed, 62 skipped, 1 xfailed in 107.45s (+12 new tests vs Wave 1 baseline 6436 ; no regression)
- Commits (T1+T2+T3+T4) : 12b2a8fa (T1 PLAN.md) → b3a7ca1a (T2 fattening + tests + Rule 1 « tu dois » auto-fix) → T3 eval JSONs → T4 EVAL-DELTA + SUMMARY
- Duration : ~3.5h
- Architectural decision : Path C (Hybrid) — single source of truth citation_grammar.py CITATION_GRAMMAR_FRAGMENT consumed by both CitationGrammarBundle (flag-conditional in compile_bundles) AND build_narrator_system_prompt (flag-conditional append). NOT in _ALWAYS_ON constant ; NOT in ALL_BUNDLE_CLASSES — preserves test_empty_intent_emits_always_on_only + test_all_bundles_importable len=6 invariants.
- Eval instrumentation : eval_narrator --gate=on propagates COACH_CITATION_GATE_ENABLED=true to env + settings (Phase 94 Wave 2 ran without ; system prompt was unchanged).
- 0-trust : SUMMARY.md `## Self-Check : PASSED` at .planning/phases/94.1-.../94.1-SUMMARY.md
- **STAGE 3 FINDING (post-94.1)** : Sonnet gate_correct=10/50 (20%), Haiku 10/50 (20%) — both moved up from 6%/14% but STILL FAR below 95%/90% thresholds. Signal concentrated in valid_citation : Sonnet 1/20 → 9/20 (+800%), Haiku 6/20 → 10/20 (+67%). Topline understates improvement because fixture scoring records post-retry verdict (FALLBACK after D-08 collapse), not first-call (REJECTED_UNCITED) — under alternative « first-call match » scoring, Sonnet ≈48%, Haiku ≈44%.
- **Verdict** : FAIL per 94.1-01-PLAN interpretation rules (Sonnet < 70%). Orchestrator decides GO/NO-GO on 94.2 second-iter with primary hypothesis « intent-driven key grouping reduces 18-bullet noise floor » (full hypothesis list H1-H5 in 94.1-EVAL-DELTA.md).
- **Disposition** : NO-GO + PARTIAL unchanged. Staging stays ON for diagnostic value, prod stays OFF for narrator quality. No new GO recommendation.
- USER VALUE DELIVERED : NONE in prod. Branch `feature/S94-mvp-citation-gate` holds 94+94.1 ; not merged. The 94.1 measurement IS the only data on the fattened narrator behavior.

Progress: [██░░░░░░░░] 14% (1/7 phases) — Phase 90 shipped 2026-05-09 (5 design-system lints + baselines + lefthook + CI).

## Phase Plan (Chat-as-Verb)

| # | Phase | Type | Effort | Status |
|---|---|---|---|---|
| 90 | MVP-DESIGN-LINTS-V1 | UI | 2d | ✓ shipped (PR #543) |
| 91 | MVP-EXTRACTOR-V2 | Architecture | 3d | RESEARCH.md done, discuss next |
| 92 | MVP-FONTS-TOKENS-V2 | UI | 3d | not started (depends on 90) |
| 93 | MVP-CTA-UNIFICATION-V1 | UI | 4d | not started (depends on 90) |
| 94 | MVP-CITATION-GATE | Architecture | 3d | not started (depends on 91) |
| 95 | MVP-DAG-INVALIDATION | Architecture | 4d | not started (depends on 94) |
| 96 | MVP-CHAT-AS-VERB | Architecture | 5d | not started (depends on 95) |

## Cross-cutting

- **Maestro flow library** : 7 new flows (one per phase) under `tools/simulator/flows/maestro-perfect-set/`. Indexed.
- **ARB sweep** : ~132 ARB additions across 6 locales (CTA + chat-as-verb intents + citation-gate error strings). Parity check per PR.
- **Banned-terms / accent / LSFin** : pre-commit hook already wired (lefthook from Phase 90) ; narrator output additionally validated at runtime by CITATION-GATE parser (Phase 94).
- **Performance budget** : cold launch ≤2.5s at W3 + W4 close ; agent loop ≤30s on EXTRACTOR-V2 + CITATION-GATE eval suite.
- **Backward compat** : DAG-INVALIDATION is additive (hash nullable) ; existing profiles compute hash lazily ; zero forced recomputation.

## Risks (per memory feedback_design_panel_before_push)

1. CTA sweep (Phase 93) slips beyond 4d — 80 sites optimistic. Mitigation: pre-flight categorization Day 1.
2. CITATION-GATE retry loop (Phase 94) blows token budget. Mitigation: hard-cap retries at 1, templated fallback.
3. DAG-INVALIDATION (Phase 95) breaks profiles. Mitigation: additive migration, nullable hash.
4. CHAT-AS-VERB (Phase 96) user revolt. Mitigation: feature flag default-on, monitor `chat_overflow_turn_4`.
5. FONTS license (Phase 92). Mitigation: Fontshare ToS review gate before W1 merge.
6. Adversarial counter-thesis « chat IS the product ». Mitigation: 3-turn cap is the hypothesis being tested ; walkback path baked in.

## Session Continuity

Last session: 2026-05-10T21:36:54.626Z
Stopped at: Completed 94.1-01-PLAN.md — narrator-prompt fattening landed at FAIL bucket (Sonnet 20% gate-correct, Haiku 20%, thresholds NOT MET ; orchestrator decides 94.2)
Resume file: None

<details>
<summary>v2.8 archive — L'Oracle & La Boucle (shipped 2026-04-25, 5/9 phases + 13 decimals)</summary>

## Architecture Decisions (pre-phase, v2.8)

- **Nom**: "L'Oracle & La Boucle" (pas "Pilote & Compression"). Capture le geste central.
- **Rule inversée scellée**: 0 feature nouvelle. Tout ajout = out of scope by default.
- **Compression transversale**: chaque phase tue du code mort au passage, pas phase isolée.
- **Sentry existant étendu**, pas Datadog/Amplitude/PostHog (un seul vecteur = moins de surface nLPD + moins de divergence).
- **Système flags custom étendu** ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) + endpoint `/config/feature-flags`), pas LaunchDarkly.
- **lefthook pre-commit local**, pas juste CI gates (feedback <5s vs 2-5 min).
- **Phase numbering continué** depuis v2.7 (30 terminé) → **30.5, 30.6 (decimal inserts post-panel-debate), puis 31-36**.
- **Research activée** (Julien a choisi "Research first") — 4 researchers parallèles sur observabilité fintech mobile. Synthèse dans `.planning/research/SUMMARY.md`.
- **Phase debate résolu** (4 panels: Claude Code architect / peer tools / academic / devil's advocate) — MEMORY.md truncation = P0 runtime confirmé, lints mécaniques ROI > refonte éditoriale, AST proof-of-read = theater, `UserPromptSubmit` hook ciblé remplace AST, Phase 30.6 Tools Déterministes ajoutée (insight Panel C).
- **Kill-policy scellée** via [ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si v2.8 exit avec REQ table-stake unmet, la feature est KILLED via flag. Pas de v2.9 stabilisation.
- **Budget Phase 36 non-empruntable** (2-3 sem MINIMUM) — forces honest sizing de 31-35.

## Last v2.8 Position (frozen 2026-04-25)

Phase: 31
Plan: Not started
Status: Phase complete — ready for `/gsd-verify-work 30.7` + `/gsd-secure-phase 30.7` (Auto profile L1)
Next: `/gsd-verify-work 30.7` on `feature/S30.7-tools-deterministes` — 5/5 plans have SUMMARY, CLAUDE.md -30% trim @ 43a38dff, kill-switch rehearsed + Julien approved 2026-04-22, J0 fresh-session smoke deferred to post-merge operational validation (non-blocking). Also pending: `/gsd-verify-work 32` on `feature/v2.8-phase-32-cartographier` (3 RISK entries await Julien ack for nyquist_compliant flip).

Progress at v2.8 close: [██████████] 100% (5/9 phases, 22/22 plans) — Phase 30.7 5/5 shipped (30.7-00 wave0 + 30.7-01 tools 1+2 + 30.7-02 tools 3+4 + 30.7-03 mcp-server + 30.7-04 CLAUDE.md trim -30%) ; Phase 32 6/6 shipped (reconcile + registry + cli + admin-ui + parity-lint + ci-docs-validation).

## v2.8 Build Order

```
30.5 → 30.6 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36
```

- **30.5 Context Sanity** (5j non-empruntable) — foundation, CTX-05 spike gate go/no-go
- **30.6 Tools Déterministes** (2-3j) — MCP tools on-demand, ~16k tokens/session saved
- **31 Instrumenter** (1.5 sem, can borrow from 34) — Sentry Replay + error boundary 3-prongs + trace_id round-trip
- **34 Guardrails** (1.5 sem, can borrow from 31, parallel with 31) — lefthook + 5 lints + CI thinning. **GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05 starts.**
- **32 Cartographier** (1 sem, can borrow from 33) — route registry + /admin/routes dashboard
- **33 Kill-switches** (1 sem, can borrow from 32, parallel with 32) — GoRouter middleware + FeatureFlags ChangeNotifier + 4 P0 kill flags provisioned for Phase 36
- **35 Boucle Daily** (1 sem) — mint-dogfood.sh simctl + auto-PR threshold
- **36 Finissage E2E** (2-3 sem **non-empruntable**) — 4 P0 fixes + 388 catches → 0 + device walkthrough 20 min

## v2.8 Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 30.5 | Context Sanity | 5j | **non-empruntable** | 5 | CTX-05 spike |
| 30.6 | Tools Déterministes | 2-3j | — | 4 | — |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — |
| 35 | Boucle Daily | 1 sem | — | 5 | — |
| **36** | **Finissage E2E** | **2-3 sem MIN** | **never** | **9** | 4 P0 kill flags + device walkthrough |

**Total estimate (v2.8):** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## v2.8 Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

**v2.8 Execution Log:**

| Phase-Plan      | Duration | Tasks | Files | Completed  |
|-----------------|----------|-------|-------|------------|
| 32-02-cli       | 7 min    | 2     | 11    | 2026-04-20 |
| 32-03-admin-ui  | 11 min   | 2     | 11    | 2026-04-20 |
| 32-04-parity-lint | 5 min  | 1     | 6     | 2026-04-20 |
| Phase 32 P05 | 9min | 3 tasks | 5 files |
| Phase 30.7 P00 | 28 min | 3 tasks | 12 files |
| Phase 30.7 P01 | 15 min | 2 tasks | 4 files |
| Phase 30.7 P02 | 4min | 2 tasks | 4 files |
| Phase 30.7 P30.7-03 | 5min | 2 tasks | 5 files |
| Phase 30.7 P30.7-04 | 35 min | 2 tasks (T1 trim + T2 checkpoint) | 1 file (CLAUDE.md) | 2026-04-22 |

## v2.8 Accumulated Context (decisions reference — preserved for continuity)

### Decisions (v2.8 pre-phase)

- **v2.8 name**: "L'Oracle & La Boucle" captures instrumentation-first + daily loop
- **0 feature nouvelle** scellée via kill-policy ADR
- **Compression transversale**: chaque phase tue du code mort au passage
- **Extend existing Sentry** (not Datadog/Amplitude/PostHog) — bump `sentry_flutter` 8→9.14.0
- **Extend custom flags** (not LaunchDarkly) — converge 2 backend systems (env-backed read + Redis-backed write)
- **lefthook 2.1.5** for pre-commit local (not CI-only) — target <5s
- **Sentry Replay Flutter 9.14.0** with `maskAllText=true` + `maskAllImages=true` nLPD-safe defaults non-négociables
- **Headers manuels `sentry-trace` + `baggage` sur `http: ^1.2.0`** (pas migration Dio)
- **Binary-per-route flags** (pas cohort/percentage)
- **4 P0 kill flags provisioned in Phase 33** before Phase 36 begins: `enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns (v2.8 carry-forward)

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Roadmap Evolution

- 2026-05-10 — Phase 94.1 inserted after Phase 94 : « Wave 4 narrator-prompt fattening — citation registry + `{{cite:<key>}}` grammar instructions (Phase 94 prod-flip unblocker) ». URGENT decimal patch surfaced by Phase 94 close-out — Stage 3 thresholds NOT MET (Sonnet 6%, Haiku 14%) because narrator system prompt does not yet teach the citation placeholder grammar. Scope : extend `build_narrator_system_prompt` + `build_narrator_system_prompt_from_bundles` in `services/backend/app/services/coach/claude_coach_service.py` with the 18-key `CITATION_REGISTRY` list + `{{cite:<key>}}` directive ; re-run the 50-fixture `citation_gate_eval_50.jsonl` pack on Sonnet + Haiku ; if Sonnet ≥95% / Haiku ≥90% land, re-open `94-03-FLAG-FLIP-PROPOSAL.md` as GO. ~1d scope. Branch policy : continue on `feature/S94-mvp-citation-gate` OR split to `feature/S94.1-narrator-prompt-fattening` (Julien decides at PR time).

### Known Good Foundations (to capitalize, still valid for v2.9)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓ (now 15 with Phase 90 design lints)
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

</details>

---
*Last activity: 2026-05-09 — v2.9 Chat-as-Verb Pivot ACTIVE. Phase 90 (MVP-DESIGN-LINTS-V1) shipped (PR #543). Phase 91 (MVP-EXTRACTOR-V2) RESEARCH.md committed (commit `d57b4db7`). Roadmap structure repaired: slug-named phase dirs renumbered to 90-mvp-design-lints-v1/ + 91-mvp-extractor-v2/ for parser compatibility ; ROADMAP.md rewritten with parseable Phase blocks 90-96.*
