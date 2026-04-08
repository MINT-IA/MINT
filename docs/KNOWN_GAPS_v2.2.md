# v2.2 Known Gaps — Production Readiness Audit

**Sweep date:** 2026-04-08
**Branch:** feature/v2.2-p0a-code-unblockers
**Scope:** 172 commits on 735 touched files since dev divergence (246 code files)
**Method:** 10-category audit-only sweep. Zero code changes.

**2026-04-07 update — P1 + 2×P2 RESOLVED** (pre-dev-merge polish pass):
- P1 `profile_drawer.dart:118` language picker no-op → wired to `/settings/langue` (commit `e8955b4e`).
- P2 `coach_orchestrator.dart:775` FR-only fallback → localized for 6 locales via new `CoachFallbackMessages` dispatch (commit `58a57628`).
- P2 `mint_trame_confiance.dart:143` unjustified ignore → corrected lint name + multi-line D-06 rationale (commit `5d98fdf0`).

Post-fix verification: `flutter analyze lib/` 0 errors, 459/459 coach tests green, 18/18 ship gates PASS.

## Executive summary

- **P1 gaps (ship-blocking for production-ready):** 1
- **P2 gaps (should fix before ship but not blocking):** 3
- **P3 gaps (documented debt, deferred to v2.3+):** 5
- **Won't fix (doctrine-protected or out of scope):** 8

**Overall production-readiness grade: A-**

The v2.2 code base is unusually clean for a milestone of this scope. Most "findings" are doctrine-protected stubs (Phase 12 D-12 externalAction), generated files (`app_localizations*.dart`), or P2/P3 debt that is already tracked in TODOs with explicit phase tags. The only true ship-blocker is the **profile drawer language picker no-op** (Cat 8): it presents a tap target with no behavior, which violates the "no dead UI" principle and is likely to surface in user testing within minutes of launch.

## Category 1 — TODO/FIXME/HACK/XXX in v2.2-touched code

ARB hits (`756.XXXX.XXXX.XX`, `TODOS LOS`) are AVS number format placeholders and Spanish/Portuguese translations of the word "TODOS" — false positives, excluded.

| File:Line | Content | Severity | Proposed fix | 10-min fixable |
|---|---|---|---|---|
| `apps/mobile/lib/providers/coach_profile_provider.dart:909` | `// TODO(P2): Sync monthly check-ins to backend for cross-device access` | P2 | Defer to v2.3 backend sync sprint. Document in `docs/KNOWN_GAPS_v2.2.md` (this file). | n |
| ~~`apps/mobile/lib/services/coach/coach_orchestrator.dart:773`~~ | ~~`// TODO(S57-i18n): migrate hardcoded FR strings`~~ | ~~P2~~ | **RESOLVED 2026-04-07** (`58a57628`) — `CoachFallbackMessages` dispatch, 6 locales. | — |
| ~~`apps/mobile/lib/widgets/profile_drawer.dart:118`~~ | ~~`// TODO: inline language picker`~~ | ~~**P1**~~ | **RESOLVED 2026-04-07** (`e8955b4e`) — wired to `/settings/langue`. | — |
| `services/backend/app/services/retirement/avs_estimation_service.py:165` | `# TODO(P1-3): LAVS art. 29quinquies — income splitting during marriage not yet modeled.` | P3 | Already known product gap (couple data client-side only). Defer. | n |

## Category 2 — Stubs and UnimplementedError

| File:Line | Content | Severity | Status |
|---|---|---|---|
| `apps/mobile/lib/widgets/alert/voice_resolution_context.dart:88` | `ExternalActionStub.execute() throws UnimplementedError` | Won't fix | **Doctrine-protected**: Phase 12 D-12 G3 — partner routing requires signed contract. Stub is deliberate, documented in `PHASE_12.md`, and the constructor is usable so Plan 09-02 wires correctly. |

Zero unintentional stubs.

## Category 3 — Lint suppression comments

