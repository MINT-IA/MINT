import 'dart:async';
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
const _unknownScanReturnId = '11111111-1111-4111-8111-111111111111';

enum _ExitGesture { cta, appBarBack, systemBack }

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

final class _RvcHarness {
  const _RvcHarness({required this.sessions, required this.router});

  final ScanSessionProvider sessions;
  final GoRouter router;
}

final class _DataBlockAdvanceSpy extends ScanSessionProvider {
  int advanceCalls = 0;
  String? advancedId;
  DataBlockScanReturnLifecycle? advancedFrom;
  DataBlockScanReturnLifecycle? advancedTo;
  DataBlockScanReturnLifecycle? lifecycleAfterAdvance;

  @override
  bool advanceDataBlockScanReturnIntent(
    String id, {
    required DataBlockScanReturnLifecycle from,
    required DataBlockScanReturnLifecycle to,
  }) {
    advanceCalls += 1;
    advancedId = id;
    advancedFrom = from;
    advancedTo = to;
    final advanced = super.advanceDataBlockScanReturnIntent(
      id,
      from: from,
      to: to,
    );
    lifecycleAfterAdvance = dataBlockScanReturnIntentById(id)?.lifecycle;
    return advanced;
  }
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

    testWidgets('opaque RVC token locks the live scanner to LPP only',
        (tester) async {
      final harness = await _pumpRvcRouter(tester);
      final scanReturnId = await _openRvcScan(tester);

      final selectors = find.byType(ChoiceChip);
      expect(selectors.evaluate().length, lessThanOrEqualTo(1));
      if (selectors.evaluate().isNotEmpty) {
        expect(
          find.byKey(const Key('document_scan_lpp_type_selector')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const Key('document_scan_tax_type_selector')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('document_scan_lpp_plan_type_selector')),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('document_scan_pillar3a_beneficiary_clause_type_selector'),
        ),
        findsNothing,
      );
      expect(
        harness.sessions.dataBlockScanReturnIntentById(scanReturnId)?.lifecycle,
        DataBlockScanReturnLifecycle.created,
      );
    });

