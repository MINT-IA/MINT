# TICKET — Batch UI/story testing that finds problems by itself

> **Base branch: `origin/dev`** (verified 2026-07-01: staging = dev minus the 7 newest wiring commits, zero staging-only content; per repo rules work branches from dev). Create `feature/SXX-ui-test-batch` from `origin/dev`.
> **Goal:** an AI-driven batch test loop that proves the wiring and catches UI defects (mis-taps, overflows, broken i18n, dead ends) without a human clicking through. Agent writes tests; **CI clicks, agent reads reports** — never drive a simulator interactively.
> **Verified facts on dev this ticket relies on:** `patrol: ^4.6.1` configured (`pubspec.yaml`, `test_directory: test/patrol`) · Maestro flows exist under `tools/simulator/flows/` (incl. `maestro-perfect-set/`, personas `julien_swiss`, `lauren_expat_us`) · `tools/checks/maestro_locator_audit.py` exists · only ~33 files in `lib/` carry `Semantics(identifier:)` · dead roads still open on dev: `/scan/review` & `/scan/impact` no-recovery traps (app.dart ~1404-1430), `/tools` & `/portfolio` context-dropping redirects (~1727-1736) · islands still unbridged: `BudgetProvider` (~1994), `HouseholdProvider` (~2002), `TimelineProvider` (~2117).

## Why Maestro "clicks next to" fields today (root cause — fix first)

Maestro drives the **platform accessibility tree**; Flutter only exposes what `Semantics` declares. With ~33 files carrying identifiers, Maestro falls back to visible text or coordinates → mis-taps, and obscured password fields receive stray input. No tool works until stable ids exist.

## T-1 — Semantics identifier sweep (prerequisite for EVERYTHING)

- Add `Semantics(identifier: '<snake_case_id>')` to: every `TextField`/`TextFormField` in auth + onboarding + data-block + coach input; every primary CTA on landing/auth/shell tabs; every result value the flows assert (see id table in `MAESTRO_FLOWS.md` M-0b — reuse those exact ids).
- Keep the visible i18n label separate from the identifier (a11y unaffected).
- Gate: extend `tools/checks/maestro_locator_audit.py` to FAIL when an interactive widget in a flow-covered screen lacks an identifier.
- Acceptance: `maestro_locator_audit.py` green; every id in the M-0b table resolves.

## T-2 — Port the proof-flows to Patrol (batch, Flutter-native, no mis-taps)

Patrol taps the widget tree directly — eliminates the accessibility-tree mis-click class entirely.

- Location: `apps/mobile/test/patrol/` (already configured).
- Port from `docs/codex/MAESTRO_FLOWS.md`: happy paths F-1..F-5 (cross-screen data proof: value entered on screen A asserted on screen B) and regressions R-1..R-5 (each still red on dev: scan/review recovery, report investment card destination, restart persistence, portfolio param).
- Use `$(#id)` finders on the T-1 identifiers; personas Julien/Lauren fixtures where profiles are needed.
- Acceptance: `patrol test` runs the suite headless in CI; F-flows green prove the spine; R-flows red list = the exact bug backlog (do NOT force them green by weakening asserts).

## T-3 — Golden tests matrix (the "finished product" net)

- For every wedge + shell + life-event screen: golden render across **fr/en/de/es/it/pt × light/dark × textScale 1.0/1.3** using `flutter_test` goldens (no emulator, runs on every commit).
- Store under `apps/mobile/test/goldens/`; one `matchesGoldenFile` per (screen × variant); seed profile via `CoachProfileSeeds`.
- Acceptance: overflow/clipped text/missing i18n breaks the build with a pixel diff artifact the agent can read.

## T-4 — Autonomous crawler (background, zero test-writing)

- Wire **Firebase Test Lab Robo** on the Android debug build (nightly CI job): Robo explores unattended on a device matrix, reports crashes + unreachable screens + input traps.
- Output parsed into a markdown report the agent reads (`tools/checks/` script), filed as issues.
- Acceptance: nightly job exists; first report triaged.

## Order & guardrails

1. T-1 (nothing works without it) → 2. T-2 → 3. T-3 → 4. T-4.
- Never fix a red R-flow by weakening its assertion — fix the app (invariants I-1..I-10, `WIRING_GRAPH.mmd`).
- All writes stay on the single write path (`CoachProfileProvider`); tests assert THROUGH the ledger, not via `state.extra`.
- i18n: any hardcoded string added for tests is forbidden — identifiers only, labels stay in ARB.
