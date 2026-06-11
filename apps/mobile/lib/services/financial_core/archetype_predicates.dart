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

  /// SOURCE OF TRUTH du droit à la DÉDUCTION fiscale 3a (plan
  /// mint-illogism-fixes-08, oracles expat_us-2 + frontalier-1).
  ///
  /// Aligne le chemin générique (minimal_profile + coach_profile.canContribute3a)
  /// sur le hub frontalier dédié (segments_service._add3aRules) qui gate déjà
  /// correctement. Avant ce plan les deux chemins divergeaient pour le MÊME
  /// archétype (CLAUDE.md NEVER #3) : le hub gate sur le statut quasi-résident,
  /// le chemin générique accordait la déduction à TOUT frontalier salarié.
  ///
  /// Règles :
  ///   * US person (FATCA) → false : la plupart des prestataires 3a suisses
  ///     refusent les US persons (CLAUDE.md NEVER #7).
  ///   * Frontalier (permis G) → déductible UNIQUEMENT si quasi-résident.
  ///     Le seul canton offrant ce statut est Genève (LIPP GE art. 6 al. 1 /
  ///     LIFD art. 83 al. 3 — ≥ 90% des revenus de source suisse + passage à
  ///     la déclaration ordinaire). Même prédicat que segments_service
  ///     (`cantonTravail == 'GE'`). Hors GE : « pas de déduction possible »
  ///     (imposé à la source, OPP3 art. 7 / LIFD art. 33a).
  ///   * Autres archétypes → on délègue au fallback fourni
  ///     ([prevoyanceFallback], p.ex. `PrevoyanceProfile.canContribute3a`).
  ///
  /// [workCanton] = canton de travail (sur CoachProfile = `canton`). Normalisé
  /// en amont par l'appelant si nécessaire.
  static bool canContribute3a({
    required bool isUsPerson,
    required bool isCrossBorder,
    required String? workCanton,
    required double grossAnnualIncome,
    required bool prevoyanceFallback,
  }) {
    if (isUsPerson) return false;
    if (isCrossBorder) {
      // Quasi-résident = seul cas frontalier déductible. Genève uniquement,
      // et seulement avec un revenu suisse positif (sinon rien à déduire).
      final isGeneva = workCanton == 'GE';
      return isGeneva && grossAnnualIncome > 0;
    }
    return prevoyanceFallback;
  }
}
