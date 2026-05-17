# Phase 31: Instrumenter — Context

**Gathered:** 2026-04-19
**Status:** Ready for planning
**Mode:** expert-lock (6 decisions locked to researcher defaults — see rationale per D-XX)

<domain>
## Phase Boundary

Oracle observability layer for MINT v2.8. Tout ce qui casse arrive dans Sentry en <60s avec assez de contexte pour diagnostiquer sans ouvrir l'IDE. 6 deliverables :

1. **OBS-02** : Global error boundary 3-prongs mobile (FlutterError.onError + PlatformDispatcher.onError + Isolate.addErrorListener, NO `runZonedGuarded`)
2. **OBS-03** : Backend FastAPI fail-loud handler with trace_id + sentry_event_id + X-Trace-Id header
3. **OBS-04** : Trace_id round-trip mobile→backend via sentry-trace + baggage headers (http ^1.2.0, NO Dio migration)
4. **OBS-05** : SentryNavigatorObserver on GoRouter + custom breadcrumbs (ComplianceGuard, save_fact tool call, FeatureFlags outcomes)
5. **OBS-06** : PII Replay redaction audit artefact on 5 sensitive screens (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget) — **nLPD kill-gate before any prod sessionSampleRate>0**
6. **OBS-07** : Sentry tier/pricing + quota budget artefact (`.planning/observability-budget.md`)

**OBS-01 already shipped via CTX-05 spike** (sentry_flutter 9.14.0 + SentryWidget + maskAllText + maskAllImages on `apps/mobile/lib/main.dart`). This phase extends, doesn't replace.

**Kill gate** : OBS-06 PII audit committed BEFORE any `sessionSampleRate > 0` flip in prod. Non-négociable nLPD.
</domain>

<decisions>
## Implementation Decisions (6 locked to researcher defaults)

Rationale : each default was reasoned by the researcher with options/tradeoffs. I'm locking them in expert-autonomy mode per user authorization. If any turns out wrong in execution, revert + flag in SUMMARY.md.

### D-01 — sessionSampleRate production target = error-only (Option C)
- **Decision**: `sessionSampleRate = 0.0` + `onErrorSampleRate = 1.0` in production. Full replay ONLY on errors.
- **Rationale**: financial-app safe default. ~5k users × full session replay at 5% would cost $1.2k+/mo on Team tier. Error-only cuts cost by ~95% and keeps 100% signal on what matters (crashes).
- **Staging**: `sessionSampleRate = 0.10` (full sampling tolerated for debugging) + `onErrorSampleRate = 1.0`.
- **Dev local**: `sessionSampleRate = 1.0` (everything captured).
- **Flip path**: if feedback shows errors without session context is insufficient, ramp prod to `0.02` (2%) after OBS-06 signed off.

### D-02 — DSN strategy = 1 project + env tag (Option A)
- **Decision**: single Sentry project `mint` with `SentryFlutter.init(options: {environment: 'staging' | 'production'})` tag.
- **Rationale**: Julien is solo. 2 projects (mint-staging, mint-prod) double the alert configuration, dashboards, token rotation. Env tag is Sentry-native and supports all filtering/alerting per env. Industry standard.
- **DSN secrets**: staging DSN in `railway.app` env var `SENTRY_DSN_STAGING`, prod in `SENTRY_DSN_PROD`. Mobile reads via `--dart-define=SENTRY_DSN=...` at build time.

### D-03 — Event/breadcrumb naming = hierarchical `mint.<surface>.<action>.<outcome>` (Option A)
- **Decision**: dotted hierarchy: `mint.compliance.guard.pass`, `mint.compliance.guard.fail`, `mint.coach.save_fact.call`, `mint.coach.save_fact.error`, `mint.feature_flags.refresh.success`, `mint.feature_flags.refresh.failure`, etc.
- **Rationale**: searchable in Sentry UI (`event.category:mint.coach.*`), consistent across team growth. `surface` enum = {compliance, coach, feature_flags, profile, arbitrage, chat, budget, document_scan}. `action` verb-noun. `outcome` ∈ {pass, fail, success, error, start, end}.
- **Implementation**: helper `lib/services/observability/breadcrumb_helper.dart` exposes `BreadcrumbHelper.log('mint.<surface>.<action>', outcome: outcome, data: data)`.

### D-04 — Quota budget ceiling = $160/mo hard limit (Option B)
- **Decision**: Sentry Business tier ($80/mo base) + error-only replay quota buffer → **$160/mo hard ceiling**. Artefact `.planning/observability-budget.md` documents the math.
- **Rationale**: Business tier gives 50k errors + replays + cross-project link. 2× buffer covers spike incidents (e.g., bad deploy → 10x error rate for 1h). Beyond $160 = systemic problem to fix at source, not pay Sentry more.
- **Quota alert**: Sentry spend alert set at $120/mo (75%) email Julien.
- **Verify J0**: before Phase 31 exec, fetch Sentry pricing page (OBS-07 task) to confirm Business tier is still $80 and not renamed.

