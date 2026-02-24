/// Guided Precision Entry service (S41).
///
/// Mirrors the backend precision logic: contextual field help,
/// cross-validation alerts, archetype-aware smart defaults,
/// and progressive precision prompts.
///
/// References:
/// - DATA_ACQUISITION_STRATEGY.md, Channel 2
/// - ADR-20260223-unified-financial-engine.md
library;

/// Contextual help for a financial field — tells the user exactly
/// where to find the number and what it is called on the document.
class FieldHelp {
  final String fieldName;
  final String whereToFind;
  final String documentName;
  final String germanName;
  final String? fallbackEstimation;

  const FieldHelp({
    required this.fieldName,
    required this.whereToFind,
    required this.documentName,
    required this.germanName,
    this.fallbackEstimation,
  });
}

/// Alert raised when entered values are inconsistent with each other
/// or with reasonable Swiss-financial bounds.
class CrossValidationAlert {
  final String fieldName;

  /// 'warning' or 'error'
  final String severity;
  final String message;
  final String suggestion;

  const CrossValidationAlert({
    required this.fieldName,
    required this.severity,
    required this.message,
    required this.suggestion,
  });
}

/// An archetype-aware default value for a field the user hasn't filled.
class SmartDefault {
  final String fieldName;
  final double value;
  final String source;
  final double confidence; // 0.0 – 1.0

  const SmartDefault({
    required this.fieldName,
    required this.value,
    required this.source,
    required this.confidence,
  });
}

/// Contextual prompt asking for more precision when it matters.
class PrecisionPrompt {
  final String trigger;
  final String fieldNeeded;
  final String promptText;
  final String impactText;

  const PrecisionPrompt({
    required this.trigger,
    required this.fieldNeeded,
    required this.promptText,
    required this.impactText,
  });
}

/// Main precision service — all methods are static / pure.
class PrecisionService {
  PrecisionService._();

  // ------------------------------------------------------------------
  // 1. Contextual field help
  // ------------------------------------------------------------------

