/// MVP Wedge onboarding state v2 — storyboard final locked 2026-04-22.
///
/// 9 tours linéaires après sélection d'un intent au tour 2. Chaque tour
/// capture une data qui peuple le dossier strip. Flush vers
/// CoachProfile au tour 9 (magic link envoyé).
///
/// Doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md`
/// Feedback règles : scenario-before-screen, retains-everything,
///                   net-monthly-not-gross-annual.
library;

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Une ligne visible du dossier, affichée dans la bande en bas d'écran.
@immutable
class DossierEntry {
  const DossierEntry({
    required this.key,
    required this.label,
    required this.value,
    required this.orderHint,
  });

  final String key;
  final String label;
  final String value;
  final int orderHint;
}

/// Les 9 tours du flow storyboard final.
enum OnboardingStep {
  entry,       // T1 — opener
  intents,     // T2 — 4 cartes d'intent
  age,         // T3
  canton,      // T4
  revenue,     // T5 — slider fourchette + lien exact
  insight,     // T6 — N1 inline contextuel à l'intent
  scene,       // T7 — scène N2 interactive
  bifurcation, // T8 — [Creuser] / [Plus tard]
  magicLink,   // T9 — email pour sceller le dossier
}

/// Niveau de confiance d'une donnée captée, aligné sur
/// EnhancedConfidence 4-axes de MINT (completeness × accuracy ×
/// freshness × understanding). Simplifié ici à 4 paliers.
enum OnboardingConfidence { low, medium, high, veryHigh }

class OnboardingProvider extends ChangeNotifier {
  OnboardingStep _step = OnboardingStep.entry;
  final Map<String, DossierEntry> _dossier = {};

  // Captures — source of truth for the mapper au tour 9.
  OnboardingIntent? _intent;
  int? _ageYears;
  String? _cantonCode;
  ({double low, double high})? _netMonthlyRange;
  double? _netMonthlyExact;
  String? _email;
  bool _wantsDeeper = false;

  final Map<String, OnboardingConfidence> _confidenceByField = {};

  // ── Read accessors ──────────────────────────────────────────────
  OnboardingStep get step => _step;
  OnboardingIntent? get intent => _intent;
  int? get ageYears => _ageYears;
  String? get cantonCode => _cantonCode;
  ({double low, double high})? get netMonthlyRange => _netMonthlyRange;
  double? get netMonthlyExact => _netMonthlyExact;
  String? get email => _email;
  bool get wantsDeeper => _wantsDeeper;
  Map<String, OnboardingConfidence> get confidenceByField =>
      Map.unmodifiable(_confidenceByField);

  bool get isCompleted => _step == OnboardingStep.magicLink && _email != null;

  List<DossierEntry> get dossier {
    final list = _dossier.values.toList()
      ..sort((a, b) => a.orderHint.compareTo(b.orderHint));
    return List.unmodifiable(list);
  }

  /// Revenu net mensuel effectif (soit l'exact s'il a été saisi, soit
  /// le milieu de la fourchette). Lecture unique pour les calculateurs.
  double? get netMonthlyEffective {
    if (_netMonthlyExact != null) return _netMonthlyExact;
    if (_netMonthlyRange != null) {
      return (_netMonthlyRange!.low + _netMonthlyRange!.high) / 2;
    }
    return null;
  }

  // ── Write actions ──────────────────────────────────────────────

  void _setDossier(String key, String label, String value, int orderHint) {
    _dossier[key] = DossierEntry(
      key: key,
      label: label,
      value: value,
      orderHint: orderHint,
    );
  }

  void setIntent(OnboardingIntent intent, String humanLabel) {
    _intent = intent;
    _confidenceByField['intent'] = OnboardingConfidence.high;
    _setDossier('intent', 'Intention', humanLabel, 0);
    notifyListeners();
  }

  void setAge(int years) {
    _ageYears = years;
    _confidenceByField['age'] = OnboardingConfidence.high;
    _setDossier('age', 'Âge', '$years ans', 1);
    notifyListeners();
  }