### D-05 — Trace propagation headers = sentry-trace + X-MINT-Trace-Id fallback (Option B)
- **Decision**: primary `sentry-trace` (Sentry OTLP-compatible) + `baggage` per W3C, with legacy `X-MINT-Trace-Id` continued for backward-compat with existing `LoggingMiddleware` (logging_config.py:85-103 already emits it).
- **Rationale**: `sentry-trace` is what Sentry's cross-project link feature reads. Adding it doesn't break `X-MINT-Trace-Id`. Dual-header approach = zero regression + new capability.
- **Implementation**: mobile `_authHeaders()` in `api_service.dart:~20` call sites gets `sentry-trace` + `baggage` added. Backend `LoggingMiddleware` propagates both in response. Cross-project UI link verified via curl trace test J1.

### D-06 — PII redaction scope = hybrid default-deny CustomPaint + SentryUnmask opt-in (Option D)
- **Decision**: keep current `options.privacy.maskAllText = true` + `options.privacy.maskAllImages = true` (from CTX-05 spike). Add `options.privacy.maskAllCustomPaint = true` if supported, OR wrap CustomPaint widgets in `SentryMask` manually (Sentry 9.x API surface TBD at exec time). Explicit `SentryUnmask` wrapper used on known-safe surfaces (e.g., phase progress widgets, currency values rendered with MintTextStyles for debugging).
- **Rationale**: CustomPaint in Flutter renders PII (charts, values, graphs) that text/image masks don't catch. MINT has 5 sensitive screens that render CustomPaint + data. Default-deny is the ONLY nLPD-safe default. Opt-in unmask comes later after OBS-06 audit signs which specific widgets are safe to show in replay.
- **Audit exit criteria**: OBS-06 produces `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` with screenshots from simulator showing MASK overlay on each of the 5 sensitive screens. ZERO leak = phase unblocks prod sampleRate flip.

### Claude's Discretion
- Exact `BreadcrumbHelper` API (static class vs injected) — planner decides.
- Exact file layout under `lib/services/observability/` — planner decides.
- Exact simctl driver script for OBS-06 audit automation — executor writes based on existing `tools/simulator/` patterns.
- Exact format of `observability-budget.md` (markdown table + math) — executor decides.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (planner, executor) MUST read these before planning or implementing.**

### Phase scope + success criteria
- `.planning/ROADMAP.md` §"Phase 31: Instrumenter" — goal, depends on 30.6 CTX-05 + 30.7, success criteria 5 items, auto profile L3
- `.planning/REQUIREMENTS.md` §OBS (OBS-01..07) — exact spec per REQ
- `.planning/STATE.md` — milestone v2.8 status post-30.6 merge

### Research artifacts (this phase)
- `.planning/phases/31-instrumenter/31-RESEARCH.md` — full technical approach + Validation Architecture + Assumptions Log
- `.planning/phase-30.5-context-foundation/PANEL-A-claude-code-architect.md` (referenced for hook runtime patterns reused by breadcrumb helper)

### Existing Sentry code to extend (no re-implement)
- `apps/mobile/lib/main.dart:111-142` — CTX-05 spike installed SentryFlutter.init + SentryWidget + maskAllText + maskAllImages. EXTEND, don't replace.
- `apps/mobile/pubspec.yaml:29` — `sentry_flutter: 9.14.0` pinned. OBS-02/04/05 use existing.
- `services/backend/app/logging_config.py:85-103` — `LoggingMiddleware` already emits `X-Trace-Id`. OBS-03 cohabite, pas overwrite.
- `apps/mobile/lib/services/api_service.dart:~20` call sites — `_authHeaders()` helper. OBS-04 patches here (~1 patch for 20+ call sites).
- `apps/mobile/lib/app.dart:173` — `AnalyticsRouteObserver` already in observers list. OBS-05 ajoute SentryNavigatorObserver **à côté**, pas remplace.

### Doctrine permanente (respecter pendant implémentation)
- `MEMORY.md` feedback prioritaires : `feedback_facade_sans_cablage.md`, `feedback_no_shortcuts_ever.md`, `feedback_audit_methodology.md`, `feedback_audit_inter_layer_contracts.md`, `feedback_app_targets_staging_always.md`, `feedback_ios_build_macos_tahoe.md`
- `rules.md` (tier 1) — fintech-grade principles
- `CLAUDE.md` — 121L restructured (new post-30.6), 5 rules bracketing TOP+BOTTOM
- `docs/AGENTS/flutter.md` + `docs/AGENTS/backend.md` — role-based conventions

