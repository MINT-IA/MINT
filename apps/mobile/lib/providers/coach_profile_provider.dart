import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/coach_cache_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';
import 'package:mint_mobile/services/snapshot_service.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;

abstract interface class TaxProfilePersistence {
  Future<Map<String, dynamic>> loadAnswers();

  Future<void> saveAnswers(Map<String, dynamic> answers);
}

final class _ReportTaxProfilePersistence implements TaxProfilePersistence {
  const _ReportTaxProfilePersistence();

  @override
  Future<Map<String, dynamic>> loadAnswers() =>
      ReportPersistenceService.loadAnswers();

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) =>
      ReportPersistenceService.saveAnswers(answers);
}

abstract interface class LppProfilePersistence {
  Future<Map<String, dynamic>> loadAnswers();

  Future<void> saveAnswers(Map<String, dynamic> answers);
}

final class _ReportLppProfilePersistence implements LppProfilePersistence {
  const _ReportLppProfilePersistence();

  @override
  Future<Map<String, dynamic>> loadAnswers() =>
      ReportPersistenceService.loadAnswers();

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) =>
      ReportPersistenceService.saveLppEvidenceAnswers(answers);
}

/// Provider pour le profil Coach MINT.
///
/// ARCHITECTURAL NOTE: Two profile models coexist by design:
/// - ProfileProvider: syncs with backend API (source of truth for persisted data)
/// - CoachProfileProvider: rich local model with wizard data, prevoyance, patrimoine
///
/// CoachProfile is the SUPERSET used by all simulators and the coach.
/// Profile (API model) is used only for backend sync (create/update).
///
/// Synchronization: CoachProfile is built from Profile + local wizard data.
/// There is no automatic sync from CoachProfile back to Profile.
///
/// Charge les reponses du wizard depuis SharedPreferences
/// et construit un CoachProfile. Si aucun wizard n'a ete complete,
/// [profile] est null et les ecrans Coach affichent un etat vide.
///
/// Le profil est recalcule a chaque appel a [loadFromWizard()].
class CoachProfileProvider extends ChangeNotifier {
  CoachProfileProvider({
    TaxProfilePersistence? taxProfilePersistence,
    LppProfilePersistence? lppProfilePersistence,
    DateTime Function()? now,
  })  : _taxProfilePersistence =
            taxProfilePersistence ?? const _ReportTaxProfilePersistence(),
        _lppProfilePersistence =
            lppProfilePersistence ?? const _ReportLppProfilePersistence(),
        _usesInjectedTaxPersistence = taxProfilePersistence != null,
        _now = now ?? DateTime.now;

  static const _taxSnapshotRootKey = '_coach_tax_snapshots_v1';
  static const _lppEvidenceRootKey = '_coach_lpp_evidence_v1';
  static const _legacySelfLppKeys = <String, LppEvidenceFactKey>{
    '_coach_avoir_lpp': LppEvidenceFactKey.vestedBenefitsCapitalChf,
    '_coach_avoir_lpp_oblig':
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf,
    '_coach_avoir_lpp_suroblig':
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
    '_coach_salaire_assure': LppEvidenceFactKey.insuredSalaryAnnualChf,
    '_coach_rachat_maximum': LppEvidenceFactKey.maximumBuybackCapitalChf,
    '_coach_taux_conversion': LppEvidenceFactKey.mandatoryConversionRateRatio,
    '_coach_taux_conversion_suroblig':
        LppEvidenceFactKey.extraMandatoryConversionRateRatio,
    '_coach_rendement_caisse': LppEvidenceFactKey.fundReturnRateRatio,
  };
  final TaxProfilePersistence _taxProfilePersistence;
  final LppProfilePersistence _lppProfilePersistence;
  final bool _usesInjectedTaxPersistence;
  final DateTime Function() _now;
  CoachProfile? _profile;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isPartialProfile = false;
  bool _remoteHydrationDone = false;
  bool _isHydrating = false;
  int? _previousScore;
  List<Map<String, dynamic>> _scoreHistory = [];
  bool _profileUpdatedSinceBudget = false;
  Map<String, dynamic> _lastAnswers = const {};
  Future<void>? _lppMutationTail;

  /// Le profil Coach construit a partir des reponses wizard.
  /// Null si le wizard n'a pas ete complete.
  CoachProfile? get profile => _profile;

  /// Immutable wizard-answer view for legacy report generation.
  ///
  /// Screens must never read `wizard_answers_v2` directly. This snapshot is a
  /// temporary compatibility boundary while the report still consumes the
  /// legacy answer shape.
  Map<String, dynamic> get reportAnswersSnapshot =>
      _immutableAnswers(_lastAnswers);

