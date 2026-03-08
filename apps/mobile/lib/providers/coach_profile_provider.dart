import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Provider pour le profil Coach MINT.
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
  int? _previousScore;
  List<Map<String, dynamic>> _scoreHistory = [];
  bool _profileUpdatedSinceBudget = false;
  Map<String, dynamic> _lastAnswers = const {};

  /// Le profil Coach construit a partir des reponses wizard.
  /// Null si le wizard n'a pas ete complete.
  CoachProfile? get profile => _profile;

  /// True pendant le chargement initial.
  bool get isLoading => _isLoading;

  /// True si le chargement a ete effectue au moins une fois.
  bool get isLoaded => _isLoaded;

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

  /// Met a jour le profil depuis le Smart Onboarding (3 questions: age, salaire, canton).
  ///
  /// Cree un profil partiel minimal immediatement utilisable par le dashboard.
  /// Convertit le salaire brut annuel en net mensuel via le taux de charges
  /// sociales standard (~13%: AVS 5.3% + LPP ~5% + AC ~1.1% + AANP ~1%).
  /// Source: OFAS barème cotisations 2025. Estimation; le taux réel dépend
  /// du plan LPP et du canton.
  ///
  /// Persiste de maniere asynchrone via [ReportPersistenceService].
  void updateFromSmartFlow({
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
  }) {
    // Convert gross annual → net monthly
    // Net monthly = (grossSalary / 12) × (1 - 0.13) (charges sociales ~13%)
    // fromWizardAnswers() reconvertit net → brut via / (1 - 0.13),
    // ce qui préserve le salaire brut original.
    const double socialChargesRate = 0.13;
    final netMonthly = (grossSalary / 12) * (1 - socialChargesRate);
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
      grossSalary: grossSalary,
      canton: canton,
    );

    // AVS contribution years (LAVS art. 29 — cotisations dès 21 ans).
    final int avsContributionYears;
    if (isReturningSwiss) {
      // Reduced by time abroad
      avsContributionYears = ((age - 20) - (yearsAbroad ?? 0)).clamp(0, 44);
    } else if (isExpat) {
      // Contributions start from max(arrivalAge, 21)
      final arrivalAge = arrivalYear - birthYear;
      final startAge = arrivalAge > 21 ? arrivalAge : 21;
      avsContributionYears = (age - startAge).clamp(0, 44);
    } else {
      // Swiss native: cotisations since age 21
      avsContributionYears = (age - 20).clamp(0, 44);
    }

    final answers = <String, dynamic>{
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': netMonthly,
      // Store gross annual directly to avoid net→gross roundtrip imprecision.
      'q_gross_salary_annual': grossSalary,
      // Use actual employment status — independant may not have LPP
      'q_employment_status': effectiveEmployment,
      // LPP access: salary > seuil AND salarié (LPP art. 7 — indépendants: opt.)
      'q_has_pension_fund':
          grossSalary >= 22680 && effectiveEmployment != 'independant',
      // AVS years estimated from age and situation (LAVS art. 29)
      'q_avs_contribution_years': avsContributionYears,
      // AVS rente estimated via financial_core AvsCalculator
      '_coach_avs_rente_estimee': minimal.avsMonthlyRente,
      // Patrimoine: estimated savings = (age-25) × salary × 5%
      'q_cash_total': minimal.currentSavings,
      // Nationality for archetype detection (see CLAUDE.md archetype table)
      if (nationality != null) 'q_nationality': nationality,
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
    _isPartialProfile = true;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();

    // Persist asynchronously so the dashboard can reload from storage
    ReportPersistenceService.saveAnswers(answers);
    ReportPersistenceService.setMiniOnboardingCompleted(true);
  }

  /// Replace the current profile with an updated one and persist via answers.
  void updateProfile(CoachProfile updated) {
    _profile = updated;
    _profileUpdatedSinceBudget = true;
    notifyListeners();
    // Persist housing fields into wizard answers for reload
    _persistHousingFields(updated);
  }

  Future<void> _persistHousingFields(CoachProfile profile) async {
    final answers = await ReportPersistenceService.loadAnswers();
    if (profile.housingStatus != null) {
      answers['q_housing_status'] = profile.housingStatus;
    } else {
      answers.remove('q_housing_status');
    }
    final p = profile.patrimoine;
    // Set or clear housing fields — avoids stale data when switching
    // between owner and renter.
    _setOrRemove(answers, 'q_property_market_value', p.propertyMarketValue);
    _setOrRemove(answers, 'q_mortgage_balance', p.mortgageBalance);
    _setOrRemove(answers, 'q_mortgage_rate', p.mortgageRate);
    _setOrRemove(answers, 'q_monthly_rent', p.monthlyRent);
    await ReportPersistenceService.saveAnswers(answers);
  }

  static void _setOrRemove(
    Map<String, dynamic> map,
    String key,
    dynamic value,
  ) {
    if (value != null) {
      map[key] = value;
    } else {
      map.remove(key);
    }
  }

  /// Ajoute un check-in mensuel au profil et le persiste.
  void addCheckIn(MonthlyCheckIn checkIn) {
    if (_profile == null) return;
    final updated = [..._profile!.checkIns, checkIn];
    _profile = _profile!.copyWithCheckIns(updated);
    // Persister les check-ins
    ReportPersistenceService.saveCheckIns(
      updated.map((ci) => ci.toJson()).toList(),
    );
    notifyListeners();
  }

  /// Met a jour les contributions dans le profil et les persiste.
  void updateContributions(List<PlannedMonthlyContribution> contributions) {
    if (_profile == null) return;
    _profile = _profile!.copyWithContributions(contributions);
    ReportPersistenceService.saveContributions(
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
  Future<void> updateFromLppExtraction(List<ExtractedField> fields) async {
    if (_profile == null) return;

    final p = _profile!;

    // Extract values from confirmed fields
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
          tauxConvOblig = value / 100; // Stored as 6.8 → 0.068
        case 'tauxConversionSuroblig':
          tauxConvSuroblig = value / 100;
        case 'buybackPotential':
          lacuneRachat = value;
        case 'lppInsuredSalary':
          salaireAssure = value;
        case 'rendementCaisse':
          rendementCaisseVal = value / 100; // Stored as 2.0 → 0.02
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
    );

    // Tag data sources as certificate-confirmed
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (avoirTotal != null)
      updatedSources['prevoyance.avoirLppTotal'] =
          ProfileDataSource.certificate;
    if (avoirOblig != null)
      updatedSources['prevoyance.avoirLppObligatoire'] =
          ProfileDataSource.certificate;
    if (avoirSuroblig != null)
      updatedSources['prevoyance.avoirLppSurobligatoire'] =
          ProfileDataSource.certificate;
    if (tauxConvOblig != null)
      updatedSources['prevoyance.tauxConversion'] =
          ProfileDataSource.certificate;
    if (tauxConvSuroblig != null)
      updatedSources['prevoyance.tauxConversionSuroblig'] =
          ProfileDataSource.certificate;
    if (lacuneRachat != null)
      updatedSources['prevoyance.rachatMaximum'] =
          ProfileDataSource.certificate;
    if (salaireAssure != null)
      updatedSources['prevoyance.salaireAssure'] =
          ProfileDataSource.certificate;
    if (rendementCaisseVal != null)
      updatedSources['prevoyance.rendementCaisse'] =
          ProfileDataSource.certificate;

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      dataSources: updatedSources,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers for consistency across restarts
    final answers = await ReportPersistenceService.loadAnswers();
    if (avoirTotal != null) answers['_coach_avoir_lpp'] = avoirTotal;
    if (avoirOblig != null) answers['_coach_avoir_lpp_oblig'] = avoirOblig;
    if (avoirSuroblig != null)
      answers['_coach_avoir_lpp_suroblig'] = avoirSuroblig;
    if (tauxConvOblig != null)
      answers['_coach_taux_conversion'] = tauxConvOblig;
    if (tauxConvSuroblig != null)
      answers['_coach_taux_conversion_suroblig'] = tauxConvSuroblig;
    if (lacuneRachat != null) answers['_coach_rachat_maximum'] = lacuneRachat;
    if (salaireAssure != null) answers['_coach_salaire_assure'] = salaireAssure;
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    answers['_coach_lpp_source'] = 'document_scan';
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
    );

    // Tag data sources as certificate-confirmed
    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);
    if (anneesContrib != null)
      updatedSources['prevoyance.anneesContribuees'] =
          ProfileDataSource.certificate;
    if (lacunesCotisation != null)
      updatedSources['prevoyance.lacunesAVS'] = ProfileDataSource.certificate;
    if (renteEstimee != null)
      updatedSources['prevoyance.renteAVSEstimeeMensuelle'] =
          ProfileDataSource.certificate;
    if (ramd != null)
      updatedSources['prevoyance.ramd'] = ProfileDataSource.certificate;

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      dataSources: updatedSources,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers
    final answers = await ReportPersistenceService.loadAnswers();
    if (anneesContrib != null)
      answers['q_avs_contribution_years'] = anneesContrib;
    if (lacunesCotisation != null)
      answers['_coach_avs_lacunes'] = lacunesCotisation;
    if (renteEstimee != null)
      answers['_coach_avs_rente_estimee'] = renteEstimee;
    if (ramd != null) answers['_coach_avs_ramd'] = ramd;
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
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

    _profile = p.copyWith(
      dataSources: updatedSources,
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
    answers['_coach_tax_source'] = 'document_scan';
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
  }) async {
    if (_profile == null) return;
    final p = _profile!;

    final updatedSources = Map<String, ProfileDataSource>.from(p.dataSources);

    PrevoyanceProfile? updatedPrev;
    if (avoirLppTotal != null || totalEpargne3a != null || nombre3a != null) {
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
        rendementCaisse: p.prevoyance.rendementCaisse,
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

    // ── 5. Apply update ──────────────────────────────────────
    _profile = p.copyWith(
      prevoyance: updatedPrev,
      patrimoine: updatedPat,
      depenses: updatedDep,
      dettes: updatedDet,
      dataSources: updatedSources,
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
  /// the Smart Onboarding flow. Keys match the onboarding field names.
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
  void clear() {
    _profile = null;
    _isPartialProfile = false;
    _isLoaded = false;
    _previousScore = null;
    _scoreHistory = [];
    _lastAnswers = const {};
    notifyListeners();
  }
}
