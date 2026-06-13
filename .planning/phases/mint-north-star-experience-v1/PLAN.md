# Plan

## Strategy

Use a strangler strategy. Define the dream surface model now, then migrate the app through a typed state spine and verified flows instead of rewriting everything in one pass.

## Defaults After GO

- North Star is treated as approved for planning.
- User-facing artifact name: `Premier éclairage`.
- Internal alias: `Lucidity Brief`.
- First wedge: universal pre-account diagnostic, not a specialized domain wedge yet.

## Doctrine Authority

When docs conflict, use this order:

1. `CLAUDE.md` and `AGENTS.md` for workflow and compliance gates.
2. This phase's `NORTH-STAR.md` for product direction and first experience.
3. `SOT.md` for API/data contracts.
4. `docs/MINT_IDENTITY.md`, `docs/VOICE_SYSTEM.md`, `docs/DESIGN_SYSTEM.md` for tone and visual execution.
5. `docs/ROADMAP_V2.md`, `docs/CHAT_CENTRAL_SPEC.md`, and old `visions/` as historical inputs only when they conflict with the dossier/state-spine direction.

## State Spine Contract

Existing model to extend: `apps/mobile/lib/models/data_spine_snapshot.dart`.

Do not create a second spine. Extend `SpineFieldMeta` and its builders so every material field can express:

- `source`, `confidence`, `freshness`, `updatedAt`, `sensitive`;
- storage location: local, secure local, backend, mixed, unknown;
- sync state: local only, sync off, pending, synced, conflict, deleted;
- AI sharing state: never sent, redacted, bucketed, sent to Mint backend, sent to provider;
- delete consequence: clears locally, clears backend, anonymized, retention exception, pending.

New North Star surfaces must read `DataSpineSnapshot` or a projection derived from it. They must not read raw `CoachProfile` unless they are migration shims.

First TDD target:

- tests: `apps/mobile/test/services/data_spine_service_test.dart`, `apps/mobile/test/services/coach_context_packet_service_test.dart`;
- code: `apps/mobile/lib/models/data_spine_snapshot.dart`, `apps/mobile/lib/services/data_spine/data_spine_service.dart`, `apps/mobile/lib/services/data_spine/coach_context_packet_service.dart`;
- command: `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart`.

Second TDD target:

- tests: `apps/mobile/test/providers/auth_provider_test.dart`, `apps/mobile/test/screens/profile/financial_summary_screen_test.dart`;
- code: `apps/mobile/lib/providers/auth_provider.dart`, `apps/mobile/lib/screens/profile/financial_summary_screen.dart`;
- command: `cd apps/mobile && flutter test test/providers/auth_provider_test.dart test/screens/profile/financial_summary_screen_test.dart`.

Third TDD target:

- tests: `apps/mobile/test/screens/onboarding/mvp_wedge_storyboard_test.dart`;
- code: `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`, `apps/mobile/lib/l10n/app_*.arb`, generated `app_localizations*.dart`;
- command: `cd apps/mobile && flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart`;
- scope: terminal `/onb` summary only. Keep `/start` as rollout seam and do not revive the legacy Premier Éclairage route while it remains a chat shim.

## Slices

1. Doctrine reset:
   - make `NORTH-STAR.md` the product authority for first experience;
   - reconcile `MINT_IDENTITY`, `VOICE_SYSTEM`, `DESIGN_SYSTEM`, roadmap, and older visions;
   - mark chat-first docs as superseded or historical.

2. State spine contract:
   - define `DataSpineSnapshot`;
   - define fact metadata: source, freshness, confidence, storage, sync, AI sharing, delete consequence;
   - define account states and migration states before UI work.

3. First-run rail:
   - keep pre-account diagnostic;
   - make `Premier éclairage` the first value artifact;
   - preserve local, save, account, reset, restore, and leave paths.

4. Auth/reset/restore trust layer:
   - finish account handoff as explicit state machine;
   - verify reset clears known local namespaces and secure storage keys;
   - document Keychain/iCloud restore limits without overpromising;
   - keep Apple-primary UI separate from Apple entitlement and backend verification evidence.

5. Surface consolidation:
   - reduce top-level app to Today, Money, Decisions, Dossier, Trust, Coach layer;
   - retire or redirect legacy routes only after replacement journeys are reachable;
   - enforce route flags through tested runtime registry.

6. Evidence gates:
   - goldens for first-run archetypes and account states;
   - widget/provider tests for state transitions;
   - Maestro/device flow for onboarding, reset, restore, auth handoff;
   - `flutter analyze`, Flutter tests, routes check, l10n parity, compliance lints;
   - G2 Julien/device for Keychain/auth claims.

## Rebuild Decision Rule

Proceed incrementally unless one of these becomes true:

- typed state spine cannot be introduced without duplicating all profile ownership;
- auth/reset/restore cannot be made deterministic in the existing shell;
- route topology cannot be reduced while preserving reachable flows;
- calculation ownership cannot be enforced without replacing feature services.

If two or more become true, start a new shell around the same calculators/backend contracts instead of continuing route-level repairs.
