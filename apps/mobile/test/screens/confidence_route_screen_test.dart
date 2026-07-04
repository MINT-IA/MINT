import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_route_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';

void main() {
  testWidgets('prefers the context result loader over persisted answers',
      (tester) async {
    var loadResultCalled = false;
    var loadAnswersCalled = false;
    var buildResultCalled = false;

    await tester.pumpWidget(
      _wrap(
        ConfidenceRouteScreen(
          loadResult: (context) async {
            loadResultCalled = true;
            return _result;
          },
          loadAnswers: () async {
            loadAnswersCalled = true;
            return _answers;
          },
          buildResult: (_) {
            buildResultCalled = true;
            return _manual3aPromptResult;
          },
          timeout: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadResultCalled, isTrue);
    expect(loadAnswersCalled, isFalse);
    expect(buildResultCalled, isFalse);
    expect(find.byType(ConfidenceDashboardScreen), findsOneWidget);
  });

  testWidgets('loads confidence from persisted answers without route extra',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ConfidenceRouteScreen(
          loadAnswers: () async => _answers,
          buildResult: (_) => _result,
          timeout: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConfidenceDashboardScreen), findsOneWidget);
    final context = tester.element(find.byType(ConfidenceRouteScreen));
    expect(find.text(S.of(context)!.confidenceDashboardTitle), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier == 'confidence_score_gauge',
      ),
      findsOneWidget,
    );
  });

  testWidgets('times out to retryable error instead of a permanent spinner',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ConfidenceRouteScreen(
          loadAnswers: () => Completer<Map<String, dynamic>>().future,
          buildResult: (_) => _result,
          timeout: const Duration(milliseconds: 1),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    final context = tester.element(find.byType(ConfidenceRouteScreen));
    expect(find.text(S.of(context)!.confidenceLoadError), findsOneWidget);
    expect(find.text(S.of(context)!.confidenceLoadErrorRetry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error back button falls back to home', (tester) async {
    final router = GoRouter(
      initialLocation: '/confidence',
      routes: [
        GoRoute(
          path: '/confidence',
          builder: (_, __) => ConfidenceRouteScreen(
            loadAnswers: () => Completer<Map<String, dynamic>>().future,
            buildResult: (_) => _result,
            timeout: const Duration(milliseconds: 1),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home destination')),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('home destination'), findsOneWidget);
  });

  testWidgets('document prompt opens scan with the matching document type',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/confidence',
      routes: [
        GoRoute(
          path: '/confidence',
          builder: (_, __) => const ConfidenceDashboardScreen(
            result: _lppPromptResult,
          ),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, state) => Scaffold(
            body: Text('scan type ${state.uri.queryParameters['type']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final prompt = find.text('Scanne ton certificat LPP');
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('scan type lpp_certificate'), findsOneWidget);
  });

  testWidgets('manual prompt opens the matching data block', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/confidence',
      routes: [
        GoRoute(
          path: '/confidence',
          builder: (_, __) => const ConfidenceDashboardScreen(
            result: _manual3aPromptResult,
          ),
        ),
        GoRoute(
          path: '/data-block/:type',
          builder: (_, state) => Scaffold(
            body: Text('data block ${state.pathParameters['type']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final prompt = find.text('Renseigne tes soldes 3a');
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('data block 3a'), findsOneWidget);
  });

  testWidgets('open banking prompt opens the banking route', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/confidence',
      routes: [
        GoRoute(
          path: '/confidence',
          builder: (_, __) => const ConfidenceDashboardScreen(
            result: _openBankingPromptResult,
          ),
        ),
        GoRoute(
          path: '/open-banking',
          builder: (_, __) =>
              const Scaffold(body: Text('open banking destination')),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final prompt = find.text('Connecte ton compte bancaire');
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('open banking destination'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: child,
  );
}

Widget _wrapRouter(GoRouter router) {
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

const _answers = <String, dynamic>{
  'q_birth_year': 1990,
  'q_canton': 'VD',
  'q_net_income_period_chf': 6000.0,
};

const _result = ConfidenceResult(
  breakdown: ConfidenceBreakdown(
    completeness: 72,
    accuracy: 68,
    freshness: 80,
    understanding: 55,
  ),
  enrichmentPrompts: [
    EnrichmentPrompt(
      fieldName: 'lpp_total',
      action: 'Importer ton certificat LPP',
      impactPoints: 12,
      method: 'documentScan',
      priority: 1,
    ),
  ],
  featureGates: [
    FeatureGate(
      gateName: 'Projection retraite',
      unlocked: true,
      minConfidence: 60,
    ),
  ],
  disclaimer: 'Score indicatif.',
  sources: ['test'],
);

const _lppPromptResult = ConfidenceResult(
  breakdown: ConfidenceBreakdown(
    completeness: 40,
    accuracy: 45,
    freshness: 70,
    understanding: 50,
  ),
  enrichmentPrompts: [
    EnrichmentPrompt(
      fieldName: 'lpp_obligatoire',
      action: 'Scanne ton certificat LPP',
      impactPoints: 27,
      method: 'documentScan',
      priority: 1,
    ),
  ],
  featureGates: [],
  disclaimer: 'Score indicatif.',
  sources: ['test'],
);

const _manual3aPromptResult = ConfidenceResult(
  breakdown: ConfidenceBreakdown(
    completeness: 40,
    accuracy: 45,
    freshness: 70,
    understanding: 50,
  ),
  enrichmentPrompts: [
    EnrichmentPrompt(
      fieldName: 'pillar_3a_balance',
      action: 'Renseigne tes soldes 3a',
      impactPoints: 10,
      method: 'manualEntry',
      priority: 1,
    ),
  ],
  featureGates: [],
  disclaimer: 'Score indicatif.',
  sources: ['test'],
);

const _openBankingPromptResult = ConfidenceResult(
  breakdown: ConfidenceBreakdown(
    completeness: 40,
    accuracy: 45,
    freshness: 70,
    understanding: 50,
  ),
  enrichmentPrompts: [
    EnrichmentPrompt(
      fieldName: 'open_banking',
      action: 'Connecte ton compte bancaire',
      impactPoints: 22,
      method: 'openBanking',
      priority: 1,
    ),
  ],
  featureGates: [],
  disclaimer: 'Score indicatif.',
  sources: ['test'],
);
