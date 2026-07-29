# W3-T1 P002-CARD-1 — ConfidenceScoreCard wired with MintCardActionBar — Receipt

> **Date** : 2026-05-12
> **Perimeter** : P002 (PHASE97_AUJOURDHUI_CARD_INVENTORY row 3)
> **Branch** : `feature/97.5-w3-t1-confidence-score-card-actionbar`
> **PLAN.md anchor** : §Wave 3, Task W3-T1, lines 323-335
> **RESEARCH.md anchors** : §B.2 (P002 perimeter) + §E.2 row 1 (per-card test pattern)
> **W1-T1 ADR anchor** : intent=explain → opens MintChatOverlay with templated Option A opener

---

## Work done

| Action | File | Reference |
|---|---|---|
| Wrap card root in `Semantics(identifier: 'card_confidence_score', container: true)` | `apps/mobile/lib/widgets/home/confidence_score_card.dart` | PLAN line 329 + RESEARCH risk D.5 M001 |
| Add `Key('card_confidence_score')` on the Container holding the new Column | same | PLAN line 329 |
| Append `MintCardActionBar(expanded: true, ...)` with the 3 verb intents (explain / simulate / reassure) | same | PLAN line 329 + cap_du_jour_banner.dart W7 pattern |
| Add `Key('mint_card_action_bar')` on the action bar (Maestro reachability) | same | mirror cap_du_jour_banner.dart:66 |
| Build `_buildCardContext(BuildContext)` helper returning `SerializedCardContext(cardId: 'confidence_score', cardType: 'confidence_axis', computedFacts: 4-axis breakdown, lifeEvent: 'general', canton/archetype from CoachProfileProvider)` | same | PLAN line 329 + Phase 96 D-12 frozen+forbid backend mirror |
| Guard `CoachProfileProvider` lookup with try/catch so 8 legacy widget tests keep working without provider scaffolding (Karpathy #3 surgical) | same | Deviation Rule 1 (legacy-test backward-compat) |
| Add 6 widget tests in new file | `apps/mobile/test/widgets/confidence_score_card_actionbar_test.dart` (new) | PLAN line 331 + RESEARCH §E.2 row 1 |

**No new ARB keys** were added. The chip text comes from the existing generic verbs (`verbExplique` / `verbSimule` / `verbRassure` at `app_fr.arb` lines 12146-12157) just like `cap_du_jour_banner.dart`. The card-specific phrasing (« Explique-moi ce score de confiance », « Rassure-moi sur les axes encore manquants » from PHASE97_AUJOURDHUI_CARD_INVENTORY row 3) is conveyed via `SerializedCardContext.cardType='confidence_axis'` + the `intent` enum dispatched to MintChatOverlay — the chip-label surface intentionally stays generic per the cap_du_jour reference contract. **VOICE-14 ARB-meta level annotation N/A** : no new ARB keys → no lint scope hit.

**No screens were modified.** The existing call site (`apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:142`) does not pass `onSimulate`, so the production fallback no-op kicks in. Wiring the production Explorer deep-link is a W3 follow-on (the test surface validates the chip → callback contract ; the parent screen owns navigation in production).

---

## Deterministic evidence

### G3 — flutter analyze exit 0

```
Evidence : cd apps/mobile && flutter analyze lib/widgets/home/confidence_score_card.dart test/widgets/confidence_score_card_actionbar_test.dart
Output   : "No issues found! (ran in 1.6s)"
Exit     : 0
```

### G4 — flutter test exit 0 (new test + legacy regression)

```
Evidence : cd apps/mobile && flutter test test/widgets/home/confidence_score_card_test.dart test/widgets/confidence_score_card_actionbar_test.dart
Output   : "00:00 +14: All tests passed!"
Tests    : 14 / 14 PASS
  - 8 / 8 legacy tests in confidence_score_card_test.dart (no regression)
  - 6 / 6 new tests in confidence_score_card_actionbar_test.dart :
    1. renders root Key(card_confidence_score)
    2. card root carries Semantics(identifier: card_confidence_score)
    3. MintCardActionBar is a descendant of ConfidenceScoreCard
    4. action bar exposes Key(mint_card_action_bar)
    5. renders 3 verb labels (Explique-moi, Simule, Rassure-moi)
    6. tapping « Simule » fires the onSimulate callback
Exit     : 0
```

### G5 — accent_lint_fr.py exit 0

```
Evidence : python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/widgets/home/confidence_score_card.dart
Output   : (silent)
Exit     : 0
```

### Git diff stat

```
apps/mobile/lib/widgets/home/confidence_score_card.dart    | 297 ++++++++++++++-------
1 file changed, 201 insertions(+), 96 deletions(-)
```
+ 1 new test file (`confidence_score_card_actionbar_test.dart`, ~155 lines).

---

## 0-Trust posture

| Claim | Status | Evidence type |
|---|---|---|
| `flutter analyze` exit 0 on touched files | **PROVEN** | command exit 0 cited above |
| `flutter test` exit 0 on new + legacy test files | **PROVEN** | command exit 0 cited above |
| `Semantics(identifier:)` carries the right value at the right node | **PROVEN** | `tester.getSemantics(...).identifier == 'card_confidence_score'` (test 2 above) |
| Code lives on the feature branch | **PROVEN** | `git diff --stat` cited above |
| **G3 dev CI green** | **PENDING** | PR-checks job not run yet |
| **G2 device walkthrough by Julien** | **PENDING** | requires merge → staging → TestFlight |
| **G1 Maestro sim flow** | **DEFERRED to W3-T4-stripped** | per PLAN §Wave 3 (« semantic-on-P004 », not on P002 in v2.9) |

**Status** : `implemented, not shipped`. PR opened = stage 1 of 4 per CLAUDE.md §9.5. End-to-end sim run + Julien eyes outstanding before any « ready » claim.

---

## Deviations from PLAN

1. **Rule 1 (auto-fix bug)** — Wrapping `_buildCardContext` with `context.read<CoachProfileProvider>()` (PLAN-line 329 prescription) caused all 8 legacy widget tests in `confidence_score_card_test.dart` to throw `ProviderNotFoundException`. Per Karpathy #3 (surgical, don't break adjacent green tests), the lookup was guarded with `try/catch` returning `profile=null` when the provider is absent. Production paths (AppScaffold-rooted) always have the provider in scope ; the fallback is test-only. Net effect : zero existing-test mod, zero behavior change in production.

2. **No new ARB keys added** — PLAN-line 329 says the verbs are « Explique-moi ce score de confiance », « Simule », « Rassure-moi sur les axes encore manquants ». But the cap_du_jour reference uses the **generic** verbExplique/Simule/Rassure chips (the card-specific phrasing is conveyed via `cardType` + `intent` to the chat overlay). Karpathy #2 (simplicity-first) : mirror the reference exactly. The phrasing distinction belongs to the chat overlay narrator, not the chip text — adding card-specific chip labels would create 3 new ARB keys × 6 locales = 18 new strings for zero behavioral difference.

3. **`onSimulate` is an optional constructor parameter** — Same reasoning as cap_du_jour : the simulate verb owns its destination at the parent screen (per CONTEXT D-06 zero-LLM contract). The screen-level integration (Explorer deep-link wiring) lands as a W3 follow-on. This task delivers the chip-→-callback contract under test, not the production screen wiring.

---

## Files touched

```
apps/mobile/lib/widgets/home/confidence_score_card.dart            (modified)
apps/mobile/test/widgets/confidence_score_card_actionbar_test.dart (new)
.planning/phases/97.5-product-completeness-for-ship/W3-T1-RECEIPT.md (new)
```
