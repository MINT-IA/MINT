# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Système Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- ✅ **v2.8 L'Oracle & La Boucle** — Phases 30.5-32 + 13 decimals (shipped 2026-04-25, gaps_found)
- ⚠️ **v2.9 Coach Visuel Hybride** — Phases 40-43 (deferred post-v2.11 ship)
- ✅ **v2.10 Outillage + Panel verdicts** — PRs #483-#489 (shipped 2026-05-04, phantom contracts révélés par 5 audits)
- 🚧 **v2.11 Walker-Validated E2E + Eclairage Wiring** — **Phases 80-85 (active milestone — this document)**

<details>
<summary>Previous milestones (v1.0 → v2.10) — full archive in MILESTONES.md + git history</summary>

v2.8 shipped 5/9 phases + 13 decimal patches (30.5 Context Sanity Core · 30.6 Advanced · 30.7 Tools Déterministes · 31 Instrumenter · 32 Cartographier). Phases 33-36 deferred. v2.9 « Coach Visuel Hybride » Phases 40-43 (vignettes/scènes/canvas) deferred post-v2.11 TestFlight ship. v2.10 livré tooling + design panels mais 5 audits 2026-05-05 ont révélé 5 phantom contracts (eclairage payload jamais consommé Flutter, MINT_E2E_FORCE_ECLAIRAGE_KIND dead code, walker coords mauvais référentiel, beta modal blocant, hero bboxes mauvaise résolution iPhone 17 Pro, cross-language drift DE→FR). v2.11 wire mécaniquement les 5 contrats.

</details>

---

## v2.11 Walker-Validated E2E + Eclairage Wiring — Active Milestone

### Milestone Goal

Boucler la boucle ouverte par v2.10. Câbler le « Premier Éclairage » de bout en bout (backend payload → Flutter parser → écran render → walker validation), fixer les écarts structurels révélés par les 5 audits du 2026-05-05.

### Critère de Done (mécanique, non négociable)

`bash walker_premier_eclairage.sh --archetype X --no-dry-run` exit 0 sur les **4 archetypes** (`julien_swiss`, `couple_acheteurs_lausanne`, `jeune_diplome_zurich`, `cadre_40_55_lpp_rachat`) AVEC :

- Card éclairage rendue (kind = `forcedEclairageKind` quand pin actif, sinon LLM-natural)
- Register CTA exposé (scroll-to confirmé par bbox SSIM ≥ 0.96)
- Visual diff par bbox ≤ 4 % vs goldens calibrés iPhone 17 Pro 1206×2622
- TestFlight build `2.11.0+1` dispo dans App Store Connect, run-id evidence attaché à la description

### Phases (sequential, 80 → 85, no parallelization)

- [ ] **Phase 80: Eclairage E2E wiring (Flutter)** — Brancher `forcedEclairageKind` + `CoachProfileSeeds` + `PremierEclairageSelector` dans le path render anonymous chat.
- [ ] **Phase 81: Backend eclairage contract** — `AnonymousChatRequest.archetype` + `AnonymousChatResponse.eclairage` + deterministic emitter pin par env var.
- [ ] **Phase 82: Walker coord-system overhaul** — osascript sim-window runtime + `hero_bboxes.json` recalibré 1206×2622 + ≥2 stable hashes + beta-disclosure dismiss step.
- [ ] **Phase 83: Sim hygiene + state isolation** — `simctl erase` per archetype + `MINT_DISABLE_BETA_MODAL` dart-define + `.gitignore` walker outputs.
- [ ] **Phase 84: Cross-language drift fix** — `build_discovery_system_prompt(language)` honoré + ARB key parity CI gate.
- [ ] **Phase 85: Walker green 4 archetypes + TestFlight 2.11.0 cut** — Final run + golden bake + IPA upload + run-id evidence.

### Phase Summary Table

