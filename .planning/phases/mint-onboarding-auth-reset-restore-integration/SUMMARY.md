# Summary

Status: IN_FLIGHT.

Done: context restored; Claude/GSD config verified; stack SHAs checked; clean
worktree selected; state contract, golden fixtures, scoring grid, verification
doc, and report created before product code; ClaudeCLI REVISE incorporated.
Product slice now adds a structured terminal dossier state, account/data state,
DataSpine trust metadata, four terminal actions (`Continuer`, `Créer un
compte`, `Repartir de zéro`, `Sortir`), and the reset/profile Keychain install
guard.

Decisions: this integration phase owns the pre-code contract; fixtures use the
canonical `FinancialArchetype` slugs; Keychain/auth/Apple cannot be closed by
simulator only; anonymous -> account handoff must expose keep vs restart.

Verified locally: 97 focused onboarding/DataSpine tests, 115 secure-storage
reset/profile tests, a 181-test combined regression slice, `flutter analyze`,
route registry, worktree ARB parity, banned terms, accent lint, public-doc
admission lint, and iPhone 17 Pro simulator screenshots under
`evidence/simulator/`.

Open: no rebase on `origin/dev`; G1 Maestro/walker still open; G2 Julien/device
still required for Keychain/auth/Apple; staging/TestFlight intentionally not
used in this pass.

Next: continue anonymous account keep/restart flows, then run Maestro/walker
and device validation for Keychain/auth/Apple.
