import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
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
  /// Plancher: partial=0.10, full=0.60.
  double get profileCompleteness {
    if (_profile == null) return 0.0;
    final total = onboardingTotalSignals;
    if (total == 0) return _isPartialProfile ? 0.10 : 0.60;
    final raw = onboardingAnsweredSignals / total;
    if (_isPartialProfile) return raw.clamp(0.10, 0.55);
    return raw.clamp(0.60, 1.0);
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

  /// Dynamic onboarding quality score, independent from legacy precision badge.
  /// Preserves floor by profile mode:
  /// - mini profile: 15%..55%
  /// - full profile: 60%..95%
  double get onboardingQualityScore {
    if (_profile == null) return 0.0;
    final total = onboardingTotalSignals;
    if (total == 0) return _isPartialProfile ? 0.15 : 0.60;
    final raw = onboardingAnsweredSignals / total;
    if (_isPartialProfile) return raw.clamp(0.15, 0.55);
    return raw.clamp(0.60, 0.95);
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
  }) {
    // Convert gross annual → net monthly
    // Net monthly = (grossSalary / 12) × (1 - 0.13) (charges sociales ~13%)
    // fromWizardAnswers() reconvertit net → brut via / (1 - 0.13),
    // ce qui préserve le salaire brut original.
    const double socialChargesRate = 0.13;
    final netMonthly = (grossSalary / 12) * (1 - socialChargesRate);
    final birthYear = DateTime.now().year - age;

    final answers = <String, dynamic>{
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': netMonthly,
      'q_employment_status': 'employed',
    };

    _lastAnswers = answers;
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = true;
    _isLoaded = true;
    _profileUpdatedSinceBudget = true;
    notifyListeners();

    // Persist asynchronously so the dashboard can reload from storage
    ReportPersistenceService.saveAnswers(answers);
    ReportPersistenceService.setMiniOnboardingCompleted(true);
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
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: totalEpargne3a ?? p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
    );

    _profile = CoachProfile(
      firstName: p.firstName,
      birthYear: p.birthYear,
      canton: p.canton,
      commune: p.commune,
      etatCivil: p.etatCivil,
      nombreEnfants: p.nombreEnfants,
      conjoint: p.conjoint,
      salaireBrutMensuel: salaireBrutMensuel ?? p.salaireBrutMensuel,
      nombreDeMois: p.nombreDeMois,
      bonusPourcentage: p.bonusPourcentage,
      employmentStatus: employmentStatus ?? p.employmentStatus,
      depenses: p.depenses,
      prevoyance: updatedPrevoyance,
      patrimoine: p.patrimoine,
      dettes: p.dettes,
      goalA: p.goalA,
      goalsB: p.goalsB,
      plannedContributions: p.plannedContributions,
      checkIns: p.checkIns,
      housingStatus: p.housingStatus,
      riskTolerance: riskTolerance ?? p.riskTolerance,
      realEstateProject: realEstateProject ?? p.realEstateProject,
      providers3a: p.providers3a,
      createdAt: p.createdAt,
      updatedAt: DateTime.now(),
    );

    // Persist updated wizard answers with refreshed fields
    final answers = await ReportPersistenceService.loadAnswers();
    if (salaireBrutMensuel != null) {
      // Convert back to net for wizard format (brut * 0.87)
      answers['q_net_income_period_chf'] = salaireBrutMensuel * 0.87;
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
      avoirLppSurobligatoire: avoirSuroblig ?? p.prevoyance.avoirLppSurobligatoire,
      rachatMaximum: lacuneRachat ?? p.prevoyance.rachatMaximum,
      rachatEffectue: p.prevoyance.rachatEffectue,
      tauxConversion: tauxConvOblig ?? p.prevoyance.tauxConversion,
      tauxConversionSuroblig: tauxConvSuroblig ?? p.prevoyance.tauxConversionSuroblig,
      rendementCaisse: p.prevoyance.rendementCaisse,
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
    );

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers for consistency across restarts
    final answers = await ReportPersistenceService.loadAnswers();
    if (avoirTotal != null) answers['_coach_avoir_lpp'] = avoirTotal;
    if (avoirOblig != null) answers['_coach_avoir_lpp_oblig'] = avoirOblig;
    if (avoirSuroblig != null) answers['_coach_avoir_lpp_suroblig'] = avoirSuroblig;
    if (tauxConvOblig != null) answers['_coach_taux_conversion'] = tauxConvOblig;
    if (tauxConvSuroblig != null) answers['_coach_taux_conversion_suroblig'] = tauxConvSuroblig;
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
          if (value is double) anneesContrib = value.round();
          if (value is int) anneesContrib = value;
        case 'lacunesCotisation':
          if (value is double) lacunesCotisation = value.round();
          if (value is int) lacunesCotisation = value;
        case 'renteEstimee':
          if (value is double) renteEstimee = value;
        case 'ramd':
          if (value is double) ramd = value;
      }
    }

    // Build updated prevoyance with real AVS data
    final updatedPrevoyance = PrevoyanceProfile(
      anneesContribuees: anneesContrib ?? p.prevoyance.anneesContribuees,
      lacunesAVS: lacunesCotisation ?? p.prevoyance.lacunesAVS,
      renteAVSEstimeeMensuelle: renteEstimee ?? p.prevoyance.renteAVSEstimeeMensuelle,
      nomCaisse: p.prevoyance.nomCaisse,
      avoirLppTotal: p.prevoyance.avoirLppTotal,
      avoirLppObligatoire: p.prevoyance.avoirLppObligatoire,
      avoirLppSurobligatoire: p.prevoyance.avoirLppSurobligatoire,
      rachatMaximum: p.prevoyance.rachatMaximum,
      rachatEffectue: p.prevoyance.rachatEffectue,
      tauxConversion: p.prevoyance.tauxConversion,
      tauxConversionSuroblig: p.prevoyance.tauxConversionSuroblig,
      rendementCaisse: p.prevoyance.rendementCaisse,
      nombre3a: p.prevoyance.nombre3a,
      totalEpargne3a: p.prevoyance.totalEpargne3a,
      comptes3a: p.prevoyance.comptes3a,
      canContribute3a: p.prevoyance.canContribute3a,
    );

    _profile = p.copyWith(
      prevoyance: updatedPrevoyance,
      updatedAt: DateTime.now(),
    );

    // Persist to wizard answers
    final answers = await ReportPersistenceService.loadAnswers();
    if (anneesContrib != null) answers['q_avs_contribution_years'] = anneesContrib;
    if (lacunesCotisation != null) answers['_coach_avs_lacunes'] = lacunesCotisation;
    if (renteEstimee != null) answers['_coach_avs_rente_estimee'] = renteEstimee;
    if (ramd != null) answers['_coach_avs_ramd'] = ramd;
    answers['_coach_updated_at'] = DateTime.now().toIso8601String();
    answers['_coach_avs_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(answers);

    _profileUpdatedSinceBudget = true;
    notifyListeners();
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
