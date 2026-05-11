---
description: Phase 97 W3 regression flow registry — index of all per-bug regression Maestro flows that gate Phase 97+ PRs in CI. Each flow MUST reproduce its bug RED before fix, then exit 0 GREEN after fix. The fix's resolved status in 97-BUGS-REGISTRY.md depends on its row here.
phase: 97
created: 2026-05-11
maintainer: PM Claude — Phase 97 W7 iteration loop
schema_version: 1
---

# Phase 97 Regression Flow Registry

> Bootstrapped during Phase 97 W7 iteration cycle #2 (F001 close). Phase 97
> W3 deliverable formalizes this as the 24-flow regression suite registry
> (3 features × 8 archetypes per D-08). Phase 97 W7's per-bug regression
> flows feed this index incrementally as bugs close.

## Purpose

Per CONTEXT.md D-37, no-regression guarantees come from Maestro flows
LIVING in CI. Each row below is one Maestro flow that :

1. Reproduces a specific bug from `97-BUGS-REGISTRY.md` (RED state captured
   at registration time)
2. Asserts the bug's fix is present (GREEN state required at LOCK)
3. Runs on every PR via `.github/workflows/maestro-regression.yml` (Phase
   97 W3 deliverable — TBD when this index has ≥ 3 flows)
4. Blocks PR merge on any flow failure (PR-blocking gate)

## Active flows

| Bug ID | Flow path | Status | RED-state evidence | GREEN gate |
|--------|-----------|--------|---------------------|------------|
| F001 | `bug__F001__chat_input_bar_exists.yaml` | LOCKED 2026-05-11 | `/tmp/maestro_f001_red.xml` — exit 1, step 3 fails on cold-launch precondition (S001/F012/F013/F014/F028 block end-to-end Maestro until W5) | Flutter widget test — `cd apps/mobile && flutter test test/widgets/mint_chat_overlay_test.dart` (11/11 pass) ; end-to-end proven via `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` (LOCKED-GREEN 2026-05-11T19:35Z after S005 close) |
| S001 | `bug__S001__cap_du_jour_action_bar_reachable.yaml` | LOCKED 2026-05-11 | `/tmp/maestro_s001_pre_fix.xml` — exit 1, step 3 fails on cold-launch precondition (S003/S005/W1 fragments block /home reachability from LandingScreen for anonymous users) | Flutter widget test — `cd apps/mobile && flutter test test/widgets/aujourdhui/cap_du_jour_banner_test.dart` (5/5 pass) ; end-to-end proven via `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` (LOCKED-GREEN 2026-05-11T19:35Z after S005 close) |
| S005 | `bug__S005__landing_anonymous_cta_to_home.yaml` | **LOCKED-GREEN 2026-05-11T19:32Z** | `/tmp/maestro_s005_pre_fix_v2.xml` — failures=1, step 4 fails on « Continuer sans compte » not visible (the canonical S005 bug : no public CTA to /home on LandingScreen for anonymous users) | **Maestro end-to-end : `/tmp/maestro_s005_post_fix.xml` failures=0, time=8.0s — AujourdhuiScreen reached from cold launch via the new « Continuer sans compte » link.** Widget test : `flutter test test/screens/landing_screen_test.dart` 5/5 pass |
| F001+S001+S005 | `bug__F001_S001_combined__chat_via_cap_du_jour.yaml` | **LOCKED-GREEN 2026-05-11T19:35Z** | precondition-blocked before W7 iter#4 — S005 closed today closes the cold-launch precondition. Pre-S005 RED captured in W7 iter#3 (precondition-blocked at step 3 « Aujourd'hui » assertion) | **Maestro end-to-end : `/tmp/maestro_chained_f001_s001_s005.xml` failures=0, time=10.0s — chains cold-launch → LandingScreen Continuer sans compte → /home → CapDuJourBanner « Parle-moi de toi » → MintCardActionBar 3 verbs → tap « Explique-moi » → MintChatOverlay open with « 0 / 3 » counter + ChatInputBar. FIRST end-to-end Maestro reachability proof of MINT's chat-as-verb surface for anonymous users.** Widget tests : 16/16 (11 F001 + 5 S001) |
| S003+F006 | `bug__S003__mintapp_scheme_opens_app.yaml` | **LOCKED-GREEN 2026-05-11T20:10Z** | `/tmp/maestro_s003_pre_fix.xml` — failures=1 time=1.0s « Unknown error » (Maestro openLink failed because `mintapp://` scheme is not registered ; openurl returned NSOSStatusErrorDomain code=-10814 « no application registered to handle this URL scheme ») | **Maestro post-fix : `/tmp/maestro_s003_post_fix.xml` failures=0 time=4.0s — iOS « Open in "MINT"? » system dialog renders (canonical proof the scheme is registered), tap Open dismisses, MINT app foregrounds.** Backend pytest 6/6 GREEN (`test_aasa_endpoint.py` validates AASA route shape). Screenshot : `/tmp/96_s003_mintapp_opens_app.png` |
| S004+F006+F007 | `bug__S004_F006_F007__universal_link_opens_app.yaml` | **LOCKED-CONFIG 2026-05-11T20:10Z (Maestro flow pending Railway deploy)** | iOS sim Universal Link path opens Safari pre-fix (no associated-domains entitlement, no AASA served). Maestro flow expected RED-on-sim until Railway redeploys + TestFlight signed-entitlements build ships. | **CONFIG GREEN proof : (i) `Runner.entitlements` diff visible — `com.apple.developer.associated-domains: applinks:mint.ch + applinks:mint-staging.up.railway.app` ; (ii) `Info.plist` diff visible — `FlutterDeepLinkingEnabled: true` ; (iii) backend pytest `test_aasa_endpoint.py` 6/6 GREEN proves AASA endpoint serves the correct payload + Content-Type post-deploy. SIM/E2E GREEN deferred until Railway redeploy fires the AASA file at https://mint-staging.up.railway.app/.well-known/apple-app-site-association (project_testflight_ship_path: dev→staging merge triggers Railway redeploy). Full prod gate on TestFlight signed build via D-22 7-day soak.** |

