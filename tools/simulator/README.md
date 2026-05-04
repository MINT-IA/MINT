# tools/simulator — MINT iOS Simulator Drivers

## What this directory is

Shell + Python primitives that drive the iPhone simulator (`xcrun simctl`)
for Phase 31 (Instrumenter) observability gates and Phase 35 (Boucle Daily)
dogfood loop. The entry point is `walker.sh`, a J0 driver that boots an
iPhone 17 Pro simulator, installs the staging MINT build, launches it,
captures a screenshot, and optionally injects a known error + pulls the
resulting Sentry event for round-trip assertion. Helper scripts
(`assert_event_round_trip.py`, `trace_round_trip_test.sh`,
`sentry_quota_smoke.sh`) are invoked by walker or by CI gates.

Philosophy: one script, one side effect, always `timeout`-wrapped.
Per the façade-sans-câblage doctrine (`feedback_facade_sans_cablage.md`),
these scripts MUST actually run end-to-end — they are not documentation.

## macOS Tahoe caveats

> Source: `feedback_ios_build_macos_tahoe.md` (read before any device build).

- **NEVER flutter clean.** Tahoe's CocoaPods/Xcode pipeline regenerates
  `Podfile.lock` in ways that break simulator slices silently. Clean builds
  waste 10+ minutes and often fail the first rebuild.
- **NEVER `rm apps/mobile/ios/Podfile.lock`.** Same reason — the lock file
  pins simulator-compatible native pods. Regenerating it on Apple Silicon +
  Tahoe picks arm64-only slices that break the simulator.
- **Wrap every `simctl` call in `timeout 30s`.** On Tahoe the simctl IPC
  can deadlock indefinitely waiting for `CoreSimulatorService`. A 30s cap
  lets the caller fail fast and retry instead of hanging the terminal.
- **Restart `idb_companion` if socket reset.** Error signature:
  `socket hang up` or `idb: error: Connection closed`. Remedy:
  `pkill -f idb_companion; idb_companion --daemon &` — then rerun walker.sh.
- **Simulator device boot is idempotent** but `simctl erase` is destructive.
  The driver uses `erase` between runs so stale state doesn't leak across
  dogfood sessions; do not rely on persisted app data across walker
  invocations.

## Required env

- **`SENTRY_AUTH_TOKEN`** — Sentry API token with minimal scopes
  `org:read project:read event:read` (NO write/admin). Created via Sentry
  UI → User Settings → Auth Tokens. Stored locally in macOS Keychain:
  ```sh
  security add-generic-password -a "$USER" -s "SENTRY_AUTH_TOKEN" -w "<token>"
  # Read back later:
  security find-generic-password -s SENTRY_AUTH_TOKEN -w
  ```
  Also mirror to GitHub repo secrets for CI consumers (Phase 34+).

- **`SENTRY_DSN_STAGING`** — Sentry DSN for the staging environment.
  Fetched from Railway dashboard → `mint-staging` → Variables. Public-by-
  design (embedded into client builds via `--dart-define`). Never
  committed to git.

- **`API_BASE_URL`** — hardcoded by walker.sh to
  `https://mint-staging.up.railway.app/api/v1` per
  `feedback_app_targets_staging_always.md` — device and simulator builds
  MUST always target staging, production is stale. This is non-negotiable
  in every simctl or physical-device task.

## Quick usage

```sh
# Boot sim, install staging, screenshot launch — smoke check the pipeline works
bash tools/simulator/walker.sh --quick-screenshot

# Same + inject known error, wait, pull Sentry event, assert round-trip
bash tools/simulator/walker.sh --smoke-test-inject-error

# Phase 31 gate mini-suite (smoke + OBS-02/04/05 assertions when Wave 1 lands)
bash tools/simulator/walker.sh --gate-phase-31

# OBS-04 (b) round-trip integration — curl staging with sentry-trace header
bash tools/simulator/trace_round_trip_test.sh

# OBS-07 (b) quota usage smoke via sentry-cli api stats_v2
bash tools/simulator/sentry_quota_smoke.sh
```

Output artefacts land in `.planning/walker/<timestamp>/` — screenshots,
`sentry-events.json`, logs. This directory is gitignored; promote
interesting runs to `.planning/research/` if they produce audit evidence.

## Known-bad combos (living list)

Append a row whenever a macOS / Xcode / simulator combo breaks walker.sh
so future Julien / agents don't repeat the debug. Keep this table honest.

| macOS | Xcode | Simulator iOS | Symptom | Workaround |
|-------|-------|---------------|---------|------------|
| _(empty at Wave 0 — fill as we hit issues)_ | | | | |
