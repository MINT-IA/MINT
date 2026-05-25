description: Summary of Plan 55, localizing patrimoine source and known-data copy across all MINT locales.

# Summary 55 - Patrimoine Localized Source Copy

## Outcome

The Mon Argent patrimoine card no longer exposes raw source codes or ASCII-flattened French in its user-facing accessibility copy. The latest update line now renders localized source labels, for example `Mis à jour le 25 mai · estimé` in French.

## Changed Files

- `apps/mobile/lib/widgets/mon_argent/patrimoine_summary_card.dart`
  - Replaced hardcoded `MaJ ... · estimated` formatting with localized copy.
  - Replaced `donnees` semantics copy with `monArgentPatrimoineKnownDataLabel`.
  - Uses `DateFormat.MMM(l10n.localeName)` for month labels.
- `apps/mobile/lib/l10n/app_*.arb`
  - Added 8 new Mon Argent patrimoine/source keys across fr/en/de/es/it/pt.
- `apps/mobile/lib/l10n/app_localizations*.dart`
  - Regenerated from ARB.
- `apps/mobile/test/widgets/mon_argent_patrimoine_summary_card_test.dart`
  - Added regression coverage for French status/source copy.

## Verification

- `flutter gen-l10n` - completed.
- `flutter test test/widgets/mon_argent_patrimoine_summary_card_test.dart test/widgets/mon_argent_budget_summary_card_test.dart` - passed.
- `flutter test test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart` - passed.
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart lib/widgets/mon_argent/patrimoine_summary_card.dart test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart` - no issues found.
- `validate_arb_parity` - OK, 6812 keys in each of the 6 locales.
- `check_accent_patterns` - clean on the new French strings.
- `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` - built `Runner.app`.
- `MINT_WALKER_ARTIFACTS=.planning/_walker/maestro-evidence-20260525T155754-plan55 MAESTRO_STALL_THRESHOLD=60 MAESTRO_HARD_LIMIT=300 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml` - Maestro returned 0.
- `snapshot_ui` on `mintapp:///mon-argent` showed `100 % des données connues` and `Mis à jour le 25 mai · estimé` in `mon_argent_patrimoine_summary`.

## Follow-up

- Continue the same cleanup rule on remaining central money surfaces: no raw enum/source codes and no ASCII-flattened French in visible or accessibility copy.
