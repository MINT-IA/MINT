# Phase 52 — Auth Local-First Toggle (PLAN)

**Status:** Drafting
**Companion CONTEXT:** `52-CONTEXT.md`
**Estimated effort:** 2.5-3 days
**Branch:** `feature/phase-52-auth-local-first-toggle` (from dev)

## Goal (one sentence)

Make MINT's local-first promise structurally true: refactor `auth_provider.dart` so account creation does NOT implicitly enable cloud sync, and add a Settings › Confidentialité toggle for explicit user opt-in.

## Tasks (sequential)

### T-52-01 — Refactor `auth_provider.dart` for local-mode default
**Files:**
- `apps/mobile/lib/providers/auth_provider.dart`
- `apps/mobile/test/providers/auth_provider_test.dart`

**Behavior:**
- `_isLocalMode` defaults to `true` on fresh install (already does — see the « Local-mode default: true on fresh install » comment).
- Remove the assignment that flips `_isLocalMode = false` inside the existing register flow so register / login no longer changes the default.
- New API: `Future<void> AuthProvider.toggleCloudSync(bool enabled)` — sets `_isLocalMode = !enabled`, persists to SharedPreferences, notifies listeners.
- New getter: `bool get isCloudSyncEnabled => !_isLocalMode`.
- Migration: existing accounts (registered pre-Phase 52 with `_isLocalMode = false`) keep their current state. Detect by absence of a new SharedPreferences key `auth_phase52_migrated` — set it true on first launch post-update.

**Test:** widget tests for the API + integration test for register flow asserting `_isLocalMode == true` post-register.

### T-52-02 — New Settings › Confidentialité screen
**Files:**
- `apps/mobile/lib/screens/settings/confidentialite_settings_screen.dart` (new)
- `apps/mobile/lib/app.dart` (route registration `/settings/confidentialite`)

**UX:**
- AppBar title `settingsPrivacyTitle` (« Confidentialité »)
- One row: « Synchronisation cloud (multi-appareils) » with subtitle, ListTile + trailing Switch
- Subtitle: « Sauvegarde + sync chiffrée sur nos serveurs européens. Activable / désactivable à tout moment. »
- Below: « Tes données restent chiffrées sur ton appareil. Avec la sync cloud, elles sont aussi chiffrées sur nos serveurs européens (sauvegarde + multi-appareils). » (italic textMuted)
- Pattern: mirror `langue_settings_screen.dart` styling for consistency
- Tap toggle → calls `AuthProvider.toggleCloudSync(value)` → HapticFeedback.selectionClick

**Test:** widget test asserting the toggle state mirrors `AuthProvider.isCloudSyncEnabled`.

### T-52-03 — Profile screen « Synchronisation » status row + entry to Settings › Confidentialité
**Files:**
- `apps/mobile/lib/screens/profile/financial_summary_screen.dart` (or wherever the Profile tabs live — to confirm during impl)

**UX:**
- New compact row in the Profile screen: « Synchronisation » + status badge (« Activée » sauge / « Désactivée » muted) + chevron → tap navigates to `/settings/confidentialite`
- The « Confidentialité » row also accessible from a Settings menu if such menu exists (need to check current Profile layout — currently the Profile mostly shows financial summary, may need to add a « Réglages » section)

**Test:** widget test asserting the status row reflects the provider state.

### T-52-04 — Migration toast for existing users
**Files:**
- `apps/mobile/lib/services/migration_phase52_service.dart` (new)
- `apps/mobile/lib/main.dart` (call into migration check on startup)

**Behavior:**
- On startup, after AuthProvider hydrates: if user is logged in AND `auth_phase52_migrated` key absent in SharedPreferences:
  - Set `auth_phase52_migrated = true`
  - Schedule a one-shot SnackBar / bottom sheet for the user's next chat surface visit:  
    « Nouvelle option : tu peux désactiver la synchronisation cloud depuis Réglages › Confidentialité » + CTA « Voir » → `/settings/confidentialite`
- New users (registered post-Phase 52) skip the toast entirely (their default is OFF)

**Test:** unit test for the migration service.

### T-52-05 — ARB strings ×6 locales
**Files:**
- `apps/mobile/lib/l10n/app_fr.arb` (canonical) + `app_en.arb` + `app_de.arb` + `app_es.arb` + `app_it.arb` + `app_pt.arb`