  /// Wait for initial provider hydration without exposing the persistence
  /// service to route builders. Timeout keeps report deep links recoverable.
  Future<Map<String, dynamic>> waitForReportAnswers({
    Duration timeout = const Duration(seconds: 8),
  }) {
    if (_isLoaded) return Future.value(reportAnswersSnapshot);

    final completer = Completer<Map<String, dynamic>>();
    late VoidCallback listener;
    listener = () {
      if (!_isLoaded || completer.isCompleted) return;
      removeListener(listener);
      completer.complete(reportAnswersSnapshot);
    };
    addListener(listener);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        removeListener(listener);
        throw TimeoutException('CoachProfile report hydration timed out');
      },
    );
  }

  static Map<String, dynamic> _copyAnswers(Map<String, dynamic> answers) =>
      answers.map((key, value) => MapEntry(key, _copyAnswerValue(value)));

  static dynamic _copyAnswerValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _copyAnswerValue(nested)),
      );
    }
    if (value is List) return value.map(_copyAnswerValue).toList();
    return value;
  }

  static Map<String, dynamic> _immutableAnswers(
    Map<String, dynamic> answers,
  ) =>
      Map.unmodifiable(
        answers.map(
          (key, value) => MapEntry(key, _immutableAnswerValue(value)),
        ),
      );

  static dynamic _immutableAnswerValue(dynamic value) {
    if (value is Map) {
      return Map.unmodifiable(
        value.map(
          (key, nested) =>
              MapEntry(key.toString(), _immutableAnswerValue(nested)),
        ),
      );
    }
    if (value is List) {
      return List.unmodifiable(value.map(_immutableAnswerValue));
    }
    return value;
  }

  static ({Map<String, dynamic> answers, bool migrated})
      _withLegacyTaxQuarantine(
    Map<String, dynamic> loaded, {
    required DateTime Function() now,
  }) {
    final answers = _copyAnswers(loaded);
    if (!FeatureFlags.typedTaxProfile) {
      return (answers: answers, migrated: false);
    }
    final rawRoot = answers[_taxSnapshotRootKey];
    // `__secure__` means the encrypted value was temporarily unreadable. Any
    // rewrite here would replace the real Keychain payload with a quarantine
    // wrapper, so consumers fail closed without touching either representation.
    if (rawRoot == '__secure__') {
      return (answers: answers, migrated: false);
    }
    final legacyValues = <String, dynamic>{
      for (final entry in answers.entries)
        if (entry.key.startsWith('_coach_tax_') &&
            entry.key != _taxSnapshotRootKey)
          entry.key: _copyAnswerValue(entry.value),
    };
    List<TaxSnapshot> snapshots = const [];
    Map<String, dynamic>? existingQuarantine;
    if (answers.containsKey(_taxSnapshotRootKey)) {
      try {
        final existing = _readTaxEnvelope(answers);
        snapshots = existing.snapshots;
        existingQuarantine = existing.legacyQuarantine;
      } on StateError {
        final quarantinedValues = <String, dynamic>{
          for (final entry in legacyValues.entries)
            entry.key: _copyAnswerValue(entry.value),
          '_coach_tax_quarantined_malformed_root_v1': _copyAnswerValue(rawRoot),
        };
        for (final key in legacyValues.keys) {
          answers.remove(key);
        }
        final rawProvenance = answers['__provenance'];
        if (rawProvenance is Map) {
          answers['__provenance'] = <String, dynamic>{
            for (final entry in rawProvenance.entries)
              if (!entry.key.toString().startsWith('fiscal.'))
                entry.key.toString(): _copyAnswerValue(entry.value),
          };
        }
        answers[_taxSnapshotRootKey] = jsonEncode({
          'schemaVersion': 1,
          'snapshots': <Object>[],
          'legacyQuarantine': <String, dynamic>{
            'legacySchemaVersion': 0,
            'reasonCodes': <String>[
              'malformed_canonical_tax_root',
              if (legacyValues.isNotEmpty) 'untyped_legacy_tax_facts',
            ],
            'values': quarantinedValues,
            'quarantinedAt': now().toUtc().toIso8601String(),
          },
        });
        return (answers: answers, migrated: true);
      }
    }
    if (legacyValues.isEmpty) {
      return (answers: answers, migrated: false);
    }

    final quarantinedValues = existingQuarantine?['values'] is Map
        ? Map<String, dynamic>.from(
            _copyAnswerValue(existingQuarantine!['values']) as Map,
          )
        : <String, dynamic>{};
    for (final entry in legacyValues.entries) {
      quarantinedValues.putIfAbsent(entry.key, () => entry.value);
    }
    final reasonCodes = existingQuarantine?['reasonCodes'] is List
        ? List<String>.from(existingQuarantine!['reasonCodes'] as List)
        : <String>[];
    if (!reasonCodes.contains('untyped_legacy_tax_facts')) {
      reasonCodes.add('untyped_legacy_tax_facts');
    }
    final quarantinedAt = existingQuarantine?['quarantinedAt']?.toString() ??
        now().toUtc().toIso8601String();

    for (final key in legacyValues.keys) {
      answers.remove(key);
    }
    answers[_taxSnapshotRootKey] = jsonEncode({
      'schemaVersion': 1,
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      'legacyQuarantine': <String, dynamic>{
        'legacySchemaVersion': existingQuarantine?['legacySchemaVersion'] ?? 0,
        'reasonCodes': reasonCodes,
        'values': quarantinedValues,
        'quarantinedAt': quarantinedAt,
      },
    });
    return (answers: answers, migrated: true);
  }

  static ({Map<String, dynamic> answers, bool migrated})
      _withoutLoosePartnerLppBesideOpaqueRoot(Map<String, dynamic> loaded) {
    final answers = _copyAnswers(loaded);
    if (!FeatureFlags.typedLppEvidence ||
        !answers.containsKey(_lppEvidenceRootKey) ||
        LppEvidenceRoot.fromJsonString(answers[_lppEvidenceRootKey]) != null) {
      return (answers: answers, migrated: false);
    }
    final presentKeys = legacyPartnerLppAnswerKeys
        .where(answers.containsKey)
        .toList(growable: false);
    if (presentKeys.isEmpty) {
      return (answers: answers, migrated: false);
    }
    for (final key in presentKeys) {
      answers.remove(key);
    }
    return (answers: answers, migrated: true);
  }

  static ({Map<String, dynamic> answers, bool migrated})
      _withLegacySelfLppMigration(Map<String, dynamic> loaded,
          {required DateTime Function() now}) {
    final answers = _copyAnswers(loaded);
    if (!FeatureFlags.typedLppEvidence) {
      return (answers: answers, migrated: false);
    }
    final hasExistingRoot = answers.containsKey(_lppEvidenceRootKey);
    final rawRoot = answers[_lppEvidenceRootKey];
    if (rawRoot == '__secure__') {
      return (answers: answers, migrated: false);
    }
    final existingRoot = hasExistingRoot
        ? LppEvidenceRoot.fromJsonString(rawRoot)
        : const LppEvidenceRoot(self: null);
    if (existingRoot == null) {
      return (answers: answers, migrated: false);
    }

    final facts = <LppEvidenceFactKey, LppEvidenceFact>{};
    final migratedKeys = <String>{};
    final retainedUnprovedZeroKeys = <String>{};
    if (!hasExistingRoot) {
      final rawProvenance = answers['__provenance'];
      if (rawProvenance is Map) {
        final ownerId = const Uuid().v4();
        DateTime? acceptanceStamp;
        final current = now().toUtc();
        for (final entry in _legacySelfLppKeys.entries) {
          final rawValue = answers[entry.key];
          if (rawValue is! num) continue;
          final value = rawValue.toDouble();
          final envelope = rawProvenance[entry.value.profilePath];
          if (envelope is! Map || envelope.keys.any((key) => key is! String)) {
            continue;
          }
          final fact = LppEvidenceFact.fromJson(
            <String, dynamic>{
              'value': value,
              'unit': entry.value.unit.wireName,
              'owner': <String, dynamic>{
                'kind': 'self',
                'profileOwnerId': ownerId,
              },
              'actor': <String, dynamic>{'profileOwnerId': ownerId},
              'authorization': const <String, dynamic>{
                'mode': 'self',
                'grantId': null,
              },
              'provenance': Map<String, dynamic>.from(envelope),
            },
            key: entry.value,
            expectedOwnerKind: LppEvidenceOwnerKind.self,
          );
          if (fact == null || fact.source != 'certificate') {
            continue;
          }
          if (fact.updatedAt.isAfter(current) ||
              (fact.sourceDate != null &&
                  _civilDay(fact.sourceDate!).isAfter(_civilDay(current)))) {
            continue;
          }
          // Loose legacy scalars have no review snippet capable of proving
          // that a documentary zero was explicit rather than extraction loss.
          if (value == 0) {
            retainedUnprovedZeroKeys.add(entry.key);
            continue;
          }
          acceptanceStamp ??= fact.updatedAt;
          if (fact.updatedAt != acceptanceStamp) {
            facts.clear();
            migratedKeys.clear();
            break;
          }
          facts[entry.value] = fact;
          migratedKeys.add(entry.key);
        }
      }
    }

    for (final key in migratedKeys) {
      answers.remove(key);
    }
    if (migratedKeys.isNotEmpty &&
        _legacySelfLppKeys.keys.every((key) => !answers.containsKey(key))) {
      answers.remove('_coach_lpp_source');
    }

    final legacyPartnerKeys = <String>[
      for (final key in legacyPartnerLppAnswerKeys)
        if (answers.containsKey(key)) key,
    ];
    for (final key in legacyPartnerKeys) {
      answers.remove(key);
    }
    if (facts.isEmpty &&
        retainedUnprovedZeroKeys.isEmpty &&
        legacyPartnerKeys.isEmpty) {
      return (answers: answers, migrated: false);
    }

    final existingQuarantine = existingRoot.legacyPartnerQuarantine;
    final quarantinedKeys = <String>{
      ...?existingQuarantine?.presentKeys,
      ...legacyPartnerKeys,
    }.toList();
    final quarantine = quarantinedKeys.isEmpty
        ? existingQuarantine
        : LppLegacyPartnerQuarantine(
            reasonCodes: const <String>['untyped_legacy_partner_lpp'],
            presentKeys: List.unmodifiable(quarantinedKeys),
            quarantinedAt: existingQuarantine?.quarantinedAt ?? now().toUtc(),
          );
    answers[_lppEvidenceRootKey] = LppEvidenceRoot(
      self: facts.isEmpty
          ? existingRoot.self
          : LppEvidenceSnapshot(
              snapshotId: const Uuid().v4(),
              facts: Map.unmodifiable(facts),
            ),
      manualPartner: existingRoot.manualPartner,
      legacyPartnerQuarantine: quarantine,
    ).toJsonString();
    return (answers: answers, migrated: true);
  }

  static ({
    List<TaxSnapshot> snapshots,
    Map<String, dynamic>? legacyQuarantine,
  }) _readTaxEnvelope(Map<String, dynamic> answers) {
    final raw = answers[_taxSnapshotRootKey];
    if (raw == null) {
      if (answers.containsKey(_taxSnapshotRootKey)) {
        throw StateError('Invalid persisted tax profile: null tax root');
      }
      return (snapshots: const [], legacyQuarantine: null);
    }
    try {
      if (raw is! String) throw const FormatException('Tax root is not JSON');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Tax root is not a map');
      final root = Map<String, dynamic>.from(decoded);
      if (root.length != 3 ||
          root['schemaVersion'] != 1 ||
          root['snapshots'] is! List ||
          !root.containsKey('legacyQuarantine')) {
        throw const FormatException('Invalid tax root contract');
      }

      final snapshots = <TaxSnapshot>[];
      final ids = <String>{};
      String? profileOwnerId;
      for (final rawSnapshot in root['snapshots'] as List) {
        if (rawSnapshot is! Map) {
          throw const FormatException('Invalid tax snapshot');
        }
        final snapshot =
            TaxSnapshot.fromJson(Map<String, dynamic>.from(rawSnapshot));
        if (!ids.add(snapshot.snapshotId)) {
          throw const FormatException('Duplicate tax snapshot');
        }
        profileOwnerId ??= snapshot.profileOwnerId;
        if (snapshot.profileOwnerId != profileOwnerId) {
          throw const FormatException('Unstable tax profile owner');
        }
        snapshots.add(snapshot);
      }

      final rawQuarantine = root['legacyQuarantine'];
      Map<String, dynamic>? legacyQuarantine;
      if (rawQuarantine != null) {
        if (rawQuarantine is! Map) {
          throw const FormatException('Invalid tax quarantine');
        }
        final quarantine = Map<String, dynamic>.from(rawQuarantine);
        final reasons = quarantine['reasonCodes'];
        final values = quarantine['values'];
        if (quarantine.length != 4 ||
            quarantine['legacySchemaVersion'] != 0 ||
            reasons is! List ||
            reasons.isEmpty ||
            reasons.any((reason) => reason is! String) ||
            values is! Map ||
            values.keys.any(
              (key) =>
                  key is! String ||
                  !key.startsWith('_coach_tax_') ||
                  key == _taxSnapshotRootKey,
            ) ||
            DateTime.tryParse(
                  quarantine['quarantinedAt']?.toString() ?? '',
                ) ==
                null) {
          throw const FormatException('Invalid tax quarantine');
        }
        legacyQuarantine = _copyAnswerValue(quarantine) as Map<String, dynamic>;
      }
      return (
        snapshots: List<TaxSnapshot>.unmodifiable(snapshots),
        legacyQuarantine: legacyQuarantine,
      );
    } on Object catch (error) {
      throw StateError('Invalid persisted tax profile: $error');
    }
  }

  static ProfileDataSource _taxSourceFor(TaxDocumentKind kind) {
    return switch (kind) {
      TaxDocumentKind.assessmentNotice => ProfileDataSource.certificate,
      TaxDocumentKind.taxpayerReturn => ProfileDataSource.userInput,
      TaxDocumentKind.provisionalBill ||
      TaxDocumentKind.finalTaxBill ||
      TaxDocumentKind.unknown =>
        ProfileDataSource.estimated,
    };
  }

  static ProfileDataSource _taxSourceForLeaf(
    TaxSnapshot snapshot,
    String leafPath,
  ) {
    if (leafPath == 'inForceAttested' ||
        (leafPath == 'assessmentStatus' &&
            snapshot.assessmentStatus == TaxAssessmentStatus.inForce)) {
      return ProfileDataSource.userInput;
    }
    return _taxSourceFor(snapshot.documentKind);
  }

  static CoachProfile _withTaxSnapshotProvenance(
    CoachProfile profile,
    TaxSnapshot snapshot, {
    required DateTime updatedAt,
  }) {
    final sources = Map<String, ProfileDataSource>.from(profile.dataSources);
    final timestamps = Map<String, DateTime>.from(profile.dataTimestamps);
    final sourceDates = Map<String, DateTime?>.from(profile.dataSourceDates);
    final prefix = 'fiscal.snapshots.${snapshot.snapshotId}.';
    sources.removeWhere((path, _) => path.startsWith(prefix));
    timestamps.removeWhere((path, _) => path.startsWith(prefix));
    sourceDates.removeWhere((path, _) => path.startsWith(prefix));
    for (final leafPath in TaxSnapshot.provenanceLeafPaths) {
      if (leafPath != 'sourceDate' &&
          snapshot.provenanceValue(leafPath) == null) {
        continue;
      }
      final path = '$prefix$leafPath';
      sources[path] = _taxSourceForLeaf(snapshot, leafPath);
      timestamps[path] = updatedAt;
      sourceDates[path] = snapshot.sourceDate;
    }
    return profile.copyWith(
      dataSources: sources,
      dataTimestamps: timestamps,
      dataSourceDates: sourceDates,
      updatedAt: updatedAt,
    );
  }

  Future<void> acceptTaxReview(TaxReviewConfirmation confirmation) async {
    if (!FeatureFlags.typedTaxProfile) {
      throw StateError('Typed tax profile is disabled');
    }
    if (confirmation.assessmentStatus == TaxAssessmentStatus.inForce &&
        !confirmation.inForceAttested) {
      throw ArgumentError.value(
        confirmation.inForceAttested,
        'inForceAttested',
        'explicit user attestation required for an in-force assessment',
      );
    }
    final currentCivilTime = _now();
    final updatedAt = currentCivilTime.toUtc();
    final sourceDate = confirmation.sourceDate;
    if (sourceDate != null &&
        _civilDay(sourceDate).isAfter(_civilDay(currentCivilTime))) {
      throw ArgumentError.value(
        sourceDate,
        'sourceDate',
        'future civil source dates cannot enter the ledger',
      );
    }
    TaxSnapshot.validateTaxYears(
      taxYear: confirmation.taxYear,
      basedOnTaxYear: confirmation.basedOnTaxYear,
      documentKind: confirmation.documentKind,
      currentYear: currentCivilTime.year,
    );

    final loaded = await _taxProfilePersistence.loadAnswers();
    final migration = _withLegacyTaxQuarantine(loaded, now: _now);
    final envelope = _readTaxEnvelope(migration.answers);
    final profileOwnerId = envelope.snapshots.isEmpty
        ? const Uuid().v4()
        : envelope.snapshots.first.profileOwnerId;
    final snapshot = TaxSnapshot(
      snapshotId: confirmation.candidate.snapshotId,
      profileOwnerId: profileOwnerId,
      taxYear: confirmation.taxYear,
      basedOnTaxYear: confirmation.basedOnTaxYear,
      sourceDate: confirmation.sourceDate,
      documentKind: confirmation.documentKind,
      assessmentStatus: confirmation.assessmentStatus,
      inForceAttested: confirmation.inForceAttested,
      subjectScope: confirmation.subjectScope,
      cantonCode: confirmation.cantonCode,
      municipalityId: confirmation.municipalityId,
      municipalityLabel: confirmation.municipalityLabel,
      cantonalCommunalTaxableIncomeChf:
          confirmation.cantonalCommunalTaxableIncomeChf,
      federalTaxableIncomeChf: confirmation.federalTaxableIncomeChf,
      cantonalCommunalTaxableWealthChf:
          confirmation.cantonalCommunalTaxableWealthChf,
      cantonalCommunalAssessedTax: confirmation.cantonalCommunalAssessedTax,
      federalDirectAssessedTax: confirmation.federalDirectAssessedTax,
      explicitMarginalIncomeTaxRate: confirmation.explicitMarginalIncomeTaxRate,
      explicitAverageIncomeTaxRate: confirmation.explicitAverageIncomeTaxRate,
      updatedAt: updatedAt,
    );
    final snapshots = List<TaxSnapshot>.from(envelope.snapshots);
    final replacementIndex = snapshots.indexWhere(
      (existing) => existing.snapshotId == snapshot.snapshotId,
    );
    if (replacementIndex == -1) {
      snapshots.add(snapshot);
    } else {
      snapshots[replacementIndex] = snapshot;
    }

    final persistedProfile = CoachProfile.fromWizardAnswers(
      migration.answers,
      now: _now,
    );
    final retainedSnapshotIds = snapshots
        .map((retainedSnapshot) => retainedSnapshot.snapshotId)
        .toSet();
    final validatedSnapshotIds = persistedProfile
        .fiscal.provenanceValidatedSnapshotIds
        .where(retainedSnapshotIds.contains)
        .toSet()
      ..add(snapshot.snapshotId);
    final nextFiscal = FiscalProfile(
      snapshots: snapshots,
      provenanceValidatedSnapshotIds: validatedSnapshotIds,
      legacyDataNeedsReview: envelope.legacyQuarantine?['values'] is Map &&
          (envelope.legacyQuarantine!['values'] as Map).isNotEmpty,
    );
    var nextProfile = persistedProfile.copyWith(fiscal: nextFiscal);
    nextProfile = _withTaxSnapshotProvenance(
      nextProfile,
      snapshot,
      updatedAt: updatedAt,
    );

    final nextAnswers = _copyAnswers(migration.answers);
    nextAnswers[_taxSnapshotRootKey] = jsonEncode({
      'schemaVersion': 1,
      'snapshots': snapshots.map((value) => value.toJson()).toList(),
      'legacyQuarantine': envelope.legacyQuarantine,
    });
    _persistProvenance(nextAnswers, nextProfile);

    await _taxProfilePersistence.saveAnswers(nextAnswers);

    _lastAnswers = _copyAnswers(nextAnswers);
    _profile = nextProfile;
    _isLoaded = true;
    _isPartialProfile = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Persists one complete person-owned LPP review before exposing it in memory.
  Future<void> acceptLppReview(LppReviewConfirmation confirmation) =>
      _serializeLppMutation(() => _acceptLppReview(confirmation));

  Future<void> _acceptLppReview(LppReviewConfirmation confirmation) async {
    if (!FeatureFlags.typedLppEvidence) {
      throw StateError('Typed LPP evidence is disabled');
    }
    final currentCivilTime = _now();
    final authorization = confirmation.authorization;
    if (!authorization.isValidAt(currentCivilTime)) {
      throw StateError('Invalid volatile LPP acquisition authorization');
    }
    if (confirmation.subject == LppEvidenceOwnerKind.manualPartner &&
        _profile?.conjoint == null) {
      throw StateError('Manual partner LPP requires a local partner profile');
    }
    if (confirmation.facts.isEmpty) {
      throw ArgumentError.value(
        confirmation.facts,
        'facts',
        'at least one reviewed LPP fact is required',
      );
    }
    final updatedAt = currentCivilTime.toUtc();
    final sourceDate = confirmation.sourceDate;
    if (sourceDate != null &&
        _civilDay(sourceDate).isAfter(_civilDay(currentCivilTime))) {
      throw ArgumentError.value(
        sourceDate,
        'sourceDate',
        'future civil source dates cannot enter the ledger',
      );
    }
    for (final entry in confirmation.facts.entries) {
      final reviewed = entry.value;
      if (!reviewed.value.isFinite ||
          reviewed.value < 0 ||
          reviewed.unit != entry.key.unit ||
          (reviewed.unit == LppEvidenceUnit.ratio && reviewed.value > 1)) {
        throw ArgumentError.value(
          reviewed.value,
          entry.key.wireName,
          'invalid LPP value or unit',
        );
      }
    }
    if (!LppBalanceCoherence.isCoherent({
      for (final entry in confirmation.facts.entries)
        entry.key: entry.value.value,
    })) {
      throw ArgumentError.value(
        confirmation.facts,
        'facts',
        'incoherent LPP balances',
      );
    }

    final loadedRaw = await _lppProfilePersistence.loadAnswers();
    final migration = _withLegacySelfLppMigration(loadedRaw, now: _now);
    final loaded = migration.answers;
    LppEvidenceRoot currentRoot = const LppEvidenceRoot(self: null);
    if (loaded.containsKey(_lppEvidenceRootKey)) {
      final decoded = LppEvidenceRoot.fromJsonString(
        loaded[_lppEvidenceRootKey],
      );
      if (decoded == null) {
        throw StateError('Persisted LPP evidence is unavailable');
      }
      currentRoot = decoded;
    }
    final stableSelfOwnerId =
        currentRoot.self?.facts.values.first.profileOwnerId ??
            currentRoot.manualPartner?.facts.values.first.actorProfileOwnerId ??
            const Uuid().v4();
    var reviewedOwnerId = stableSelfOwnerId;
    if (confirmation.subject == LppEvidenceOwnerKind.manualPartner) {
      reviewedOwnerId =
          currentRoot.manualPartner?.facts.values.first.profileOwnerId ??
              const Uuid().v4();
      while (reviewedOwnerId == stableSelfOwnerId) {
        reviewedOwnerId = const Uuid().v4();
      }
    }
    final authorizationMode = confirmation.subject == LppEvidenceOwnerKind.self
        ? LppEvidenceAuthorizationMode.self
        : LppEvidenceAuthorizationMode.manualPartnerDeclaration;
    final storedFacts = <LppEvidenceFactKey, LppEvidenceFact>{
      for (final entry in confirmation.facts.entries)
        entry.key: LppEvidenceFact(
          value: entry.value.value,
          unit: entry.value.unit,
          profileOwnerId: reviewedOwnerId,
          actorProfileOwnerId: stableSelfOwnerId,
          ownerKind: confirmation.subject,
          authorizationMode: authorizationMode,
          source: entry.value.corrected ? 'userInput' : 'certificate',
          sourceDate: entry.value.corrected ? null : sourceDate,
          updatedAt: updatedAt,
        ),
    };
    final nextRoot = LppEvidenceRoot(
      self: confirmation.subject == LppEvidenceOwnerKind.self
          ? LppEvidenceSnapshot(
              snapshotId: const Uuid().v4(),
              facts: Map.unmodifiable(storedFacts),
            )
          : currentRoot.self,
      manualPartner: confirmation.subject == LppEvidenceOwnerKind.manualPartner
          ? LppEvidenceSnapshot(
              snapshotId: const Uuid().v4(),
              facts: Map.unmodifiable(storedFacts),
            )
          : currentRoot.manualPartner,
      legacyPartnerQuarantine: currentRoot.legacyPartnerQuarantine,
    );
    final nextAnswers = _copyAnswers(loaded);
    if (confirmation.subject == LppEvidenceOwnerKind.self) {
      for (final key in _legacySelfLppKeys.keys) {
        nextAnswers.remove(key);
      }
      nextAnswers.remove('_coach_lpp_source');
    }
    nextAnswers[_lppEvidenceRootKey] = nextRoot.toJsonString();
    var nextProfile = CoachProfile.fromWizardAnswers(nextAnswers, now: _now);
    for (final entry in storedFacts.entries) {
      nextProfile = _withStampedProvenance(
        nextProfile,
        <String>[
          confirmation.subject == LppEvidenceOwnerKind.self
              ? entry.key.profilePath
              : entry.key.manualPartnerProfilePath,
        ],
        source: entry.value.source == 'certificate'
            ? ProfileDataSource.certificate
            : ProfileDataSource.userInput,
        sourceDate: entry.value.sourceDate,
        updatedAt: entry.value.updatedAt,
      );
    }
    _persistProvenance(nextAnswers, nextProfile);

    await _lppProfilePersistence.saveAnswers(nextAnswers);

    _lastAnswers = _copyAnswers(nextAnswers);
    _profile = nextProfile;
    _isLoaded = true;
    _isPartialProfile = true;
    _profileUpdatedSinceBudget = true;
    CoachNarrativeService.invalidateCache(profile: _profile);
    notifyListeners();
  }

  Future<T> _serializeLppMutation<T>(Future<T> Function() operation) async {
    final previousMutation = _lppMutationTail;
    final completion = Completer<void>();
    final currentMutation = completion.future;
    _lppMutationTail = currentMutation;
    if (previousMutation != null) await previousMutation;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_lppMutationTail, currentMutation)) {
        _lppMutationTail = null;
      }
    }
  }

  static DateTime _civilDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// S47: Stamp dataTimestamps for a set of field paths.
  /// Merges with existing timestamps — only overwrites the given fields.
  static Map<String, DateTime> _stampTimestamps(
    Map<String, DateTime> existing,
    Iterable<String> fieldPaths, {
    DateTime? now,
  }) {
    final ts = Map<String, DateTime>.from(existing);
    final stamp = now ?? DateTime.now();
    for (final path in fieldPaths) {
      ts[path] = stamp;
    }
    return ts;
  }

  /// S47: Persist dataTimestamps into wizard answers for reload survival.
  static void _persistTimestamps(
    Map<String, dynamic> answers,
    Map<String, DateTime> timestamps,
  ) {
    final serialized = <String, String>{};
    for (final entry in timestamps.entries) {
      serialized[entry.key] = entry.value.toIso8601String();
    }
    answers['_coach_data_timestamps'] = serialized;
  }

  static const Map<String, List<String>> _answerProvenancePaths = {
    'q_firstname': ['firstName'],
    'q_birth_year': ['birthYear'],
    'q_date_of_birth': ['dateOfBirth'],
    'q_canton': ['canton'],
    'q_commune': ['commune'],
    'q_nationality': ['nationality'],
    'q_residence_permit': ['residencePermit'],
    'q_civil_status': ['etatCivil'],
    'q_children': ['nombreEnfants'],
    'q_employment_status': ['employmentStatus'],
    'q_main_goal': ['goalA.type'],
    'q_gender': ['gender'],
    'q_target_retirement_age': ['targetRetirementAge'],
    'q_net_income_period_chf': ['monthlyNetIncomeDeclared'],
    'q_pay_frequency': ['monthlyNetIncomeDeclared'],
    'q_gross_salary_annual': ['salaireBrutMensuel'],
    'q_nombre_mois': ['nombreDeMois'],
    'q_employment_rate': ['employmentRate'],
    'q_annual_bonus': ['bonusPourcentage'],
    'q_bonus_percentage': ['bonusPourcentage'],
    'q_self_employed_income': ['selfEmployedNetIncome'],
    'q_company_profit_annual_chf': ['companyProfitAnnual'],
    'q_unemployment_contribution_months': [
      'unemploymentContributionMonths',
    ],
    '_coach_avoir_lpp': ['prevoyance.avoirLppTotal'],
    '_coach_avoir_lpp_oblig': ['prevoyance.avoirLppObligatoire'],
    '_coach_avoir_lpp_suroblig': ['prevoyance.avoirLppSurobligatoire'],
    '_coach_salaire_assure': ['prevoyance.salaireAssure'],
    '_coach_rachat_maximum': ['prevoyance.rachatMaximum'],
    '_coach_taux_conversion': ['prevoyance.tauxConversion'],
    '_coach_taux_conversion_suroblig': [
      'prevoyance.tauxConversionSuroblig',
    ],
    '_coach_avs_rente_estimee': [
      'prevoyance.renteAVSEstimeeMensuelle',
    ],
    '_coach_avs_ramd': ['prevoyance.ramd'],
    'q_has_pension_fund': ['prevoyance.hasPensionFund'],
    'q_has_voluntary_lpp': ['prevoyance.hasVoluntaryLpp'],
    'q_3a_annual_contribution': ['pillar3aAnnualContribution'],
    'q_3a_total': ['prevoyance.totalEpargne3a'],
    'q_has_3a': ['hasPillar3a'],
    'q_3a_accounts_count': ['prevoyance.nombre3a'],
    'q_3a_providers': ['providers3a'],
    'q_savings_monthly': ['monthlySavingsContribution'],
    'q_cash_total': ['patrimoine.epargneLiquide'],
    'q_investments_total': ['patrimoine.investissements'],
    'q_wealth_estimate': ['patrimoine.wealthEstimate'],
    'q_property_market_value': ['patrimoine.propertyMarketValue'],
    'q_mortgage_balance': ['dettes.hypotheque'],
    'q_mortgage_rate': ['patrimoine.mortgageRate'],
    'q_monthly_rent': ['patrimoine.monthlyRent'],
    '_coach_dettes_hypotheque': ['dettes.hypotheque'],
    '_coach_dettes_credit': ['dettes.creditConsommation'],
    '_coach_dettes_leasing': ['dettes.leasing'],
    '_coach_dettes_autres': ['dettes.autresDettes'],
    'q_has_consumer_debt': ['dettes.hasDette'],
    'q_debt_payments_period_chf': ['dettes.totalMensualite'],
    'q_partner_birth_year': ['conjoint.birthYear'],
    'q_spouse_avs_contribution_years': [
      'conjoint.prevoyance.anneesContribuees',
    ],
    'q_avs_lacunes_status': ['avsGapStatus'],
    'q_avs_contribution_years': ['prevoyance.anneesContribuees'],
    'q_housing_cost_period_chf': ['depenses.loyer'],
    'q_housing_pay_frequency': ['depenses.loyer'],
    'q_lamal_premium_monthly_chf': ['depenses.assuranceMaladie'],
    '_coach_depenses_electricite': ['depenses.electricite'],
    '_coach_depenses_transport': ['depenses.transport'],
    '_coach_depenses_telecom': ['depenses.telecom'],
    '_coach_depenses_frais_medicaux': ['depenses.fraisMedicaux'],
    '_coach_depenses_autres': ['depenses.autresDepensesFixes'],
  };

  static Set<String> _canonicalPathsForAnswers(
    Map<String, dynamic> answers,
  ) {
    final paths = <String>{};
    for (final entry in answers.entries) {
      if (entry.value != null) {
        paths.addAll(_answerProvenancePaths[entry.key] ?? const []);
      }
    }
    return paths;
  }

  static Set<String> _clearedCanonicalPathsForAnswers(
    Map<String, dynamic> answers,
  ) {
    final paths = <String>{};
    for (final entry in answers.entries) {
      if (entry.value == null) {
        paths.addAll(_answerProvenancePaths[entry.key] ?? const []);
      }
    }
    return paths;
  }

  static dynamic _resolvedCanonicalValue(
    CoachProfile profile,
    String fieldPath,
  ) {
    switch (fieldPath) {
      case 'dettes.hasDette':
        return profile.dettes.hasDette;
      case 'dettes.totalMensualite':
        return profile.dettes.totalMensualite;
    }
    dynamic value = profile.toJson();
    for (final segment in fieldPath.split('.')) {
      if (value is! Map) return null;
      value = value[segment];
    }
    return value;
  }

  static CoachProfile _withStampedProvenance(
    CoachProfile profile,
    Iterable<String> fieldPaths, {
    required ProfileDataSource source,
    required DateTime? sourceDate,
    required DateTime updatedAt,
    Iterable<String> clearedFieldPaths = const [],
  }) {
    final sources = Map<String, ProfileDataSource>.from(profile.dataSources);
    final timestamps = Map<String, DateTime>.from(profile.dataTimestamps);
    final sourceDates = Map<String, DateTime?>.from(profile.dataSourceDates);
    for (final path in clearedFieldPaths) {
      sources.remove(path);
      timestamps.remove(path);
      sourceDates.remove(path);
    }
    for (final path in fieldPaths) {
      sources[path] = source;
      timestamps[path] = updatedAt;
      sourceDates[path] = sourceDate;
    }
    return profile.copyWith(
      dataSources: sources,
      dataTimestamps: timestamps,
      dataSourceDates: sourceDates,
      updatedAt: updatedAt,
    );
  }

  static void _persistProvenance(
    Map<String, dynamic> answers,
    CoachProfile profile,
  ) {
    final envelope = <String, dynamic>{};
    for (final entry in profile.dataSources.entries) {
      final updatedAt = profile.dataTimestamps[entry.key];
      if (updatedAt == null) continue;
      envelope[entry.key] = <String, dynamic>{
        'source': entry.value.name,
        'updatedAt': updatedAt.toIso8601String(),
        'sourceDate': profile.dataSourceDates[entry.key]?.toIso8601String(),
      };
    }
    answers['__provenance'] = envelope;
  }

  /// True pendant le chargement initial.
  bool get isLoading => _isLoading;

  /// True si le chargement a ete effectue au moins une fois.
  bool get isLoaded => _isLoaded;

  /// True if remote profile hydration has already been attempted.
  bool get remoteHydrationDone => _remoteHydrationDone;

  /// True while an async hydration from backend is in progress.
  /// GoRouter uses this to avoid redirecting to onboarding prematurely.
  bool get isHydrating => _isHydrating;

  /// Mark remote hydration as done (prevents duplicate API calls).
  void markRemoteHydrationDone() => _remoteHydrationDone = true;

  /// Signal that async hydration has started.
  /// GoRouter (via refreshListenable) re-evaluates redirects on notify.
  void startHydrating() {
    _isHydrating = true;
    notifyListeners();
  }

  /// Signal that async hydration has completed (success or error).
  /// GoRouter (via refreshListenable) re-evaluates redirects on notify.
  void finishHydrating() {
    _isHydrating = false;
    notifyListeners();
  }

  /// True si un profil est disponible (wizard complete).
  bool get hasProfile => _profile != null;

  /// True si le profil est partiel (mini-onboarding, pas wizard complet).
  bool get isPartialProfile => _isPartialProfile;

  /// True si le profil est complet (wizard complete).
  bool get hasFullProfile => _profile != null && !_isPartialProfile;

  /// Niveau de completude du profil (0.0 a 1.0).
  /// Dynamique: ratio des signaux qualite renseignes sur le total.
  double get profileCompleteness {
    if (_profile == null) return 0.0;
    final total = onboardingTotalSignals;
    if (total == 0) return 0.10;
    return (onboardingAnsweredSignals / total).clamp(0.05, 1.0);
  }

  /// Nombre de donnees renseignees (pour le badge precision).
  /// Dynamique: compte les signaux qualite effectivement remplis.
  int get dataPointsCount {
    if (_profile == null) return 0;
    return onboardingAnsweredSignals;
  }

  /// Dernier score enregistre (pour le calcul de tendance).
  int? get previousScore => _previousScore;

  /// Historique des scores mensuels (max 24 mois).
  List<Map<String, dynamic>> get scoreHistory => _scoreHistory;

  /// True si le profil a ete mis a jour depuis la derniere synchro budget.
  bool get profileUpdatedSinceBudget => _profileUpdatedSinceBudget;

  // ════════════════════════════════════════════════════════════════
  //  BACKEND SYNC — fire-and-forget profile push
  // ════════════════════════════════════════════════════════════════

  /// Best-effort sync of local profile data to the backend.
  /// Fire-and-forget: failure does NOT block local operations.
  /// Only runs when the user is authenticated.
  /// All exceptions are caught — safe to call without awaiting.
  Future<void> _syncToBackend() async {
    if (_profile == null || !_isLoaded) return;
    try {
      // Only sync when authenticated — avoid 401 errors.
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) return;
      final answers = ReportPersistenceService.backendSafeAnswers(_lastAnswers);
      final prefs = await SharedPreferences.getInstance();
      // Stable device ID — generated once, persisted across sessions.
      var deviceId = prefs.getString('_mint_device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('_mint_device_id', deviceId);
      }
      await ApiService.claimLocalData(
        localDataVersion: 1,
        deviceId: deviceId,
        wizardAnswers: answers,
      );
    } catch (e) {
      debugPrint('[CoachProfile] Backend sync failed (non-fatal): $e');
    }
  }

  /// Public entry point for backend sync.
  /// Called by [AuthProvider] after login/register to push local data
  /// when the backend profile is empty.
  Future<void> triggerBackendSync() => _syncToBackend();

  /// Pull fresh profile data from backend and merge into local state.
  ///
  /// Called after each coach chat exchange to capture data written by
  /// save_fact (which executes server-side and never reaches Flutter).
  /// Fire-and-forget: errors are caught silently so chat flow is never blocked.
  ///
  /// OBS-05 note: save_fact itself runs server-side (no mobile dispatch
  /// point). This method is the closest mobile-side proxy to observe the
  /// save_fact outcome — if the remote profile merges new financial fields,
  /// a save_fact succeeded on the server. Breadcrumbs emitted here use
  /// factKind = `'profile_sync'` as the coarse category since we cannot
  /// know which individual factKind was written server-side without a
  /// dedicated response header (deferred to Phase 31-02 backend work).
  Future<void> syncFromBackend() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) return;
      final remoteData = await ApiService.get('/profiles/me');
      mergeFromRemoteProfile(remoteData);
      // Also merge financial fields that the basic merge doesn't cover.
      _mergeFinancialFieldsFromRemote(remoteData);
      // OBS-05 — save_fact success proxy breadcrumb (D-03 4-level).
      // factKind is the coarse 'profile_sync' enum; the finer-grained
      // per-field attribution is deferred to Phase 31-02 (backend can
      // echo `facts_saved: [...]` in /profiles/me response).
      MintBreadcrumbs.saveFact(
        success: true,
        factKind: 'profile_sync',
      );
    } catch (e) {
      debugPrint('[CoachProfile] syncFromBackend failed (non-fatal): $e');
      // OBS-05 — save_fact failure proxy breadcrumb. Error code is an
      // enum (no raw exception message — may contain PII).
      final code = e is ApiException
          ? (e.isOffline ? 'offline' : 'api_error')
          : 'unknown';
      MintBreadcrumbs.saveFact(
        success: false,
        factKind: 'profile_sync',
        errorCode: code,
      );
    }
  }

  /// Merge financial fields from backend that save_fact may have written.
  ///
  /// Complements [mergeFromRemoteProfile] which only covers identity fields.
  /// Maps backend camelCase keys → wizard answer keys understood by
  /// [CoachProfile.fromWizardAnswers], then calls [mergeAnswers] which
  /// handles persistence + notifyListeners.
  void _mergeFinancialFieldsFromRemote(Map<String, dynamic> remote) {
    if (_profile == null) return;
    final p = _profile!.prevoyance;
    final partial = <String, dynamic>{};

    // LPP avoir
    final remoteLpp = (remote['avoirLpp'] as num?)?.toDouble();
    if ((p.avoirLppTotal ?? 0) <= 0 && remoteLpp != null && remoteLpp > 0) {
      partial['_coach_avoir_lpp'] = remoteLpp;
    }
    // LPP salaire assuré
    final remoteSalaire = (remote['lppInsuredSalary'] as num?)?.toDouble();
    if ((p.salaireAssure ?? 0) <= 0 &&
        remoteSalaire != null &&
        remoteSalaire > 0) {
      partial['_coach_salaire_assure'] = remoteSalaire;
    }
    // LPP rachat max
    final remoteRachat = (remote['lppBuybackMax'] as num?)?.toDouble();
    if ((p.rachatMaximum ?? 0) <= 0 &&
        remoteRachat != null &&
        remoteRachat > 0) {
      partial['_coach_rachat_maximum'] = remoteRachat;
    }
    // 3a balance
    final remote3a = (remote['pillar3aBalance'] as num?)?.toDouble();
    if (p.totalEpargne3a <= 0 && remote3a != null && remote3a > 0) {
      partial['_coach_total_3a'] = remote3a;
    }

    if (partial.isNotEmpty) {
      mergeAnswers(partial); // handles persist + notifyListeners + backend sync
    }
  }

  String get personaKey {
    final p = _profile;
    if (p == null) return 'unknown';
    if (p.nombreEnfants > 0 && p.etatCivil == CoachCivilStatus.celibataire) {
      return 'single_parent';
    }
    if (p.nombreEnfants > 0) return 'family';
    if (p.hasPartnerContext) {
      return 'couple';
    }
    return 'single';
  }

  List<String> get _qualityKeys {
    final keys = <String>[
      'q_birth_year',
      'q_canton',
      'q_residence_permit',
      'q_net_income_period_chf',
      'q_employment_status',
      'q_household_type',
      'q_housing_cost_period_chf',
      'q_tax_provision_monthly_chf',
      'q_lamal_premium_monthly_chf',
      'q_has_pension_fund',
      'q_avs_lacunes_status',
      'q_has_3a',
      'q_3a_annual_contribution',
      'q_has_investments',
      'q_savings_monthly',
      'q_has_consumer_debt',
    ];
    if (personaKey == 'couple' || personaKey == 'family') {
      keys.addAll([
        'q_civil_status_choice',
        'q_partner_net_income_chf',
        'q_partner_birth_year',
        'q_partner_employment_status',
      ]);
    }
    if (personaKey == 'single_parent') {
      keys.add('q_children');
    }
    return keys;
  }

  bool _isAnswered(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return value > 0;
    if (value is bool) return true;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  int get onboardingAnsweredSignals {
    if (_profile == null) return 0;
    return _qualityKeys.where((k) => _isAnswered(_lastAnswers[k])).length;
  }

  int get onboardingTotalSignals {
    if (_profile == null) return 0;
    return _qualityKeys.length;
  }

  /// Dynamic onboarding quality score — continuous 0..1 scale.
  /// Based purely on answered signals / total signals.
  double get onboardingQualityScore {
    if (_profile == null) return 0.0;
    final total = onboardingTotalSignals;
    if (total == 0) return 0.10;
    return (onboardingAnsweredSignals / total).clamp(0.05, 0.95);
  }

  String get recommendedWizardSection {
    if (_profile == null) return 'identity';

    final identityComplete = _isAnswered(_lastAnswers['q_birth_year']) &&
        _isAnswered(_lastAnswers['q_canton']);
    if (!identityComplete) return 'identity';

    final hasHousehold = _isAnswered(_lastAnswers['q_household_type']);
    final household =
        (_lastAnswers['q_household_type'] as String?) ?? personaKey;
    final baseIncomeComplete =
        _isAnswered(_lastAnswers['q_net_income_period_chf']) &&
            _isAnswered(_lastAnswers['q_employment_status']) &&
            hasHousehold;
    if (!baseIncomeComplete) return 'income';

    if (household == 'couple' || household == 'family') {
      final partnerComplete =
          _isAnswered(_lastAnswers['q_civil_status_choice']) &&
              _isAnswered(_lastAnswers['q_partner_net_income_chf']) &&
              _isAnswered(_lastAnswers['q_partner_birth_year']) &&
              _isAnswered(_lastAnswers['q_partner_employment_status']);
      if (!partnerComplete) return 'income';
    }

    final pensionComplete = _isAnswered(_lastAnswers['q_has_pension_fund']) &&
        (_isAnswered(_lastAnswers['q_has_3a']) ||
            _isAnswered(_lastAnswers['q_3a_annual_contribution']) ||
            _isAnswered(_lastAnswers['q_lpp_buyback_available']) ||
            _isAnswered(_lastAnswers['q_avs_lacunes_status']));
    if (!pensionComplete) return 'pension';

    final propertyComplete = _isAnswered(_lastAnswers['q_has_investments']) ||
        _isAnswered(_lastAnswers['q_real_estate_project']) ||
        _isAnswered(_lastAnswers['q_risk_tolerance']);
    if (!propertyComplete) return 'property';

    return 'income';
  }

  /// Marque le budget comme synchronise avec le profil actuel.
  void markBudgetSynced() {
    _profileUpdatedSinceBudget = false;
  }

  /// Charge le profil depuis les reponses wizard stockees.
  ///
  /// Appele automatiquement au demarrage de l'app et apres
  /// la completion du wizard.
  Future<void> loadFromWizard() => _serializeLppMutation(_loadFromWizard);

  Future<void> _loadFromWizard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedAnswers = await _taxProfilePersistence.loadAnswers();
      final migration = _withLegacyTaxQuarantine(loadedAnswers, now: _now);
      if (migration.migrated) {
        await _taxProfilePersistence.saveAnswers(migration.answers);
      }
      final opaqueLppCleanup =
          _withoutLoosePartnerLppBesideOpaqueRoot(migration.answers);
      if (opaqueLppCleanup.migrated) {
        await _taxProfilePersistence.saveAnswers(opaqueLppCleanup.answers);
      }
      final lppMigration = _withLegacySelfLppMigration(
        opaqueLppCleanup.answers,
        now: _now,
      );
      if (lppMigration.migrated) {
        await _lppProfilePersistence.saveAnswers(lppMigration.answers);
      }
      final answers = lppMigration.answers;
      _lastAnswers = _copyAnswers(answers);

      // Bounded tax consumers may inject a persistence boundary that has no
      // dependency on Flutter platform bindings. Its
      // non-empty payload is enough to hydrate a partial local profile; the
      // full/mini onboarding completion flags and cross-feature merge remain
      // owned by the default ReportPersistenceService path below.
      if (_usesInjectedTaxPersistence) {
        _profile = answers.isEmpty
            ? null
            : CoachProfile.fromWizardAnswers(answers, now: _now);
        _isPartialProfile = _profile != null;
        _isLoading = false;
        _isLoaded = true;
        _profileUpdatedSinceBudget = _profile != null;
        notifyListeners();
        return;
      }

      // Check full wizard first.
      final isFullCompleted = await ReportPersistenceService.isCompleted();
      if (isFullCompleted && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers, now: _now);
        _isPartialProfile = false;
        await _mergePersistedData();
        _isLoading = false;
        _isLoaded = true;
        _profileUpdatedSinceBudget = true;
        notifyListeners();
        return;
      }

      // Check mini-onboarding
      final isMiniCompleted =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      if (isMiniCompleted && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers, now: _now);
        _isPartialProfile = true;
        await _mergePersistedData();
        _isLoading = false;
        _isLoaded = true;
        _profileUpdatedSinceBudget = true;
        notifyListeners();
        return;
      }

      // Scan-first onboarding: if a document scan has written fields to
      // answers (via updateFrom*Extraction persisting `_coach_*` keys)
      // without any wizard being completed, hydrate from those so the
      // enriched profile survives app restart instead of being lost.
      final hasScanData = answers.keys.any((k) => k.startsWith('_coach_'));
      if (hasScanData && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers, now: _now);
        _isPartialProfile = true;
        await _mergePersistedData();
        _isLoading = false;
        _isLoaded = true;
        _profileUpdatedSinceBudget = true;
        notifyListeners();
        return;
      }

      // No profile at all
      _profile = null;
      _isPartialProfile = false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur chargement CoachProfile: $e');
      }
      _profile = null;
      _isPartialProfile = false;
    }

    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  /// Fusionne les donnees persistees (check-ins, contributions, score)
  /// avec le profil fraichement construit depuis le wizard.
  Future<void> _mergePersistedData() async {
    if (_profile == null) return;

    // Merge check-ins
    final persistedCheckIns = await ReportPersistenceService.loadCheckIns();
    if (persistedCheckIns.isNotEmpty) {
      final checkIns =
          persistedCheckIns.map((ci) => MonthlyCheckIn.fromJson(ci)).toList();
      _profile = _profile!.copyWithCheckIns(checkIns);
    }

    // Merge contributions (si l'utilisateur les a modifies via check-in)
    final persistedContribs =
        await ReportPersistenceService.loadContributions();
    if (persistedContribs.isNotEmpty) {
      final contribs = persistedContribs
          .map((c) => PlannedMonthlyContribution.fromJson(c))
          .toList();
      _profile = _profile!.copyWithContributions(contribs);
    }

    // Charger le score precedent pour le calcul de tendance
    _previousScore = await ReportPersistenceService.loadLastScore();

    // Charger l'historique des scores mensuels
    _scoreHistory = await ReportPersistenceService.loadScoreHistory();
  }

  /// Updates the profile directly from an answers map.
  /// Used after wizard completion to avoid an async reload.
  void updateFromAnswers(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _lastAnswers = _copyAnswers(answers);
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = false;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Merge individual fields into the existing profile (incremental update).
  /// Used by chat inline pickers to update one field at a time without
  /// overwriting the rest of the profile.
  Future<void> mergeAnswers(Map<String, dynamic> partial) =>
      mergeAnswersWithProvenance(partial);

  /// Merge answers while explicitly recording their origin metadata.
  Future<void> mergeAnswersWithProvenance(
    Map<String, dynamic> partial, {
    ProfileDataSource source = ProfileDataSource.userInput,
    DateTime? sourceDate,
  }) async {
    if (partial.isEmpty) return;
    // Deep-walk crack #15: always re-read the on-disk answers before
    // merging. `_lastAnswers` is populated at startup by loadFromWizard
    // but updateFrom*Extraction / budget setup / regex fallback each
    // load+save independently. If mergeAnswers relied on the stale
    // in-memory copy, a budget setup that ran after a scan would build
    // `merged` from {} + {q_housing, q_lamal} and overwrite the persisted
    // `_coach_avoir_lpp` on disk — card Patrimoine would go empty right
    // after the card Budget populated. Read-then-merge-then-save is the
    // only crash-safe discipline.
    final current = await ReportPersistenceService.loadAnswers();
    final normalizedPartial = _withExplicitCashAnswerSource(
      partial,
      source: source,
    );
    final merged = Map<String, dynamic>.from(current)
      ..addAll(normalizedPartial);
    final clearsPartner = _setsNonCoupledCivilStatus(partial);
    if (clearsPartner) {
      _clearPartnerAnswers(merged);
    }

    final stamp = DateTime.now();
    final persistedProfile = CoachProfile.fromWizardAnswers(current);
    final requestedClears = _clearedCanonicalPathsForAnswers(
      normalizedPartial,
    );
    if (clearsPartner) {
      requestedClears.addAll(
        persistedProfile.dataSources.keys.where(
          (path) => path.startsWith('conjoint.'),
        ),
      );
    }
    final requestedStamps = _canonicalPathsForAnswers(normalizedPartial);
    final resolvedProfile = CoachProfile.fromWizardAnswers(merged);
    final touchedPaths = <String>{...requestedStamps, ...requestedClears};
    final clearedFieldPaths = touchedPaths
        .where((path) => _resolvedCanonicalValue(resolvedProfile, path) == null)
        .toSet();
    final stampedFieldPaths = requestedStamps
        .where((path) => _resolvedCanonicalValue(resolvedProfile, path) != null)
        .toSet();
    final legacyAvsEstimatePaths = <String>{
      if (normalizedPartial['_coach_avs_rente_estimee'] != null)
        'prevoyance.renteAVSEstimeeMensuelle',
      if (normalizedPartial['_coach_avs_ramd'] != null) 'prevoyance.ramd',
    };
    stampedFieldPaths.removeAll(legacyAvsEstimatePaths);
    var profileWithProvenance = _withStampedProvenance(
      persistedProfile,
      stampedFieldPaths,
      source: source,
      sourceDate: sourceDate,
      updatedAt: stamp,
      clearedFieldPaths: clearedFieldPaths,
    );
    profileWithProvenance = _withStampedProvenance(
      profileWithProvenance,
      legacyAvsEstimatePaths,
      source: ProfileDataSource.estimated,
      sourceDate: null,
      updatedAt: stamp,
    );
    _persistTimestamps(merged, profileWithProvenance.dataTimestamps);
    _persistProvenance(merged, profileWithProvenance);

    final nextProfile = CoachProfile.fromWizardAnswers(merged);
    await ReportPersistenceService.saveAnswers(merged);

    _lastAnswers = _copyAnswers(merged);
    _profile = nextProfile;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    CoachNarrativeService.invalidateCache(profile: _profile);
    notifyListeners();
    _syncToBackend(); // Fire-and-forget, does not block UI
  }

  /// Apply a `save_fact` tool call locally.
  ///
  /// Backend `save_fact` persists to `ProfileModel.data` only when `user_id`
  /// is present. Anonymous local-mode users (the default for fresh installs)
  /// never have a `user_id`, so the backend path hits `# Hors-DB path` and
  /// returns a non-DB acknowledgement without persisting — the chat captures
  /// data in theory but nothing lands in the profile.
  ///
  /// This method closes that gap: when the coach_chat_screen receives a
  /// `save_fact` tool_use block, it dispatches here to translate the canonical
  /// backend fact key (`incomeNetMonthly`, `canton`, `avoirLpp`, …) into the
  /// wizard answer key(s) that `CoachProfile.fromWizardAnswers` reads, then
  /// calls `mergeAnswers` to persist to SharedPreferences + refresh the
  /// profile.
  ///
  /// Returns `true` when the fact was mapped and applied, `false` when the
  /// key is unknown (caller can log — Claude occasionally hallucinates keys).
  Future<bool> applySaveFact(
    String factKey,
    dynamic factValue, {
    String confidence = 'medium',
    ProfileDataSource source = ProfileDataSource.userInput,
    DateTime? sourceDate,
  }) async {
    if (confidence == 'low') return false; // mirror backend skip
    final mapped = _mapFactKeyToAnswers(factKey, factValue);
    if (mapped.isEmpty) return false;
    if (factKey == 'hasAvsGaps' && _asBool(factValue) == true) {
      final current = await ReportPersistenceService.loadAnswers();
      final currentStatus = current['q_avs_lacunes_status'];
      if (currentStatus == 'arrived_late' || currentStatus == 'lived_abroad') {
        await mergeAnswersWithProvenance(
          {'q_avs_lacunes_status': currentStatus},
          source: source,
          sourceDate: sourceDate,
        );
        return true;
      }
    }
    await mergeAnswersWithProvenance(
      mapped,
      source: source,
      sourceDate: sourceDate,
    );
    return true;
  }

  /// Translates a `save_fact` canonical key + value into the corresponding
  /// wizard answer keys expected by `CoachProfile.fromWizardAnswers`.
  /// Returns an empty map when the key is unknown.
  Map<String, dynamic> _mapFactKeyToAnswers(String factKey, dynamic value) {
    if (value == null) return const {};
    switch (factKey) {
      // Identity / location
      case 'birthYear':
        return {'q_birth_year': value};
      case 'dateOfBirth':
        return {'q_date_of_birth': value};
      case 'canton':
        return {'q_canton': value};
      case 'commune':
        return {'q_commune': value};
      case 'householdType':
        return {'q_civil_status': value};
      case 'employmentStatus':
        return {'q_employment_status': value};
      case 'goal':
        return {'q_main_goal': value};
      case 'gender':
        return {'q_gender': value};
      case 'targetRetirementAge':
        return {'q_target_retirement_age': value};
      // Income — map each fact into a pay-frequency-consistent pair so
      // fromWizardAnswers computes salaireBrutMensuel correctly.
      case 'incomeNetMonthly':
        return {
          'q_net_income_period_chf': value,
          'q_pay_frequency': 'monthly',
        };
      case 'incomeNetYearly':
        return {
          'q_net_income_period_chf': value,
          'q_pay_frequency': 'yearly',
        };
      case 'incomeGrossMonthly':
        final monthly = _asNum(value);
        if (monthly == null) return const {};
        return {'q_gross_salary_annual': monthly * 12};
      case 'incomeGrossYearly':
        return {'q_gross_salary_annual': value};
      case 'employmentRate':
        return {'q_employment_rate': value};
      case 'annualBonus':
        return {'q_annual_bonus': value};
      case 'selfEmployedNetIncome':
        final income = _asNum(value);
        if (income == null) return const {};
        final normalized = income < 0 ? 0 : income;
        return {
          'q_self_employed_income': normalized,
          'q_net_income_period_chf': normalized,
          'q_pay_frequency': 'yearly',
          'q_employment_status': 'independant',
        };
      case 'companyProfitAnnual':
        final profit = _asNum(value);
        if (profit == null) return const {};
        return {
          'q_company_profit_annual_chf': profit < 0 ? 0 : profit,
        };
      // LPP — align with keys fromWizardAnswers reads for scan data
      case 'avoirLpp':
        return {'_coach_avoir_lpp': value};
      case 'avoirLppObligatoire':
        return {'_coach_avoir_lpp_oblig': value};
      case 'avoirLppSurobligatoire':
        return {'_coach_avoir_lpp_suroblig': value};
      case 'lppInsuredSalary':
        return {'_coach_salaire_assure': value};
      case 'lppBuybackMax':
        return {'_coach_rachat_maximum': value};
      case 'has2ndPillar':
        final hasPillar = _asBool(value);
        if (hasPillar == null) return const {};
        return {'q_has_pension_fund': hasPillar ? 'yes' : 'no'};
      case 'hasVoluntaryLpp':
        final hasVoluntary = _asBool(value);
        if (hasVoluntary == null) return const {};
        final answers = {'q_has_voluntary_lpp': hasVoluntary ? 'yes' : 'no'};
        if (hasVoluntary || _profile?.employmentStatus == 'independant') {
          answers['q_has_pension_fund'] = hasVoluntary ? 'yes' : 'no';
        }
        return answers;
      // 3a
      case 'pillar3aAnnual':
        return {'q_3a_annual_contribution': value};
      case 'pillar3aBalance':
        return {'q_3a_total': value};
      // Savings / wealth / debt
      case 'savingsMonthly':
        return {'q_savings_monthly': value};
      case 'totalSavings':
        return {'q_cash_total': value};
      case 'wealthEstimate':
        return {'q_wealth_estimate': value};
      case 'hasDebt':
        final hasDebt = _asBool(value);
        if (hasDebt == null) return const {};
        if (hasDebt) {
          return {
            'q_has_consumer_debt': 'yes',
            '_coach_dettes_credit': null,
            '_coach_dettes_leasing': null,
            '_coach_dettes_autres': null,
          };
        }
        return {
          'q_has_consumer_debt': 'no',
          '_coach_dettes_credit': 0,
          '_coach_dettes_leasing': 0,
          '_coach_dettes_autres': 0,
        };
      case 'totalDebt':
        final total = _asNum(value);
        if (total == null) return const {};
        final normalized = total < 0 ? 0 : total;
        return {
          'q_has_consumer_debt': normalized > 0 ? 'yes' : 'no',
          '_coach_dettes_autres': normalized,
        };
      // Spouse
      case 'spouseBirthYear':
        if (_profile?.isCouple != true) return const {};
        final birthYear = _asNum(value)?.toInt();
        final currentYear = DateTime.now().year;
        if (birthYear == null ||
            birthYear < 1900 ||
            birthYear > currentYear + 1) {
          return const {};
        }
        return {'q_partner_birth_year': birthYear};
      case 'spouseIncomeNetMonthly':
        if (_profile?.isCouple != true) return const {};
        final income = _asNum(value);
        if (income == null) return const {};
        return {'q_partner_net_income_chf': income < 0 ? 0 : income};
      case 'spouseAvsContributionYears':
        if (_profile?.isCouple != true) return const {};
        final years = _asNum(value)?.toInt();
        if (years == null) return const {};
        return {'q_spouse_avs_contribution_years': years.clamp(0, 44)};
      // AVS
      case 'avsContributionYears':
        return {'q_avs_contribution_years': value};
      case 'hasAvsGaps':
        final hasGaps = _asBool(value);
        if (hasGaps == null) return const {};
        return {'q_avs_lacunes_status': hasGaps ? 'unknown' : 'no_gaps'};
      default:
        return const {};
    }
  }

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static bool? _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      switch (v.toLowerCase()) {
        case 'true':
        case 'yes':
        case 'oui':
        case '1':
          return true;
        case 'false':
        case 'no':
        case 'non':
        case '0':
          return false;
      }
    }
    return null;
  }

  /// Met a jour le profil depuis le mini-onboarding (3-4 questions).
  /// Cree un profil partiel immediatement utilisable par le dashboard.
  void updateFromMiniOnboarding(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _lastAnswers = _copyAnswers(answers);
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = true;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Met a jour le profil depuis l'onboarding (3 questions: age, salaire, canton).
  ///
  /// Cree un profil partiel minimal immediatement utilisable par le dashboard.
  /// Convertit le salaire brut annuel en net mensuel via le taux de charges
  /// sociales standard (~13%: AVS 5.3% + LPP ~5% + AC ~1.1% + AANP ~1%).
  /// Source: OFAS barème cotisations 2025. Estimation; le taux réel dépend
  /// du plan LPP et du canton.
  ///
  /// Persiste via [ReportPersistenceService] before notifying listeners.
  Future<void> updateFromSmartFlow({
    required int age,
    required double grossSalary,
    required String canton,

    /// Optional first name — personalises coach greeting.
    String? firstName,

    /// 'CH', 'EU', or 'OTHER' — used to derive q_nationality for archetype detection.
    String? nationalityGroup,

    /// ISO country code when nationalityGroup == 'OTHER' (e.g. 'US', 'BR').
    String? nationalityCountry,

    /// Employment status from onboarding ('salarie', 'independant', etc.).
    String? employmentStatus,

    /// True if a Swiss national declares having lived abroad.
    /// Preserved as a status fact; it never infers AVS years or a pension.
    bool? hasLivedAbroad,

    /// Declared Swiss arrival/return year, when known. It may constrain the
    /// illustrative LPP start but is not converted into AVS contribution years.
    int? arrivalYear,

    /// User's primary focus/intention from FocusSelector.
    String? primaryFocus,

    /// Residence permit type: 'C', 'B', 'G', 'L', or 'other'.
    /// When 'G', archetype is forced to cross_border.
    String? permitType,
  }) async {
    // P0-9: Clamp salary to valid bounds before any computation.
    final clampedGrossSalary = grossSalary.clamp(0, 10000000).toDouble();

    // Convert gross annual → net monthly
    // Net monthly = (grossSalary / 12) × (1 - 0.13) (charges sociales ~13%)
    // fromWizardAnswers() reconvertit net → brut via / (1 - 0.13),
    // ce qui préserve le salaire brut original.
    const double socialChargesRate =
        IncomeConversionCalculator.fallbackSwissSocialChargesRate;
    final netMonthly = (clampedGrossSalary / 12) * (1 - socialChargesRate);
    final birthYear = DateTime.now().year - age;
    final effectiveEmployment = employmentStatus ?? 'salarie';

    // Derive q_nationality for archetype detection (CLAUDE.md archetype table).
    // 'CH' → swissNative/returningSwiss; 'EU' → expatEu (use 'FR' placeholder);
    // 'OTHER' → expatUs (if 'US') or expatNonEu (any other value).
    String? nationality;
    if (nationalityGroup == 'CH') {
      nationality = 'CH';
    } else if (nationalityGroup == 'EU') {
      nationality =
          'FR'; // Generic EU/AELE placeholder → triggers expatEu archetype
    } else if (nationalityGroup == 'OTHER') {
      nationality =
          nationalityCountry; // 'US' → expatUs; null → expatNonEu fallback
    }

    // Arrival and lived-abroad answers remain declarations. They must not be
    // converted into certified AVS years or a pension amount.
    final bool isReturningSwiss = hasLivedAbroad == true && arrivalYear != null;
    final bool isExpat = nationalityGroup != null &&
        nationalityGroup != 'CH' &&
        arrivalYear != null;

    final answers = <String, dynamic>{
      if (firstName != null && firstName.isNotEmpty) 'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': netMonthly,
      // Store gross annual directly to avoid net→gross roundtrip imprecision.
      'q_gross_salary_annual': clampedGrossSalary,
      // Use actual employment status — independant may not have LPP
      'q_employment_status': effectiveEmployment,
      // LPP access: salary > seuil AND salarié (LPP art. 7 — indépendants: opt.)
      'q_has_pension_fund':
          clampedGrossSalary >= 22680 && effectiveEmployment != 'independant'
              ? 'yes'
              : 'no',
      // Nationality for archetype detection (see CLAUDE.md archetype table)
      if (nationality != null) 'q_nationality': nationality,
      if (primaryFocus != null) 'q_primary_focus': primaryFocus,
      if (permitType != null) 'q_residence_permit': permitType,
    };

    // Preserve the declaration and arrival year so the illustrative LPP
    // accumulation can start at arrival rather than at age 25.
    if (isReturningSwiss) {
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      answers['q_avs_arrival_year'] = arrivalYear;
    } else if (isExpat) {
      // Preserve the declared arrived-late status and LPP arrival context.
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] = arrivalYear;
    }

    _lastAnswers = _copyAnswers(answers);
    _profile = CoachProfile.fromWizardAnswers(answers);
    // Inject firstName immediately if provided — not part of wizard answers map.
    if (firstName != null && firstName.isNotEmpty) {
      _profile = _profile!.copyWith(firstName: firstName);
    }

    // S47: Stamp initial timestamps for all fields populated by onboarding.
    // Stamp only fields actually populated by onboarding. Missing AVS pension
    // and contribution years deliberately receive no timestamp.
    final initialFields = <String>[
      'salaireBrutMensuel',
      'age',
      'canton',
      'etatCivil',
      'prevoyance.avoirLppTotal',
      'prevoyance.totalEpargne3a',
    ];
    _profile = _profile!.copyWith(
      dataTimestamps: _stampTimestamps(
        _profile!.dataTimestamps,
        initialFields,
      ),
    );

    // S47-fix: Persist timestamps so they survive app restart
    _persistTimestamps(answers, _profile!.dataTimestamps);

    _isPartialProfile = true;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;

    // Persist BEFORE notify so downstream listeners see consistent state
    await ReportPersistenceService.saveAnswers(answers);
    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    notifyListeners();
    _syncToBackend(); // Fire-and-forget, does not block UI
  }

  /// Create a NEW local CoachProfile from backend data when no local profile
  /// exists (Scenario B: backend-only user, no wizard completed).
  ///
  /// Called when auth is logged in, local profile is null, but GET /profiles/me
  /// returns data. Creates a minimal partial profile so the user is not stuck
  /// in onboarding redirect.
  void createFromRemoteProfile(Map<String, dynamic> remote) {
    if (_profile != null) {
      return; // Already has local profile, use merge instead
    }

    final birthYear =
        remote['birth_year'] as int? ?? remote['birthYear'] as int?;
    final canton = remote['canton'] as String?;
    final grossYearly = (remote['income_gross_yearly'] as num?)?.toDouble() ??
        (remote['incomeGrossYearly'] as num?)?.toDouble();
    final gender = remote['gender'] as String?;
    final employmentStatus = remote['employment_status'] as String? ??
        remote['employmentStatus'] as String?;

    // Only create if we have at least one meaningful field from backend
    if (birthYear == null && canton == null && grossYearly == null) {
      return;
    }

    // P0-9: Clamp remote salary to valid bounds.
    final clampedGrossYearly = grossYearly?.clamp(0, 10000000).toDouble();
    final salaireBrutMensuel =
        clampedGrossYearly != null ? clampedGrossYearly / 12 : 0.0;
    // Use actual birthYear if available; fallback = current year - 40
    // but mark profile as partial so wizard completion is triggered.
    final effectiveBirthYear = birthYear ?? (DateTime.now().year - 40);
    final isPartialAge = birthYear == null;

    _profile = CoachProfile(
      birthYear: effectiveBirthYear,
      canton: canton ?? '',
      salaireBrutMensuel: salaireBrutMensuel,
      gender: gender,
      employmentStatus: employmentStatus ?? 'salarie',
      goalA: GoalA(
        type: GoalAType.retraite,
        // If birthYear is estimated, use a conservative target (don't assume 65)
        targetDate: isPartialAge
            ? DateTime(DateTime.now().year + 20) // Generic "20 years from now"
            : DateTime(effectiveBirthYear + 65),
        label: 'Retraite',
      ),
    );
    _isPartialProfile = _isPartialProfile || isPartialAge;
    _isPartialProfile = true;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Merge remote profile data from backend GET /profiles/me.
  ///
  /// Best-effort: fills in fields that are null locally but present in
  /// the remote profile. Does NOT overwrite local data with remote data.
  /// This ensures wizard/chat-captured data takes priority.
  void mergeFromRemoteProfile(Map<String, dynamic> remoteData) {
    if (_profile == null) return;
    final p = _profile!;

    // Only merge fields where local is null/zero and remote has a value.
    final updates = <String, dynamic>{};

    if (p.birthYear == 0 && remoteData['birthYear'] != null) {
      updates['birthYear'] = remoteData['birthYear'];
    }
    if ((p.canton.isEmpty || p.canton == 'unknown') &&
        remoteData['canton'] != null) {
      updates['canton'] = remoteData['canton'] as String?;
    }
    if (p.gender == null && remoteData['gender'] != null) {
      updates['gender'] = remoteData['gender'] as String?;
    }
    if (p.salaireBrutMensuel <= 0) {
      final grossYearly = (remoteData['incomeGrossYearly'] as num?)?.toDouble();
      if (grossYearly != null && grossYearly > 0) {
        updates['salaireBrutMensuel'] = grossYearly / 12;
      }
    }
    if (p.employmentStatus.isEmpty && remoteData['employmentStatus'] != null) {
      updates['employmentStatus'] = remoteData['employmentStatus'] as String?;
    }

    if (updates.isEmpty) return;

    // Apply updates via copyWith
    _profile = p.copyWith(
      birthYear:
          updates.containsKey('birthYear') ? updates['birthYear'] as int : null,
      canton:
          updates.containsKey('canton') ? updates['canton'] as String? : null,
      gender:
          updates.containsKey('gender') ? updates['gender'] as String? : null,
      salaireBrutMensuel: updates.containsKey('salaireBrutMensuel')
          ? updates['salaireBrutMensuel'] as double
          : null,
      employmentStatus: updates.containsKey('employmentStatus')
          ? updates['employmentStatus'] as String?
          : null,
    );
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Phase 12-01 — Optimistic update of [CoachProfile.voiceCursorPreference].
  ///
  /// Updates local state immediately + notifies listeners (optimistic). Then
  /// awaits [remoteSync] (injected for testability — defaults to a no-op
  /// success since no `/api/v1/profile` PATCH endpoint is wired yet).
  ///
  /// On `false` from [remoteSync], rolls back local state and notifies again.
  /// Returns `true` on success, `false` on rollback.
  ///
  /// Pure provider — does NOT show toasts or fire analytics. Callers (UI) own
  /// the toast + analytics decisions per D-09 (event source distinguishes
  /// first-launch vs settings).
  Future<bool> setVoiceCursorPreference(
    VoicePreference next, {
    Future<bool> Function(VoicePreference value)? remoteSync,
  }) async {
    final current = _profile;
    if (current == null) return false;
    if (current.voiceCursorPreference == next) return true;

    final previous = current.voiceCursorPreference;

    // Optimistic local update.
    _profile = current.copyWith(voiceCursorPreference: next);
    notifyListeners();

    // Default sync = no-op success (Plan 12-04 will wire real PATCH).
    final ok = remoteSync == null ? true : await remoteSync(next);

    if (!ok) {
      // Rollback.
      _profile = _profile?.copyWith(voiceCursorPreference: previous);
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Replace the current profile with an updated one and persist via answers.
  void updateProfile(CoachProfile updated) {
    final normalized = _withExplicitCashMarkerFromSource(updated);
    final previousStatus = _profile?.etatCivil;
    _profile = normalized;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
    // FIX-045: Persist ALL profile fields.
    _persistFullProfile(normalized);
    // FIX-HIGH-1: Invalidate coach cache on profile change (was never called).
    CoachCacheService.invalidate(InvalidationTrigger.profileUpdate);
    // Also invalidate daily narrative cache so greeting / topTip / scenarios
    // pick up new profile data instead of showing stale pre-scan copy.
    CoachNarrativeService.invalidateCache(profile: normalized);
    // FIX-HIGH-2: Invalidate CapMemory on significant profile change
    // to prevent stale caps from being re-served.
    CapMemoryStore.load().then((mem) {
      CapMemoryStore.save(mem.copyWith(
        lastCapServed: null,
        lastCapDate: null,
      ));
    }).catchError((Object e) {
      debugPrint('[CoachProfileProvider] CapMemory invalidation failed: $e');
    });
    // FIX-097: If civil status changed to non-coupled, dissolve household.
    if (previousStatus != null &&
        previousStatus != normalized.etatCivil &&
        !normalized.hasPartnerContext &&
        !normalized.civilStatusNeedsConfirmation) {
      // Clear local household cache after separation. Partner answers are
      // cleared by _persistFullProfile() based on civil status, so this
      // fire-and-forget cache cleanup cannot resurrect a ghost conjoint.
      _clearHouseholdCacheAfterSeparation();
    }
  }

  bool _isExplicitCashSource(ProfileDataSource? source) =>
      source == ProfileDataSource.userInput ||
      source == ProfileDataSource.openBanking ||
      source == ProfileDataSource.certificate ||
      source == ProfileDataSource.crossValidated;

  bool _hasExplicitCashSource(CoachProfile profile) =>
      _isExplicitCashSource(profile.dataSources['patrimoine.epargneLiquide']);

  Map<String, dynamic> _withExplicitCashAnswerSource(
    Map<String, dynamic> answers, {
    ProfileDataSource source = ProfileDataSource.userInput,
  }) {
    if (!answers.containsKey('q_cash_total')) {
      return answers;
    }
    final cashTotal = _asNum(answers['q_cash_total']);
    if (cashTotal == null || cashTotal < 0) {
      return answers;
    }
    return Map<String, dynamic>.from(answers)
      ..putIfAbsent('_coach_cash_total_source', () => source.name)
      ..['q_cash_total_unconfirmed_legacy'] = null;
  }

  CoachProfile _withExplicitCashMarkerFromSource(CoachProfile profile) {
    if (!_hasExplicitCashSource(profile) ||
        profile.userProvidedFields.contains('liquidSavingsAmount')) {
      return profile;
    }
    return profile.copyWith(userProvidedFields: {
      ...profile.userProvidedFields,
      'liquidSavings',
      'liquidSavingsAmount',
    });
  }

  /// Best-effort separation cleanup for the legacy household cache.
  Future<void> _clearHouseholdCacheAfterSeparation() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('_household_data');
    } catch (_) {
      // Best-effort: SharedPreferences failure is non-fatal.
    }
  }

  void _clearPartnerAnswers(Map<String, dynamic> answers) {
    final keysToRemove = answers.keys
        .where((k) => k.startsWith('q_partner_') || k.startsWith('q_spouse_'))
        .toList();
    for (final key in keysToRemove) {
      answers.remove(key);
    }
    // Keep this null marker so SecureWizardStore deletes encrypted values too.
    answers['q_partner_net_income_chf'] = null;
    answers['q_partner_salary'] = null;
  }

  bool _setsNonCoupledCivilStatus(Map<String, dynamic> answers) {
    if (!answers.containsKey('q_civil_status')) return false;
    final value = answers['q_civil_status'];
    if (value is! String) return true;
    switch (value.trim().toLowerCase()) {
      case 'marie':
      case 'marié': // lint-ignore: accepted legacy input
      case 'married':
      case 'registered_partner':
      case 'registered_partnership':
      case 'registeredpartnership':
      case 'partenariat_enregistre':
      case 'partenariat_enregistré': // lint-ignore: accepted input alias
      case 'concubinage':
      case 'cohabiting':
      // Ambiguous legacy status keeps partner facts for reconfirmation, but
      // CoachProfile legal predicates remain disabled.
      case 'partenariat':
      case 'pacs':
      case 'civil_union':
      case 'civil union':
      case 'foreign_civil_union':
      case 'foreign_registered_partner':
      case 'foreign_registered_partnership':
        return false;
      default:
        return true;
    }
  }

  Future<void> _persistFullProfile(CoachProfile profile) async {
    final answers = await ReportPersistenceService.loadAnswers();
    // Core fields
    if (profile.canton.isNotEmpty) answers['q_canton'] = profile.canton;
    if (profile.commune != null && profile.commune!.isNotEmpty) {
      answers['q_commune'] = profile.commune;
    }
    if (profile.gender != null && profile.gender!.isNotEmpty) {
      answers['q_gender'] = profile.gender;
    }
    // FIX-096: Persist etatCivil (divorce was lost on restart).
    answers['q_civil_status'] = profile.civilStatusNeedsConfirmation
        ? (profile.civilStatusRawValue ?? 'partenariat')
        : profile.etatCivil.name;
    answers['q_salaire'] = profile.salaireBrutMensuel;
    answers['q_nombre_mois'] = profile.nombreDeMois;
    final grossAnnual = IncomeConversionCalculator.annualGrossFromMonthly(
      monthlyGross: profile.salaireBrutMensuel,
      months: profile.nombreDeMois,
    );
    answers['q_gross_salary_annual'] = grossAnnual;
    if (grossAnnual > 0 && profile.bonusPourcentage != null) {
      answers['q_annual_bonus'] =
          IncomeConversionCalculator.annualBonusFromPercentage(
        annualGross: grossAnnual,
        bonusPercentage: profile.bonusPourcentage!,
      );
    } else {
      answers.remove('q_annual_bonus');
    }
    if (profile.employmentRate !=
        IncomeConversionCalculator.fullTimeEmploymentRatePercent) {
      answers['q_employment_rate'] = profile.employmentRate;
    } else {
      answers.remove('q_employment_rate');
    }
    if (profile.employmentStatus.isNotEmpty) {
      answers['q_employment_status'] = profile.employmentStatus;
    }
    if (profile.selfEmployedNetIncome != null) {
      answers['q_self_employed_income'] = profile.selfEmployedNetIncome;
      answers['q_net_income_period_chf'] = profile.selfEmployedNetIncome;
      answers['q_pay_frequency'] = 'yearly';
    }
    if (profile.companyProfitAnnual != null) {
      answers['q_company_profit_annual_chf'] = profile.companyProfitAnnual;
    }
    // Prevoyance
    if (profile.prevoyance.hasPensionFund != null) {
      answers['q_has_pension_fund'] =
          profile.prevoyance.hasPensionFund! ? 'yes' : 'no';
    }
    if (profile.prevoyance.hasVoluntaryLpp != null) {
      answers['q_has_voluntary_lpp'] =
          profile.prevoyance.hasVoluntaryLpp! ? 'yes' : 'no';
    }
    if (profile.prevoyance.avoirLppTotal != null) {
      answers['q_avoir_lpp'] = profile.prevoyance.avoirLppTotal;
    }
    if (profile.prevoyance.nombre3a > 0) {
      answers['q_nombre_3a'] = profile.prevoyance.nombre3a;
    }
    if (profile.prevoyance.totalEpargne3a > 0) {
      answers['q_3a_total'] = profile.prevoyance.totalEpargne3a;
    }
    // Patrimoine
    // Only an explicit q_cash_total fact may write back as cash; callers that
    // set a real cash amount via copyWith must mark liquidSavingsAmount or
    // provide an explicit cash provenance.
    final existingCashTotal = _asNum(answers['q_cash_total']);
    final hasExistingExplicitCash =
        existingCashTotal != null && existingCashTotal >= 0;
    final hasExplicitCashTotal =
        profile.userProvidedFields.contains('liquidSavingsAmount') ||
            hasExistingExplicitCash ||
            _hasExplicitCashSource(profile);
    if (hasExplicitCashTotal) {
      answers['q_cash_total'] = profile.patrimoine.epargneLiquide;
      answers['_coach_cash_total_source'] =
          (profile.dataSources['patrimoine.epargneLiquide'] ??
                  ProfileDataSource.userInput)
              .name;
    }
    answers['q_investissements'] = profile.patrimoine.investissements;
    if (profile.patrimoine.wealthEstimate != null) {
      answers['q_wealth_estimate'] = profile.patrimoine.wealthEstimate;
    }
    // Housing
    _persistHousingFieldsSync(answers, profile);
    // Target retirement
    if (profile.targetRetirementAge != null) {
      answers['q_target_retirement_age'] = profile.targetRetirementAge;
    }
    // FIX-P0-2: Persist conjoint (spouse) data — was previously lost on restart.
    // fromWizardAnswers() reads these keys to rebuild ConjointProfile.
    final preservesPartnerFacts =
        profile.hasPartnerContext || profile.civilStatusNeedsConfirmation;
    if (preservesPartnerFacts && profile.conjoint != null) {
      final c = profile.conjoint!;
      if (c.salaireBrutMensuel != null) {
        // Store as net (reverse the brut→net from fromWizardAnswers)
        const socialChargesRate =
            IncomeConversionCalculator.fallbackSwissSocialChargesRate;
        answers['q_partner_net_income_chf'] =
            c.salaireBrutMensuel! * (1 - socialChargesRate);
      }
      if (c.birthYear != null) {
        answers['q_partner_birth_year'] = c.birthYear;
      }
      if (c.employmentStatus != null) {
        answers['q_partner_employment_status'] = c.employmentStatus;
      }
      if (c.firstName != null) {
        answers['q_partner_firstname'] = c.firstName;
      }
      if (c.gender != null) {
        answers['q_partner_gender'] = c.gender;
      }
      if (c.nationality != null) {
        answers['q_partner_nationality'] = c.nationality;
      }
      if (c.canton != null) {
        answers['q_partner_canton'] = c.canton;
      }
      if (c.nombreEnfants != null) {
        answers['q_partner_enfants'] = c.nombreEnfants;
      }
      if (c.prevoyance?.anneesContribuees != null) {
        answers['q_spouse_avs_contribution_years'] =
            c.prevoyance!.anneesContribuees;
      }
    } else {
      _clearPartnerAnswers(answers);
    }
    await ReportPersistenceService.saveAnswers(answers);
  }

  /// W15: Create a financial snapshot from the current profile state.
  /// Fire-and-forget — errors are logged, never surfaced to the user.
  void _createSnapshotFromProfile(String trigger) {
    final p = _profile;
    if (p == null) return;
    SnapshotService.createSnapshot(
      trigger: trigger,
      age: p.age,
      grossIncome: p.salaireBrutMensuel * p.nombreDeMois,
      canton: p.canton,
      replacementRatio:
          0.0, // Computed by projection services, not available here
      monthsLiquidity: 0.0, // Requires budget data not in CoachProfile
      taxSavingPotential: 0.0, // Requires tax simulation
      confidenceScore: 0.0, // Requires projection
    );
  }

  void _persistHousingFieldsSync(
      Map<String, dynamic> answers, CoachProfile profile) {
    if (profile.housingStatus != null) {
      answers['q_housing_status'] = profile.housingStatus;
    }
    if (profile.riskTolerance != null) {
      answers['q_risk_tolerance'] = profile.riskTolerance;
    }
    if (profile.realEstateProject != null) {
      answers['q_real_estate_project'] = profile.realEstateProject;
    }
  }

  /// Update the user's primary focus/intention from Pulse screen.
  /// Does NOT trigger full profile recomputation — only persists the new focus.
  Future<void> updatePrimaryFocus(String focus) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      primaryFocus: focus,
      updatedAt: DateTime.now(),
    );
    // Persist to wizard answers for survival across app restart.
    _lastAnswers['q_primary_focus'] = focus;
    _profileUpdatedSinceBudget = true;
    await ReportPersistenceService.saveAnswers(_lastAnswers);
    notifyListeners();
  }

  /// Ajoute un check-in mensuel au profil et le persiste.
  // TODO(P2): Sync monthly check-ins to backend for cross-device access
  Future<void> addCheckIn(MonthlyCheckIn checkIn) async {
    if (_profile == null) return;
    final updated = [..._profile!.checkIns, checkIn];
    _profile = _profile!.copyWithCheckIns(updated);
    // Persist BEFORE notify so downstream listeners see consistent state
    await ReportPersistenceService.saveCheckIns(
      updated.map((ci) => ci.toJson()).toList(),
    );

    // W15: Auto-trigger financial snapshot after each check-in
    _createSnapshotFromProfile('check_in');

    notifyListeners();
  }

  /// Met a jour les contributions dans le profil et les persiste.
  Future<void> updateContributions(
      List<PlannedMonthlyContribution> contributions) async {
    if (_profile == null) return;
    _profile = _profile!.copyWithContributions(contributions);
    await ReportPersistenceService.saveContributions(
      contributions.map((c) => c.toJson()).toList(),
    );
    notifyListeners();
  }

  /// Ajoute une contribution au profil.
  void addContribution(PlannedMonthlyContribution contribution) {
    if (_profile == null) return;
    final updated = [..._profile!.plannedContributions, contribution];
    _profile = _profile!.copyWithContributions(updated);
    notifyListeners();
  }

  /// Supprime une contribution par index.
  void removeContribution(int index) {
    if (_profile == null) return;
    final updated =
        List<PlannedMonthlyContribution>.from(_profile!.plannedContributions);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      _profile = _profile!.copyWithContributions(updated);
      notifyListeners();
    }
  }

  /// Sauvegarde le score actuel pour la tendance du mois suivant.
  Future<void> saveCurrentScore(int score) async {
    _previousScore = score;
    await ReportPersistenceService.saveLastScore(score);
    // Recharger l'historique pour inclure la nouvelle entree
    _scoreHistory = await ReportPersistenceService.loadScoreHistory();
    notifyListeners();
  }

  /// Met a jour le profil depuis le check-up annuel (annual refresh).
  /// Seuls les champs non-null sont mis a jour.
  /// Persiste les reponses wizard mises a jour et recalcule le score.
  Future<void> updateFromRefresh({
    double? salaireBrutMensuel,
    String? employmentStatus,
    double? avoirLppTotal,
    double? totalEpargne3a,
    String? realEstateProject,
    String? familyChange,
    String? riskTolerance,
  }) async {
    if (_profile == null) return;

    final p = _profile!;

    // Build updated prevoyance if LPP or 3a changed
    final updatedPrevoyance = PrevoyanceProfile(
      anneesContribuees: p.prevoyance.anneesContribuees,
      lacunesAVS: p.prevoyance.lacunesAVS,
      renteAVSEstimeeMensuelle: p.prevoyance.renteAVSEstimeeMensuelle,
      nomCaisse: p.prevoyance.nomCaisse,
      avoirLppTotal: avoirLppTotal ?? p.prevoyance.avoirLppTotal,
      avoirLppObligatoire: p.prevoyance.avoirLppObligatoire,
      avoirLppSurobligatoire: p.prevoyance.avoirLppSurobligatoire,
      rachatMaximum: p.prevoyance.rachatMaximum,
      rachatEffectue: p.prevoyance.rachatEffectue,
      tauxConversion: p.prevoyance.tauxConversion,
      tauxConversionSuroblig: p.prevoyance.tauxConversionSuroblig,
      rendementCaisse: p.prevoyance.rendementCaisse,
      salaireAssure: p.prevoyance.salaireAssure,
      ramd: p.prevoyance.ramd,
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: totalEpargne3a ?? p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
      librePassage: p.prevoyance.librePassage,
    );

    _profile = p.copyWith(
      salaireBrutMensuel: salaireBrutMensuel ?? p.salaireBrutMensuel,
      employmentStatus: employmentStatus ?? p.employmentStatus,
      prevoyance: updatedPrevoyance,
      riskTolerance: riskTolerance ?? p.riskTolerance,
      realEstateProject: realEstateProject ?? p.realEstateProject,
      updatedAt: DateTime.now(),
    );

    // Persist updated wizard answers with refreshed fields
    final answers = await ReportPersistenceService.loadAnswers();
    if (salaireBrutMensuel != null) {
      // Convert brut to net for wizard format using NetIncomeBreakdown
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: salaireBrutMensuel * 12,
        canton: _profile?.canton ?? 'ZH',
        age: _profile?.age ?? 45,
      );
      answers['q_net_income_period_chf'] = breakdown.monthlyNetPayslip;
    }
    if (employmentStatus != null) {
      answers['q_employment_status'] = employmentStatus;
    }
    if (riskTolerance != null) {
      answers['q_risk_tolerance'] = riskTolerance;
    }
    if (realEstateProject != null) {
      answers['q_real_estate_project'] = realEstateProject;
    }

    // BUG 1 FIX: Persister updatedAt pour que le banner 11 mois fonctionne
    // Sans ca, fromWizardAnswers() reconstruit updatedAt = DateTime.now()
    // a chaque restart et daysSinceUpdate >= 330 ne sera jamais vrai.
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();

    // Preserve createdAt on the first refresh.
    if (answers['_coach_created_at'] == null && p.createdAt != p.updatedAt) {
      answers['_coach_created_at'] = p.createdAt.toIso8601String();
    }

    // BUG 2 FIX: Persister LPP et 3a (pas de cle wizard standard pour ces valeurs)
    if (avoirLppTotal != null) {
      answers['_coach_avoir_lpp'] = avoirLppTotal;
    }
    if (totalEpargne3a != null) {
      answers['_coach_total_3a'] = totalEpargne3a;
    }

    // BUG 3 FIX: Persister familyChange (etait accepte mais jamais utilise)
    if (familyChange != null && familyChange != 'Aucun') {
      answers['_coach_family_change'] = familyChange;
    }

    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
    notifyListeners();
    _syncToBackend(); // Fire-and-forget, does not block UI
  }

  // ════════════════════════════════════════════════════════════════
  //  DOCUMENT EXTRACTION → PROFILE INJECTION
  // ════════════════════════════════════════════════════════════════

  /// Met a jour le profil depuis l'extraction d'un extrait AVS.
  ///
  /// Mappe les champs AVS extraits vers PrevoyanceProfile.
  /// Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1, Document C
  Future<void> updateFromAvsExtraction(List<ExtractedField> fields) async {
    _profile ??= CoachProfile.defaults();

    final p = _profile!;

    int? anneesContrib;
    int? lacunesCotisation;
    double? renteEstimee;
    double? ramd;
    int? bonificationsEduc;

    for (final field in fields) {
      if (field.profileField == null) continue;
      final value = field.value;

      switch (field.profileField) {
        case 'anneesContribution':
        case 'avsContributionYears':
          if (value is double) anneesContrib = value.round();
          if (value is int) anneesContrib = value;
        case 'lacunesCotisation':
        case 'avsGaps':
          if (value is double) lacunesCotisation = value.round();
          if (value is int) lacunesCotisation = value;
        case 'renteEstimee':
        case 'avsEstimatedPension':
          if (value is double) renteEstimee = value;
          if (value is int) renteEstimee = value.toDouble();
        case 'ramd':
        case 'avsRamd':
          if (value is double) ramd = value;
          if (value is int) ramd = value.toDouble();
        case 'bonificationsEducatives':
        case 'avsEducationCredits':
          if (value is double) bonificationsEduc = value.round();
          if (value is int) bonificationsEduc = value;
      }
    }

    // Build updated prevoyance with real AVS data
    final updatedPrevoyance = PrevoyanceProfile(
      anneesContribuees: anneesContrib ?? p.prevoyance.anneesContribuees,
      lacunesAVS: lacunesCotisation ?? p.prevoyance.lacunesAVS,
      renteAVSEstimeeMensuelle:
          renteEstimee ?? p.prevoyance.renteAVSEstimeeMensuelle,
      nomCaisse: p.prevoyance.nomCaisse,
      avoirLppTotal: p.prevoyance.avoirLppTotal,
      avoirLppObligatoire: p.prevoyance.avoirLppObligatoire,
      avoirLppSurobligatoire: p.prevoyance.avoirLppSurobligatoire,
      rachatMaximum: p.prevoyance.rachatMaximum,
      rachatEffectue: p.prevoyance.rachatEffectue,
      tauxConversion: p.prevoyance.tauxConversion,
      tauxConversionSuroblig: p.prevoyance.tauxConversionSuroblig,
      rendementCaisse: p.prevoyance.rendementCaisse,
      salaireAssure: p.prevoyance.salaireAssure,
      ramd: ramd ?? p.prevoyance.ramd,
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
      librePassage: p.prevoyance.librePassage,
      bonificationsEducatives:
          bonificationsEduc ?? p.prevoyance.bonificationsEducatives,
      projectedRenteLpp: p.prevoyance.projectedRenteLpp,
      projectedCapital65: p.prevoyance.projectedCapital65,
      disabilityCoverage: p.prevoyance.disabilityCoverage,
      deathCoverage: p.prevoyance.deathCoverage,
    );

    // Tag data sources as certificate-confirmed
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (bonificationsEduc != null) {
      updatedSources['prevoyance.bonificationsEducatives'] =
          ProfileDataSource.certificate;
    }
    if (anneesContrib != null) {
      updatedSources['prevoyance.anneesContribuees'] =
          ProfileDataSource.certificate;
    }
    if (lacunesCotisation != null) {
      updatedSources['prevoyance.lacunesAVS'] = ProfileDataSource.certificate;
    }
    if (renteEstimee != null) {
      updatedSources['prevoyance.renteAVSEstimeeMensuelle'] =
          ProfileDataSource.certificate;
    }
    if (ramd != null) {
      updatedSources['prevoyance.ramd'] = ProfileDataSource.certificate;
    }

    // S47: Stamp timestamps for all fields touched by this extraction
    final touchedFields = <String>[];
    if (anneesContrib != null) {
      touchedFields.add('prevoyance.anneesContribuees');
    }
    if (lacunesCotisation != null) {
      touchedFields.add('prevoyance.lacunesAVS');
    }
    if (renteEstimee != null) {
      touchedFields.add('prevoyance.renteAVSEstimeeMensuelle');
    }
    if (ramd != null) {
      touchedFields.add('prevoyance.ramd');
    }
    if (bonificationsEduc != null) {
      touchedFields.add('prevoyance.bonificationsEducatives');
    }
    final stamp = DateTime.now();
    final valueProfile = p.copyWith(
      prevoyance: updatedPrevoyance,
      dataSources: updatedSources,
      updatedAt: stamp,
    );
    final nextProfile = _withStampedProvenance(
      valueProfile,
      touchedFields,
      source: ProfileDataSource.certificate,
      sourceDate: null,
      updatedAt: stamp,
    );

    // Persist to wizard answers
    final answers = await ReportPersistenceService.loadAnswers();
    if (anneesContrib != null) {
      answers['q_avs_contribution_years'] = anneesContrib;
    }
    if (lacunesCotisation != null) {
      answers['_coach_avs_lacunes'] = lacunesCotisation;
    }
    if (renteEstimee != null) {
      answers['_coach_avs_rente_estimee'] = renteEstimee;
    }
    if (ramd != null) answers['_coach_avs_ramd'] = ramd;
    if (bonificationsEduc != null) {
      answers['_coach_avs_bonifications_educatives'] = bonificationsEduc;
    }
    answers['_coach_updated_at'] = stamp.toIso8601String();
    _persistTimestamps(answers, nextProfile.dataTimestamps);
    _persistProvenance(answers, nextProfile);
    if (touchedFields.isNotEmpty) {
      // Legacy trace only. Reload never treats this document-wide marker as
      // field provenance because it carries neither field scope nor source date.
      answers['_coach_avs_source'] = 'document_scan';
    }
    await ReportPersistenceService.saveAnswers(answers);

    _lastAnswers = _copyAnswers(answers);
    _profile = nextProfile;
    _profileUpdatedSinceBudget = true;
    CoachNarrativeService.invalidateCache(profile: _profile);
    notifyListeners();
  }

  /// Inject salary certificate extraction into CoachProfile.
  ///
  /// Stores: salaireBrutMensuel, nombreDeMois, bonusPourcentage.
  /// Tags dataSources as certificate. Stamps timestamps.
  Future<void> updateFromSalaryExtraction(List<ExtractedField> fields) async {
    final p = _profile ?? CoachProfile.defaults();
    double? salaireBrut;
    int? nombreMois;
    double? bonus;
    double?
        tauxActivite; // ignore: unused_local_variable — extracted for future use

    for (final field in fields) {
      if (field.profileField == null) continue;
      switch (field.profileField) {
        case 'salaireBrutMensuel':
          if (field.value is num) {
            salaireBrut = (field.value as num).toDouble();
          }
        case 'nombreMois' || 'nombreDeMois':
          if (field.value is num) {
            nombreMois = (field.value as num).toInt();
          }
        case 'bonus' || 'bonusPourcentage':
          if (field.value is num) {
            bonus = (field.value as num).toDouble();
          }
        case 'tauxActivite':
          if (field.value is num) {
            tauxActivite = (field.value as num).toDouble();
          }
      }
    }

    // Tag data sources
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (salaireBrut != null) {
      updatedSources['salaireBrutMensuel'] = ProfileDataSource.certificate;
    }
    if (nombreMois != null) {
      updatedSources['nombreDeMois'] = ProfileDataSource.certificate;
    }

    // Stamp timestamps
    final touchedFields = <String>[];
    if (salaireBrut != null) touchedFields.add('salaireBrutMensuel');
    if (nombreMois != null) touchedFields.add('nombreDeMois');
    if (bonus != null) touchedFields.add('bonusPourcentage');
    final stamp = DateTime.now();
    final valueProfile = p.copyWith(
      salaireBrutMensuel: salaireBrut ?? p.salaireBrutMensuel,
      nombreDeMois: (nombreMois ?? p.nombreDeMois).toDouble(),
      bonusPourcentage: bonus ?? p.bonusPourcentage,
      dataSources: updatedSources,
      updatedAt: stamp,
    );
    final nextProfile = _withStampedProvenance(
      valueProfile,
      touchedFields,
      source: ProfileDataSource.certificate,
      sourceDate: null,
      updatedAt: stamp,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    if (salaireBrut != null || nombreMois != null) {
      answers['q_gross_salary_annual'] =
          nextProfile.salaireBrutMensuel * nextProfile.nombreDeMois;
    }
    if (nombreMois != null) {
      answers['q_nombre_mois'] = nombreMois;
    }
    if (bonus != null) {
      answers['q_bonus_percentage'] = bonus;
      answers.remove('q_annual_bonus');
    }
    answers['_coach_updated_at'] = stamp.toIso8601String();
    _persistTimestamps(answers, nextProfile.dataTimestamps);
    _persistProvenance(answers, nextProfile);
    answers['_coach_salary_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _lastAnswers = _copyAnswers(answers);
    _profile = nextProfile;
    _profileUpdatedSinceBudget = true;
    CoachNarrativeService.invalidateCache(profile: _profile);
    notifyListeners();
  }

  /// Met a jour un ou plusieurs champs du profil depuis l'edition inline
  /// sur l'apercu financier. Persiste les answers wizard.
  ///
  /// Tags all updated fields as [ProfileDataSource.userInput].
  Future<void> updateInline({
    double? salaireBrutMensuel,
    double? avoirLppTotal,
    int? nombre3a,
    double? totalEpargne3a,

    /// Rachat LPP mensuel planifié (CHF/mois). Crée ou met à jour la
    /// PlannedMonthlyContribution 'lpp_buyback_user'. Mis à 0 supprime
    /// la contribution. Utilisé par ForecasterService via
    /// profile.totalLppBuybackMensuel pour les projections LPP.
    double? rachatLppMensuel,
    double? epargneLiquide,
    double? investissements,
    double? loyer,
    double? assuranceMaladie,
    double? electricite,
    double? transport,
    double? telecom,
    double? fraisMedicaux,
    double? autresDepensesFixes,
    double? hypotheque,
    double? creditConsommation,
    double? leasing,
    double? autresDettes,
    double? rendementCaisse,
  }) async {
    if (_profile == null) return;
    final p = _profile!;

    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);

    PrevoyanceProfile? updatedPrev;
    if (avoirLppTotal != null ||
        totalEpargne3a != null ||
        nombre3a != null ||
        rendementCaisse != null) {
      updatedPrev = PrevoyanceProfile(
        anneesContribuees: p.prevoyance.anneesContribuees,
        lacunesAVS: p.prevoyance.lacunesAVS,
        renteAVSEstimeeMensuelle: p.prevoyance.renteAVSEstimeeMensuelle,
        nomCaisse: p.prevoyance.nomCaisse,
        avoirLppTotal: avoirLppTotal ?? p.prevoyance.avoirLppTotal,
        avoirLppObligatoire: p.prevoyance.avoirLppObligatoire,
        avoirLppSurobligatoire: p.prevoyance.avoirLppSurobligatoire,
        rachatMaximum: p.prevoyance.rachatMaximum,
        rachatEffectue: p.prevoyance.rachatEffectue,
        tauxConversion: p.prevoyance.tauxConversion,
        tauxConversionSuroblig: p.prevoyance.tauxConversionSuroblig,
        rendementCaisse: rendementCaisse ?? p.prevoyance.rendementCaisse,
        salaireAssure: p.prevoyance.salaireAssure,
        ramd: p.prevoyance.ramd,
        nombre3a: nombre3a ?? p.prevoyance.nombre3a,
        totalEpargne3a: totalEpargne3a ?? p.prevoyance.totalEpargne3a,
        comptes3a: p.prevoyance.comptes3a,
        canContribute3a: p.prevoyance.canContribute3a,
        librePassage: p.prevoyance.librePassage,
      );
      if (avoirLppTotal != null) {
        updatedSources['prevoyance.avoirLppTotal'] =
            ProfileDataSource.userInput;
      }
      if (totalEpargne3a != null) {
        updatedSources['prevoyance.totalEpargne3a'] =
            ProfileDataSource.userInput;
      }
      if (rendementCaisse != null) {
        updatedSources['prevoyance.rendementCaisse'] =
            ProfileDataSource.userInput;
      }
    }

    PatrimoineProfile? updatedPat;
    if (epargneLiquide != null || investissements != null) {
      updatedPat = p.patrimoine.copyWith(
        epargneLiquide: epargneLiquide,
        investissements: investissements,
      );
      if (epargneLiquide != null) {
        updatedSources['patrimoine.epargneLiquide'] =
            ProfileDataSource.userInput;
      }
      if (investissements != null) {
        updatedSources['patrimoine.investissements'] =
            ProfileDataSource.userInput;
      }
    }

    DepensesProfile? updatedDep;
    if (loyer != null ||
        assuranceMaladie != null ||
        electricite != null ||
        transport != null ||
        telecom != null ||
        fraisMedicaux != null ||
        autresDepensesFixes != null) {
      updatedDep = p.depenses.copyWith(
        loyer: loyer,
        assuranceMaladie: assuranceMaladie,
        electricite: electricite,
        transport: transport,
        telecom: telecom,
        fraisMedicaux: fraisMedicaux,
        autresDepensesFixes: autresDepensesFixes,
      );
      if (loyer != null) {
        updatedSources['depenses.loyer'] = ProfileDataSource.userInput;
      }
      if (assuranceMaladie != null) {
        updatedSources['depenses.assuranceMaladie'] =
            ProfileDataSource.userInput;
      }
      if (electricite != null) {
        updatedSources['depenses.electricite'] = ProfileDataSource.userInput;
      }
      if (transport != null) {
        updatedSources['depenses.transport'] = ProfileDataSource.userInput;
      }
      if (telecom != null) {
        updatedSources['depenses.telecom'] = ProfileDataSource.userInput;
      }
      if (fraisMedicaux != null) {
        updatedSources['depenses.fraisMedicaux'] = ProfileDataSource.userInput;
      }
      if (autresDepensesFixes != null) {
        updatedSources['depenses.autresDepensesFixes'] =
            ProfileDataSource.userInput;
      }
    }

    DetteProfile? updatedDet;
    if (hypotheque != null ||
        creditConsommation != null ||
        leasing != null ||
        autresDettes != null) {
      updatedDet = p.dettes.copyWith(
        hypotheque: hypotheque,
        creditConsommation: creditConsommation,
        leasing: leasing,
        autresDettes: autresDettes,
      );
      if (hypotheque != null) {
        updatedSources['dettes.hypotheque'] = ProfileDataSource.userInput;
      }
      if (creditConsommation != null) {
        updatedSources['dettes.creditConsommation'] =
            ProfileDataSource.userInput;
      }
      if (leasing != null) {
        updatedSources['dettes.leasing'] = ProfileDataSource.userInput;
      }
      if (autresDettes != null) {
        updatedSources['dettes.autresDettes'] = ProfileDataSource.userInput;
      }
    }

    if (salaireBrutMensuel != null) {
      updatedSources['salaireBrutMensuel'] = ProfileDataSource.userInput;
    }

    // S47: Stamp timestamps for all fields touched by this inline edit
    final touchedFields = <String>[
      if (salaireBrutMensuel != null) 'salaireBrutMensuel',
      if (avoirLppTotal != null) 'prevoyance.avoirLppTotal',
      if (totalEpargne3a != null) 'prevoyance.totalEpargne3a',
      if (rendementCaisse != null) 'prevoyance.rendementCaisse',
      if (rachatLppMensuel != null) 'prevoyance.rachatLppMensuel',
      if (epargneLiquide != null) 'patrimoine.epargneLiquide',
      if (investissements != null) 'patrimoine.investissements',
      if (loyer != null) 'depenses.loyer',
      if (assuranceMaladie != null) 'depenses.assuranceMaladie',
      if (electricite != null) 'depenses.electricite',
      if (transport != null) 'depenses.transport',
      if (telecom != null) 'depenses.telecom',
      if (fraisMedicaux != null) 'depenses.fraisMedicaux',
      if (autresDepensesFixes != null) 'depenses.autresDepensesFixes',
      if (hypotheque != null) 'dettes.hypotheque',
      if (creditConsommation != null) 'dettes.creditConsommation',
      if (leasing != null) 'dettes.leasing',
      if (autresDettes != null) 'dettes.autresDettes',
    ];
    final stamp = DateTime.now();

    // Rachat LPP mensuel: crée/met à jour ou supprime 'lpp_buyback_user'.
    List<PlannedMonthlyContribution>? updatedContribs;
    if (rachatLppMensuel != null) {
      final existing = List<PlannedMonthlyContribution>.from(
        p.plannedContributions,
      );
      final idx = existing.indexWhere((c) => c.id == 'lpp_buyback_user');
      if (rachatLppMensuel <= 0) {
        if (idx >= 0) existing.removeAt(idx);
      } else if (idx >= 0) {
        existing[idx] = existing[idx].copyWith(amount: rachatLppMensuel);
      } else {
        existing.add(PlannedMonthlyContribution(
          id: 'lpp_buyback_user',
          label: 'Rachat LPP',
          amount: rachatLppMensuel,
          category: 'lpp_buyback',
          isAutomatic: false,
        ));
      }
      updatedContribs = existing;
    }

    final valueProfile = p.copyWith(
      salaireBrutMensuel: salaireBrutMensuel,
      prevoyance: updatedPrev,
      patrimoine: updatedPat,
      depenses: updatedDep,
      dettes: updatedDet,
      plannedContributions: updatedContribs,
      dataSources: updatedSources,
      updatedAt: stamp,
    );
    final nextProfile = _withExplicitCashMarkerFromSource(
      _withStampedProvenance(
        valueProfile,
        touchedFields,
        source: ProfileDataSource.userInput,
        sourceDate: null,
        updatedAt: stamp,
      ),
    );

    final answers = await ReportPersistenceService.loadAnswers();
    if (salaireBrutMensuel != null) {
      answers['q_gross_salary_annual'] =
          salaireBrutMensuel * nextProfile.nombreDeMois;
    }
    if (avoirLppTotal != null) answers['_coach_avoir_lpp'] = avoirLppTotal;
    if (rendementCaisse != null) {
      answers['_coach_rendement_caisse'] = rendementCaisse;
    }
    if (totalEpargne3a != null) answers['_coach_total_3a'] = totalEpargne3a;
    if (rachatLppMensuel != null) {
      answers['_coach_rachat_lpp_mensuel'] = rachatLppMensuel;
    }
    if (epargneLiquide != null) {
      answers['q_cash_total'] = epargneLiquide;
      answers['_coach_cash_total_source'] = ProfileDataSource.userInput.name;
      answers['q_cash_total_unconfirmed_legacy'] = null;
    }
    if (investissements != null) {
      answers['q_investments_total'] = investissements;
    }
    if (loyer != null) answers['q_housing_cost_period_chf'] = loyer;
    if (assuranceMaladie != null) {
      answers['q_lamal_premium_monthly_chf'] = assuranceMaladie;
    }
    if (electricite != null) {
      answers['_coach_depenses_electricite'] = electricite;
    }
    if (transport != null) answers['_coach_depenses_transport'] = transport;
    if (telecom != null) answers['_coach_depenses_telecom'] = telecom;
    if (fraisMedicaux != null) {
      answers['_coach_depenses_frais_medicaux'] = fraisMedicaux;
    }
    if (autresDepensesFixes != null) {
      answers['_coach_depenses_autres'] = autresDepensesFixes;
    }
    if (hypotheque != null) {
      answers['_coach_dettes_hypotheque'] = hypotheque;
    }
    if (creditConsommation != null) {
      answers['_coach_dettes_credit'] = creditConsommation;
    }
    if (leasing != null) {
      answers['_coach_dettes_leasing'] = leasing;
    }
    if (autresDettes != null) {
      answers['_coach_dettes_autres'] = autresDettes;
    }
    answers['_coach_updated_at'] = stamp.toIso8601String();
    _persistTimestamps(answers, nextProfile.dataTimestamps);
    _persistProvenance(answers, nextProfile);
    await ReportPersistenceService.saveAnswers(answers);

    _lastAnswers = _copyAnswers(answers);
    _profile = nextProfile;
    _profileUpdatedSinceBudget = true;
    CoachNarrativeService.invalidateCache(profile: _profile);
    notifyListeners();
  }

  /// Met a jour le profil depuis les donnees bancaires Open Banking (bLink).
  ///
  /// Mappe les soldes de comptes et depenses categorisees vers CoachProfile.
  /// Ne met a jour que les champs pour lesquels les donnees bancaires sont
  /// plus fiables que la source actuelle (ne downgrade jamais certificate).
  ///
  /// Tags all updated fields as [ProfileDataSource.openBanking] (conf. 1.00).
  /// Reference: DATA_ACQUISITION_STRATEGY.md — Channel 3
  Future<void> updateFromOpenBanking({
    required List<Map<String, dynamic>> accounts,
    required Map<String, double> categoryTotals,
  }) async {
    if (_profile == null) return;
    final p = _profile!;

    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);

    // ── 1. Extract balances by account type ──────────────────
    double epargneLiquide = 0;
    double investissements = 0;
    double epargne3a = 0;
    var hasLiquidAccount = false;

    for (final acct in accounts) {
      final balance = (acct['balance'] as num?)?.toDouble() ?? 0;
      final type = acct['accountType'] as String? ?? '';
      switch (type) {
        case 'checking':
        case 'savings':
          hasLiquidAccount = true;
          epargneLiquide += balance;
        case '3a':
          epargne3a += balance;
        case 'securities':
          investissements += balance;
      }
    }

    // ── 2. Extract monthly expenses from categories ──────────
    final loyer =
        _safeExpense(categoryTotals['logement'], p.salaireBrutMensuel, 0.50);
    final assurance =
        _safeExpense(categoryTotals['assurances'], p.salaireBrutMensuel, 0.12);
    final electricite =
        _safeExpense(categoryTotals['energie'], p.salaireBrutMensuel, 0.05);
    final transport =
        _safeExpense(categoryTotals['transport'], p.salaireBrutMensuel, 0.10);
    final telecom =
        _safeExpense(categoryTotals['telecom'], p.salaireBrutMensuel, 0.05);
    final fraisMedicaux =
        _safeExpense(categoryTotals['sante'], p.salaireBrutMensuel, 0.10);
    final hypotheque =
        _safeExpense(categoryTotals['hypotheque'], p.salaireBrutMensuel, 0.50);

    // ── 3. Build updated sub-profiles ────────────────────────
    final updatedPat = p.patrimoine.copyWith(
      epargneLiquide: hasLiquidAccount ? epargneLiquide : null,
      investissements: investissements > 0 ? investissements : null,
    );

    PrevoyanceProfile? updatedPrev;
    if (epargne3a > 0) {
      updatedPrev = PrevoyanceProfile(
        anneesContribuees: p.prevoyance.anneesContribuees,
        lacunesAVS: p.prevoyance.lacunesAVS,
        renteAVSEstimeeMensuelle: p.prevoyance.renteAVSEstimeeMensuelle,
        nomCaisse: p.prevoyance.nomCaisse,
        avoirLppTotal: p.prevoyance.avoirLppTotal,
        avoirLppObligatoire: p.prevoyance.avoirLppObligatoire,
        avoirLppSurobligatoire: p.prevoyance.avoirLppSurobligatoire,
        rachatMaximum: p.prevoyance.rachatMaximum,
        rachatEffectue: p.prevoyance.rachatEffectue,
        tauxConversion: p.prevoyance.tauxConversion,
        tauxConversionSuroblig: p.prevoyance.tauxConversionSuroblig,
        rendementCaisse: p.prevoyance.rendementCaisse,
        salaireAssure: p.prevoyance.salaireAssure,
        ramd: p.prevoyance.ramd,
        nombre3a: p.prevoyance.nombre3a,
        totalEpargne3a: epargne3a,
        comptes3a: p.prevoyance.comptes3a,
        canContribute3a: p.prevoyance.canContribute3a,
        librePassage: p.prevoyance.librePassage,
      );
    }

    final updatedDep = p.depenses.copyWith(
      loyer: loyer,
      assuranceMaladie: assurance,
      electricite: electricite,
      transport: transport,
      telecom: telecom,
      fraisMedicaux: fraisMedicaux,
    );

    final updatedDet =
        hypotheque != null ? p.dettes.copyWith(hypotheque: hypotheque) : null;

    // ── 4. Tag all updated fields as openBanking ─────────────
    if (hasLiquidAccount) {
      updatedSources['patrimoine.epargneLiquide'] =
          ProfileDataSource.openBanking;
    }
    if (investissements > 0) {
      updatedSources['patrimoine.investissements'] =
          ProfileDataSource.openBanking;
    }
    if (epargne3a > 0) {
      updatedSources['prevoyance.totalEpargne3a'] =
          ProfileDataSource.openBanking;
    }
    if (loyer != null) {
      updatedSources['depenses.loyer'] = ProfileDataSource.openBanking;
    }
    if (assurance != null) {
      updatedSources['depenses.assuranceMaladie'] =
          ProfileDataSource.openBanking;
    }
    if (electricite != null) {
      updatedSources['depenses.electricite'] = ProfileDataSource.openBanking;
    }
    if (transport != null) {
      updatedSources['depenses.transport'] = ProfileDataSource.openBanking;
    }
    if (telecom != null) {
      updatedSources['depenses.telecom'] = ProfileDataSource.openBanking;
    }
    if (fraisMedicaux != null) {
      updatedSources['depenses.fraisMedicaux'] = ProfileDataSource.openBanking;
    }
    if (hypotheque != null) {
      updatedSources['dettes.hypotheque'] = ProfileDataSource.openBanking;
    }

    // S47: Stamp timestamps for all fields touched by open banking sync
    final touchedFields = <String>[
      if (hasLiquidAccount) 'patrimoine.epargneLiquide',
      if (investissements > 0) 'patrimoine.investissements',
      if (epargne3a > 0) 'prevoyance.totalEpargne3a',
      if (loyer != null) 'depenses.loyer',
      if (assurance != null) 'depenses.assuranceMaladie',
      if (electricite != null) 'depenses.electricite',
      if (transport != null) 'depenses.transport',
      if (telecom != null) 'depenses.telecom',
      if (fraisMedicaux != null) 'depenses.fraisMedicaux',
      if (hypotheque != null) 'dettes.hypotheque',
    ];
    final stamp = DateTime.now();
    final updatedTimestamps = _stampTimestamps(
      p.dataTimestamps,
      touchedFields,
      now: stamp,
    );

    // ── 5. Apply update ──────────────────────────────────────
    final valueProfile = _withExplicitCashMarkerFromSource(p.copyWith(
      prevoyance: updatedPrev,
      patrimoine: updatedPat,
      depenses: updatedDep,
      dettes: updatedDet,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: stamp,
    ));
    final nextProfile = _withStampedProvenance(
      valueProfile,
      touchedFields,
      source: ProfileDataSource.openBanking,
      sourceDate: null,
      updatedAt: stamp,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    if (hasLiquidAccount) {
      answers['q_cash_total'] = epargneLiquide;
      answers['_coach_cash_total_source'] = ProfileDataSource.openBanking.name;
      answers['q_cash_total_unconfirmed_legacy'] = null;
    }
    if (investissements > 0) {
      answers['_coach_investissements'] = investissements;
    }
    if (epargne3a > 0) {
      answers['_coach_total_3a'] = epargne3a;
    }
    if (loyer != null) {
      answers['_coach_depenses_loyer'] = loyer;
    }
    if (assurance != null) {
      answers['_coach_depenses_assurance'] = assurance;
    }
    if (electricite != null) {
      answers['_coach_depenses_electricite'] = electricite;
    }
    if (transport != null) {
      answers['_coach_depenses_transport'] = transport;
    }
    if (telecom != null) {
      answers['_coach_depenses_telecom'] = telecom;
    }
    if (fraisMedicaux != null) {
      answers['_coach_depenses_frais_medicaux'] = fraisMedicaux;
    }
    if (hypotheque != null) {
      answers['_coach_dettes_hypotheque'] = hypotheque;
    }
    answers['_coach_updated_at'] = stamp.toIso8601String();
    _persistTimestamps(answers, nextProfile.dataTimestamps);
    _persistProvenance(answers, nextProfile);
    answers['_coach_blink_source'] = 'open_banking';
    await ReportPersistenceService.saveAnswers(answers);

    _lastAnswers = _copyAnswers(answers);
    _profile = nextProfile;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Plausibility check: reject expense estimates that exceed a reasonable
  /// ratio of gross monthly salary (e.g., rent > 50% of salary = suspect).
  static double? _safeExpense(
    double? categoryTotal,
    double grossMonthlySalary,
    double maxRatio,
  ) {
    if (categoryTotal == null || categoryTotal <= 0) return null;
    if (grossMonthlySalary <= 0) return categoryTotal;
    final ceiling = grossMonthlySalary * maxRatio * 1.5; // 50% margin
    return categoryTotal <= ceiling ? categoryTotal : null;
  }

  /// Returns a map of pre-filled values from the existing profile for
  /// the onboarding flow. Keys match the onboarding field names.
  ///
  /// Returns an empty map if no profile exists. Only includes non-null
  /// values so the caller can skip fields without data.
  Map<String, dynamic> getSmartFlowDefaults() {
    final p = _profile;
    if (p == null) return const {};

    final defaults = <String, dynamic>{};

    defaults['age'] = p.age;
    defaults['grossSalary'] = p.revenuBrutAnnuel;
    defaults['canton'] = p.canton;
    defaults['situationFamiliale'] = p.etatCivil.name;

    final lppBalance = p.prevoyance.avoirLppTotal;
    if (lppBalance != null && lppBalance > 0) {
      defaults['lppBalance'] = lppBalance;
    }

    final epargne3a = p.prevoyance.totalEpargne3a;
    if (epargne3a > 0) {
      defaults['epargne3a'] = epargne3a;
    }

    final epargneLiquide = p.patrimoine.epargneLiquide;
    if (epargneLiquide > 0) {
      defaults['epargneLiquide'] = epargneLiquide;
    }

    return defaults;
  }

  /// Reset le profil (logout / reset).
  ///
  /// Clears both in-memory state AND persisted wizard data in SharedPreferences
  /// to prevent cross-account data bleed on shared devices.
  void clear() {
    _profile = null;
    _isPartialProfile = false;
    _isLoaded = false;
    _remoteHydrationDone = false;
    _isHydrating = false;
    _previousScore = null;
    _scoreHistory = [];
    _lastAnswers = const {};
    // Fire-and-forget: clear persisted wizard answers + coach history
    // to prevent cross-account bleed. In-memory state is already reset above.
    ReportPersistenceService.clear();
    notifyListeners();
  }
}

/// Safe [CoachProfile] lookup extensions.
///
/// Screens that watch [CoachProfileProvider] for prefill / SafeMode decisions
/// need to tolerate the provider being absent (isolated unit widget tests
/// that pump a single screen without the full shell). These helpers return
/// `null` / `false` instead of throwing [ProviderNotFoundException].
extension CoachProfileContextLookup on BuildContext {
  /// Read the current [CoachProfile] without subscribing. Returns `null` if
  /// the provider isn't in the widget tree. Intended for `didChangeDependencies`
  /// / `initState`-style eager reads (prefill).
  CoachProfile? get coachProfileOrNull {
    try {
      return read<CoachProfileProvider>().profile;
    } on ProviderNotFoundException {
      return null;
    }
  }
}
