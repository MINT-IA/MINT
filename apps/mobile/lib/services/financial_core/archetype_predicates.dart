/// Prédicats d'archétype partagés (financial_core L1).
///
/// SOURCE OF TRUTH des gates qui pilotent l'ESTIMATION de la prévoyance par
/// âge×salaire. Les deux moteurs de profil — `MinimalProfileService.compute`
/// et `CoachProfile.fromWizardAnswers` — consomment ces mêmes prédicats afin
/// qu'un même profil produise le même verdict, quelle que soit la surface
/// empruntée (CLAUDE.md NEVER #3 : un seul gate, pas deux dérives).
///
/// Plan mint-illogism-fixes-07 (oracle independent_no_lpp-3 + cadre_divorce_hypo-1).
class ArchetypePredicates {
  ArchetypePredicates._();

  /// True quand l'archétype « indépendant sans LPP » s'applique : un
  /// indépendant sans caisse déclarée. Pour ce profil l'avoir LPP est 0.
  ///
  /// Note : ce prédicat répond « pas de caisse du tout ». Le gate qui ferme
  /// le bug du gate non-équivalent (independent_no_lpp-3) est plutôt
  /// [canEstimateLppByEmployment] — un indépendant qui répond « oui » à la
  /// question caisse ne doit JAMAIS recevoir un avoir ESTIMÉ (seule une
  /// valeur réelle saisie/scannée compte).
  static bool isIndependantSansLpp({
    required String? employmentStatus,
    required bool hasPensionFund,
  }) =>
      employmentStatus == 'independant' && !hasPensionFund;

  /// Règle d'or independent_no_lpp-3 : l'ESTIMATION LPP âge×salaire est
  /// INTERDITE pour un indépendant, même s'il a déclaré une caisse
  /// (`hasPensionFund == true`). Un indépendant cotise à titre facultatif et
  /// de manière irrégulière — l'estimation salariée surévalue son avoir. Seule
  /// une valeur réelle saisie/scannée est exploitable.
  ///
  /// C'est ce prédicat — et non le free-standing `q_has_pension_fund` — qui
  /// doit garder la branche d'estimation dans les deux moteurs.
  static bool canEstimateLppByEmployment({
    required String? employmentStatus,
    required bool hasPensionFund,
  }) =>
      employmentStatus != 'independant' && hasPensionFund;

  /// True si l'avoir LPP peut être estimé par âge×salaire pour cet état civil.
  ///
  /// False pour un divorcé : le partage de prévoyance au divorce
  /// (CC art. 122 / LFLP art. 22a — seule la part acquise pendant le mariage
  /// est partagée) rend l'avoir réel path-dependent du jugement. Estimer par
  /// âge×salaire produirait un nombre faux présenté comme certain. Le moteur
  /// doit exposer l'état « valeur réelle requise » + dégrader la confiance.
  static bool canEstimateLppByCivilStatus({required bool isDivorced}) =>
      !isDivorced;
}
