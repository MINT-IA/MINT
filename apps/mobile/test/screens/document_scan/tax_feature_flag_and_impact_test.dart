import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

Widget _withProviders({
  required Widget child,
  ScanSessionProvider? scanSessions,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => CoachProfileProvider(),
      ),
      ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
      ChangeNotifierProvider<ScanSessionProvider>.value(
        value: scanSessions ?? ScanSessionProvider(),
      ),
    ],
    child: child,
  );
}

MaterialApp _localizedApp(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  test('tax acquisition activation requires both independent kill switches',
      () {
    for (final flags in const [
      (typed: false, document: false, expected: false),
      (typed: true, document: false, expected: false),
      (typed: false, document: true, expected: false),
      (typed: true, document: true, expected: true),
    ]) {
      FeatureFlags.typedTaxProfile = flags.typed;
      FeatureFlags.documentTaxAssessmentEnabled = flags.document;
      expect(
        FeatureFlags.taxAssessmentIngestionEnabled,
        flags.expected,
        reason: 'typed=${flags.typed}, document=${flags.document}',
      );
    }
  });

  testWidgets(
      'tax kill switch rejects a tax deep link and exposes no selector or acquisition CTA',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FeatureFlags.typedTaxProfile = true;

    await tester.pumpWidget(
      _withProviders(
        child: _localizedApp(
          const DocumentScanScreen(initialType: DocumentType.taxDeclaration),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('document_scan_tax_type_selector')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('document_scan_tax_local_text_cta')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('document_scan_tax_example_cta')),
      findsNothing,
    );
  });

  testWidgets('enabled tax flow reaches its typed local review route',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final sessions = ScanSessionProvider();
    String? routedSessionId;
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/scan',
          builder: (_, __) => const DocumentScanScreen(
            initialType: DocumentType.taxDeclaration,
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (_, state) {
            routedSessionId = state.uri.queryParameters['scanSessionId'];
            return const Scaffold(
              body: Text(
                'typed local tax review reached',
                key: Key('typed_local_tax_review_reached'),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _withProviders(
        scanSessions: sessions,
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
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('document_scan_tax_type_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('document_scan_tax_local_text_cta')),
      findsOneWidget,
    );
    final example = find.byKey(const Key('document_scan_tax_example_cta'));
    expect(example, findsOneWidget);
    await tester.ensureVisible(example);
    await tester.tap(example);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('typed_local_tax_review_reached')), findsOne);
    expect(routedSessionId, isNotNull);
    expect(sessions.byId(routedSessionId)?.taxCandidate, isNotNull);
  });

  testWidgets('canonical tax ratios render as percentages, never CHF zero',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    const result = ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [
        ExtractedField(
          fieldName: 'explicitMarginalIncomeTaxRate',
          label: 'Taux marginal explicite (%)',
          value: 0.325,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'explicitAverageIncomeTaxRate',
          label: 'Taux moyen explicite (%)',
          value: 0.223,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
      ],
      overallConfidence: 1,
      confidenceDelta: 0,
      warnings: [],
      disclaimer: '',
      sources: [],
    );
    final sessions = ScanSessionProvider();
    final id = sessions.retainExtraction(result);
    expect(
      sessions.retainImpact(
        id,
        extraction: result,
        previousConfidence: 0,
      ),
      isTrue,
    );

    await tester.pumpWidget(
      _withProviders(
        scanSessions: sessions,
        child: _localizedApp(
          DocumentImpactScreen(
            scanSessionId: id,
            result: result,
            previousConfidence: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('32.5%'), findsOneWidget);
    expect(find.text('22.3%'), findsOneWidget);
    expect(find.text('CHF 0'), findsNothing);
  });
}
