import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/financial_core/budget_crash_financial_facts.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/coach_cache_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';
import 'package:mint_mobile/services/snapshot_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;

abstract interface class CanonicalAnswerMutationPersistence {
  Future<Map<String, dynamic>> inspectAnswers(
    void Function(Map<String, dynamic> persisted) inspect,
  );

  Future<Map<String, dynamic>> mutateAnswers(
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  });
}

/// Serialized boundary for injected in-memory persistence implementations.
/// Production persistence uses ReportPersistenceService's process-global tail.
mixin SerializedCanonicalAnswerMutationPersistence {
  Future<void>? _canonicalMutationTail;

  Future<Map<String, dynamic>> loadAnswers();

  Future<void> saveAnswers(Map<String, dynamic> answers);

  Future<Map<String, dynamic>> inspectAnswers(
    void Function(Map<String, dynamic> persisted) inspect,
  ) async {
    final previous = _canonicalMutationTail;
    final completion = Completer<void>();
    final currentTail = completion.future;
    _canonicalMutationTail = currentTail;
    if (previous != null) await previous;
    try {
      final current = Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(await loadAnswers()),
      );
      inspect(current);
      return Map<String, dynamic>.from(current);
    } finally {
      completion.complete();
      if (identical(_canonicalMutationTail, currentTail)) {
        _canonicalMutationTail = null;
      }
    }
  }

  Future<Map<String, dynamic>> mutateAnswers(
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  }) async {
    final previous = _canonicalMutationTail;
    final completion = Completer<void>();
    final currentTail = completion.future;
    _canonicalMutationTail = currentTail;
    if (previous != null) await previous;
    try {
      final current = await loadAnswers();
      final candidate = mutation(Map<String, dynamic>.from(current));
      final next = candidate == null
          ? Map<String, dynamic>.from(current)
          : Map<String, dynamic>.from(candidate);
      if (candidate != null) await saveAnswers(next);
      final persisted = Map<String, dynamic>.unmodifiable(next);
      publish?.call(persisted);
      return Map<String, dynamic>.from(persisted);
    } finally {
      completion.complete();
      if (identical(_canonicalMutationTail, currentTail)) {
        _canonicalMutationTail = null;
      }
    }
  }
}

abstract interface class TaxProfilePersistence
    implements CanonicalAnswerMutationPersistence {
  Future<Map<String, dynamic>> loadAnswers();
}

final class _ReportTaxProfilePersistence
    implements TaxProfilePersistence, CanonicalAnswerMutationPersistence {
  const _ReportTaxProfilePersistence();

  @override
  Future<Map<String, dynamic>> loadAnswers() =>
      ReportPersistenceService.loadAnswers();

  @override
  Future<Map<String, dynamic>> inspectAnswers(
    void Function(Map<String, dynamic> persisted) inspect,
  ) =>
      ReportPersistenceService.loadAnswers(publish: inspect);

  @override
  Future<Map<String, dynamic>> mutateAnswers(
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  }) =>
      ReportPersistenceService.mutateAnswers(mutation, publish: publish);
}

abstract interface class LppProfilePersistence
    implements CanonicalAnswerMutationPersistence {
  Future<Map<String, dynamic>> loadAnswers();
}