| #  | Phase                                                  | Goal (1 line)                                                                                                       | Requirements (count)        | Estimated effort |
|----|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|-----------------------------|------------------|
| 80 | Eclairage E2E wiring (Flutter)                         | Wire `forcedEclairageKind`, `CoachProfileSeeds.activeSeed`, `PremierEclairageSelector` into the anonymous render path | ECLW-01..05 (5)             | 1.5 d            |
| 81 | Backend eclairage contract                             | Extend Pydantic request+response, deterministic emitter, env-var pin honored, LSFin compliance                      | ECLB-01..05 (5)             | 2.0 d            |
| 82 | Walker coord-system overhaul                           | Runtime sim-window anchors, recalibrate bboxes 1206×2622, ≥2 stable hashes, beta-disclosure dismiss, scroll gesture | WALKC-01..06 (6)            | 2.0 d            |
| 83 | Sim hygiene + state isolation                          | Per-archetype `simctl erase`, `MINT_DISABLE_BETA_MODAL`, defensive uninstall, gitignore walker outputs              | SIMH-01..05 (5)             | 1.0 d            |
| 84 | Cross-language drift fix                               | `build_discovery_system_prompt` reads `language`, ARB key parity CI gate active                                      | LANG-01..03 (3)             | 1.5 d            |
| 85 | Walker green 4 archetypes + TestFlight 2.11.0 cut      | Final run on 4 archetypes, golden bake, version bump 2.11.0+1, IPA upload, evidence attached                         | WALKR-01..06 (6)            | 2.0 d            |
|    | **Total**                                              |                                                                                                                     | **30 / 30**                 | **~10 d**        |

### Critical Path

```
Phase 80 (Flutter wiring spec)
   ↓ defines consumer contract
Phase 81 (backend matches Flutter contract)
   ↓ both sides wired
Phase 82 (walker calibrates against the wired stack)
   ↓ walker tests are now meaningful
Phase 83 (sim hygiene removes false-positives)
   ↓ runs are reproducible
Phase 84 (i18n drift fixed before final run)
   ↓ FR-only invariant verified
Phase 85 (LAST GATE: walker green ×4 + TestFlight 2.11.0 cut)
```

