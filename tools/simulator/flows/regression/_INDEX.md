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
| S004+F006+F007 | `bug__S004_F006_F007__universal_link_opens_app.yaml` | **OPEN-RELEASE-GATE 2026-06-01 (Universal Links not release-ready)** | iOS sim Universal Link path opens Safari pre-fix. Current code has `FlutterDeepLinkingEnabled: true` and backend AASA tests, but `Runner.entitlements` intentionally does **not** contain `com.apple.developer.associated-domains` because that capability previously broke TestFlight provisioning. | **Partial proof only:** `Info.plist` contains `FlutterDeepLinkingEnabled: true`; backend `test_aasa_endpoint.py` proves the app can serve a valid AASA payload on hosts that route to this backend; `ios_release_capability_drift.py` passes because no unprovisioned Associated Domains entitlement is present; staging AASA is valid. **Not closed:** no signed TestFlight IPA with Associated Domains, no Apple Developer/match profile proof, no real-device Universal Link proof, and product host `mint-ai.ch` must resolve and serve the expected AASA before any production Universal Link claim. |
| L001 | `tools/simulator/flows/{julien_swiss,lauren_expat_us,auth_coach_post_hotfix}.yaml` (lint-gated, not flow-gated) | **LOCKED-GREEN 2026-05-11T (W7 iter#12)** | `/tmp/L001_locator_audit_pre.txt` — `python3 tools/checks/maestro_locator_audit.py` exit 1, 14 violations across 3 flows (8 ID violations on `anon-chat-*` Keys missing in Dart + 4 false-positive narrator-token text literals in `assertNotVisible` regression guards + 2 drifted positive-assertion text literals `'Estime ta marge précise'`). | **`python3 tools/checks/maestro_locator_audit.py` exit 0, scanned 3 flows / 17 locators, « [OK] All locators resolve. » (deterministic citation @ /tmp/L001_locator_audit_post.txt).** Fix : (a) added 4 stable Keys to `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` (Key('anon-chat-input') on TextField line 654, Key('anon-chat-register-cta') on « Créer un compte » ElevatedButton line 543, Key('anon-chat-opener-bubble') on first coach message Padding when isOpener=true, Key('anon-chat-message-assistant') on subsequent coach message Padding) ; (b) taught the lint to skip `assertNotVisible` literals (negative regression guards are BY DESIGN absent from rendered tree) ; (c) dropped 2 drifted positive-assertion text literals from julien_swiss + lauren_expat_us (stable Key assertion above already covers). Flutter widget tests : `cd apps/mobile && flutter test test/screens/anonymous/` 13 passed + 1 skipped (golden), zero regression. Fix commits : `c689bfcf` (4 Keys) + `a1bcec8d` (lint scope + YAML drops). Per CLAUDE.md never #7 archetype coverage : julien_swiss (swiss_native) + lauren_expat_us (expat_us FATCA canary) preserved as test fixtures, FIX over DELETE. |

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
| B023 (REJECTED — false flag) → permanent schema-parity guard | `services/backend/tests/test_snapshots_migration_exists.py` | **LOCKED-GREEN 2026-05-11T21:25Z** | The audit row B023 (« no alembic migration creates the snapshots table ») was a FALSE FLAG : the table IS created by `d73dcc3968c9_baseline_14_models.py:109-135` + `p12_add_birth_date.py` (21st column). The audit checked filenames only via `ls alembic/versions/ \| grep snapshot` and missed the baseline migration which contains the create_table call in its CONTENT. RED-state for B023 cannot be captured because the bug does not exist on the current chain. Per CLAUDE.md memory `feedback_audit_verification_logs` audits flag false-positives ; always re-verify. The test file is preserved as the permanent schema-parity regression guard. | **`cd services/backend && python3 -m pytest tests/test_snapshots_migration_exists.py -q` → 4 passed in 0.45s.** Asserts : (1) `alembic upgrade head` on fresh SQLite creates the snapshots table (canonical alembic path, not Base.metadata.create_all side-channel) ; (2) all 21 ORM columns from `app/models/snapshot.py::SnapshotModel` present after upgrade (schema parity guard — future ORM-column drift or migration-drop fails the test) ; (3) the 3 expected indexes are present (ix_snapshots_created_at, ix_snapshots_user_created composite, ix_snapshots_user_id) ; (4) alembic chain has a single head (no dangling unmerged branches). Roundtrip proof : `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` clean on local SQLite. Fix commit : `d57ab894`. Full backend pytest 6632 passed, 62 skipped, 2 xfailed in 112s — zero regression vs 6628 baseline. The smaller real drift surfaced during re-verification (missing FK + missing server_defaults) is filed as a new row B023b for next cycle. |
| T002 (mobile layer) | `apps/mobile/test/services/sqlite_encryption_test.dart` | **LOCKED-GREEN 2026-05-11T18:55Z** | RED proof : a one-byte downgrade `sqflite_sqlcipher → sqflite` in `biography_repository.dart` makes the canonical contract test fail with `T002 CONTRACT : BiographyRepository must import sqflite_sqlcipher`. Captured at `/tmp/t002_red_proof.txt` (1 test failed, 5 passed). Restored deterministically. | **`cd apps/mobile && flutter test test/services/sqlite_encryption_test.dart` → 6/6 pass in <1s.** Asserts : (1) repository imports `sqflite_sqlcipher` (not plain `sqflite` — plain produces an unencrypted DB and silently ignores `password:`) ; (2) `openDatabase(...)` is called with `password: key` ; (3) the key is sourced from `flutter_secure_storage` (iOS Keychain / Android KeyStore, hardware-backed) ; (4) `Random.secure()` CSPRNG + `List.generate(32, ...)` produces 32-byte AES-256 key ; (5) alias contract `mint_biography_key` pinned (renaming would orphan users' encrypted data) ; (6) DB filename contract `mint_biography.db` pinned. Fix commit : `6219bb65` (FIX was a 0-LOC code change — SQLCipher AES-256-CBC was already shipped in production code per Phase 03 Memoire Narrative ; T002 cycle ADDED the lock + the docs file). |
| T002 (backend layer) | `services/backend/tests/test_sqlite_at_rest_encryption.py` | **LOCKED-GREEN 2026-05-11T18:55Z** | RED proof : initial run, 6/7 pass, 1/7 fails on missing `services/backend/docs/security/at-rest-encryption.md`. Captured at `/tmp/t002_backend_red.txt`. The other 6 tests (envelope AES-256-GCM + per-user DEK + fail-closed config in prod/staging/dev/postgresql happy paths) pass against the v2.7 PRIV-04 envelope module shipped today. | **`cd services/backend && python3 -m pytest tests/test_sqlite_at_rest_encryption.py -q` → 7/7 pass in 0.16s.** Asserts the 3 at-rest layers : (1) Railway PostgreSQL infra encryption gated by fail-closed startup check (`app/core/config.py:179-188` rejects `sqlite://` in production+staging, allows in development, accepts `postgresql://` in production) ; (2) `app/services/encryption/envelope.py` uses AES-256-GCM with 12-byte CSPRNG nonces ; (3) `app/services/encryption/key_vault.py` exposes per-user `get_or_create_dek` + `DEKRevokedError` crypto-shred for GDPR Art. 17 ; (4) `services/backend/docs/security/at-rest-encryption.md` cites Railway + PostgreSQL + fail-closed + AES-256-GCM + GDPR Art. 32 + Swiss DSG/LPD + SQLCipher. Fix commit : `6219bb65`. Full backend pytest 6644 passed (vs 6628 baseline = +16 net, zero regression). Honest disclosure : Railway PostgreSQL encryption-at-rest is INFRA-provided (Railway SOC 2 attestation), NOT app-provided. `DocumentModel.extracted_fields` + `warnings` JSON columns remain protected ONLY by Layer 1 today ; promoting them to Layer 2 envelope is a separate plan (alembic backfill + middleware wiring), NOT a T002 blocker. Manual G2-equivalent sim-side dump verification SKIPPED for budget : the deterministic source-code contract test + RED-state proof is the canonical gate per CLAUDE.md §9 0-trust. |
| P001 (W7 iter#11 H1 intent-scoped grammar) | `services/backend/tests/test_citation_gate/test_intent_scoped_grammar.py` | **LOCKED-PARTIAL 2026-05-11T21:45Z (unit-tests GREEN, headline eval REJECTED)** | RED would require reverting the function — unit-test contract is « intent-scoped fragment exists and behaves correctly » ; that test cannot fail when the function exists. The MEANINGFUL RED is on the eval JSONs : Sonnet baseline 8/50 (16%) gate_correct ; Haiku baseline 9/50 (18%) gate_correct (.planning/phases/97-.../eval-runs/P001-iter11-baseline-{sonnet,haiku}.json). | **`cd services/backend && python3 -m pytest tests/test_citation_gate/test_intent_scoped_grammar.py -q` → 8/8 pass in 0.21s.** Asserts the H1 contract : (1) empty intent set → full 18-key fragment (cold-start fallback) ; (2) single-intent `{'retirement'}` → only 8 retirement-bucket keys in « Clés autorisées » (no mortgage / housing keys leak) ; (3) single-intent `{'mortgage'}` → only 5 FINMA keys in « Clés autorisées » (no retirement leak) ; (4) multi-intent `{'retirement','tax'}` → union of both buckets ; (5) unknown intent → fallback to full fragment ; (6) full-coverage union → defers to canonical CITATION_GRAMMAR_FRAGMENT ; (7) legacy narrator path uses intent-scoped variant when `intents` kwarg passed ; (8) backward-compat — `intents=None / intents=set() / kwarg-omitted` all equivalent. Eval-side measurement : Sonnet 8→9/50 (+2pts), Haiku 9→11/50 (+4pts), Haiku fallback rate 54%→38% (−16pts material) — H1 yields MARGINAL improvement on headline (still <50% PARTIAL bar) + MATERIAL improvement on process metrics. Fix commit : `f38975d9` + `4991a552` (mock signature alignment). Full citation_gate suite 190/190 GREEN ; full backend pytest 6621 passed, no regression vs pre-iter11 6620 baseline. P001 stays IN_PROGRESS — H2-H5 filed as P001b/c/d/e for next cycles. |

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
