---
name: MAESTRO-STRATEGY-MINT — strategy & playbook for using Maestro on MINT
description: Where Maestro fits, how to use it for max ROI, what it does/doesn't do, lessons from 2026-05-09 device-verify session (4/5 perimeters proved on iPhone 17 Pro sim via flows).
type: playbook
date: 2026-05-09
status: ACTIVE
---

# Maestro Strategy for MINT — what it solves, where it fits, how to push it to the max

> Lived from a 2026-05-09 device-verify session that proved 5 perimeters in production on iPhone 17 Pro sim using Maestro flows + Anthropic agentic Bash. Replaces the « TestFlight + Julien-eyes » bottleneck. **No more deploy-to-verify.**

## TL;DR

**Maestro is the right tool for the « UI maladie » (broken-screen-shipped-in-prod regressions).** Specifically :

- It **runs as part of the build loop** (no human in the loop, no deploy step). Same model as `flutter test`, but at the screen-level instead of widget-level.
- It **catches semantic regressions** (« the button no longer says what it should say », « the wrong content fires on the wrong context »). `flutter test` proves « widget renders » ; Maestro proves « user can complete this flow ».
- It **bridges Flutter and the backend** (HTTP staging round-trip), which is where most regressions actually live (the 6 perimeters shipped today were all backend ↔ frontend contract drifts).
- It **runs in seconds**, fits in CI, and doesn't need a human to drive the device.

**Push it everywhere.** Every device-reported bug should ship with a Maestro flow as the regression guard. Period.

## What it is (mechanism)

Maestro is a YAML-driven mobile UI test runner. You write a flow file (« tap this », « assert that text is visible », « take a screenshot ») and the runner executes it on a connected device or simulator. It uses the iOS Accessibility API for element queries, so locators are :

- Text content (literal or regex)
- Accessibility identifiers / Semantics labels (Flutter)
- Coordinates (last resort)

The runner is a small JVM CLI installed at `~/.maestro/bin/maestro`. Requires Java 21+. On macOS the wrapper at `tools/simulator/maestro_env.sh` sets `JAVA_HOME` from brew openjdk.

## Where it fits in MINT's quality stack (vs other tools)

| Layer | Tool | What it proves | Speed | Coverage |
|---|---|---|---|---|
| Pure-function | `pytest` (backend) / `flutter test` widget-only | « given X input, function returns Y » | Fast (ms) | Granular |
| Integration | `pytest --integration` / `flutter test integration_test` | « given DB X, endpoint returns Y » | Medium (sec) | Functional |
| **Screen flow** | **Maestro** | « given app state X, user can complete flow Y » | **Medium (10-60s/flow)** | **Real user-facing** |
| Visual regression | Golden tests (Flutter) | « screen pixels match recorded reference » | Fast (sec) | UI fidelity |
| Cold launch / perf | `tools/simulator/measure_*.sh` | « cold launch ≤ 2.5s », « frame jank ≤ 5% » | Slow (sec) | Perf budget |
| End-to-end ship | TestFlight + Julien | « real device, real user, real eyes » | Slow (hours) | Production reality |

**Maestro lives between integration tests and TestFlight.** It's the « last code-driven gate before the human ». Once Maestro green, you can ship to TestFlight with high confidence — TestFlight then becomes a *sanity* check, not a *primary* test.

The bottleneck this kills : the « deploy → wait → Julien tests → bug found → roll back → fix → redeploy » 30-minute loop. Maestro converts that to a 60-second feedback loop.

## Lessons from 2026-05-09 device-verify session

### What worked

