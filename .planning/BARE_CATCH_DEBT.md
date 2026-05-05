# Bare-Catch Debt Ledger — MINT Flutter app

**Last updated:** 2026-05-04 (Phase 87 Wave 1 closeout)
**Lint enforcer:** `tools/checks/no_new_bare_catch.py` (pre-commit blocking)
**Master plan:** v2.12 REQ OBSV-01..08 → v2.13 Wave 2 (next 50) → v2.14 Wave 3 (residual)

## Doctrine

A « bare catch » is a `} catch (e) {` or `} catch (_) {` block in
`apps/mobile/lib/` that **does not** route the exception through one of
the single-allowed Sentry capture surfaces:

- `Sentry.captureException(...)` (only inside `services/error_boundary.dart`,
  enforced by `tools/checks/sentry_capture_single_source.py`)
- `captureSwallowedException(...)` (the one allowed swallow path)
- A `MintBreadcrumbs.*(success: false, ...)` failure breadcrumb that the
  caller has explicitly chosen as observability-equivalent (rare, must be
  justified inline)

Wave 1 (Phase 87, this milestone) typed-converts the **15 highest-risk
sites** on the walker / data-integrity / UI-service path. The other 318
sites listed below are **grandfathered** and will be processed in waves:

| Wave | Phase | Count target | Scope |
|------|-------|--------------|-------|
| 1 | v2.12 / Phase 87 (closed) | 15 | walker + data-integrity + UI-service |
| 2 | v2.13 (next milestone) | next 50 | providers + services bulk |
| 3 | v2.14+ | residual | screens + widgets long-tail |

A bare catch listed below is **allowed** by the lint. Adding a NEW bare
catch (path:line not in this ledger) **fails** the pre-commit hook.

## Wave 1 — closed in Phase 87 (NOT in ledger, MUST stay typed)

| # | Bucket | File:Line (pre-edit) | Surface |
|---|--------|----------------------|---------|
| 1 | a | `apps/mobile/lib/main.dart:58` | `main.slm_init` |
| 2 | a | `apps/mobile/lib/main.dart:79` | `main.feature_flags_refresh` |
| 3 | a | `apps/mobile/lib/main.dart:68` (.catchError) | `main.slm_engine_preinit` |
| 4 | a | `apps/mobile/lib/main.dart:85` (.catchError) | `main.pillar3a_load` |
| 5 | a | `apps/mobile/lib/main.dart:96` (.catchError) | `main.regulatory_sync` |
| 6 | a | `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:253` | `anonymous_chat.persist` |
| 7 | b | `apps/mobile/lib/screens/auth/login_screen.dart:127` | `login.apple_sign_in` |
| 8 | b | `apps/mobile/lib/services/auth_service.dart:148` | `auth.refresh` |
| 9 | b | `apps/mobile/lib/services/anonymous_session_service.dart:32` | `anonymous_session.secure_read` |
| 10 | b | `apps/mobile/lib/services/anonymous_session_service.dart:47` | `anonymous_session.secure_write` |
| 11 | b | `apps/mobile/lib/services/api_service.dart:279` | `api.try_refresh` |
| 12 | c | `apps/mobile/lib/providers/coach_profile_provider.dart:189` | `coach_profile.sync_to_backend` |
| 13 | c | `apps/mobile/lib/providers/coach_profile_provider.dart:248` | `coach_profile.sync_from_backend` |
| 14 | c | `apps/mobile/lib/main.dart` (Sentry beforeSend) | `sentry.before_send` |
| 15 | d | `apps/mobile/lib/services/coach/coach_orchestrator.dart:978` | `coach_orchestrator.fallback_compliance` |

Plus one bonus typed-conversion on `apps/mobile/lib/services/feature_flags.dart:158` (refreshFromBackend), which fixes the
`Sentry.captureException` single-source lint violation that was failing
`tools/checks/sentry_capture_single_source.py` at Phase 86 close-out.

## Grandfathered — NOT in scope of Phase 87, allowed by lint

The following bare-catch sites are **currently allowed**. Each will be
addressed in a future wave per the table above. Format:

```
<relative-path>:<line>:<reason>
```

The lint reads the GRANDFATHERED block below (between the BEGIN/END
markers) and treats every listed `path:line` as exempt. New entries
require an ADR or a milestone roadmap reference.

<!-- BEGIN GRANDFATHERED -->
apps/mobile/lib/main_web.dart:25:web entrypoint — Wave 3
apps/mobile/lib/providers/coach_profile_provider.dart:510:Wave 2 — provider hydration path
apps/mobile/lib/providers/coach_profile_provider.dart:1083:Wave 2 — provider helper
apps/mobile/lib/providers/coach_profile_provider.dart:2253:Wave 2 — provider helper
apps/mobile/lib/providers/coach_profile_provider.dart:2419:Wave 2 — provider helper
<!-- END GRANDFATHERED -->

**Auto-generated raw debt list** (kept in sync by `tools/checks/no_new_bare_catch.py --regen-debt`)
lives at `tools/checks/bare_catch_debt.lock` — that is the actual
machine-readable allowlist. The block above is the human-curated subset
called out for context. The lock file enumerates **all 318 grandfathered
sites** so lint runs in O(n) without parsing markdown.

## How to add a NEW bare catch (escape hatch)

You can't, **except** in one of these cases:

1. **You typed-convert a Wave 1 site away from a bare catch.** Already done.
2. **You add a typed catch with `captureSwallowedException`.** Not bare → not blocked.
3. **The lint flags a false positive** (e.g. catch inside generator function
   the regex misclassifies). Add to `tools/checks/bare_catch_debt.lock`
   manually with rationale `false-positive: <kind>` and bump Wave-2 plan
   accordingly.

## Verification

```bash
python3 tools/checks/no_new_bare_catch.py
# OK — N grandfathered, 0 new violations
```

Pre-commit hook: `lefthook run pre-commit` ; the `no_new_bare_catch`
command MUST be green.