  void setCanton(String code, String humanName) {
    _cantonCode = code;
    _confidenceByField['canton'] = OnboardingConfidence.high;
    _setDossier('canton', 'Canton', humanName, 2);
    notifyListeners();
  }

  void setNetMonthlyRange(double low, double high) {
    _netMonthlyRange = (low: low, high: high);
    _netMonthlyExact = null;
    _confidenceByField['revenue'] = OnboardingConfidence.medium;
    _setDossier(
      'revenue',
      'Revenu net mensuel',
      '${_formatChf(low)} – ${_formatChf(high)} CHF',
      3,
    );
    notifyListeners();
  }

  void setNetMonthlyExact(double value) {
    _netMonthlyExact = value;
    _netMonthlyRange = null;
    _confidenceByField['revenue'] = OnboardingConfidence.high;
    _setDossier(
      'revenue',
      'Revenu net mensuel',
      '${_formatChf(value)} CHF',
      3,
    );
    notifyListeners();
  }

  void setWantsDeeper(bool value) {
    _wantsDeeper = value;
    notifyListeners();
  }

  void setEmail(String email) {
    _email = email;
    _confidenceByField['email'] = OnboardingConfidence.high;
    _setDossier('email', 'Email', email, 4);
    notifyListeners();
  }

  // ── Step navigation ─────────────────────────────────────────────

  void goToStep(OnboardingStep s) {
    _step = s;
    notifyListeners();
  }

  void advance() {
    const order = OnboardingStep.values;
    final idx = order.indexOf(_step);
    if (idx < order.length - 1) {
      _step = order[idx + 1];
      notifyListeners();
    }
  }

  // ── Flush to CoachProfile au tour 9 ─────────────────────────────

  /// Persiste la capture dans `wizard_answers_v2` + seed
  /// `CoachProfileProvider`. Appelé après la saisie de l'email au T9.
  ///
  /// Failure modes (both throw — caller MUST try/catch, never silent-swallow) :
  /// - `saveAnswers` → disk full, corrupted SharedPreferences, SecureWizardStore
  ///   KeyChain unavailable. Without this, the magic-link email is saved but
  ///   the answers are lost → user re-onboarded from zero on reopen.
  /// - `mergeAnswers` → same SharedPreferences bucket, plus CoachProfile
  ///   derivation errors. Backend sync is already fire-and-forget inside
  ///   `mergeAnswers` (see `_syncToBackend`), so a thrown exception here
  ///   means local seed failed — NOT a backend outage.
  Future<void> completeAndFlushToProfile(
    CoachProfileProvider coachProvider,
  ) async {
    final answers = <String, dynamic>{};
    if (_intent != null) answers['onb_intent'] = _intent!.name;
    if (_ageYears != null) answers['q_age'] = _ageYears;
    if (_cantonCode != null) answers['q_canton'] = _cantonCode;
    if (_netMonthlyExact != null) {
      answers['q_net_income_period_chf'] = _netMonthlyExact;
      answers['q_net_income_confidence'] = 'high';
    } else if (_netMonthlyRange != null) {
      // Persiste le milieu de la fourchette en valeur effective, et
      // archive la fourchette brute pour les upgrades de confidence.
      answers['q_net_income_period_chf'] = netMonthlyEffective;
      answers['q_net_income_range_low'] = _netMonthlyRange!.low;
      answers['q_net_income_range_high'] = _netMonthlyRange!.high;
      answers['q_net_income_confidence'] = 'medium';
    }
    if (_email != null) answers['q_email'] = _email;
    answers['q_wants_deeper'] = _wantsDeeper;

    await ReportPersistenceService.saveAnswers(answers);
    await coachProvider.mergeAnswers(answers);
  }

  /// Format CHF suisse avec apostrophe comme séparateur de milliers.
  /// Source of truth de formatage — le même que DossierStrip et
  /// chiffres héros des scènes N2.
  static String _formatChf(double value) {
    final whole = value.round();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
