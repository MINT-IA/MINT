---
date: 2026-05-13
status: Open
authors: Claude (Opus 4.7) post sweep ↔ classifier loop closure (commit b9c6085f)
description: Large sweep (16 curated flows) post-patch. 6 ✅ / 10 ❌ / 0 stalled. 8 real cassures + 2 YAML parse errors. Single dominant cassure cascades on 5 flows.
related:
  - .planning/_walker/sweep-2026-05-13-FINDINGS.md  (sweep #1, hand-curated)
  - .planning/_walker/sweep-20260513T232519/sweep-summary.md  (machine output)
  - tools/simulator/maestro_sweep.sh
  - tools/debug/cassure-classifier.sh
---

# Sweep #2 (large, post-loop-closure) — 16 flows ground truth

## TL;DR

Post-`b9c6085f` the sweep ↔ classifier loop is closed : every red flow now ships a `cassure-report.json` with a deterministic `primary_hypothesis`. First large sweep across the 16 curated flows produced :

- **6 ✅ green** (37.5 %) — landing→home, cold launch fragment, overlay populated, chat via cap-du-jour, mintapp:// scheme, concrete-facts chips
- **8 ❌ red** with `primary_hypothesis = maestro_assertion_failed` (real cassures)
- **2 ❌ red** with `hypothesis = —` (Maestro YAML parse errors on the persona flows ; not real cassures)

**The single highest-leverage cassure :** 5 of 8 real failures cascade from one unfixed transition, « Je comprends, on y va » → « Aujourd'hui ». Fix that = 5 flows likely turn green in the next sweep. That's the P0.

## Sweep dir

`.planning/_walker/sweep-20260513T232519/`

Each red flow's directory contains : `EXIT_CODE`, `maestro.log`, `cassure-report.json`, `last-screen.png`, `oslog-mint.txt`, `maestro-trace/`. The classifier output drives this triage.

## Cassures grouped by root pattern

### P0 — « Je comprends, on y va » → « Aujourd'hui » transition broken (5 flows)

The classifier's `evidence` field for these flows :

| Flow | PRECEDING | FAILED |
|---|---|---|
| `bug__F001__chat_input_bar_exists` | `Run flow when "Je comprends, on y va" is visible... COMPLETED` | `Assert that "Aujourd'hui" is visible... FAILED` |
| `bug__S001__cap_du_jour_action_bar_reachable` | `Run flow when "Je comprends, on y va" is visible... COMPLETED` | `Assert that "Aujourd'hui" is visible... FAILED` |
| `bug__S004_F006_F007__universal_link_opens_app` | `Wait for animation to end... COMPLETED` | `Assert that ".*Aujourd'hui.*" is visible... FAILED` |
| `flow_drawer_navigation_smoke` | `Warning: Element not found: Text matching regex: Je comprends, on y va` | `Assert that "Explorer" is visible... FAILED` |
| `flow_empty_state_cascade` | `Warning: Element not found: Text matching regex: Je comprends, on y va` | `Assert that "Explorer" is visible... FAILED` |

**Hypothesis :** the bêta-modal dismissal button « Je comprends, on y va » either :
1. doesn't navigate to the « Aujourd'hui » home screen anymore (real nav regression), or
2. the « Aujourd'hui » string was renamed (label drift, breaks 5 assertions silently), or
3. the bêta modal itself isn't shown to the test user anymore (« Element not found » in the 2 drawer/empty-state flows hints at this — they couldn't even find the modal to dismiss).

**Suspect files (need to read) :**
- The bêta modal widget : `apps/mobile/lib/widgets/beta/` or `apps/mobile/lib/screens/landing/beta_modal.dart` (path-guess)
- The home screen widget that owns « Aujourd'hui » : likely `apps/mobile/lib/screens/today/today_screen.dart` or `apps/mobile/lib/screens/home/home_screen.dart`
- The router : `apps/mobile/lib/router/`

**Critical workflow impact :**
- B (anonymous chat + bridge) — chat_input_bar_exists assumes home screen reached
- C (coach authenticated post-login) — cap_du_jour_action_bar + drawer_nav both downstream of home
- A (onboarding) — universal_link entrypoint expects « Aujourd'hui »
- D (parcours-vie SequenceCoordinator) — empty_state_cascade is the parcours-vie surface

### P1 — Maestro 2.5.1 rejects `timeout:` flow property (2 personas, mechanical fix)

Both `julien_swiss.yaml` and `lauren_expat_us.yaml` fail at parse time :

```
> Unknown Property: timeout
/Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/flows/julien_swiss.yaml:-1
```

**Root cause :** Maestro 2.5.1 dropped the top-level `timeout:` property. Either remove the line or migrate to per-step `timeout:` if needed.

**Critical workflow impact :** these are the persona walkthroughs (Julien Swiss native, Lauren expat-US). They cover **all 5 critical workflows** in single end-to-end scripts. Fixing the parse error unblocks the highest-coverage tests in the suite. Trivial 5-min fix.