### Test/tooling artefacts
- `tools/agent-drift/dashboard.py` — CTX-02 metric (b) context_hit_rate — extend for OBS event counts per surface
- `tools/simulator/` directory — create `walker.sh` J0 here for OBS-06 audit driver (simctl iPhone 17 Pro scenarios)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (OBS-01 CTX-05 output)
- `SentryFlutter.init(...)` initialized in `main.dart` with:
  - `sentry_flutter: 9.14.0` (pinned)
  - `options.privacy.maskAllText = true`
  - `options.privacy.maskAllImages = true`
  - `SentryWidget` wrapping `MintApp` at line 138
  - Session + error sample rates currently commented out / defaults — D-01 sets them explicitly
- `options.tracePropagationTargets` is `final List<String>` (mutate via `..clear()..addAll([...])` per STACK.md quirk) — OBS-04 extends this

### Pattern Catalog (from existing code)
- **Node.js hooks** `.claude/hooks/*.js` — NOT relevant for Phase 31 (Flutter + FastAPI only)
- **Python lints** `tools/checks/*.py` — can add OBS post-hoc lints (e.g., `no_bare_catch.py` to verify error boundary catches all exceptions)
- **`ApiService._authHeaders()` pattern** — 20+ call sites, single patch point for OBS-04
- **`LoggingMiddleware` middleware-ordering** — stacked AFTER `SentryFastApiIntegration` per FastAPI convention (OBS-03 respects this)

### Integration Points
- `apps/mobile/lib/main.dart` — OBS-02 error boundary AROUND existing SentryFlutter.init
- `apps/mobile/lib/app.dart:173` observers list — OBS-05 adds SentryNavigatorObserver
- `apps/mobile/lib/services/api_service.dart` — OBS-04 extends _authHeaders
- `services/backend/app/main.py` — OBS-03 adds global exception handler middleware
- `services/backend/app/logging_config.py` — OBS-03 cohabits with existing LoggingMiddleware
- `apps/mobile/lib/services/observability/` — NEW dir for breadcrumb helper
- `tools/simulator/walker.sh` — NEW J0 driver for OBS-06 audit
- `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` — NEW artefact from OBS-06
- `.planning/observability-budget.md` — NEW artefact from OBS-07
</code_context>

<specifics>
## Specific Ideas

- **Error boundary 3-prongs implementation reference** : Sentry Flutter official docs pattern, NOT `runZonedGuarded` (rejeté Panel A + production best practice). Installer dans `main()` AVANT `runApp`.
- **Breadcrumb helper design** : static class `BreadcrumbHelper` with `log(category, data)`. Category = `mint.<surface>.<action>.<outcome>` per D-03. Data = typed payload (dict merge compliance result / tool_call outcome).
- **Cross-project link verification** : curl test from staging mobile build → staging backend → Sentry UI shows event linked. J0 smoke test via `walker.sh`.
- **simctl driver for OBS-06** : boot iPhone 17 Pro sim, install staging build (`--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1` per memory doctrine), navigate to each of 5 sensitive screens via GoRouter deep links, capture screenshot, verify MASK overlay present. Output to `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`.
- **observability-budget.md math** : 5k users × 30d × (error rate baseline 0.5% × 1.0 onErrorSampleRate) = ~3k error events/mo. Business tier = 50k errors included → ~6% of quota. 2× spike headroom OK. Monthly € target = $80 base + replay buffer.

</specifics>

<deferred>
## Deferred Ideas

### To v2.9+ (not scope of Phase 31)
- **Full prod session sampling** — after OBS-06 audit + 30d error-only observation, decide if `sessionSampleRate = 0.02` flip makes sense. NOT in Phase 31.
- **Custom trace spans** (e.g., `Sentry.startTransaction('mint.onboarding.flow')`) — added where needed later, not a foundation REQ.
- **Breadcrumb dashboard** (aggregated view per surface) — observability UX, not observability plumbing. Phase 32 or later.
- **OTel export** for Sentry → Grafana / Datadog dual-write — maybe, if Sentry ever becomes insufficient. Hors scope.

### Refus permanents (NOT deferred, KILL définitif)
- **`runZonedGuarded` error boundary** — rejeté (pattern deprecated in Sentry Flutter 8+, Panel A + research confirm).
- **Dio HTTP client migration** — rejeté (http ^1.2.0 already in place, no value in switching).
- **2 Sentry projects** — rejeté (D-02 Option A locked, single project + env tag).

### Reviewed todos
*Aucun todo matché pour Phase 31 — clean start.*
</deferred>

---

*Phase: 31-instrumenter*
*Context locked: 2026-04-19 (expert-autonomy mode, researcher defaults accepted after reasoned review)*
*Decisions: D-01 to D-06 locked*
*Next step: plan + execute with 3 plans (31-00 scaffolding + J0 walker.sh, 31-01 mobile, 31-02 backend, 31-03 ops budget) per researcher recommendation.*