  static final Map<String, FieldHelp> _fieldHelpMap = {
    'lpp_total': const FieldHelp(
      fieldName: 'lpp_total',
      whereToFind:
          'Sur ton certificat de prevoyance, ligne "Avoir de vieillesse" ou "Total des avoirs".',
      documentName: 'Certificat de prevoyance LPP',
      germanName: 'Altersguthaben (Vorsorgeausweis)',
      fallbackEstimation:
          'On peut estimer depuis ton salaire et ton age, mais la precision sera de +/-30 %.',
    ),
    'lpp_obligatoire': const FieldHelp(
      fieldName: 'lpp_obligatoire',
      whereToFind:
          'Sur ton certificat de prevoyance, ligne "Part obligatoire" ou "Obligatorisches Altersguthaben".',
      documentName: 'Certificat de prevoyance LPP',
      germanName: 'Obligatorisches Altersguthaben (Vorsorgeausweis)',
      fallbackEstimation:
          'Estimation possible depuis le salaire coordonne et les bonifications legales.',
    ),
    'lpp_surobligatoire': const FieldHelp(
      fieldName: 'lpp_surobligatoire',
      whereToFind:
          'Sur ton certificat de prevoyance, ligne "Part surobligatoire" (= total - obligatoire).',
      documentName: 'Certificat de prevoyance LPP',
      germanName: 'Ueberobligatorisches Altersguthaben (Vorsorgeausweis)',
      fallbackEstimation:
          'Calculable comme la difference entre LPP total et LPP obligatoire.',
    ),
    'salaire_brut': const FieldHelp(
      fieldName: 'salaire_brut',
      whereToFind:
          'Sur ta fiche de salaire (bulletin de paie), ligne "Salaire brut" tout en haut.',
      documentName: 'Fiche de salaire mensuelle',
      germanName: 'Bruttolohn (Lohnabrechnung)',
      fallbackEstimation: null,
    ),
    'salaire_net': const FieldHelp(
      fieldName: 'salaire_net',
      whereToFind:
          'Sur ta fiche de salaire, ligne "Salaire net" ou "Montant verse".',
      documentName: 'Fiche de salaire mensuelle',
      germanName: 'Nettolohn (Lohnabrechnung)',
      fallbackEstimation:
          'Environ 75-82 % du brut selon le canton et ta situation.',
    ),
    'taux_marginal': const FieldHelp(
      fieldName: 'taux_marginal',
      whereToFind:
          'Sur ton avis de taxation, compare l\'impot total avec le revenu imposable. '
          'Ou utilise le simulateur cantonal.',
      documentName: 'Avis de taxation (Declaration fiscale)',
      germanName: 'Grenzsteuersatz (Steuerveranlagung)',
      fallbackEstimation:
          'Estimation possible depuis le revenu et le canton, mais peut varier de +/-5 points.',
    ),
    'avs_contribution_years': const FieldHelp(
      fieldName: 'avs_contribution_years',
      whereToFind:
          'Sur ton extrait de compte individuel AVS (CI), section "Annees de cotisation".',
      documentName: 'Extrait de compte individuel AVS',
      germanName: 'Beitragsjahre (Individueller Kontoauszug AHV)',
      fallbackEstimation:
          'On estime depuis ton age et ton arrivee en Suisse, mais des lacunes sont possibles.',
    ),
    'pillar_3a_balance': const FieldHelp(
      fieldName: 'pillar_3a_balance',
      whereToFind:
          'Sur ton attestation 3a ou dans ton e-banking, section "Prevoyance 3a".',
      documentName: 'Attestation 3e pilier a',
      germanName: 'Saeule-3a-Guthaben (Vorsorgebescheinigung)',
      fallbackEstimation:
          'On peut estimer si tu cotises depuis un certain nombre d\'annees.',
    ),
    'mortgage_remaining': const FieldHelp(
      fieldName: 'mortgage_remaining',
      whereToFind:
          'Sur ton attestation hypothecaire ou dans ton e-banking, "Capital restant du".',
      documentName: 'Attestation hypothecaire',
      germanName: 'Restschuld (Hypothekarbestaetiung)',
      fallbackEstimation: null,
    ),
    'monthly_expenses': const FieldHelp(
      fieldName: 'monthly_expenses',
      whereToFind:
          'Additionne tes depenses fixes (loyer, assurances, abonnements) '
          'et variables (courses, loisirs). Ton e-banking peut t\'aider.',
      documentName: 'Releve de compte bancaire',
      germanName: 'Monatliche Ausgaben (Kontoauszug)',
      fallbackEstimation:
          'Estimation possible selon ton profil, mais la precision sera limitee.',
    ),
    'replacement_ratio': const FieldHelp(
      fieldName: 'replacement_ratio',
      whereToFind:
          'C\'est le pourcentage de ton dernier salaire que tu veux maintenir a la retraite. '
          'En general entre 60 % et 80 %.',
      documentName: 'Aucun document — c\'est un objectif personnel',
      germanName: 'Ersatzquote',
      fallbackEstimation: 'Par defaut on utilise 70 % (norme suisse courante).',
    ),
    'tax_saving_3a': const FieldHelp(
      fieldName: 'tax_saving_3a',
      whereToFind:
          'Calcule depuis ton taux marginal et ta cotisation 3a annuelle. '
          'Visible aussi sur ton avis de taxation.',
      documentName: 'Avis de taxation',
      germanName: 'Steuerersparnis Saeule 3a (Steuerveranlagung)',
      fallbackEstimation:
          'Estimation = cotisation 3a x taux marginal estime.',
    ),
  };

  /// Returns contextual help for a given financial field.
  static FieldHelp? getFieldHelp(String fieldName) {
    return _fieldHelpMap[fieldName];
  }