final class _ReportLppProfilePersistence
    implements LppProfilePersistence, CanonicalAnswerMutationPersistence {
  const _ReportLppProfilePersistence();

  @override
  Future<Map<String, dynamic>> loadAnswers() =>
      ReportPersistenceService.loadAnswers();

  @override
  Future<Map<String, dynamic>> inspectAnswers(
    void Function(Map<String, dynamic> persisted) inspect,
  ) =>
      ReportPersistenceService.loadAnswers(publish: inspect);

  @override
  Future<Map<String, dynamic>> mutateAnswers(
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  }) =>
      ReportPersistenceService.mutateAnswers(mutation, publish: publish);
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
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
    PartnerAccountabilityService? partnerAccountabilityService,
    SessionEpoch? sessionEpoch,
    DateTime Function()? now,
  })  : _taxProfilePersistence =
            taxProfilePersistence ?? const _ReportTaxProfilePersistence(),
        _lppProfilePersistence =
            lppProfilePersistence ?? const _ReportLppProfilePersistence(),
        _partnerAccountabilityBindingStore =
            partnerAccountabilityBindingStore ??
                PartnerAccountabilityBindingStore(),
        _partnerAccountabilityService =
            partnerAccountabilityService ?? PartnerAccountabilityService(),
        _usesInjectedTaxPersistence = taxProfilePersistence != null,
        _sessionEpoch = sessionEpoch ?? SessionEpoch(),
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
  final PartnerAccountabilityBindingStore _partnerAccountabilityBindingStore;
  final PartnerAccountabilityService _partnerAccountabilityService;
  final bool _usesInjectedTaxPersistence;
  final SessionEpoch _sessionEpoch;
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
  Future<void>? _ownerResolutionTail;
  PartnerAccountabilityBinding? _partnerLppAccountabilityBinding;
  Timer? _partnerAuthorityInvalidationTimer;
  bool _disposed = false;
  bool _hasManualPartnerLppEvidence = false;
  String? _canonicalProfileOwnerId;
  String? _stagedCanonicalProfileOwnerId;

  PartnerAccountabilityBinding? get partnerLppAccountabilityBinding =>
      _partnerLppAccountabilityBinding;

  PartnerAccountabilityBindingState? get partnerLppAccountabilityState =>
      _partnerLppAccountabilityBinding?.state ??
      (_hasManualPartnerLppEvidence
          ? PartnerAccountabilityBindingState.partial
          : null);

  DateTime? _partnerAuthorityDeadline(
    PartnerAccountabilityBinding binding,
  ) {
    if (binding.state != PartnerAccountabilityBindingState.active ||
        binding.failureStatus != null ||
        binding.lastVerifiedAt == null ||
        binding.expiresAt == null) {
      return null;
    }
    final verificationDeadline =
        binding.lastVerifiedAt!.toUtc().add(const Duration(hours: 6));
    final receiptDeadline = binding.expiresAt!.toUtc();
    return receiptDeadline.isBefore(verificationDeadline)
        ? receiptDeadline
        : verificationDeadline;
  }

  bool _isCurrentPartnerAuthority(
    PartnerAccountabilityBinding binding,
    DateTime now,
  ) {
    final current = now.toUtc();
    final deadline = _partnerAuthorityDeadline(binding);
    return deadline != null &&
        current.isBefore(deadline) &&
        binding.isCurrentAt(current);
  }

  void _setPartnerLppAccountabilityBinding(
    PartnerAccountabilityBinding? binding,
  ) {
    _partnerAuthorityInvalidationTimer?.cancel();
    _partnerAuthorityInvalidationTimer = null;
    _partnerLppAccountabilityBinding = binding;
    final activeBinding = binding;
    if (activeBinding == null) return;
    final deadline = _partnerAuthorityDeadline(activeBinding);
    if (deadline == null || _disposed) return;
    _schedulePartnerAuthorityInvalidation(activeBinding, deadline);
  }

  void _schedulePartnerAuthorityInvalidation(
    PartnerAccountabilityBinding binding,
    DateTime deadline,
  ) {
    final delay = deadline.difference(_now().toUtc());
    _partnerAuthorityInvalidationTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _partnerAuthorityInvalidationTimer = null;
        if (_disposed ||
            !identical(_partnerLppAccountabilityBinding, binding)) {
          return;
        }
        final current = _now().toUtc();
        if (current.isBefore(deadline)) {
          // Wall-clock drift or an early timer wake-up: re-arm against the
          // canonical absolute deadline instead of exposing stale authority.
          _schedulePartnerAuthorityInvalidation(binding, deadline);
          return;
        }
        _rematerializeExpiredPartnerLpp(binding);
        notifyListeners();
      },
    );
  }

  void _rematerializeExpiredPartnerLpp(
    PartnerAccountabilityBinding expiredBinding,
  ) {
    final currentProfile = _profile;
    final currentPartner = currentProfile?.conjoint;
    if (!_isLoaded || currentProfile == null || currentPartner == null) return;

    final canonicalProfile = CoachProfile.fromWizardAnswers(
      _lastAnswers,
      now: _now,
      partnerAccountabilityBinding:
          _isCurrentPartnerAuthority(expiredBinding, _now().toUtc())
              ? expiredBinding
              : null,
      enforcePartnerAccountability: true,
    );
    final canonicalPartnerLpp =
        canonicalProfile.conjoint?.prevoyance ?? const PrevoyanceProfile();
    final currentPartnerPrevoyance =
        currentPartner.prevoyance ?? const PrevoyanceProfile();
    final rematerializedPartnerPrevoyance = currentPartnerPrevoyance
        .withLppEvidenceProjectionFrom(canonicalPartnerLpp);

    final partnerLppPaths = LppEvidenceFactKey.values
        .map((key) => key.manualPartnerProfilePath)
        .toSet();
    final rematerializedSources =
        Map<String, ProfileDataSource>.from(currentProfile.dataSources)
          ..removeWhere((path, _) => partnerLppPaths.contains(path));
    final rematerializedTimestamps =
        Map<String, DateTime>.from(currentProfile.dataTimestamps)
          ..removeWhere((path, _) => partnerLppPaths.contains(path));
    final rematerializedSourceDates =
        Map<String, DateTime?>.from(currentProfile.dataSourceDates)
          ..removeWhere((path, _) => partnerLppPaths.contains(path));
    for (final path in partnerLppPaths) {
      final source = canonicalProfile.dataSources[path];
      final timestamp = canonicalProfile.dataTimestamps[path];
      if (source != null) rematerializedSources[path] = source;
      if (timestamp != null) rematerializedTimestamps[path] = timestamp;
      if (canonicalProfile.dataSourceDates.containsKey(path)) {
        rematerializedSourceDates[path] =
            canonicalProfile.dataSourceDates[path];
      }
    }

    _profile = currentProfile.copyWith(
      conjoint: currentPartner.copyWith(
        prevoyance: rematerializedPartnerPrevoyance,
      ),
      dataSources: Map.unmodifiable(rematerializedSources),
      dataTimestamps: Map.unmodifiable(rematerializedTimestamps),
      dataSourceDates: Map.unmodifiable(rematerializedSourceDates),
    );
    _profileUpdatedSinceBudget = true;
    CoachCacheService.invalidate(InvalidationTrigger.profileUpdate);
    unawaited(CoachNarrativeService.invalidateCache(profile: currentProfile));
  }

  /// Le profil Coach construit a partir des reponses wizard.
  /// Null si le wizard n'a pas ete complete.
  CoachProfile? get profile => _profile;

  /// Durable pseudonymous owner for high-stakes local ledger publication.
  String? get canonicalProfileOwnerId => _canonicalProfileOwnerId;

  Future<Map<String, dynamic>> _mutateTaxAnswers(
    SessionEpochGuard sessionGuard,
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  }) =>
      _mutateCanonicalAnswers(
        persistence: _taxProfilePersistence,
        sessionGuard: sessionGuard,
        mutation: mutation,
        publish: publish,
      );

  Future<Map<String, dynamic>> _mutateLppAnswers(
    SessionEpochGuard sessionGuard,
    Map<String, dynamic>? Function(Map<String, dynamic> current) mutation, {
    void Function(Map<String, dynamic> persisted)? publish,
  }) =>
      _mutateCanonicalAnswers(
        persistence: _lppProfilePersistence,
        sessionGuard: sessionGuard,
        mutation: mutation,
        publish: publish,
      );

  Future<Map<String, dynamic>> _inspectTaxAnswers(
    SessionEpochGuard sessionGuard,
    void Function(Map<String, dynamic> persisted) inspect,
  ) =>
      _sessionEpoch.runGuardedPersistence(sessionGuard, () {
        return _taxProfilePersistence.inspectAnswers((persisted) {
          sessionGuard.assertCurrent();
          inspect(persisted);
        });
      });

  Future<Map<String, dynamic>> _mutateCanonicalAnswers({
    required CanonicalAnswerMutationPersistence persistence,
    required SessionEpochGuard sessionGuard,
    required Map<String, dynamic>? Function(Map<String, dynamic> current)
        mutation,
    void Function(Map<String, dynamic> persisted)? publish,
  }) =>
      _sessionEpoch.runGuardedPersistence(sessionGuard, () {
        return persistence.mutateAnswers(
          (current) {
            sessionGuard.assertCurrent();
            return mutation(current);
          },
          publish: (persisted) {
            sessionGuard.assertCurrent();
            publish?.call(persisted);
          },
        );
      });

  /// Resolves and durably publishes the canonical owner before high-stakes use.
  Future<String> ensureCanonicalProfileOwner() {
    final guard = _sessionEpoch.capture();
    return _serializeOwnerResolution(() async {
      late String ownerId;
      await _mutateTaxAnswers(
        guard,
        (loaded) {
          final prepared = _prepareCanonicalProfileOwnerForCombinedWriteLocked(
            loaded,
          );
          ownerId = prepared.ownerId;
          return _persistedCanonicalOwners(loaded).rootOwner == null
              ? prepared.answers
              : null;
        },
        publish: (persisted) {
          guard.assertCurrent();
          _canonicalProfileOwnerId = ownerId;
          _lastAnswers = _copyAnswers(persisted);
        },
      );
      return ownerId;
    });
  }

  /// Returns a stable owner candidate without crossing a persistence boundary.
  ///
  /// Plan review uses this value to build an immutable draft. The candidate is
  /// not authoritative until [commitStagedCanonicalProfileOwner] succeeds on
  /// the user's final confirmation tap.
  Future<String> previewCanonicalProfileOwner() {
    final guard = _sessionEpoch.capture();
    return _serializeOwnerResolution(() async {
      final loaded = _usesInjectedTaxPersistence
          ? await _taxProfilePersistence.loadAnswers()
          : await ReportPersistenceService.loadAnswersReadOnly();
      guard.assertCurrent();
      final owners = _persistedCanonicalOwners(loaded);
      final durableRoot = owners.rootOwner;
      final inMemoryOwner = _canonicalProfileOwnerId;
      final stagedOwner = _stagedCanonicalProfileOwnerId;
      final candidates = <String?>[
        durableRoot,
        inMemoryOwner,
        owners.lppOwner,
        owners.taxOwner,
        stagedOwner,
      ].whereType<String>().toSet();
      if (candidates.length > 1) {
        throw StateError('Canonical profile owner changed before preview');
      }
      final ownerId = candidates.isEmpty ? const Uuid().v4() : candidates.first;
      if (!isCanonicalUuidV4(ownerId)) {
        throw StateError('Canonical profile owner preview failed');
      }
      _stagedCanonicalProfileOwnerId = ownerId;
      if (durableRoot != null) _canonicalProfileOwnerId = durableRoot;
      return ownerId;
    });
  }

  /// Publishes exactly the owner previously shown in the plan review.
  Future<String> commitStagedCanonicalProfileOwner(String ownerId) {
    final guard = _sessionEpoch.capture();
    return _serializeOwnerResolution(() async {
      if (!isCanonicalUuidV4(ownerId) ||
          _stagedCanonicalProfileOwnerId != ownerId) {
        throw StateError('Canonical profile owner is not the staged owner');
      }
      await _mutateTaxAnswers(
        guard,
        (loaded) {
          final owners = _persistedCanonicalOwners(loaded);
          final candidates = <String?>[
            owners.rootOwner,
            owners.lppOwner,
            owners.taxOwner,
            _canonicalProfileOwnerId,
          ].whereType<String>();
          if (candidates.any((candidate) => candidate != ownerId)) {
            throw StateError('Canonical profile owner changed before consent');
          }
          return owners.rootOwner == null
              ? (_copyAnswers(loaded)
                ..[coachProfileOwnerRootKey] =
                    CoachProfileOwnerRoot(ownerId).toJsonString())
              : null;
        },
        publish: (persisted) {
          guard.assertCurrent();
          _canonicalProfileOwnerId = ownerId;
          _stagedCanonicalProfileOwnerId = null;
          _lastAnswers = _copyAnswers(persisted);
        },
      );
      return ownerId;
    });
  }

  /// Immutable wizard-answer view for legacy report generation.
  ///
  /// Screens must never read `wizard_answers_v2` directly. This snapshot is a
  /// temporary compatibility boundary while the report still consumes the
  /// legacy answer shape.
  Map<String, dynamic> get reportAnswersSnapshot {
    final safe = _copyAnswers(_lastAnswers);
    if (safe.containsKey(coachProfileOwnerRootKey)) {
      safe[coachProfileOwnerRootKey] = '__secure__';
    }
    return _immutableAnswers(safe);
  }

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

  static String? _lppCanonicalSelfOwner(Map<String, dynamic> answers) {
    if (!answers.containsKey(_lppEvidenceRootKey)) return null;
    final raw = answers[_lppEvidenceRootKey];
    if (raw == '__secure__') {
      throw StateError('Persisted LPP evidence is unreadable');
    }
    final root = LppEvidenceRoot.fromJsonString(raw);
    if (root == null) {
      throw StateError('Persisted LPP evidence root is malformed');
    }

    String? candidate;
    final self = root.self;
    if (self != null) {
      final identity = self.identityFacts.first;
      if (!isCanonicalUuidV4(identity.profileOwnerId) ||
          identity.actorProfileOwnerId != identity.profileOwnerId) {
        throw StateError('Persisted self LPP owner is invalid');
      }
      candidate = identity.profileOwnerId;
    }
    final manual = root.manualPartner;
    if (manual != null) {
      final identity = manual.identityFacts.first;
      if (!isCanonicalUuidV4(identity.profileOwnerId) ||
          !isCanonicalUuidV4(identity.actorProfileOwnerId) ||
          identity.profileOwnerId == identity.actorProfileOwnerId) {
        throw StateError('Persisted manual-partner LPP owner is invalid');
      }
      candidate ??= identity.actorProfileOwnerId;
      if (candidate != identity.actorProfileOwnerId) {
        throw StateError('Persisted LPP owners conflict');
      }
    }
    return candidate;
  }

  static String? _taxCanonicalSelfOwner(Map<String, dynamic> answers) {
    if (!answers.containsKey(_taxSnapshotRootKey)) return null;
    if (answers[_taxSnapshotRootKey] == '__secure__') {
      throw StateError('Persisted tax evidence is unreadable');
    }
    final envelope = _readTaxEnvelope(answers);
    String? candidate;
    for (final snapshot in envelope.snapshots) {
      if (!isCanonicalUuidV4(snapshot.profileOwnerId)) {
        throw StateError('Persisted tax owner is not a canonical UUIDv4');
      }
      candidate ??= snapshot.profileOwnerId;
      if (candidate != snapshot.profileOwnerId) {
        throw StateError('Persisted tax owners conflict');
      }
    }
    return candidate;
  }

  Future<T> _serializeOwnerResolution<T>(Future<T> Function() operation) async {
    final previous = _ownerResolutionTail;
    final completion = Completer<void>();
    final current = completion.future;
    _ownerResolutionTail = current;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_ownerResolutionTail, current)) {
        _ownerResolutionTail = null;
      }
    }
  }

  ({Map<String, dynamic> answers, String ownerId})
      _prepareCanonicalProfileOwnerForCombinedWriteLocked(
    Map<String, dynamic> loaded,
  ) {
    final persistedOwners = _persistedCanonicalOwners(loaded);
    final lppOwner = persistedOwners.lppOwner;
    final taxOwner = persistedOwners.taxOwner;
    final durableRootOwner = persistedOwners.rootOwner;
    final inMemoryOwner = _canonicalProfileOwnerId;
    final stagedOwner = _stagedCanonicalProfileOwnerId;
    if (durableRootOwner != null &&
        inMemoryOwner != null &&
        durableRootOwner != inMemoryOwner) {
      throw StateError('Canonical profile owner changed during this session');
    }
    final existingOwner = durableRootOwner ?? inMemoryOwner;
    for (final candidate in <String?>[lppOwner, taxOwner]) {
      if (existingOwner != null &&
          candidate != null &&
          existingOwner != candidate) {
        throw StateError('Canonical profile owner conflicts with ledger owner');
      }
    }
    if (stagedOwner != null &&
        <String?>[
          durableRootOwner,
          inMemoryOwner,
          lppOwner,
          taxOwner,
        ].whereType<String>().any((candidate) => candidate != stagedOwner)) {
      throw StateError('Canonical profile owner conflicts with staged owner');
    }
    final ownerId = durableRootOwner ??
        existingOwner ??
        lppOwner ??
        taxOwner ??
        stagedOwner ??
        const Uuid().v4();
    if (!isCanonicalUuidV4(ownerId)) {
      throw StateError('Canonical profile owner resolution failed');
    }
    final next = _copyAnswers(loaded)
      ..[coachProfileOwnerRootKey] =
          CoachProfileOwnerRoot(ownerId).toJsonString();
    return (answers: next, ownerId: ownerId);
  }

  static ({String? lppOwner, String? taxOwner, String? rootOwner})
      _persistedCanonicalOwners(Map<String, dynamic> loaded) {
    final lppOwner = _lppCanonicalSelfOwner(loaded);
    final taxOwner = _taxCanonicalSelfOwner(loaded);
    if (lppOwner != null && taxOwner != null && lppOwner != taxOwner) {
      throw StateError('Persisted LPP and tax owners conflict');
    }

    final hasRoot = loaded.containsKey(coachProfileOwnerRootKey);
    final rawRoot = loaded[coachProfileOwnerRootKey];
    if (rawRoot == '__secure__') {
      throw StateError('Canonical profile owner is unreadable');
    }
    final existingRoot =
        hasRoot ? CoachProfileOwnerRoot.fromJsonString(rawRoot) : null;
    if (hasRoot && existingRoot == null) {
      throw StateError('Canonical profile owner root is malformed');
    }
    final rootOwner = existingRoot?.profileOwnerId;
    for (final candidate in <String?>[lppOwner, taxOwner]) {
      if (rootOwner != null && candidate != null && rootOwner != candidate) {
        throw StateError('Canonical profile owner conflicts with ledger owner');
      }
    }
    return (
      lppOwner: lppOwner,
      taxOwner: taxOwner,
      rootOwner: rootOwner,
    );
  }

  static bool _hasRejectedPersistedCanonicalAuthority(
    Map<String, dynamic> loaded,
  ) {
    try {
      _persistedCanonicalOwners(loaded);
      return false;
    } on StateError {
      return true;
    }
  }

  static ({Map<String, dynamic> answers, bool migrated})
      _withCanonicalOtherFixedCostMigration(Map<String, dynamic> loaded) {
    const canonicalKey = 'q_other_fixed_costs_monthly_chf';
    const legacyKey = '_coach_depenses_autres';
    if (!loaded.containsKey(legacyKey)) {
      return (answers: loaded, migrated: false);
    }
    final answers = _copyAnswers(loaded);
    if (!answers.containsKey(canonicalKey)) {
      answers[canonicalKey] = answers[legacyKey];
    }
    answers.remove(legacyKey);
    return (answers: answers, migrated: true);
  }

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
          {required DateTime Function() now, required String? profileOwnerId}) {
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
      if (rawProvenance is Map && profileOwnerId != null) {
        final ownerId = profileOwnerId;
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
                  SwissCivilTime.isFutureCivilDate(
                    fact.sourceDate!,
                    now: current,
                  ))) {
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
    } on Object {
      throw StateError('Invalid persisted tax profile');
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

  Future<void> acceptTaxReview(TaxReviewConfirmation confirmation) {
    final guard = _sessionEpoch.capture();
    return _serializeOwnerResolution(
      () => _acceptTaxReviewLocked(confirmation, guard),
    );
  }

  Future<void> _acceptTaxReviewLocked(
    TaxReviewConfirmation confirmation,
    SessionEpochGuard sessionGuard,
  ) async {
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
        SwissCivilTime.isFutureCivilDate(
          sourceDate,
          now: currentCivilTime,
        )) {
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

    late String publishedOwnerId;
    late CoachProfile publishedProfile;
    await _mutateTaxAnswers(sessionGuard, (loadedRaw) {
      sessionGuard.assertCurrent();
      final ownerResolution =
          _prepareCanonicalProfileOwnerForCombinedWriteLocked(loadedRaw);
      publishedOwnerId = ownerResolution.ownerId;
      final loaded = ownerResolution.answers;
      final migration = _withLegacyTaxQuarantine(loaded, now: _now);
      final envelope = _readTaxEnvelope(migration.answers);
      final profileOwnerId = ownerResolution.ownerId;
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
        explicitMarginalIncomeTaxRate:
            confirmation.explicitMarginalIncomeTaxRate,
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

      publishedProfile = nextProfile;
      return nextAnswers;
    }, publish: (persisted) {
      sessionGuard.assertCurrent();
      _canonicalProfileOwnerId = publishedOwnerId;
      _lastAnswers = _copyAnswers(persisted);
      _profile = publishedProfile;
      _isLoaded = true;
      _isPartialProfile = true;
      _profileUpdatedSinceBudget = true;
      notifyListeners();
    });
  }

  /// Persists one complete person-owned LPP review before exposing it in memory.
  Future<LppReviewReceipt> acceptLppReview(
    LppReviewConfirmation confirmation,
  ) {
    final guard = _sessionEpoch.capture();
    return _serializeLppMutation(
      () => _serializeOwnerResolution(
        () => _acceptLppReview(confirmation, guard),
      ),
    );
  }

  Future<LppReviewReceipt> _acceptLppReview(
    LppReviewConfirmation confirmation,
    SessionEpochGuard sessionGuard,
  ) async {
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
    PartnerAccountabilityBinding? pendingAccountabilityBinding;
    PartnerAccountabilityBinding? previousActiveAccountabilityBinding;
    final accountabilityContext = confirmation.partnerAccountabilityContext;
    if (confirmation.subject == LppEvidenceOwnerKind.self &&
        accountabilityContext != null) {
      throw StateError('Self LPP cannot carry partner accountability');
    }
    if (confirmation.subject == LppEvidenceOwnerKind.manualPartner) {
      if (!FeatureFlags.partnerLppAccountabilityEnabled) {
        throw StateError('Manual partner LPP accountability is disabled');
      } else if (authorization.receiptId == null ||
          authorization.manualPartnerOwnerId == null ||
          accountabilityContext == null ||
          !accountabilityContext.isActiveAt(currentCivilTime) ||
          !accountabilityContext.matchesAuthorization(
            receiptId: authorization.receiptId,
            ownerId: authorization.manualPartnerOwnerId,
          )) {
        throw StateError('Manual partner LPP accountability binding missing');
      } else {
        final envelope = await _partnerAccountabilityBindingStore.load();
        sessionGuard.assertCurrent();
        final pending = envelope.pending;
        if (pending == null ||
            !accountabilityContext.matchesPending(pending) ||
            !currentCivilTime.toUtc().isBefore(pending.expiresAt!)) {
          throw StateError(
            'Manual partner LPP accountability binding inactive',
          );
        }
        pendingAccountabilityBinding = pending;
        previousActiveAccountabilityBinding =
            envelope.shadowed ?? envelope.active;
      }
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
        SwissCivilTime.isFutureCivilDate(
          sourceDate,
          now: currentCivilTime,
        )) {
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

    late String publishedOwnerId;
    late String committedRootJson;
    late String snapshotId;
    late Map<LppEvidenceFactKey, LppEvidenceFact> storedFacts;
    late CoachProfile committedProfile;
    String? previousLppRootJson;
    await _mutateLppAnswers(sessionGuard, (loadedRaw) {
      sessionGuard.assertCurrent();
      final ownerResolution =
          _prepareCanonicalProfileOwnerForCombinedWriteLocked(loadedRaw);
      publishedOwnerId = ownerResolution.ownerId;
      final migration = _withLegacySelfLppMigration(
        ownerResolution.answers,
        now: _now,
        profileOwnerId: ownerResolution.ownerId,
      );
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
      final stableSelfOwnerId = ownerResolution.ownerId;
      var reviewedOwnerId = stableSelfOwnerId;
      if (confirmation.subject == LppEvidenceOwnerKind.manualPartner) {
        reviewedOwnerId = authorization.manualPartnerOwnerId ??
            currentRoot.manualPartner?.identityFacts.first.profileOwnerId ??
            const Uuid().v4();
        if (reviewedOwnerId == stableSelfOwnerId) {
          throw StateError('Manual partner owner must be distinct from self');
        }
      }
      final authorizationMode =
          confirmation.subject == LppEvidenceOwnerKind.self
              ? LppEvidenceAuthorizationMode.self
              : LppEvidenceAuthorizationMode.manualPartnerDeclaration;
      storedFacts = <LppEvidenceFactKey, LppEvidenceFact>{
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
      snapshotId = const Uuid().v4();
      final nextRoot = LppEvidenceRoot(
        self: confirmation.subject == LppEvidenceOwnerKind.self
            ? LppEvidenceSnapshot(
                snapshotId: snapshotId,
                facts: Map.unmodifiable(storedFacts),
              )
            : currentRoot.self,
        manualPartner:
            confirmation.subject == LppEvidenceOwnerKind.manualPartner
                ? LppEvidenceSnapshot(
                    snapshotId: snapshotId,
                    facts: Map.unmodifiable(storedFacts),
                    independentFacts:
                        currentRoot.manualPartner?.independentFacts ?? const {},
                  )
                : currentRoot.manualPartner,
        legacyPartnerQuarantine: currentRoot.legacyPartnerQuarantine,
      );
      previousLppRootJson = loaded[_lppEvidenceRootKey] as String?;
      final nextAnswers = _copyAnswers(loaded);
      if (confirmation.subject == LppEvidenceOwnerKind.self) {
        for (final key in _legacySelfLppKeys.keys) {
          nextAnswers.remove(key);
        }
        nextAnswers.remove('_coach_lpp_source');
      }
      committedRootJson = nextRoot.toJsonString();
      nextAnswers[_lppEvidenceRootKey] = committedRootJson;
      final prospectiveAccountabilityBinding =
          pendingAccountabilityBinding?.copyWith(
        state: PartnerAccountabilityBindingState.active,
        lppSnapshotId: snapshotId,
        lastVerifiedAt: updatedAt,
        clearFailureStatus: true,
      );
      var nextProfile = CoachProfile.fromWizardAnswers(
        nextAnswers,
        now: _now,
        partnerAccountabilityBinding: prospectiveAccountabilityBinding,
        enforcePartnerAccountability: pendingAccountabilityBinding != null,
      );
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
      committedProfile = nextProfile;
      return nextAnswers;
    }, publish: (persisted) {
      sessionGuard.assertCurrent();
      _canonicalProfileOwnerId = publishedOwnerId;
      _lastAnswers = _copyAnswers(persisted);
      final pendingBinding = pendingAccountabilityBinding;
      if (pendingBinding == null) {
        _profile = committedProfile;
      } else {
        // Root B is durable before its receipt activation is authoritative.
        // Publishing the old active receipt A here would expose B under A.
        _setPartnerLppAccountabilityBinding(pendingBinding);
        _profile = CoachProfile.fromWizardAnswers(
          persisted,
          now: _now,
          partnerAccountabilityBinding: pendingBinding,
          enforcePartnerAccountability: true,
        );
        _hasManualPartnerLppEvidence = false;
      }
      _isLoaded = true;
      _isPartialProfile = true;
      _profileUpdatedSinceBudget = true;
      CoachNarrativeService.invalidateCache(profile: _profile);
      notifyListeners();
    });

    final pendingBinding = pendingAccountabilityBinding;
    if (pendingBinding != null) {
      try {
        final activatedBinding = await _sessionEpoch.runGuardedPersistence(
          sessionGuard,
          () => _partnerAccountabilityBindingStore.activatePending(
            receiptId: pendingBinding.receiptId,
            manualPartnerOwnerId: pendingBinding.manualPartnerOwnerId,
            lppSnapshotId: snapshotId,
            verifiedAt: updatedAt,
          ),
        );
        late CoachProfile activatedProfile;
        await _mutateLppAnswers(
          sessionGuard,
          (current) {
            if (current[_lppEvidenceRootKey] != committedRootJson) {
              throw StateError('LPP root changed during binding activation');
            }
            activatedProfile = CoachProfile.fromWizardAnswers(
              current,
              now: _now,
              partnerAccountabilityBinding: activatedBinding,
              enforcePartnerAccountability: true,
            );
            return null;
          },
          publish: (persisted) {
            sessionGuard.assertCurrent();
            _setPartnerLppAccountabilityBinding(activatedBinding);
            _lastAnswers = _copyAnswers(persisted);
            _profile = activatedProfile;
            _hasManualPartnerLppEvidence = true;
            _profileUpdatedSinceBudget = true;
            CoachNarrativeService.invalidateCache(profile: _profile);
            notifyListeners();
          },
        );
      } on SessionEpochInvalidated {
        rethrow;
      } on Object catch (activationError, activationStackTrace) {
        try {
          var restoredPreviousRoot = false;
          late CoachProfile compensatedProfile;
          await _mutateLppAnswers(
            sessionGuard,
            (current) {
              final compensated = _copyAnswers(current);
              if (compensated[_lppEvidenceRootKey] == committedRootJson) {
                restoredPreviousRoot = true;
                final previousRoot = previousLppRootJson;
                if (previousRoot == null) {
                  compensated.remove(_lppEvidenceRootKey);
                } else {
                  compensated[_lppEvidenceRootKey] = previousRoot;
                }
              }
              compensatedProfile = CoachProfile.fromWizardAnswers(
                compensated,
                now: _now,
                partnerAccountabilityBinding: restoredPreviousRoot
                    ? previousActiveAccountabilityBinding
                    : null,
                enforcePartnerAccountability: true,
              );
              _persistProvenance(compensated, compensatedProfile);
              return compensated;
            },
            publish: (persisted) {
              sessionGuard.assertCurrent();
              _setPartnerLppAccountabilityBinding(restoredPreviousRoot
                  ? previousActiveAccountabilityBinding
                  : null);
              _lastAnswers = _copyAnswers(persisted);
              _profile = compensatedProfile;
              _hasManualPartnerLppEvidence = restoredPreviousRoot &&
                  previousActiveAccountabilityBinding != null;
              _profileUpdatedSinceBudget = true;
              CoachNarrativeService.invalidateCache(profile: _profile);
              notifyListeners();
            },
          );
          if (restoredPreviousRoot) {
            await _sessionEpoch.runGuardedPersistence(
              sessionGuard,
              () =>
                  _partnerAccountabilityBindingStore.compensateFailedActivation(
                receiptId: pendingBinding.receiptId,
                manualPartnerOwnerId: pendingBinding.manualPartnerOwnerId,
                previousActive: previousActiveAccountabilityBinding,
              ),
            );
          } else {
            await _sessionEpoch.runGuardedPersistence(
              sessionGuard,
              _partnerAccountabilityBindingStore.clear,
            );
          }
        } on SessionEpochInvalidated {
          rethrow;
        } on Object {
          try {
            await _sessionEpoch.runGuardedPersistence(
              sessionGuard,
              _partnerAccountabilityBindingStore.clear,
            );
          } finally {
            sessionGuard.assertCurrent();
            _setPartnerLppAccountabilityBinding(null);
            _profile = CoachProfile.fromWizardAnswers(
              _lastAnswers,
              now: _now,
              partnerAccountabilityBinding: null,
              enforcePartnerAccountability: true,
            );
            _hasManualPartnerLppEvidence = false;
            _profileUpdatedSinceBudget = true;
            CoachNarrativeService.invalidateCache(profile: _profile);
            notifyListeners();
          }
          throw StateError(
            'LPP root activation failed and could not be restored',
          );
        }
        Error.throwWithStackTrace(activationError, activationStackTrace);
      }
    }
    return LppReviewReceipt(
      snapshotId: snapshotId,
      ownerKind: confirmation.subject,
      factKeys: storedFacts.keys.toSet(),
    );
  }

  /// Stores the single highest-impact manual recovery fact independently of
  /// any partner certificate receipt. Passing null records "unknown" by
  /// removing only this independent value.
  Future<void> setIndependentManualPartnerVestedBenefitsCapital(
    double? value,
  ) {
    final sessionGuard = _sessionEpoch.capture();
    return _serializeLppMutation(() => _serializeOwnerResolution(() async {
          if (!FeatureFlags.typedLppEvidence || _profile?.conjoint == null) {
            throw StateError('Manual partner LPP recovery is unavailable');
          }
          if (value != null && (!value.isFinite || value <= 0)) {
            throw ArgumentError.value(value, 'value', 'invalid LPP capital');
          }
          late String publishedOwnerId;
          late CoachProfile publishedProfile;
          late bool hasManualEvidence;
          await _mutateLppAnswers(sessionGuard, (loadedRaw) {
            sessionGuard.assertCurrent();
            final ownerResolution =
                _prepareCanonicalProfileOwnerForCombinedWriteLocked(
              loadedRaw,
            );
            publishedOwnerId = ownerResolution.ownerId;
            final loaded = ownerResolution.answers;
            final root = LppEvidenceRoot.fromJsonString(
                  loaded[_lppEvidenceRootKey],
                ) ??
                const LppEvidenceRoot(self: null);
            final currentManual = root.manualPartner;
            final identity = currentManual?.identityFacts.first;
            final selfOwnerId = ownerResolution.ownerId;
            final partnerOwnerId = identity?.profileOwnerId ??
                _partnerLppAccountabilityBinding?.manualPartnerOwnerId ??
                const Uuid().v4();
            if (partnerOwnerId == selfOwnerId) {
              throw StateError(
                  'Manual partner owner must be distinct from self');
            }
            final independent = <LppEvidenceFactKey, LppEvidenceFact>{
              ...?currentManual?.independentFacts,
            };
            const key = LppEvidenceFactKey.vestedBenefitsCapitalChf;
            final updatedAt = _now().toUtc();
            if (value == null) {
              independent.remove(key);
            } else {
              independent[key] = LppEvidenceFact(
                value: value,
                unit: key.unit,
                profileOwnerId: partnerOwnerId,
                actorProfileOwnerId: selfOwnerId,
                ownerKind: LppEvidenceOwnerKind.manualPartner,
                authorizationMode:
                    LppEvidenceAuthorizationMode.manualPartnerDeclaration,
                source: ProfileDataSource.userInput.name,
                sourceDate: null,
                updatedAt: updatedAt,
              );
            }
            final nextManual = (currentManual?.facts.isNotEmpty == true ||
                    independent.isNotEmpty)
                ? LppEvidenceSnapshot(
                    snapshotId: currentManual?.snapshotId ?? const Uuid().v4(),
                    facts: currentManual?.facts ?? const {},
                    independentFacts: Map.unmodifiable(independent),
                  )
                : null;
            final nextRoot = LppEvidenceRoot(
              self: root.self,
              manualPartner: nextManual,
              legacyPartnerQuarantine: root.legacyPartnerQuarantine,
            );
            final nextAnswers = _copyAnswers(loaded)
              ..[_lppEvidenceRootKey] = nextRoot.toJsonString();
            var nextProfile = CoachProfile.fromWizardAnswers(
              nextAnswers,
              now: _now,
              partnerAccountabilityBinding: _partnerLppAccountabilityBinding,
              enforcePartnerAccountability: true,
            );
            if (value != null) {
              nextProfile = _withStampedProvenance(
                nextProfile,
                [key.manualPartnerProfilePath],
                source: ProfileDataSource.userInput,
                sourceDate: null,
                updatedAt: updatedAt,
              );
            }
            _persistProvenance(nextAnswers, nextProfile);
            publishedProfile = nextProfile;
            hasManualEvidence = nextManual != null;
            return nextAnswers;
          }, publish: (persisted) {
            sessionGuard.assertCurrent();
            _canonicalProfileOwnerId = publishedOwnerId;
            _lastAnswers = _copyAnswers(persisted);
            _profile = publishedProfile;
            _hasManualPartnerLppEvidence = hasManualEvidence;
            _isLoaded = true;
            _isPartialProfile = true;
            _profileUpdatedSinceBudget = true;
            CoachNarrativeService.invalidateCache(profile: _profile);
            notifyListeners();
          });
        }));
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
    'q_household_type': ['householdType'],
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
    '_coach_total_3a': ['prevoyance.totalEpargne3a'],
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
    'q_tax_provision_monthly_chf': ['monthlyTaxProvisionDeclared'],
    'q_other_fixed_costs_monthly_chf': ['depenses.autresDepensesFixes'],
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

  /// Returns the current strict LPP snapshot for [ownerKind].
  ///
  /// This never falls back to loose legacy profile values. Before initial
  /// ledger hydration, for an unreadable root, or for a future-dated snapshot,
  /// it returns null so external reference readers fail closed.
  LppEvidenceSnapshot? currentLppSnapshot(
    LppEvidenceOwnerKind ownerKind,
  ) {
    if (!_isLoaded || !FeatureFlags.typedLppEvidence) return null;
    final rawRoot = _lastAnswers[_lppEvidenceRootKey];
    switch (ownerKind) {
      case LppEvidenceOwnerKind.self:
        return LppEvidenceSelector.selectSelf(rawRoot, now: _now);
      case LppEvidenceOwnerKind.manualPartner:
        if (!FeatureFlags.partnerLppAccountabilityEnabled) return null;
        final expectedOwnerId =
            LppEvidenceSelector.manualPartnerOwnerId(rawRoot);
        final expectedSnapshotId =
            LppEvidenceSelector.manualPartnerSnapshotId(rawRoot);
        final accountabilityBinding = _partnerLppAccountabilityBinding;
        if (expectedOwnerId == null ||
            expectedSnapshotId == null ||
            accountabilityBinding == null ||
            accountabilityBinding.manualPartnerOwnerId != expectedOwnerId ||
            accountabilityBinding.lppSnapshotId != expectedSnapshotId ||
            !_isCurrentPartnerAuthority(
              accountabilityBinding,
              _now().toUtc(),
            )) {
          return null;
        }
        final snapshot = LppEvidenceSelector.selectManualPartner(
          rawRoot,
          expectedOwnerId: expectedOwnerId,
          now: _now,
        );
        return snapshot == null || snapshot.facts.isEmpty ? null : snapshot;
    }
  }

  String? currentLppSnapshotId(LppEvidenceOwnerKind ownerKind) =>
      currentLppSnapshot(ownerKind)?.snapshotId;

  /// Validates a receipt only against the already-persisted strict root.
  ///
  /// This is intentionally narrower than [currentLppSnapshot]: it permits a
  /// metadata-only reference retry after volatile partner authority expires,
  /// but never exposes or republishes the underlying financial values.
  bool matchesAcceptedLppReceipt(LppReviewReceipt receipt) {
    if (!_isLoaded ||
        !FeatureFlags.typedLppEvidence ||
        receipt.factKeys.isEmpty) {
      return false;
    }
    final root = LppEvidenceRoot.fromJsonString(
      _lastAnswers[_lppEvidenceRootKey],
    );
    final snapshot = switch (receipt.ownerKind) {
      LppEvidenceOwnerKind.self => root?.self,
      LppEvidenceOwnerKind.manualPartner => root?.manualPartner,
    };
    return snapshot != null &&
        snapshot.facts.isNotEmpty &&
        snapshot.snapshotId == receipt.snapshotId &&
        setEquals(snapshot.facts.keys.toSet(), receipt.factKeys);
  }

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
      final sessionGuard = _sessionEpoch.capture();
      final isLoggedIn = await AuthService.isLoggedIn();
      sessionGuard.assertCurrent();
      if (!isLoggedIn) return;
      final remoteData = await ApiService.get('/profiles/me');
      sessionGuard.assertCurrent();
      await _mergeBackendUnknownProfile(remoteData, sessionGuard);
      sessionGuard.assertCurrent();
      // OBS-05 — save_fact success proxy breadcrumb (D-03 4-level).
      // factKind is the coarse 'profile_sync' enum; the finer-grained
      // per-field attribution is deferred to Phase 31-02 (backend can
      // echo `facts_saved: [...]` in /profiles/me response).
      MintBreadcrumbs.saveFact(
        success: true,
        factKind: 'profile_sync',
      );
    } on SessionEpochInvalidated {
      return;
    } catch (e) {
      // OBS-05 — save_fact failure proxy breadcrumb. Error code is an
      // enum (no raw exception message — may contain PII).
      final code = e is ApiException
          ? (e.isOffline ? 'offline' : 'api_error')
          : 'unknown';
      if (kDebugMode) {
        debugPrint('[CoachProfile] syncFromBackend failed: $code');
      }
      MintBreadcrumbs.saveFact(
        success: false,
        factKind: 'profile_sync',
        errorCode: code,
      );
    }
  }

  /// Maps an opaque backend profile into one canonical, non-echoing ledger
  /// mutation. Validation here rejects malformed transport values; authority
  /// and fill-only decisions remain inside [mergeBackendUnknownAnswers].
  Future<void> mergeBackendUnknownProfile(
    Map<String, dynamic> remote, {
    SessionEpochGuard? sessionGuard,
  }) =>
      _mergeBackendUnknownProfile(
        remote,
        sessionGuard ?? _sessionEpoch.capture(),
      );

  Future<void> _mergeBackendUnknownProfile(
    Map<String, dynamic> remote,
    SessionEpochGuard sessionGuard,
  ) async {
    sessionGuard.assertCurrent();
    final partial = <String, dynamic>{};
    final birthYear = _validRemoteBirthYear(remote['birthYear']);
    if (birthYear != null) partial['q_birth_year'] = birthYear;
    final canton = _validRemoteCanton(remote['canton']);
    if (canton != null) partial['q_canton'] = canton;
    final gender = _validRemoteString(remote['gender']);
    if (gender != null) partial['q_gender'] = gender;
    final grossYearly = _validRemoteAmount(remote['incomeGrossYearly']);
    if (grossYearly != null) {
      partial['q_gross_salary_annual'] = grossYearly;
    }
    final netMonthly = _validRemoteAmount(remote['incomeNetMonthly']);
    if (netMonthly != null) {
      partial['q_net_income_period_chf'] = netMonthly;
      partial['q_pay_frequency'] = 'monthly';
    }
    final employment = _validRemoteEmployment(remote['employmentStatus']);
    if (employment != null) partial['q_employment_status'] = employment;
    final household = _validRemoteString(remote['householdType']);
    if (household != null) partial['q_household_type'] = household;
    final lpp = _validRemoteAmount(remote['avoirLpp']);
    if (lpp != null) partial['_coach_avoir_lpp'] = lpp;
    final insuredSalary = _validRemoteAmount(remote['lppInsuredSalary']);
    if (insuredSalary != null) {
      partial['_coach_salaire_assure'] = insuredSalary;
    }
    final buyback = _validRemoteAmount(remote['lppBuybackMax']);
    if (buyback != null) partial['_coach_rachat_maximum'] = buyback;
    final pillar3a = _validRemoteAmount(remote['pillar3aBalance']);
    if (pillar3a != null) partial['q_3a_total'] = pillar3a;
    await mergeBackendUnknownAnswers(partial, sessionGuard: sessionGuard);
  }

  int? _validRemoteBirthYear(Object? raw) {
    if (raw is! num || !raw.toDouble().isFinite) return null;
    final year = raw.toInt();
    if (raw.toDouble() != year.toDouble()) return null;
    final candidate = DateTime(year, 1, 1);
    return SwissCivilTime.isSupportedAdultBirthDate(candidate, now: _now())
        ? year
        : null;
  }

  static String? _validRemoteString(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty || value.toLowerCase() == 'unknown' ? null : value;
  }

  static String? _validRemoteCanton(Object? raw) {
    final value = _validRemoteString(raw)?.toUpperCase();
    return sortedCantonCodes.contains(value) ? value : null;
  }

  static String? _validRemoteEmployment(Object? raw) {
    final value = _validRemoteString(raw)?.toLowerCase();
    return const <String>{
      'employee',
      'salarie',
      'salarié', // lint-ignore: accepted legacy backend wire value
      'self_employed',
      'independant',
      'indépendant', // lint-ignore: accepted legacy backend wire value
      'retired',
      'retraite',
      'retraité', // lint-ignore: accepted legacy backend wire value
      'student',
      'etudiant',
      'étudiant', // lint-ignore: accepted legacy backend wire value
      'unemployed',
      'chomage',
      'chômage', // lint-ignore: accepted legacy backend wire value
      'mixed',
      'mixte',
    }.contains(value)
        ? value
        : null;
  }

  static double? _validRemoteAmount(Object? raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    return value.isFinite && value >= 0 && value <= 10000000 ? value : null;
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
  Future<void> loadFromWizard() {
    final guard = _sessionEpoch.capture();
    return _serializeLppMutation(() => _loadFromWizard(guard));
  }

  Future<PartnerAccountabilityBinding?>
      _reconcilePartnerAccountabilityOnColdLoad(
    Map<String, dynamic> answers,
    SessionEpochGuard sessionGuard,
  ) async {
    if (!FeatureFlags.typedLppEvidence) {
      _hasManualPartnerLppEvidence = false;
      _setPartnerLppAccountabilityBinding(null);
      return null;
    }
    final root = LppEvidenceRoot.fromJsonString(answers[_lppEvidenceRootKey]);
    final manual = root?.manualPartner;
    _hasManualPartnerLppEvidence = manual != null &&
        (manual.facts.isNotEmpty || manual.independentFacts.isNotEmpty);
    if (manual == null || manual.identityFacts.isEmpty) {
      _setPartnerLppAccountabilityBinding(null);
      return null;
    }

    if (!FeatureFlags.partnerLppAccountabilityEnabled) {
      _setPartnerLppAccountabilityBinding(null);
      return null;
    }

    final envelope = await _partnerAccountabilityBindingStore.load();
    sessionGuard.assertCurrent();
    final pending = envelope.pending;
    if (pending != null) {
      _setPartnerLppAccountabilityBinding(pending);
      return pending;
    }
    final candidate = envelope.active;
    if (candidate == null ||
        candidate.manualPartnerOwnerId !=
            manual.identityFacts.first.profileOwnerId ||
        candidate.lppSnapshotId != manual.snapshotId) {
      _setPartnerLppAccountabilityBinding(null);
      return null;
    }

    try {
      final receipt = await _partnerAccountabilityService.status(
        candidate.receiptId,
      );
      sessionGuard.assertCurrent();
      if (!receipt.isCurrent ||
          receipt.receiptId != candidate.receiptId ||
          receipt.noticeVersion != candidate.noticeVersion ||
          receipt.policyVersion != candidate.policyVersion ||
          receipt.expiresAt == null ||
          !_now().toUtc().isBefore(receipt.expiresAt!)) {
        await _restoreIndependentPartnerUserInputFacts(
          answers,
          sessionGuard,
        );
        final partial = await _sessionEpoch.runGuardedPersistence(
          sessionGuard,
          () => _partnerAccountabilityBindingStore.markPartial(
            failureStatus: receipt.status,
          ),
        );
        sessionGuard.assertCurrent();
        _setPartnerLppAccountabilityBinding(partial);
        return partial;
      }
      final verified = await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => _partnerAccountabilityBindingStore.verifyActive(
          receiptId: candidate.receiptId,
          verifiedAt: _now().toUtc(),
          expiresAt: receipt.expiresAt!,
        ),
      );
      sessionGuard.assertCurrent();
      _setPartnerLppAccountabilityBinding(verified);
      return verified;
    } on SessionEpochInvalidated {
      rethrow;
    } on PartnerAccountabilityException catch (error) {
      if (error.status != PartnerAccountabilityReceiptStatus.offline) {
        await _restoreIndependentPartnerUserInputFacts(
          answers,
          sessionGuard,
        );
      }
      final partial = await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => _partnerAccountabilityBindingStore.markPartial(
          failureStatus: error.status,
        ),
      );
      sessionGuard.assertCurrent();
      _setPartnerLppAccountabilityBinding(partial);
      return partial;
    } catch (_) {
      final partial = await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => _partnerAccountabilityBindingStore.markPartial(
          failureStatus: PartnerAccountabilityReceiptStatus.stale,
        ),
      );
      sessionGuard.assertCurrent();
      _setPartnerLppAccountabilityBinding(partial);
      return partial;
    }
  }

  Future<void> _restoreIndependentPartnerUserInputFacts(
    Map<String, dynamic> answers,
    SessionEpochGuard sessionGuard,
  ) async {
    await _mutateLppAnswers(
      sessionGuard,
      (current) {
        final next = _copyAnswers(current);
        final root = LppEvidenceRoot.fromJsonString(next[_lppEvidenceRootKey]);
        final manual = root?.manualPartner;
        if (root == null || manual == null) return next;
        final independent = manual.independentFacts;
        final restoredRoot = LppEvidenceRoot(
          self: root.self,
          manualPartner: independent.isEmpty
              ? null
              : LppEvidenceSnapshot(
                  snapshotId: manual.snapshotId,
                  facts: const {},
                  independentFacts: independent,
                ),
          legacyPartnerQuarantine: root.legacyPartnerQuarantine,
        );
        next[_lppEvidenceRootKey] = restoredRoot.toJsonString();
        return next;
      },
      publish: (persisted) {
        answers
          ..clear()
          ..addAll(_copyAnswers(persisted));
        _lastAnswers = _copyAnswers(persisted);
      },
    );
  }

  Map<String, dynamic> _withoutRejectedLedgerAuthority(
    Map<String, dynamic> rawAnswers,
  ) {
    final baseAnswers = _copyAnswers(rawAnswers)
      ..remove(coachProfileOwnerRootKey)
      ..remove(_lppEvidenceRootKey)
      ..remove(_taxSnapshotRootKey)
      ..removeWhere(
        (key, _) =>
            _legacySelfLppKeys.containsKey(key) ||
            key == '_coach_lpp_source' ||
            legacyPartnerLppAnswerKeys.contains(key) ||
            key.startsWith('_coach_tax_'),
      );
    final lppPaths = <String>{
      for (final key in LppEvidenceFactKey.values) key.profilePath,
      for (final key in LppEvidenceFactKey.values) key.manualPartnerProfilePath,
    };
    bool isLedgerPath(Object? path) =>
        path is String &&
        (path.startsWith('fiscal.') || lppPaths.contains(path));
    for (final envelopeKey in const <String>{
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final rawEnvelope = baseAnswers[envelopeKey];
      if (rawEnvelope is! Map) continue;
      final safeEnvelope = Map<String, dynamic>.from(rawEnvelope)
        ..removeWhere((path, _) => isLedgerPath(path));
      if (safeEnvelope.isEmpty) {
        baseAnswers.remove(envelopeKey);
      } else {
        baseAnswers[envelopeKey] = safeEnvelope;
      }
    }
    return baseAnswers;
  }

  Future<void> _hydrateBaseProfileWithoutLedgerAuthority(
    SessionEpochGuard sessionGuard,
  ) async {
    var partial = true;
    if (!_usesInjectedTaxPersistence &&
        await ReportPersistenceService.isCompleted()) {
      partial = false;
    }

    sessionGuard.assertCurrent();
    await _inspectTaxAnswers(sessionGuard, (current) {
      final baseAnswers = _withoutRejectedLedgerAuthority(current);
      _lastAnswers = _copyAnswers(baseAnswers);
      _canonicalProfileOwnerId = null;
      _stagedCanonicalProfileOwnerId = null;
      _profile = baseAnswers.isEmpty
          ? null
          : CoachProfile.fromWizardAnswers(
              baseAnswers,
              now: _now,
              enforcePartnerAccountability: false,
            );
      _isPartialProfile = _profile == null ? false : partial;
      _profileUpdatedSinceBudget = _profile != null;
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    });
  }

  ({Map<String, dynamic> answers, String? ownerId, bool changed})
      _prepareColdWizardAnswers(Map<String, dynamic> rawAnswers) {
    if (rawAnswers.isEmpty) {
      return (answers: _copyAnswers(rawAnswers), ownerId: null, changed: false);
    }

    final persistedOwners = _persistedCanonicalOwners(rawAnswers);
    final requiresOwnerForLegacyLpp = rawAnswers.keys.any(
      _legacySelfLppKeys.containsKey,
    );
    final hasExistingOwnerAuthority = persistedOwners.rootOwner != null ||
        persistedOwners.lppOwner != null ||
        persistedOwners.taxOwner != null ||
        requiresOwnerForLegacyLpp;
    late final Map<String, dynamic> ownerPreparedAnswers;
    String? ownerId;
    var ownerAdded = false;
    if (hasExistingOwnerAuthority) {
      final prepared = _prepareCanonicalProfileOwnerForCombinedWriteLocked(
        rawAnswers,
      );
      ownerId = prepared.ownerId;
      ownerPreparedAnswers = prepared.answers;
      ownerAdded = persistedOwners.rootOwner == null;
    } else {
      ownerPreparedAnswers = _copyAnswers(rawAnswers);
    }

    final taxMigration =
        _withLegacyTaxQuarantine(ownerPreparedAnswers, now: _now);
    final opaqueLppCleanup =
        _withoutLoosePartnerLppBesideOpaqueRoot(taxMigration.answers);
    final lppMigration = opaqueLppCleanup.answers.isEmpty
        ? (answers: opaqueLppCleanup.answers, migrated: false)
        : _withLegacySelfLppMigration(
            opaqueLppCleanup.answers,
            now: _now,
            profileOwnerId: ownerId,
          );
    final fixedCostMigration =
        _withCanonicalOtherFixedCostMigration(lppMigration.answers);
    return (
      answers: _copyAnswers(fixedCostMigration.answers),
      ownerId: ownerId,
      changed: ownerAdded ||
          taxMigration.migrated ||
          opaqueLppCleanup.migrated ||
          lppMigration.migrated ||
          fixedCostMigration.migrated,
    );
  }

  Future<void> _publishColdProfileFromDurable({
    required SessionEpochGuard sessionGuard,
    required PartnerAccountabilityBinding? partnerAccountabilityBinding,
    required bool isFullCompleted,
    required bool isMiniCompleted,
    required List<MonthlyCheckIn> checkIns,
    required List<PlannedMonthlyContribution> contributions,
    required int? previousScore,
    required List<Map<String, dynamic>> scoreHistory,
  }) =>
      _inspectTaxAnswers(sessionGuard, (persisted) {
        var answers = _copyAnswers(persisted);
        String? ownerId;
        try {
          final owners = _persistedCanonicalOwners(answers);
          ownerId = owners.rootOwner ?? owners.lppOwner ?? owners.taxOwner;
        } on StateError {
          answers = _withoutRejectedLedgerAuthority(answers);
        }

        final lppRoot = LppEvidenceRoot.fromJsonString(
          answers[_lppEvidenceRootKey],
        );
        final manualPartner = lppRoot?.manualPartner;
        _hasManualPartnerLppEvidence = manualPartner != null &&
            (manualPartner.facts.isNotEmpty ||
                manualPartner.independentFacts.isNotEmpty);
        final bindingMatchesCurrentRoot = manualPartner != null &&
            manualPartner.identityFacts.isNotEmpty &&
            partnerAccountabilityBinding?.manualPartnerOwnerId ==
                manualPartner.identityFacts.first.profileOwnerId &&
            (partnerAccountabilityBinding?.state ==
                    PartnerAccountabilityBindingState.pending ||
                partnerAccountabilityBinding?.lppSnapshotId ==
                    manualPartner.snapshotId);
        final effectiveBinding =
            bindingMatchesCurrentRoot ? partnerAccountabilityBinding : null;
        if (!bindingMatchesCurrentRoot &&
            _partnerLppAccountabilityBinding != null) {
          _setPartnerLppAccountabilityBinding(null);
        }

        final hasScanData = answers.keys.any(
          (key) => key.startsWith('_coach_') && key != coachProfileOwnerRootKey,
        );
        final hydrate = answers.isNotEmpty &&
            (_usesInjectedTaxPersistence ||
                isFullCompleted ||
                isMiniCompleted ||
                hasScanData);
        final partial = hydrate && !isFullCompleted;
        CoachProfile? nextProfile = hydrate
            ? CoachProfile.fromWizardAnswers(
                answers,
                now: _now,
                partnerAccountabilityBinding: effectiveBinding,
                enforcePartnerAccountability: manualPartner != null,
              )
            : null;
        if (!_usesInjectedTaxPersistence && nextProfile != null) {
          if (checkIns.isNotEmpty) {
            nextProfile = nextProfile.copyWithCheckIns(checkIns);
          }
          if (contributions.isNotEmpty) {
            nextProfile = nextProfile.copyWithContributions(contributions);
          }
          _previousScore = previousScore;
          _scoreHistory = scoreHistory;
        }

        _canonicalProfileOwnerId = ownerId;
        _lastAnswers = _copyAnswers(answers);
        _profile = nextProfile;
        _isPartialProfile = nextProfile == null ? false : partial;
        _isLoading = false;
        _isLoaded = true;
        _profileUpdatedSinceBudget = nextProfile != null;
        notifyListeners();
      });

  Future<void> _loadFromWizard(SessionEpochGuard sessionGuard) async {
    sessionGuard.assertCurrent();
    _isLoading = true;
    _canonicalProfileOwnerId = null;
    _stagedCanonicalProfileOwnerId = null;
    notifyListeners();

    try {
      late Map<String, dynamic> rawLoadedAnswers;
      late ({
        Map<String, dynamic> answers,
        String? ownerId,
        bool changed
      }) preview;
      try {
        await _inspectTaxAnswers(sessionGuard, (persisted) {
          rawLoadedAnswers = _copyAnswers(persisted);
          preview = _prepareColdWizardAnswers(persisted);
        });
      } on StateError {
        if (!_hasRejectedPersistedCanonicalAuthority(rawLoadedAnswers)) {
          rethrow;
        }
        await _hydrateBaseProfileWithoutLedgerAuthority(sessionGuard);
        return;
      }

      late Map<String, dynamic> answers;
      if (!preview.changed) {
        answers = _copyAnswers(rawLoadedAnswers);
      } else {
        try {
          answers = await _mutateTaxAnswers(
            sessionGuard,
            (current) {
              final fresh = _prepareColdWizardAnswers(current);
              return fresh.changed ? fresh.answers : null;
            },
          );
        } on StateError {
          await _hydrateBaseProfileWithoutLedgerAuthority(sessionGuard);
          return;
        }
      }

      final partnerAccountabilityBinding =
          await _reconcilePartnerAccountabilityOnColdLoad(
        answers,
        sessionGuard,
      );
      sessionGuard.assertCurrent();

      var isFullCompleted = false;
      var isMiniCompleted = false;
      var checkIns = const <MonthlyCheckIn>[];
      var contributions = const <PlannedMonthlyContribution>[];
      int? previousScore;
      var scoreHistory = const <Map<String, dynamic>>[];
      if (!_usesInjectedTaxPersistence) {
        isFullCompleted = await ReportPersistenceService.isCompleted();
        sessionGuard.assertCurrent();
        isMiniCompleted =
            await ReportPersistenceService.isMiniOnboardingCompleted();
        sessionGuard.assertCurrent();
        final persistedCheckIns = await ReportPersistenceService.loadCheckIns();
        sessionGuard.assertCurrent();
        checkIns = persistedCheckIns
            .map((value) => MonthlyCheckIn.fromJson(value))
            .toList(growable: false);
        final persistedContributions =
            await ReportPersistenceService.loadContributions();
        sessionGuard.assertCurrent();
        contributions = persistedContributions
            .map((value) => PlannedMonthlyContribution.fromJson(value))
            .toList(growable: false);
        previousScore = await ReportPersistenceService.loadLastScore();
        sessionGuard.assertCurrent();
        scoreHistory = await ReportPersistenceService.loadScoreHistory();
        sessionGuard.assertCurrent();
      }

      await _publishColdProfileFromDurable(
        sessionGuard: sessionGuard,
        partnerAccountabilityBinding: partnerAccountabilityBinding,
        isFullCompleted: isFullCompleted,
        isMiniCompleted: isMiniCompleted,
        checkIns: checkIns,
        contributions: contributions,
        previousScore: previousScore,
        scoreHistory: scoreHistory,
      );
    } on SessionEpochInvalidated {
      return;
    } catch (_) {
      sessionGuard.assertCurrent();
      if (kDebugMode) {
        debugPrint('[CoachProfile] Profile load failed');
      }
      // Do not publish a stale/null snapshot after a concurrent canonical
      // writer. A fresh provider is already null; an existing one retains the
      // last successfully published durable view.
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Updates the profile directly from an answers map.
  /// Used after wizard completion to avoid an async reload.
  void updateFromAnswers(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _validateDateOfBirthAnswer(answers);
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

  /// Applies cloud profile values whose upstream provenance is unavailable.
  ///
  /// The values remain usable, but they must not inherit a local source or a
  /// fresh timestamp merely because they were downloaded during this login.
  Future<void> mergeBackendUnknownAnswers(
    Map<String, dynamic> partial, {
    SessionEpochGuard? sessionGuard,
  }) async {
    if (partial.isEmpty) return;
    _validateDateOfBirthAnswer(partial);
    final guard = sessionGuard ?? _sessionEpoch.capture();
    guard.assertCurrent();
    late CoachProfile publishedProfile;
    var shouldPublish = true;
    await _mutateTaxAnswers(
      guard,
      (current) {
        final effectivePartial = <String, dynamic>{
          for (final entry in partial.entries)
            if (_isResolvedBackendAnswer(entry.key, entry.value) &&
                !_hasResolvedLocalAnswer(current, entry.key))
              entry.key: entry.value,
        };
        if (current.containsKey(_lppEvidenceRootKey)) {
          effectivePartial.removeWhere(
            (key, _) => _remoteLooseSelfLppAnswerKeys.contains(key),
          );
        }
        final exactDateOfBirth =
            _authoritativeExactDateOfBirthFromAnswers(current);
        if (exactDateOfBirth != null &&
            effectivePartial.containsKey('q_birth_year')) {
          effectivePartial.remove('q_birth_year');
        }
        if (exactDateOfBirth != null &&
            effectivePartial.isEmpty &&
            _hasCoherentBirthAuthority(current, exactDateOfBirth)) {
          publishedProfile = _rebuildCanonicalProfile(current);
          return null;
        }
        if (effectivePartial.isEmpty) {
          if (current.isEmpty && _profile == null) {
            shouldPublish = false;
            return null;
          }
          publishedProfile = _rebuildCanonicalProfile(current);
          return null;
        }
        final next = Map<String, dynamic>.from(current)
          ..addAll(effectivePartial);
        if (exactDateOfBirth != null) {
          next['q_birth_year'] = exactDateOfBirth.year;
          _mirrorDateOfBirthAuthorityToBirthYear(next);
          _updateBackendUnknownPaths(
            next,
            const {'birthYear'},
            markUnknown: false,
          );
        }
        final paths = _canonicalPathsForAnswers(effectivePartial);
        _clearPersistedProvenancePaths(next, paths);
        _updateBackendUnknownPaths(next, paths, markUnknown: true);
        publishedProfile = _rebuildCanonicalProfile(next);
        return next;
      },
      publish: (persisted) {
        guard.assertCurrent();
        if (!shouldPublish) return;
        _lastAnswers = _copyAnswers(persisted);
        _profile = publishedProfile;
        _isLoaded = true;
        _profileUpdatedSinceBudget = true;
        CoachNarrativeService.invalidateCache(profile: _profile);
        notifyListeners();
      },
    );
  }

  static const _remoteLooseSelfLppAnswerKeys = <String>{
    '_coach_avoir_lpp',
    '_coach_salaire_assure',
    '_coach_rachat_maximum',
  };

  bool _isResolvedBackendAnswer(String key, Object? value) {
    if (value == null || value == '__secure__') return false;
    switch (key) {
      case 'q_birth_year':
        return _validRemoteBirthYear(value) != null;
      case 'q_canton':
        return _validRemoteCanton(value) != null;
      case 'q_gender':
        return value == 'M' || value == 'F';
      case 'q_employment_status':
        return _validRemoteEmployment(value) != null;
      case 'q_pay_frequency':
        return value == 'monthly';
      case 'q_gross_salary_annual':
      case 'q_net_income_period_chf':
      case '_coach_avoir_lpp':
      case '_coach_salaire_assure':
      case '_coach_rachat_maximum':
      case 'q_3a_total':
        return _validRemoteAmount(value) != null;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty && normalized != 'unknown';
    }
    if (value is num) return value.toDouble().isFinite;
    if (value is bool) return true;
    return value is List ? value.isNotEmpty : value is Map && value.isNotEmpty;
  }

  bool _hasResolvedLocalAnswer(
    Map<String, dynamic> current,
    String answerKey,
  ) {
    final paths = _answerProvenancePaths[answerKey] ?? const <String>[];
    for (final envelopeKey in const <String>{
      '__provenance',
      '_coach_data_sources',
    }) {
      final envelope = current[envelopeKey];
      if (envelope is Map && paths.any(envelope.containsKey)) return true;
    }
    if (paths.isEmpty) {
      return _isResolvedLocalAnswer(answerKey, current[answerKey]);
    }
    final rawUnknown = current[coachBackendUnknownPathsKey];
    final unknownPaths = rawUnknown is List
        ? rawUnknown.whereType<String>().toSet()
        : const <String>{};
    for (final path in paths) {
      if (unknownPaths.contains(path)) continue;
      for (final entry in _answerProvenancePaths.entries) {
        if (!entry.value.contains(path)) continue;
        if (_isResolvedLocalAnswer(entry.key, current[entry.key])) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isResolvedLocalAnswer(String key, Object? value) {
    if (value == null || value == '__secure__') return false;
    switch (key) {
      case 'q_birth_year':
        return _validRemoteBirthYear(value) != null;
      case 'q_canton':
        return _validRemoteCanton(value) != null;
      case 'q_gender':
        return value == 'M' || value == 'F';
      case 'q_employment_status':
        return _validRemoteEmployment(value) != null;
      case 'q_pay_frequency':
        return value == 'monthly' || value == 'yearly' || value == 'annuel';
    }
    if (value is num) return value.toDouble().isFinite;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty && normalized != 'unknown';
    }
    if (value is bool) return true;
    return value is List ? value.isNotEmpty : value is Map && value.isNotEmpty;
  }

  CoachProfile _rebuildCanonicalProfile(Map<String, dynamic> answers) {
    final hasManualPartnerRoot = LppEvidenceRoot.fromJsonString(
          answers[_lppEvidenceRootKey],
        )?.manualPartner !=
        null;
    final rebuilt = CoachProfile.fromWizardAnswers(
      answers,
      now: _now,
      partnerAccountabilityBinding: _partnerLppAccountabilityBinding,
      enforcePartnerAccountability: hasManualPartnerRoot,
    );
    final current = _profile;
    if (current == null) return rebuilt;
    return rebuilt.copyWith(
      checkIns: current.checkIns,
      plannedContributions: current.plannedContributions,
      initialProjectionSnapshot: current.initialProjectionSnapshot,
    );
  }

  static DateTime? _authoritativeExactDateOfBirthFromAnswers(
    Map<String, dynamic> answers,
  ) {
    final rawDate = answers['q_date_of_birth'];
    if (rawDate is! String) return null;
    final parsed = SwissCivilTime.parseCanonicalCivilDate(rawDate);
    if (parsed == null) return null;
    final rawProvenance = answers['__provenance'];
    if (rawProvenance is! Map) return null;
    final envelope = rawProvenance['dateOfBirth'];
    if (envelope is! Map) return null;
    final source = envelope['source'];
    if (source != ProfileDataSource.userInput.name &&
        source != ProfileDataSource.certificate.name &&
        source != ProfileDataSource.crossValidated.name) {
      return null;
    }
    return parsed;
  }

  static void _mirrorDateOfBirthAuthorityToBirthYear(
    Map<String, dynamic> answers,
  ) {
    for (final envelopeKey in const <String>{
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final raw = answers[envelopeKey];
      if (raw is! Map || !raw.containsKey('dateOfBirth')) continue;
      answers[envelopeKey] = <String, dynamic>{
        for (final entry in raw.entries)
          entry.key.toString(): _copyAnswerValue(entry.value),
        'birthYear': _copyAnswerValue(raw['dateOfBirth']),
      };
    }
  }

  static bool _hasCoherentBirthAuthority(
    Map<String, dynamic> answers,
    DateTime dateOfBirth,
  ) {
    final rawBirthYear = answers['q_birth_year'];
    if (rawBirthYear is! num || rawBirthYear.toInt() != dateOfBirth.year) {
      return false;
    }
    final rawProvenance = answers['__provenance'];
    if (rawProvenance is! Map) return false;
    final dateEnvelope = rawProvenance['dateOfBirth'];
    final yearEnvelope = rawProvenance['birthYear'];
    if (dateEnvelope is! Map || yearEnvelope is! Map) return false;
    if (!mapEquals(
      Map<String, dynamic>.from(dateEnvelope),
      Map<String, dynamic>.from(yearEnvelope),
    )) {
      return false;
    }
    final rawUnknown = answers[coachBackendUnknownPathsKey];
    return rawUnknown is! List || !rawUnknown.contains('birthYear');
  }

  static void _clearPersistedProvenancePaths(
    Map<String, dynamic> answers,
    Set<String> paths,
  ) {
    for (final envelopeKey in const <String>{
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final raw = answers[envelopeKey];
      if (raw is! Map) continue;
      final cleaned = Map<String, dynamic>.from(raw)
        ..removeWhere((path, _) => paths.contains(path));
      if (cleaned.isEmpty) {
        answers.remove(envelopeKey);
      } else {
        answers[envelopeKey] = cleaned;
      }
    }
  }

  static void _updateBackendUnknownPaths(
    Map<String, dynamic> answers,
    Set<String> paths, {
    required bool markUnknown,
  }) {
    final raw = answers[coachBackendUnknownPathsKey];
    final unknown = raw is List ? raw.whereType<String>().toSet() : <String>{};
    if (markUnknown) {
      unknown.addAll(paths);
    } else {
      unknown.removeAll(paths);
    }
    if (unknown.isEmpty) {
      answers.remove(coachBackendUnknownPathsKey);
    } else {
      answers[coachBackendUnknownPathsKey] = unknown.toList()..sort();
    }
  }

  void _validateDateOfBirthAnswer(Map<String, dynamic> answers) {
    if (!answers.containsKey('q_date_of_birth')) return;
    final raw = answers['q_date_of_birth'];
    if (raw == null) return;
    final parsed =
        raw is String ? SwissCivilTime.parseCanonicalCivilDate(raw) : null;
    if (parsed == null ||
        !SwissCivilTime.isSupportedAdultBirthDate(parsed, now: _now())) {
      throw ArgumentError.value(
        raw,
        'q_date_of_birth',
        'canonical supported adult YYYY-MM-DD required',
      );
    }
  }

  /// Merge answers while explicitly recording their origin metadata.
  Future<void> mergeAnswersWithProvenance(
    Map<String, dynamic> partial, {
    ProfileDataSource source = ProfileDataSource.userInput,
    DateTime? sourceDate,
    SessionEpochGuard? sessionGuard,
  }) async {
    if (partial.isEmpty) return;
    _validateDateOfBirthAnswer(partial);
    if (sourceDate != null &&
        SwissCivilTime.isFutureCivilDate(sourceDate, now: _now())) {
      throw ArgumentError.value(
        sourceDate,
        'sourceDate',
        'future Swiss civil dates cannot enter the ledger',
      );
    }
    final guard = sessionGuard ?? _sessionEpoch.capture();
    guard.assertCurrent();
    late CoachProfile publishedProfile;
    await _mutateTaxAnswers(
      guard,
      (current) {
        guard.assertCurrent();
        _validateDateOfBirthAnswer(partial);
        final normalizedPartial = Map<String, dynamic>.from(
          _withExplicitCashAnswerSource(partial, source: source),
        );
        if (normalizedPartial['q_avs_lacunes_status'] == 'unknown') {
          final currentStatus = current['q_avs_lacunes_status'];
          if (currentStatus == 'arrived_late' ||
              currentStatus == 'lived_abroad') {
            normalizedPartial['q_avs_lacunes_status'] = currentStatus;
          }
        }
        if (normalizedPartial.containsKey('_coach_depenses_autres')) {
          normalizedPartial.putIfAbsent(
            'q_other_fixed_costs_monthly_chf',
            () => normalizedPartial['_coach_depenses_autres'],
          );
          normalizedPartial.remove('_coach_depenses_autres');
        }
        final merged = Map<String, dynamic>.from(current)
          ..addAll(normalizedPartial);
        if (normalizedPartial.containsKey('q_other_fixed_costs_monthly_chf')) {
          merged.remove('_coach_depenses_autres');
        }
        final clearsPartner = _setsNonCoupledCivilStatus(partial);
        if (clearsPartner) _clearPartnerAnswers(merged);

        final stamp = _now();
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
        _updateBackendUnknownPaths(
          merged,
          touchedPaths,
          markUnknown: false,
        );
        final clearedFieldPaths = touchedPaths
            .where(
              (path) => _resolvedCanonicalValue(resolvedProfile, path) == null,
            )
            .toSet();
        final stampedFieldPaths = requestedStamps
            .where(
              (path) => _resolvedCanonicalValue(resolvedProfile, path) != null,
            )
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
        publishedProfile = _rebuildCanonicalProfile(merged);
        return merged;
      },
      publish: (persisted) {
        guard.assertCurrent();
        _lastAnswers = _copyAnswers(persisted);
        _profile = publishedProfile;
        _isLoaded = true;
        _profileUpdatedSinceBudget = true;
        CoachNarrativeService.invalidateCache(profile: _profile);
        notifyListeners();
      },
    );
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
    final sessionGuard = _sessionEpoch.capture();
    // P0-9: Clamp salary to valid bounds before any computation.
    final clampedGrossSalary = grossSalary.clamp(0, 10000000).toDouble();

    // Convert gross annual → net monthly
    // Net monthly = (grossSalary / 12) × (1 - 0.13) (charges sociales ~13%)
    // fromWizardAnswers() reconvertit net → brut via / (1 - 0.13),
    // ce qui préserve le salaire brut original.
    final netMonthly = IncomeConversionCalculator.monthlyNetFromAnnualGross(
      clampedGrossSalary,
    );
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
    late CoachProfile publishedProfile;
    await _sessionEpoch.runGuardedPersistence(sessionGuard, () async {
      await ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final next = Map<String, dynamic>.from(current)..addAll(answers);
          var nextProfile = CoachProfile.fromWizardAnswers(next);
          if (firstName != null && firstName.isNotEmpty) {
            nextProfile = nextProfile.copyWith(firstName: firstName);
          }
          nextProfile = nextProfile.copyWith(
            dataTimestamps: _stampTimestamps(
              nextProfile.dataTimestamps,
              initialFields,
            ),
          );
          _persistTimestamps(next, nextProfile.dataTimestamps);
          publishedProfile = nextProfile;
          return next;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = publishedProfile;
          _isPartialProfile = true;
          _isLoaded = true;
          _profileUpdatedSinceBudget = true;
          notifyListeners();
        },
      );
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
    });
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
    final sessionGuard = _sessionEpoch.capture();

    final previous = current.voiceCursorPreference;

    // Optimistic local update.
    _profile = current.copyWith(voiceCursorPreference: next);
    notifyListeners();

    // Default sync = no-op success (Plan 12-04 will wire real PATCH).
    final ok = remoteSync == null ? true : await remoteSync(next);
    sessionGuard.assertCurrent();

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
    final identityNormalized = _withCoherentBirthAuthority(updated);
    final dateOfBirth = identityNormalized.dateOfBirth;
    if (dateOfBirth != null &&
        !SwissCivilTime.isSupportedAdultBirthDate(
          dateOfBirth,
          now: _now(),
        )) {
      throw ArgumentError.value(
        dateOfBirth,
        'dateOfBirth',
        'supported adult Swiss civil date required',
      );
    }
    final sessionGuard = _sessionEpoch.capture();
    final normalized = _withExplicitCashMarkerFromSource(identityNormalized);
    final previousStatus = _profile?.etatCivil;
    _profile = normalized;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
    // FIX-045: Persist ALL profile fields.
    unawaited(
      _persistFullProfile(normalized, sessionGuard).catchError((Object e) {
        if (e is! SessionEpochInvalidated) {
          debugPrint('[CoachProfileProvider] Profile persistence failed');
        }
      }),
    );
    // FIX-HIGH-1: Invalidate coach cache on profile change (was never called).
    CoachCacheService.invalidate(InvalidationTrigger.profileUpdate);
    // Also invalidate daily narrative cache so greeting / topTip / scenarios
    // pick up new profile data instead of showing stale pre-scan copy.
    CoachNarrativeService.invalidateCache(profile: normalized);
    // FIX-HIGH-2: Invalidate CapMemory on significant profile change
    // to prevent stale caps from being re-served.
    CapMemoryStore.load().then((mem) async {
      sessionGuard.assertCurrent();
      await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => CapMemoryStore.save(mem.copyWith(
          lastCapServed: null,
          lastCapDate: null,
        )),
      );
    }).catchError((Object e) {
      if (e is! SessionEpochInvalidated) {
        debugPrint('[CoachProfileProvider] CapMemory invalidation failed');
      }
    });
    // FIX-097: If civil status changed to non-coupled, dissolve household.
    if (previousStatus != null &&
        previousStatus != normalized.etatCivil &&
        !normalized.hasPartnerContext &&
        !normalized.civilStatusNeedsConfirmation) {
      // Clear local household cache after separation. Partner answers are
      // cleared by _persistFullProfile() based on civil status, so this
      // fire-and-forget cache cleanup cannot resurrect a ghost conjoint.
      unawaited(_clearHouseholdCacheAfterSeparation(sessionGuard));
    }
  }

  CoachProfile _withCoherentBirthAuthority(CoachProfile profile) {
    final dateOfBirth = profile.dateOfBirth;
    final sources = Map<String, ProfileDataSource>.from(profile.dataSources);
    final timestamps = Map<String, DateTime>.from(profile.dataTimestamps);
    if (dateOfBirth == null) {
      sources.remove('dateOfBirth');
      timestamps.remove('dateOfBirth');
      if (mapEquals(sources, profile.dataSources) &&
          mapEquals(timestamps, profile.dataTimestamps)) {
        return profile;
      }
      return profile.copyWith(
        dataSources: sources,
        dataTimestamps: timestamps,
      );
    }

    final source = sources['dateOfBirth'] ?? sources['birthYear'];
    final updatedAt = timestamps['dateOfBirth'] ?? timestamps['birthYear'];
    sources
      ..remove('dateOfBirth')
      ..remove('birthYear');
    timestamps
      ..remove('dateOfBirth')
      ..remove('birthYear');
    if (source != null) {
      sources['dateOfBirth'] = source;
      sources['birthYear'] = source;
    }
    if (updatedAt != null) {
      timestamps['dateOfBirth'] = updatedAt;
      timestamps['birthYear'] = updatedAt;
    }
    if (profile.birthYear == dateOfBirth.year &&
        mapEquals(sources, profile.dataSources) &&
        mapEquals(timestamps, profile.dataTimestamps)) {
      return profile;
    }
    return profile.copyWith(
      birthYear: dateOfBirth.year,
      dataSources: sources,
      dataTimestamps: timestamps,
    );
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
  Future<void> _clearHouseholdCacheAfterSeparation(
    SessionEpochGuard sessionGuard,
  ) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => sp.remove('_household_data'),
      );
    } on SessionEpochInvalidated {
      return;
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

  Future<void> _persistFullProfile(
    CoachProfile profile,
    SessionEpochGuard sessionGuard,
  ) async {
    late CoachProfile publishedProfile;
    await _mutateTaxAnswers(
      sessionGuard,
      (current) {
        sessionGuard.assertCurrent();
        final answers = Map<String, dynamic>.from(current);
        // Core fields
        final dateOfBirth = profile.dateOfBirth;
        if (dateOfBirth != null) {
          answers['q_date_of_birth'] =
              '${dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${dateOfBirth.day.toString().padLeft(2, '0')}';
          answers['q_birth_year'] = dateOfBirth.year;
        } else {
          answers.remove('q_date_of_birth');
          if (profile.birthYear > 0) {
            answers['q_birth_year'] = profile.birthYear;
          } else {
            answers.remove('q_birth_year');
          }
        }
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
        final hasExplicitConsumerDebtPayments =
            profile.dettes.mensualiteCreditConso != null ||
                profile.dettes.mensualiteLeasing != null;
        if (hasExplicitConsumerDebtPayments) {
          answers['q_debt_payments_period_chf'] =
              (profile.dettes.mensualiteCreditConso ?? 0) +
                  (profile.dettes.mensualiteLeasing ?? 0);
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
        _persistTimestamps(answers, profile.dataTimestamps);
        _persistProvenance(answers, profile);
        final hasManualPartnerRoot = LppEvidenceRoot.fromJsonString(
              answers[_lppEvidenceRootKey],
            )?.manualPartner !=
            null;
        publishedProfile = CoachProfile.fromWizardAnswers(
          answers,
          now: _now,
          partnerAccountabilityBinding: _partnerLppAccountabilityBinding,
          enforcePartnerAccountability: hasManualPartnerRoot,
        ).copyWith(
          checkIns: profile.checkIns,
          plannedContributions: profile.plannedContributions,
          initialProjectionSnapshot: profile.initialProjectionSnapshot,
        );
        return answers;
      },
      publish: (persisted) {
        sessionGuard.assertCurrent();
        _lastAnswers = _copyAnswers(persisted);
        _profile = publishedProfile;
        _profileUpdatedSinceBudget = true;
        notifyListeners();
      },
    );
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
    final sessionGuard = _sessionEpoch.capture();
    late CoachProfile publishedProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          final next = Map<String, dynamic>.from(current)
            ..['q_primary_focus'] = focus;
          publishedProfile = CoachProfile.fromWizardAnswers(next).copyWith(
            updatedAt: DateTime.now(),
          );
          return next;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = publishedProfile;
          _profileUpdatedSinceBudget = true;
          notifyListeners();
        },
      ),
    );
  }

  /// Ajoute un check-in mensuel au profil et le persiste.
  // TODO(P2): Sync monthly check-ins to backend for cross-device access
  Future<void> addCheckIn(MonthlyCheckIn checkIn) async {
    if (_profile == null) return;
    final sessionGuard = _sessionEpoch.capture();
    final updated = [..._profile!.checkIns, checkIn];
    _profile = _profile!.copyWithCheckIns(updated);
    // Persist BEFORE notify so downstream listeners see consistent state
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.saveCheckIns(
        updated.map((ci) => ci.toJson()).toList(),
      ),
    );
    sessionGuard.assertCurrent();

    // W15: Auto-trigger financial snapshot after each check-in
    _createSnapshotFromProfile('check_in');

    notifyListeners();
  }

  /// Met a jour les contributions dans le profil et les persiste.
  Future<void> updateContributions(
      List<PlannedMonthlyContribution> contributions) async {
    if (_profile == null) return;
    final sessionGuard = _sessionEpoch.capture();
    _profile = _profile!.copyWithContributions(contributions);
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.saveContributions(
        contributions.map((c) => c.toJson()).toList(),
      ),
    );
    sessionGuard.assertCurrent();
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
    final sessionGuard = _sessionEpoch.capture();
    _previousScore = score;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.saveLastScore(score),
    );
    // Recharger l'historique pour inclure la nouvelle entree
    final scoreHistory = await ReportPersistenceService.loadScoreHistory();
    sessionGuard.assertCurrent();
    _scoreHistory = scoreHistory;
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
    final sessionGuard = _sessionEpoch.capture();

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

    final requestedProfile = p.copyWith(
      salaireBrutMensuel: salaireBrutMensuel ?? p.salaireBrutMensuel,
      employmentStatus: employmentStatus ?? p.employmentStatus,
      prevoyance: updatedPrevoyance,
      riskTolerance: riskTolerance ?? p.riskTolerance,
      realEstateProject: realEstateProject ?? p.realEstateProject,
      updatedAt: DateTime.now(),
    );

    late CoachProfile publishedProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final answers = Map<String, dynamic>.from(current);
          if (salaireBrutMensuel != null) {
            // Convert brut to net for wizard format using NetIncomeBreakdown
            final breakdown = NetIncomeBreakdown.compute(
              grossSalary: salaireBrutMensuel * 12,
              canton: requestedProfile.canton,
              age: requestedProfile.age,
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
          if (answers['_coach_created_at'] == null &&
              p.createdAt != p.updatedAt) {
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
          publishedProfile = CoachProfile.fromWizardAnswers(
            answers,
            now: _now,
          );
          return answers;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = publishedProfile;
          _profileUpdatedSinceBudget = true;
          notifyListeners();
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DOCUMENT EXTRACTION → PROFILE INJECTION
  // ════════════════════════════════════════════════════════════════

  /// Met a jour le profil depuis l'extraction d'un extrait AVS.
  ///
  /// Mappe les champs AVS extraits vers PrevoyanceProfile.
  /// Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1, Document C
  Future<void> updateFromAvsExtraction(List<ExtractedField> fields) async {
    final sessionGuard = _sessionEpoch.capture();
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
    late CoachProfile transactionProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final answers = Map<String, dynamic>.from(current);
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
          transactionProfile = _withStampedProvenance(
            CoachProfile.fromWizardAnswers(answers, now: _now),
            touchedFields,
            source: ProfileDataSource.certificate,
            sourceDate: null,
            updatedAt: stamp,
          );
          _persistTimestamps(
            answers,
            transactionProfile.dataTimestamps,
          );
          _persistProvenance(answers, transactionProfile);
          if (touchedFields.isNotEmpty) {
            // Compatibility trace; field provenance remains canonical.
            answers['_coach_avs_source'] = 'document_scan';
          }
          return answers;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = transactionProfile;
          _profileUpdatedSinceBudget = true;
          CoachNarrativeService.invalidateCache(profile: _profile);
          notifyListeners();
        },
      ),
    );
  }

  /// Inject salary certificate extraction into CoachProfile.
  ///
  /// Stores: salaireBrutMensuel, nombreDeMois, bonusPourcentage.
  /// Tags dataSources as certificate. Stamps timestamps.
  Future<void> updateFromSalaryExtraction(List<ExtractedField> fields) async {
    final sessionGuard = _sessionEpoch.capture();
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

    // Stamp timestamps
    final touchedFields = <String>[];
    if (salaireBrut != null) touchedFields.add('salaireBrutMensuel');
    if (nombreMois != null) touchedFields.add('nombreDeMois');
    if (bonus != null) touchedFields.add('bonusPourcentage');
    final stamp = DateTime.now();
    late CoachProfile transactionProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final answers = Map<String, dynamic>.from(current);
          final baseProfile = CoachProfile.fromWizardAnswers(
            answers,
            now: _now,
          );
          final valueProfile = baseProfile.copyWith(
            salaireBrutMensuel: salaireBrut ?? baseProfile.salaireBrutMensuel,
            nombreDeMois: (nombreMois ?? baseProfile.nombreDeMois).toDouble(),
            bonusPourcentage: bonus ?? baseProfile.bonusPourcentage,
            updatedAt: stamp,
          );
          transactionProfile = _withStampedProvenance(
            valueProfile,
            touchedFields,
            source: ProfileDataSource.certificate,
            sourceDate: null,
            updatedAt: stamp,
          );
          if (salaireBrut != null || nombreMois != null) {
            answers['q_gross_salary_annual'] =
                transactionProfile.salaireBrutMensuel *
                    transactionProfile.nombreDeMois;
          }
          if (nombreMois != null) {
            answers['q_nombre_mois'] = nombreMois;
          }
          if (bonus != null) {
            answers['q_bonus_percentage'] = bonus;
            answers.remove('q_annual_bonus');
          }
          answers['_coach_updated_at'] = stamp.toIso8601String();
          _persistTimestamps(answers, transactionProfile.dataTimestamps);
          _persistProvenance(answers, transactionProfile);
          answers['_coach_salary_source'] = 'document_scan';
          return answers;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = transactionProfile;
          _profileUpdatedSinceBudget = true;
          CoachNarrativeService.invalidateCache(profile: _profile);
          notifyListeners();
        },
      ),
    );
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
    final sessionGuard = _sessionEpoch.capture();
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

    late CoachProfile transactionProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final answers = Map<String, dynamic>.from(current);
          final baseProfile = CoachProfile.fromWizardAnswers(
            answers,
            now: _now,
          );
          if (salaireBrutMensuel != null) {
            answers['q_gross_salary_annual'] =
                salaireBrutMensuel * baseProfile.nombreDeMois;
          }
          if (avoirLppTotal != null) {
            answers['_coach_avoir_lpp'] = avoirLppTotal;
          }
          if (rendementCaisse != null) {
            answers['_coach_rendement_caisse'] = rendementCaisse;
          }
          if (totalEpargne3a != null) {
            answers['_coach_total_3a'] = totalEpargne3a;
          }
          if (nombre3a != null) {
            answers['q_3a_accounts_count'] = nombre3a;
          }
          if (rachatLppMensuel != null) {
            answers['_coach_rachat_lpp_mensuel'] = rachatLppMensuel;
          }
          if (epargneLiquide != null) {
            answers['q_cash_total'] = epargneLiquide;
            answers['_coach_cash_total_source'] =
                ProfileDataSource.userInput.name;
            answers['q_cash_total_unconfirmed_legacy'] = null;
          }
          if (investissements != null) {
            answers['q_investments_total'] = investissements;
          }
          if (loyer != null) {
            answers['q_housing_cost_period_chf'] = loyer;
          }
          if (assuranceMaladie != null) {
            answers['q_lamal_premium_monthly_chf'] = assuranceMaladie;
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
          if (autresDepensesFixes != null) {
            answers['q_other_fixed_costs_monthly_chf'] = autresDepensesFixes;
            answers.remove('_coach_depenses_autres');
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
          transactionProfile = _withExplicitCashMarkerFromSource(
            _withStampedProvenance(
              CoachProfile.fromWizardAnswers(answers, now: _now),
              touchedFields,
              source: ProfileDataSource.userInput,
              sourceDate: null,
              updatedAt: stamp,
            ),
          );
          _persistTimestamps(answers, transactionProfile.dataTimestamps);
          _persistProvenance(answers, transactionProfile);
          return answers;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = transactionProfile;
          _profileUpdatedSinceBudget = true;
          CoachNarrativeService.invalidateCache(profile: _profile);
          notifyListeners();
        },
      ),
    );
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
    final sessionGuard = _sessionEpoch.capture();
    final p = _profile!;

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
    late CoachProfile transactionProfile;
    await _sessionEpoch.runGuardedPersistence(
      sessionGuard,
      () => ReportPersistenceService.mutateAnswers(
        (current) {
          sessionGuard.assertCurrent();
          final answers = Map<String, dynamic>.from(current);
          if (hasLiquidAccount) {
            answers['q_cash_total'] = epargneLiquide;
            answers['_coach_cash_total_source'] =
                ProfileDataSource.openBanking.name;
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
          transactionProfile = _withExplicitCashMarkerFromSource(
            _withStampedProvenance(
              CoachProfile.fromWizardAnswers(answers, now: _now),
              touchedFields,
              source: ProfileDataSource.openBanking,
              sourceDate: null,
              updatedAt: stamp,
            ),
          );
          _persistTimestamps(answers, transactionProfile.dataTimestamps);
          _persistProvenance(answers, transactionProfile);
          answers['_coach_blink_source'] = 'open_banking';
          return answers;
        },
        publish: (persisted) {
          sessionGuard.assertCurrent();
          _lastAnswers = _copyAnswers(persisted);
          _profile = transactionProfile;
          _profileUpdatedSinceBudget = true;
          notifyListeners();
        },
      ),
    );
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
    return BudgetCrashFinancialFacts.isMonthlyExpensePlausible(
      monthlyExpense: categoryTotal,
      grossMonthlyIncome: grossMonthlySalary,
      maximumExpenseRatio: maxRatio,
    )
        ? categoryTotal
        : null;
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
  Future<void> clear() async {
    await purgeDurableSessionData();
    clearSessionMemoryAfterPurge();
  }

  /// Strict durable half of the app-level session termination transaction.
  Future<void> purgeDurableSessionData() => ReportPersistenceService.clear(
        partnerAccountabilityBindingStore: _partnerAccountabilityBindingStore,
      );

  /// Publishes an empty ledger only after the coordinator completed its purge.
  void clearSessionMemoryAfterPurge() {
    _setPartnerLppAccountabilityBinding(null);
    _hasManualPartnerLppEvidence = false;
    _profile = null;
    _canonicalProfileOwnerId = null;
    _stagedCanonicalProfileOwnerId = null;
    _isLoading = false;
    _isPartialProfile = false;
    _isLoaded = false;
    _remoteHydrationDone = false;
    _isHydrating = false;
    _previousScore = null;
    _scoreHistory = [];
    _profileUpdatedSinceBudget = false;
    _lastAnswers = const {};
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stagedCanonicalProfileOwnerId = null;
    _partnerAuthorityInvalidationTimer?.cancel();
    _partnerAuthorityInvalidationTimer = null;
    super.dispose();
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
