import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/financial_core/emergency_fund_heuristic.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

class ReportPersistenceService {
  static const String _wizardKey = 'wizard_answers_v2';
  static const String _completedKey = 'wizard_completed';
  static const String _strictLppEvidenceKey = '_coach_lpp_evidence_v1';
  static const String _activeLppEvidenceSlotKey = 'lpp_evidence_active_slot_v1';
  static Future<void>? _lppPersistenceTail;
  static const _looseSelfLppKeys = <String>{
    '_coach_avoir_lpp',
    '_coach_avoir_lpp_oblig',
    '_coach_avoir_lpp_suroblig',
    '_coach_salaire_assure',
    '_coach_rachat_maximum',
    '_coach_taux_conversion',
    '_coach_taux_conversion_suroblig',
    '_coach_rendement_caisse',
    '_coach_lpp_source',
  };

  static Map<String, dynamic> backendSafeAnswers(
    Map<String, dynamic> localAnswers,
  ) {
    final hasStrictLppRoot = localAnswers.containsKey(_strictLppEvidenceKey);
    return Map<String, dynamic>.from(localAnswers)
      ..removeWhere(
        (key, _) =>
            key == '__provenance' ||
            key == _strictLppEvidenceKey ||
            key == _activeLppEvidenceSlotKey ||
            legacyPartnerLppAnswerKeys.contains(key) ||
            (hasStrictLppRoot && _looseSelfLppKeys.contains(key)) ||
            key.startsWith('_coach_tax_'),
      );
  }

  /// Sauvegarde les réponses du wizard (incremental off).
  /// SEC-10: Sensitive financial keys are stored in encrypted storage.
  static Future<void> saveAnswers(Map<String, dynamic> answers) =>
      _serializeLppPersistence(() => _saveAnswers(answers));

  static Future<void> _saveAnswers(Map<String, dynamic> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final prepared = Map<String, dynamic>.from(answers);
    if (prefs.getString(_activeLppEvidenceSlotKey) != null) {
      prepared[_strictLppEvidenceKey] = '__secure__';
    }
    final cleaned = await SecureWizardStore.secureSensitiveKeys(prepared);
    final jsonString = json.encode(cleaned);
    await prefs.setString(_wizardKey, jsonString);
  }

  /// Persists the strict LPP root without replacing it before the matching
  /// placeholder map is durable.
  ///
  /// The placeholder is staged and verified first. A replacement therefore
  /// keeps the previous secure root authoritative until the final write, while
  /// an interrupted first write remains unavailable rather than publishing
  /// evidence that was never durably stored.
  static Future<void> saveLppEvidenceAnswers(
    Map<String, dynamic> answers,
  ) =>
      _serializeLppPersistence(() => _saveLppEvidenceAnswers(answers));

