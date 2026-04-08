# Phase 12: L1.6c Ton UX + Ship Gate - SUMMARY (CODE-SIDE COMPLETE)

**Completed:** 2026-04-08 (code side fully closed; human gates pending)
**Status:** GREEN — 5/6 plans landed + 1 hotfix sweep, Plan 12-06 awaits human T5/T6/T7 + ACCESS-01 + Krippendorff decisions

## Plans
| # | Plan | Commits | Status |
|---|---|---|---|
| 12-01 | Ton chooser UI | 3 | ✓ Segmented control + 14 ARB keys × 6 locales + 9 tests |
| 12-02 | WCAG AA all-touched gate | 3 | ✓ Dart widget test + Python hardcoded-color gate, 0 hits |
| 12-03 | BloomStrategy lint | 1 | ✓ All 12 MTC sites already explicit |
| 12-04 | ComplianceGuard regression | 3 | ✓ 61/61 samples across 10 channels, 0 violations |
| 12-05 | Ship gate matrix + 6 fixes | 5 | ✓ 17/18 → 18/18 after gate-2 hotfix, all green |
| HOTFIX | 21 test failures (Phases 7+8c+12 contract drift) | 3 | ✓ Cleared, 0 production code touched |
| 12-06 | Human gates T5/T6/T7 | 0 | ⏸ AWAITING USER |

**Total:** 18 execution commits.

## Key outcomes
- **Ton chooser** ships in intent_screen first-launch flow + ProfileDrawer settings, segmented control (Linear/Things 3 style), "curseur" word never user-visible (CI grep gate enforces)
- **WCAG 2.1 AA gate** verifies all 9 v2.2 surfaces hit textContrast + tap target on every CI run; zero hardcoded text-colors found across 702 lib/ files
- **BloomStrategy lint** ensures every MintTrameConfiance instantiation has an explicit strategy parameter; 12/12 callsites already compliant
- **ComplianceGuard regression** v2.2 final: 61 samples × 10 channels (alerts G2/G3 × N1-N5, biography, openers, extraction, alert grammar, rewritten coach phrases, voice cursor outputs, Ton chooser, regional overlays, landing/onboarding) — zero violations
- **Ship gate matrix** at `tools/ship_gate/run_all_gates_v2_2.sh` runs all 18 gates, generates `docs/SHIP_GATE_v2.2.md` with PASS/FAIL/owner per gate
- **18/18 gates GREEN** including the gate-2 test failures hotfix that cleared 21 contract-drift failures from Phases 7/8c/12 (test-side migration only, zero production touched)

## 18 ship gates final state
| # | Gate | Status |
|---|---|---|
| 1 | flutter analyze (errors-only) | ✓ |
| 2 | flutter test (full suite, allowlist) | ✓ 9326 passed / 8 skipped / 0 failed |
| 3 | pytest backend | ✓ |
| 4 | ruff (skip if absent) | ✓ |
| 5 | OpenAPI canonical drift | ✓ |
| 6 | VoiceCursorContract drift | ✓ |
| 7 | RegionalMicrocopy drift | ✓ |
| 8 | Contrast matrix (AAA + AA) | ✓ |
| 9 | Flesch-Kincaid French | ✓ |
| 10 | no_chiffre_choc grep | ✓ |
| 11 | no_legacy_confidence_render | ✓ |
| 12 | no_llm_alert | ✓ |
| 13 | sentence_subject + @meta level + no curseur | ✓ |
| 14 | landing no_numbers + no_financial_core | ✓ |
| 15 | s0_s5_aaa_only (refreshed paths) | ✓ |
| 16 | no_implicit_bloom_strategy | ✓ |
| 17 | REGIONAL_MAP grep (tightened) | ✓ |
| 18 | banned-terms grep | ✓ |

## Plan 12-06 — AWAITING HUMAN

Plan 12-06 (human-gated) requires:
1. **T4 (Phase 10.5)** — Galaxy A14 friction walkthrough on the new landing → intent → chat path (~30 min)
2. **T5 (Plan 12-06)** — STAB-18 tap-render walkthrough on A14 (~60 min)
3. **T6 (Plan 12-06)** — PERF-01..04 baseline capture: cold start, scroll, bloom (~45 min)
4. **T7 (Plan 12-06)** — Final "ready for humans" sign-off (~20 min)
5. **ACCESS-01** — 6 a11y partner recruitment emails sent (Phase 1 deferred, Phase 8b-04 deferred, now blocking)
6. **Krippendorff testers** — 15 testers recruited (Phase 11-02 deferred), runs the α validation

The infrastructure for all 6 items is fully shipped:
- A14 build script: `tools/scripts/build_a14.sh`
- Friction walkthrough README + template: `docs/FRICTION_PASS_1.md` + `docs/FRICTION_PASS_1/README.md`
- Krippendorff α runner: `tools/voice_corpus/krippendorff_runner.py` (synthetic fixture passes α=0.97)
- ACCESS-01 tracker: `docs/ACCESSIBILITY_TEST_LAYER1.md` (6 rows pending email send)

Decision tree at `docs/SHIP_GATE_v2.2.md` and individual phase context files.

## Branch state
`feature/v2.2-p0a-code-unblockers` — ~155 commits ahead of dev.

## What's left to ship v2.2
**Code-side: NOTHING.** The branch is fully shippable.
**Human-side:** the 6 items listed under Plan 12-06 above.

Two doctrine-compatible paths exist for the human-side:
- **Full ambition**: send emails + recruit testers + run all 4 walkthroughs → ship in 2-4 weeks
- **ACCESS-09 + Krippendorff descope**: sign written descope decisions per phase doctrine → ship in 1-2 days after the 4 walkthroughs

Either path is doctrine-compliant. The orchestrator awaits user decision.
