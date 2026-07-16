import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _DetailProfilePersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _DetailProfilePersistence()
      : _answers = <String, dynamic>{
          'q_birth_year': 1981,
          'q_canton': 'VD',
          'q_civil_status': 'celibataire',
          'q_has_pension_fund': 'yes',
        };

  final Map<String, dynamic> _answers;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(_answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    _answers
      ..clear()
      ..addAll(answers);
  }
}

final class _FailingThenReadyReferenceStore extends DocumentReferenceStore {
  int loadCalls = 0;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    loadCalls += 1;
    if (loadCalls == 1) {
      throw StateError('synthetic hydration failure');
    }
    return const <ConfirmedDocumentReference>[];
  }
}

LppReviewConfirmation _confirmation(
  DateTime now, {
  required double total,
  required double disability,
}) {
  return LppReviewConfirmation(
    authorization: LppAcquisitionAuthorization(
      acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
      subject: LppEvidenceOwnerKind.self,
      partnerAttested: false,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: now.subtract(const Duration(minutes: 5)),
      documentSha256:
          '1111111111111111111111111111111111111111111111111111111111111111',
    ),
    sourceDate: DateTime.utc(2026, 6, 30),
    facts: <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
        value: total,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
        value: disability,
        unit: LppEvidenceUnit.chfPerYear,
      ),
    },
  );
}

Widget _app({
  required CoachProfileProvider ledger,
  required DocumentProvider documents,
  required String referenceId,
}) {
  final router = GoRouter(
    initialLocation: '/documents/$referenceId',
    routes: [
      GoRoute(
        path: '/documents',
        builder: (_, __) => const Scaffold(
          key: Key('documents_destination'),
        ),
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (_, state) => DocumentDetailScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<DocumentProvider>.value(value: documents),
    ],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
  });

  testWidgets(
      'confirmed detail exposes loading, failure retry, and missing states',
      (tester) async {
    const referenceId = '99999999-9999-4999-8999-999999999999';
    final now = DateTime.utc(2026, 7, 16, 17);
    final persistence = _DetailProfilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    final store = _FailingThenReadyReferenceStore();
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    await ledger.loadFromWizard();
    documents.bindLedger(ledger);

    await tester.pumpWidget(
      _app(
        ledger: ledger,
        documents: documents,
        referenceId: referenceId,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('document_reference_loading_state')),
      findsOneWidget,
    );

    await documents.hydrateReferences().catchError((_) {});
    await tester.pump();
    expect(
      find.byKey(const Key('document_reference_failed_state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('document_reference_retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('document_reference_retry')));
    await tester.pumpAndSettle();
    expect(store.loadCalls, 2);
    expect(
      find.byKey(const Key('document_reference_missing_state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('document_reference_back_to_documents')),
      findsOneWidget,
    );
  });

  testWidgets(
      'confirmed detail renders strict snapshot facts and stale id never shows replacement values',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 7, 16, 17);
    final persistence = _DetailProfilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    final documents = DocumentProvider(now: () => now);
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    await ledger.loadFromWizard();
    final receipt = await ledger.acceptLppReview(
      _confirmation(now, total: 125000, disability: 24000),
    );
    documents.bindLedger(ledger);
    final reference = await documents.recordConfirmedLppReview(receipt);

    await tester.pumpWidget(
      _app(
        ledger: ledger,
        documents: documents,
        referenceId: reference.referenceId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("CHF 125'000"), findsOneWidget);
    expect(find.text("CHF 24'000/an"), findsOneWidget);
    expect(find.text('Capital-décès'), findsNothing);

    await ledger.acceptLppReview(
      _confirmation(now, total: 131000, disability: 25200),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('document_reference_stale_state')),
      findsOneWidget,
    );
    expect(find.text("CHF 125'000"), findsNothing);
    expect(find.text("CHF 131'000"), findsNothing);
    expect(find.text("CHF 25'200/an"), findsNothing);
  });

  testWidgets(
      'removing a confirmed link says ledger facts remain and deletes metadata only',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 7, 16, 18);
    final persistence = _DetailProfilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    final documents = DocumentProvider(now: () => now);
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    await ledger.loadFromWizard();
    final receipt = await ledger.acceptLppReview(
      _confirmation(now, total: 125000, disability: 24000),
    );
    documents.bindLedger(ledger);
    final reference = await documents.recordConfirmedLppReview(receipt);

    await tester.pumpWidget(
      _app(
        ledger: ledger,
        documents: documents,
        referenceId: reference.referenceId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('document_reference_remove')));
    await tester.pumpAndSettle();

    expect(find.text('Retirer le lien du document ?'), findsOneWidget);
    expect(
      find.text(
        'Seul le lien local sera retiré. Les faits confirmés restent conservés dans ton profil.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retirer le lien').last);
    await tester.pumpAndSettle();

    expect(documents.hasStoredReference(reference.referenceId), isFalse);
    expect(
      ledger.currentLppSnapshotId(LppEvidenceOwnerKind.self),
      receipt.snapshotId,
    );
  });
}