## Unit-Test-Locked Bugs

> Bootstrapped 2026-05-11 (W7 iter#5, T001 close). Some bugs live in
> data pipelines that have no visible UI surface — they are pre-upload
> guards, schema validators, encoding utilities, etc. These cannot
> meaningfully be reproduced by a Maestro UI flow ; their regression
> guard is a deterministic Flutter / pytest unit test run by lefthook
> pre-commit + CI `flutter test` / `pytest -q` (the same gates that
> Maestro flows feed). Each row below cites the unit test path that
> any future PR must keep GREEN to merge.

| Bug ID | Unit test path | Status | RED-state evidence | GREEN gate |
|--------|---------------|--------|---------------------|------------|
| T001 | `apps/mobile/test/services/exif_scrub_test.dart` | **LOCKED-GREEN 2026-05-11T20:30Z** | Compilation failed on `package:mint_mobile/services/exif_scrub.dart` (No such file or directory) + « Method not found : scrubExif » on 6 call sites — captured pre-fix at commit `d3172e60` | **`cd apps/mobile && flutter test test/services/exif_scrub_test.dart` → 00:00 +6: All tests passed!** Asserts : DateTime / Make / Model / Software stripped, ifd0 empty post-scrub, pixel checksum preserved within JPEG-roundtrip 5 % tolerance, EXIF-less JPEG passes through, regression-detect fixture confirms tags ARE present pre-scrub. Fix commit : `5f7d1953`. |
| B004 | `services/backend/tests/test_auth_jti_blacklist_silent_fail.py` | **LOCKED-GREEN 2026-05-11T21:00Z** | Pre-fix : `test_b004_blacklist_db_error_fails_closed` FAILS with `AssertionError: Expected 503 fail-closed when blacklist DB raises ; got 200 body='{"authenticated":true,"user_id":"b004-user-id"}'. If this is 200, the B004 bare-except bug is still present (auth-bypass via infra degradation).` Tests 2/3/4 pre-fix already pass (they validate the intended JWT-decode-fallback + happy-path + blacklist-enforcement paths). Captured at HEAD pre-fix (PICK commit `4c047e35`). | **`cd services/backend && python3 -m pytest tests/test_auth_jti_blacklist_silent_fail.py -q` → 4 passed in 0.90s.** Asserts : (1) SQLAlchemyError during `is_jti_blacklisted` → HTTPException 503 « Service de blacklist temporairement indisponible » (fail-CLOSED, not silent-allow) ; (2) garbage JWT → decode_token fallthrough still produces 401 (intended PyJWTError pass-through preserved) ; (3) valid non-revoked token → 200 OK (happy-path regression guard) ; (4) valid revoked token → 401 « Token révoqué » (blacklist enforcement still works). Fix commit : `d50e2d2e`. Full backend pytest 6628 passed, 62 skipped, 2 xfailed in 112s — zero regression. |

## Per-archetype × per-feature regression flows (Phase 97 W3 deliverable)

Below is the target structure for the 24 flow regression matrix per
CONTEXT D-08 (3 features × 8 archetypes). Filled progressively in W3.

### feature : chat_as_verb

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `chat_as_verb__swiss_native.yaml` | TBD W3 |
| expat_eu | `chat_as_verb__expat_eu.yaml` | TBD W3 |
| expat_us | `chat_as_verb__expat_us.yaml` | TBD W3 (FATCA canary) |
| cross_border | `chat_as_verb__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `chat_as_verb__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `chat_as_verb__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `chat_as_verb__returning_swiss.yaml` | TBD W3 |
| near_retirement | `chat_as_verb__near_retirement.yaml` | TBD W3 |

### feature : citation_gate

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `citation_gate__swiss_native.yaml` | TBD W3 |
| expat_eu | `citation_gate__expat_eu.yaml` | TBD W3 |
| expat_us | `citation_gate__expat_us.yaml` | TBD W3 |
| cross_border | `citation_gate__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `citation_gate__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `citation_gate__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `citation_gate__returning_swiss.yaml` | TBD W3 |
| near_retirement | `citation_gate__near_retirement.yaml` | TBD W3 |

### feature : dag_invalidation

| Archetype | Flow path | Status |
|-----------|-----------|--------|
| swiss_native | `dag_invalidation__swiss_native.yaml` | TBD W3 |
| expat_eu | `dag_invalidation__expat_eu.yaml` | TBD W3 |
| expat_us | `dag_invalidation__expat_us.yaml` | TBD W3 |
| cross_border | `dag_invalidation__cross_border.yaml` | TBD W3 |
| indep_with_lpp | `dag_invalidation__indep_with_lpp.yaml` | TBD W3 |
| indep_no_lpp | `dag_invalidation__indep_no_lpp.yaml` | TBD W3 |
| returning_swiss | `dag_invalidation__returning_swiss.yaml` | TBD W3 |
| near_retirement | `dag_invalidation__near_retirement.yaml` | TBD W3 |

## CI integration (Phase 97 W3 + W6)

Future CI workflow `.github/workflows/maestro-regression.yml` will :

1. Trigger on every PR touching `apps/mobile/` OR `services/backend/` OR
   `tools/simulator/flows/` (path filter)
2. For each row in « Active flows » + the 24-flow matrix : run on the
   Mac mini self-hosted runner (per memory `project_remote_control`)
   against Railway staging
3. Aggregate per-archetype JUnit XMLs via
   `tools/simulator/merge_maestro_junit.py` into one combined report
4. Post a PR comment with pass/fail breakdown + visual diff thumbnails
   (Phase 97 W4 visual baselines)
5. Block merge on any flow failure ; merge requires green across the
   full matrix.

## How to register a new flow

1. Author Maestro YAML at `tools/simulator/flows/regression/
   bug__<id>__<feature>__<archetype>.yaml` (per CONTEXT D-07 naming).
2. Capture RED-state JUnit XML BEFORE the fix lands. Cite the artifact
   path in the « RED-state evidence » column above.
3. Implement the fix surgically (Karpathy #3 — every changed line
   traces to the bug).
4. Re-run the flow ; verify GREEN. Cite the GREEN evidence in the row.
5. Add a row to the « Active flows » table above with the bug ID, flow
   path, LOCKED date, RED-state path, GREEN gate.
6. Update `97-BUGS-REGISTRY.md` : bug row goes IN_PROGRESS → RESOLVED
   with `repro_flow:` pointing to this flow.

## Naming convention (locked per CONTEXT D-07)

- Single-bug regression flows : `bug__<id>__<short-slug>.yaml`
  Example : `bug__F001__chat_input_bar_exists.yaml`
- Feature × archetype matrix flows : `<feature>__<archetype>.yaml`
  Example : `chat_as_verb__expat_us.yaml`

Tags inside the flow YAML follow CONTEXT D-07 :
`tags: [feature:<slug>, archetype:<slug>, phase-97, regression]`.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Registry bootstrapped : 2026-05-11 (W7 iter#2 F001 close)*
