---

## Audit Report — `codex/mint-product-usability-plan-20260712` vs `81a9108e4`

**Scope:** 19 files, 109 insertions / 716 deletions. All within `apps/mobile`.

---

### Summary of changes under review

| Area | Change |
|---|---|
| `simulator_3a_screen.dart` | Null-profile guard: `Center(Text(...))` → `MintEmptyState` with CTA → `/coach/chat` |
| `recommendation_card.dart` | Deleted (dead widget) |
| `simulators/buyback_widget.dart` | Deleted (dead widget) |
| `l10n` (6 locales × ARB + Dart) | `sim3aDebtLockedTitle` / `sim3aDebtStrategyMessage` copy softened (removes explicit "debt" framing, replacing with "financial stability") |
| `legacy_provider_migration_test.dart` | `_namedDebtReaders` shrinks to 1; `_retiredDeadWidgets` set added; new tests for Signal C (emergency-fund) crisis + null-profile routing |
| `safe_mode_gate_test.dart` | Removes `RecommendationCard` / `BuybackWidget` groups (now defunct); keeps SafeModeGate and `buildLifeEventSuggestions` groups |

---

### Findings

#### P0 — None

#### P1 — None

#### P2 (advisory, no gate)

**P2-1 · `lookupSafeModeFlag` silent debt-free default (pre-existing, not touched)**
`safe_mode_gate.dart:17`

```dart
return context.watch<CoachProfileProvider>().profile?.isInDebtCrisis ?? false;
```

When a provider is present but `profile` is `null` (pre-load transient state), this returns `false`, which would briefly expose optimization sections. The screen-level null guard in `Simulator3aScreen` (`hasDebt == null` branch) prevents this for this screen, but any future screen using `lookupSafeModeFlag()` directly would be exposed during the loading window. Not introduced by this diff but worth tracking.

Proof command: `grep -rn 'lookupSafeModeFlag' apps/mobile/lib/`

**P2-2 · `MintEmptyState` receives `subtitle: ''` (cosmetic)**
`simulator_3a_screen.dart:202`

The widget renders an empty `Text('')`. No functional impact, but a noticeable layout gap. Consider passing `l.financialSummaryNoProfileSubtitle` if/when that key exists, or removing the subtitle altogether once one is defined.

---

### Correctness checks

| Claim | Evidence | Result |
|---|---|---|
| `emergencyFundOnly.isInDebtCrisis == true` via Signal C | `epargneLiquide=0`, `depenses.loyer=1500 + assuranceMaladie=400 → totalMensuel=1900`, `monthsLiquidity=0<3` → returns `true` (coach_profile.dart:3377-3378) | ✓ |
| New `sim3aDebtLockedTitle` copy matches test expectations | All 6 ARB + 6 generated `.dart` + abstract `app_localizations.dart` updated consistently; FR value is `'Stabilité financière prioritaire'` matching the test assertion at test line 149 | ✓ |
| Deleted widgets have no live imports | `grep -rn 'recommendation_card\|RecommendationCard\|buyback_widget\|BuybackWidget' apps/mobile/lib/` → zero results outside `gender_gap_screen.dart:_buildRecommendationCard` (private local method, unrelated) | ✓ |
| Null-profile CTA routes correctly | Test wires real `GoRouter` with `/` and `/coach/chat`; `Simulator3aScreen` calls `context.go('/coach/chat')`; test taps CTA and asserts `'coach-chat-destination'` visible | ✓ |
| `_retiredDeadWidgets` files absent | Test asserts `File(path).existsSync() == false` for both paths; confirmed not present in `lib/` | ✓ |
| `PopScope` present in null-profile branch | `simulator_3a_screen.dart:185-206` wraps null scaffold in `PopScope` with `_emitFinalReturn()` | ✓ |
| i18n abstract base updated | `app_localizations.dart` doc comment updated from `'Priorité au désendettement'` → `'Stabilité financière prioritaire'` | ✓ |

---

## Verdict: **PASS**

No P0 or P1 findings. Two pre-existing or cosmetic P2 observations that do not block merge. The dead-widget removal is clean (no dangling imports), Signal C emergency-fund gating is correctly proven end-to-end, and the null-profile diagnostic CTA is fully wired with router-level test coverage.
