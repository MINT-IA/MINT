# Phase 52 — Auth Local-First Toggle (CONTEXT)

**Status:** Drafting
**Origin:** Companion phase to PR #422 (register subtitle l10n) and the data-residency decision doc. PR #422's subtitle says « Sync controls coming to Settings soon »; Phase 52 is the code behind that line.

## Goal (one sentence)

Refactor `auth_provider.dart` so account creation does not enable cloud sync as a side effect, and add a Settings › Confidentialité toggle that lets the user opt in or out of multi-device cloud sync. After Phase 52 lands, the « tes données restent sur ton appareil » strings across the app match the runtime behavior.

## Why now

1. PR #422 references Settings controls that do not yet exist; Phase 52 makes that copy match the code.
2. The data-residency decision doc (Path A v2.x → Q3 Swiss-region → v3.0 E2EE) names Phase 52 as the v2.x deliverable.
3. nFADP art. 19 (information at collection) and LSFin art. 8 (accurate description of feature availability) frame the alignment between in-app copy and runtime behavior.

## Locked decisions

### D-01 — Default local-mode after register/login
After this phase, `auth_provider.dart` keeps `_isLocalMode = true` after register/login. Account creation is identity-only (auth + JWT, profile metadata server-side for password reset). User data (chat history, profile fields, documents, insights) STAYS on device unless user explicitly enables cloud sync.

### D-02 — Settings location: Settings › Confidentialité
A new `confidentialite_settings_screen.dart` lives next to the existing `langue_settings_screen.dart` in `apps/mobile/lib/screens/settings/`. The route is `/settings/confidentialite`. The route is reachable from the Profile screen (Phase 50.x nav) under a « Confidentialité » row.

### D-03 — Toggle UX
A single explicit toggle: « Synchronisation cloud (multi-appareils) » with subtitle « Sauvegarde + sync chiffrée sur nos serveurs européens. Activable / désactivable à tout moment. » Default OFF. When toggled ON, the next sync push goes through; when OFF, no further data leaves the device. Existing cloud-side data is NOT auto-deleted on toggle-off (user can issue a separate « Supprimer mes données cloud » action — out of scope for Phase 52, deferred to v2.11).

### D-04 — Backwards compatibility for existing accounts
Existing users (registered before Phase 52) currently have `_isLocalMode = false` as part of the existing register flow. On first launch post-update, we preserve their current sync state and show a one-time « Nouvelle option : tu peux désactiver la synchronisation cloud depuis Réglages › Confidentialité » toast or sheet. New accounts default OFF; existing accounts retain whatever state they had. The migration toast surfaces the new control so existing users can adopt the new default if they wish — without changing their sync state without consent.

### D-05 — Transparent state surfacing
The Profile screen displays a compact « Synchronisation : activée / désactivée » status row. The « Coach personnalisé » feature works in both states — local SQLite for opted-out users, server-side coaching context for opted-in.

### D-06 — Mobile state only in this phase; cloud-side deletion in v2.11
The local-mode flag is mobile-only state. Mobile gates whether to push profile updates, chat history, and documents to the backend based on this flag. Phase 52 does not change backend code.

The cloud-side data already pushed before a user toggles OFF stays on the backend until the v2.11 « Supprimer mes données cloud » action lands. The toggle subtitle and Settings page must say so explicitly, so a user toggling OFF understands that "no further data leaves the device" and "delete what is already on the server" are separate actions. nFADP art. 32 (right to deletion / Recht auf Löschung) is the handle for the v2.11 follow-up, not Phase 52.

### D-07 — String key naming convention
New ARB keys prefixed `settingsPrivacy*`:
- `settingsPrivacyTitle` → « Confidentialité »
- `settingsPrivacyCloudSyncTitle` → « Synchronisation cloud (multi-appareils) »
- `settingsPrivacyCloudSyncSubtitle` → « Sauvegarde + sync chiffrée sur nos serveurs européens. Activable / désactivable à tout moment. »
- `settingsPrivacyCloudSyncOn` → « Activée »
- `settingsPrivacyCloudSyncOff` → « Désactivée »
- `settingsPrivacyMigrationToast` → « Nouvelle option : tu peux désactiver la synchronisation cloud depuis Réglages › Confidentialité »
- `settingsPrivacyDataLocation` → « Tes données restent chiffrées sur ton appareil. Avec la sync cloud, elles sont aussi chiffrées sur nos serveurs européens (sauvegarde + multi-appareils). »