**No parallelization.** Each phase merges to `dev` before next opens. This avoids the v2.10 phantom-contract trap (Phase 71b PR #486 assumed Phase 71a contract that wasn't shipped on `dev`).

---

## Phase Details

### Phase 80: Eclairage E2E wiring (Flutter)
**Goal**: Wire the three Flutter primitives that the 5-audit C/C1 flagged as declared-but-never-called — `forcedEclairageKind` getter, `CoachProfileSeeds.activeSeed`, `PremierEclairageSelector.select()` — into the actual render path of the anonymous chat screen, gated by `kReleaseMode`.
**Depends on**: Nothing (first phase). Spec phase: defines the consumer contract that Phase 81 backend must match.
**Requirements**: ECLW-01, ECLW-02, ECLW-03, ECLW-04, ECLW-05
**Success Criteria** (what must be TRUE):
  1. Running `flutter test test/widgets/eclairage_force_kind_test.dart` (new) PASSES with `--dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a` and the rendered widget tree contains `EclairageCardData(kind: fiscal_margin_3a)`, NOT the LLM-natural kind.
  2. `grep -rn 'forcedEclairageKind' apps/mobile/lib/` returns at least 1 callsite outside `coach_orchestrator.dart` (the audit-C dead-code condition is broken: getter is now READ).
  3. With `MINT_E2E_ARCHETYPE=julien_swiss` set at build time, `CoachContext.profileSeed` resolves to the v2.10 `julien_swiss` seed (asserted by `coach_context_seed_test.dart`).
  4. `PremierEclairageSelector.select()` is invoked at least once when an `EclairagePayload` is parsed from the response (asserted by orchestrator integration test).
  5. Release build with `flutter build ios --release` ignores `MINT_E2E_FORCE_ECLAIRAGE_KIND` entirely (asserted by `kReleaseMode` guard test + `strings Runner | grep -c MINT_E2E_FORCE_ECLAIRAGE_KIND` strategy).
**Plans**: TBD (≤ 4)
**Risk** (top 1):
  - **R-80-1**: Hidden additional dispatcher branches that ALSO produce eclairage payloads but bypass the wiring point. Mitigation: panel pre-PR (Pre-push checklist mandatory rule) + `grep -rn 'EclairagePayload\\|EclairageCardData(' apps/mobile/lib/` to enumerate ALL render sites before wiring.

### Phase 81: Backend eclairage contract
**Goal**: Ship the matching backend half of the eclairage contract — extend `AnonymousChatRequest` with optional `archetype` field, extend `AnonymousChatResponse` with optional `eclairage: EclairageSchema | None`, implement the deterministic emitter keyed on `(archetype, turn_number)`, and honor `MINT_E2E_FORCE_ECLAIRAGE_KIND` server-side. LSFin-compliance hardened (always range, always disclaimer, expanded banned-terms list).
**Depends on**: Phase 80 (Flutter consumer contract finalized — backend Pydantic schema must mirror `EclairageCardData` field names).
**Requirements**: ECLB-01, ECLB-02, ECLB-03, ECLB-04, ECLB-05
**Success Criteria** (what must be TRUE):
  1. `cd services/backend && pytest tests/api/v1/test_anonymous_chat_eclairage.py -q` PASSES with assertion `eclairage.kind == "fiscal_margin_3a"` for `POST /api/v1/anonymous/chat {"message": "ok", "archetype": "julien_swiss"}` at turn 2.
  2. `grep -n "archetype" services/backend/app/schemas/anonymous_chat.py` shows the field declared as `Optional[Literal["julien_swiss", "couple_acheteurs_lausanne", "jeune_diplome_zurich", "cadre_40_55_lpp_rachat"]]`.
  3. Backend OpenAPI canonical regenerated (`python3 services/backend/tools/generate_canonical.py`) and committed; CI `openapi-parity` job green.
  4. `check_banned_terms` MCP invoked at `EclairagePayload.build()` time fails the test if any of `idéal | il faut | vous économiserez | rentable | opportunité | garanti | optimal | meilleur` leaks into headline/body.
  5. Setting `MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a` env var on Railway staging forces every archetype to emit `kind=fiscal_margin_3a` (asserted by deterministic E2E pytest hitting staging).
**Plans**: TBD (≤ 4)
**Risk** (top 2):
  - **R-81-1**: Schema additive change breaks an unknown downstream consumer (mobile staging build, walker, or fixture). Mitigation: schema fields all `Optional` with `None` default + `python3 services/backend/tools/generate_canonical.py` + full backend `pytest -q` BEFORE push (memory rule `feedback_pre_push_checklist`).
  - **R-81-2**: LSFin compliance regression — adding `eclairage` payload without disclaimer would ship a soft-flag (audit B already flagged 2 soft-flags). Mitigation: `check_banned_terms` + `lsfin_disclaimer` field non-optional in schema + explicit pytest `test_eclairage_always_includes_disclaimer`.

### Phase 82: Walker coord-system overhaul
**Goal**: Replace the broken cliclick desktop-px coord system (audit A) with runtime sim-window anchors derived via `osascript`, recalibrate `hero_bboxes.json` to iPhone 17 Pro native resolution 1206×2622 (excluding Dynamic Island), require ≥2 consecutive stable SHA hashes for `wait_for_ui` quiescence, and add the missing beta-disclosure dismiss step + scroll-to-register-CTA gesture.
**Depends on**: Phase 80 + Phase 81 (the wired stack must exist BEFORE walker calibrates against it — otherwise we calibrate against beta-modal screens, repeating the v2.10 trap).
**Requirements**: WALKC-01, WALKC-02, WALKC-03, WALKC-04, WALKC-05, WALKC-06
**Success Criteria** (what must be TRUE):
  1. `bash walker_premier_eclairage.sh --archetype julien_swiss --dry-run` logs `osascript bounds: {X, Y, W, H}` and computes anchor-derived tap coords (no hardcoded `cliclick c:NNN,NNN` desktop pixels in the script source — `grep -nE 'cliclick c:[0-9]+,[0-9]+' tools/simulator/walker_premier_eclairage.sh` returns 0 matches).
  2. `cat tools/simulator/hero_bboxes.json | jq '._resolution_px'` returns `[1206, 2622]` AND every `bbox` entry's `y0 >= 180` (Dynamic Island excluded — asserted by new `tools/checks/hero_bboxes_sanity.py` lint).
  3. `wait_for_ui` requires ≥ 2 consecutive identical SHA hashes before returning (asserted by injecting a 1-stable-1-different sequence into the helper and confirming it does NOT return early). Hash sequence dumped to `walker.log` after 3 retries.
  4. Walker activates Simulator window via `osascript -e 'tell application "Simulator" to activate'` BEFORE every `_tap_at` call (asserted by `grep -c 'tell application "Simulator" to activate' walker_premier_eclairage.sh >= 1` AND by step trace in dry-run).
  5. `walker_premier_eclairage.sh` log shows an explicit `step_beta_disclosure_dismiss` step BEFORE the first chat-message step, AND the scroll-to-register-CTA step uses `cliclick dd:X,Y du:X,Y2` (drag-down→drag-up swipe gesture, not tap).
**Plans**: TBD (≤ 4)
**Risk** (top 2):
  - **R-82-1**: macOS Sonoma/Sequoia simulator window has internal chrome (titlebar height varies by macOS version) → anchor math drifts across dev hosts. Mitigation: `osascript` returns CONTENT bounds (not chrome-inclusive) + runtime calibration probe at script start logs the resolved screen-px-per-device-px ratio; deviation > 5% from expected → exit 4.
  - **R-82-2**: Diff against existing tool drift — `walker.sh` (legacy) has historical flags (`--no-codesign` for .nosync provenance xattrs per `feedback_diff_against_existing_tool`). Mitigation: textual line-by-line diff `walker.sh` vs `walker_premier_eclairage.sh` BEFORE merging, port any missing build/launch flags.

### Phase 83: Sim hygiene + state isolation
**Goal**: Eliminate state pollution between archetype runs (audit D) — wire `xcrun simctl shutdown && erase && boot` per archetype, defensive `uninstall ch.mint.app`, ship `MINT_DISABLE_BETA_MODAL` dart-define wired into `BetaProgramDisclosureSheet.maybeShow`, gitignore walker output paths, and add a sim-runtime preflight check.
**Depends on**: Phase 82 (walker overhaul stable). Could run parallel with 82 conceptually but ships sequential to avoid the parallel-PR-merge race that bit v2.10.
**Requirements**: SIMH-01, SIMH-02, SIMH-03, SIMH-04, SIMH-05
**Success Criteria** (what must be TRUE):
  1. Running `walker_premier_eclairage.sh --archetype julien_swiss` then `--archetype jeune_diplome_zurich` consecutively shows BOTH runs starting from a fresh sim state — verified by SharedPrefs check (`xcrun simctl spawn $DEVICE_ID launchctl list | grep ch.mint` empty between runs) and beta-disclosure shown again on the second run if `MINT_DISABLE_BETA_MODAL=false`.
  2. With `--dart-define=MINT_DISABLE_BETA_MODAL=true`, `BetaProgramDisclosureSheet.maybeShow()` returns `false` immediately (asserted by widget test `beta_modal_disable_dart_define_test.dart`); walker passes the flag in its build invocation.
  3. `git status --porcelain` after a walker run shows ZERO new tracked files under `screenshots/walkthrough/`, `tools/simulator/walker_runs/`, or `.planning/walker/` (asserted by `.gitignore` lint + integration test running walker in dry-run + checking `git status`).
  4. Walker `--archetype` mode preflight refuses to start if no booted iOS sim runtime is present (`xcrun simctl list runtimes | grep -c iOS` >= 1 check), exiting with explicit error message including `MINT_WALKER_REQUIRED_RUNTIME` override hint.
  5. `xcrun simctl uninstall $DEVICE_ID ch.mint.app` is invoked unconditionally before `simctl install` in the script body (`grep -c 'simctl uninstall' walker_premier_eclairage.sh >= 1`).
**Plans**: TBD (≤ 4)
**Risk** (top 1):
  - **R-83-1**: `simctl erase` per archetype adds ~20-40s per run × 4 archetypes = +2-3 min walker total runtime; might bust a 5-min CI budget. Mitigation: erase is conditional on `--archetype` mode only (smoke runs unaffected); document the runtime in walker README.

### Phase 84: Cross-language drift fix
**Goal**: Fix the audit-B + audit-E cross-language drift — `build_discovery_system_prompt` accepts a `language` parameter today but never reads it, so DE input still produces FR system prompt (and FR coach output with DE disclaimers — incoherent). Wire the param. Add an ARB key parity CI gate to prevent locale drift across the 6 ARB files.
**Depends on**: Independent of 80/81/82/83 in principle, but ships AFTER 83 so the walker run (Phase 85) sees both fixes simultaneously.
**Requirements**: LANG-01, LANG-02, LANG-03
**Success Criteria** (what must be TRUE):
  1. `pytest services/backend/tests/api/v1/test_anonymous_chat_language.py -q` PASSES with: `POST /anonymous/chat {"message": "Was ist die 3. Säule?", "language": "de"}` returns response `body` matching DE language pattern (e.g., contains `Säule | Vorsorge | Steuer` not `pilier | prévoyance | impôt`) AND `disclaimers` localized to DE.
  2. `grep -n 'def build_discovery_system_prompt' services/backend/app/api/v1/endpoints/anonymous_chat.py` shows the function reads `language` (not just accepts it as a dead param) — asserted by AST-level pytest probing the function body for `language` token usage outside the signature.
  3. CI workflow `.github/workflows/ci.yml` has a job `arb-key-parity` that runs `python3 tools/checks/arb_key_parity.py` and fails the build if any key in `app_fr.arb` is missing in `app_{en,de,es,it,pt}.arb` (or vice versa). Verified by intentionally deleting a key from `app_de.arb` in a throwaway commit + observing CI red.
**Plans**: TBD (≤ 3)
**Risk** (top 1):
  - **R-84-1**: 6-locale parity gate may flag pre-existing drift accumulated over previous milestones (potentially blocking 80+ unrelated PRs). Mitigation: introduce gate AS WARNING for one PR cycle, snapshot the current drift to a `arb_parity_baseline.json`, then flip to ERROR on net-new drift only — avoids halting unrelated work; remove baseline once cleaned.

### Phase 85: Walker green 4 archetypes + TestFlight 2.11.0 cut
**Goal**: LAST gate. Run `walker_premier_eclairage.sh --no-dry-run` against all 4 archetypes, bake per-archetype goldens, bump `pubspec.yaml` to `2.11.0+1`, trigger `testflight.yml` workflow, verify IPA in App Store Connect, attach run-id evidence to the build description.
**Depends on**: Phases 80, 81, 82, 83, 84 (all wired and merged to `dev`).
**Requirements**: WALKR-01, WALKR-02, WALKR-03, WALKR-04, WALKR-05, WALKR-06
**Success Criteria** (what must be TRUE):
  1. `bash walker_premier_eclairage.sh --archetype julien_swiss --no-dry-run` exits 0 with 6/6 captured screenshots SHA-distinct (no stuck-UI false-positive), evidence at `.planning/walker/<run-id>/julien_swiss/`.
  2. Identical exit-0 outcome on 3 other archetypes: `couple_acheteurs_lausanne`, `jeune_diplome_zurich`, `cadre_40_55_lpp_rachat`. All 4 evidence dirs present.
  3. `python3 tools/simulator/image_diff.py --archetype X --check-all-bboxes` reports SSIM ≥ 0.96 on every hero bbox vs committed goldens at `tools/simulator/goldens/<archetype>/<checkpoint>.png` for all 4 archetypes; register-CTA bbox SSIM ≥ 0.96 specifically (exit 3 if fail).
  4. `git tag` shows `v2.11.0` on the merge commit; `apps/mobile/pubspec.yaml` has `version: 2.11.0+1`; `testflight.yml` workflow run completed green; IPA visible in App Store Connect with build number `1`.
  5. TestFlight build description contains the walker run-id (e.g., `walker-2026-05-NN-HHMMSS`) AND a link to `.planning/walker/<run-id>/summary.json` AND the 4-archetype green checklist; verified by manual App Store Connect inspection screenshot saved to `.planning/phases/85-walker-green/evidence/`.
**Plans**: TBD (≤ 4)
**Risk** (top 2):
  - **R-85-1**: Golden bake circularity — committing fresh goldens from the same walker run that's supposed to verify them is a no-op gate (audit A's exact original failure mode). Mitigation: golden bake in dedicated commit BEFORE the green-gate run; green-gate run uses the committed goldens; if any SSIM < 0.96 → human review of the per-archetype diff PNGs in `.planning/phases/85-walker-green/evidence/diffs/` BEFORE re-baking.
  - **R-85-2**: TestFlight upload may fail on App Store Connect side (provisioning, beta review queue, "Another build in review" race — already rescued in commit `0daadff1`). Mitigation: testflight.yml has retry+rescue logic; if upload still fails, the walker green is already evidence-of-readiness; ship blocker logged but milestone remains shippable on next-day retry — no scope drift to other phases.