    for (final action in <({String name, Key key})>[
      (
        name: 'camera',
        key: const Key('document_scan_capture_cta'),
      ),
      (
        name: 'gallery',
        key: const Key('document_scan_gallery_cta'),
      ),
      (
        name: 'example',
        key: const Key('document_scan_lpp_example_cta'),
      ),
    ]) {
      testWidgets(
          '${action.name} stays created through self gate then advances at acquisition',
          (tester) async {
        final advanceSpy = _DataBlockAdvanceSpy();
        final consentGate = Completer<bool>();
        var consentRequested = false;
        var pickerCalls = 0;
        DataBlockScanReturnLifecycle? lifecycleAtPicker;
        late _RvcHarness harness;
        late String scanReturnId;
        harness = await _pumpRvcRouter(
          tester,
          sessions: advanceSpy,
          requireConsent: (_, __) {
            consentRequested = true;
            return consentGate.future;
          },
          pickFile: () async {
            pickerCalls += 1;
            lifecycleAtPicker = harness.sessions
                .dataBlockScanReturnIntentById(scanReturnId)
                ?.lifecycle;
            return null;
          },
          navigateToReview: (_, __) async {},
        );
        scanReturnId = await _openRvcScan(tester);
        expect(
          harness.sessions
              .dataBlockScanReturnIntentById(scanReturnId)
              ?.lifecycle,
          DataBlockScanReturnLifecycle.created,
        );
        expect(advanceSpy.advanceCalls, 0);

        final cta = find.byKey(action.key);
        expect(cta, findsOneWidget);
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pump();

        expect(
          find.byKey(const Key('lpp_acquisition_self_gate')),
          findsOneWidget,
        );
        expect(
          harness.sessions
              .dataBlockScanReturnIntentById(scanReturnId)
              ?.lifecycle,
          DataBlockScanReturnLifecycle.created,
        );
        expect(advanceSpy.advanceCalls, 0);
        await tester.tap(find.byKey(const Key('lpp_acquisition_cancel')));
        await tester.pump();
        expect(
          harness.sessions
              .dataBlockScanReturnIntentById(scanReturnId)
              ?.lifecycle,
          DataBlockScanReturnLifecycle.created,
        );
        expect(advanceSpy.advanceCalls, 0);

        await tester.tap(cta);
        await tester.pump();
        expect(
          harness.sessions
              .dataBlockScanReturnIntentById(scanReturnId)
              ?.lifecycle,
          DataBlockScanReturnLifecycle.created,
        );
        await tester.tap(
          find.byKey(const Key('lpp_acquisition_self_continue')),
        );
        await tester.pump();

        if (action.name != 'example') {
          expect(consentRequested, isTrue);
          expect(
            harness.sessions
                .dataBlockScanReturnIntentById(scanReturnId)
                ?.lifecycle,
            DataBlockScanReturnLifecycle.created,
          );
          expect(advanceSpy.advanceCalls, 0);
          consentGate.complete(true);
          await _pumpFrames(tester);
          expect(pickerCalls, 1);
          expect(lifecycleAtPicker, DataBlockScanReturnLifecycle.processing);
        } else {
          await _pumpFrames(tester);
          expect(consentRequested, isFalse);
          expect(pickerCalls, 0);
        }
        expect(advanceSpy.advanceCalls, 1);
        expect(advanceSpy.advancedId, scanReturnId);
        expect(
          advanceSpy.advancedFrom,
          DataBlockScanReturnLifecycle.created,
        );
        expect(
          advanceSpy.advancedTo,
          DataBlockScanReturnLifecycle.processing,
        );
        expect(
          advanceSpy.lifecycleAfterAdvance,
          DataBlockScanReturnLifecycle.processing,
        );
        expect(
          harness.sessions
              .dataBlockScanReturnIntentById(scanReturnId)
              ?.lifecycle,
          action.name == 'example'
              ? DataBlockScanReturnLifecycle.reviewRetained
              : DataBlockScanReturnLifecycle.processing,
        );
      });
    }