### P2 — F1 e2e ship-gate cassure (already documented in sweep #1)

`flow_e2e_new_user_full_journey` :
- PRECEDING : `Tap on "Créer un compte"... COMPLETED`
- FAILED : `Assert that "Pas encore de compte ?" is visible... FAILED`

Same as sweep #1's F1. The flow taps « Créer un compte » then asserts « Pas encore de compte ? » should be visible — but that text only appears on the LOGIN screen, not the register screen the user just navigated to. Two possibilities (per sweep #1 doc) :
1. flow YAML asserts wrong text (assertion-text drift) — fix the YAML
2. tap on « Créer un compte » fails to navigate (real nav bug) — read `last-screen.png`

**Critical workflow impact :** A (onboarding new user). This is THE ship-gate flow.

### P3 — Cold-launch landing copy drift

`flow_landing_to_register` :
- PRECEDING : `Launch app "ch.mint.app"... COMPLETED`
- FAILED : `Assert that "Voir clair, décider seul." is visible... FAILED`

After cold launch, the assertion expects the landing hero copy « Voir clair, décider seul. » — but it's not visible. Either :
- The hero copy was changed (string drift)
- The app boots into a different state (already-logged-in user → home, not landing)
- The landing screen restructure means the copy is rendered differently (e.g. inside a child widget the assertion can't see)

**Critical workflow impact :** A (onboarding). Cold-launch is the entry point.

### P4 — flow_3a_calculator entrypoint missing

`flow_3a_calculator` :
- PRECEDING : ` > Flow flow_3a_calculator` (just the flow header — failed at the very first step)
- FAILED : `Assert that "Ton 3e pilier" is visible... FAILED`

The 3a calculator screen header « Ton 3e pilier » is not visible at flow start. Either :
- The flow assumes prior navigation that wasn't performed
- The screen header was renamed
- The user route into the calculator is broken upstream

**Critical workflow impact :** E (variables library / profile data — 3e pilier capture is part of the financial profile).

## Recommended attack order (decisive)

1. **P0** — investigate « Je comprends, on y va » → « Aujourd'hui » cascade FIRST. Read `last-screen.png` from one of the 5 affected flows + read the bêta modal + home screen widgets. If it's a label rename, fix once, re-run sweep, expect 5 flows to flip green. If it's a real nav regression, fix the router/handler.
2. **P1** — strip `timeout:` from `julien_swiss.yaml` + `lauren_expat_us.yaml`. 5-min mechanical PR. Re-run, get persona signal back.
3. **P2** — F1 e2e : read `last-screen.png` from sweep-20260513T232519/flow_e2e_new_user_full_journey/last-screen.png to disambiguate « tap was no-op » vs « assertion text wrong ». Fix accordingly.
4. **P3** — landing hero copy drift. Read landing screen widget. Either fix the assertion or reinstate the copy.
5. **P4** — 3a calculator entrypoint. Lower leverage ; investigate after P0-P3.

## Ground-truth caveats (per CLAUDE.md §9 0-trust)

- The 6 ✅ green flows passed against **the build currently on the sim**. I have NOT re-built or re-installed the app since sweep start. If the build is stale, green ≠ green-on-latest-code.
- The 8 ❌ red flows **WILL fail again on identical re-run** unless the underlying app changes (or the test YAMLs are fixed). They're deterministic given current build + current flow specs.
- The 2 personas (P1) failed at YAML parse, NOT app behavior. Their app-coverage signal is currently zero.
- I have NOT verified that the sim build points to `mint-staging.up.railway.app` (memory `feedback_app_targets_staging_always.md`). If it points to local or to dev (not staging), some flows may fail because the wrong backend version is responding.

## What this sweep does NOT cover yet

The curated `--tier all` skips 9 perfect-set flows that ARE on disk :
- `flow_card_action_intent_bar.yaml`
- `flow_extractor_captures_age_canton.yaml` (workflow E — variables library)
- `flow_lpp_scan_review.yaml` (workflow E — LPP PDF capture)
- `flow_b14_debt_intent_no_mortgage.yaml`
- `flow_narrator_refuses_uncited_numbers.yaml` (LSFin compliance)
- `flow_fatca_3a_gate.yaml` (archetype — Lauren-expat-US-style)
- `flow_g2_julien_walkthrough.yaml` (G2 Julien gate)
- `_fragment_cold_launch_to_aujourdhui.yaml` (fragment, not standalone)
- `auth_coach_post_hotfix.yaml` (post-hotfix regression)

After P0 is fixed and the sweep cascade clears, expanding `FLOWS_PERFECT` to include `flow_extractor_captures_age_canton` + `flow_lpp_scan_review` + `flow_g2_julien_walkthrough` + `flow_narrator_refuses_uncited_numbers` would give us coverage of workflow E (variables library) + workflow C (coach LSFin guardrails) + persona G2.