**New keys (per CONTEXT D-07):**
- `settingsPrivacyTitle`
- `settingsPrivacyCloudSyncTitle`
- `settingsPrivacyCloudSyncSubtitle`
- `settingsPrivacyCloudSyncOn`
- `settingsPrivacyCloudSyncOff`
- `settingsPrivacyMigrationToast`
- `settingsPrivacyDataLocation`

**Verify:** `flutter gen-l10n` regenerates dart files. `python3 tools/checks/accent_lint_fr.py --file app_fr.arb` clean. `arb_parity` check (existing) passes.

### T-52-06 — Update `authRegisterSubtitle` to match Phase 52 default
**Files:** 6 ARB locales

**Behavior:**
- After T-52-01 lands, replace the placeholder copy from PR #422 with text that matches D-01 (default OFF for new accounts):
  - FR: « Crée un compte chiffré. La synchronisation cloud est désactivée par défaut ; tu peux l'activer depuis Réglages › Confidentialité. »
  - EN: « Create an encrypted account. Cloud sync is off by default; you can turn it on in Settings › Privacy. »
  - DE / ES / IT / PT: equivalent default-OFF framing.

### T-52-07 — Live sim verification + HTML evidence report
**Files:**
- `.planning/phases/52-auth-local-first-toggle/52-VERIFICATION-REPORT.html` (new — per CONTEXT D-10 HTML report integration)
- `.planning/phases/52-auth-local-first-toggle/52-VERIFICATION.md` (new — standard GSD text dossier)
- Screenshot artifacts under `.planning/phases/52-auth-local-first-toggle/screenshots/`

**Steps:**
- Build sim with the new code
- Live walkthrough:
  1. Fresh install → register new account → verify Settings › Confidentialité shows « Désactivée » by default
  2. Open Profile → verify « Synchronisation : Désactivée » status row
  3. Tap into Settings › Confidentialité → toggle ON → verify HapticFeedback + Switch animation
  4. Send a chat message → verify backend receives it (network inspector OR backend log)
  5. Toggle OFF → verify next chat message NOT pushed to backend (local only)
  6. Migration test: install pre-Phase-52 build → register → install Phase 52 build over it → verify migration toast appears once + sync stays ON
- Capture screenshots for each step
- Compile HTML report with:
  - Screenshots
  - Pre/post code diff highlights
  - Network-inspector evidence
  - Test counts + analyze output
  - Panel review verdicts (run a 3-reviewer panel on the implementation)

### T-52-08 — Panel review (per « Panel Reviews of MY OWN PRs » sub-pattern)
**Reviewers:** code (Flutter/M3/a11y), compliance (nFADP/LSFin), brand voice.

**Synthesize, fix critical findings, push, then merge.**

## Dependencies

- T-52-01 → T-52-02 (toggle screen needs the API)
- T-52-02 → T-52-03 (Profile status row needs the route to navigate to)
- T-52-04 (migration) can land in parallel with T-52-02/03
- T-52-05 (ARB) feeds T-52-02/03/04
- T-52-06 (register subtitle update) blocked on T-52-01 landing in dev
- T-52-07 + T-52-08 are post-impl

## Acceptance criteria (« must-haves »)

1. `AuthProvider._isLocalMode` defaults true on fresh install + STAYS true after register/login
2. Settings › Confidentialité screen exists at `/settings/confidentialite`
3. Toggle Switch is wired to `AuthProvider.toggleCloudSync(bool)`
4. Profile screen displays the sync status + tap entry into Settings
5. Migration toast appears exactly once for pre-Phase-52 users
6. ARB parity check passes (7 new keys × 6 locales)
7. `flutter analyze` exits 0 on changed files
8. `flutter test` exits 0 (new widget + provider + integration tests included)
9. `accent_lint_fr.py` clean on FR strings
10. Live sim walkthrough captured (≥6 screenshots) in 52-VERIFICATION-REPORT.html
11. Panel review (3 reviewers) verdict: APPROVE on critical, follow-ups logged
12. PR description references CONTEXT.md + decision doc + companion PRs (#422 to be updated post-merge per T-52-06)

## Notes

- This phase tracks the data-residency decision doc (`.planning/decisions/2026-05-02-data-residency.md`, Status = Proposed). If Path A is replaced, revisit D-01 and D-04 before starting implementation.
- The phase produces standard GSD text artifacts (CONTEXT.md, PLAN.md, SUMMARY.md, VERIFICATION.md) plus an HTML evidence report alongside.
