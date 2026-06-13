# Plan

Status: IN_FLIGHT.

Ready-to-code means these files exist and pass checks: `STATE-CONTRACT.md`,
`golden-onboarding-archetypes.json`, `SCORING-GRID.md`, `VERIFICATION.md`, and
this phase summary/report. No product code before tests are derived from them.

Sequence:

1. A audit/stabilisation: classify dirty checkout, keep stack local, no staging
   outside scope.
2. B diagnostic: state banner, captured facts, missing facts, next questions,
   educational scenario if data is sufficient; qualitative only otherwise.
3. C profile purge: profile, conversation, secure storage, anonymous counters,
   and fresh-install-with-persistent-Keychain test.
4. D anonymous restore: restore after kill, `Nouvelle discussion`, clear exit,
   and migration failure without local data loss.
5. E auth-safe/Apple-primary UI: keep email/refusal/CI paths; do not treat
   simulator Apple UI as entitlement proof.
6. G integrated states: explicit account handoff choice, keep or restart; local
   vs sync state visible.
7. F real Apple entitlement if needed: portal capability, signed entitlements,
   and device proof.

Tests to write first: fresh install Keychain purge; owned-key purge preserving
foreign keys; reset then cold start; anonymous kill/restore; account keep;
account restart; migration failure; interrupted redirect; Apple fallback;
existing-account login precedence; connected restore/token refresh; account
closure; Apple first-grant/private-relay/revocation; BYOK/partner/biography
lifecycle; golden scoring against chat-empty baseline.

Exit gates: G1 Maestro/walker evidence; G2 Julien/device for Keychain/auth/Apple
or explicit open risk; G3 CI/dev/local equivalence; G4 targeted regressions;
G5 lints, ARB parity, banned terms, accents, public-doc check.

Non-goals: no global visual rewrite, no UI financial calculation copy, no cloud
erasure promise, no merge/push to `dev`, `staging`, or `main` without GO.
