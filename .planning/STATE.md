---
gsd_state_version: 1.0
milestone: v2.8
milestone_name: L'Oracle & La Boucle — Overview
status: executing
stopped_at: Completed 30.7-02-PLAN.md (TOOL-03 + TOOL-04 shipped)
last_updated: "2026-04-22T17:37:59.906Z"
last_activity: 2026-04-22
progress:
  total_phases: 9
  completed_phases: 4
  total_plans: 22
  completed_plans: 20
  percent: 91
---

# GSD State: MINT v2.8 — L'Oracle & La Boucle

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19)

**Core value:** Toute route user-visible marche end-to-end et on le prouve mécaniquement ; on sait en <60s ce qui casse ; aucun agent ne peut ignorer son contexte ; Julien ouvre MINT 20 min sans taper un mur.
**Current focus:** Phase 30.7 — Tools Déterministes

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

Phase: 30.7 (Tools Déterministes) — EXECUTING
Plan: 4 of 5
Status: Ready to execute
Last activity: 2026-04-22
Next: `/gsd-verify-work 32` on `feature/v2.8-phase-32-cartographier` — 6/6 plans have SUMMARY, VALIDATION.md reflects reality (3 PASS + 3 BLOCKED + 0 FAIL), 3 RISK entries await Julien ack for nyquist_compliant flip

Progress: [██████████] 100% (4/9 phases, 17/17 plans) — phase 32: 6/6 plans shipped (32-00 reconcile + 32-01 registry + 32-02 cli + 32-03 admin-ui + 32-04 parity-lint + 32-05 ci-docs-validation green)

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

### Phase 32-05 Decisions (Wave 4b CI + Docs + J0 Validation, shipped 2026-04-20)

- **32-05** (commits `69d6d87c` → `acd02c65`): 4 CI jobs wired into `.github/workflows/ci.yml` — `route-registry-parity` (D-12 §1, invokes Plan 04 lint), `mint-routes-tests` (D-12 §2, DRY_RUN pytest over Plans 02+03+04 = 26 tests), `admin-build-sanity` (D-12 §3, grep scan ENABLE_ADMIN=1 in testflight.yml+play-store.yml, T-32-05 mitigation), `cache-gitignore-check` (D-09 §3, T-32-02 residual). `ci-gate` needs[] extended; baseline clean pre-commit (no pre-existing ENABLE_ADMIN=1 leak).
- **`docs/SETUP-MINT-ROUTES.md` shipped**: Keychain setup with `-U -A` hardening + scope lock (`project:read + event:read + org:read` only, DO-NOT list including `member:*`) + 7-row commands table + 5-row env vars table + 5 nLPD controls D-09 §1-§5 with Art. 5/6/7/9/12 mapping + 6-row troubleshooting + Phase 35/36/CI integration refs. Technical English, no FR user-facing prose, banned LSFin terms grep empty.
- **`README.md` Developer Tools section added** with link to SETUP-MINT-ROUTES.md.
- **`tools/simulator/walker.sh --admin-routes` mode added**: rebuilds booted sim with `--dart-define=ENABLE_ADMIN=1`, reinstalls, launches, opens `mint://admin/routes` deep link (soft-fail if scheme missing), captures 5 screenshots to `.planning/phases/32-cartographier/screenshots/walker-$(date +%Y-%m-%d)/`. Alias `--scenario=admin-routes` normalized to `--admin-routes` before case dispatch. `MINT_WALKER_DRY_RUN=1` short-circuits. Both invocations verified exit 0 DRY_RUN.
- **Tree-shake gate (J0 Task 1) PASS on device target (not simulator)**: Flutter 3.41.6 rejects `--release` and `--profile` on simulator (documented deviation Rule 3). Built `flutter build ios --release --no-codesign --dart-define=ENABLE_ADMIN=0` → 8.86 MB Mach-O arm64. `strings Runner | grep -c kRouteRegistry` = 0. `grep -c "Retirement scenarios hub"` = 0. No admin symbols leaked. Tree-shake contract verified empirically.
- **6 J0 gates verdict: AMBER** (3 PASS + 3 BLOCKED + 0 FAIL). PASS: Task 1 tree-shake, Task 4 parity lint (exit 0, 140 routes parity OK), Task 5 DRY_RUN pytest (26/26 green). BLOCKED: Task 2 SentryNavigatorObserver (Keychain denied to non-interactive subprocess + staging DSN env unset), Task 3 batch OR-query live (same env reason; client-side `_build_batch_query(30)`=302 chars PASS), Task 6 walker.sh screenshots (Xcode CodeSign failed on simulator rebuild — L3 partial, autonomous must NOT self-patch per feedback_tests_green_app_broken).
- **M-4 strict 3-branch hierarchy applied**: `nyquist_compliant: false` STAYS false per strict rule — Task 2 is BLOCKED, not PASS, so flip condition not met. 3 §Risks entries (A/B operator choice each) written to `32-VALIDATION.md` awaiting Julien acknowledgment. The previous "soft defer / acceptable for now" wording was explicitly rejected per plan M-4 fix.
- **Per-Task Verification Map flipped**: all 34 rows in `32-VALIDATION.md` table from `⬜ pending` → `✅ green` (Wave 0-4 empirically verified via pytest/flutter test/parity lint). 6 J0 gates documented separately in new `## J0 Empirical Results — 2026-04-20` matrix.
- **VALIDATION.md frontmatter final**: `status: executed`, `wave_0_complete: true`, `nyquist_compliant: false`, `j0_verdict: AMBER`, `j0_pass_count: 3`, `j0_blocked_count: 3`, `j0_fail_count: 0`.

