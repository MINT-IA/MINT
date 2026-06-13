# Verification

Status: IN_FLIGHT.

Already verified: Engram context/search; `CLAUDE.md`, `AGENTS.md`,
`docs/ROADMAP_V2.md`, `SOT.md`, identity/voice/design docs, `visions/`, and
relevant phase briefs; Claude model `claude-opus-4-8[1m]`; GSD timeouts
`600/600000`; `git status`, `git worktree list`, `git fetch --all --prune`,
`codex/mint-*`, requested SHAs, and storage/auth surfaces.

Checks run on this phase:

| Check | Result |
|---|---|
| `jq empty golden-onboarding-archetypes.json` | PASS |
| iPhone 17 Pro simulator, local feature-flag stub | PASS, landing -> `/start` -> `/onb` -> terminal dossier |
| Simulator screenshots | PASS, `evidence/simulator/01-landing.jpg` through `10-reset-returned-entry.jpg` |
| Simulator account handoff screenshots | PASS, `evidence/simulator/11-account-handoff-login-restart.jpg`, `12-account-handoff-register-apple.jpg`, `14-account-handoff-register-session-profile.jpg`, and `15-account-handoff-register-restart-session-profile.jpg` |
| `MINT_WALKER_ARTIFACTS=... bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_landing_to_diagnostic_onboarding.yaml` | PASS, Maestro 2.5.1 on iPhone 17 Pro; artifacts under `evidence/maestro/account-handoff-route-20260613T2245/` |
| `MINT_WALKER_ARTIFACTS=... bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_diagnostic_situation_scene.yaml` | PASS, structured diagnostic Situation path; artifacts under `evidence/maestro/diagnostic-situation-20260613T2255/` |
| `MINT_WALKER_ARTIFACTS=... bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_diagnostic_situation_scene.yaml` after session-profile handoff fix | PASS, iPhone 17 Pro with same local stub; artifacts under `evidence/maestro/diagnostic-handoff-session-profile-20260614T012029/` |
| Terminal actions | PASS, `Continuer`, `Créer un compte`, `Repartir de zéro`, `Sortir` visible with stable identifiers |
| Simulator reset action | PASS, `Repartir de zéro` returns to the onboarding entry without profile flush |
| `flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/providers/auth_provider_test.dart test/screens/profile/financial_summary_screen_test.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart` | PASS, 97 tests |
| `flutter test test/providers/auth_provider_test.dart test/services/secure_wizard_store_test.dart test/services/anonymous_session_service_test.dart test/services/report_persistence_service_test.dart` | PASS, 115 tests; fresh-install Keychain purge, pending retry, and profile `clearAll` secure-key purge red/green covered |
| `flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/providers/auth_provider_test.dart test/screens/profile/financial_summary_screen_test.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart test/services/secure_wizard_store_test.dart test/services/anonymous_session_service_test.dart test/services/report_persistence_service_test.dart test/screens/retirement_dashboard_profile_test.dart` | PASS, 181 tests |
| `flutter test test/services/account_handoff_service_test.dart test/screens/register_account_entry_test.dart test/services/api_service_test.dart test/providers/auth_provider_test.dart` | PASS, 80 tests; missing choice keeps data separate, existing-account login keeps the local dossier separate without explicit choice, explicit keep, explicit restart purge, stale choice expiry, feature-flag off, budget/letters detection, registration UI choice, session-only wedge profile detection, and magic-link auth bootstrap covered |
| `flutter test test/screens/auth_screens_smoke_test.dart test/services/account_handoff_service_test.dart test/screens/register_account_entry_test.dart test/providers/auth_provider_test.dart` | PASS, 98 tests |
| `flutter analyze` | PASS, no issues |
| `./tools/mint-routes check` | PASS, 145 routes after known-miss exemptions |
| `flutter gen-l10n` | PASS |
| `python3 tools/checks/arb_parity.py --locale all` | PASS, 6 locales, 6986 keys each |
| `python3 tools/checks/banned_terms_arb.py --locale all` | PASS |
| `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` | PASS |
| `python3 tools/checks/accent_lint_fr.py --scope .planning/phases/mint-north-star-experience-v1 .planning/phases/mint-onboarding-auth-reset-restore-integration` | PASS |
| `python3 tools/checks/no_legal_admission_in_public_docs.py --paths ...` | PASS, 4 doc paths scanned, 0 hit |
| `git diff --check` | PASS, CRLF warnings only on generated l10n Dart files |
| MCP `check_banned_terms` / `check_accent_patterns` on new FR action text | PASS |
| `claude -p` independent contract review | REVISE, findings incorporated in state/scoring/fixtures |
| `claude -p` re-review | PASS on prior findings; non-blocking tax-residence naming nit noted |