| File:Line | Suppression | Status |
|---|---|---|
| `app_localizations*.dart` (12 hits) | `ignore_for_file: type=lint`, `ignore: unused_import` | Won't fix — all generated files. |
| `apps/mobile/lib/providers/coach_profile_provider.dart:1611` | `// ignore: unused_local_variable — extracted for future use` | P3 | Annotated reason. Either wire `tauxActivite` consumer or delete extraction. ~5 min if delete. |
| `apps/mobile/lib/services/navigation/screen_registry.dart` (5 hits, lines 372/453/488/742/937) | `// ignore: prefer_const_constructors` | P3 | Likely runtime-built widgets that can't be const. Verify and either make const or annotate reason. ~15 min total. |
| ~~`apps/mobile/lib/widgets/trust/mint_trame_confiance.dart:143`~~ | ~~`// ignore: avoid_unused_constructor_parameters`~~ | ~~P2~~ | **RESOLVED 2026-04-07** (`5d98fdf0`) — corrected to `unused_element_parameter` + D-06 API-stability rationale. |

## Category 4 — `skip: true` in tests

| File:Line | Reason | Status |
|---|---|---|
| `apps/mobile/test/patrol/onboarding_patrol_test.dart:47` | LateInitializationError, deferred to v2.3 | Known baseline (documented in `df2b39cb` commit). |
| `apps/mobile/test/patrol/document_patrol_test.dart:69` | Same | Known baseline. |
| `apps/mobile/test/goldens/s4_response_card_golden_test.dart:34/40/46` | 3 golden tests gated, README documents how to re-enable | Known baseline; intentional intent-only fixture per `README.md`. |
| `apps/mobile/test/screens/lpp_deep_screens_smoke_test.dart:258` | "Scroll offset depends on MintNarrativeCard height" | P3 | Replace scroll-offset assertion with semantic finder. ~20 min. |
| `apps/mobile/test/navigation_verify_test.dart:34` | No reason annotated | P2 | Either annotate reason or delete dead test. ~5 min. |
| `apps/mobile/test/widgets/alert/mint_alert_object_talkback_test.dart:147` | "N/A: MintAlertObject uses Icon, not CustomPaint" | Won't fix — annotated, justified. **DO NOT TOUCH** (parallel agent owns alert files). |

## Category 5 — Hardcoded user-facing strings (i18n violations)

Scanned 83 v2.2-touched UI files in `lib/screens/` + `lib/widgets/`.

13 raw `Text('...')` hits, **all 13** are `Text('CHF ${formatChf(amount)}')` numeric formatters in `lpp_deep/rachat_echelonne_screen.dart`, `pillar_3a_deep/staggered_withdrawal_screen.dart`, and `disability_countdown_widget.dart`. None are user-facing copy.

**Zero hardcoded sentences.** Clean.

(Note: `CHF` prefix could arguably be locale-aware via `NumberFormat.currency`, but this is P3 polish, not an i18n violation.)

## Category 6 — Hardcoded `Color(0xFF...)` beyond `theme/colors.dart`

Scanned all 246 v2.2-touched code files.

**Zero hits.** Phase 12-02 WCAG AA gate is doing its job.

## Category 7 — Coach fallback language hardcoding

`coach_orchestrator.dart:775` `_chatFallback()` returns:
```
'Le coach IA n\'est pas disponible pour le moment.\n\n'
'En attendant, tu peux :\n'
'• Explorer tes simulateurs (3a, LPP, retraite)\n'
...
```

**Severity P2.** This is the user-visible message when SLM/BYOK both fail, which means German/Italian/English/Spanish/Portuguese users see French. The TODO at line 773 acknowledges the gap and explains the constraint (no `BuildContext` in static service). Fix requires either:
1. Static `S.current` accessor pattern (~30 min)
2. Caller injects pre-localised fallback string (~45 min, cleaner)

Backend `claude_coach_service.py`: scanned for fallback FR strings, none found. The backend is clean.

## Category 8 — Profile drawer incomplete affordances

| Tap target | Behavior | Severity |
|---|---|---|
| `drawerLanguage` (line 113-120) | **No-op.** Calls `// TODO: inline language picker` and does nothing. | **P1 — ship blocker** |
| `drawerApiKey` | Routes to `/profile/byok` | OK |
| `drawerPrivacy` | Routes to `/profile/consent` | OK |
| `drawerDataTransparency` | Routes to `/profile/data-transparency` | OK |
| `drawerPrivacyControl` | Routes to `/profile/privacy-control` | OK |
| `drawerLogout` | Pops drawer, navigates to `/` | OK (no auth model in v2.2 yet, so this is correct) |