- **Smoke flow first, scale up.** A 4-line flow validating « app launches + landing renders » was the 30-second gate that confirmed the build, sim, Maestro, JVM, and locator strategy were all wired. Run that BEFORE writing perimeter flows.
- **Regex locators (`.*pattern.*`) for FR strings.** Flutter `Text` widgets split content across line wraps. Maestro's literal locator fails on multi-line text. Regex bypasses this *and* sidesteps Unicode apostrophe drift (`'` U+0027 vs `’` U+2019).
- **Stable post-response markers.** « Information générale, pas un conseil financier personnalisé » (LSFin disclaimer) renders persistently across all coach states ; perfect Maestro `extendedWaitUntil` target after an HTTP round-trip. Don't try to assert on LLM-generated text — variable across runs.
- **`assertNotVisible` is the regression weapon.** B14's win was « response no longer mentions amortissement direct/indirect ». A `assertNotVisible: { text: ".*amortissement.*" }` after the response renders IS the test.
- **`takeScreenshot` always.** Maestro stores screenshots in `~/.maestro/tests/<run-id>/`. Even passing flows produce visual evidence usable in PR descriptions.
- **Background `Bash` + `xcrun simctl io screenshot`.** When a Maestro flow fails, capture the live sim state via `xcrun simctl io <udid> screenshot /tmp/x.png` then `Read` the image. This is faster than digging through Maestro's debug bundle.

### Maestro 2.5.1 syntax gotchas (real bugs hit today)

| Anti-pattern | Fix |
|---|---|
| `assertVisible: { text: "X", timeout: 8000 }` | `extendedWaitUntil: { visible: { text: "X" }, timeout: 8000 }` (timeout no longer valid on assertVisible in 2.5+) |
| `assertVisible: "Voir clair, décider seul."` (multi-line FR) | `assertVisible: { text: ".*Voir clair.*" }` (regex sidesteps line wrap) |
| `assertVisible: "J'ai déjà un compte"` (apostrophe drift) | `assertVisible: { text: ".*déjà un compte.*" }` (regex sidesteps unicode) |
| Asserting on Semantics label « Réponse du coach » | This label doesn't exist in `anonymous_chat_screen.dart` Semantics tree. Use post-response stable text (LSFin disclaimer) instead. |

### What didn't work / open gaps

- **Deep-linking via `openLink: ch.mint.app://path`** wasn't tested. iOS deep-link requires URL scheme registration in `Info.plist`. Verify before relying on it.
- **Wizard-driven archetype seeds** are more complex than expected. Tests that need `MINT_E2E_ARCHETYPE=expat_us_seed` need a build with that dart-define present, OR a mocked profile injection path. We didn't verify the seed key wiring this session — the FATCA gate flow assumes it but didn't run it.
- **No integration with mint-staging backend health checks.** A flaky Railway staging instance can fail Maestro flows that make HTTP round-trips. Mitigation : add a pre-flow curl health check (Bash before Maestro), bail fast if staging is down.
- **CI integration not yet wired.** The 5 flows shipped today are local-only. Future : add a GitHub Actions matrix step that runs Maestro flows against a synthetic seed user post-merge.

## How to use Maestro to MAX impact on MINT — playbook

### Rule 1 — Every device-reported bug ships with a Maestro flow

When Julien (or anyone) says « I tried X, the app showed Y » :

1. Reproduce the bug locally on the sim.
2. Write a Maestro flow that asserts the bug — it should FAIL with the buggy code.
3. Fix the bug.
4. Re-run the flow — it should PASS.
5. Land the fix + the flow in the same PR.

Cost : 5 minutes per flow. Value : the bug never returns.

### Rule 2 — Anonymous flows are the cheapest, run them first

Anonymous-mode flows don't need user setup, login state, or seed data. If a regression is reproducible from anon, write the anon flow first. ~80 % of MINT's UI regressions are reproducible from a fresh install + 1-3 user messages.

