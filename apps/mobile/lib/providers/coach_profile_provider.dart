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

  /// Le profil Coach construit a partir des reponses wizard.
  /// Null si le wizard n'a pas ete complete.
  CoachProfile? get profile => _profile;

  /// True pendant le chargement initial.
  bool get isLoading => _isLoading;

  /// True si le chargement a ete effectue au moins une fois.
  bool get isLoaded => _isLoaded;

  /// True si un profil est disponible (wizard complete).
  bool get hasProfile => _profile != null;

  /// Charge le profil depuis les reponses wizard stockees.
  ///
  /// Appele automatiquement au demarrage de l'app et apres
  /// la completion du wizard.
  Future<void> loadFromWizard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isCompleted = await ReportPersistenceService.isCompleted();
      if (!isCompleted) {
        _profile = null;
        _isLoading = false;
        _isLoaded = true;
        notifyListeners();
        return;
      }

      final answers = await ReportPersistenceService.loadAnswers();
      if (answers.isEmpty) {
        _profile = null;
        _isLoading = false;
        _isLoaded = true;
        notifyListeners();
        return;
      }

      _profile = CoachProfile.fromWizardAnswers(answers);
    } catch (e) {
      debugPrint('Erreur chargement CoachProfile: $e');
      _profile = null;
    }

    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  /// Met a jour le profil directement a partir d'un map d'answers.
  /// Utilise apres la completion du wizard pour eviter un rechargement async.
  void updateFromAnswers(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    _profile = CoachProfile.fromWizardAnswers(answers);
    _isLoaded = true;
    notifyListeners();
  }

  /// Reset le profil (logout / reset).
  void clear() {
    _profile = null;
    _isLoaded = false;
    notifyListeners();
  }
}