### Phase 32-04 Decisions (Wave 4 Parity Lint MAP-04, shipped 2026-04-20)

- **32-04** (commit `189aa0d6`): `tools/checks/route_registry_parity.py` ships stdlib-only Python 3.9 lint (argparse + re + pathlib + typing) with DOTALL regex over `GoRoute|ScopedGoRoute(path:...)`. Runtime 30ms (1000x under 30s CI budget). Extracts 148 path literals from app.dart (includes `/admin/routes` compile-conditional) vs 147 `kRouteRegistry` keys → 140 comparison paths parity OK after symmetric KNOWN-MISSES subtraction. Exits 0/1/2 per sysexits.h.
- **KNOWN-MISSES exemption strategy**: explicit allow-list sets `_ADMIN_CONDITIONAL` (1 entry: `/admin/routes`) + `_NESTED_PROFILE_CHILDREN` (7 tuples for `/profile/<child>` pairings) in the lint source. Rejected regex-guard preprocessing (fragile syntax variance) and separate allow-list file (scope bloat). Static allow-list is deterministic, auditable, fails loud on new entries not in the list (no_shortcuts_ever).
- **Symmetric subtraction for Category 5 nested children**: lint strips bare-segment from app.dart side AND composed `/profile/<segment>` from registry side. Asymmetric exemption would let ghost registry keys go unnoticed. Tuple form `(segment, composed)` in `_NESTED_PROFILE_CHILDREN` makes the pairing explicit, prevents half-updates.
- **KNOWN-MISSES.md amended**: Category 5 rewritten to document allow-list strategy (dropping stale `--resolve-nested` flag reference); Category 7 (admin-only compile-conditional routes) added with 3-option decision trail + maintenance policy for Phase 33 `/admin/flags`.
- **Shell wrapper anti-façade test** (`test_shell_wrapper_invokes_lint_and_propagates_exit_code`): `bash .lefthook/route_registry_parity.sh` asserted to exit 0 + forward "parity OK" stdout on pristine HEAD. Wrappers that exist but don't invoke the lint are `feedback_facade_sans_cablage` at the Bash level — tested end-to-end, not just chmod +x.
- **`lefthook.yml` + `.github/workflows/ci.yml` INTENTIONALLY UNTOUCHED**: per D-12 §5 the hook wiring is Phase 34 GUARD-01 scope (avoids merge conflict with GUARD-02 bare-catch work); CI job is Plan 32-05 scope. Git diff on both files is empty for this commit — scope discipline.
- **pytest 9/9 green** (9 cases, not the plan's stated 6): added 3 beyond plan scope — shell-wrapper-exists + shell-wrapper-invokes-lint + sort/dedup strictness. Pure additive coverage for anti-façade + regression-prevention.
- **Python 3.9 strict compat**: verified via `python3 -m py_compile`. Uses `from __future__ import annotations` + `typing.List/Optional/Set/Tuple` (not PEP 585 builtins). Zero PEP 604 unions, no match/case, no dict|dict merge. Dev 3.9.6 ↔ CI 3.11 forward-compat safe.

### Phase 32-03 Decisions (Wave 3 Admin UI MAP-02b + MAP-05, shipped 2026-04-20)

- **32-03** (commits `1639c3f0` → `95c21137`): `/admin/routes` pure schema viewer shipped behind compile-time `ENABLE_ADMIN` + runtime `FeatureFlags.isAdmin` double gate (D-10 local-only; NO backend call). 147 routes × 15 RouteOwner ExpansionTiles with `Semantics` labels (a11y). Footer points to `./tools/mint-routes health` for live status (D-06 CLI-exclusive health contract). AdminShell reusable for Phase 33 `/admin/flags` without refactor. 4 Wave 0 Flutter stubs flipped live (16 tests) + 1 new pytest (3 tests) — all green.
- **MAP-05 wired end-to-end**: all 43 arrow-form legacy redirects in app.dart converted to block-form `(_, state) { MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/x'); return '/x'; }`. Per-site coverage asserted by `tests/tools/test_redirect_breadcrumb_coverage.py` parsing the 43-row RECONCILE-REPORT inventory — not a fragile `grep -c == 43` total count (M-3 fix). Sum check (43 == Σ redirect_branches == 43) cross-validates. 9 block-form Category 6 redirects (scope guards, FF gates, param-passing) intentionally left unwired.
- **Behavioural breadcrumb test via `Sentry.init(beforeBreadcrumb: ...)` hook** (M-2 fix): captures real `Breadcrumb` objects from `MintBreadcrumbs.adminRoutesViewed` + `legacyRedirectHit`, asserts exact `data.keys.toSet()` equality (`{route_count, feature_flags_enabled_count}` when snapshotAgeMinutes null; `{route_count, feature_flags_enabled_count, snapshot_age_minutes}` when provided; `{from, to}` for redirects). Int-only structural check (`isNot(isA<String>())`) forbids String values (anti-PII gate). Supersedes Wave 0 source-string grep stub — behavioural contract matches nLPD Art. 12 processing record.
- **M-1 English carve-out** declared in every admin file header (`admin_gate.dart`, `admin_shell.dart`, `routes_registry_screen.dart`): exact literal `// Dev-only admin surface per D-03 + D-10 (CONTEXT v4). English-only by executor discretion — no i18n/ARB keys. Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**`. Phase 34 GUARD-03 can exempt the admin tree safely with an explicit provenance trail.
- **MintBreadcrumbs pre-landed in Task 1 commit** (Rule 3 blocking auto-fix): plan structured `legacyRedirectHit` + `adminRoutesViewed` as Task 2 File 1, but `RoutesRegistryScreen.initState` calls `adminRoutesViewed` at mount. Compile-time dependency won — helpers land with Task 1. 43-site wiring + tests still owned by Task 2.
- **Pytest indexes callsites by source path, not line number**: wiring 43 arrow-form redirects (1 line) into 4-line block forms shifts every downstream line in app.dart. `_extract_callback_body_by_source(src, source_path)` walks backward to `ScopedGoRoute(` then forward via balanced-paren tracking. Source paths are stable identifiers; line numbers are not.
- **Widget-test viewport trick**: `tester.view.physicalSize = Size(800, 20000)` so ListView.builder materialises all 15 owner tiles (default 800x600 only fits ~10). Also `find.byWidgetPredicate((w) => w is ListTile && w.dense == true)` to exclude ExpansionTile's internal-header ListTiles (otherwise naive `find.byType(ListTile)` returns 147+15=162).
- **Tree-shake empirical proof deferred to Plan 32-05 Wave 4 J0 Task 1**: `if (AdminGate.isAvailable) ...[ ScopedGoRoute(...) ]` is the compile-time guarantee; binary-grep `strings Runner | grep -c kRouteRegistry == 0` validates. Plan 32-05 also wires `admin-build-sanity` CI job scanning prod build YAMLs for accidental `--dart-define=ENABLE_ADMIN=1`.

### Phase 32-02 Decisions (Wave 2 CLI MAP-02a + MAP-03, shipped 2026-04-20)

- **32-02** (commits `458b0dab` → `317ccdb7`): `./tools/mint-routes` Python 3.9-compat CLI shipped with 3 subcommands (health, redirects, reconcile) + purge-cache + `--verify-token`. Task-split 2-phase: Task 1 skeleton with `NotImplementedError` stubs (pytest collects clean, no `ImportError`); Task 2 wires sentry_client + redaction + dry_run + replaces all 4 stubs. 14/14 pytest green, 0 skipped; 2/2 Flutter `route_meta_json_test.dart` green.
- **Keychain service name reused: `SENTRY_AUTH_TOKEN`** (matches Phase 31 `sentry_quota_smoke.sh:72`) — CONTEXT D-02 literal `mint-sentry-auth` **amended** inline. Zero onboarding friction: operator configures the Keychain entry ONCE for Phase 31 + 32 together.
- **nLPD D-09 controls active**: 5-pattern redaction (IBAN_CH, IBAN_ANY, AVS 756.xxxx.xxxx.xx added as A2 defensive default, EMAIL, CHF >100) + recursive `user.{id,email,ip_address,username}` key stripper + 7d cache TTL auto-purge + `purge-cache` operator wipe + `--verify-token` scope enforcer (allowed: project:read + event:read + org:read; extras => exit 78).
- **Token NEVER in argv** (T-32-03 mitigation): urllib.request with `Authorization: Bearer` header only. Test `test_keychain_fallback_token_never_in_argv` asserts no `--auth-token` string appears in sentry_client.py source. sentry-cli subprocess pattern explicitly rejected.
- **Schema contract published**: `apps/mobile/lib/routes/route_health_schema.dart::kRouteHealthSchemaVersion = 1`. Python↔Dart parity enforced byte-exactly by `test_json_output_schema_matches_dart_contract` regex-parsing the Dart source for the literal and asserting equality with Python `__schema_version__`. Any future drift fails the test loudly.
- **Exit codes (sysexits.h D-02 locked)**: 0/2/71/75/78. Graceful degradation on 414 (batch too large → 1 req/sec sequential fallback) and 429 (4s backoff → partial index). 401/403 → exit 78 with scope-diagnostic stderr.
- **Batch size default = 30** (147 paths → 5 chunks: 30+30+30+30+27). D-11 J0 empirical validation deferred to Plan 32-05 Task 3.
- **`reconcile` subcommand** graceful no-op until Plan 32-04 ships `tools/checks/route_registry_parity.py`: WARN to stderr + exit 0 (not crash). Auto-switches to lint-driven exit when script lands.
- **Python 3.9-compat throughout**: no PEP 604 `X | Y` unions, no `match/case`, no `dict | dict` merge. stdlib-only (urllib + subprocess + json + re). Zero external deps. CI 3.11 forward-compat verified.

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

Last session: 2026-04-22T17:37:59.903Z
Stopped at: Completed 30.7-02-PLAN.md (TOOL-03 + TOOL-04 shipped)
Resume file: None

---
*Last activity: 2026-04-19 — v2.8 ROADMAP.md created, 8 phases (30.5 → 36), 48 REQ mapped 1:1, build order 30.5 → 30.6 → (31∥34) → (32∥33) → 35 → 36*
