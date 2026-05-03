# Phase 52 — post-merge panel review (T-52-08)

**Date:** 2026-05-03
**Reviewers:** 4-person panel (product / compliance / engineering / adversarial)
**Verdict:** **BLOCK** — toggle is non-functional + one false copy claim
**Follow-up:** Phase 52.1 (cloud-sync actual gating) — opened immediately

## Headline finding

The Phase 52 cloud-sync toggle (`AuthProvider.toggleCloudSync` + `isCloudSyncEnabled`) was wired into the UI surface (Settings › Confidentialité, Profile sync row, migration toast) but **never wired into the backend writers**. Today, `isLocalMode` is read in exactly two non-test, non-self locations (`app.dart:298` router auth guard, `app.dart:414` shell visibility). **Zero service or backend writer checks the flag.**

Concretely: with sync OFF + user logged in → next chat message still hits `/coach/chat`, next profile edit still calls `claimLocalData`. Reproducible in 30 seconds with Charles Proxy.

This is **journalistically defensible as « MINT shipped a privacy toggle that does nothing — server still gets all your data »**. Worst posture: not « known limitation, ship anyway » but « shipped as if complete ».

## Block-list (must fix before Phase 52 is « done »)

| ID | File:line | Defect | Fix |
|---|---|---|---|
| B-1 | `apps/mobile/lib/providers/coach_profile_provider.dart:156` (`_syncToBackend`) | Gates only on `AuthService.isLoggedIn()`, not on `isLocalMode`. Fired from 4 callsites — every profile mutation pushes regardless of toggle. | Read `AuthProvider.isLocalMode` (or `isCloudSyncEnabled`); early-return when `false`. |
| B-2 | `apps/mobile/lib/providers/auth_provider.dart:681` (`_migrateLocalDataIfNeeded` → `claimLocalData`) | Every login path (register / login / Apple SSO / magic-link) pushes anonymous data unconditionally. New register flow with `isLocalMode = true` immediately ships local data to backend; UI says « off ». | Decide product behavior on register: D-01 says default OFF for new accounts → must NOT auto-push. Gate the `claimLocalData` block on `isCloudSyncEnabled`. |
| B-3 | `apps/mobile/lib/services/coach/coach_chat_api_service.dart` | Sends every message to `/coach/chat` regardless of toggle. **Nuance:** LLM call is unavoidable (no on-device LLM); the gateable part is « do we PERSIST chat history server-side for cross-device sync? ». | Design panel before coding — disambiguate « LLM call » (always allowed) vs. « server-side history persistence » (gated). Update `settingsPrivacyDataLocation` copy if necessary. |
| B-4 | `apps/mobile/lib/l10n/app_*.arb` (6 locales) — `settingsPrivacyDataLocation` value contains « serveurs européens (Suisse/UE) » | Backend currently runs on Railway US (no Swiss region available). Data-residency decision (`/.planning/decisions/2026-05-02-data-residency.md:50`) classifies Swiss/EU migration as Q3 2026 backlog. Shipping « serveurs européens » today is factual misrepresentation under nFADP art. 19. | Replace with truthful current-state copy until Q3 migration ships. |

## Needs-followup (next sprint, not blocking)

- **N-1**: Soften « chiffrement de bout en bout prévu en v3.0 » → « envisagé pour une version future » in 6 ARBs (defensible-if-slipped framing).
- **N-2**: Add an acceptance test that asserts: with `auth_local_mode=true`, `_syncToBackend` is a no-op (mock `ApiService.claimLocalData`, `verifyNever(...)`).
- **N-3**: Re-time the migration toast — defer until after first user-initiated navigation OR first 3 s of stable foreground; add unit test for « not fired during isLoading transition ».
- **N-4**: Verify the « Continuer en mode local » CTAs on auth screens still call `enableLocalMode()` after logout (logout sets `_isLocalMode = false` per `auth_provider.dart:558`; if the CTA is gone, anonymous re-use silently disables local mode).

## What was actually clean

- The UI chain (Settings ↔ Profile row ↔ migration toast) is functional and consistent.
- The server-data-persists caveat (`settingsPrivacyCloudSyncOffServerCaveat`) is correctly gated to `!cloudSyncOn && isLoggedIn`.
- Migration toast does not violate FDPIC art. 6 (no behavior change for legacy users — only a new control surfaced; copy is neutral « nouvelle option »).

## Lesson for the design-panel-first discipline

The pre-implementation panels for T-52-02 (Settings screen) and T-52-04 (migration toast) reviewed UX, copy, a11y, compliance — but **none asked the load-bearing engineering question « does the toggle actually gate any write path? »**. The post-merge panel caught it; the pre-implementation panels did not.

→ **Update to memory rule `feedback_design_panel_before_push.md`**: every screen panel must include an « engineering / wiring reviewer » who traces whether the new control's state is actually consumed by the data-flow it claims to gate.

## Phase 52.1 scope

`.planning/phases/52.1-cloud-sync-actual-gating/` — see CONTEXT + PLAN.