---

## Coverage Summary

| Category | REQ IDs           | Phase | Coverage |
|----------|-------------------|-------|----------|
| Eclairage E2E wiring (Flutter) | ECLW-01..05 | 80    | 5/5      |
| Backend eclairage contract     | ECLB-01..05 | 81    | 5/5      |
| Walker coord-system overhaul   | WALKC-01..06 | 82   | 6/6      |
| Sim hygiene + state isolation  | SIMH-01..05 | 83    | 5/5      |
| Cross-language drift fix       | LANG-01..03 | 84    | 3/3      |
| Walker green + TestFlight cut  | WALKR-01..06 | 85    | 6/6      |
| **Total**                      |             |       | **30/30 ✓** |

**No orphans. No duplicates. Every v2.11 REQ maps to exactly one phase.**

---

## 5 Audits — Research Artifacts Referenced

| Audit | Topic                                          | Phases that absorb the audit's findings        |
|-------|------------------------------------------------|------------------------------------------------|
| A     | Walker tap coords vs Phase 71a/73 UI réelle    | Phase 82 (WALKC-01..06) + Phase 85 (WALKR-03..04) golden recalibration |
| B     | Backend pipeline staging — phantom contract C2 + cross-language drift + 2 LSFin soft-flags | Phase 81 (ECLB-01..05) + Phase 84 (LANG-01..02) |
| C     | `MINT_E2E_FORCE_ECLAIRAGE_KIND` lifecycle — getter dead code | Phase 80 (ECLW-01, ECLW-04) + Phase 81 (ECLB-03 server-side honor) |
| D     | Beta modal `isDismissible: false` + walker idempotence + `wait_for_ui` happy-on-stuck | Phase 82 (WALKC-03, WALKC-05) + Phase 83 (SIMH-01..05) |
| E     | i18n + animation timing — `LocaleProvider` FR-hardcoded OK + iPhone 17 Pro 1206×2622 + iOS 26 keyboard 350ms + Liquid Glass blur SHA flap | Phase 82 (WALKC-02 res, WALKC-03 ≥2 hashes) + Phase 84 (LANG-01..03) |