  /// Returns all known field-help entries.
  static List<FieldHelp> get allFieldHelps =>
      _fieldHelpMap.values.toList(growable: false);

  // ------------------------------------------------------------------
  // 2. Cross-validation
  // ------------------------------------------------------------------

  /// Runs cross-validation checks on [profile] and returns alerts.
  ///
  /// [profile] keys follow the same naming as the field-help map:
  /// `lpp_total`, `lpp_obligatoire`, `salaire_brut`, `salaire_net`,
  /// `age`, `avs_contribution_years`, `pillar_3a_balance`, etc.
  static List<CrossValidationAlert> crossValidate(
    Map<String, dynamic> profile,
  ) {
    final alerts = <CrossValidationAlert>[];

    final age = _dbl(profile, 'age');
    final salaireBrut = _dbl(profile, 'salaire_brut');
    final salaireNet = _dbl(profile, 'salaire_net');
    final lppTotal = _dbl(profile, 'lpp_total');
    final lppOblig = _dbl(profile, 'lpp_obligatoire');
    final lppSuroblig = _dbl(profile, 'lpp_surobligatoire');
    final pillar3a = _dbl(profile, 'pillar_3a_balance');
    final avsYears = _dbl(profile, 'avs_contribution_years');
    final monthlyExpenses = _dbl(profile, 'monthly_expenses');
    final tauxMarginal = _dbl(profile, 'taux_marginal');

    // Check 1: LPP total vs age/salary bounds
    if (lppTotal > 0 && age > 25 && salaireBrut > 0) {
      final yearsWorked = age - 25;
      final annualSalary = salaireBrut * 12;
      // Rough lower bound: 7% of coordinated salary per year (minimum)
      final salaireCoord =
          (annualSalary - 26460).clamp(3780.0, double.infinity);
      final expectedMin = salaireCoord * 0.07 * yearsWorked * 0.5;
      // Upper bound: generous employer ~25% of full salary
      final expectedMax = annualSalary * 0.25 * yearsWorked;

      if (lppTotal < expectedMin) {
        alerts.add(CrossValidationAlert(
          fieldName: 'lpp_total',
          severity: 'warning',
          message:
              'Ton avoir LPP (CHF ${_fmt(lppTotal)}) semble bas pour ton age et ton salaire.',
          suggestion:
              'As-tu recemment change d\'emploi, retire un EPL ou travaille a temps partiel?',
        ));
      }
      if (lppTotal > expectedMax) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'lpp_total',
          severity: 'warning',
          message: 'Ton avoir LPP semble tres eleve.',
          suggestion:
              'Est-ce que ca inclut bien le surobligatoire? Verifie sur ton certificat de prevoyance.',
        ));
      }
    }

    // Check 2: LPP obligatoire + surobligatoire = total
    if (lppOblig > 0 && lppSuroblig > 0 && lppTotal > 0) {
      final sum = lppOblig + lppSuroblig;
      if ((sum - lppTotal).abs() > lppTotal * 0.02) {
        alerts.add(CrossValidationAlert(
          fieldName: 'lpp_obligatoire',
          severity: 'error',
          message:
              'La somme obligatoire + surobligatoire (CHF ${_fmt(sum)}) '
              'ne correspond pas au total LPP (CHF ${_fmt(lppTotal)}).',
          suggestion:
              'Verifie les montants sur ton certificat de prevoyance.',
        ));
      }
    }

    // Check 3: Salary gross vs net ratio
    if (salaireBrut > 0 && salaireNet > 0) {
      final ratio = salaireNet / salaireBrut;
      if (ratio > 0.92) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'salaire_net',
          severity: 'warning',
          message:
              'Ton net est tres proche du brut — les deductions semblent faibles.',
          suggestion:
              'Verifie que tu as bien entre le salaire brut (avant deductions AVS, LPP, etc.).',
        ));
      }
      if (ratio < 0.55) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'salaire_net',
          severity: 'warning',
          message:
              'L\'ecart entre ton brut et ton net est inhabituellement grand.',
          suggestion:
              'Verifie que le brut inclut bien le 13e salaire si applicable, '
              'et que le net n\'inclut pas de remboursements de frais.',
        ));
      }
    }

    // Check 4: AVS contribution years vs age
    if (avsYears > 0 && age > 0) {
      final maxYears = (age - 20).clamp(0, 44).toDouble();
      if (avsYears > maxYears + 1) {
        alerts.add(CrossValidationAlert(
          fieldName: 'avs_contribution_years',
          severity: 'error',
          message:
              '$avsYears annees de cotisation AVS ne sont pas possibles a ${age.round()} ans.',
          suggestion:
              'Le nombre d\'annees ne peut pas depasser ${maxYears.round()} (cotisation des 20 ans).',
        ));
      }
    }

    // Check 5: Pillar 3a balance vs age
    if (pillar3a > 0 && age > 0) {
      const maxAnnual = 7258.0;
      final maxYears3a = (age - 18).clamp(0, 47).toDouble();
      // Reasonable upper bound: max contribution each year + ~3% annual return
      final theoreticalMax = maxAnnual * maxYears3a * 1.4;
      if (pillar3a > theoreticalMax) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'pillar_3a_balance',
          severity: 'warning',
          message: 'Ton solde 3a semble tres eleve par rapport a ton age.',
          suggestion:
              'Verifie qu\'il s\'agit bien du solde 3a et non du total patrimoine.',
        ));
      }
      if (age < 18 && pillar3a > 0) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'pillar_3a_balance',
          severity: 'error',
          message: 'Tu ne peux ouvrir un 3a qu\'a partir de 18 ans.',
          suggestion: 'Verifie ton age ou ton solde 3a.',
        ));
      }
    }

    // Check 6: Monthly expenses vs net salary
    if (monthlyExpenses > 0 && salaireNet > 0) {
      if (monthlyExpenses > salaireNet * 1.3) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'monthly_expenses',
          severity: 'warning',
          message:
              'Tes depenses mensuelles depassent largement ton salaire net.',
          suggestion:
              'Verifie que tu n\'as pas inclus des depenses annuelles (impots, assurances) en mensuel.',
        ));
      }
    }

    // Check 7: Marginal tax rate bounds
    if (tauxMarginal > 0) {
      if (tauxMarginal > 0.50) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'taux_marginal',
          severity: 'warning',
          message:
              'Un taux marginal superieur a 50 % est tres rare en Suisse.',
          suggestion:
              'Verifie ton avis de taxation — le taux marginal est l\'impot supplementaire '
              'sur le prochain franc gagne, pas le taux moyen.',
        ));
      }
      if (tauxMarginal < 0.05 && salaireBrut > 3000) {
        alerts.add(const CrossValidationAlert(
          fieldName: 'taux_marginal',
          severity: 'warning',
          message:
              'Un taux marginal inferieur a 5 % semble bas pour ton salaire.',
          suggestion:
              'Verifie que tu n\'as pas entre le taux moyen au lieu du taux marginal.',
        ));
      }
    }

    return alerts;
  }

  // ------------------------------------------------------------------
  // 3. Smart defaults
  // ------------------------------------------------------------------

  /// Computes archetype-aware default values for missing fields.
  ///
  /// Uses Swiss statutory minimums, bonification tables, and
  /// archetype-specific adjustments.
  static List<SmartDefault> computeSmartDefaults({
    required String archetype,
    required int age,
    required double salary,
    required String canton,
  }) {
    final defaults = <SmartDefault>[];
    final annualSalary = salary * 12;

    // --- LPP total estimation ---
    final yearsContrib = _lppYears(archetype, age);
    final salaireCoord =
        (annualSalary - 26460).clamp(3780.0, annualSalary * 0.8);
    double lppEstimate = 0;
    for (int a = (age - yearsContrib).round(); a < age; a++) {
      lppEstimate += salaireCoord * _bonificationRate(a);
    }
    // Add ~2% annual return compounding
    lppEstimate *= 1.0 + (yearsContrib * 0.015);

    if (archetype == 'independent_no_lpp') {
      defaults.add(const SmartDefault(
        fieldName: 'lpp_total',
        value: 0,
        source: 'Independant sans LPP — pas de 2e pilier obligatoire',
        confidence: 0.90,
      ));
    } else {
      defaults.add(SmartDefault(
        fieldName: 'lpp_total',
        value: _round(lppEstimate),
        source:
            'Estimation pour un profil $archetype de $age ans (bonifications legales)',
        confidence: archetype == 'swiss_native' ? 0.40 : 0.25,
      ));
    }

    // --- LPP obligatoire estimation ---
    if (archetype != 'independent_no_lpp') {
      // Obligatory part: use only statutory minimum salary coord
      final coordMin = (annualSalary - 26460).clamp(3780.0, 62475.0);
      double obligEstimate = 0;
      for (int a = (age - yearsContrib).round(); a < age; a++) {
        obligEstimate += coordMin * _bonificationRate(a);
      }
      obligEstimate *= 1.0 + (yearsContrib * 0.01);

      defaults.add(SmartDefault(
        fieldName: 'lpp_obligatoire',
        value: _round(obligEstimate),
        source:
            'Estimation part obligatoire (salaire coordonne min LPP art. 8)',
        confidence: 0.30,
      ));
    }

    // --- Salaire net estimation ---
    final netRatio = _netRatio(canton);
    defaults.add(SmartDefault(
      fieldName: 'salaire_net',
      value: _round(salary * netRatio),
      source:
          'Estimation net ~${(netRatio * 100).round()} % du brut (canton de $canton)',
      confidence: 0.35,
    ));

    // --- AVS contribution years ---
    double avsYears;
    if (archetype == 'swiss_native') {
      avsYears = (age - 20).clamp(0, 44).toDouble();
    } else if (archetype.startsWith('expat')) {
      // Expat: assume arrival at ~30 on average
      avsYears = (age - 30).clamp(0, 44).toDouble();
    } else if (archetype == 'cross_border') {
      avsYears = (age - 25).clamp(0, 44).toDouble();
    } else {
      avsYears = (age - 20).clamp(0, 44).toDouble();
    }
    defaults.add(SmartDefault(
      fieldName: 'avs_contribution_years',
      value: avsYears,
      source: 'Estimation pour archetype $archetype (sans lacunes)',
      confidence: archetype == 'swiss_native' ? 0.55 : 0.30,
    ));

    // --- Pillar 3a balance ---
    final contributing3aYears = (age - 25).clamp(0, 40).toDouble();
    final estimated3a = contributing3aYears > 0
        ? contributing3aYears * 7258 * 0.6 // assume 60% utilization
        : 0.0;
    defaults.add(SmartDefault(
      fieldName: 'pillar_3a_balance',
      value: _round(estimated3a),
      source:
          'Estimation (cotisation max CHF 7\'258/an, taux d\'utilisation 60 %)',
      confidence: 0.20,
    ));

    // --- Monthly expenses ---
    final estimatedExpenses = salary * 0.65;
    defaults.add(SmartDefault(
      fieldName: 'monthly_expenses',
      value: _round(estimatedExpenses),
      source: 'Estimation ~65 % du salaire brut (loyer, assurances, quotidien)',
      confidence: 0.25,
    ));

    // --- Taux marginal estimation ---
    final tauxEstimate = _estimateMarginalRate(annualSalary, canton);
    defaults.add(SmartDefault(
      fieldName: 'taux_marginal',
      value: (tauxEstimate * 100).roundToDouble(),
      source: 'Estimation depuis le revenu brut et le canton de $canton',
      confidence: 0.30,
    ));

    // --- Replacement ratio ---
    defaults.add(const SmartDefault(
      fieldName: 'replacement_ratio',
      value: 70,
      source: 'Norme suisse courante : 70 % du dernier salaire',
      confidence: 0.50,
    ));

    // --- Tax saving 3a ---
    final taxSaving3a = 7258 * tauxEstimate;
    defaults.add(SmartDefault(
      fieldName: 'tax_saving_3a',
      value: _round(taxSaving3a),
      source:
          'Cotisation max CHF 7\'258 x taux marginal estime ${(tauxEstimate * 100).round()} %',
      confidence: 0.25,
    ));

    return defaults;
  }

  // ------------------------------------------------------------------
  // 4. Precision prompts
  // ------------------------------------------------------------------

  /// Returns context-sensitive precision prompts based on the current
  /// screen/context and the user's profile completeness.
  static List<PrecisionPrompt> getPrecisionPrompts({
    required String context,
    required Map<String, dynamic> profile,
  }) {
    final prompts = <PrecisionPrompt>[];

    final hasLppOblig = _dbl(profile, 'lpp_obligatoire') > 0;
    final hasLppTotal = _dbl(profile, 'lpp_total') > 0;
    final hasTauxMarginal = _dbl(profile, 'taux_marginal') > 0;
    final hasAvsYears = _dbl(profile, 'avs_contribution_years') > 0;
    final has3a = _dbl(profile, 'pillar_3a_balance') > 0;
    final hasMortgage = _dbl(profile, 'mortgage_remaining') > 0;

    // Rente vs Capital arbitrage context
    if (context == 'rente_vs_capital' || context == 'retirement') {
      if (!hasLppOblig) {
        prompts.add(const PrecisionPrompt(
          trigger: 'rente_vs_capital',
          fieldNeeded: 'lpp_obligatoire',
          promptText:
              'Pour comparer rente et capital precisement, '
              'on a besoin de la part obligatoire de ta LPP.',
          impactText: 'Resultat +/-20 % plus precis',
        ));
      }
      if (!hasLppTotal) {
        prompts.add(const PrecisionPrompt(
          trigger: 'rente_vs_capital',
          fieldNeeded: 'lpp_total',
          promptText:
              'Ton avoir LPP total est estime. '
              'Avec le chiffre exact, la projection sera fiable.',
          impactText: 'Resultat +/-30 % plus precis',
        ));
      }
    }

    // Tax optimization context
    if (context == 'tax_optimization' || context == 'rachat_lpp') {
      if (!hasTauxMarginal) {
        prompts.add(const PrecisionPrompt(
          trigger: 'tax_optimization',
          fieldNeeded: 'taux_marginal',
          promptText:
              'Ton taux marginal est estime. '
              'Ton avis de taxation contient le chiffre exact.',
          impactText: 'Economie d\'impot +/-5 points de precision',
        ));
      }
    }

    // Retirement projection context
    if (context == 'retirement' || context == 'dashboard') {
      if (!hasAvsYears) {
        prompts.add(const PrecisionPrompt(
          trigger: 'retirement',
          fieldNeeded: 'avs_contribution_years',
          promptText:
              'Tes annees AVS sont estimees. '
              'Commande ton extrait de compte individuel (gratuit) pour un chiffre exact.',
          impactText: 'Rente AVS +/-CHF 200/mois de precision',
        ));
      }
      if (!has3a) {
        prompts.add(const PrecisionPrompt(
          trigger: 'retirement',
          fieldNeeded: 'pillar_3a_balance',
          promptText:
              'Ton solde 3a n\'est pas renseigne. '
              'Ajoute-le pour une projection de retraite complete.',
          impactText: 'Projection retraite plus complete',
        ));
      }
    }

    // 3a deep context
    if (context == '3a_deep' || context == '3a_optimization') {
      if (!hasTauxMarginal) {
        prompts.add(const PrecisionPrompt(
          trigger: '3a_optimization',
          fieldNeeded: 'taux_marginal',
          promptText:
              'Pour calculer ton economie fiscale 3a, '
              'on a besoin de ton taux marginal reel.',
          impactText: 'Calcul d\'economie +/-5 points de precision',
        ));
      }
    }

    // Mortgage context
    if (context == 'mortgage') {
      if (!hasMortgage) {
        prompts.add(const PrecisionPrompt(
          trigger: 'mortgage',
          fieldNeeded: 'mortgage_remaining',
          promptText:
              'Pour l\'analyse hypothecaire, '
              'on a besoin du capital restant du exact.',
          impactText: 'Analyse de capacite plus fiable',
        ));
      }
    }

    // Budget context
    if (context == 'budget') {
      final hasExpenses = _dbl(profile, 'monthly_expenses') > 0;
      if (!hasExpenses) {
        prompts.add(const PrecisionPrompt(
          trigger: 'budget',
          fieldNeeded: 'monthly_expenses',
          promptText:
              'Tes depenses mensuelles ne sont pas renseignees. '
              'Ajoute-les pour un budget realiste.',
          impactText: 'Budget +/-15 % plus precis',
        ));
      }
    }

    return prompts;
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  static double _dbl(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      final intV = v.round();
      final str = intV.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return v.toStringAsFixed(0);
  }

  static double _round(double v) => (v / 100).roundToDouble() * 100;

  /// LPP contribution years depending on archetype.
  static double _lppYears(String archetype, int age) {
    switch (archetype) {
      case 'swiss_native':
        return (age - 25).clamp(0, 40).toDouble();
      case 'expat_eu':
      case 'expat_non_eu':
      case 'expat_us':
        return (age - 30).clamp(0, 35).toDouble(); // later start
      case 'independent_with_lpp':
        return (age - 30).clamp(0, 35).toDouble();
      case 'independent_no_lpp':
        return 0;
      case 'cross_border':
        return (age - 25).clamp(0, 40).toDouble();
      case 'returning_swiss':
        return (age - 28).clamp(0, 37).toDouble();
      default:
        return (age - 25).clamp(0, 40).toDouble();
    }
  }

  /// LPP bonification rate by age (LPP art. 16).
  static double _bonificationRate(int age) {
    if (age < 25) return 0;
    if (age < 35) return 0.07;
    if (age < 45) return 0.10;
    if (age < 55) return 0.15;
    return 0.18;
  }

  /// Approximate net/gross ratio by canton.
  static double _netRatio(String canton) {
    // Higher-tax cantons have lower net ratio
    const highTax = {'GE', 'VD', 'NE', 'BS', 'BE', 'JU', 'FR'};
    const lowTax = {'ZG', 'SZ', 'NW', 'OW', 'AI', 'AR', 'UR'};
    if (lowTax.contains(canton.toUpperCase())) return 0.82;
    if (highTax.contains(canton.toUpperCase())) return 0.75;
    return 0.78; // median
  }

  /// Rough marginal rate estimation from annual salary and canton.
  static double _estimateMarginalRate(double annualSalary, String canton) {
    // Simplified progressive brackets (federal + cantonal combined)
    double base;
    if (annualSalary < 50000) {
      base = 0.10;
    } else if (annualSalary < 80000) {
      base = 0.18;
    } else if (annualSalary < 120000) {
      base = 0.25;
    } else if (annualSalary < 180000) {
      base = 0.30;
    } else if (annualSalary < 300000) {
      base = 0.35;
    } else {
      base = 0.40;
    }

    // Canton adjustment
    const lowTax = {'ZG', 'SZ', 'NW', 'OW', 'AI', 'AR', 'UR'};
    const highTax = {'GE', 'VD', 'NE', 'BS', 'BE', 'JU', 'FR'};
    if (lowTax.contains(canton.toUpperCase())) return base * 0.80;
    if (highTax.contains(canton.toUpperCase())) return base * 1.15;
    return base;
  }
}
