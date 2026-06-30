import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

Widget _wrap(GoRouter router) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/onb',
    routes: [
      GoRoute(
        path: '/onb',
        builder: (context, state) => const OnboardingShellScreen(),
      ),
      GoRoute(
        path: '/retraite/rente-vs-capital',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('RvC route sentinel', key: ValueKey('rvc-sentinel')),
          ),
        ),
      ),
    ],
  );
}

Future<GoRouter> _openAxes(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(_wrap(router));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FeatureFlags.enableMint2FirstExperienceEntry = true;
  });

  tearDown(() {
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  test('onboarding Mint 2 signal axes do not call RvC calculators', () {
    final roots = <Directory>[
      Directory('lib/screens/onboarding/mvp_wedge'),
      Directory('lib/models'),
    ];
    final hits = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('ArbitrageEngine.compareRenteVsCapital') ||
              line.contains('ApiService.compareRenteVsCapital') ||
              RegExp(r'(^|[^A-Za-z0-9_])computeRenteVsCapital\(')
                  .hasMatch(line)) {
            hits.add('${entity.path}:${i + 1}: $line');
          }
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason: 'Slice 2C signal axes may save intent, not calculate RvC.',
    );
  });

  testWidgets('housing and fiscal axes stay signal-only after tap',
      (tester) async {
    const axes = [
      (
        key: ValueKey('mint2-axis-logement_signal'),
        label: 'Logement : 2e / 3e pilier',
      ),
      (
        key: ValueKey('mint2-axis-fiscal_signal'),
        label: '3a et rachats : impact fiscal',
      ),
    ];
    for (final axis in axes) {
      await _openAxes(tester);
      final card = find.byKey(axis.key);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('Choisis le sujet que tu veux éclairer d\'abord.'),
          findsOneWidget);
      expect(find.text(axis.label), findsWidgets);
      expect(find.text('Intérêt enregistré'), findsOneWidget);
      expect(find.textContaining('/mois'), findsNothing);
      expect(find.textContaining('CHF'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('signal axis exposes a forward path to the live RvC gate',
      (tester) async {
    final router = await _openAxes(tester);

    await tester.tap(find.text('Logement : 2e / 3e pilier').first);
    await tester.pumpAndSettle();

    final continueLive = find.byKey(const ValueKey('mint2-axis-continue-live'));
    expect(continueLive, findsOneWidget);
    expect(find.text('Intérêt enregistré'), findsOneWidget);

    await tester.tap(continueLive);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/retraite/rente-vs-capital');
    expect(find.byKey(const ValueKey('rvc-sentinel')), findsOneWidget);
    expect(
      find.text('Choisis le sujet que tu veux éclairer d\'abord.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