Audits are research artifacts (not phases). They are NOT re-researched — Julien's constraint 2026-05-05.

---

## Doctrine v2.11 (Anti–Phantom-Contract)

1. **Wire mécaniquement, pas documentation** : every contract has an end-to-end test that proves it is alive (widget test for Flutter, pytest for backend, walker run for the integrated stack).
2. **Walker = la machine de vérité** : if the walker doesn't validate it, it's not shipped.
3. **No PR without runtime evidence** : every PR in v2.11 attaches at minimum one of (walker dry-run log / pytest output / widget test output) showing the new wiring is exercised.
4. **Pre-push checklist mandatory** (memory rule `feedback_pre_push_checklist`) : grep ALL callers when changing a function signature; regenerate OpenAPI canonical or ARB; full pytest + flutter test BEFORE push. No "clean" claim before all three pass.
5. **Sequential merges to `dev`** : no parallel phase PRs. Avoids the v2.10 Phase 71a/71b race where 71b assumed a 71a contract that wasn't merged yet.

---

## Progress

**Execution Order:**
Phases execute in numeric order: 80 → 81 → 82 → 83 → 84 → 85. No decimal phases planned at roadmap time. Decimal phases (e.g., 82.1) only opened via `/gsd-insert-phase` if an audit-D-style runtime issue is discovered mid-execution.

| Phase                                                  | Plans Complete | Status      | Completed |
|--------------------------------------------------------|----------------|-------------|-----------|
| 80. Eclairage E2E wiring (Flutter)                     | 0 / TBD        | Not started | -         |
| 81. Backend eclairage contract                         | 0 / TBD        | Not started | -         |
| 82. Walker coord-system overhaul                       | 0 / TBD        | Not started | -         |
| 83. Sim hygiene + state isolation                      | 0 / TBD        | Not started | -         |
| 84. Cross-language drift fix                           | 0 / TBD        | Not started | -         |
| 85. Walker green 4 archetypes + TestFlight 2.11.0 cut  | 0 / TBD        | Not started | -         |

---

*Last updated: 2026-05-05 — v2.11 ROADMAP created. Coverage 30/30. 6 phases. Sequential execution. Phase 85 = LAST gate before TestFlight 2.11.0.*
