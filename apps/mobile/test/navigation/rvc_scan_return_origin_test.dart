import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rvcOrigin = '/rente-vs-capital';

final class _StaticProfileProvider extends CoachProfileProvider {
  _StaticProfileProvider(this._profile);

  final CoachProfile _profile;

  @override
  CoachProfile? get profile => _profile;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
  });

  group('G1-RETURN-01 RVC indirect LPP scan chain', () {
    testWidgets('real IndicatifBanner CTA carries RVC into the LPP DataBlock',
        (tester) async {
      await _pumpRvcRouter(tester);

      await _tapIndicatifCta(tester);

      _expectLppCollector(tester);
    });

    testWidgets('real LPP CTA carries an opaque RVC scanReturnId into scan',
        (tester) async {
      await _pumpRvcRouter(tester);
      await _tapIndicatifCta(tester);
      _expectLppCollector(tester);

      final lppCta = find.descendant(
        of: find.byType(DataBlockEnrichmentScreen),
        matching: find.byType(FilledButton),
      );
      expect(lppCta, findsOneWidget);
      await tester.tap(lppCta);
      await _pumpFrames(tester);

      final scan = find.byType(DocumentScanScreen);
      expect(scan, findsOneWidget);
      final uri = GoRouterState.of(tester.element(scan)).uri;
      expect(uri.path, '/scan');
      expect(uri.queryParameters.keys, const <String>['scanReturnId']);
      expect(_isCanonicalUuidV4(uri.queryParameters['scanReturnId']), isTrue);
      expect(tester.widget<DocumentScanScreen>(scan).returnUri, isNull);
      expect(tester.widget<DocumentScanScreen>(scan).scanContextId, isNull);
    });

    testWidgets('cancel from the live LPP collector returns to RVC',
        (tester) async {
      await _pumpRvcRouter(tester);
      await _tapIndicatifCta(tester);
      _expectLppCollector(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await _pumpFrames(tester);

      _expectRvcOrigin(tester);
    });

    testWidgets('scan cancel resolves the opaque token back to RVC',
        (tester) async {
      await _pumpRvcRouter(tester);
      await _tapIndicatifCta(tester);
      _expectLppCollector(tester);

      final lppCta = find.descendant(
        of: find.byType(DataBlockEnrichmentScreen),
        matching: find.byType(FilledButton),
      );
      expect(lppCta, findsOneWidget);
      await tester.tap(lppCta);
      await _pumpFrames(tester);

      final scan = find.byType(DocumentScanScreen);
      expect(scan, findsOneWidget);
      final back = find.descendant(
        of: scan,
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(back, findsOneWidget);
      await tester.tap(back);
      await _pumpFrames(tester);

      _expectRvcOrigin(tester);
    });
  });

  group('G1-RETURN-01 RVC scan security boundary', () {
    testWidgets('unknown scanReturnId stays fail-closed', (tester) async {
      final sessions = ScanSessionProvider();
      addTearDown(sessions.dispose);

      await tester.pumpWidget(_scanBoundaryHarness(
        sessions,
        Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': '11111111-1111-4111-8111-111111111111',
          },
        ),
      ));
      await tester.pump();

      expect(find.byType(DocumentScanScreen), findsNothing);
      expect(
        find.byKey(const Key('scan_review_recovery_cta')),
        findsOneWidget,
      );
    });

    testWidgets('hostile generic return stays fail-closed', (tester) async {
      final sessions = ScanSessionProvider();
      addTearDown(sessions.dispose);

      for (final uri in <Uri>[
        Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': 'not-a-uuid',
          },
        ),
        Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': '11111111-1111-4111-8111-111111111111',
            'returnUri': _rvcOrigin,
          },
        ),
        Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'ScanReturnId': '11111111-1111-4111-8111-111111111111',
          },
        ),
        Uri.parse(
          '/scan?scan%52eturnId=11111111-1111-4111-8111-111111111111',
        ),
        Uri.parse(
          '/scan?scanReturnId=11111111-1111-4111-8111-111111111111'
          '&scanReturnId=22222222-2222-4222-8222-222222222222',
        ),
        Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': '11111111-1111-4111-8111-111111111111',
            'access_token': 'synthetic-secret',
          },
        ),
      ]) {
        await tester.pumpWidget(_scanBoundaryHarness(sessions, uri));
        await tester.pump();
        expect(find.byType(DocumentScanScreen), findsNothing);
        expect(
          find.byKey(const Key('scan_review_recovery_cta')),
          findsOneWidget,
        );
      }
    });

    test('review and impact add opaque ids beside the pillar3a branch', () {
      final source = File('lib/app.dart').readAsStringSync();
      final reviewStart = source.indexOf("path: '/scan/review'");
      final impactStart = source.indexOf("path: '/scan/impact'", reviewStart);
      final nextRoute = source.indexOf('ScopedGoRoute(', impactStart + 1);
      expect(reviewStart, greaterThanOrEqualTo(0));
      expect(impactStart, greaterThan(reviewStart));

      final reviewBlock = source.substring(reviewStart, impactStart);
      final impactBlock = source.substring(
        impactStart,
        nextRoute == -1 ? source.length : nextRoute,
      );
      for (final block in <String>[reviewBlock, impactBlock]) {
        expect(block, contains("queryParameters['scanSessionId']"));
        expect(block, contains("queryParameters['scanReturnId']"));
      }
    });

    testWidgets('pillar3a keeps its exact two-key opaque intent contract',
        (tester) async {
      final sessions = ScanSessionProvider();
      addTearDown(sessions.dispose);
      final scanContextId = sessions.retainPillar3aBeneficiaryScanIntent(
        kind: Pillar3aBeneficiaryScanIntentKind.insertion,
        returnUri: '/retraite',
      );

      await tester.pumpWidget(_scanBoundaryHarness(
        sessions,
        Uri(
          path: '/scan',
          queryParameters: <String, String>{
            'scanContextId': scanContextId,
            'returnUri': '/retraite',
          },
        ),
      ));
      await tester.pump();
      expect(find.byType(DocumentScanScreen), findsOneWidget);

      await tester.pumpWidget(_scanBoundaryHarness(
        sessions,
        Uri(
          path: '/scan',
          queryParameters: <String, String>{
            'scanContextId': scanContextId,
            'returnUri': '/retraite',
            'flow': 'rvc',
          },
        ),
      ));
      await tester.pump();
      expect(find.byType(DocumentScanScreen), findsNothing);
      expect(
        find.byKey(const Key('scan_review_recovery_cta')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpRvcRouter(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final profileProvider = _StaticProfileProvider(_rvcProfile());
  final sessions = ScanSessionProvider();
  final router = GoRouter(
    initialLocation: _rvcOrigin,
    routes: <RouteBase>[
      GoRoute(
        path: _rvcOrigin,
        builder: (_, __) => const RenteVsCapitalScreen(),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => DataBlockEnrichmentScreen(
          blockType: state.pathParameters['type']!,
          initialInputKey: state.uri.queryParameters['inputKey'],
          returnTarget: parseDataBlockReturnTarget(
            state.uri.queryParameters['returnUri'],
          ),
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, state) => testOnlyBuildScanRoute(state.uri),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('wrong fallback')),
      ),
    ],
  );
  addTearDown(profileProvider.dispose);
  addTearDown(sessions.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: profileProvider,
        ),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) => DocumentProvider(),
        ),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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
  await _pumpFrames(tester, frames: 30);
}

Widget _scanBoundaryHarness(ScanSessionProvider sessions, Uri uri) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: _StaticProfileProvider(_rvcProfile()),
      ),
      ChangeNotifierProvider<DocumentProvider>(
        create: (_) => DocumentProvider(),
      ),
      ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: testOnlyBuildScanRoute(uri),
    ),
  );
}

