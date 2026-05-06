// DOCS-02 (Phase 92) — widget-level integration test for the
// post-upload merge step exposed by `mergeVaultUploadIntoCoachProfile`.
//
// We don't drive `_pickAndUpload` directly because it depends on
// `FilePicker.platform.pickFiles`, which can't be triggered cleanly in a
// widget test without a platform-channel fake. Instead we exercise the
// `@visibleForTesting` top-level helper that `_pickAndUpload` calls
// after the upload completes — same code path, deterministic inputs.
//
// What this proves :
//   - When `lastUploadResult` carries an `LppExtractedFields`, the merge
//     populates `CoachProfileProvider.profile.prevoyance` with the typed
//     values (BUG #4 P0 surface).
//   - `MintStateProvider.recompute` is invoked exactly once with the
//     freshly-merged profile (Cap recompute kicked off).
//   - `dataTimestamps` is stamped, proving confidence will be invalidated
//     on the next `EnhancedConfidenceService` read.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────

/// Drop-in DocumentProvider that returns a canned upload result without
/// hitting `DocumentService` / HTTP.
class _FakeDocumentProvider extends DocumentProvider {
  _FakeDocumentProvider({required this.cannedResult}) : super();

  DocumentUploadResult? cannedResult;

  @override
  DocumentUploadResult? get lastUploadResult => cannedResult;
}

/// Records `recompute` calls without running the real engine (which
/// depends on SharedPreferences + MintStateEngine).
class _RecordingMintStateProvider extends MintStateProvider {
  final List<CoachProfile> recomputed = <CoachProfile>[];

  @override
  Future<void> recompute(CoachProfile profile) async {
    recomputed.add(profile);
  }
}

DocumentUploadResult _lppResult({required double avoir}) {
  return DocumentUploadResult(
    id: 'fake-upload-id',
    documentType: VaultDocumentType.lppCertificate,
    extractedFields: VaultExtractedFields(
      documentType: VaultDocumentType.lppCertificate,
      lpp: LppExtractedFields(
        avoirVieillesseTotal: avoir,
        salaireAssure: 91967.0,
        rachatMaximum: 539413.70,
      ),
    ),
    confidence: 0.95,
    fieldsFound: 3,
    fieldsTotal: LppExtractedFields.fieldsTotal,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mirror the secure-storage / SharedPreferences scaffolding used by
  // CoachProfileProvider's persist path.
  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) {
              mockSecureStorage[key] = value;
            }
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('mergeVaultUploadIntoCoachProfile (DOCS-02 — closes BUG #4 P0)', () {
    test(
        'LPP upload populates CoachProfile + triggers recompute exactly once',
        () async {
      final docProvider =
          _FakeDocumentProvider(cannedResult: _lppResult(avoir: 70376.60));
      final coachProvider = CoachProfileProvider();
      final mintState = _RecordingMintStateProvider();

      await mergeVaultUploadIntoCoachProfile(
        type: VaultDocumentType.lppCertificate,
        docProvider: docProvider,
        coachProvider: coachProvider,
        mintState: mintState,
      );

      // CoachProfile populated.
      expect(coachProvider.profile, isNotNull);
      expect(coachProvider.profile!.prevoyance.avoirLppTotal,
          closeTo(70376.60, 1.0));
      expect(coachProvider.profile!.prevoyance.salaireAssure,
          closeTo(91967.0, 1.0));

      // MintStateProvider.recompute called exactly once with the freshly-
      // merged profile.
      expect(mintState.recomputed.length, 1);
      expect(mintState.recomputed.single.prevoyance.avoirLppTotal,
          closeTo(70376.60, 1.0));

      // Timestamps stamped → EnhancedConfidenceService will treat this as
      // fresh, automatic confidence invalidation (no explicit invalidate
      // call needed).
      expect(
          coachProvider.profile!.dataTimestamps['prevoyance.avoirLppTotal'],
          isA<DateTime>());
    });

    test('non-LPP upload is a no-op (no merge, no recompute)', () async {
      final docProvider = _FakeDocumentProvider(
        cannedResult: const DocumentUploadResult(
          id: 'salary-id',
          documentType: VaultDocumentType.salaryCertificate,
          extractedFields: VaultExtractedFields(
            documentType: VaultDocumentType.salaryCertificate,
          ),
          confidence: 0.9,
          fieldsFound: 0,
          fieldsTotal: 0,
        ),
      );
      final coachProvider = CoachProfileProvider();
      final mintState = _RecordingMintStateProvider();

      await mergeVaultUploadIntoCoachProfile(
        type: VaultDocumentType.salaryCertificate,
        docProvider: docProvider,
        coachProvider: coachProvider,
        mintState: mintState,
      );

      // No profile bootstrap (we never called the LPP merge).
      expect(coachProvider.profile, isNull);
      expect(mintState.recomputed, isEmpty);
    });

    test('null lastUploadResult is a no-op (e.g. upload failed)', () async {
      final docProvider = _FakeDocumentProvider(cannedResult: null);
      final coachProvider = CoachProfileProvider();
      final mintState = _RecordingMintStateProvider();

      await mergeVaultUploadIntoCoachProfile(
        type: VaultDocumentType.lppCertificate,
        docProvider: docProvider,
        coachProvider: coachProvider,
        mintState: mintState,
      );

      expect(coachProvider.profile, isNull);
      expect(mintState.recomputed, isEmpty);
    });

    test('upload succeeded but lpp field is null → no-op (defensive guard)',
        () async {
      final docProvider = _FakeDocumentProvider(
        cannedResult: const DocumentUploadResult(
          id: 'lpp-but-empty',
          documentType: VaultDocumentType.lppCertificate,
          extractedFields: VaultExtractedFields(
            documentType: VaultDocumentType.lppCertificate,
            // lpp explicitly omitted (extractor returned no fields)
          ),
          confidence: 0.0,
          fieldsFound: 0,
          fieldsTotal: LppExtractedFields.fieldsTotal,
        ),
      );
      final coachProvider = CoachProfileProvider();
      final mintState = _RecordingMintStateProvider();

      await mergeVaultUploadIntoCoachProfile(
        type: VaultDocumentType.lppCertificate,
        docProvider: docProvider,
        coachProvider: coachProvider,
        mintState: mintState,
      );

      expect(coachProvider.profile, isNull);
      expect(mintState.recomputed, isEmpty);
    });
  });
}