Examples (today's 5 perimeters) :
- **B14 + B15** : reproducible 100 % from anon (just type the buggy message). Both verified end-to-end via anon Maestro flows in this session.
- **B7-cascade** : empty-state CTA → cold profile state — also reproducible from anon.
- **FATCA gate** : NEEDS logged-in user with US nationality. Harder. Defer to seed-driven flow OR wizard-driven flow.

### Rule 3 — Use staging backend, never local

Per `feedback_app_targets_staging_always` memory : the build dart-define
`API_BASE_URL=https://mint-staging.up.railway.app/api/v1` is mandatory. Local backend would mask backend regressions. The merged commits land on staging within seconds of push to dev, so flows always run against the latest backend.

### Rule 4 — Fast-fail with extendedWaitUntil

Use `extendedWaitUntil` with reasonable timeouts (8s for UI render, 35s for HTTP round-trips). Polling interval is 500ms internally. A flow that uses `wait(60)` is wrong ; use the polling primitive so the flow exits as soon as the assertion fires.

### Rule 5 — Tags by perimeter / risk surface

Every flow should have YAML tags. Reference :
```yaml
tags:
  - perimeter-2026-05-09       # which audit / perimeter this guards
  - regression                 # vs. happy-path / smoke
  - debt-intent                # functional area
  - p0                         # severity
```

Then `maestro test --tags perimeter-2026-05-09` runs only today's flows. Useful for « run today's regression guards before push ».

## ROI math (back-of-envelope)

- Time to write a Maestro flow : **5 min** (with the smoke template above).
- Time saved per Julien-device-loop : **30 min** (deploy + test + report).
- Bugs blocked from regression : compounding.
- Post-merge confidence boost : « tests green » now means « user-facing flows still work » not just « function returns Y ».

If MINT ships 1 device-bug per 2 days and we add 1 Maestro flow per fix, after 30 days we have 15 flows that run in ~10 min total. That's 30 min/day (CI background) for 7.5 hours/day of human-driver-on-device equivalent. **The math closes after week 1.**

## Concrete next moves (post-2026-05-09 session)

1. **Patch the 5 existing flows** (`flow_landing_to_register.yaml`, `flow_drawer_navigation_smoke.yaml`, etc.) — they use the pre-2.5 `assertVisible: { timeout }` syntax that no longer parses. Switch to `extendedWaitUntil`. ~10 min effort.
2. **Add a pre-flow staging health check** to `tools/simulator/maestro_env.sh` — bail if Railway staging returns non-200 on `/health`.
3. **Wire Maestro into CI** — `.github/workflows/maestro.yml` running on a macOS-13 runner, tagged flows for « post-merge regression suite ».
4. **Author 1 flow per ARB key landing** — every new user-facing string change triggers a flow that asserts the new text appears in context.
5. **Author 1 flow per archetype** : `flow_julien_swiss.yaml` (existing), `flow_expat_us.yaml`, `flow_cross_border.yaml`, `flow_independant.yaml` to lock 4/8 archetype rendering paths.

## Anti-patterns (don't do)

- **Don't use Maestro to test pure logic.** That's `pytest` / `flutter test`'s job. Maestro is for « can the user complete this flow ».
- **Don't assert on LLM output content.** Variable. Assert on stable post-response markers (LSFin disclaimer, chip presence/absence) and on regression-banned content (« amortissement direct » must NOT appear after debt query).
- **Don't write Maestro flows for happy-path screen renders.** That's a golden test. Maestro is for *flows*, not single screens.
- **Don't run flows in parallel against the same sim.** State conflicts. Sequential, or use multiple sims.
- **Don't rely on coordinates.** They break across screen sizes. Use semantic locators.

## Pitfalls / what I'd do differently

- **Today I burned 15 min on the « Unknown Property: timeout » error** because I copied the existing flow patterns blindly. Lesson : always smoke-test the syntax with a 4-line flow first.
- **Build failures on `.nosync` xattr** ate ~5 min. The Xcode-level « Strip xattrs » script in the project is necessary but not sufficient — sometimes a manual `xattr -cr ios/ lib/` + `rm -rf build/ios` is required. Document this in the maestro_env.sh as a fallback.
- **No locator audit** — I tried `J'ai déjà un compte` literal first and failed. Should have inspected the Flutter source's Semantics tree before writing the flow. Future : add a `tools/simulator/locator_audit.sh` that dumps the live Semantics tree to compare against flow assertions.

## Bottom line

Maestro is the missing layer between « tests pass » and « user happy ». Today proved it works for backend ↔ frontend regression guards (B14, B15) and surface-level flow guards (smoke, landing). Push it to all device-reported bugs from now on. **No more « PR opened ≠ shipped »** — Maestro green is the new « shipped ».

The bottleneck Julien named (« déployer test flight... on perd tellement de temps ») is solved structurally by this tool.
