/// MVP Wedge onboarding state — doctrine « valeur continue »
/// (`.planning/mvp-wedge-onboarding-2026-04-21/ONBOARDING-DOCTRINE-V2.md`).
///
/// Un dossier qui se densifie ligne par ligne, pas un verdict forcé.
/// Le provider est l'unique source de vérité pendant le flow. À la fin
/// (écran 7 valide), il flush dans `CoachProfile` via le mapper.
library;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Une ligne visible du dossier, affichée dans la bande en bas d'écran.
///
/// `label` = intitulé courant (« Année de naissance »).
/// `value` = valeur humaine lisible déjà formatée (« 1992 »).
/// `orderHint` pilote l'ordre visuel stable (0..6) indépendant de l'ordre
/// d'ajout — utile si un pas est revenu en arrière et réécrit.
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

  DossierEntry copyWith({String? value}) => DossierEntry(
        key: key,
        label: label,
        value: value ?? this.value,
        orderHint: orderHint,
      );
}

/// Les 7 pas du flow. Entry n'a pas d'input (écran 1), les 6 suivants oui.
enum OnboardingStep {
  entry,
  birth,
  canton,
  proStatus,
  salary,
  pension,
  household,
}

/// Statut pro retenu par le flow. Mappé vers archetype dans
/// [OnboardingProvider.completeAndFlushToProfile].
enum ProStatus { salaried, selfEmployed, crossBorder, other }

class OnboardingProvider extends ChangeNotifier {
  OnboardingStep _step = OnboardingStep.entry;
  final Map<String, DossierEntry> _dossier = {};

  // Raw captured values (source of truth pour le mapper de sortie).
  int? _birthYear;
  String? _cantonCode; // 'VD', 'GE', 'ZH', ...
  ProStatus? _proStatus;
  double? _grossSalaryAnnual; // CHF
  double? _pensionBalance; // CHF, null si « plus tard »
  bool _pensionSkipped = false;
  bool? _inCouple;

  OnboardingStep get step => _step;
  List<DossierEntry> get dossier {
    final list = _dossier.values.toList()
      ..sort((a, b) => a.orderHint.compareTo(b.orderHint));
    return List.unmodifiable(list);
  }

  int? get birthYear => _birthYear;
  String? get cantonCode => _cantonCode;
  ProStatus? get proStatus => _proStatus;
  double? get grossSalaryAnnual => _grossSalaryAnnual;
  double? get pensionBalance => _pensionBalance;
  bool get pensionSkipped => _pensionSkipped;
  bool? get inCouple => _inCouple;

  bool get isCompleted => _step == OnboardingStep.household && _inCouple != null;

  void _setDossier(String key, String label, String value, int orderHint) {
    _dossier[key] = DossierEntry(
      key: key,
      label: label,
      value: value,
      orderHint: orderHint,
    );
  }

  void setBirthYear(int year) {
    _birthYear = year;
    _setDossier('birth', 'Année de naissance', year.toString(), 0);
    notifyListeners();
  }

  void setCanton(String code, String humanName) {
    _cantonCode = code;
    _setDossier('canton', 'Canton', humanName, 1);
    notifyListeners();
  }

  void setProStatus(ProStatus status, String humanLabel) {
    _proStatus = status;
    _setDossier('pro', 'Statut pro', humanLabel, 2);
    notifyListeners();
  }

  void setSalaryAnnual(double chf) {
    _grossSalaryAnnual = chf;
    _setDossier(
      'salary',
      'Salaire brut annuel',
      '${_formatChf(chf)} CHF',
      3,
    );
    notifyListeners();
  }

  void setPensionBalance(double chf) {
    _pensionBalance = chf;
    _pensionSkipped = false;
    _setDossier('pension', 'Caisse de pension', '${_formatChf(chf)} CHF', 4);
    notifyListeners();
  }

  void skipPension() {
    _pensionBalance = null;
    _pensionSkipped = true;
    _setDossier('pension', 'Caisse de pension', 'À compléter', 4);
    notifyListeners();
  }

  void setHousehold(bool couple, String humanLabel) {
    _inCouple = couple;
    _setDossier('household', 'Foyer', humanLabel, 5);
    notifyListeners();
  }

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

  /// Au pas 7 validé, persiste le dossier dans `wizard_answers_v2`
  /// et seed le `CoachProfileProvider` pour la suite de la session.
  ///
  /// Ne fait AUCUN calcul fiscal/LPP/AVS ici — juste captation.
  Future<void> completeAndFlushToProfile(
    CoachProfileProvider coachProvider,
  ) async {
    final answers = <String, dynamic>{};
    if (_birthYear != null) answers['q_birth_year'] = _birthYear;
    if (_cantonCode != null) answers['q_canton'] = _cantonCode;
    if (_proStatus != null) answers['q_pro_status'] = _proStatus!.name;
    if (_grossSalaryAnnual != null) {
      answers['q_gross_salary'] = _grossSalaryAnnual! / 12.0; // mensuel, format legacy
    }
    if (_pensionBalance != null) {
      answers['q_lpp_avoir'] = _pensionBalance;
    }
    if (_inCouple != null) answers['q_in_couple'] = _inCouple;

    await ReportPersistenceService.saveAnswers(answers);
    await coachProvider.mergeAnswers(answers);
  }

  /// Format CHF sans décimale avec apostrophe suisse comme séparateur
  /// de milliers. Pure function for determinism; DossierStrip must see
  /// the same rendering as any downstream screen.
  static String _formatChf(double v) {
    final whole = v.round();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
