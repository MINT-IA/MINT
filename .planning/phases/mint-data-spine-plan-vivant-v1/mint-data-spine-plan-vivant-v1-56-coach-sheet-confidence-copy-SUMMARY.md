description: Summary of Plan 56, polishing coach sheet and confidence copy.

# Summary 56 - Coach Sheet Confidence Copy

## Outcome

The coach quick sheet and confidence breakdown card no longer show ASCII-flattened French on these trust surfaces. The coach profile CTA now uses a more cautious projection message, and the quick sheet is scrollable so it does not overflow in constrained heights.

## Changed Files

- `apps/mobile/lib/widgets/mentor_fab.dart`
  - Replaced `scenario`, `hypotheque`, and `donnees` copy with accented French.
  - Replaced the strong projection claim with `Données complètes, projections plus solides`.
  - Wrapped the bottom-sheet content in `SingleChildScrollView` after the widget test exposed a vertical overflow.
- `apps/mobile/lib/widgets/confidence_breakdown_card.dart`
  - Replaced `Precision des donnees` with `Qualité des données`.
- `apps/mobile/test/widgets/mentor_fab_test.dart`
  - Added regression tests for coach quick-sheet copy and the absence of old ASCII strings.
- `apps/mobile/test/widgets/confidence_breakdown_card_test.dart`
  - Added regression coverage for the data-quality heading.

## Verification

- `flutter test test/widgets/mentor_fab_test.dart test/widgets/confidence_breakdown_card_test.dart` - passed.
- `flutter analyze lib/widgets/mentor_fab.dart lib/widgets/confidence_breakdown_card.dart test/widgets/mentor_fab_test.dart test/widgets/confidence_breakdown_card_test.dart` - no issues found.
- `check_accent_patterns` - clean on the new French strings.
- `check_banned_terms` - clean on the new French strings.
- `python3 tools/checks/wiki_lint.py` - no FAIL-level violations; 139 historical warnings remain.

## Follow-up

Continue the same sweep on the remaining money/coach surfaces where visible text still contains ASCII-flattened French or raw implementation labels.