**Recommended fix (10-15 min):** wire `drawerLanguage` to push `/profile/language` (existing route — verify) OR show a `CupertinoActionSheet` with the 6 ARB locales. Either option resolves the dead UI.

## Category 9 — Cross-device state TODOs

| File:Line | Local-only state | Matters for v2.2? |
|---|---|---|
| `apps/mobile/lib/providers/coach_profile_provider.dart:909` | Monthly check-ins | No — v2.2 is single-device by design |
| `apps/mobile/lib/services/cap_memory_store.dart:20` | CapMemory continuity | No — P3 documented |
| `apps/mobile/lib/services/expat_service.dart:44` | Source tax calculations (mobile re-implements backend math) | P2 — known product gap (frontalier tax not implemented), already tracked in MEMORY.md |

All three are tracked, none block v2.2 ship.

## Category 10 — Orphan ARB keys

Sampled first 200 of 6494 FR ARB keys + verified the 3 known orphans from Phase 8c doctrine.

| Key | Status |
|---|---|
| `intentChipBilan` | **Won't fix** — Phase 8c doctrine + intent_router legacy routing |
| `intentChipPrevoyance` | **Won't fix** — same |
| `intentChipNouvelEmploi` | **Won't fix** — same |
| (sample of 200 other keys) | Zero new orphans |

A full 6494-key sweep is not run here (would exceed sweep timebox); recommend a dedicated `tools/check_orphan_arb.dart` job in v2.3 CI.

## Recommended fix order (if time allows)

### Quick wins (<10 min each, ~25 min total)
1. **[P1] Wire `drawerLanguage` tap** (`profile_drawer.dart:118`) — push `/profile/language` route or inline `CupertinoActionSheet`. **Ship-blocker.**
2. **[P3] Annotate or delete** `navigation_verify_test.dart:34` skipped test reason.
3. **[P3] Delete unused** `tauxActivite` extraction in `coach_profile_provider.dart:1611` (or wire it).

### Medium wins (10-30 min each, ~75 min total)
1. **[P2] Localise** `coach_orchestrator._chatFallback()` via `S.current` static accessor or caller injection. Affects all 6 locales when SLM+BYOK both fail.
2. **[P3] Replace scroll-offset assertion** in `lpp_deep_screens_smoke_test.dart:258` with semantic finder, un-skip.
3. **[P3] Audit `screen_registry.dart` const ignores** (5 hits) — make const where possible.

### Known deferred (documented, not blocking ship)
1. P2: `coach_profile_provider.dart:909` monthly check-in backend sync (v2.3 sprint)
2. P3: `cap_memory_store.dart:20` CapMemory backend continuity (v2.3+)
3. P3: `expat_service.dart:44` mobile↔backend source-tax authority (P1-3 product gap)
4. P3: `avs_estimation_service.py:165` LAVS art. 29quinquies splitting (P1-3 product gap)
5. P3: 2 Patrol tests (LateInitializationError, v2.3)

### Won't fix (doctrine or scope)
1. `voice_resolution_context.dart:88` `ExternalActionStub` — Phase 12 D-12 G3 doctrine
2. `app_localizations*.dart` lint ignores (12) — generated files
3. `mint_alert_object_talkback_test.dart:147` skipped — annotated, justified, parallel-agent file
4. `intentChipBilan/Prevoyance/NouvelEmploi` ARB orphans — Phase 8c doctrine
5. 3 `s4_response_card_golden_test.dart` skips — intentional intent-only fixture
6. `mint_trame_confiance.dart:143` ignore — parallel-agent file, re-audit post-merge

---

**Estimated fix time if all P1+P2 are addressed: ~1.5 hours**

**Top 3 most critical findings:**
1. **P1 — Profile drawer language picker is a no-op** (`profile_drawer.dart:118`). Dead UI. ~15 min fix. **Must ship green.**
2. **P2 — Coach offline fallback is FR-only** (`coach_orchestrator.dart:775`). 5 of 6 locales see French when SLM+BYOK both fail. ~30 min fix.
3. **P2 — `mint_trame_confiance.dart:143` unjustified ignore** — flagged but parallel-agent file; **re-audit post-merge** before ship-gate.