CoachProfile _rvcProfile() => CoachProfile(
      birthYear: 1976,
      canton: 'VD',
      salaireBrutMensuel: 9000,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 350000,
        tauxConversion: 0.06,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2041),
        label: 'Retraite',
      ),
    );

Future<void> _tapIndicatifCta(WidgetTester tester) async {
  final banner = find.byType(IndicatifBanner);
  expect(banner, findsOneWidget);
  final cta = find.descendant(of: banner, matching: find.byType(TextButton));
  expect(cta, findsOneWidget);
  await tester.ensureVisible(cta);
  await tester.tap(cta);
  await _pumpFrames(tester);
}

void _expectLppCollector(WidgetTester tester) {
  final collector = find.byType(DataBlockEnrichmentScreen);
  expect(collector, findsOneWidget);
  final uri = GoRouterState.of(tester.element(collector)).uri;
  expect(uri.path, '/data-block/lpp');
  expect(uri.queryParameters, const <String, String>{
    'returnUri': _rvcOrigin,
  });
}

void _expectRvcOrigin(WidgetTester tester) {
  final origin = find.byType(RenteVsCapitalScreen);
  expect(origin, findsOneWidget);
  expect(GoRouterState.of(tester.element(origin)).uri.toString(), _rvcOrigin);
}

bool _isCanonicalUuidV4(String? value) =>
    value != null &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 12,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
