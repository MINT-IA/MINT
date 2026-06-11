// ────────────────────────────────────────────────────────────
//  RENTE VS CAPITAL — Coach prefill regression test
//
//  Codex W3 finding 1 (P1) : RenteVsCapitalScreen.initState's
//  postFrameCallback only STORED `_goRouterPrefill` — it never applied
//  it. `_autoFillFromProfile` (one-shot from didChangeDependencies) runs
//  BEFORE the first frame, so its `if (_goRouterPrefill != null)
//  _applyPrefill(...)` always saw null. The `profile == null` early-return
//  also skipped prefill entirely. Before plan 10's fiction-defaults
//  removal this was masked (the screen had hardcoded values); after plan
//  10 a coach-prefilled RvC (RouteSuggestionCard pushes
//  GoRouterState.extra = {'prefill': {...}}) opened EMPTY and computed
//  nothing.
//
//  This test pins the coach → RvC flow with NO profile in the tree :
//   1. The prefilled avoir LPP populates the field (engine has usable
//      input) — the screen is not empty.
//   2. The explicit empty-state invitation is NOT shown (a usable input
//      exists, so a projection is computed).
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';

/// Wraps the screen behind a GoRouter that pushes `/rente-vs-capital` with
/// the coach prefill envelope as `extra` — the exact shape
/// RouteSuggestionCard pushes (`{'prefill': {...}}`).
Widget _wrapWithPrefill(
  CoachProfileProvider provider,
  Map<String, dynamic> prefill,
) {
  final router = GoRouter(
    initialLocation: '/rente-vs-capital',
    routes: [
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const RenteVsCapitalScreen(),
      ),
    ],
  );
  // Seed the initial route's extra via redirect-free initialExtra.
  router.go('/rente-vs-capital', extra: {'prefill': prefill});

  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
    ),
  );
}

/// Collect the current text of every editable [TextField] on screen.
List<String> _allFieldTexts(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((tf) => tf.controller?.text ?? '')
      .toList();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Codex-W3-1: coach prefill with NO profile populates the avoir LPP '
    'field (screen is not empty)',
    (tester) async {
      final provider = CoachProfileProvider(); // profile == null

      await tester.pumpWidget(_wrapWithPrefill(provider, {
        'avoirLpp': 240000,
        'salaireBrut': 8000,
        'ageRetraite': 65,
      }));
      // Let the postFrameCallback + prefill application + debounce settle.
      await tester.pump(const Duration(milliseconds: 600));

      final fieldTexts = _allFieldTexts(tester);
      expect(fieldTexts, contains('240000'),
          reason: 'coach-prefilled avoir LPP must populate the field even '
              'when no CoachProfile exists in the tree');
    },
  );

  testWidgets(
    'Codex-W3-1: coach prefill with NO profile → no empty-state invitation '
    '(a projection is computed)',
    (tester) async {
      final provider = CoachProfileProvider(); // profile == null

      await tester.pumpWidget(_wrapWithPrefill(provider, {
        'avoirLpp': 240000,
        'salaireBrut': 8000,
        'ageRetraite': 65,
      }));
      await tester.pump(const Duration(milliseconds: 600));

      final ctx = tester.element(find.byType(RenteVsCapitalScreen));
      final emptyCopy = S.of(ctx)!.renteVsCapitalEmptyState;
      expect(find.text(emptyCopy), findsNothing,
          reason: 'with a coach-prefilled usable input the screen must NOT '
              'show the empty-state — it must compute a projection');
    },
  );
}