  static Future<T> _serializeLppPersistence<T>(
    Future<T> Function() operation,
  ) async {
    final previousOperation = _lppPersistenceTail;
    final completion = Completer<void>();
    final currentOperation = completion.future;
    _lppPersistenceTail = currentOperation;
    if (previousOperation != null) await previousOperation;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_lppPersistenceTail, currentOperation)) {
        _lppPersistenceTail = null;
      }
    }
  }

  static Future<void> _saveLppEvidenceAnswers(
    Map<String, dynamic> answers,
  ) async {
    final strictRoot = answers[_strictLppEvidenceKey];
    if (strictRoot is! String || strictRoot == '__secure__') {
      throw StateError('Strict LPP evidence root is required');
    }

    final prefs = await SharedPreferences.getInstance();
    final previousBytes = prefs.getString(_wizardKey);
    final previousSlotId = prefs.getString(_activeLppEvidenceSlotKey);
    final stagedAnswers = Map<String, dynamic>.from(answers)
      ..[_strictLppEvidenceKey] = '__secure__';
    final cleaned = await SecureWizardStore.secureSensitiveKeys(stagedAnswers);
    final stagedBytes = json.encode(cleaned);

    try {
      final staged = await prefs.setString(_wizardKey, stagedBytes);
      if (!staged || prefs.getString(_wizardKey) != stagedBytes) {
        throw StateError('Strict LPP preferences stage failed');
      }
    } on Object {
      await _restoreWizardBytes(prefs, previousBytes);
      rethrow;
    }

    final nextSlotId = _newLppEvidenceSlotId();
    final stored = await SecureWizardStore.writeLppEvidenceSlot(
      nextSlotId,
      strictRoot,
    );
    if (!stored) {
      await _restoreWizardBytes(prefs, previousBytes);
      await SecureWizardStore.deleteLppEvidenceSlot(nextSlotId);
      throw StateError('Strict LPP secure slot write failed');
    }

    try {
      final activated = await prefs.setString(
        _activeLppEvidenceSlotKey,
        nextSlotId,
      );
      if (!activated ||
          prefs.getString(_activeLppEvidenceSlotKey) != nextSlotId) {
        throw StateError('Strict LPP active slot write failed');
      }
    } on Object {
      await _rollbackLppPublication(
        prefs,
        previousBytes: previousBytes,
        previousSlotId: previousSlotId,
        failedSlotId: nextSlotId,
      );
      rethrow;
    }

    if (previousSlotId != null &&
        previousSlotId != nextSlotId &&
        SecureWizardStore.isValidLppEvidenceSlotId(previousSlotId)) {
      await SecureWizardStore.deleteLppEvidenceSlot(previousSlotId);
    }
    await SecureWizardStore.deleteInactiveLppEvidenceSlots(nextSlotId);
    await SecureWizardStore.deleteLegacyLppEvidenceRoot();
  }

  static String _newLppEvidenceSlotId() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      growable: false,
    ).join();
  }

  static Future<void> _restoreWizardBytes(
    SharedPreferences prefs,
    String? previousBytes,
  ) async {
    final restored = previousBytes == null
        ? await prefs.remove(_wizardKey)
        : await prefs.setString(_wizardKey, previousBytes);
    if (!restored || prefs.getString(_wizardKey) != previousBytes) {
      throw StateError('Strict LPP preferences rollback failed');
    }
  }

  static Future<void> _restoreLppSlotPointer(
    SharedPreferences prefs,
    String? previousSlotId,
  ) async {
    final restored = previousSlotId == null
        ? await prefs.remove(_activeLppEvidenceSlotKey)
        : await prefs.setString(_activeLppEvidenceSlotKey, previousSlotId);
    if (!restored ||
        prefs.getString(_activeLppEvidenceSlotKey) != previousSlotId) {
      throw StateError('Strict LPP active slot rollback failed');
    }
  }

  static Future<void> _rollbackLppPublication(
    SharedPreferences prefs, {
    required String? previousBytes,
    required String? previousSlotId,
    required String failedSlotId,
  }) async {
    Object? rollbackFailure;
    try {
      await _restoreLppSlotPointer(prefs, previousSlotId);
    } on Object catch (error) {
      rollbackFailure = error;
    }
    try {
      await _restoreWizardBytes(prefs, previousBytes);
    } on Object catch (error) {
      rollbackFailure ??= error;
    }
    await SecureWizardStore.deleteLppEvidenceSlot(failedSlotId);
    if (rollbackFailure != null) {
      throw StateError('Strict LPP cross-store rollback failed');
    }
  }

  /// Charge les réponses existantes.
  /// SEC-10: Sensitive financial keys are restored from encrypted storage.
  static Future<Map<String, dynamic>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_wizardKey);

    if (jsonString == null) return {};

    try {
      final answers = Map<String, dynamic>.from(json.decode(jsonString));
      final restored = await SecureWizardStore.restoreSensitiveKeys(answers);
      final withLpp = await _restoreLppEvidenceRoot(prefs, restored);
      return await _normalizeLegacyCashTotal(withLpp);
    } catch (e, stack) {
      dev.log('Failed to decode wizard answers',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _restoreLppEvidenceRoot(
    SharedPreferences prefs,
    Map<String, dynamic> answers,
  ) async {
    if (answers[_strictLppEvidenceKey] != '__secure__') return answers;
    final restored = Map<String, dynamic>.from(answers);
    final activeSlotId = prefs.getString(_activeLppEvidenceSlotKey);
    if (activeSlotId != null) {
      final root = await SecureWizardStore.readLppEvidenceSlot(activeSlotId);
      if (root != null) restored[_strictLppEvidenceKey] = root;
      return restored;
    }

    final legacyRoot = await SecureWizardStore.readLegacyLppEvidenceRoot();
    if (legacyRoot == null) return restored;
    await _migrateLegacyLppEvidenceRoot(prefs, legacyRoot);

    final migratedSlotId = prefs.getString(_activeLppEvidenceSlotKey);
    if (migratedSlotId != null) {
      final migratedRoot =
          await SecureWizardStore.readLppEvidenceSlot(migratedSlotId);
      if (migratedRoot != null) {
        restored[_strictLppEvidenceKey] = migratedRoot;
      }
    } else if (_wizardHasStrictLppPlaceholder(prefs)) {
      final retainedLegacyRoot =
          await SecureWizardStore.readLegacyLppEvidenceRoot();
      if (retainedLegacyRoot != null) {
        restored[_strictLppEvidenceKey] = retainedLegacyRoot;
      }
    }
    return restored;
  }

  static Future<void> _migrateLegacyLppEvidenceRoot(
    SharedPreferences prefs,
    String legacyRoot,
  ) =>
      _serializeLppPersistence(
        () => _migrateLegacyLppEvidenceRootLocked(prefs, legacyRoot),
      );

  static Future<void> _migrateLegacyLppEvidenceRootLocked(
    SharedPreferences prefs,
    String legacyRoot,
  ) async {
    if (prefs.getString(_activeLppEvidenceSlotKey) != null ||
        !_wizardHasStrictLppPlaceholder(prefs) ||
        await SecureWizardStore.readLegacyLppEvidenceRoot() != legacyRoot) {
      return;
    }

    final slotId = _newLppEvidenceSlotId();
    final stored = await SecureWizardStore.writeLppEvidenceSlot(
      slotId,
      legacyRoot,
    );
    if (!stored) return;

    try {
      final activated =
          await prefs.setString(_activeLppEvidenceSlotKey, slotId);
      if (!activated || prefs.getString(_activeLppEvidenceSlotKey) != slotId) {
        throw StateError('Legacy LPP active slot migration failed');
      }
    } on Object {
      await _restoreLppSlotPointer(prefs, null);
      await SecureWizardStore.deleteLppEvidenceSlot(slotId);
      return;
    }
    await SecureWizardStore.deleteInactiveLppEvidenceSlots(slotId);
    await SecureWizardStore.deleteLegacyLppEvidenceRoot();
  }

  static bool _wizardHasStrictLppPlaceholder(SharedPreferences prefs) {
    final wizardBytes = prefs.getString(_wizardKey);
    if (wizardBytes == null) return false;
    try {
      final wizard = json.decode(wizardBytes);
      return wizard is Map && wizard[_strictLppEvidenceKey] == '__secure__';
    } on Object {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _normalizeLegacyCashTotal(
    Map<String, dynamic> answers,
  ) async {
    if (!_looksLikeLegacyUnprovenancedCash(answers)) return answers;

    final legacyCash = _parseDouble(answers['q_cash_total']);
    final cleaned = Map<String, dynamic>.from(answers)
      ..remove('q_cash_total')
      ..['q_cash_total_unconfirmed_legacy'] = legacyCash;
    final persisted = Map<String, dynamic>.from(cleaned)
      ..['q_cash_total'] = null;
    dev.log(
      'Quarantined legacy unprovenanced q_cash_total estimate',
      name: 'Persistence',
    );
    await saveAnswers(persisted);
    return cleaned;
  }

  static bool _looksLikeLegacyUnprovenancedCash(
    Map<String, dynamic> answers,
  ) {
    if (!answers.containsKey('q_cash_total')) return false;
    final cash = _parseDouble(answers['q_cash_total']);
    if (cash == null || cash <= 0) return false;
    if (_hasExplicitCashSource(answers)) return false;
    return _looksLikeLegacyEmergencyFundCash(answers, cash) ||
        _looksLikeLegacySmartFlowCash(answers, cash);
  }

  static bool _looksLikeLegacyEmergencyFundCash(
    Map<String, dynamic> answers,
    double cash,
  ) {
    final emergencyFund = answers['q_emergency_fund'];
    if (emergencyFund is! String) return false;
    final heuristicCash = EmergencyFundHeuristic.cashForWizardBucket(
      emergencyFundBucket: emergencyFund,
      housingCost: _parseDouble(answers['q_housing_cost_period_chf']) ?? 0,
      monthlyLamalPremium:
          _parseDouble(answers['q_lamal_premium_monthly_chf']) ?? 0,
      housingPayFrequency: answers['q_housing_pay_frequency'] as String?,
    );
    return heuristicCash > 0 && (cash - heuristicCash).abs() <= 0.01;
  }

  static bool _hasExplicitCashSource(Map<String, dynamic> answers) {
    final source = answers['_coach_cash_total_source'];
    return source == 'userInput' ||
        source == 'openBanking' ||
        source == 'certificate' ||
        source == 'crossValidated';
  }

  static bool _looksLikeLegacySmartFlowCash(
    Map<String, dynamic> answers,
    double cash,
  ) {
    final birthYear = _parseInt(answers['q_birth_year']);
    final grossSalary = _parseDouble(answers['q_gross_salary_annual']);
    if (birthYear == null || grossSalary == null) return false;
    final age = DateTime.now().year - birthYear;
    final heuristicCash = LegacyCashEstimateHeuristic.smartFlowSavingsEstimate(
      age: age,
      grossSalary: grossSalary,
    );
    // A rare real user amount can equal the old estimate exactly. Quarantine is
    // still reversible through q_cash_total_unconfirmed_legacy and safer than
    // promoting a fabricated cash amount to high-stakes scenarios.
    return heuristicCash > 0 && (cash - heuristicCash).abs() <= 0.01;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Marque le wizard comme complété (pour ne pas le relancer au reboot)
  static Future<void> setCompleted(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, isCompleted);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  //  MINI-ONBOARDING PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _miniOnboardingKey = 'mini_onboarding_completed';
  static const String _miniOnboardingVariantKey = 'mini_onboarding_variant_v1';
  static const String _miniOnboardingExposureTrackedKey =
      'mini_onboarding_exposure_tracked_v1';
  static const String _onboardingMetricsControlKey =
      'mini_onboarding_metrics_control_v1';
  static const String _onboardingMetricsChallengeKey =
      'mini_onboarding_metrics_challenge_v1';
  static const String _onboardingCohortMetricsKey =
      'mini_onboarding_cohort_metrics_v1';
  static const String _selectedIntentKey = 'selected_onboarding_intent_v1';

  // Premier insight persistence keys (D-09).
  static const String _hasSeenPremierEclairageKey =
      'has_seen_premier_eclairage_v1';
  static const String _premierEclairageSnapshotKey =
      'premier_eclairage_snapshot_v1';

  static Future<void>? _metricLock;

  /// Marks the mini-onboarding as completed.
  static Future<void> setMiniOnboardingCompleted(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_miniOnboardingKey, isCompleted);
  }

  /// Returns whether the mini-onboarding has been completed.
  static Future<bool> isMiniOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_miniOnboardingKey) ?? false;
  }

  /// Persists the onboarding intent selected by the user.
  static Future<void> setSelectedOnboardingIntent(String intent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedIntentKey, intent);
  }

  /// Returns the selected onboarding intent, if any.
  static Future<String?> getSelectedOnboardingIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedIntentKey);
  }

  /// Returns a persistent A/B variant for mini-onboarding.
  /// Possible values: 'control' or 'challenge'.
  static Future<String> getOrCreateMiniOnboardingVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_miniOnboardingVariantKey);
    if (existing == 'control' || existing == 'challenge') {
      return existing!;
    }
    final variant = Random().nextBool() ? 'control' : 'challenge';
    await prefs.setString(_miniOnboardingVariantKey, variant);
    return variant;
  }

  /// Returns whether mini-onboarding exposure has already been tracked.
  static Future<bool> isMiniOnboardingExposureTracked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_miniOnboardingExposureTrackedKey) ?? false;
  }

  /// Marks mini-onboarding exposure as tracked.
  static Future<void> setMiniOnboardingExposureTracked(bool tracked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_miniOnboardingExposureTrackedKey, tracked);
  }

  static String _metricsKeyForVariant(String variant) {
    return variant == 'challenge'
        ? _onboardingMetricsChallengeKey
        : _onboardingMetricsControlKey;
  }

  static Map<String, int> _defaultOnboardingMetrics() {
    return const {
      'started': 0,
      'completed': 0,
      'abandoned': 0,
      'step_1': 0,
      'step_2': 0,
      'step_3': 0,
      'step_4': 0,
      'exit_prompt_shown': 0,
      'exit_prompt_stay': 0,
      'exit_prompt_leave': 0,
      'step2_aha_shown': 0,
      'step2_to_step3_after_aha': 0,
      'quick_pick_birth_year': 0,
      'quick_pick_income': 0,
      'duration_step_1_sum': 0,
      'duration_step_1_count': 0,
      'duration_step_2_sum': 0,
      'duration_step_2_count': 0,
      'duration_step_3_sum': 0,
      'duration_step_3_count': 0,
      'duration_step_4_sum': 0,
      'duration_step_4_count': 0,
    };
  }

  /// Charge les metriques onboarding d'une variante.
  static Future<Map<String, int>> loadMiniOnboardingMetrics(
    String variant,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _metricsKeyForVariant(variant);
    final jsonString = prefs.getString(key);
    if (jsonString == null) {
      return _defaultOnboardingMetrics();
    }
    try {
      final decoded = Map<String, dynamic>.from(json.decode(jsonString));
      final defaults = _defaultOnboardingMetrics();
      final merged = <String, int>{};
      for (final entry in defaults.entries) {
        final value = decoded[entry.key];
        merged[entry.key] = value is num ? value.toInt() : entry.value;
      }
      return merged;
    } catch (e, stack) {
      dev.log('Failed to decode onboarding metrics',
          error: e, stackTrace: stack, name: 'Persistence');
      return _defaultOnboardingMetrics();
    }
  }

  /// Incremente un compteur onboarding pour une variante.
  static Future<void> incrementMiniOnboardingMetric(
    String variant,
    String metricKey, {
    int by = 1,
  }) async {
    // Serialize concurrent calls to prevent lost increments
    while (_metricLock != null) {
      await _metricLock;
    }
    final completer = Completer<void>();
    _metricLock = completer.future;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _metricsKeyForVariant(variant);
      final current = Map<String, int>.from(
        await loadMiniOnboardingMetrics(variant),
      );
      current[metricKey] = (current[metricKey] ?? 0) + by;
      await prefs.setString(key, json.encode(current));
    } finally {
      _metricLock = null;
      completer.complete();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PREMIER INSIGHT PERSISTENCE (D-09)
  // ═══════════════════════════════════════════════════════════

  /// Saves a premier insight snapshot to SharedPreferences.
  ///
  /// [data] MUST contain only display fields:
  ///   value (formatted string), title, subtitle, colorKey, suggestedRoute.
  /// NEVER store raw salary, IBAN, or PII — per T-03-02 threat mitigation.
  static Future<void> savePremierEclairageSnapshot(
      Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_premierEclairageSnapshotKey, json.encode(data));
  }

  /// Loads the premier insight snapshot. Returns null if not set or on error.
  static Future<Map<String, dynamic>?> loadPremierEclairageSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_premierEclairageSnapshotKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the user has already seen their premier insight card.
  static Future<bool> hasSeenPremierEclairage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenPremierEclairageKey) ?? false;
  }

  /// Marks the premier insight card as seen.
  static Future<void> markPremierEclairageSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenPremierEclairageKey, true);
  }

  /// Clears onboarding metrics for both variants.
  static Future<void> clearMiniOnboardingMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingMetricsControlKey);
    await prefs.remove(_onboardingMetricsChallengeKey);
    await prefs.remove(_onboardingCohortMetricsKey);
  }

  /// Charge les metriques cohortes onboarding.
  ///
  /// Structure:
  /// {
  ///   "control": {
  ///     "stress_budget|emp_employee|inc_mid": {"started": 3, "completed": 2}
  ///   },
  ///   "challenge": {...}
  /// }
  static Future<Map<String, dynamic>> loadMiniOnboardingCohortMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_onboardingCohortMetricsKey);
    if (jsonString == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e, stack) {
      dev.log('Failed to decode onboarding cohort metrics',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  /// Incremente un metric de cohorte onboarding (started/completed/etc).
  static Future<void> incrementMiniOnboardingCohortMetric(
    String variant,
    String profileBucket,
    String metricKey, {
    int by = 1,
  }) async {
    // Serialize concurrent calls to prevent lost increments
    while (_metricLock != null) {
      await _metricLock;
    }
    final completer = Completer<void>();
    _metricLock = completer.future;
    try {
      final prefs = await SharedPreferences.getInstance();
      final root = Map<String, dynamic>.from(
        await loadMiniOnboardingCohortMetrics(),
      );

      final variantMap = Map<String, dynamic>.from(
        (root[variant] as Map?) ?? const {},
      );
      final bucketMap = Map<String, dynamic>.from(
        (variantMap[profileBucket] as Map?) ?? const {},
      );
      final current = (bucketMap[metricKey] as num?)?.toInt() ?? 0;
      bucketMap[metricKey] = current + by;
      variantMap[profileBucket] = bucketMap;
      root[variant] = variantMap;

      await prefs.setString(_onboardingCohortMetricsKey, json.encode(root));
    } finally {
      _metricLock = null;
      completer.complete();
    }
  }

  /// Export CSV des cohortes A/B avec completion par profil.
  static Future<String> exportMiniOnboardingCohortCsv() async {
    final root = await loadMiniOnboardingCohortMetrics();
    final buffer = StringBuffer();
    buffer.writeln(
      'variant,profile_bucket,started,completed,completion_rate_pct',
    );

    for (final variantEntry in root.entries) {
      final variant = variantEntry.key;
      final variantMap = variantEntry.value;
      if (variantMap is! Map) continue;
      for (final bucketEntry in variantMap.entries) {
        final bucket = bucketEntry.key;
        final bucketMap = bucketEntry.value;
        if (bucketMap is! Map) continue;
        final started = (bucketMap['started'] as num?)?.toInt() ?? 0;
        final completed = (bucketMap['completed'] as num?)?.toInt() ?? 0;
        final rate = started <= 0 ? 0.0 : (completed / started) * 100;
        buffer.writeln(
          '$variant,$bucket,$started,$completed,${rate.toStringAsFixed(1)}',
        );
      }
    }

    return buffer.toString();
  }

  static const String _lettersKey = 'generated_letters_history';

  static Future<void> saveLettersHistory(
      List<Map<String, dynamic>> letters) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(letters);
    await prefs.setString(_lettersKey, jsonString);
  }

  static Future<List<Map<String, dynamic>>> loadLettersHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_lettersKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(json.decode(jsonString));
    } catch (e, stack) {
      dev.log('Failed to decode letters history',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PLANNED CONTRIBUTIONS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _contributionsKey = 'planned_contributions_v1';

  /// Sauvegarde les versements planifiés (JSON list)
  static Future<void> saveContributions(
      List<Map<String, dynamic>> contributions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contributionsKey, json.encode(contributions));
  }

  /// Charge les versements planifiés
  static Future<List<Map<String, dynamic>>> loadContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_contributionsKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode contributions',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  /// Vérifie si des contributions ont été personnalisées
  static Future<bool> hasCustomContributions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_contributionsKey);
  }

  // ═══════════════════════════════════════════════════════════
  //  CHECK-INS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _checkInsKey = 'monthly_checkins_v1';

  /// Sauvegarde l'historique des check-ins (JSON list)
  static Future<void> saveCheckIns(List<Map<String, dynamic>> checkIns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkInsKey, json.encode(checkIns));
  }

  /// Charge l'historique des check-ins
  static Future<List<Map<String, dynamic>>> loadCheckIns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_checkInsKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode check-ins',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCORE HISTORY PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _lastScoreKey = 'last_fitness_score_v1';
  static const String _lastScoreMonthKey = 'last_fitness_score_month_v1';
  static const String _scoreHistoryKey = 'score_history_v1';
  static const String _lastScoreReasonKey = 'last_fitness_score_reason_v1';
  static const String _lastScoreDeltaKey = 'last_fitness_score_delta_v1';
  static const String _lastScoreReasonAtKey = 'last_fitness_score_reason_at_v1';
  static const String _coachNarrativeModeKey = 'coach_narrative_mode_v1';

  /// Sauvegarde le score du mois en cours pour comparer au suivant.
  /// Ajoute egalement le score a l'historique mensuel.
  static Future<void> saveLastScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await prefs.setInt(_lastScoreKey, score);
    await prefs.setString(_lastScoreMonthKey, monthKey);
    // Ajouter automatiquement a l'historique
    await saveScoreToHistory(score);
  }

  /// Charge le dernier score enregistre (null si premier mois).
  static Future<int?> loadLastScore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMonth = prefs.getString(_lastScoreMonthKey);
    if (savedMonth == null) return null;
    return prefs.getInt(_lastScoreKey);
  }

  /// Ajoute un score a l'historique mensuel.
  /// Stocke au max 24 entrees (supprime les plus anciennes si > 24).
  /// Format: [{"month": "2026-02", "score": 72}, ...]
  static Future<void> saveScoreToHistory(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Load existing history.
    List<Map<String, dynamic>> history = await loadScoreHistory();

    // Replace the current-month entry when it already exists.
    final existingIndex =
        history.indexWhere((entry) => entry['month'] == monthKey);
    if (existingIndex >= 0) {
      history[existingIndex] = {'month': monthKey, 'score': score};
    } else {
      history.add({'month': monthKey, 'score': score});
    }

    // Limiter a 24 entrees (supprimer les plus anciennes)
    while (history.length > 24) {
      history.removeAt(0);
    }

    await prefs.setString(_scoreHistoryKey, json.encode(history));
  }

  /// Charge l'historique des scores mensuels.
  /// Retourne une liste de maps {"month": "2026-02", "score": 72}.
  static Future<List<Map<String, dynamic>>> loadScoreHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_scoreHistoryKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode score history',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  /// Sauvegarde la raison explicative du dernier delta de score (check-in).
  static Future<void> saveLastScoreAttribution({
    required String reason,
    required int delta,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScoreReasonKey, reason);
    await prefs.setInt(_lastScoreDeltaKey, delta);
    await prefs.setString(
        _lastScoreReasonAtKey, DateTime.now().toIso8601String());
  }

  /// Charge la raison explicative du dernier delta de score (si presente).
  static Future<Map<String, dynamic>?> loadLastScoreAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    final reason = prefs.getString(_lastScoreReasonKey);
    if (reason == null || reason.trim().isEmpty) return null;
    return {
      'reason': reason,
      'delta': prefs.getInt(_lastScoreDeltaKey) ?? 0,
      'at': prefs.getString(_lastScoreReasonAtKey),
    };
  }

  /// Mode de narration partage entre Dashboard/Agir:
  /// - detailed (par defaut)
  /// - concise
  static Future<String> loadCoachNarrativeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_coachNarrativeModeKey);
    if (mode == 'concise' || mode == 'detailed') {
      return mode!;
    }
    return 'detailed';
  }

  static Future<void> saveCoachNarrativeMode(String mode) async {
    if (mode != 'concise' && mode != 'detailed') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coachNarrativeModeKey, mode);
  }

  // ═══════════════════════════════════════════════════════════
  //  EXPLORED SIMULATORS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _exploredSimulatorsKey = 'explored_simulators_v1';
  static const String _exploredLifeEventsKey = 'explored_life_events_v1';
  static const String _dismissedTipsKey = 'dismissed_tips_v1';
  static const String _snoozedTipsKey = 'snoozed_tips_v1';
  static const String _onboarding30PlanKey = 'onboarding_30_day_plan_v1';

  /// Marque un simulateur comme exploré (pour le suivi de progression)
  static Future<void> markSimulatorExplored(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_exploredSimulatorsKey) ?? [];
    if (!existing.contains(id)) {
      existing.add(id);
      await prefs.setStringList(_exploredSimulatorsKey, existing);
    }
  }

  /// Charge la liste des simulateurs explorés
  static Future<Set<String>> loadExploredSimulators() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_exploredSimulatorsKey) ?? [];
    return list.toSet();
  }

  // ═══════════════════════════════════════════════════════════
  //  ONBOARDING 30 DAYS PLAN PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  /// Loads the persisted onboarding 30-day plan state.
  /// Returned map keys:
  /// - started_at (ISO string)
  /// - completed (bool)
  /// - completed_at (ISO string)
  /// - stress_choice (string)
  /// - main_goal (string)
  /// - last_route (string)
  /// - opened_routes (List<String>)
  static Future<Map<String, dynamic>> loadOnboarding30PlanState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_onboarding30PlanKey);
    if (jsonString == null) return {};
    try {
      final decoded = Map<String, dynamic>.from(json.decode(jsonString));
      final opened = decoded['opened_routes'];
      if (opened is List) {
        decoded['opened_routes'] = opened.map((e) => e.toString()).toList();
      } else {
        decoded['opened_routes'] = <String>[];
      }
      decoded['completed'] = decoded['completed'] == true;
      return decoded;
    } catch (e, stack) {
      dev.log('Failed to decode onboarding 30-day plan state',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  static Future<void> _saveOnboarding30PlanState(
    Map<String, dynamic> state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_onboarding30PlanKey, json.encode(state));
  }

  /// Marks the onboarding 30-day plan as started (idempotent).
  static Future<void> markOnboarding30PlanStarted({
    String? stressChoice,
    String? mainGoal,
  }) async {
    final state = await loadOnboarding30PlanState();
    state.putIfAbsent('started_at', () => DateTime.now().toIso8601String());
    state['completed'] = state['completed'] == true;
    state.putIfAbsent('opened_routes', () => <String>[]);
    if (stressChoice != null && stressChoice.isNotEmpty) {
      state['stress_choice'] = stressChoice;
    }
    if (mainGoal != null && mainGoal.isNotEmpty) {
      state['main_goal'] = mainGoal;
    }
    await _saveOnboarding30PlanState(state);
  }

  /// Stores the last opened route and appends it to opened_routes if missing.
  static Future<void> markOnboarding30PlanRouteOpened(String route) async {
    final state = await loadOnboarding30PlanState();
    final opened =
        List<String>.from((state['opened_routes'] as List?) ?? const []);
    if (!opened.contains(route)) {
      opened.add(route);
    }
    state['opened_routes'] = opened;
    state['last_route'] = route;
    await _saveOnboarding30PlanState(state);
  }

  /// Sets completion flag for onboarding 30-day plan.
  static Future<void> setOnboarding30PlanCompleted(bool completed) async {
    final state = await loadOnboarding30PlanState();
    state['completed'] = completed;
    if (completed) {
      state['completed_at'] = DateTime.now().toIso8601String();
    } else {
      state.remove('completed_at');
    }
    await _saveOnboarding30PlanState(state);
  }

  /// Clears onboarding 30-day plan local state.
  static Future<void> clearOnboarding30PlanState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboarding30PlanKey);
  }

  /// Efface tout (Logout / Reset)
  static Future<void> clear({
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
  }) async {
    await clearDiagnostic(
      partnerAccountabilityBindingStore: partnerAccountabilityBindingStore,
    );
    final prefs = await SharedPreferences.getInstance();
    await clearCoachHistory();
    await prefs.remove(_lettersKey);
  }

  /// Clears coach history only:
  /// - monthly check-ins
  /// - current score and score history
  /// - simulator progress
  /// - user activity such as life events and dismissed or snoozed tips
  static Future<void> clearCoachHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checkInsKey);
    await prefs.remove(_lastScoreKey);
    await prefs.remove(_lastScoreMonthKey);
    await prefs.remove(_scoreHistoryKey);
    await prefs.remove(_lastScoreReasonKey);
    await prefs.remove(_lastScoreDeltaKey);
    await prefs.remove(_lastScoreReasonAtKey);
    await prefs.remove(_exploredSimulatorsKey);
    await prefs.remove(_exploredLifeEventsKey);
    await prefs.remove(_dismissedTipsKey);
    await prefs.remove(_snoozedTipsKey);
  }

  /// Efface le diagnostic/profil financier:
  /// - réponses wizard/mini-onboarding
  /// - flags de complétion
  /// - contributions planifiées liées au profil
  static Future<void> clearDiagnostic({
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
  }) =>
      _serializeLppPersistence(
        () => _clearDiagnostic(partnerAccountabilityBindingStore),
      );

  static Future<void> _clearDiagnostic(
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
  ) async {
    await (partnerAccountabilityBindingStore ??
            PartnerAccountabilityBindingStore())
        .clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wizardKey);
    await prefs.remove(_activeLppEvidenceSlotKey);
    await SecureWizardStore.deleteAll();
    await prefs.remove(_completedKey);
    await prefs.remove(_miniOnboardingKey);
    await prefs.remove(_miniOnboardingVariantKey);
    await prefs.remove(_miniOnboardingExposureTrackedKey);
    await prefs.remove(_onboardingMetricsControlKey);
    await prefs.remove(_onboardingMetricsChallengeKey);
    await prefs.remove(_onboardingCohortMetricsKey);
    await prefs.remove(_selectedIntentKey);
    await prefs.remove(_contributionsKey);
    await prefs.remove(_onboarding30PlanKey);
    await prefs.remove(_coachNarrativeModeKey);
    await prefs.remove(_hasSeenPremierEclairageKey);
    await prefs.remove(_premierEclairageSnapshotKey);
  }
}
