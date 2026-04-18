import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/coach_cache_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/snapshot_service.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;

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

  /// Le profil Coach construit a partir des reponses wizard.
  /// Null si le wizard n'a pas ete complete.
  CoachProfile? get profile => _profile;

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
      final answers = Map<String, dynamic>.from(_lastAnswers);
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
  Future<void> syncFromBackend() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) return;
      final remoteData = await ApiService.get('/profiles/me');
      if (remoteData is Map<String, dynamic>) {
        mergeFromRemoteProfile(remoteData);
        // Also merge financial fields that the basic merge doesn't cover.
        _mergeFinancialFieldsFromRemote(remoteData);
      }
    } catch (e) {
      debugPrint('[CoachProfile] syncFromBackend failed (non-fatal): $e');
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
    if ((p.salaireAssure ?? 0) <= 0 && remoteSalaire != null && remoteSalaire > 0) {
      partial['_coach_salaire_assure'] = remoteSalaire;
    }
    // LPP rachat max
    final remoteRachat = (remote['lppBuybackMax'] as num?)?.toDouble();
    if ((p.rachatMaximum ?? 0) <= 0 && remoteRachat != null && remoteRachat > 0) {
      partial['_coach_rachat_maximum'] = remoteRachat;
    }
    // 3a balance
    final remote3a = (remote['pillar3aBalance'] as num?)?.toDouble();
    if ((p.totalEpargne3a ?? 0) <= 0 && remote3a != null && remote3a > 0) {
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
    if (p.etatCivil == CoachCivilStatus.marie ||
        p.etatCivil == CoachCivilStatus.concubinage) {
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
  Future<void> loadFromWizard() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check full wizard first
      final isFullCompleted = await ReportPersistenceService.isCompleted();
      final answers = await ReportPersistenceService.loadAnswers();
      _lastAnswers = answers;

      if (isFullCompleted && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers);
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
        _profile = CoachProfile.fromWizardAnswers(answers);
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

  /// Met a jour le profil directement a partir d'un map d'answers.
  /// Utilise apres la completion du wizard pour eviter un rechargement async.
  void updateFromAnswers(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _lastAnswers = answers;
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = false;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Merge individual fields into the existing profile (incremental update).
  /// Used by chat inline pickers to update one field at a time without
  /// overwriting the rest of the profile.
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    if (partial.isEmpty) return;
    final merged = Map<String, dynamic>.from(_lastAnswers)..addAll(partial);
    _lastAnswers = merged;
    _profile = CoachProfile.fromWizardAnswers(merged);
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    await ReportPersistenceService.saveAnswers(merged);
    notifyListeners();
    _syncToBackend(); // Fire-and-forget, does not block UI
  }

  /// Met a jour le profil depuis le mini-onboarding (3-4 questions).
  /// Cree un profil partiel immediatement utilisable par le dashboard.
  void updateFromMiniOnboarding(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _lastAnswers = answers;
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
    /// True if a Swiss national has lived abroad and interrupted cotisations.
    /// Maps to q_avs_lacunes_status = 'lived_abroad' so fromWizardAnswers()
    /// computes the correct LPP gap and AVS reduction.
    bool? hasLivedAbroad,
    /// Year since which the user contributed to Swiss AVS/LPP (if hasLivedAbroad
    /// or non-Swiss). Used to derive yearsAbroad for the wizard answers.
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
    const double socialChargesRate = 0.13;
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
      nationality = 'FR'; // Generic EU/AELE placeholder → triggers expatEu archetype
    } else if (nationalityGroup == 'OTHER') {
      nationality = nationalityCountry; // 'US' → expatUs; null → expatNonEu fallback
    }

    // Returning Swiss: compute yearsAbroad from arrivalYear and birthYear.
    // yearsAbroad = arrivalYear - (birthYear + 21) clamped to [0, age-21].
    // This matches fromWizardAnswers 'lived_abroad' logic: avsGaps = yearsAbroad.
    int? yearsAbroad;
    if (hasLivedAbroad == true && arrivalYear != null) {
      yearsAbroad = (arrivalYear - (birthYear + 21)).clamp(0, age - 21);
    }

    final bool isReturningSwiss = hasLivedAbroad == true && arrivalYear != null;
    // Non-Swiss expat arriving late: contributions start from arrivalYear.
    final bool isExpat =
        nationalityGroup != null && nationalityGroup != 'CH' && arrivalYear != null;

    // Compute smart estimates via MinimalProfileService (financial_core)
    // so the aperçu financier shows realistic values instead of zeros.
    final minimal = MinimalProfileService.compute(
      age: age,
      grossSalary: clampedGrossSalary,
      canton: canton,
    );

    // AVS contribution years (LAVS art. 29 — cotisations dès 21 ans).
    final int rawAvsYears;
    if (isReturningSwiss) {
      // Reduced by time abroad
      rawAvsYears = (age - 20) - (yearsAbroad ?? 0);
    } else if (isExpat) {
      // Contributions start from max(arrivalAge, 21)
      final arrivalAge = arrivalYear - birthYear;
      final startAge = arrivalAge > 21 ? arrivalAge : 21;
      rawAvsYears = age - startAge;
    } else {
      // Swiss native: cotisations since age 21
      rawAvsYears = age - 20;
    }
    final avsContributionYears = rawAvsYears.clamp(0, 44);
    // Flag when the raw value was outside [0, 44] so UI can inform the user.
    final bool avsYearsWereClamped = rawAvsYears != avsContributionYears;

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
          clampedGrossSalary >= 22680 && effectiveEmployment != 'independant',
      // AVS years estimated from age and situation (LAVS art. 29)
      'q_avs_contribution_years': avsContributionYears,
      // P2-15: Flag when AVS years were clamped to [0,44] so UI can warn user.
      if (avsYearsWereClamped) '_avs_years_clamped': true,
      // AVS rente estimated via financial_core AvsCalculator
      '_coach_avs_rente_estimee': minimal.avsMonthlyRente,
      // Patrimoine: estimated savings = (age-25) × salary × 5%
      'q_cash_total': minimal.currentSavings,
      // Nationality for archetype detection (see CLAUDE.md archetype table)
      if (nationality != null) 'q_nationality': nationality,
      if (primaryFocus != null) 'q_primary_focus': primaryFocus,
      if (permitType != null) 'q_residence_permit': permitType,
    };

    // Returning Swiss: inject lacunes and arrivalYear so fromWizardAnswers
    // correctly starts LPP bonifications from arrivalAge, not from 25.
    if (isReturningSwiss) {
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      answers['q_avs_years_abroad'] = yearsAbroad;
      answers['q_avs_arrival_year'] = arrivalYear;
    } else if (isExpat) {
      // Non-Swiss expat: use 'arrived_late' so fromWizardAnswers computes
      // arrivalAge and starts LPP bonifications from the correct age.
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] = arrivalYear;
    }

    _lastAnswers = answers;
    _profile = CoachProfile.fromWizardAnswers(answers);
    // Inject firstName immediately if provided — not part of wizard answers map.
    if (firstName != null && firstName.isNotEmpty) {
      _profile = _profile!.copyWith(firstName: firstName);
    }

    // S47: Stamp initial timestamps for all fields populated by onboarding.
    // Core fields are userInput quality (age, salary, canton); derived fields
    // (AVS, LPP estimates, savings) are estimated quality but still get timestamps
    // so freshness scoring can track when the profile was last refreshed.
    final initialFields = <String>[
      'salaireBrutMensuel',
      'age',
      'canton',
      'etatCivil',
      'prevoyance.avoirLppTotal',
      'prevoyance.totalEpargne3a',
      'prevoyance.anneesContribuees',
      'prevoyance.renteAVSEstimeeMensuelle',
      'patrimoine.epargneLiquide',
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
    if (_profile != null) return; // Already has local profile, use merge instead

    final birthYear = remote['birth_year'] as int? ??
        remote['birthYear'] as int?;
    final canton = remote['canton'] as String?;
    final grossYearly = (remote['income_gross_yearly'] as num?)?.toDouble() ??
        (remote['incomeGrossYearly'] as num?)?.toDouble();
    final gender = remote['gender'] as String?;
    final employmentStatus = remote['employment_status'] as String? ??
        remote['employmentStatus'] as String?;

    // Only create if we have at least one meaningful field from backend
    if (birthYear == null && canton == null && grossYearly == null) return;

    // P0-9: Clamp remote salary to valid bounds.
    final clampedGrossYearly = grossYearly?.clamp(0, 10000000).toDouble();
    final salaireBrutMensuel = clampedGrossYearly != null ? clampedGrossYearly / 12 : 0.0;
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
    if ((p.canton.isEmpty || p.canton == 'unknown') && remoteData['canton'] != null) {
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
      birthYear: updates.containsKey('birthYear')
          ? updates['birthYear'] as int
          : null,
      canton: updates.containsKey('canton')
          ? updates['canton'] as String?
          : null,
      gender: updates.containsKey('gender')
          ? updates['gender'] as String?
          : null,
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
    final previousStatus = _profile?.etatCivil;
    _profile = updated;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
    // FIX-045: Persist ALL profile fields.
    _persistFullProfile(updated);
    // FIX-HIGH-1: Invalidate coach cache on profile change (was never called).
    CoachCacheService.invalidate(InvalidationTrigger.profileUpdate);
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
        previousStatus != updated.etatCivil &&
        updated.etatCivil != CoachCivilStatus.marie &&
        updated.etatCivil != CoachCivilStatus.concubinage) {
      // FIX-097: Clear local household state on divorce (AWAITED).
      // FIX-P0-1: Remove ALL partner/spouse keys to prevent ghost conjoint
      // on app restart. Without this, fromWizardAnswers() recreates the spouse
      // from stale SharedPreferences → AVS couple cap 150% applied to a single.
      // FIX-P0-3: Was fire-and-forget → now awaited to guarantee cleanup before
      // any subsequent read.
      _awaitedDivorceCleanup();
    }
  }

  /// Awaited divorce cleanup — removes all partner/spouse keys from SharedPreferences.
  /// Previously fire-and-forget (.then/.catchError), which could race with subsequent reads.
  Future<void> _awaitedDivorceCleanup() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('_household_data');
      final keysToRemove = sp.getKeys().where(
          (k) => k.startsWith('q_partner_') || k.startsWith('q_spouse_'));
      for (final key in keysToRemove.toList()) {
        await sp.remove(key);
      }
    } catch (_) {
      // Best-effort: SharedPreferences failure is non-fatal.
    }
  }

  Future<void> _persistFullProfile(CoachProfile profile) async {
    final answers = await ReportPersistenceService.loadAnswers();
    // Core fields
    if (profile.canton.isNotEmpty) answers['q_canton'] = profile.canton;
    // FIX-096: Persist etatCivil (divorce was lost on restart).
    answers['q_civil_status'] = profile.etatCivil.name;
    answers['q_salaire'] = profile.salaireBrutMensuel;
    answers['q_nombre_mois'] = profile.nombreDeMois;
    if (profile.employmentStatus.isNotEmpty) {
      answers['q_employment_status'] = profile.employmentStatus;
    }
    // Prevoyance
    if (profile.prevoyance.avoirLppTotal != null) {
      answers['q_avoir_lpp'] = profile.prevoyance.avoirLppTotal;
    }
    if (profile.prevoyance.nombre3a > 0) {
      answers['q_nombre_3a'] = profile.prevoyance.nombre3a;
    }
    if (profile.prevoyance.totalEpargne3a > 0) {
      answers['q_total_3a'] = profile.prevoyance.totalEpargne3a;
    }
    // Patrimoine
    answers['q_epargne_liquide'] = profile.patrimoine.epargneLiquide;
    answers['q_investissements'] = profile.patrimoine.investissements;
    // Housing
    _persistHousingFieldsSync(answers, profile);
    // Target retirement
    if (profile.targetRetirementAge != null) {
      answers['q_target_retirement_age'] = profile.targetRetirementAge;
    }
    // FIX-P0-2: Persist conjoint (spouse) data — was previously lost on restart.
    // fromWizardAnswers() reads these keys to rebuild ConjointProfile.
    if (profile.conjoint != null) {
      final c = profile.conjoint!;
      if (c.salaireBrutMensuel != null) {
        // Store as net (reverse the brut→net from fromWizardAnswers)
        const socialChargesRate = 0.133; // AVS+AI+APG+AC standard rate
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
      replacementRatio: 0.0, // Computed by projection services, not available here
      monthsLiquidity: 0.0, // Requires budget data not in CoachProfile
      taxSavingPotential: 0.0, // Requires tax simulation
      confidenceScore: 0.0, // Requires projection
    );
  }

  void _persistHousingFieldsSync(Map<String, dynamic> answers, CoachProfile profile) {
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
  Future<void> updateContributions(List<PlannedMonthlyContribution> contributions) async {
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

    // Persister aussi createdAt si c'est le premier refresh (preserve l'original)
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

  /// Met a jour le profil depuis l'extraction d'un certificat LPP.
  ///
  /// Mappe chaque [ExtractedField.profileField] vers les champs
  /// PrevoyanceProfile correspondants. Persiste les nouvelles valeurs
  /// dans les answers wizard pour coherence au redemarrage.
  ///
  /// Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1, Document A
  /// FIX-095: Previous prevoyance backup for undo capability.
  PrevoyanceProfile? _previousPrevoyance;

  /// FIX-095: Get the previous prevoyance state (before last extraction).
  PrevoyanceProfile? get previousPrevoyance => _previousPrevoyance;

  /// FIX-094: Check if new LPP data diverges significantly from existing.
  /// Returns the delta percentage if > 30%, null otherwise.
  double? checkLppDivergence(List<ExtractedField> fields) {
    if (_profile == null) return null;
    final currentAvoir = _profile!.prevoyance.avoirLppTotal;
    if (currentAvoir == null || currentAvoir <= 0) return null;
    final newAvoir = fields
        .where((f) => f.fieldName == 'avoirLppTotal' || f.fieldName == 'avoir_lpp_total')
        .firstOrNull?.value;
    if (newAvoir == null) return null;
    final newVal = newAvoir is num ? newAvoir.toDouble() : double.tryParse(newAvoir.toString()) ?? 0;
    if (newVal <= 0) return null;
    final deltaPct = ((newVal - currentAvoir) / currentAvoir * 100).abs();
    return deltaPct > 30 ? deltaPct : null;
  }

  Future<void> updateFromLppExtraction(List<ExtractedField> fields) async {
    if (_profile == null) return;

    final p = _profile!;
    // FIX-095: Save previous state for undo capability.
    _previousPrevoyance = p.prevoyance;

    // Extract values from confirmed fields
    double? avoirTotal;
    double? avoirOblig;
    double? avoirSuroblig;
    double? tauxConvOblig;
    double? tauxConvSuroblig;
    double? lacuneRachat;
    double? salaireAssure;
    double? rendementCaisseVal;
    double? projectedRente;
    double? projectedCapital;
    double? disabilityCov;
    double? deathCov;

    for (final field in fields) {
      if (field.profileField == null) continue;
      final value = field.value;
      if (value is! double) continue;

      switch (field.profileField) {
        case 'avoirLppTotal':
          avoirTotal = value;
        case 'lppObligatoire':
          avoirOblig = value;
        case 'lppSurobligatoire':
          avoirSuroblig = value;
        case 'tauxConversionOblig':
          tauxConvOblig = value / 100; // Stored as 6.8 → 0.068
        case 'tauxConversionSuroblig':
          tauxConvSuroblig = value / 100;
        case 'buybackPotential':
          lacuneRachat = value;
        case 'lppInsuredSalary':
          salaireAssure = value;
        case 'rendementCaisse':
          rendementCaisseVal = value / 100; // Stored as 2.0 → 0.02
        case 'projectedRenteLpp':
          projectedRente = value;
        case 'projectedCapital65':
          projectedCapital = value;
        case 'disabilityCoverage':
          disabilityCov = value;
        case 'deathCoverage':
          deathCov = value;
      }
    }

    // Build updated prevoyance with real certificate data
    final updatedPrevoyance = PrevoyanceProfile(
      anneesContribuees: p.prevoyance.anneesContribuees,
      lacunesAVS: p.prevoyance.lacunesAVS,
      renteAVSEstimeeMensuelle: p.prevoyance.renteAVSEstimeeMensuelle,
      nomCaisse: p.prevoyance.nomCaisse,
      avoirLppTotal: avoirTotal ?? p.prevoyance.avoirLppTotal,
      avoirLppObligatoire: avoirOblig ?? p.prevoyance.avoirLppObligatoire,
      avoirLppSurobligatoire:
          avoirSuroblig ?? p.prevoyance.avoirLppSurobligatoire,
      rachatMaximum: lacuneRachat ?? p.prevoyance.rachatMaximum,
      rachatEffectue: p.prevoyance.rachatEffectue,
      tauxConversion: tauxConvOblig ?? p.prevoyance.tauxConversion,
      tauxConversionSuroblig:
          tauxConvSuroblig ?? p.prevoyance.tauxConversionSuroblig,
      rendementCaisse: rendementCaisseVal ?? p.prevoyance.rendementCaisse,
      salaireAssure: salaireAssure ?? p.prevoyance.salaireAssure,
      ramd: p.prevoyance.ramd,
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
      librePassage: p.prevoyance.librePassage,
      bonificationsEducatives: p.prevoyance.bonificationsEducatives,
      projectedRenteLpp: projectedRente ?? p.prevoyance.projectedRenteLpp,
      projectedCapital65: projectedCapital ?? p.prevoyance.projectedCapital65,
      disabilityCoverage: disabilityCov ?? p.prevoyance.disabilityCoverage,
      deathCoverage: deathCov ?? p.prevoyance.deathCoverage,
    );

    // Tag data sources as certificate-confirmed
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (avoirTotal != null) {
      updatedSources['prevoyance.avoirLppTotal'] =
          ProfileDataSource.certificate;
    }
    if (avoirOblig != null) {
      updatedSources['prevoyance.avoirLppObligatoire'] =
          ProfileDataSource.certificate;
    }
    if (avoirSuroblig != null) {
      updatedSources['prevoyance.avoirLppSurobligatoire'] =
          ProfileDataSource.certificate;
    }
    if (tauxConvOblig != null) {
      updatedSources['prevoyance.tauxConversion'] =
          ProfileDataSource.certificate;
    }
    if (tauxConvSuroblig != null) {
      updatedSources['prevoyance.tauxConversionSuroblig'] =
          ProfileDataSource.certificate;
    }
    if (lacuneRachat != null) {
      updatedSources['prevoyance.rachatMaximum'] =
          ProfileDataSource.certificate;
    }
    if (salaireAssure != null) {
      updatedSources['prevoyance.salaireAssure'] =
          ProfileDataSource.certificate;
    }
    if (rendementCaisseVal != null) {
      updatedSources['prevoyance.rendementCaisse'] =
          ProfileDataSource.certificate;
    }

    // S47: Stamp timestamps for all fields touched by this extraction
    final touchedFields = <String>[];
    if (avoirTotal != null) touchedFields.add('prevoyance.avoirLppTotal');
    if (avoirOblig != null) touchedFields.add('prevoyance.avoirLppObligatoire');
    if (avoirSuroblig != null) touchedFields.add('prevoyance.avoirLppSurobligatoire');
    if (tauxConvOblig != null) touchedFields.add('prevoyance.tauxConversion');
    if (tauxConvSuroblig != null) touchedFields.add('prevoyance.tauxConversionSuroblig');
    if (lacuneRachat != null) touchedFields.add('prevoyance.rachatMaximum');
    if (salaireAssure != null) touchedFields.add('prevoyance.salaireAssure');
    if (rendementCaisseVal != null) touchedFields.add('prevoyance.rendementCaisse');
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers for consistency across restarts
    final answers = await ReportPersistenceService.loadAnswers();
    if (avoirTotal != null) answers['_coach_avoir_lpp'] = avoirTotal;
    if (avoirOblig != null) answers['_coach_avoir_lpp_oblig'] = avoirOblig;
    if (avoirSuroblig != null) {
      answers['_coach_avoir_lpp_suroblig'] = avoirSuroblig;
    }
    if (tauxConvOblig != null) {
      answers['_coach_taux_conversion'] = tauxConvOblig;
    }
    if (tauxConvSuroblig != null) {
      answers['_coach_taux_conversion_suroblig'] = tauxConvSuroblig;
    }
    if (lacuneRachat != null) answers['_coach_rachat_maximum'] = lacuneRachat;
    if (salaireAssure != null) answers['_coach_salaire_assure'] = salaireAssure;
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
    answers['_coach_lpp_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;

    // W15: Auto-trigger snapshot after LPP certificate scan
    _createSnapshotFromProfile('document_scan');

    notifyListeners();
    _syncToBackend(); // Fire-and-forget, does not block UI
  }

  /// Inject PARTNER LPP certificate extraction into CoachProfile.conjoint.
  ///
  /// Identical field extraction to updateFromLppExtraction, but stores
  /// in profile.conjoint.prevoyance instead of profile.prevoyance.
  /// Ensures couple certificates are never mixed.
  Future<void> updateFromPartnerLppExtraction(
    List<ExtractedField> fields,
  ) async {
    if (_profile == null) return;
    final p = _profile!;
    if (p.conjoint == null) return; // No partner configured

    double? avoirTotal;
    double? avoirOblig;
    double? avoirSuroblig;
    double? tauxConvOblig;
    double? tauxConvSuroblig;
    double? lacuneRachat;
    double? salaireAssure;
    double? rendementCaisseVal;

    for (final field in fields) {
      if (field.profileField == null) continue;
      final value = field.value;
      if (value is! double) continue;
      switch (field.profileField) {
        case 'avoirLppTotal':
          avoirTotal = value;
        case 'lppObligatoire':
          avoirOblig = value;
        case 'lppSurobligatoire':
          avoirSuroblig = value;
        case 'tauxConversionOblig':
          tauxConvOblig = value / 100;
        case 'tauxConversionSuroblig':
          tauxConvSuroblig = value / 100;
        case 'buybackPotential':
          lacuneRachat = value;
        case 'lppInsuredSalary':
          salaireAssure = value;
        case 'rendementCaisse':
          rendementCaisseVal = value / 100;
      }
    }

    final existing = p.conjoint!.prevoyance ?? const PrevoyanceProfile();
    final updatedPrev = PrevoyanceProfile(
      anneesContribuees: existing.anneesContribuees,
      lacunesAVS: existing.lacunesAVS,
      renteAVSEstimeeMensuelle: existing.renteAVSEstimeeMensuelle,
      avoirLppTotal: avoirTotal ?? existing.avoirLppTotal,
      avoirLppObligatoire: avoirOblig ?? existing.avoirLppObligatoire,
      avoirLppSurobligatoire: avoirSuroblig ?? existing.avoirLppSurobligatoire,
      rachatMaximum: lacuneRachat ?? existing.rachatMaximum,
      tauxConversion: tauxConvOblig ?? existing.tauxConversion,
      tauxConversionSuroblig: tauxConvSuroblig ?? existing.tauxConversionSuroblig,
      rendementCaisse: rendementCaisseVal ?? existing.rendementCaisse,
      salaireAssure: salaireAssure ?? existing.salaireAssure,
      ramd: existing.ramd,
      nombre3a: existing.nombre3a,
      totalEpargne3a: existing.totalEpargne3a,
      comptes3a: existing.comptes3a,
      canContribute3a: existing.canContribute3a,
      librePassage: existing.librePassage,
    );

    final updatedConjoint = p.conjoint!.copyWith(prevoyance: updatedPrev);

    // Tag data sources
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (avoirTotal != null) {
      updatedSources['conjoint.prevoyance.avoirLppTotal'] =
          ProfileDataSource.certificate;
    }
    if (tauxConvOblig != null) {
      updatedSources['conjoint.prevoyance.tauxConversion'] =
          ProfileDataSource.certificate;
    }

    // Stamp timestamps
    final touchedFields = <String>[];
    if (avoirTotal != null) touchedFields.add('conjoint.prevoyance.avoirLppTotal');
    if (tauxConvOblig != null) touchedFields.add('conjoint.prevoyance.tauxConversion');
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    _profile = p.copyWith(
      conjoint: updatedConjoint,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    // Persist partner LPP data
    final answers = await ReportPersistenceService.loadAnswers();
    if (avoirTotal != null) answers['_coach_conjoint_avoir_lpp'] = avoirTotal;
    if (tauxConvOblig != null) {
      answers['_coach_conjoint_taux_conversion'] = tauxConvOblig;
    }
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
    answers['_coach_conjoint_lpp_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Met a jour le profil depuis l'extraction d'un extrait AVS.
  ///
  /// Mappe les champs AVS extraits vers PrevoyanceProfile.
  /// Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1, Document C
  Future<void> updateFromAvsExtraction(List<ExtractedField> fields) async {
    if (_profile == null) return;

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
    if (anneesContrib != null) touchedFields.add('prevoyance.anneesContribuees');
    if (lacunesCotisation != null) touchedFields.add('prevoyance.lacunesAVS');
    if (renteEstimee != null) touchedFields.add('prevoyance.renteAVSEstimeeMensuelle');
    if (ramd != null) touchedFields.add('prevoyance.ramd');
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
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
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
    answers['_coach_avs_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Met a jour le profil depuis l'extraction d'une declaration fiscale.
  ///
  /// Mappe les 6 champs fiscaux extraits vers les wizard answers
  /// et tag les dataSources comme certificate-confirmed.
  /// Le taux marginal effectif est le champ le plus critique (drive
  /// tous les arbitrages: 3a, rachat LPP, rente vs capital).
  ///
  /// Reference: LIFD art. 33-33a (deductions), LIFD art. 38 (capital)
  Future<void> updateFromTaxExtraction(List<ExtractedField> fields) async {
    if (_profile == null) return;

    final p = _profile!;

    // Extract values from confirmed fields
    double? revenuImposable;
    double? fortuneImposable;
    double? deductions;
    double? impotCantonal;
    double? impotFederal;
    double? tauxMarginal;

    for (final field in fields) {
      if (field.profileField == null) continue;
      final value = field.value;
      if (value is! double) continue;

      switch (field.profileField) {
        case 'actualTaxableIncome':
          revenuImposable = value;
        case 'actualTaxableWealth':
          fortuneImposable = value;
        case 'actualDeductions':
          deductions = value;
        case 'actualCantonalTax':
          impotCantonal = value;
        case 'actualFederalTax':
          impotFederal = value;
        case 'actualMarginalRate':
          tauxMarginal = value;
      }
    }

    // Tag data sources as certificate-confirmed
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (revenuImposable != null) {
      updatedSources['fiscal.revenuImposable'] = ProfileDataSource.certificate;
    }
    if (fortuneImposable != null) {
      updatedSources['fiscal.fortuneImposable'] = ProfileDataSource.certificate;
    }
    if (tauxMarginal != null) {
      updatedSources['fiscal.tauxMarginal'] = ProfileDataSource.certificate;
    }
    if (impotCantonal != null || impotFederal != null) {
      updatedSources['fiscal.impots'] = ProfileDataSource.certificate;
    }

    // S47: Stamp timestamps for all fields touched by this extraction
    final touchedFields = <String>[];
    if (revenuImposable != null) touchedFields.add('fiscal.revenuImposable');
    if (fortuneImposable != null) touchedFields.add('fiscal.fortuneImposable');
    if (tauxMarginal != null) touchedFields.add('fiscal.tauxMarginal');
    if (impotCantonal != null || impotFederal != null) touchedFields.add('fiscal.impots');
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    _profile = p.copyWith(
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers for availability across restarts
    final answers = await ReportPersistenceService.loadAnswers();
    if (revenuImposable != null) {
      answers['_coach_tax_revenu_imposable'] = revenuImposable;
    }
    if (fortuneImposable != null) {
      answers['_coach_tax_fortune_imposable'] = fortuneImposable;
    }
    if (deductions != null) {
      answers['_coach_tax_deductions'] = deductions;
    }
    if (impotCantonal != null) {
      answers['_coach_tax_impot_cantonal'] = impotCantonal;
    }
    if (impotFederal != null) {
      answers['_coach_tax_impot_federal'] = impotFederal;
    }
    if (tauxMarginal != null) {
      answers['_coach_tax_taux_marginal'] = tauxMarginal;
    }
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
    answers['_coach_tax_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
    notifyListeners();
  }

  /// Inject salary certificate extraction into CoachProfile.
  ///
  /// Stores: salaireBrutMensuel, nombreDeMois, bonusPourcentage.
  /// Tags dataSources as certificate. Stamps timestamps.
  Future<void> updateFromSalaryExtraction(List<ExtractedField> fields) async {
    if (_profile == null) return;

    final p = _profile!;
    double? salaireBrut;
    int? nombreMois;
    double? bonus;
    double? tauxActivite; // ignore: unused_local_variable — extracted for future use

    for (final field in fields) {
      if (field.profileField == null) continue;
      switch (field.profileField) {
        case 'salaireBrutMensuel':
          if (field.value is num) salaireBrut = (field.value as num).toDouble();
        case 'nombreMois' || 'nombreDeMois':
          if (field.value is num) nombreMois = (field.value as num).toInt();
        case 'bonus' || 'bonusPourcentage':
          if (field.value is num) bonus = (field.value as num).toDouble();
        case 'tauxActivite':
          if (field.value is num) tauxActivite = (field.value as num).toDouble();
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
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    _profile = p.copyWith(
      salaireBrutMensuel: salaireBrut ?? p.salaireBrutMensuel,
      nombreDeMois: (nombreMois ?? p.nombreDeMois).toDouble(),
      bonusPourcentage: bonus ?? p.bonusPourcentage,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    // Persist
    final answers = await ReportPersistenceService.loadAnswers();
    if (salaireBrut != null) {
      answers['q_monthly_gross_salary_chf'] = salaireBrut;
    }
    if (nombreMois != null) {
      answers['q_salary_months'] = nombreMois;
    }
    if (bonus != null) {
      answers['q_bonus_percentage'] = bonus;
    }
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
    answers['_coach_salary_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
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
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

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

    _profile = p.copyWith(
      salaireBrutMensuel: salaireBrutMensuel,
      prevoyance: updatedPrev,
      patrimoine: updatedPat,
      depenses: updatedDep,
      dettes: updatedDet,
      plannedContributions: updatedContribs,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    // Immediate UI update BEFORE async persistence (Bug 1 fix)
    _profileUpdatedSinceBudget = true;
    notifyListeners();

    // Persist to wizard answers (non-blocking, with error handling)
    try {
      final answers = await ReportPersistenceService.loadAnswers();
      if (salaireBrutMensuel != null) {
        final breakdown = NetIncomeBreakdown.compute(
          grossSalary: salaireBrutMensuel * 12,
          canton: _profile?.canton ?? 'ZH',
          age: _profile?.age ?? 45,
        );
        answers['q_net_income_period_chf'] = breakdown.monthlyNetPayslip;
      }
      if (avoirLppTotal != null) answers['_coach_avoir_lpp'] = avoirLppTotal;
      if (rendementCaisse != null) {
        answers['_coach_rendement_caisse'] = rendementCaisse;
      }
      if (totalEpargne3a != null) answers['_coach_total_3a'] = totalEpargne3a;
      if (rachatLppMensuel != null) {
        answers['_coach_rachat_lpp_mensuel'] = rachatLppMensuel;
      }
      if (epargneLiquide != null) answers['q_cash_total'] = epargneLiquide;
      // Write to the same keys fromWizardAnswers() reads so values survive restart.
      if (investissements != null) {
        answers['q_investments_total'] = investissements;
      }
      // Persist depenses — use canonical wizard keys where they exist
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
      // Persist dettes
      if (hypotheque != null) {
        answers['_coach_dettes_hypotheque'] = hypotheque;
      }
      if (creditConsommation != null) {
        answers['_coach_dettes_credit'] = creditConsommation;
      }
      if (leasing != null) answers['_coach_dettes_leasing'] = leasing;
      if (autresDettes != null) {
        answers['_coach_dettes_autres'] = autresDettes;
      }
      answers['_coach_updated_at'] = DateTime.now().toIso8601String();
      if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
      await ReportPersistenceService.saveAnswers(answers);
    } catch (e) {
      debugPrint('[CoachProfileProvider] persistence error: $e');
    }
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

    for (final acct in accounts) {
      final balance = (acct['balance'] as num?)?.toDouble() ?? 0;
      final type = acct['accountType'] as String? ?? '';
      switch (type) {
        case 'checking':
        case 'savings':
          epargneLiquide += balance;
        case '3a':
          epargne3a += balance;
        case 'securities':
          investissements += balance;
      }
    }

    // ── 2. Extract monthly expenses from categories ──────────
    final loyer = _safeExpense(categoryTotals['logement'], p.salaireBrutMensuel, 0.50);
    final assurance = _safeExpense(categoryTotals['assurances'], p.salaireBrutMensuel, 0.12);
    final electricite = _safeExpense(categoryTotals['energie'], p.salaireBrutMensuel, 0.05);
    final transport = _safeExpense(categoryTotals['transport'], p.salaireBrutMensuel, 0.10);
    final telecom = _safeExpense(categoryTotals['telecom'], p.salaireBrutMensuel, 0.05);
    final fraisMedicaux = _safeExpense(categoryTotals['sante'], p.salaireBrutMensuel, 0.10);
    final hypotheque = _safeExpense(categoryTotals['hypotheque'], p.salaireBrutMensuel, 0.50);

    // ── 3. Build updated sub-profiles ────────────────────────
    final updatedPat = p.patrimoine.copyWith(
      epargneLiquide: epargneLiquide > 0 ? epargneLiquide : null,
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

    final updatedDet = hypotheque != null
        ? p.dettes.copyWith(hypotheque: hypotheque)
        : null;

    // ── 4. Tag all updated fields as openBanking ─────────────
    if (epargneLiquide > 0) {
      updatedSources['patrimoine.epargneLiquide'] = ProfileDataSource.openBanking;
    }
    if (investissements > 0) {
      updatedSources['patrimoine.investissements'] = ProfileDataSource.openBanking;
    }
    if (epargne3a > 0) {
      updatedSources['prevoyance.totalEpargne3a'] = ProfileDataSource.openBanking;
    }
    if (loyer != null) updatedSources['depenses.loyer'] = ProfileDataSource.openBanking;
    if (assurance != null) {
      updatedSources['depenses.assuranceMaladie'] = ProfileDataSource.openBanking;
    }
    if (electricite != null) {
      updatedSources['depenses.electricite'] = ProfileDataSource.openBanking;
    }
    if (transport != null) updatedSources['depenses.transport'] = ProfileDataSource.openBanking;
    if (telecom != null) updatedSources['depenses.telecom'] = ProfileDataSource.openBanking;
    if (fraisMedicaux != null) {
      updatedSources['depenses.fraisMedicaux'] = ProfileDataSource.openBanking;
    }
    if (hypotheque != null) updatedSources['dettes.hypotheque'] = ProfileDataSource.openBanking;

    // S47: Stamp timestamps for all fields touched by open banking sync
    final touchedFields = <String>[
      if (epargneLiquide > 0) 'patrimoine.epargneLiquide',
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
    final updatedTimestamps = _stampTimestamps(p.dataTimestamps, touchedFields);

    // ── 5. Apply update ──────────────────────────────────────
    _profile = p.copyWith(
      prevoyance: updatedPrev,
      patrimoine: updatedPat,
      depenses: updatedDep,
      dettes: updatedDet,
      dataSources: updatedSources,
      dataTimestamps: updatedTimestamps,
      updatedAt: DateTime.now(),
    );

    _profileUpdatedSinceBudget = true;
    notifyListeners();

    // Persist asynchronously
    try {
      final answers = await ReportPersistenceService.loadAnswers();
      if (epargneLiquide > 0) answers['q_cash_total'] = epargneLiquide;
      if (investissements > 0) answers['_coach_investissements'] = investissements;
      if (epargne3a > 0) answers['_coach_total_3a'] = epargne3a;
      if (loyer != null) answers['_coach_depenses_loyer'] = loyer;
      if (assurance != null) answers['_coach_depenses_assurance'] = assurance;
      if (electricite != null) answers['_coach_depenses_electricite'] = electricite;
      if (transport != null) answers['_coach_depenses_transport'] = transport;
      if (telecom != null) answers['_coach_depenses_telecom'] = telecom;
      if (fraisMedicaux != null) {
        answers['_coach_depenses_frais_medicaux'] = fraisMedicaux;
      }
      if (hypotheque != null) answers['_coach_dettes_hypotheque'] = hypotheque;
      answers['_coach_updated_at'] = DateTime.now().toIso8601String();
      if (_profile != null) _persistTimestamps(answers, _profile!.dataTimestamps);
      answers['_coach_blink_source'] = 'open_banking';
      await ReportPersistenceService.saveAnswers(answers);
    } catch (e) {
      debugPrint('[CoachProfileProvider] bLink persistence error: $e');
    }
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

