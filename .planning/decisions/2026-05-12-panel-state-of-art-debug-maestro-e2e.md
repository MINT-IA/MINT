---
type: expert-verdict
role: e2e-maestro-architect
status: Decided
decided_at: 2026-05-12
panel_question: state-of-art-e2e-debug-plan-v2.9
---

# Verdict — SF-FinTech E2E Maestro debug plan for MINT v2.9

**TL;DR.** MINT today has ~15 micro-flows (perfect-set + regression) each scoped to one bug or one screen — what we DO NOT have is a single canonical *first-user happy-path* flow that walks `cold launch → bêta modal → landing → anonymous chat (3-turn cap) → register wall → email verif → T&C consent → onboarding → first card populated`. That gap is exactly why « it feels broken » — every PR ships its slice but no test exercises the seams between slices on a clean device. SF-FinTech bar 2026 (Cash App, Robinhood, Cleo class) is: 8-15 journey flows, ≤30 min wall-clock via Maestro Cloud parallelism on a 3-device matrix (iPhone 15 / iPhone SE / Pixel 8), screenshots at every value-moment with `assertVisible` + visual-diff thresholdPercentage 95-98, deterministic seed users via fixture API endpoint, blocking on `dev→staging` merge. **Minimum-viable for v2.9 TestFlight = 5 flows, ~2 days of work, Maestro Cloud trial ($250/device/month) or self-hosted devicecloud.dev fallback.**

## Section 1 — SF-FinTech bar 2026

State-of-art from the search corpus:

- **Volume & shape.** Critical E2E suites kept under ~30 min wall-clock via parallel execution; teams focus on the « most important journey paths » rather than exhaustive coverage ([drizz.dev 2026](https://www.drizz.dev/post/5-best-end-to-end-automated-mobile-app-testing-platforms-for-2026), [bunnyshell.com](https://www.bunnyshell.com/blog/introduction-to-end-to-end-testing-everything-you-/)). Typical FinTech mobile app : 8-15 journey flows, each 90s-180s.
- **Device matrix.** Maestro Cloud + BrowserStack-style farms run 3-5 device permutations minimum (latest iOS flagship, iOS-1-gen, smallest viewport iPhone SE, Android flagship, Android budget Pixel-a). Maestro Cloud pricing $250/device/month gives unlimited runs ([maestro.dev/pricing](https://maestro.dev/pricing), [maestro.dev/cloud](https://maestro.dev/cloud)).
- **Parallelism.** « hundreds of tests in parallel on dedicated infrastructure, cutting execution times by up to 90% » ([maestro.dev/cloud](https://maestro.dev/cloud)). Native cross-platform from a single YAML.
- **Screenshots & visual diff.** Maestro 1.x ships `takeScreenshot` + diff with `thresholdPercentage` (default 95, bump 98-99 for charts/illustrations) ([maestro.dev/blog/visual-testing](https://maestro.dev/blog/visual-testing)). Baselines committed to repo; CI fails on drift.
- **Data seeding.** Fixture API endpoint creates « seeded test user » with known archetype + balance + LPP state. Maestro `runScript`/`evalScript` calls a `POST /test/seed` route that bypasses email-verif and returns a Bearer token, then `setEnv` injects it before flow. NEVER hardcode prod credentials in YAML.
- **Cloud farm choice.** Maestro Cloud is built-for-Maestro and removes infra ops; BrowserStack covers 3000+ devices but Maestro integration is via parallel-test SDK (heavier); Firebase Test Lab is Android-only-strong, weaker iOS; self-hosted devicecloud.dev at $99/device/month sits between. For MINT v2.9 → Maestro Cloud trial is the fastest path.
- **CI gate.** PR opens → Maestro Cloud parallel run → screenshot diff → block merge to `dev`/`staging` on red. Mabl / Cash App pattern: « test the whole end-to-end user journey » before each release branch cut ([mabl.com](https://www.mabl.com/test-end-to-end-user-journeys)).

## Section 2 — Minimum-viable E2E for v2.9

**Ruthless cut: 5 flows. Each ≤ 180s. Total wall-clock with 2-device parallelism: ≤ 18 min.**

1. **`flow_e2e_01_anonymous_first_value.yaml`** — cold launch → bêta modal accept → landing → « Discuter anonymement » → 3-turn chat hitting the 3-turn cap → register-wall appears. ★ **The « it feels broken » regression-killer.**
2. **`flow_e2e_02_register_email_verify_onboard.yaml`** — register form → email verif (via fixture mailbox endpoint) → T&C consent (ConsentService log_only audit-trail) → onboarding 6-screen → home with empty cards.
3. **`flow_e2e_03_returning_user_card_populated.yaml`** — seeded user (julien_swiss archetype, balance + LPP loaded) → cold launch → home shows ConfidenceScoreCard populated → tap card → P004 overlay-populated state visible.
4. **`flow_e2e_04_cap_du_jour_to_chat_via_intent_bar.yaml`** — existing micro `bug__F001_S001_combined` promoted into the canonical suite (the W1-T1 Option-A opener path).
5. **`flow_e2e_05_offline_degraded_network.yaml`** — toggle airplane mode mid-chat → assert « Réessaie » UI, no crash, no « sans risque » banned-term leak in offline copy.

**Deferred to v2.10** (explicit out-of-scope, written down so we don't argue later) : Plaid/Yapeal bank connect, FATCA archetype detection flow, session-end SoA report, biometric auth, push notif consent, deep-link from email.

## Section 3 — Implementation plan

| # | Task | Effort | Deliverable |
|---|---|---|---|
| T1 | Write `flow_e2e_01_anonymous_first_value.yaml` + commit baseline screenshots | M (4h) | `tools/simulator/flows/e2e/flow_e2e_01_*.yaml` + 8 `.png` baselines |
| T2 | Add `POST /test/seed` fixture endpoint to FastAPI (gated by `MINT_ENV=staging` + `X-Test-Token` header) | S (1h) | `services/backend/app/routers/test_fixtures.py` + 4 pytest |
| T3 | Write `flow_e2e_02_register_email_verify_onboard.yaml` + fixture mailbox endpoint `GET /test/mailbox/{email}` | M (4h) | flow + endpoint + 3 baselines |
| T4 | Write `flow_e2e_03_returning_user_card_populated.yaml` (depends T2 seed endpoint) | S (1h) | flow + 5 baselines |
| T5 | Promote `bug__F001_S001_combined` → `flow_e2e_04_*` rename + add visual-diff asserts | XS (15min) | renamed flow |
| T6 | Write `flow_e2e_05_offline_degraded_network.yaml` using `setAirplaneMode` | S (1h) | flow + 3 baselines |
| T7 | Maestro Cloud account + first run on iPhone 15 + Pixel 8 (or self-hosted devicecloud.dev fallback) | S (1h) | API key in Railway, CI secret `MAESTRO_CLOUD_API_KEY` |
| T8 | `.github/workflows/e2e_maestro.yml` triggered on PR to `dev`/`staging` running the 5 flows in parallel | M (4h) | green CI badge on next PR |
| T9 | `.planning/E2E_FLOW_INDEX.md` — wiki index of journey flows, archetypes covered, latest run timestamp | XS (15min) | index file |
| T10 | Visual-diff baseline refresh script `tools/simulator/refresh_e2e_baselines.sh` (only updates with `--approved` flag) | S (1h) | shell script + README |

**Total: ~2 days for one engineer.** Critical path = T2 → T3 → T8.

## Section 4 — First-user happy path (8-12 steps)

The canonical journey for MINT v2.9 — every E2E flow MUST hit some subset of this:

1. **Cold launch** from springboard, no prior state.
2. **Bêta modal** auto-appears → tap « J'ai compris ».
3. **Landing** displays « Anonyme » + « Compte » CTA fork.
4. **Anonymous path** → « Discuter anonymement » → composer.
5. **3-turn chat** — type message 1, receive coach reply ; message 2, reply ; message 3 → **anonymous limit modal fires** (this is the value-revelation moment, not a blocker — it's the proof of value).
6. **Register wall** — modal CTA « Crée ton compte pour continuer » → email + password form.
7. **Email verif** — fixture mailbox or magic-link tap (in test fixture, auto-confirm).
8. **T&C consent capture** — ConsentService log_only audit-trail row written (assertion: `GET /api/v1/consent/me` returns 200 with `tcs_accepted_at`).
9. **Onboarding 6-screen** — archetype select, canton, age band, goals, life event, summary.
10. **Home screen empty state** — ConfidenceScoreCard shows « Définis ton budget » CTA.
11. **First card populated** (seeded path only) — after `POST /test/seed`, home shows real card with confidence score + uncertainty band.
12. **Session-end SoA report** — **deferred to v2.10** (write down explicitly, don't pretend to test it).

## Section 5 — Adversarial spots (top 5)

1. **Offline mid-chat** — airplane mode after composer focus → coach response 30s timeout → must show « Réessaie » + no « garanti / sans risque » leak in fallback copy (LSFin §1). Covered by flow_e2e_05.
2. **Slow network 3G** — Maestro `--network-conditioning slow-3g` (or simctl Network Link Conditioner) → first-render budget 4s before TimeoutException. Add to T8 as separate Cloud config.
3. **Expired anonymous token mid-3-turn-chat** — token expires between turn 2 and 3 → must rotate gracefully, not lose draft message. Adversarial extension of flow_e2e_01.
4. **Cold-start latency > 8s on iPhone SE** — small device + cold cache → bêta modal might race with deep-link handler → flake. Cover by running flow_e2e_01 on iPhone SE in matrix.
5. **Denied notification permission** during onboarding → must NOT block T&C consent capture. Cover in flow_e2e_02 with `denyPermission notifications`.

## Section 6 — Current gap vs SF-FinTech bar (5 specific deltas)

1. **No canonical journey suite.** MINT has 15+ bug-scoped Maestro micro-flows; SF-FinTech apps ship a separate `e2e/journey/` directory with 8-15 multi-screen flows. Today MINT's longest flow is `flow_g2_julien_walkthrough.yaml` which is one archetype, not the cold-launch-to-first-value arc.
2. **No fixture seeding API.** Cash App / Cleo bypass email + bank-connect via test-only `/seed` endpoints gated by env. MINT has nothing — every Maestro run currently creates a fresh user via UI, which adds 90s per flow and is fragile to onboarding copy changes.
3. **No visual-diff baselines committed.** Maestro's `takeScreenshot` is used, but baselines aren't versioned in `tests/baselines/` with diff-on-CI. Drift goes unnoticed until Julien sees it on his sim.
4. **No cloud farm wired.** All MINT Maestro runs are local-sim only. SF bar = Maestro Cloud or BrowserStack on every PR. No parallel execution → no realistic 30-min budget.
5. **No CI gate on dev→staging merge.** Today the only gate is unit-test green + Julien eyeball. SF bar = E2E suite must be green before the staging branch merges. This is the gate that catches « it feels broken » before TestFlight.

## Counter-arguments and data gaps

**Counter #1 — « 5 flows is too few, we'll miss bugs ».** Maybe. But 15 micro-flows missed « it feels broken » this week; coverage breadth ≠ journey continuity. 5 well-chosen journeys catch more class-of-bug than 50 bug-scoped flows. Re-evaluate after v2.9 ship.

**Counter #2 — « Maestro Cloud $250/device/month is expensive for a pre-launch app ».** True. Fallback: self-hosted devicecloud.dev at $99/device or local-sim parallel with `maestro test --parallel`. Cloud is the 1-week trial path; defer commitment to post-TestFlight feedback.

**Counter #3 — « Fixture seed endpoint is a security risk in staging ».** True if not properly gated. Mitigation: endpoint requires `MINT_ENV=staging` + `X-Test-Token` header matching a Railway-side secret rotated weekly + IP-allowlist CI runners. Never deploy to prod (compile-time `assert os.environ["MINT_ENV"] != "production"`).

**Data gap #1.** We don't have actual flake-rate data on current micro-flows (no historical run database). Maestro Cloud's flake-detection feature would surface this — install before T-1 to start collecting.

**Data gap #2.** No measured cold-launch latency on iPhone SE. T1 baseline run will produce first data point.

**Data gap #3.** No public Cash App / Robinhood case study confirms exact flow count (search returned no concrete numbers). The « 8-15 flows » figure is industry-typical from drizz.dev + mabl best-practice, not a citation of a specific FinTech app's published suite. Treat as informed estimate, not gospel.

**Sources:**
- [Maestro Cloud overview](https://maestro.dev/cloud)
- [Maestro pricing 2026](https://maestro.dev/pricing)
- [Top 5 E2E Testing Frameworks 2026](https://maestro.dev/insights/top-5-end-to-end-testing-frameworks-compared)
- [Visual Testing in Maestro](https://maestro.dev/blog/visual-testing)
- [drizz.dev — 5 E2E Mobile Testing Platforms 2026](https://www.drizz.dev/post/5-best-end-to-end-automated-mobile-app-testing-platforms-for-2026)
- [Mabl — Test the whole end-to-end user journey](https://www.mabl.com/test-end-to-end-user-journeys)
- [End-to-End Testing 2026 guide — bunnyshell](https://www.bunnyshell.com/blog/introduction-to-end-to-end-testing-everything-you-/)
- [Maestro Cloud vs BrowserStack vs own devices — DeviceLab](https://devicelab.dev/blog/maestro-browserstack-vs-own-devices)
- [10 Best Device Farms 2026 — getpanto.ai](https://www.getpanto.ai/blog/device-farms-for-mobile-testing)
- [Visual Regression Testing in Mobile QA 2026](https://www.getpanto.ai/blog/visual-regression-testing-in-mobile-qa)
- [Mobile App User Journey 2026 — uxcam](https://uxcam.com/blog/mobile-app-customer-journey/)
