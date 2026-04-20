# Phase 32: Cartographier — Discussion Log (expert-lock mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 32-cartographier
**Mode:** expert-lock (user authorized "b" / expert-lock, 2026-04-20, post-PR #367 merge)
**Areas analyzed:** 6 (all via expert-lock, no interactive Q&A per user choice)

---

## Session context

- Immediately after PR #367 merge (`b7a88cc89`, 2026-04-20 05:23 UTC) — Phase 31 Instrumenter shipped including real PII audit + flaky test fix + Chat Vivant v2.9 Phase 3 deferral ADR.
- Prior CONTEXT.md files read: 30.5, 30.6, 31 (inheritance D-03 breadcrumb naming, D-05 trace propagation, D-06 default-deny CustomPaint).
- Codebase scout confirmed : `app.dart` has 156 GoRoute declarations at session start, `lib/routes/` doesn't exist, `lib/screens/admin/` doesn't exist, `FeatureFlags` service exists, Phase 31 `MintBreadcrumbs` helper shipped.
- Julien doctrine applied : no-shortcuts + v2.8 kill-policy (no new features hors roadmap) + façade-sans-câblage guardrails.

## Areas presented + locked decisions

### Area 1 — RouteMeta schema extras

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| Required 5 only (path, category, owner, requiresAuth, killFlag) | Strict ROADMAP scope | |
| 5 required + owner=enum feature-group + description + sentryTag optional | Aligns with Phase 33 flag-groups, reduces drift | ✓ |
| 5 required + extra fields (owner, description, sentryTag, lastTouchedSha) | Maximal audit trail | |

**User's choice:** expert-lock → Option 2 (5 + 2 optional, owner=enum with 15 values).

**Notes:** 15 owners = 11 flag-groups Phase 33 + 4 système (anonymous/auth/admin/system). `lastTouchedSha` explicitly dropped (volatile, git blame suffices).

### Area 2 — Sentry Issues API access pattern

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| Mobile direct via `--dart-define=SENTRY_AUTH_TOKEN=...` | Simplest but token exfiltrable | |
| Backend proxy `/api/v1/admin/route-health` + mount-only refresh + 30s cache | Secure, rate-limit friendly | ✓ |
| Backend proxy + auto-refresh every 60s | More live data, hammers API | |

**User's choice:** expert-lock → Option 2 (backend proxy + mount-only + manual refresh button + 30s FastAPI cache).

**Notes:** Sentry rate limit 40 req/min default. Admin is solo usage (Julien), continuous auto-refresh wastes quota.

### Area 3 — /admin shell architecture

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone `/admin/routes` only, Phase 33 re-scaffold | Phase isolation | |
| Shared `AdminScaffold` shell + `/admin/routes` as child, Phase 33 adds `/admin/flags` child | Code reuse, -0.5j Phase 33 | ✓ |
| `/admin` monolithic screen with tabs | Simpler but conflates phases | |

**User's choice:** expert-lock → Option 2 (shared AdminScaffold, Phase 33 reuses).

**Notes:** Shell does `ENABLE_ADMIN` compile-time + `AdminProvider.isAllowed` runtime gate once, children inherit validated state.

### Area 4 — Parity lint scope

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| Mobile GoRoute ↔ kRouteRegistry only | Strict ROADMAP MAP-04 scope, tenable 1 sem | ✓ |
| Mobile parity + backend OpenAPI endpoints parity | Cross-layer enforcement | |
| Mobile parity + backend + analytics events parity | Full observability coverage | |

**User's choice:** expert-lock → Option 1 (mobile-only).

**Notes:** L2 profile mentioned "mobile↔backend OpenAPI parity" but that's overreach vs success criterion 4 wording. If cross-layer tension emerges, MAP-06 v2.9+ standalone.

### Area 5 — Redirect legacy analytics storage

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| Sentry breadcrumb counter (`mint.routing.legacy_redirect.hit`) | 0 new infra, inherits Phase 31 D-03 naming | ✓ |
| Backend analytics table + migration + `/admin/redirects` endpoint | Proper DB schema | |
| Local SQLite on device | Not shared across devices = useless for audit | |

**User's choice:** expert-lock → Option 1 (Sentry breadcrumb).

**Notes:** 23 redirects × ~10 hits/day = 230 events/day = 0.005% of Sentry Business 50k/mo quota. Negligible cost, maximum reuse.

### Area 6 — Dashboard UX

**Options presented:**

| Option | Description | Selected |
|--------|-------------|----------|
| MVP strict (table + status dot, no filter/search/export) | 1 sem tenable, no scope creep | ✓ |
| MVP + filter by owner/killFlag/status | +0.5j, nice-to-have | |
| Enriched (heatmap DIFF-02 + filter + export) | Explicit ROADMAP out-of-scope | |

**User's choice:** expert-lock → Option 1 (MVP strict).

**Notes:** DIFF-02 heatmap is explicitly listed in ROADMAP "Differentiators (Out of Scope v2.8)". Respect kill-policy. v2.9+ if friction emerges.

---

## Claude's Discretion (deferred to planner/executor)

- Shape of `AdminProvider.isAllowed` (ChangeNotifier vs StreamProvider) — Flutter pattern scan
- Tree-shaking verification approach for `/admin/routes` in prod IPA — likely `grep` on binary, doc in VALIDATION.md
- Status dot rendering (CSS circle vs icon) — MintColors palette
- `lib/routes/` vs `lib/router/` location — match existing conventions
- `/admin/me` endpoint vs reuse `/auth/me` + `is_admin` claim — backend executor decides

## Deferred Ideas

- Backend OpenAPI parity (MAP-06 v2.9+)
- Dashboard filter/search/export (v2.9+)
- Heatmap user paths DIFF-02 (v2.9+ standalone phase)
- 23 redirects sunset (defer v2.9+ after 30-day zero-traffic validation)
- Mobile↔Backend cross-layer parity (v2.9+)
- Per-route flag (v2.9+, only if 11 flag-groups become too coarse)

## Canonical refs captured during discussion

- ROADMAP.md §"Phase 32: Cartographier"
- REQUIREMENTS.md §MAP (MAP-01..05)
- STATE.md (post-PR #367 merge, b7a88cc89)
- 31-CONTEXT.md D-03, D-05, D-06 (inheritance)
- breadcrumb_helper.dart (Phase 31 ship)
- ADR-20260419-v2.8-kill-policy.md (scope discipline)
- ADR-20260419-autonomous-profile-tiered.md (L2 profile definition)
- Sentry Issues API docs (external)

---

*Expert-lock mode justification: Julien authorized "b" choice explicitly after 6-area presentation. All 6 decisions lock to PM/engineering recommendations marked "recommandé" in the presentation. Julien retains override authority via /gsd-plan-phase review.*