Gate state:

| Gate | Status | Note |
|---|---|---|
| G1 Maestro/walker | PASS TARGETED | Maestro route-contract flow passed for landing -> diagnostic onboarding; broader persona walker remains open. |
| G2 Julien/device | OPEN | Required for Keychain persistence, iCloud/backup restore, auth redirects, and Apple entitlement. |
| G3 CI/dev/local | PARTIAL | Local tests/analyze/routes pass; CI/dev equivalence still requires branch/rebase workflow. |
| G4 Regression | PASS LOCAL | Focused DataSpine/auth/profile/onboarding and secure-storage reset regressions passed locally. |
| G5 Lints/parity/compliance | PASS LOCAL | L10n parity, banned terms, accent lint, public-doc admission lint passed locally. |

Non-proofs: simulator-only Keychain/iCloud/backup, Apple-primary UI without
entitlement proof, open PR without runtime, mock LLM output without golden eval.

Runtime notes:

- The simulator run used `API_BASE_URL=http://127.0.0.1:8888/api/v1` with a
  minimal local stub for `/health` and `/config/feature-flags`, returning
  `enableMvpWedgeOnboarding=true`.
- The Maestro route-contract run used the same local stub and `launchApp:
  clearState`. Assertions covered landing CTA, `/onb` entry identifier,
  absence of the old empty-chat prompt, and the intent explorer. Stubbed
  non-contract routes such as `/snapshots` returned 404 and did not affect the
  flow.
- The Maestro Situation run covered a deeper structured path: selected the
  Situation intent, answered FATCA/residence/status/household/move/date/canton
  and revenue prompts, then asserted `Ce que Mint peut déjà situer`, `Repères
  captés`, `Vaud · environ 7’250 CHF/mois net`, `À préciser ensuite`, and
  absence of the retirement fallback scene.
- The account entry simulator run verified login and registration: the handoff
  segmented control is visible, `Repartir` updates the explanatory copy, Apple
  remains primary on iPhone registration, and e-mail remains a fallback.
- The session-profile simulator run caught and fixed a runtime-only handoff
  gap: after wedge completion on the debug simulator, secure seal may fail with
  Keychain `-34018`, leaving a CoachProfile only in memory. The register
  handoff panel now also observes `CoachProfileProvider.hasProfile`, so it shows
  `Mint a des éléments...` instead of `Aucune donnée locale...` for that current
  dossier.
- The first simulator launch logged Keychain read `-34018` for token access in
  debug simulator; onboarding continued. This is not a device proof and keeps
  G2 open.
- The fresh-install Keychain contract is unit-tested with an empty
  SharedPreferences marker store and stale MINT secure-storage keys. It proves
  the Dart decision order, not iCloud/backup restoration semantics.
- Partial secure purge failure keeps `mint_install_secure_purge_pending_v1`
  and blocks auth restore on the next launch until the owned-key purge succeeds.
- Anonymous -> account handoff is widget/service-tested: missing or stale
  choice keeps the local dossier separate; fresh explicit keep attaches it for
  migration; explicit restart clears the anonymous local dossier before account
  migration. The detector now includes budget-only and generated-letter local
  data.
- Existing-account login is provider-tested with cloud sync enabled: without an
  explicit handoff choice, Mint does not call `/sync/claim-local-data`, the
  account namespace stays separate, and the anonymous dossier remains available.
- Magic-link verification now fetches `/auth/me` with the fresh bearer before
  saving the final session; `AuthService.saveToken()` remains strict and never
  accepts empty user IDs or emails.
- Profile reset preserves the login session but purges local owned secure
  feature keys such as BYOK, partner estimate, biography, anonymous session
  and wizard secure values.
- The 3a scene displayed an indicative fiscal range only after canton, income
  range, employment/LPP status, and source/hypothesis text were visible.
