import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

const _rvcRoute = '/rente-vs-capital';

final _candidate = LppExtractionAdapter.adapt(
  source: LppAcquisitionSource.localParser,
  sourceOverallConfidence: 0.99,
  sourceDate: DateTime.utc(2026, 6, 30),
  fields: const <ExtractedField>[
    ExtractedField(
      fieldName: 'lpp_total',
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
).candidate!;

final _authorization = LppAcquisitionAuthorization(
  acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
  subject: LppEvidenceOwnerKind.self,
  partnerAttested: false,
  policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
  declaredAt: DateTime.utc(2026, 7, 19, 9),
  documentSha256:
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
);

final _reviewExtraction = ExtractionResult(
  documentType: DocumentType.lppCertificate,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: LppEvidenceFactKey.vestedBenefitsCapitalChf.wireName,
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 27,
  warnings: const <String>[],
  disclaimer: '',
  sources: const <String>[],
);

final _impactExtraction = ExtractionResult(
  documentType: DocumentType.lppCertificate,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: LppEvidenceFactKey.vestedBenefitsCapitalChf.wireName,
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 1,
      sourceText: '',
      needsReview: false,
    ),
  ],
  overallConfidence: 1,
  confidenceDelta: 27,
  warnings: const <String>[],
  disclaimer: '',
  sources: const <String>[],
);

