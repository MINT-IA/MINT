# Phase 52 — Auth Local-First Toggle (CONTEXT)

**Status:** Open (planning)
**Origin:** Companion phase to PR #422 (register subtitle l10n) + PR #423 (data residency decision doc). Without Phase 52 landing, PR #422's promise « Sync controls coming to Settings soon » remains a forward-looking statement without code behind it.
**Decided by:** Julien signoff pending (data residency decision doc Status = Proposed).

## Goal (one sentence)

Refactor `auth_provider.dart` so account creation does NOT implicitly enable cloud sync, and add a Settings › Confidentialité toggle that lets the user explicitly opt IN to multi-device cloud sync. After Phase 52 lands, the « tes données restent sur ton appareil » strings across the app become universally accurate again.

## Why now

1. PR #422 shipped a forward-looking promise (« Sync controls coming to Settings soon ») in 6 locales. Phase 52 is what makes that promise true.
2. The data residency decision doc (Path A v2.x → Q3 Swiss-region → v3.0 E2EE) explicitly identifies Phase 52 as the v2.x deliverable.
3. Brand positioning « Ta lucidité. Ton appareil. Ton choix de synchroniser. » requires the toggle to exist.
4. nFADP art. 19 (information at collection) + LSFin art. 8 (no overstatement of feature availability) — without Phase 52, the gap between « what we say » and « what the code does » remains material.

## Locked decisions

### D-01 — Default local-mode after register/login
After this phase, `auth_provider.dart` keeps `_isLocalMode = true` after register/login. Account creation is identity-only (auth + JWT, profile metadata server-side for password reset). User data (chat history, profile fields, documents, insights) STAYS on device unless user explicitly enables cloud sync.

### D-02 — Settings location: Settings › Confidentialité
A new `confidentialite_settings_screen.dart` lives next to the existing `langue_settings_screen.dart` in `apps/mobile/lib/screens/settings/`. The route is `/settings/confidentialite`. The route is reachable from the Profile screen (Phase 50.x nav) under a « Confidentialité » row.

### D-03 — Toggle UX
A single explicit toggle: « Synchronisation cloud (multi-appareils) » with subtitle « Sauvegarde + sync chiffrée sur nos serveurs européens. Activable / désactivable à tout moment. » Default OFF. When toggled ON, the next sync push goes through; when OFF, no further data leaves the device. Existing cloud-side data is NOT auto-deleted on toggle-off (user can issue a separate « Supprimer mes données cloud » action — out of scope for Phase 52, deferred to v2.11).

### D-04 — Backwards compatibility for existing accounts
Existing users (registered before Phase 52) currently have `_isLocalMode = false` (silently set at register). On first launch post-update, we preserve their current behavior (cloud sync stays ON for them) but show a one-time « Nouvelle option : tu peux maintenant désactiver la synchronisation cloud depuis Réglages › Confidentialité » toast/sheet. Migration is opt-out for existing users (don't surprise-disable their sync), opt-IN for new users (default OFF).

### D-05 — Transparent state surfacing
The Profile screen displays a compact « Synchronisation : activée / désactivée » status row. The « Coach personnalisé » feature still works in both states — uses local SQLite for opted-out users, server-side coaching context for opted-in.

### D-06 — No backend changes in this phase
The backend `_isLocalMode` flag is mobile-only state. The backend already accepts both authenticated AND anonymous calls. Mobile gates whether to push profile updates / chat history / documents to the backend based on the local flag. Zero backend code change in Phase 52 (server-side opt-out implementation = v2.11 if needed).

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
After Phase 52 ships, update `authRegisterSubtitle` in 6 locales again — this time to the « really true » copy from the decision doc:
- FR: « Crée un compte chiffré. La synchronisation entre tes appareils est désactivable depuis Réglages › Confidentialité (par défaut activée). »
- (Or default-OFF + explicit opt-in framing depending on D-04 final wording — to confirm at PR time.)

### D-09 — Test coverage
- Widget test for the toggle Settings screen
- Provider test for `AuthProvider.toggleCloudSync(bool)` API
- Integration test: register new account → verify `_isLocalMode == true` post-register
- Integration test: existing account migration → verify `_isLocalMode` preserved
- Golden test for the Settings › Confidentialité screen (light + dark mode)

### D-10 — HTML report integration (per Julien instruction 2026-05-02)
Phase 52 produces `.planning/phases/52-auth-local-first-toggle/52-VERIFICATION-REPORT.html` alongside the standard text VERIFICATION.md. The HTML includes: live sim screenshots of the toggle in both states, before/after register-screen subtitle, network-inspector evidence that no PII transits while local mode is ON, panel review verdicts.

## Out of scope

- Server-side cloud-data deletion when user opts out (deferred v2.11)
- Per-data-class opt-in (e.g., sync chat but not profile) — deferred v2.11
- E2EE — deferred v3.0 (separate epic)
- Swiss-region hosting migration — deferred Q3 2026 (separate phase)
- Bulk sanitization of the « tes données restent sur ton appareil » strings across the app — they remain accurate post-Phase 52 (the toggle being default-OFF for new users + opt-out for existing makes the original claim true again)

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

- `.planning/decisions/2026-05-02-data-residency.md` (Path A locked decision)
- `.planning/reviews/2026-05-02-pr-batch-1.md` (panel review batch 1, identifies Phase 52 as required follow-up to PR #422)
- `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/feedback_app_targets_staging_always.md`
- `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/feedback_public_repo_discipline.md`
- PR #420, #421, #422, #423, #424, #425 (related ships in the 2026-05-02 session)
- `apps/mobile/lib/providers/auth_provider.dart:135` (the `_isLocalMode = false` flip site to refactor)
- `apps/mobile/lib/screens/settings/langue_settings_screen.dart` (sibling settings screen — pattern to follow)
