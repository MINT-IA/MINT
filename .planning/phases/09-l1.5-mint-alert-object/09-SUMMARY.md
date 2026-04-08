# Phase 9: L1.5 MintAlertObject (S5) - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 4/4 plans landed

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 09-01 | Typed API + ARB | 3 | MintAlertObject + VoiceResolutionContext + 8 widget tests + 6 ARB keys × 6 locales |
| 09-02 | Feeders + migration | 4 | ContextualCard gravity + card_ranking_service + 3 feeders + debt_alert_banner migrated + deleted, 9 new tests |
| 09-03 | CI gates | 2 | no_llm_alert.py + extended sentence_subject_arb_lint, both exit 0 |
| 09-04 | Patrol + ack + announce + TalkBack | 4 | G3 ack via BiographyFact + announce on G2→G3 + MintAlertHost + 19 tests (6 host + 5 TalkBack + 8 patrol) |

**Total:** 13 execution commits.

## Key outcomes
- **MintAlertObject typed API** at `apps/mobile/lib/widgets/alert/mint_alert_object.dart` — constructor requires `Gravity gravity`, `String fact`, `String cause`, `String nextMoment`. **NO `String message` field** — grammar enforced at compile time. Prevents LLM free-form leakage.
- **Gravity enum reused** from generated `voice_cursor_contract.g.dart` — no duplication, contract is single source of truth.
- **card_ranking_service** floats G3 to top, G2 second, ungraded last. Stable sort preserves within-tier order.
- **debt_alert_banner.dart DELETED.** Single call site in `financial_report_screen_v2.dart` migrated to MintAlertObject G3.
- **G3 ack persistence** via `BiographyFact.alertAcknowledged` — COGA pattern respected, ack stored in biography with alertId + timestamp.
- **SemanticsService.announce on G2→G3 transition** (not first render per D-11). MintAlertHost wrapper tracks previous gravity.
- **TalkBack 13 widget-trap sweep on S5** — IconButton tooltips, InkResponse labels, AnimatedSwitcher keys verified. CustomPaint N/A (MintAlertObject doesn't use one).
- **8 patrol integration tests** covering G2/G3 × 3 voices + sensitive-topic guard + fragile-mode guard. Compile-clean, awaiting device runner (same posture as existing patrol tests).
- **Two CI gates landed:** `no_llm_alert.py` (prevents MintAlertObject in files importing claude_*_service) + extended sentence_subject_arb_lint (now covers alert keys).

## Deviations
1. **MintAlertHost wrapper** added by Plan 09-04 to carry the gravity-transition state (needed for SemanticsService.announce to fire only on G2→G3, not first render). Not in original plan, but doctrine-compatible extension.
2. **Exhaustive-switch fixups in 7 files** — adding `Gravity` to `ContextualCard` revealed exhaustive switches on old gravity-less models. All fixed in commit `c991822d`.
3. **Patrol tests not locally executable** — require device runner, same as the 2 existing allowlisted patrol baseline tests. Compile-clean + analyze 0 is the landable state.

## Gate results
- `flutter analyze lib/` 0 errors (6 pre-existing info notes in trust/mint_trame_confiance.dart, out of Phase 9 scope)
- All new unit/widget tests green (19 added)
- `no_llm_alert.py` exit 0
- `sentence_subject_arb_lint.py` exit 0
- OpenAPI contract drift guard still green (untouched)

## Baseline deltas
- Flutter tests: +19 unit/widget tests + 8 patrol (device runner)
- New widget: MintAlertObject + MintAlertHost
- Deleted widget: debt_alert_banner.dart
- New service: card_ranking_service.dart

## Branch state
`feature/v2.2-p0a-code-unblockers` — 97 commits ahead of dev.

## What Phase 9 unblocks
- **Phase 10** (Onboarding v2): alert primitive ready if onboarding needs to render an alert
- **Phase 11** (Krippendorff): MintAlertObject output channels are in the compliance regression scope for Phase 12
- **Phase 12** (Ship gate): ComplianceGuard regression must cover MintAlertObject at all 5 voice levels

## Next
Phase 10: L1.8 Onboarding v2 — delete 5 onboarding screens, wire intent → chat directly, drop screens-before-first-insight from 5 to 2. Biggest UX change of the milestone.