const _genericExtraction = ExtractionResult(
  documentType: DocumentType.avsExtract,
  fields: <ExtractedField>[],
  overallConfidence: 0,
  confidenceDelta: 0,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

final _knownInvalidRawCases = <_RawInvalidCase>[
  _RawInvalidCase(
    'missing scanSessionId',
    (path, _, returnId) => Uri.parse(
      '$path?scanReturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'missing scanReturnId',
    (path, sessionId, _) => Uri.parse(
      '$path?scanSessionId=$sessionId',
    ),
  ),
  _RawInvalidCase(
    'duplicate scanSessionId',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scanSessionId=other-session'
      '&scanReturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'double-encoded scanSessionId key',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scan%2553essionId=$sessionId&scanReturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'case-altered scanSessionId key',
    (path, sessionId, returnId) => Uri.parse(
      '$path?ScanSessionId=$sessionId&scanReturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'extra sensitive access_token',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scanReturnId=$returnId'
      '&access_token=synthetic-redacted',
    ),
  ),
  _RawInvalidCase(
    'duplicate scanReturnId',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scanReturnId=$returnId'
      '&scanReturnId=22222222-2222-4222-8222-222222222222',
    ),
  ),
  _RawInvalidCase(
    'double-encoded scanReturnId key',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scan%2552eturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'case-altered scanReturnId key',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&ScanReturnId=$returnId',
    ),
  ),
  _RawInvalidCase(
    'extra legacy returnUri',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scanReturnId=$returnId'
      '&returnUri=%2Frente-vs-capital',
    ),
  ),
  _RawInvalidCase(
    'extra non-sensitive mode',
    (path, sessionId, returnId) => Uri.parse(
      '$path?scanSessionId=$sessionId&scanReturnId=$returnId&mode=synthetic',
    ),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

  testWidgets(
    'exact linked reviewRetained pair renders ExtractionReviewScreen',
    (tester) async {
      final fixture = _retainRvcReview();
      final harness = _RouteHarness.review(
        sessions: fixture.sessions,
        uri: _reviewUri(fixture.scanSessionId, fixture.scanReturnId),
      );

      await harness.pump(tester);

      expect(find.byType(ExtractionReviewScreen), findsOneWidget);
      expect(
        fixture.sessions
            .dataBlockScanReturnIntentById(fixture.scanReturnId)
            ?.lifecycle,
        DataBlockScanReturnLifecycle.reviewRetained,
      );
    },
  );

  testWidgets(
    'exact linked impactRetained pair renders DocumentImpactScreen',
    (tester) async {
      final fixture = _retainRvcImpact();
      final harness = _RouteHarness.impact(
        sessions: fixture.sessions,
        uri: _impactUri(fixture.scanSessionId, fixture.scanReturnId),
      );

      await harness.pump(tester);

      expect(find.byType(DocumentImpactScreen), findsOneWidget);
      expect(
        fixture.sessions
            .dataBlockScanReturnIntentById(fixture.scanReturnId)
            ?.lifecycle,
        DataBlockScanReturnLifecycle.impactRetained,
      );
    },
  );

  testWidgets(
    'review accepts the exact linked pair with reversed raw key order',
    (tester) async {
      final fixture = _retainRvcReview();
      final harness = _RouteHarness.review(
        sessions: fixture.sessions,
        uri: _reversedReviewUri(
          fixture.scanSessionId,
          fixture.scanReturnId,
        ),
      );

      await harness.pump(tester);

      expect(find.byType(ExtractionReviewScreen), findsOneWidget);
    },
  );

  testWidgets(
    'impact accepts the exact linked pair with reversed raw key order',
    (tester) async {
      final fixture = _retainRvcImpact();
      final harness = _RouteHarness.impact(
        sessions: fixture.sessions,
        uri: _reversedImpactUri(
          fixture.scanSessionId,
          fixture.scanReturnId,
        ),
      );

      await harness.pump(tester);

      expect(find.byType(DocumentImpactScreen), findsOneWidget);
    },
  );

  testWidgets(
    'real Review confirmation carries the exact RVC pair into Impact',
    (tester) async {
      final harness = _ReviewConfirmHarness.create();

      await harness.pump(tester);
      expect(find.byType(ExtractionReviewScreen), findsOneWidget);
      expect(
        harness.sessions
            .dataBlockScanReturnIntentById(harness.fixture.scanReturnId)
            ?.lifecycle,
        DataBlockScanReturnLifecycle.reviewRetained,
      );
      await _tapLppReviewConfirm(tester);

      final routeExceptions = _drainWidgetExceptions(tester);
      final impactUri = harness.impactUri;
      expect(impactUri, isNotNull);
      expect(impactUri!.path, '/scan/impact');
      expect(
        harness.sessions
            .dataBlockScanReturnIntentById(harness.fixture.scanReturnId)
            ?.lifecycle,
        DataBlockScanReturnLifecycle.impactRetained,
      );
      expect(harness.coach.acceptCalls, 1);
      expect(harness.persistence.saveCalls, 1);
      expect(harness.documents.recordCalls, 1);
      expect(
        routeExceptions,
        isEmpty,
        reason:
            'Review watch must not rebuild from the scrubbed Impact payload',
      );
      expect(
        impactUri.queryParameters.keys.toSet(),
        const <String>{'scanSessionId', 'scanReturnId'},
      );
      expect(
        impactUri.queryParametersAll['scanSessionId'],
        <String>[harness.fixture.scanSessionId],
      );
      expect(
        impactUri.queryParametersAll['scanReturnId'],
        <String>[harness.fixture.scanReturnId],
      );
      expect(impactUri.queryParameters.containsKey('returnUri'), isFalse);
      expect(
        impactUri.queryParameters.keys.any(_isSensitiveQueryKey),
        isFalse,
      );
      expect(find.byKey(const Key('impact_uri_probe')), findsOneWidget);
    },
  );

  testWidgets(
    'review wrong queried intent purges linked pair A and preserves B plus survivors',
    (tester) async {
      final fixture = _retainRvcReview();
      final queriedPairB = _retainRvcReview(fixture.sessions);
      final queriedPairBSnapshot = _snapshotFixture(
        fixture.sessions,
        queriedPairB,
      );
      final survivor = _retainSurvivor(fixture.sessions);
      final harness = _RouteHarness.review(
        sessions: fixture.sessions,
        uri: _reviewUri(fixture.scanSessionId, queriedPairB.scanReturnId),
      );

      await harness.pump(tester);

      _expectKnownPairPurged(
        fixture.sessions,
        fixture,
        screen: find.byType(ExtractionReviewScreen),
      );
      _expectFixturePreserved(
        fixture.sessions,
        queriedPairBSnapshot,
      );
      _expectSurvivor(fixture.sessions, survivor);
      await _exitRecovery(
        tester,
        _RecoveryExit.cta,
        ctaKey: const Key('scan_review_recovery_cta'),
      );
      expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
      _expectFixturePreserved(
        fixture.sessions,
        queriedPairBSnapshot,
      );
      _expectSurvivor(fixture.sessions, survivor);
    },
  );

  testWidgets(
    'impact wrong queried intent purges linked pair A and preserves impact pair B plus survivors',
    (tester) async {
      final fixture = _retainRvcImpact();
      final queriedPairB = _retainRvcImpact(fixture.sessions);
      final queriedPairBSnapshot = _snapshotFixture(
        fixture.sessions,
        queriedPairB,
      );
      final survivor = _retainSurvivor(fixture.sessions);
      final harness = _RouteHarness.impact(
        sessions: fixture.sessions,
        uri: _impactUri(fixture.scanSessionId, queriedPairB.scanReturnId),
      );

      await harness.pump(tester);

      _expectKnownPairPurged(
        fixture.sessions,
        fixture,
        screen: find.byType(DocumentImpactScreen),
      );
      _expectFixturePreserved(
        fixture.sessions,
        queriedPairBSnapshot,
      );
      _expectSurvivor(fixture.sessions, survivor);
      await _exitRecovery(
        tester,
        _RecoveryExit.cta,
        ctaKey: const Key('scan_impact_recovery_cta'),
      );
      expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
      _expectFixturePreserved(
        fixture.sessions,
        queriedPairBSnapshot,
      );
      _expectSurvivor(fixture.sessions, survivor);
    },
  );

  testWidgets(
    'review rejects same linked pair at impactRetained and purges only it',
    (tester) async {
      final fixture = _retainRvcImpact();
      final survivor = _retainSurvivor(fixture.sessions);
      final harness = _RouteHarness.review(
        sessions: fixture.sessions,
        uri: _reviewUri(fixture.scanSessionId, fixture.scanReturnId),
      );

      await harness.pump(tester);

      _expectKnownPairPurged(
        fixture.sessions,
        fixture,
        screen: find.byType(ExtractionReviewScreen),
      );
      _expectSurvivor(fixture.sessions, survivor);
      await _exitRecovery(
        tester,
        _RecoveryExit.cta,
        ctaKey: const Key('scan_review_recovery_cta'),
      );
      expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
      _expectSurvivor(fixture.sessions, survivor);
    },
  );

  testWidgets(
    'impact rejects same linked pair at reviewRetained and purges only it',
    (tester) async {
      final fixture = _retainRvcReview();
      final survivor = _retainSurvivor(fixture.sessions);
      final harness = _RouteHarness.impact(
        sessions: fixture.sessions,
        uri: _impactUri(fixture.scanSessionId, fixture.scanReturnId),
      );

      await harness.pump(tester);

      _expectKnownPairPurged(
        fixture.sessions,
        fixture,
        screen: find.byType(DocumentImpactScreen),
      );
      _expectSurvivor(fixture.sessions, survivor);
      await _exitRecovery(
        tester,
        _RecoveryExit.cta,
        ctaKey: const Key('scan_impact_recovery_cta'),
      );
      expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
      _expectSurvivor(fixture.sessions, survivor);
    },
  );

  for (final invalidCase in _knownInvalidRawCases) {
    testWidgets(
      'review rejects ${invalidCase.label}, purges exact pair, preserves survivors, and exits RVC',
      (tester) async {
        final fixture = _retainRvcReview();
        final survivor = _retainSurvivor(fixture.sessions);
        final harness = _RouteHarness.review(
          sessions: fixture.sessions,
          uri: invalidCase.uri(
            '/scan/review',
            fixture.scanSessionId,
            fixture.scanReturnId,
          ),
        );

        await harness.pump(tester);

        _expectKnownPairPurged(
          fixture.sessions,
          fixture,
          screen: find.byType(ExtractionReviewScreen),
        );
        _expectSurvivor(fixture.sessions, survivor);
        await _exitRecovery(
          tester,
          _RecoveryExit.cta,
          ctaKey: const Key('scan_review_recovery_cta'),
        );
        expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
        _expectSurvivor(fixture.sessions, survivor);
      },
    );

    testWidgets(
      'impact rejects ${invalidCase.label}, purges exact pair, preserves survivors, and exits RVC',
      (tester) async {
        final fixture = _retainRvcImpact();
        final survivor = _retainSurvivor(fixture.sessions);
        final harness = _RouteHarness.impact(
          sessions: fixture.sessions,
          uri: invalidCase.uri(
            '/scan/impact',
            fixture.scanSessionId,
            fixture.scanReturnId,
          ),
        );

        await harness.pump(tester);

        _expectKnownPairPurged(
          fixture.sessions,
          fixture,
          screen: find.byType(DocumentImpactScreen),
        );
        _expectSurvivor(fixture.sessions, survivor);
        await _exitRecovery(
          tester,
          _RecoveryExit.cta,
          ctaKey: const Key('scan_impact_recovery_cta'),
        );
        expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
        _expectSurvivor(fixture.sessions, survivor);
      },
    );
  }

  testWidgets('canonical process-loss recovery exits to RVC', (tester) async {
    final sessions = ScanSessionProvider();
    final harness = _RouteHarness.review(
      sessions: sessions,
      uri: Uri.parse(
        '/scan/review?scanSessionId=lost-session'
        '&scanReturnId=11111111-1111-4111-8111-111111111111',
      ),
    );

    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('scan_review_recovery_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
  });

  testWidgets('malformed unknown recovery exits home', (tester) async {
    final sessions = ScanSessionProvider();
    final harness = _RouteHarness.review(
      sessions: sessions,
      uri: Uri.parse(
        '/scan/review?scanSessionId=lost-session&scanReturnId=not-a-uuid',
      ),
    );

    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('scan_review_recovery_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_destination')), findsOneWidget);
  });

  testWidgets('canonical Impact process-loss replays only through RVC recovery',
      (tester) async {
    final sessions = ScanSessionProvider();
    final survivor = _retainSurvivor(sessions);
    final oldUri = Uri.parse(
      '/scan/impact?scanSessionId=lost-session'
      '&scanReturnId=11111111-1111-4111-8111-111111111111',
    );
    final harness = _RouteHarness.impact(sessions: sessions, uri: oldUri);

    await harness.pump(tester);
    expect(find.byType(DocumentImpactScreen), findsNothing);
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_impact_recovery_cta'),
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();
    expect(find.byType(DocumentImpactScreen), findsNothing);
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_impact_recovery_cta'),
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  for (final recoveryCase in _impactRecoveryCases) {
    for (final exit in const <_RecoveryExit>[
      _RecoveryExit.appBar,
      _RecoveryExit.systemBack,
    ]) {
      testWidgets(
        '${recoveryCase.label} Impact first recovery exits RVC and replay exits ${recoveryCase.replayDestination.name} through ${exit.name}',
        (tester) async {
          final scenario = recoveryCase.build();
          final harness = _RouteHarness.impact(
            sessions: scenario.sessions,
            uri: scenario.oldUri,
          );

          await harness.pump(tester);
          final expectedDiscardIds = scenario.knownPair == null
              ? const <String>[]
              : <String>[scenario.knownPair!.scanReturnId];
          expect(scenario.sessions.discardCalls, expectedDiscardIds.length);
          expect(scenario.sessions.discardIds, expectedDiscardIds);
          expect(scenario.sessions.consumeCalls, 0);
          expect(scenario.sessions.consumeIds, isEmpty);
          expect(find.byType(DocumentImpactScreen), findsNothing);
          final knownPair = scenario.knownPair;
          if (knownPair != null) {
            _expectKnownPairPurged(
              scenario.sessions,
              knownPair,
              screen: find.byType(DocumentImpactScreen),
            );
          }
          _expectSurvivor(scenario.sessions, scenario.survivor);
          await _exitRecovery(
            tester,
            exit,
            ctaKey: const Key('scan_impact_recovery_cta'),
          );
          expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
          _expectSurvivor(scenario.sessions, scenario.survivor);

          harness.router.go(scenario.oldUri.toString());
          await tester.pumpAndSettle();
          expect(scenario.sessions.discardCalls, expectedDiscardIds.length);
          expect(scenario.sessions.discardIds, expectedDiscardIds);
          expect(scenario.sessions.consumeCalls, 0);
          expect(scenario.sessions.consumeIds, isEmpty);
          expect(find.byType(DocumentImpactScreen), findsNothing);
          await _exitRecovery(
            tester,
            exit,
            ctaKey: const Key('scan_impact_recovery_cta'),
          );
          expect(
            find.byKey(
              Key('${recoveryCase.replayDestination.name}_destination'),
            ),
            findsOneWidget,
          );
          _expectSurvivor(scenario.sessions, scenario.survivor);
        },
      );
    }
  }

  testWidgets(
      'known-altered Review purges once, exits RVC, then replays only Home',
      (tester) async {
    final sessions = _DiscardSpy();
    final fixture = _retainRvcReview(sessions);
    final survivor = _retainSurvivor(sessions);
    final oldUri = Uri.parse(
      '/scan/review?scanSessionId=${fixture.scanSessionId}'
      '&scanReturnId=${fixture.scanReturnId}&returnUri=%2Fhome',
    );
    final harness = _RouteHarness.review(
      sessions: fixture.sessions,
      uri: oldUri,
    );

    await harness.pump(tester);
    expect(sessions.discardCalls, 1);
    expect(sessions.discardIds, <String>[fixture.scanReturnId]);
    expect(sessions.consumeCalls, 0);
    expect(sessions.consumeIds, isEmpty);
    _expectKnownPairPurged(
      sessions,
      fixture,
      screen: find.byType(ExtractionReviewScreen),
    );
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_review_recovery_cta'),
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();
    expect(sessions.discardCalls, 1);
    expect(sessions.discardIds, <String>[fixture.scanReturnId]);
    expect(sessions.consumeCalls, 0);
    expect(sessions.consumeIds, isEmpty);
    expect(find.byType(ExtractionReviewScreen), findsNothing);
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_review_recovery_cta'),
    );
    expect(find.byKey(const Key('home_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  testWidgets('hostile malformed Impact replay remains home and preserves all',
      (tester) async {
    final sessions = ScanSessionProvider();
    final survivor = _retainSurvivor(sessions);
    final oldUri = Uri.parse(
      '/scan/impact?scanSessionId=lost-session&scanReturnId=not-a-uuid',
    );
    final harness = _RouteHarness.impact(sessions: sessions, uri: oldUri);

    await harness.pump(tester);
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_impact_recovery_cta'),
    );
    expect(find.byKey(const Key('home_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();
    expect(find.byType(DocumentImpactScreen), findsNothing);
    await _exitRecovery(
      tester,
      _RecoveryExit.cta,
      ctaKey: const Key('scan_impact_recovery_cta'),
    );
    expect(find.byKey(const Key('home_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  for (final exit in _RecoveryExit.values) {
    testWidgets(
      'known invalid review exits exactly to RVC through ${exit.name}',
      (tester) async {
        final fixture = _retainRvcReview();
        final survivor = _retainSurvivor(fixture.sessions);
        final harness = _RouteHarness.review(
          sessions: fixture.sessions,
          uri: Uri.parse(
            '/scan/review?scanSessionId=${fixture.scanSessionId}',
          ),
        );

        await harness.pump(tester);

        _expectKnownPairPurged(
          fixture.sessions,
          fixture,
          screen: find.byType(ExtractionReviewScreen),
        );
        _expectSurvivor(fixture.sessions, survivor);
        await _exitRecovery(
          tester,
          exit,
          ctaKey: const Key('scan_review_recovery_cta'),
        );
        expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
        _expectSurvivor(fixture.sessions, survivor);
      },
    );

    testWidgets(
      'malformed unknown impact exits exactly home through ${exit.name}',
      (tester) async {
        final sessions = ScanSessionProvider();
        final survivor = _retainSurvivor(sessions);
        final harness = _RouteHarness.impact(
          sessions: sessions,
          uri: Uri.parse(
            '/scan/impact?scanSessionId=lost-session&scanReturnId=not-a-uuid',
          ),
        );

        await harness.pump(tester);

        expect(find.byType(DocumentImpactScreen), findsNothing);
        expect(
          find.byKey(const Key('scan_impact_recovery_cta')),
          findsOneWidget,
        );
        _expectSurvivor(sessions, survivor);
        await _exitRecovery(
          tester,
          exit,
          ctaKey: const Key('scan_impact_recovery_cta'),
        );
        expect(find.byKey(const Key('home_destination')), findsOneWidget);
        _expectSurvivor(sessions, survivor);
      },
    );
  }

  for (final exit in const <_RecoveryExit>[
    _RecoveryExit.appBar,
    _RecoveryExit.systemBack,
  ]) {
    testWidgets(
      'exact review cancellation through ${exit.name} purges pair and returns RVC',
      (tester) async {
        final fixture = _retainRvcReview();
        final survivor = _retainSurvivor(fixture.sessions);
        final harness = _RouteHarness.review(
          sessions: fixture.sessions,
          uri: _reviewUri(fixture.scanSessionId, fixture.scanReturnId),
        );

        await harness.pump(tester);
        expect(find.byType(ExtractionReviewScreen), findsOneWidget);
        await _cancelExactReview(tester, exit);

        expect(fixture.sessions.byId(fixture.scanSessionId), isNull);
        expect(
          fixture.sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
          isNull,
        );
        expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
        _expectSurvivor(fixture.sessions, survivor);
      },
    );
  }

  testWidgets('cancelled exact review URL replays only through RVC recovery',
      (tester) async {
    final fixture = _retainRvcReview();
    final survivor = _retainSurvivor(fixture.sessions);
    final oldUri = _reviewUri(fixture.scanSessionId, fixture.scanReturnId);
    final harness = _RouteHarness.review(
      sessions: fixture.sessions,
      uri: oldUri,
    );

    await harness.pump(tester);
    await _cancelExactReview(tester, _RecoveryExit.appBar);
    expect(fixture.sessions.byId(fixture.scanSessionId), isNull);
    expect(
      fixture.sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
      isNull,
    );
    _expectSurvivor(fixture.sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();

    expect(find.byType(ExtractionReviewScreen), findsNothing);
    expect(find.byKey(const Key('scan_review_recovery_cta')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan_review_recovery_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(fixture.sessions, survivor);
  });

  testWidgets('impact main CTA consumes the exact pair and returns to RVC',
      (tester) async {
    final sessions = _ConsumeSpy();
    final fixture = _retainRvcImpact(sessions);
    final survivor = _retainSurvivor(sessions);
    final harness = _RouteHarness.impact(
      sessions: sessions,
      uri: _impactUri(fixture.scanSessionId, fixture.scanReturnId),
    );

    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('lpp_impact_retirement_cta')));
    await tester.pumpAndSettle();

    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    expect(sessions.byId(fixture.scanSessionId), isNull);
    expect(
      sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
      isNull,
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  testWidgets(
      'impact AppBar terminal consumes once, returns RVC, and replays through recovery',
      (tester) async {
    final sessions = _ConsumeSpy();
    final fixture = _retainRvcImpact(sessions);
    final survivor = _retainSurvivor(sessions);
    final oldUri = _impactUri(fixture.scanSessionId, fixture.scanReturnId);
    final harness = _RouteHarness.impact(
      sessions: sessions,
      uri: oldUri,
    );

    await harness.pump(tester);
    final appBarBack = find.bySemanticsIdentifier('document_impact_back_cta');
    expect(appBarBack, findsOneWidget);
    await tester.tap(appBarBack);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    expect(sessions.byId(fixture.scanSessionId), isNull);
    expect(
      sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
      isNull,
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();
    expect(find.byType(DocumentImpactScreen), findsNothing);
    expect(find.byKey(const Key('scan_impact_recovery_cta')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan_impact_recovery_cta')));
    await tester.pumpAndSettle();

    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  testWidgets('impact system back consumes the exact pair and returns to RVC',
      (tester) async {
    final sessions = _ConsumeSpy();
    final fixture = _retainRvcImpact(sessions);
    final survivor = _retainSurvivor(sessions);
    final harness = _RouteHarness.impact(
      sessions: sessions,
      uri: _impactUri(fixture.scanSessionId, fixture.scanReturnId),
    );

    await harness.pump(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    expect(sessions.byId(fixture.scanSessionId), isNull);
    expect(
      sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
      isNull,
    );
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });

  testWidgets('consumed impact exact URL replays only through RVC recovery',
      (tester) async {
    final sessions = _ConsumeSpy();
    final fixture = _retainRvcImpact(sessions);
    final survivor = _retainSurvivor(sessions);
    final oldUri = _impactUri(fixture.scanSessionId, fixture.scanReturnId);
    final harness = _RouteHarness.impact(
      sessions: sessions,
      uri: oldUri,
    );

    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('lpp_impact_retirement_cta')));
    await tester.pumpAndSettle();
    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    _expectSurvivor(sessions, survivor);

    harness.router.go(oldUri.toString());
    await tester.pumpAndSettle();

    expect(find.byType(DocumentImpactScreen), findsNothing);
    expect(find.byKey(const Key('scan_impact_recovery_cta')), findsOneWidget);

    await tester.tap(find.byKey(const Key('scan_impact_recovery_cta')));
    await tester.pumpAndSettle();

    expect(sessions.consumeCalls, 1);
    expect(sessions.consumeIds, <String>[fixture.scanReturnId]);
    expect(find.byKey(const Key('rvc_destination')), findsOneWidget);
    _expectSurvivor(sessions, survivor);
  });
}

Uri _reviewUri(String scanSessionId, String scanReturnId) => Uri.parse(
      '/scan/review?scanSessionId=$scanSessionId&scanReturnId=$scanReturnId',
    );

Uri _impactUri(String scanSessionId, String scanReturnId) => Uri.parse(
      '/scan/impact?scanSessionId=$scanSessionId&scanReturnId=$scanReturnId',
    );

Uri _reversedReviewUri(String scanSessionId, String scanReturnId) => Uri.parse(
      '/scan/review?scanReturnId=$scanReturnId&scanSessionId=$scanSessionId',
    );

Uri _reversedImpactUri(String scanSessionId, String scanReturnId) => Uri.parse(
      '/scan/impact?scanReturnId=$scanReturnId&scanSessionId=$scanSessionId',
    );

String _retainCreatedRvcIntent(ScanSessionProvider sessions) =>
    sessions.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: parseDataBlockReturnTarget(_rvcRoute)!,
    );

_RvcFixture _retainRvcReview([ScanSessionProvider? existingSessions]) {
  final sessions = existingSessions ?? ScanSessionProvider();
  final scanReturnId = _retainCreatedRvcIntent(sessions);
  expect(
    sessions.advanceDataBlockScanReturnIntent(
      scanReturnId,
      from: DataBlockScanReturnLifecycle.created,
      to: DataBlockScanReturnLifecycle.processing,
    ),
    isTrue,
  );
  final scanSessionId = sessions.retainExtraction(
    _reviewExtraction,
    dataBlockScanReturnIntentId: scanReturnId,
    lppCandidate: _candidate,
    lppAuthorization: _authorization,
  );
  return _RvcFixture(
    sessions: sessions,
    scanSessionId: scanSessionId,
    scanReturnId: scanReturnId,
  );
}

_RvcFixture _retainRvcImpact([ScanSessionProvider? existingSessions]) {
  final fixture = _retainRvcReview(existingSessions);
  expect(
    fixture.sessions.retainImpact(
      fixture.scanSessionId,
      extraction: _impactExtraction,
      previousConfidence: 42,
    ),
    isTrue,
  );
  return fixture;
}

final class _RvcFixture {
  const _RvcFixture({
    required this.sessions,
    required this.scanSessionId,
    required this.scanReturnId,
  });

  final ScanSessionProvider sessions;
  final String scanSessionId;
  final String scanReturnId;
}

final class _Survivor {
  const _Survivor({
    required this.genericScanSessionId,
    required this.linkedScanSessionId,
    required this.linkedScanReturnId,
    required this.unlinkedScanReturnId,
    required this.genericSessionSnapshot,
    required this.linkedSessionSnapshot,
    required this.linkedIntentSnapshot,
    required this.unlinkedIntentSnapshot,
  });

  final String genericScanSessionId;
  final String linkedScanSessionId;
  final String linkedScanReturnId;
  final String unlinkedScanReturnId;
  final ScanSessionPayload genericSessionSnapshot;
  final ScanSessionPayload linkedSessionSnapshot;
  final DataBlockScanReturnIntent linkedIntentSnapshot;
  final DataBlockScanReturnIntent unlinkedIntentSnapshot;
}

_Survivor _retainSurvivor(ScanSessionProvider sessions) {
  final genericScanSessionId = sessions.retainExtraction(_genericExtraction);
  final linked = _retainRvcReview(sessions);
  final unlinkedScanReturnId = _retainCreatedRvcIntent(sessions);
  return _Survivor(
    genericScanSessionId: genericScanSessionId,
    linkedScanSessionId: linked.scanSessionId,
    linkedScanReturnId: linked.scanReturnId,
    unlinkedScanReturnId: unlinkedScanReturnId,
    genericSessionSnapshot: sessions.byId(genericScanSessionId)!,
    linkedSessionSnapshot: sessions.byId(linked.scanSessionId)!,
    linkedIntentSnapshot:
        sessions.dataBlockScanReturnIntentById(linked.scanReturnId)!,
    unlinkedIntentSnapshot:
        sessions.dataBlockScanReturnIntentById(unlinkedScanReturnId)!,
  );
}

void _expectSurvivor(ScanSessionProvider sessions, _Survivor survivor) {
  expect(
    sessions.byId(survivor.genericScanSessionId),
    same(survivor.genericSessionSnapshot),
  );
  expect(
    sessions.byId(survivor.linkedScanSessionId),
    same(survivor.linkedSessionSnapshot),
  );
  expect(
    sessions.dataBlockScanReturnIntentById(survivor.linkedScanReturnId),
    same(survivor.linkedIntentSnapshot),
  );
  expect(
    sessions.dataBlockScanReturnIntentById(survivor.unlinkedScanReturnId),
    same(survivor.unlinkedIntentSnapshot),
  );
}

typedef _ImpactRecoveryBuilder = _ImpactRecoveryScenario Function();

enum _ReplayDestination { rvc, home }

final class _ImpactRecoveryCase {
  const _ImpactRecoveryCase(
    this.label,
    this.replayDestination,
    this.build,
  );

  final String label;
  final _ReplayDestination replayDestination;
  final _ImpactRecoveryBuilder build;
}

final class _ImpactRecoveryScenario {
  const _ImpactRecoveryScenario({
    required this.sessions,
    required this.survivor,
    required this.oldUri,
    this.knownPair,
  });

  final _DiscardSpy sessions;
  final _Survivor survivor;
  final Uri oldUri;
  final _RvcFixture? knownPair;
}

final _impactRecoveryCases = <_ImpactRecoveryCase>[
  _ImpactRecoveryCase(
    'canonical process-loss',
    _ReplayDestination.rvc,
    () {
      final sessions = _DiscardSpy();
      return _ImpactRecoveryScenario(
        sessions: sessions,
        survivor: _retainSurvivor(sessions),
        oldUri: Uri.parse(
          '/scan/impact?scanSessionId=lost-session'
          '&scanReturnId=11111111-1111-4111-8111-111111111111',
        ),
      );
    },
  ),
  _ImpactRecoveryCase(
    'known-altered',
    _ReplayDestination.home,
    () {
      final sessions = _DiscardSpy();
      final fixture = _retainRvcImpact(sessions);
      return _ImpactRecoveryScenario(
        sessions: sessions,
        survivor: _retainSurvivor(sessions),
        oldUri: Uri.parse(
          '/scan/impact?scanSessionId=${fixture.scanSessionId}'
          '&scanReturnId=${fixture.scanReturnId}&returnUri=%2Fhome',
        ),
        knownPair: fixture,
      );
    },
  ),
];

typedef _RawUriBuilder = Uri Function(
  String path,
  String scanSessionId,
  String scanReturnId,
);

final class _RawInvalidCase {
  const _RawInvalidCase(this.label, this.uri);

  final String label;
  final _RawUriBuilder uri;
}

enum _RecoveryExit { cta, appBar, systemBack }

bool _isSensitiveQueryKey(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'access_token' ||
      normalized == 'authorization' ||
      normalized == 'cookie' ||
      normalized == 'password' ||
      normalized == 'sourcetext' ||
      normalized.contains('secret');
}

final class _ReviewRoutePersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  Map<String, dynamic> answers = <String, dynamic>{
    'q_birth_year': 1980,
    'q_canton': 'VD',
  };
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

final class _ReviewRouteCoachProvider extends CoachProfileProvider {
  _ReviewRouteCoachProvider(this.persistence)
      : super(
          taxProfilePersistence: persistence,
          lppProfilePersistence: persistence,
          now: () => DateTime.utc(2026, 7, 19, 12),
        );

  final _ReviewRoutePersistence persistence;
  bool _loaded = false;
  int acceptCalls = 0;

  @override
  Future<LppReviewReceipt> acceptLppReview(
    LppReviewConfirmation confirmation,
  ) async {
    acceptCalls += 1;
    if (!_loaded) {
      await loadFromWizard();
      _loaded = true;
    }
    return super.acceptLppReview(confirmation);
  }
}

final class _ReviewRouteDocumentProvider extends DocumentProvider {
  int recordCalls = 0;

  @override
  Future<ConfirmedDocumentReference> recordConfirmedLppReview(
    LppReviewReceipt receipt,
  ) async {
    recordCalls += 1;
    return ConfirmedDocumentReference(
      referenceId: '44444444-4444-4444-8444-444444444444',
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: receipt.snapshotId,
      ownerKind: receipt.ownerKind,
      confirmedAt: DateTime.utc(2026, 7, 19, 12),
    );
  }
}

final class _ReviewConfirmHarness {
  _ReviewConfirmHarness._({
    required this.sessions,
    required this.fixture,
    required this.persistence,
    required this.coach,
    required this.documents,
  });

  factory _ReviewConfirmHarness.create() {
    final sessions = ScanSessionProvider();
    final fixture = _retainRvcReview(sessions);
    final persistence = _ReviewRoutePersistence();
    final coach = _ReviewRouteCoachProvider(persistence);
    final documents = _ReviewRouteDocumentProvider();
    final harness = _ReviewConfirmHarness._(
      sessions: sessions,
      fixture: fixture,
      persistence: persistence,
      coach: coach,
      documents: documents,
    );
    harness.router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => testOnlyBuildScanReviewRoute(
            _reviewUri(fixture.scanSessionId, fixture.scanReturnId),
          ),
        ),
        GoRoute(
          path: '/scan/impact',
          builder: (_, state) {
            harness.impactUri = state.uri;
            return const Scaffold(key: Key('impact_uri_probe'));
          },
        ),
        GoRoute(
          path: _rvcRoute,
          builder: (_, __) => const Scaffold(key: Key('rvc_destination')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(key: Key('home_destination')),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, __) => const Scaffold(key: Key('scan_destination')),
        ),
      ],
    );
    return harness;
  }

  final ScanSessionProvider sessions;
  final _RvcFixture fixture;
  final _ReviewRoutePersistence persistence;
  final _ReviewRouteCoachProvider coach;
  final _ReviewRouteDocumentProvider documents;
  late final GoRouter router;
  Uri? impactUri;
  bool _closed = false;

  Future<void> pump(WidgetTester tester) async {
    addTearDown(() => close(tester));
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
          ChangeNotifierProvider<DocumentProvider>.value(value: documents),
          ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
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
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    documents.dispose();
    coach.dispose();
    sessions.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

final class _ConsumeSpy extends ScanSessionProvider {
  int consumeCalls = 0;
  final List<String> consumeIds = <String>[];

  @override
  DataBlockReturnTarget? consumeDataBlockScanReturnIntent(String id) {
    consumeCalls += 1;
    consumeIds.add(id);
    return super.consumeDataBlockScanReturnIntent(id);
  }
}

final class _DiscardSpy extends ScanSessionProvider {
  int discardCalls = 0;
  final List<String> discardIds = <String>[];
  int consumeCalls = 0;
  final List<String> consumeIds = <String>[];

  @override
  bool discardDataBlockScanReturnIntent(String id) {
    discardCalls += 1;
    discardIds.add(id);
    return super.discardDataBlockScanReturnIntent(id);
  }

  @override
  DataBlockReturnTarget? consumeDataBlockScanReturnIntent(String id) {
    consumeCalls += 1;
    consumeIds.add(id);
    return super.consumeDataBlockScanReturnIntent(id);
  }
}

void _expectKnownPairPurged(
  ScanSessionProvider sessions,
  _RvcFixture fixture, {
  required Finder screen,
}) {
  expect(screen, findsNothing);
  expect(sessions.byId(fixture.scanSessionId), isNull);
  expect(
    sessions.dataBlockScanReturnIntentById(fixture.scanReturnId),
    isNull,
  );
}

final class _FixtureSnapshot {
  const _FixtureSnapshot({
    required this.fixture,
    required this.session,
    required this.intent,
  });

  final _RvcFixture fixture;
  final ScanSessionPayload session;
  final DataBlockScanReturnIntent intent;
}

_FixtureSnapshot _snapshotFixture(
  ScanSessionProvider sessions,
  _RvcFixture fixture,
) =>
    _FixtureSnapshot(
      fixture: fixture,
      session: sessions.byId(fixture.scanSessionId)!,
      intent: sessions.dataBlockScanReturnIntentById(fixture.scanReturnId)!,
    );

void _expectFixturePreserved(
  ScanSessionProvider sessions,
  _FixtureSnapshot snapshot,
) {
  expect(
    sessions.byId(snapshot.fixture.scanSessionId),
    same(snapshot.session),
  );
  expect(
    sessions.dataBlockScanReturnIntentById(snapshot.fixture.scanReturnId),
    same(snapshot.intent),
  );
}

Future<void> _exitRecovery(
  WidgetTester tester,
  _RecoveryExit exit, {
  required Key ctaKey,
}) async {
  switch (exit) {
    case _RecoveryExit.cta:
      await tester.tap(find.byKey(ctaKey));
    case _RecoveryExit.appBar:
      await tester.tap(find.byType(BackButton).first);
    case _RecoveryExit.systemBack:
      await tester.binding.handlePopRoute();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapLppReviewConfirm(WidgetTester tester) async {
  final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
  await tester.scrollUntilVisible(
    confirm,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(
    find.byType(Scrollable).first,
    const Offset(0, -100),
  );
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

List<Object> _drainWidgetExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  while (true) {
    final exception = tester.takeException();
    if (exception == null) return exceptions;
    exceptions.add(exception);
  }
}

Future<void> _cancelExactReview(
  WidgetTester tester,
  _RecoveryExit exit,
) async {
  switch (exit) {
    case _RecoveryExit.appBar:
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.arrow_back).first,
      );
    case _RecoveryExit.systemBack:
      await tester.binding.handlePopRoute();
    case _RecoveryExit.cta:
      throw ArgumentError('Exact Review cancellation has no CTA gesture');
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

final class _RouteHarness {
  _RouteHarness._({
    required this.sessions,
    required Widget Function() routeBuilder,
  }) {
    router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, __) => routeBuilder()),
        GoRoute(
          path: '/scan/review',
          builder: (_, state) => testOnlyBuildScanReviewRoute(state.uri),
        ),
        GoRoute(
          path: '/scan/impact',
          builder: (_, state) => testOnlyBuildScanImpactRoute(state.uri),
        ),
        GoRoute(
          path: _rvcRoute,
          builder: (_, __) => const Scaffold(key: Key('rvc_destination')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(key: Key('home_destination')),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, __) => const Scaffold(key: Key('scan_destination')),
        ),
        GoRoute(
          path: '/retraite',
          builder: (_, __) =>
              const Scaffold(key: Key('retirement_destination')),
        ),
      ],
    );
  }

  factory _RouteHarness.review({
    required ScanSessionProvider sessions,
    required Uri uri,
  }) =>
      _RouteHarness._(
        sessions: sessions,
        routeBuilder: () => testOnlyBuildScanReviewRoute(uri),
      );

  factory _RouteHarness.impact({
    required ScanSessionProvider sessions,
    required Uri uri,
  }) =>
      _RouteHarness._(
        sessions: sessions,
        routeBuilder: () => testOnlyBuildScanImpactRoute(uri),
      );

  final ScanSessionProvider sessions;
  late final GoRouter router;
  bool _closed = false;

  Future<void> pump(WidgetTester tester) async {
    addTearDown(() => close(tester));
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
          ChangeNotifierProvider<DocumentProvider>(
            create: (_) => DocumentProvider(),
          ),
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
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    sessions.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
