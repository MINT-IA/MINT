# Verification

## Completed

- Restored Engram context for project `mint`.
- Ran six read-only expert reviews: product, UX research, design system, architecture, AI, trust/security.
- Verified Claude setting: `claude-opus-4-8[1m]`.
- Fixed planning config to include `cross_ai_timeout=600` and `subagent_timeout=600000`.
- Checked current worktree status before edits.
- Counted local surface size: `156` route declarations, `122` screen files, `191` screen classes.
- Verified `DataSpineSnapshot` already exists and should be extended rather than duplicated.
- Passed `git diff --check`, JSON validation, targeted no-legal scan, banned-term scan, accent scan, and ARB parity.
- Added first TDD slice for spine trust metadata and coach-packet serialization.
- Passed `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart`.
- Passed `cd apps/mobile && flutter test test/services/data_spine_readiness_digest_service_test.dart`.
- Passed `cd apps/mobile && flutter analyze`.
- Added second TDD slice for account/data state:
  - `MintAccountDataState` in `AuthProvider`;
  - account state values for anonymous local, signed out, account sync off, cloud sync on, and delete pending;
  - profile sync status row now consumes the derived account/data state instead of a raw cloud-sync boolean.
- Passed `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/providers/auth_provider_test.dart test/screens/profile/financial_summary_screen_test.dart` with 75 passing tests.
- Passed `cd apps/mobile && flutter analyze`.
- Passed `git diff --check`.
- Passed `./tools/mint-routes check`.
- Re-verified `.planning/config.json`: `cross_ai_timeout=600`, `subagent_timeout=600000`.
- Passed targeted no-legal scan for the two active phase directories.
- Passed targeted banned-term scan and FR accent-pattern scan after verification doc update.
- Passed ARB parity through Phase 30.7 MCP: 6 locales, 6936 keys each.
- Added third TDD slice for the `/onb` terminal dossier state:
  - terminal step now shows account/data state, understood facts, missing items, and useful next questions before `Creuser` / `Plus tard`;
  - state label reads `AuthProvider.accountDataState`;
  - text is localized through 6 ARB files and generated `app_localizations*.dart`.
- Passed red/green storyboard check:
  - red failure: missing `État du dossier` block;
  - green command: `cd apps/mobile && flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart` with 20 passing tests.
- Passed combined targeted Flutter tests after the third slice:
  - `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/providers/auth_provider_test.dart test/screens/profile/financial_summary_screen_test.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart`;
  - 95 passing tests.
- Passed `cd apps/mobile && flutter analyze`.
- Passed `python3 tools/checks/arb_parity.py --locale all` in the active worktree: 6 locales, 6974 keys each.
- Passed `python3 tools/checks/banned_terms_arb.py --locale all`.
- Passed `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb`.
- Note: Phase 30.7 MCP `validate_arb_parity` currently points at the main checkout path and still reports 6936 keys; use the worktree-local script output for this branch until the MCP path is configurable.
- Julien explicitly approved going above the repo's preferred <300-line size for this chantier; keep changes coherent and verified instead of splitting solely for line count.

## Not Done

- The complete North Star first-run rail is not rebuilt yet; only the existing `/onb` terminal step now exposes the dossier/account state.
- No backend code changed or backend tests run in this phase.
- No branch merge, PR, or staging/TestFlight validation.
- No public legal copy changed.
- Global no-legal scan still reports existing historical `.planning` hits unrelated to this phase.
- `AuthProvider` tests still log existing localhost hydration failures during `checkAuth()`; the provider catches them and the targeted tests pass, but this remains a test-harness noise source to clean separately.

## Required Before Next UI Slice

- Keep `Premier éclairage` as the user-facing first artifact name unless Julien changes it.
- Route the first-run rail from the existing `DataSpineSnapshot` and `MintAccountDataState`, not raw `CoachProfile`/auth booleans.
- Add golden/widget coverage before broadening the onboarding UI beyond the tested terminal summary.
- Keep `/start` as the rollout seam; do not point to the legacy Premier Éclairage route until it stops being a chat shim.
- Keep Keychain/iCloud restore claims open until G2 device validation.