All 6 locales (FR canonical / EN / DE / ES / IT / PT). FR uses tutoiement.

### D-08 — Update register screen subtitle (post-Phase 52)
After Phase 52 ships, update `authRegisterSubtitle` in 6 locales to match D-01 (default OFF for new accounts):
- FR: « Crée un compte chiffré. La synchronisation cloud est désactivée par défaut ; tu peux l'activer depuis Réglages › Confidentialité. »
- EN / DE / ES / IT / PT: equivalent default-OFF framing.

### D-09 — Test coverage
- Widget test for the toggle Settings screen
- Provider test for `AuthProvider.toggleCloudSync(bool)` API
- Integration test: register new account → verify `_isLocalMode == true` post-register
- Integration test: existing account migration → verify `_isLocalMode` preserved
- Golden test for the Settings › Confidentialité screen (light + dark mode)

### D-10 — HTML report integration (per Julien instruction 2026-05-02)
Phase 52 produces `.planning/phases/52-auth-local-first-toggle/52-VERIFICATION-REPORT.html` alongside the standard text VERIFICATION.md. The HTML includes: live sim screenshots of the toggle in both states, before/after register-screen subtitle, network-inspector evidence that no PII transits while local mode is ON, panel review verdicts.

## Out of scope

- Server-side deletion of data already pushed before opt-out (deferred v2.11; nFADP art. 32 follow-up — see D-06)
- Per-data-class opt-in (e.g., sync chat but not profile) — deferred v2.11
- E2EE — deferred v3.0 (separate epic)
- Swiss-region hosting migration — deferred Q3 2026 (separate phase)
- Bulk rewrite of the « tes données restent sur ton appareil » strings across the app — they describe the new default once Phase 52 ships

## Risk register

| ID | Risk | Mitigation |
|----|------|------------|
| R-01 | Existing users surprised by toggle change → support tickets | Migration toast + status visible in Profile (D-04, D-05) |
| R-02 | Sync state desync between mobile and backend (mobile thinks OFF, backend has stale data) | Mobile is the writer; backend is read-only follower of mobile state. Never the other way. |
| R-03 | Coach quality drops for opted-out users (no server-side context) | Local SQLite holds last 50 chat turns + profile snapshot; coaching prompt assembled client-side from local data; LLM call is single-shot stateless server-side. |
| R-04 | Toggle confusion: users don't know what « cloud sync » means in Swiss-financial context | Settings row subtitle explicit; status row in Profile; first-time toast (D-04) |
| R-05 | i18n drift across 7 new ARB keys × 6 locales | accent_lint_fr + arb_parity (existing checks) + native review for DE/IT/PT |

## Verification plan (high level)

1. Unit + widget tests pass (D-09)
2. Live sim walkthrough: register → verify default-OFF → toggle ON in Settings → verify sync starts → toggle OFF → verify no further outbound calls (network inspector evidence in the HTML report per D-10)
3. Migration test: launch with pre-Phase-52 account state → verify sync-ON preserved + migration toast shown once
4. ARB parity check passes
5. accent_lint_fr passes on FR strings
6. Panel review on the PR before merge (per `feedback_expert_panel_pattern.md` sub-pattern)

## Estimated effort

- Implementation (auth_provider refactor + Settings screen + Profile status row + ARB × 6 + migration logic): 1-1.5 days
- Tests: 0.5 day
- Live sim verification + HTML report: 0.5 day
- Panel review + revisions: 0.5 day
- **Total: 2.5-3 days**

## References

- `.planning/decisions/2026-05-02-data-residency.md` (Path A — Proposed)
- `.planning/reviews/2026-05-02-pr-batch-1.md` (panel review batch 1, identifies Phase 52 as required follow-up to PR #422)
- PR #420, #421, #422, #423, #424, #425 (related ships in the 2026-05-02 session)
- `apps/mobile/lib/providers/auth_provider.dart` (`_isLocalMode = false` flip site to refactor)
- `apps/mobile/lib/screens/settings/langue_settings_screen.dart` (sibling settings screen — pattern to follow)
