import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;

Widget _wrapRecovery(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => child),
      GoRoute(
        path: '/scan',
        builder: (_, __) => const Scaffold(body: Text('scan destination')),
      ),
      GoRoute(
        path: '/documents',
        builder: (_, __) => const Scaffold(body: Text('documents destination')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home destination')),
      ),
    ],
  );

  return MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  group('scan degraded route recovery', () {
    for (final routeCase in const [
      (
        route: '/scan/review',
        ctaKey: Key('scan_review_recovery_cta'),
        ctaIdentifier: 'scan_review_recovery_cta',
        destination: 'scan destination',
      ),
      (
        route: '/scan/impact',
        ctaKey: Key('scan_impact_recovery_cta'),
        ctaIdentifier: 'scan_impact_recovery_cta',
        destination: 'home destination',
      ),
    ]) {
      testWidgets('${routeCase.route} without payload is recoverable',
          (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_wrapRecovery(
            testOnlyBuildScanRecoveryScaffold(routeCase.route),
          ));
          await tester.pumpAndSettle();

          expect(find.text('Document non disponible'), findsNothing);
          expect(find.byType(AppBar), findsOneWidget);
          expect(find.byType(BackButton), findsWidgets);
          expect(find.byKey(routeCase.ctaKey), findsOneWidget);
          expect(
            find.bySemanticsIdentifier(routeCase.ctaIdentifier),
            findsOneWidget,
          );

          await tester.tap(find.byKey(routeCase.ctaKey));
          await tester.pumpAndSettle();
          expect(find.text(routeCase.destination), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
  });
}
