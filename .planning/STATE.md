---
gsd_state_version: 1.0
milestone: v2.8
milestone_name: L'Oracle & La Boucle — Overview
status: executing
stopped_at: Completed 31-02-PLAN.md (OBS-03 backend global_exception_handler + trace_id round-trip)
last_updated: "2026-04-19T17:20:17.548Z"
last_activity: 2026-04-19
progress:
  total_phases: 9
  completed_phases: 2
  total_plans: 11
  completed_plans: 9
  percent: 82
---

# GSD State: MINT v2.8 — L'Oracle & La Boucle

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19)

**Core value:** Toute route user-visible marche end-to-end et on le prouve mécaniquement ; on sait en <60s ce qui casse ; aucun agent ne peut ignorer son contexte ; Julien ouvre MINT 20 min sans taper un mur.
**Current focus:** Phase 31 — Instrumenter

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

## Current Position

Phase: 31 (Instrumenter) — EXECUTING
Plan: 3 of 5 complete (Plans 31-00 Wave 0 + 31-01 Wave 1 mobile + 31-02 Wave 2 backend shipped — Plan 31-03 PII audit next)
Status: Ready to execute
Last activity: 2026-04-19
Next: `/gsd-execute-phase 31` continue with Plan 31-03 (Wave 3 OBS-06 PII replay redaction audit on 5 sensitive screens) on `feature/v2.8-phase-31-instrumenter`

Progress: [████████░░] 82% (2/9 phases, 9/11 plans) — phase 31: 3/5 plans shipped (OBS-02 + OBS-03 + OBS-04 + OBS-05 green)

## Build Order

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

## Phase Budget Table

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

**Total estimate:** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

## Accumulated Context

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

### Phase 30.6 Decisions (Context Sanity Advanced, shipped 2026-04-19)

- **CTX-03** (plan 00, `fb85cc9e`): CLAUDE.md refonte 429L → 121L quickref with bracketing TOP+BOTTOM + 10 triplets + AGENTS split into 3 role-scoped files, SHA-pinned backup for revert-safety
- **CTX-04** (plan 01, `89b6fb61`): `.claude/hooks/mint-context-injector.js` UserPromptSubmit hook with 5 patterns, top-3 dedup, 500ms fail-open, `MINT_NO_CONTEXT_INJECT=1` override
- **CTX-05** (plan 02, spike `38a3950b`, merge `0d86d215`): `sentry_flutter 9.14.0` + SentryWidget + `options.privacy.maskAllText/maskAllImages = true` — 5/5 mechanical grid + 0 dashboard regression, **Kill-policy D-01 NOT triggered, PHASE SHIPS**
- **Dashboard deltas vs baseline-J0**: metric A drift rate +2.4 pts (noise band, <10 pts gate); metric B context hit rate +14.2 pts (positive — hook catches more rule-hits = working); metric C token cost -37.7% (memory gc win from CTX-01 confirmed)
- **sentry_flutter 9.14.0 API learning**: `options.privacy.*` owns masks (not `.experimental.replay.*`); `options.replay.*` owns sampling rates; `tracePropagationTargets` is `final List<String>` (mutate via `..clear()..addAll([...])`)

### Phase 31-02 Decisions (Wave 2 backend OBS-03, shipped 2026-04-19)

