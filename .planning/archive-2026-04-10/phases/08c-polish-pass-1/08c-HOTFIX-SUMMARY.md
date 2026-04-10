# Phase 8c Hot-Fix Summary — POLISH_PASS_1 actionable items

**Phase:** 08c-polish-pass-1
**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Source:** `docs/POLISH_PASS_1.md` (4 `hot-fix-now` items)
**Doctrine:** `feedback_anti_shame_situated_learning.md`

---

## Resolved (4 / 4 hot-fix-now items)

| # | ID | Surface | Item | Commit | LOC delta |
|---|----|---------|------|--------|-----------|
| 1 | P-S1-01 | S1 onboarding intent | Delete 3 anti-shame chips (`intentChipBilan`, `intentChipPrevoyance`, `intentChipNouvelEmploi`) from rendered list | `737838fd` | intent_screen.dart: −12 / +9, intent_screen_test.dart: −10 / +17 |
| 2 | P-S2-01 | S2 home Aujourd'hui | Remove `StreakBadgeWidget` from `PlanRealityCard` + delete the widget file | `a35be357` | mint_home_screen.dart: −4 / +5, plan_reality_home_test.dart: −56 / +6, streak_badge.dart: **deleted** (−200 LOC) |
| 3 | P-S2-02 | S2 home Aujourd'hui | Remove `mintHomeConfidence` + `mintHomeNoActionProjection` suggestion chips + ARB keys (6 locales) | `dbf6a87d` | mint_home_screen.dart: −34 / +6, ARB × 6: −12, app_localizations*.dart × 7: −63 (regenerated) |
| 4 | P-S3-01 + P-S3-02 | S3 coach bubble | Remove `CoachAvatar` rendering + `CoachTierBadge` rendering (classes preserved) | `8fa8993e` | coach_message_bubble.dart: −13 / +12 |

**Total commits:** 4 (one per hot-fix as planned).
**Total files touched:** 5 source + 1 deleted + 14 l10n (12 ARB/dart) + 2 tests = ~21 files.

---

## ARB key deletions

| Key | Locales | Notes |
|-----|---------|-------|
| `mintHomeConfidence` | fr, en, de, es, it, pt | Anti-shame nudge — "improve your data" framing |
| `mintHomeNoActionProjection` | fr, en, de, es, it, pt | Anti-shame nudge — "if you do nothing" framing |

**Total ARB keys deleted: 2 × 6 locales = 12 entries.** Generated `app_localizations*.dart` files regenerated via `flutter gen-l10n`.

**Deliberately preserved (scope clarification vs POLISH_PASS_1):**
`intentChipBilan`, `intentChipPrevoyance`, `intentChipNouvelEmploi` ARB keys + `IntentRouter` mappings + `coachOpenerIntentBilan/Prevoyance` opener strings are kept intact. Removing them would have cascaded into `lib/services/coach/intent_router.dart`, `lib/screens/coach/coach_chat_screen.dart`, and 4 golden journey tests (`pierre_golden_path_test`, `marc_golden_path_test`, `anna_golden_path_test`, `newjob_journey_test`) — well outside the "strict ownership" scope of this hot-fix pass. The doctrinal goal (chips no longer visible in onboarding UI) is achieved by removing them from the rendered list only. Routing infrastructure remains for legacy deep-links and golden journeys.

---

## Verification gates

After **each** commit:

| Gate | Result |
|------|--------|
| `flutter analyze lib/` | **0 errors**, 6 baseline infos in `lib/widgets/trust/mint_trame_confiance.dart` (unrelated to this phase) |
| `flutter test test/screens/onboarding/intent_screen_test.dart` | **14 / 14 passed** (after commit 1) |
| `flutter test test/widgets/plan_reality_home_test.dart test/screens/main_tabs/` | **33 / 33 passed** (after commit 2) |
| `flutter test test/screens/main_tabs/` | **30 / 30 passed** (after commit 3) |
| `flutter test test/widgets/coach/` | **726 / 726 passed** (after commit 4) |

No new failures introduced. No regressions vs baseline.

