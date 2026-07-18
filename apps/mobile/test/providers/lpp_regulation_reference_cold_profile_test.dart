import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') return secureStorageValues;
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    if (call.method == 'deleteAll') {
      secureStorageValues.clear();
      return null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secureStorageValues.clear();
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
  });

  test('default persistence cold-loads a regulation-only schema-2 root',
      () async {
    final now = DateTime.utc(2026, 7, 18, 8, 30);
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
    });

    final writer = CoachProfileProvider(now: () => now);
    final writerDocuments = DocumentProvider(now: () => now);
    addTearDown(writer.dispose);
    addTearDown(writerDocuments.dispose);
    await writer.loadFromWizard();
    writerDocuments.bindLedger(writer);
    await writerDocuments.hydrateReferences();
    final receipt = await writer.acceptLppRegulationReference(
      LppRegulationReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        sourceDate: DateTime.utc(2026, 7, 17),
        legalYear: 2025,
        fundRelationship: LppFundRelationship.currentFund,
      ),
    );
    final documentReference =
        await writerDocuments.recordLppRegulation(receipt);

    final preferences = await SharedPreferences.getInstance();
    final wizardCache = preferences.getString('wizard_answers_v2');
    final activeAuthoritySlot =
        preferences.getString('coach_authority_active_slot_v1');
    expect(wizardCache, isNotNull);
    expect(jsonDecode(wizardCache!)['_coach_lpp_evidence_v1'], '__secure__');
    expect(activeAuthoritySlot, isNotNull);

    final persistedBeforeDefaultOff =
        await ReportPersistenceService.loadAnswers();
    final rootBeforeDefaultOff = LppEvidenceRoot.fromJsonString(
      persistedBeforeDefaultOff['_coach_lpp_evidence_v1'],
      now: () => now,
    );
    expect(rootBeforeDefaultOff, isNotNull);
    expect(rootBeforeDefaultOff!.self, isNull);
    expect(rootBeforeDefaultOff.selfRegulationReference?.referenceId,
        receipt.referenceId);
    expect(
      await DocumentReferenceStore().load(),
      contains(
        isA<ConfirmedDocumentReference>()
            .having(
              (reference) => reference.referenceId,
              'referenceId',
              documentReference.referenceId,
            )
            .having(
              (reference) => reference.kind,
              'kind',
              documentReference.kind,
            ),
      ),
    );

    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    final defaultOff = CoachProfileProvider(now: () => now);
    addTearDown(defaultOff.dispose);
    await defaultOff.loadFromWizard();
    expect(defaultOff.isLoaded, isTrue);

    final persistedAfterDefaultOff =
        await ReportPersistenceService.loadAnswers();
    expect(
      persistedAfterDefaultOff['_coach_lpp_evidence_v1'],
      persistedBeforeDefaultOff['_coach_lpp_evidence_v1'],
    );
    expect(
      await DocumentReferenceStore().load(),
      contains(
        isA<ConfirmedDocumentReference>().having(
          (reference) => reference.referenceId,
          'referenceId',
          documentReference.referenceId,
        ),
      ),
    );

    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final cold = CoachProfileProvider(now: () => now);
    final coldDocuments = DocumentProvider(now: () => now);
    addTearDown(cold.dispose);
    addTearDown(coldDocuments.dispose);
    await cold.loadFromWizard();
    coldDocuments.bindLedger(cold);
    await coldDocuments.hydrateReferences();

    expect(cold.isLoaded, isTrue);
    expect(cold.currentLppSnapshot(LppEvidenceOwnerKind.self), isNull);
    expect(cold.profile, isNotNull);
    expect(
        cold.profile!.lppRegulationReference?.referenceId, receipt.referenceId);
    expect(
        coldDocuments.resolveLppRegulation(
          cold.profile!.lppRegulationReference,
        ),
        isNotNull);
  });
}
