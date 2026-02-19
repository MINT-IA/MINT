import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
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
  /// Mini-onboarding = ~0.15, wizard complet = ~0.60, wizard + documents = 1.0.
  double get profileCompleteness {
    if (_profile == null) return 0.0;
    if (_isPartialProfile) return 0.15;
    // Full wizard = 0.60 base (documents ajouteraient le reste)
    return 0.60;
  }

  /// Nombre de donnees renseignees (pour le badge precision).
  int get dataPointsCount {
    if (_profile == null) return 0;
    if (_isPartialProfile) return 4; // birthYear, canton, revenu, statut
    return 25; // wizard complet
  }

  /// Dernier score enregistre (pour le calcul de tendance).
  int? get previousScore => _previousScore;

  /// Historique des scores mensuels (max 24 mois).
  List<Map<String, dynamic>> get scoreHistory => _scoreHistory;

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

      if (isFullCompleted && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers);
        _isPartialProfile = false;
        await _mergePersistedData();
        _isLoading = false;
        _isLoaded = true;
        notifyListeners();
        return;
      }

      // Check mini-onboarding
      final isMiniCompleted = await ReportPersistenceService.isMiniOnboardingCompleted();
      if (isMiniCompleted && answers.isNotEmpty) {
        _profile = CoachProfile.fromWizardAnswers(answers);
        _isPartialProfile = true;
        await _mergePersistedData();
        _isLoading = false;
        _isLoaded = true;
        notifyListeners();
        return;
      }

      // No profile at all
      _profile = null;
      _isPartialProfile = false;
    } catch (e) {
      debugPrint('Erreur chargement CoachProfile: $e');
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
      final checkIns = persistedCheckIns
          .map((ci) => MonthlyCheckIn.fromJson(ci))
          .toList();
      _profile = _profile!.copyWithCheckIns(checkIns);
    }

    // Merge contributions (si l'utilisateur les a modifies via check-in)
    final persistedContribs = await ReportPersistenceService.loadContributions();
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
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = false;
    _isLoaded = true;
    notifyListeners();
  }

  /// Met a jour le profil depuis le mini-onboarding (3-4 questions).
  /// Cree un profil partiel immediatement utilisable par le dashboard.
  void updateFromMiniOnboarding(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isPartialProfile = true;
    _isLoaded = true;
    notifyListeners();
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
    final updated = List<PlannedMonthlyContribution>.from(_profile!.plannedContributions);
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

  /// Reset le profil (logout / reset).
  void clear() {
    _profile = null;
    _isPartialProfile = false;
    _isLoaded = false;
    _previousScore = null;
    _scoreHistory = [];
    notifyListeners();
  }
}