---

## Doctrine alignment (anti-shame checkpoints)

| Checkpoint | Hot-fix | Resolution |
|---|---|---|
| #2 (no shame for incompleteness) | P-S2-02 | Deleted `mintHomeConfidence` ("improve confidence") chip |
| #3 (no levels/badges/scores tied to knowledge) | **P-S2-01** | Deleted `StreakBadgeWidget` (highest-gravity finding) |
| #3 (no curriculum framing) | P-S1-01 | Deleted `intentChipBilan` ("faire un bilan") chip |
| #3 (no retirement-default framing — CLAUDE.md anti-pattern #16) | P-S1-01 | Deleted `intentChipPrevoyance` ("comprends mal ma prévoyance") chip |
| #3 (no redundant onboarding paths) | P-S1-01 | Deleted `intentChipNouvelEmploi` chip (covered by `premierEmploi` + `changement`) |
| #6 (no inaction shaming) | P-S2-02 | Deleted `mintHomeNoActionProjection` ("Si tu ne fais rien") chip |

**Decorative noise (non-doctrinal but coherence wins):**
- P-S3-01 — `CoachAvatar` (24px gradient dot + "M") removed from coach reading zone.
- P-S3-02 — `CoachTierBadge` (SLM/BYOK/Fallback developer metadata) removed from coach reading zone.

---

## Remaining proposals from POLISH_PASS_1

### Defer to post-milestone (6) — not blockers for "très belle avant les humains" gate

| # | Item | Why deferred |
|---|------|-------------|
| P-S0-01 | S0 paragraph compression (~48 → ≤30 words) | Doctrinally locked copy; needs Julien + doctrine review |
| P-S0-02 | CTA color softening (`textPrimary` → `encre`/`anthracite`) | 5%-calmer polish; not a regression |
| P-S1-02 | Delete `intentScreenMicrocopy` footer | Onboarding rewrite in Phase 10 — risk of double-churn |
| P-S2-03 | Delete empty-state `ctxEmptyCta` → `/documents/scan` | Empty state will be rethought in Phase 10 |
| P-S2-04 | Coach opener `headlineLarge` → `headlineMedium` (Aesop demotion) | Consistency refinement, not regression |
| P-S3-03 | Remove "Sources" header + disclaimer info Icon | Phase 9 will reconsider these via `MintAlertObject` |

### Phase 9 pre-conditions (2) — *the reason Phase 9 exists*

| # | Item | Phase 9 dependency |
|---|------|-------------------|
| P-S4-01 | Proof-sheet alerte row should use typed `MintAlertObject` instead of inline `Container(warning bg + Icon + Text)` | Blocked on MintAlertObject typed API (Phase 9 deliverable) |
| P-S5-01 | S5 debt alert banner — 5 Phase 3 DELETE items (gradient bg, hardcoded strings, imperative copy, "plan de sortie" framing) | Phase 9 MintAlertObject rebuild replaces the entire banner |

---

## Self-Check

- intent_screen.dart edit verified: `Bash` analyze + targeted test pass.
- streak_badge.dart deletion verified: `git status` shows `D apps/mobile/lib/widgets/coach/streak_badge.dart`, file no longer exists, no remaining grep hits in `lib/`.
- mint_home_screen.dart edits verified: analyze + main_tabs tests green.
- coach_message_bubble.dart edits verified: 726 coach widget tests green.
- 4 commits present in branch history (`git log --oneline | head -4` would show: `8fa8993e`, `dbf6a87d`, `a35be357`, `737838fd`).
- All `flutter analyze lib/` runs returned same 6 baseline infos (no new errors or warnings introduced).

## Self-Check: PASSED

---

## Next steps

Phase 9 is unblocked from a polish-coherence standpoint. The 4 doctrinally-critical surface bleeds (S1 chips, S2 streak, S2 chips, S3 ornaments) are no longer present at HEAD. The `très belle avant les humains` gate (Phase 10.5) has 6 remaining defer-able polish items + 2 Phase 9 pre-conditions to address as Phase 9 lands `MintAlertObject`.
