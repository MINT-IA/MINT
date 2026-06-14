# Summary

Status: IN_FLIGHT.

Done: context restored; Claude/GSD config verified; stack SHAs checked; clean
worktree selected; state contract, golden fixtures, scoring grid, verification
doc, and report created before product code; ClaudeCLI REVISE incorporated.
Product slice now adds a structured terminal dossier state, account/data state,
DataSpine trust metadata, four terminal actions (`Continuer`, `Créer un
compte`, `Repartir de zéro`, `Sortir`), and the reset/profile Keychain install
guard. Account entry now exposes a persisted anonymous handoff choice:
conserver local data or repartir with a clean local dossier. Missing/stale
choices keep anonymous data separate from the account.

Decisions: this integration phase owns the pre-code contract; fixtures use the
canonical `FinancialArchetype` slugs; Keychain/auth/Apple cannot be closed by
simulator only; anonymous -> account handoff must expose keep vs restart.

Verified locally: 105 focused onboarding/DataSpine tests, 119 secure-storage
reset/profile tests, 82 handoff/auth bootstrap tests, a 100-test auth-screen
slice, a 185-test combined regression slice, `flutter analyze`, route registry,
worktree ARB parity, banned terms, accent lint, public-doc admission lint, and
iPhone 17 Pro simulator screenshots under `evidence/simulator/`, including
account handoff login/register screens. A post-fix simulator pass also verified
that a session-only wedge profile is detected by the register handoff panel even
when debug simulator Keychain seal fails; a provider contract also verifies that
existing-account login does not claim a local dossier without explicit choice.
Provider contracts now also keep failed backend local-data claims retryable via
`local_data_sync_pending_<user>` and clear that flag after auth-restore retry.
Targeted Maestro route-contract proof
for landing -> diagnostic onboarding also passed with screenshots under
`evidence/maestro/account-handoff-route-20260613T2245/` and was rerun after
the retryable-claim fix with visual proof
`evidence/simulator/16-post-retry-intents.jpg`; the structured
Situation diagnostic scene passed under
`evidence/maestro/diagnostic-situation-20260613T2255/` and again under
`evidence/maestro/diagnostic-handoff-session-profile-20260614T012029/` after
the session-profile handoff fix, then after the retryable-claim fix with
`evidence/simulator/17-post-retry-situation-terminal.jpg`.
After commit `197a81bf4`, the auth/reset boundary review findings were fixed
and reverified: no-choice existing-account login no longer exposes anonymous
wizard answers in the connected profile, flag-off legacy login still migrates
anonymous data, logout revokes the backend refresh token before local purge, and
profile reset records pending secure-purge failures. `auth_provider_test.dart`
passes 48 tests, `account_handoff_service_test.dart` + `auth_service_test.dart`
pass 34 tests, `flutter analyze` is clean, `xcodebuildmcp build_run_sim -quiet`
passes on iPhone 17 Pro, and Maestro route/Situation flows pass again with
visual proofs `evidence/simulator/18-post-boundary-intents.jpg` and
`evidence/simulator/19-post-boundary-situation-terminal.jpg`.

Open: no rebase on `origin/dev`; broader persona walker still open; G2
Julien/device still required for Keychain/auth/Apple; staging/TestFlight
intentionally not used in this pass.

Next: run broader walker/persona coverage and device validation for
Keychain/auth/Apple.