- **31-02** (commits `6ea76af5` → `e39d3480`): `global_exception_handler` extended with 3-tier trace_id fallback (inbound `sentry-trace` > `trace_id_var` ContextVar > fresh `uuid4`). 500 JSON body surfaces `trace_id` + `sentry_event_id`. `X-Trace-Id` response header cohabits with LoggingMiddleware emission. FIX-077 nLPD `%.100s` log truncation preserved.
- **3-tier fallback over plan's 2-tier** (Rule 1 deviation) — RED phase surfaced `trace_id_var.get("-")` returning default `"-"` when handler runs in exception-handler scope (BaseHTTPMiddleware+`call_next` interaction). Added `uuid4()` 3rd tier to guarantee non-empty trace_id on all 500 responses. Future exception paths should reuse this pattern.
- **`sentry-sdk[fastapi]` pinned `==2.53.0`** in `services/backend/pyproject.toml` (was `>=2.0.0,<3.0.0`). Upgrade gated by rerunning `tools/simulator/trace_round_trip_test.sh` against staging.
- **A2 (proxy strip) VERIFIED** — Railway delivered `sentry-trace` header intact through `/auth/login` (422 response proves header was not stripped by CDN/proxy). X-MINT-Trace-Id fallback NOT needed.
- **A1 (auto-read cross-project link) PARTIAL** — capability documented upstream but unproven end-to-end here (staging 422 path never fires the 500 handler; cross-project link requires real Sentry event pair). Flip VERIFIED in Plan 31-04 quota probe.
- **DEFERRED: test-only raise_500 endpoint (accepted limitation per revision Info 7)** — `trace_round_trip_test.sh` PASS-PARTIAL via `/auth/login` 422 path is the accepted ship state for Phase 31. Re-evaluate Phase 32 or Phase 35.
- **Test fixture pattern** — app-level exception handler tests register a raising route via `@app.get` in a pytest fixture, use `TestClient(app, raise_server_exceptions=False)`, and pop the route from `app.router.routes` in teardown. Precedent: `tests/test_coach_chat_endpoint.py:91`.
- **Full backend suite: 5958 passed + 6 skipped** (baseline 5955+9; delta +3/-3 expected). Zero regression on pre-existing tests.

### Phase 31-00 Decisions (Wave 0 scaffolding + J0 walker, shipped 2026-04-19)

- **31-00** (plan 00, commits `6c265341` → `a8699856`): 17/17 Wave 0 scaffolds landed (8 Flutter test stubs + 1 pytest stub + 3 Python lints + 4 shell/simulator helpers + 1 README + integration_test/.gitkeep), `sentry-cli 3.3.5` installed, `.gitignore` extended with `.planning/walker/`.
- **OBS-01 SHIPPED via CTX-05 + Wave 0 audit** — `verify_sentry_init.py` reports 8/8 invariants green on current `main.dart`; no new mobile code for OBS-01. Any future edit dropping `maskAllText`/`maskAllImages`/`sendDefaultPii=false`/`SentryWidget`/`tracePropagationTargets`/`onErrorSampleRate=1.0` fails the lint mechanically (Pitfall 10 mitigation).
- **walker.sh smoke PASS** — `MINT_WALKER_DRY_RUN=1 bash tools/simulator/walker.sh --smoke-test-inject-error` exits 0 in ~61s (< 3 min budget). Façade-sans-câblage Pitfall 10 mitigated: the script was EXERCISED, not just shipped.
- **Open Question #4 resolved empirically** — staging `/_test/inject_error` HTTP 404 (endpoint absent); fallback to malformed JSON `POST /auth/login` HTTP 422 works (backend reachable + error handler active). Plan 31-02 will add the dedicated test endpoint backend-side.
- **Portable `to()` wrapper** added to walker.sh (Rule 2 deviation): macOS ships without `timeout`; walker now chains `gtimeout` → `timeout` → bare fallback with `WARN`. `brew install coreutils` executed on dev host to provide `gtimeout` (9.10). No hard dependency on coreutils for correctness.
- **D-03 4-level breadcrumb categories locked** as string literals in Flutter stub test descriptions: `mint.compliance.guard.{pass,fail}`, `mint.coach.save_fact.{success,error}`, `mint.feature_flags.refresh.{success,failure}`. Wave 1 implementers cannot drift the naming scheme.
- **`nyquist_compliant: true`** and **`wave_0_complete: true`** now set in `31-VALIDATION.md` frontmatter — Wave 1/2 (Plans 31-01, 31-02) unblocked.
- **`SENTRY_AUTH_TOKEN` operator setup** deferred (human-action auth gate). walker.sh + sentry_quota_smoke.sh gracefully WARN-and-continue when absent. Non-blocking for Wave 1 mobile; blocks Wave 4 quota probe only.

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Known Good Foundations (to capitalize)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

## Session Continuity

Last session: 2026-04-19T17:20:17.546Z
Stopped at: Completed 31-02-PLAN.md (OBS-03 backend global_exception_handler + trace_id round-trip)
Resume file: None

---
*Last activity: 2026-04-19 — v2.8 ROADMAP.md created, 8 phases (30.5 → 36), 48 REQ mapped 1:1, build order 30.5 → 30.6 → (31∥34) → (32∥33) → 35 → 36*