    testWidgets(
        'real LPP example retains the opaque pair and opens exact Review URI',
        (tester) async {
      final harness = await _pumpRvcRouter(tester);
      final scanReturnId = await _openRvcScan(tester);

      final example = find.byKey(const Key('document_scan_lpp_example_cta'));
      expect(example, findsOneWidget);
      await tester.ensureVisible(example);
      await tester.tap(example);
      await tester.pump();

      expect(
          find.byKey(const Key('lpp_acquisition_self_gate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lpp_acquisition_self_continue')));
      await _pumpFrames(tester);

      final review = find.byKey(const Key('rvc_scan_review_destination'));
      expect(review, findsOneWidget);
      final reviewUri = GoRouterState.of(tester.element(review)).uri;
      expect(reviewUri.path, '/scan/review');
      final rawKeys = reviewUri.query
          .split('&')
          .map((component) => component.split('=').first)
          .toList(growable: false);
      expect(rawKeys, hasLength(2));
      expect(rawKeys.toSet(), <String>{'scanSessionId', 'scanReturnId'});
      expect(reviewUri.queryParametersAll, hasLength(2));
      expect(
        reviewUri.queryParametersAll['scanSessionId'],
        hasLength(1),
      );
      expect(
        reviewUri.queryParametersAll['scanReturnId'],
        <String>[scanReturnId],
      );

      final scanSessionId = reviewUri.queryParameters['scanSessionId'];
      expect(scanSessionId, isNotNull);
      final session = harness.sessions.byId(scanSessionId);
      expect(session, isNotNull);
      expect(session!.dataBlockScanReturnIntentId, scanReturnId);
      expect(
        harness.sessions.dataBlockScanReturnIntentById(scanReturnId)?.lifecycle,
        DataBlockScanReturnLifecycle.reviewRetained,
      );
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
          '/scan?scan%2552eturnId=11111111-1111-4111-8111-111111111111',
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

    for (final exit in _ExitGesture.values) {
      testWidgets(
          'canonical unknown process-loss ${exit.name} recovers to literal RVC',
          (tester) async {
        final sessions = ScanSessionProvider();
        addTearDown(sessions.dispose);
        final harness = await _pumpScanRouter(
          tester,
          sessions,
          Uri(
            path: '/scan',
            queryParameters: const <String, String>{
              'scanReturnId': _unknownScanReturnId,
            },
          ),
        );

        _expectScanRecovery();
        await _exitRecovery(tester, exit);

        _expectLiteralRoute(harness.router, _rvcOrigin);
      });
    }

    for (final hostileCase in <({String name, Uri uri})>[
      (
        name: 'malformed identity',
        uri: Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': 'not-a-uuid',
          },
        ),
      ),
      (
        name: 'case-altered key',
        uri: Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'ScanReturnId': _unknownScanReturnId,
          },
        ),
      ),
      (
        name: 'double-encoded key',
        uri: Uri.parse(
          '/scan?scan%2552eturnId=$_unknownScanReturnId',
        ),
      ),
      (
        name: 'double identity',
        uri: Uri.parse(
          '/scan?scanReturnId=$_unknownScanReturnId'
          '&scanReturnId=22222222-2222-4222-8222-222222222222',
        ),
      ),
      (
        name: 'nested return target',
        uri: Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': _unknownScanReturnId,
            'returnUri': _rvcOrigin,
          },
        ),
      ),
      (
        name: 'sensitive extra query',
        uri: Uri(
          path: '/scan',
          queryParameters: const <String, String>{
            'scanReturnId': _unknownScanReturnId,
            'access_token': 'synthetic-secret',
          },
        ),
      ),
    ]) {
      for (final exit in _ExitGesture.values) {
        testWidgets(
            '${hostileCase.name} ${exit.name} terminates at literal home',
            (tester) async {
          final sessions = ScanSessionProvider();
          addTearDown(sessions.dispose);
          final harness = await _pumpScanRouter(
            tester,
            sessions,
            hostileCase.uri,
          );

          _expectScanRecovery();
          await _exitRecovery(tester, exit);

          _expectLiteralRoute(harness.router, '/home');
        });
      }
    }

    for (final altered in <({String name, bool sensitive})>[
      (name: 'extra field', sensitive: false),
      (name: 'sensitive field', sensitive: true),
    ]) {
      for (final exit in _ExitGesture.values) {
        testWidgets(
            'known ${altered.name} captures target discards and ${exit.name} returns RVC',
            (tester) async {
          final sessions = ScanSessionProvider();
          addTearDown(sessions.dispose);
          final scanReturnId = _retainRvcIntent(sessions);
          final harness = await _pumpScanRouter(
            tester,
            sessions,
            Uri(
              path: '/scan',
              queryParameters: <String, String>{
                'scanReturnId': scanReturnId,
                if (altered.sensitive)
                  'access_token': 'synthetic-secret'
                else
                  'flow': 'altered',
              },
            ),
          );

          _expectScanRecovery();
          expect(
            sessions.dataBlockScanReturnIntentById(scanReturnId),
            isNull,
          );
          await _exitRecovery(tester, exit);
          _expectLiteralRoute(harness.router, _rvcOrigin);
        });
      }
    }

    for (final exit in <_ExitGesture>[
      _ExitGesture.appBarBack,
      _ExitGesture.systemBack,
    ]) {
      testWidgets(
          'live scan ${exit.name} returns to RVC and discards the token',
          (tester) async {
        final harness = await _pumpRvcRouter(tester);
        final scanReturnId = await _openRvcScan(tester);

        await _exitLiveScan(tester, exit);

        _expectRvcOrigin(tester);
        expect(
          harness.sessions.dataBlockScanReturnIntentById(scanReturnId),
          isNull,
        );
      });
    }

    for (final exit in _ExitGesture.values) {
      testWidgets(
          'mixed Pillar3a and RVC purges both and ${exit.name} returns RVC',
          (tester) async {
        final sessions = ScanSessionProvider();
        addTearDown(sessions.dispose);
        final scanReturnId = _retainRvcIntent(sessions);
        final scanContextId = sessions.retainPillar3aBeneficiaryScanIntent(
          kind: Pillar3aBeneficiaryScanIntentKind.insertion,
          returnUri: '/retraite',
        );
        final harness = await _pumpScanRouter(
          tester,
          sessions,
          Uri(
            path: '/scan',
            queryParameters: <String, String>{
              'scanReturnId': scanReturnId,
              'scanContextId': scanContextId,
              'returnUri': '/retraite',
            },
          ),
        );

        expect(find.byType(DocumentScanScreen), findsNothing);
        _expectScanRecovery();
        expect(sessions.dataBlockScanReturnIntentById(scanReturnId), isNull);
        expect(
          sessions.pillar3aBeneficiaryScanIntentById(
            scanContextId,
            returnUri: '/retraite',
          ),
          isNull,
        );
        await _exitRecovery(tester, exit);
        _expectLiteralRoute(harness.router, _rvcOrigin);
      });
    }

    testWidgets('RVC LPP token remains usable with the Pillar3a flag off',
        (tester) async {
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;

      final harness = await _pumpRvcRouter(tester);
      final scanReturnId = await _openRvcScan(tester);

      expect(find.byType(DocumentScanScreen), findsOneWidget);
      expect(
        harness.sessions.dataBlockScanReturnIntentById(scanReturnId)?.kind,
        DataBlockScanReturnKind.rvcLpp,
      );
      expect(
        harness.sessions.dataBlockScanReturnIntentById(scanReturnId)?.lifecycle,
        DataBlockScanReturnLifecycle.created,
      );
    });

    testWidgets('LPP composite flag drop discards mid-flight token to RVC',
        (tester) async {
      final harness = await _pumpRvcRouter(tester);
      final scanReturnId = await _openRvcScan(tester);

      FeatureFlags.documentLppEvidenceEnabled = false;
      harness.router.refresh();
      await _pumpFrames(tester);

      _expectScanRecovery();
      expect(
        harness.sessions.dataBlockScanReturnIntentById(scanReturnId),
        isNull,
      );
      await _exitRecovery(tester, _ExitGesture.cta);
      _expectRvcOrigin(tester);
    });

    for (final exit in _ExitGesture.values) {
      testWidgets('replayed cancelled URL ${exit.name} recovers to RVC',
          (tester) async {
        final harness = await _pumpRvcRouter(tester);
        final scanReturnId = await _openRvcScan(tester);
        final scan = find.byType(DocumentScanScreen);
        final oldScanUri = GoRouterState.of(tester.element(scan)).uri;
        expect(oldScanUri.path, '/scan');
        expect(oldScanUri.queryParameters, <String, String>{
          'scanReturnId': scanReturnId,
        });

        await _exitLiveScan(tester, _ExitGesture.appBarBack);
        _expectRvcOrigin(tester);
        expect(
          harness.sessions.dataBlockScanReturnIntentById(scanReturnId),
          isNull,
        );

        harness.router.go(oldScanUri.toString());
        await _pumpFrames(tester);
        expect(
          harness.router.routeInformationProvider.value.uri,
          oldScanUri,
        );
        expect(find.byType(DocumentScanScreen), findsNothing);
        _expectScanRecovery();
        await _exitRecovery(tester, exit);
        _expectRvcOrigin(tester);
      });
    }

    testWidgets('FIFO-evicted RVC token recovers to literal RVC',
        (tester) async {
      final sessions = ScanSessionProvider();
      addTearDown(sessions.dispose);
      final ids = <String>[
        for (var index = 0; index < 6; index++) _retainRvcIntent(sessions),
      ];
      expect(sessions.dataBlockScanReturnIntentById(ids.first), isNull);

      final harness = await _pumpScanRouter(
        tester,
        sessions,
        Uri(
          path: '/scan',
          queryParameters: <String, String>{'scanReturnId': ids.first},
        ),
      );

      _expectScanRecovery();
      await _exitRecovery(tester, _ExitGesture.cta);
      _expectLiteralRoute(harness.router, _rvcOrigin);
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

Future<_RvcHarness> _pumpRvcRouter(
  WidgetTester tester, {
  ScanSessionProvider? sessions,
  DocumentScanFilePicker? pickFile,
  DocumentScanConsentRequester? requireConsent,
  DocumentScanReviewNavigator? navigateToReview,
}) async {
  tester.view.physicalSize = const Size(1440, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final profileProvider = _StaticProfileProvider(_rvcProfile());
  final activeSessions = sessions ?? ScanSessionProvider();
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
        builder: (_, state) => testOnlyBuildScanRoute(
          state.uri,
          pickFile: pickFile,
          requireConsent: requireConsent,
          navigateToReview: navigateToReview,
        ),
      ),
      GoRoute(
        path: '/scan/review',
        builder: (_, __) => const Scaffold(
          key: Key('rvc_scan_review_destination'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('wrong fallback')),
      ),
    ],
  );
  addTearDown(profileProvider.dispose);
  addTearDown(activeSessions.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: profileProvider,
        ),
        ChangeNotifierProvider<ScanSessionProvider>.value(
          value: activeSessions,
        ),
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
  return _RvcHarness(sessions: activeSessions, router: router);
}

Future<_RvcHarness> _pumpScanRouter(
  WidgetTester tester,
  ScanSessionProvider sessions,
  Uri initialUri,
) async {
  tester.view.physicalSize = const Size(1440, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final profileProvider = _StaticProfileProvider(_rvcProfile());
  final router = GoRouter(
    initialLocation: initialUri.toString(),
    routes: <RouteBase>[
      GoRoute(
        path: '/scan',
        builder: (_, state) => testOnlyBuildScanRoute(state.uri),
      ),
      GoRoute(
        path: _rvcOrigin,
        builder: (_, __) => const Scaffold(
          key: Key('literal_rvc_destination'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(
          key: Key('literal_home_destination'),
        ),
      ),
    ],
  );
  addTearDown(profileProvider.dispose);
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
  await _pumpFrames(tester);
  return _RvcHarness(sessions: sessions, router: router);
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

String _retainRvcIntent(ScanSessionProvider sessions) =>
    sessions.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: parseDataBlockReturnTarget(_rvcOrigin)!,
    );

Future<String> _openRvcScan(WidgetTester tester) async {
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
  final scanReturnId = uri.queryParameters['scanReturnId'];
  expect(_isCanonicalUuidV4(scanReturnId), isTrue);
  return scanReturnId!;
}

void _expectScanRecovery() {
  expect(find.byType(DocumentScanScreen), findsNothing);
  expect(
    find.byKey(const Key('scan_review_recovery_cta')),
    findsOneWidget,
  );
}

Future<void> _exitRecovery(
  WidgetTester tester,
  _ExitGesture exit,
) async {
  switch (exit) {
    case _ExitGesture.cta:
      await tester.tap(find.byKey(const Key('scan_review_recovery_cta')));
      break;
    case _ExitGesture.appBarBack:
      await tester.tap(find.byType(BackButton));
      break;
    case _ExitGesture.systemBack:
      await tester.binding.handlePopRoute();
      break;
  }
  await _pumpFrames(tester);
}

Future<void> _exitLiveScan(
  WidgetTester tester,
  _ExitGesture exit,
) async {
  switch (exit) {
    case _ExitGesture.appBarBack:
      final scan = find.byType(DocumentScanScreen);
      expect(scan, findsOneWidget);
      final back = find.descendant(
        of: scan,
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(back, findsOneWidget);
      await tester.tap(back);
      break;
    case _ExitGesture.systemBack:
      await tester.binding.handlePopRoute();
      break;
    case _ExitGesture.cta:
      throw StateError('Live scan has no recovery CTA');
  }
  await _pumpFrames(tester);
}

void _expectLiteralRoute(GoRouter router, String route) {
  expect(router.routeInformationProvider.value.uri.toString(), route);
  expect(
    find.byKey(
      Key(route == _rvcOrigin
          ? 'literal_rvc_destination'
          : 'literal_home_destination'),
    ),
    findsOneWidget,
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
