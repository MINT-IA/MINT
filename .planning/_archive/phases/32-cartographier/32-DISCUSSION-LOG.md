# Phase 32: Cartographier — Discussion Log (expert-lock v4, post-3-panel-reviews, structural fix pass)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md v4 — this log preserves the full v1→v4 trail + 12 expert findings across 3 panel rounds.

**Date:** 2026-04-20
**Phase:** 32-cartographier
**Mode:** v1 expert-lock → panel 1 (4 experts) → v2 Option C → panel 2 (4 experts) → v3 hybrid → panel 3 (4 experts) → v4 structural fix pass
**Areas analyzed:** 12 decisions locked (D-01..D-12)

---

## Session timeline

1. **v1 initial** (AM) — 6 decisions PM-locked, Julien authorized "b" / expert-lock.
2. **Panel 1** (4 experts: Flutter architect, Backend security, Staff iconoclast, UX/product) — 5 critical findings.
3. **v2 Option C pivot** — Julien "Je suis ton avis d'expert", PM chose CLI-first, deferred Flutter UI to Phase 33.
4. **Panel 2** (4 NEW experts: Python CLI, Observability SRE, Contrarian #2, Technical writer) — 15 findings including pivot bias audit + route-tag gap identification.
5. **Verification** — PM grep'd Phase 31 code, confirmed no `setTag('route')`, but SDK SentryNavigatorObserver auto-sets `transaction.name` → query pivot works.
6. **v3 hybrid** — Julien "meilleure techno, meilleur code, meilleure infra" + "on va avec ta recommandation". PM chose hybrid (both CLI + Flutter UI Phase 32).
7. **Panel 3** (4 NEW experts: Execution engineer, nLPD compliance, Performance/scale, DevOps/release) — 15 structural findings across 4 dimensions.
8. **v4 structural fix pass** — Julien "Je valide ton call, je te fais confiance". PM applied C discipline (no Panel 4), wrote v4 addressing Panel 3's factual blockers (iOS sandbox, backend contradiction, nLPD controls).

---

## Panel 1 findings (4 experts, v1 → v2 trigger)

### 🔴 Security panel — 3 P1 bugs in v1 D-02
1. `@lru_cache(ttl=30)` — Python `functools.lru_cache` has NO ttl param
2. SENTRY_AUTH_TOKEN no rotation policy
3. Rate limit 429 not handled

### 🟡 Flutter panel — 3 concrete risks
1. Tree-shaking unverified — VALIDATION step needed
2. Parity lint regex fragile — KNOWN-MISSES.md needed
3. Count mismatch 148 vs 156 — reconcile BEFORE planning

### 🟠 Staff panel — 2 premise challenges
1. Registry-as-code duplication — codegen alternative
2. Dashboard affordance wrong for solo user — CLI alternative

### 🔴 UX panel — 4/10 brand alignment
1. Dashboard Flutter = cliché vs feedback_no_banality_wow
2. 156 rows × 9 cols = cognitive overload on iPhone
3. Terminal-style alternative scores 7/10

## v1 → v2 changes (Option C pivot)

| Decision | v1 | v2 |
|----------|----|----|
| D-01 RouteMeta | 5 req + enum 15 + desc + sentryTag | UNCHANGED |
| D-02 Sentry access | Backend proxy + `lru_cache(ttl=30)` | CLI direct + Keychain |
| D-03 /admin shell | Scaffold 32+33 | DEFERRED Phase 33 |
| D-04 Parity lint | Regex only | + KNOWN-MISSES.md |
| D-05 Redirect analytics | Breadcrumb, 23 | UNCHANGED mechanism, count → 43 |
| D-06 Dashboard | Flutter MVP 9-col | CLI terminal-only |

---

## Panel 2 findings (4 NEW experts, v2 → v3 trigger)

### 🔴 Observability SRE
- **Critical data gap** : `event.tag:route:X` returns 0 (Phase 31 ne setTag pas). Fix: `transaction:<path>` query (SDK auto-sets transaction.name).
- **Math error D-05** : 0.009% → actually 0.258% (off 28.6×).
- Rate limit 40/min unvalidated (empirical J0 needed).
- "Last-visited" breadcrumbs unfetchable for routes without events (accepted limit).

### 🔴 Contrarian #2
- **Panel 1 was systematically anti-UI biased** (PM's prompts framed skepticism).
- UX 4/10 = doctrine-citing, not evidence.
- **v2 "Phase 33 absorbs MAP-02b" = +3-5j hidden scope transfer** (not elimination).
- **Honest question PM didn't ask Julien** : "Flutter UI ou CLI ?" — user choice, not panel-emergent.
- Recommend : hybrid re-pivot (v3) with Security fixes applied.

### 🟡 Python CLI — 5 gaps
1. sysexits.h exit codes not locked
2. 401/403/429 not differentiated
3. `--json` mode not specified (Phase 35 hard dep)
4. `NO_COLOR` env var missing
5. DRY_RUN fixture for unit tests missing

### 🟡 Technical writer — docs drift
- REQUIREMENTS.md still lists MAP-02 Phase 32 (inconsistent with v2 defer)
- ROADMAP.md still 148 routes, 23 redirects (inconsistent with 147, 43)
- Canonical refs paths may be broken
- Decision numbering inconsistency

## v2 → v3 changes (hybrid decision)

| Decision | v2 | v3 |
|----------|----|----|
| D-02 Sentry access | CLI direct, `event.tag:route:` (BROKEN) | CLI direct, `transaction:<path>` + quality bar |
| D-03 /admin shell | DEFERRED Phase 33 | REVERTED : AdminScaffold Phase 32 |
| D-05 Redirect | Math 0.009% | Math corrigé 0.258% |
| D-06 Dashboard | CLI terminal-only | CLI + Flutter UI registry viewer (both) |
| D-07 (NEW) | — | Route-tag query pattern resolution |
| D-08 (NEW) | — | CLI + Flutter UI quality bar |

---

## Panel 3 findings (4 NEW experts, v3 → v4 trigger)

### 🔴 Execution engineer — 5 execution blockers
1. **iOS simulator sandbox cassure** : Flutter UI ne peut pas lire `.cache/route-health.json` écrit par CLI sur Mac. Apple sandbox empêche cross-filesystem read. Options : (a) backend endpoint, (b) simctl trick fragile, (c) **simplify UI scope**.
2. **`GET /api/v1/admin/me` backend endpoint n'existe PAS** — CONTEXT v3 tue le backend mais spec ce endpoint pour AdminProvider.isAllowed. Contradiction interne.
3. RouteOwner ambiguïté cross-owner (`/coach/chat/from-budget` = coach ou budget ?).
4. `sentryTag ?? path` query builder logic non-spec'd.
5. Wave 0 extraction script non défini.

### 🔴 nLPD compliance — 5 P0/P1 controls missing
1. **SENTRY_AUTH_TOKEN scope non locké** — Art. 6 data minimization. Fix : lock `project:read` + `event:read`.
2. **Snapshot `.cache/route-health.json` retention undefined** — Art. 9 storage limitation. Fix : 7-day auto-delete.
3. **Raw Sentry events = PII non redacted** — Art. 6 + 12. Fix : redaction layer (user IDs, amounts, IBAN, email).
4. **Aucun admin tool access log** — Art. 12 processing record. Fix : breadcrumb `mint.admin.routes.viewed`.
5. **Transaction.name gap = observability incomplète** — Art. 5 accuracy. Fix : J0 smoke test + doc limitation.

### 🟡 Performance/scale — YELLOW at 5k DAU
- **CLI batch OR-query manquant** : 3 min full scan → 15 sec with batch. À locker J0 empirical.
- **Flutter UI rebuild jank** si non-memoized sur FeatureFlags ChangeNotifier Phase 33.
- **Quota math at scale** : 5k DAU = borderline $160 ceiling (requires tracesSampleRate 0.1→0.05), 10k DAU = $595/mo (3.7× over, Enterprise required).
- Binary size : 147 entries = ~2KB compiled enum table, negligible.
- Tree-shake unverified empirically — VALIDATION gate needed.

### 🟠 DevOps/release — MEDIUM maturity
- **Zero CI integration wired** pour parity lint, CLI pytest, tree-shake gate.
- **Keychain onboarding undocumented** — new dev friction 7/10.
- **32-VALIDATION.md nonexistant** — référencé dans CONTEXT, pas créé.
- **`ENABLE_ADMIN=1` non linté en CI prod** builds.
- **AdminProvider.isAllowed contradiction** (same as Execution finding) — backend endpoint absent.
- **Phase 35 dogfood hard-dep sur JSON schema** — schema.dart non spec'd comme livrable.

---

## v3 → v4 changes (structural fix pass, no Panel 4)

**Philosophy shift** : Panel 3 contrarian #2 called out panel-driven-design risk. v4 addresses FACTUAL findings (sandbox = Apple law, missing endpoint = verifiable, nLPD = regulation) NOT panel preferences. Self-discipline validated.

| Decision | v3 | v4 |
|----------|----|----|
| D-01 RouteMeta schema | Schema + enum 15 | UNCHANGED + owner ambiguity rule "first segment wins" |
| D-02 Sentry access | CLI direct + quality bar | + batch OR-query J0 validation + token scope lock (ref D-09) |
| D-03 AdminScaffold | Phase 32 with isAllowed via `/admin/me` | Phase 32 with isAllowed via **local FF (D-10)** |
| D-06 Dashboard UX | CLI + Flutter UI (UI reads snapshot JSON) | CLI + Flutter UI **pure schema viewer, NO snapshot read** |
| D-09 NEW | — | **nLPD controls locked** (token scope, redaction, retention, access log, Keychain hardening) |
| D-10 NEW | — | **AdminProvider = FeatureFlags.isAdmin local** (resolves v3 backend contradiction) |
| D-11 NEW | — | **32-VALIDATION.md artefact** with J0 empirical gates |
| D-12 NEW | — | **CI integration explicit** (parity job, pytest, schema publication, SETUP docs) |

**Why these are not "just another pivot"** :
- iOS sandbox is APPLE'S DESIGN, not a preference. Flutter UI reading Mac filesystem via iPhone sim = impossible.
- `/admin/me` endpoint missing is a VERIFIABLE FACT (grep confirmed).
- nLPD Art. 6, 9, 12 are LAW, not opinion.
- CI integration gaps are OPERATIONAL REALITY, not philosophical.

Panel 3 findings were structural, not aesthetic. v4 closes them by DESIGN SIMPLIFICATION (Flutter UI scope narrowed), not feature shuffling.

---

## Panel bias audit (consolidated across 3 rounds)

- Panel 1 : PM's prompts framed implicit skepticism of UI — contrarian #2 flagged this correctly
- Panel 2 contrarian #2 : self-aware attempt to correct Panel 1 bias, succeeded
- Panel 3 : PM's prompts this time were structural-facts-focused (iOS sandbox, backend fact-check, nLPD regulations, perf math) — LESS bias-prone
- **v4 self-discipline** : PM refused to auto-spawn Panel 4, Julien validated the discipline ("Je valide ton call")

---

## Locked decisions v4 per area

| Area | v1 | v2 | v3 | v4 (FINAL) |
|------|----|----|----|-----------|
| RouteMeta schema | 5 req + enum 15 + 2 opt | = | = | = + owner ambiguity rule |
| Sentry access | Backend proxy | CLI + lru_cache | CLI + transaction query + quality bar | = + batch J0 + token scope lock |
| Admin shell | Phase 32 scaffold | Phase 33 deferred | Phase 32 scaffold | Phase 32 scaffold + FF.isAdmin runtime gate |
| Parity lint | Regex | + KNOWN-MISSES | = | = + CI job D-12 |
| Redirect analytics | Breadcrumb 23 | Breadcrumb 43, math 0.009% | Math 0.258% | = + retention 7d (D-09) |
| Dashboard | MVP Flutter 9-col | CLI only | CLI + Flutter UI (reads snapshot) | CLI + **Flutter UI pure schema viewer (no snapshot)** |
| Route-tag query | — | — | `transaction:<path>` | = + J0 validation D-11 |
| Quality bar | — | — | sysexits + --json + NO_COLOR + DRY_RUN | = + schema.dart D-12 |
| nLPD controls | — | — | — | **NEW D-09 locked** |
| AdminProvider source | — | — | `/admin/me` (broken) | **NEW D-10 FF.isAdmin local** |
| VALIDATION artefact | — | — | — | **NEW D-11 32-VALIDATION.md** |
| CI integration | Implicit | Implicit | Implicit | **NEW D-12 explicit jobs + SETUP docs** |

---

## Deferred Ideas (consolidated v4)

See 32-CONTEXT.md v4 §deferred. Summary :
- Backend endpoint `/api/v1/admin/*` — killed cleanly (v4 D-10 uses FF.isAdmin), v2.9+ if multi-user.
- Codegen build_runner — v2.9+ if >5 regex false negatives.
- AST-based parity lint — v2.9+.
- Filter/search/export CLI+UI — MVP v2.8, v2.9+ if friction.
- Backend OpenAPI parity — v2.9+ MAP-06.
- Sunset 43 redirects — v2.9+ after 30-day zero-traffic.
- Per-route flag — v2.9+ if 11 flag-groups coarse.
- Phase 31 retroactive setTag('route') — only if D-11 J0 reveals SDK doesn't auto-set.
- Heatmap DIFF-02 — v2.9+ standalone.
- Sentry Enterprise tier — trigger 5-10k DAU (D-05 math).

---

## Canonical refs accumulated v4

- `.planning/ROADMAP.md` §Phase 32/33/36 (amended 2026-04-20)
- `.planning/REQUIREMENTS.md` §MAP (amended 2026-04-20)
- `decisions/ADR-20260419-v2.8-kill-policy.md`
- `decisions/ADR-20260419-autonomous-profile-tiered.md`
- `decisions/ADR-20260420-chat-vivant-deferred-v2.9-phase3.md`
- `.planning/phases/31-instrumenter/31-CONTEXT.md` D-03/D-05/D-06
- `apps/mobile/lib/app.dart:184` (SentryNavigatorObserver — D-07 foundation)
- `apps/mobile/lib/services/observability/breadcrumb_helper.dart`
- `apps/mobile/lib/services/error_boundary.dart:96` (setTag pattern evidence)
- `apps/mobile/lib/services/feature_flags.dart` (D-10 consumer)
- `tools/simulator/sentry_quota_smoke.sh` (Keychain + Sentry API pattern)
- Sentry Issues API docs (external)
- sysexits.h POSIX (external)
- NO_COLOR standard no-color.org (external)
- nLPD Swiss law Art. 5/6/7/9/12 (D-09 mapping)
- DESIGN_SYSTEM.md "Utility Screens" doctrine

---

*Expert-lock v4 justification : Julien authorized "Je valide ton call, je te fais confiance" after Panel 3 findings presented. PM applied C discipline (no Panel 4) and wrote v4 addressing factual structural blockers. 12 decisions locked. 3 panel rounds, 12 expert opinions, 1 PM synthesis. Julien retains override authority via /gsd-plan-phase review.*

*Panel history: Panel 1 (Flutter/Security/Staff/UX) → v2. Panel 2 (Python CLI/SRE/Contrarian/Tech writer) → v3. Panel 3 (Execution/nLPD/Perf/DevOps) → v4. Total 12 expert reviews across 3 rounds.*
