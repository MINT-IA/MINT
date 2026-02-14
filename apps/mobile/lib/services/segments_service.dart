import 'dart:math';

// ────────────────────────────────────────────────────────────
//  SEGMENTS SOCIOLOGIQUES SERVICE — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Contains 3 service classes for sociological segments:
//   1. GenderGapService  — pension gap analysis for part-time workers
//   2. FrontalierService — cross-border worker rules (FR/DE/IT/AT/LI)
//   3. IndependantService — self-employed coverage gap analysis
//
// All logic is local (no backend call). No banned terms
// ("garanti", "assuré", "certain") — only "peut", "pourrait",
// "estimation".
// ────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
//  1. GENDER GAP PREVOYANCE SERVICE
// ════════════════════════════════════════════════════════════

/// Input model for Gender Gap analysis.
class GenderGapInput {
  final double tauxActivite; // 0-100%
  final int age;
  final double revenuAnnuel; // gross annual income at current taux
  final double avoirLpp; // current LPP assets
  final int anneesCotisation; // years already contributed
  final String canton; // e.g. "VD", "GE", "ZH"

  const GenderGapInput({
    required this.tauxActivite,
    required this.age,
    required this.revenuAnnuel,
    required this.avoirLpp,
    required this.anneesCotisation,
    required this.canton,
  });
}

/// Result of Gender Gap analysis.
class GenderGapResult {
  final double renteAt100Pct; // projected annual pension at 100% activity
  final double renteAtCurrentTaux; // projected annual pension at current taux
  final double lacuneAnnuelle; // annual pension gap
  final double lacuneTotale; // total gap over retirement (20 years approx)
  final double salaireCoordonne100; // coordinated salary at 100%
  final double salaireCoordonneActuel; // coordinated salary at current taux
  final double deductionCoordination; // 26'460 CHF (fixed, NOT prorated)
  final int anneesRestantes; // years to age 65
  final List<GenderGapRecommendation> recommendations;
  final String statistiqueOfs;

  const GenderGapResult({
    required this.renteAt100Pct,
    required this.renteAtCurrentTaux,
    required this.lacuneAnnuelle,
    required this.lacuneTotale,
    required this.salaireCoordonne100,
    required this.salaireCoordonneActuel,
    required this.deductionCoordination,
    required this.anneesRestantes,
    required this.recommendations,
    required this.statistiqueOfs,
  });
}

/// A single recommendation.
class GenderGapRecommendation {
  final String title;
  final String description;
  final String source;
  final String icon; // icon name for the UI

  const GenderGapRecommendation({
    required this.title,
    required this.description,
    required this.source,
    required this.icon,
  });
}

/// Service that analyses the pension gap for part-time workers.
///
/// The coordination deduction (CHF 26'460) is NOT prorated for
/// part-time workers under current LPP law (art. 8), which creates
/// a disproportionate penalty on lower activity rates.
class GenderGapService {
  // ── Constants ──────────────────────────────────────────────

  /// LPP coordination deduction (art. 8). NOT prorated.
  static const double deductionCoordination = 26460;

  /// Maximum coordinated salary (LPP).
  static const double maxSalaireCoordonne = 64260;

  /// Minimum coordinated salary (LPP).
  static const double minSalaireCoordonne = 3780;

  /// Conversion rate at retirement (LPP art. 14).
  static const double tauxConversion = 0.068;

  /// Swiss legal retirement age (post-AVS21).
  static const int ageRetraite = 65;

  /// LPP contribution rates by age bracket (employee + employer).
  static const Map<String, double> tauxCotisationParAge = {
    '25-34': 0.07,
    '35-44': 0.10,
    '45-54': 0.15,
    '55-64': 0.18,
  };

  /// OFS statistic on gender pension gap.
  static const String statistiqueOfs =
      'En Suisse, les femmes touchent en moyenne 37% de rente '
      'de moins que les hommes (OFS 2024)';

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the pension gap between current activity rate and 100%.
  static GenderGapResult analyse({required GenderGapInput input}) {
    final anneesRestantes = (ageRetraite - input.age).clamp(0, 40);

    // Salary at 100% (extrapolated from current taux)
    final salaire100 = input.tauxActivite > 0
        ? input.revenuAnnuel / (input.tauxActivite / 100)
        : 0.0;

    // Coordinated salary at 100%
    final salaireCoordonne100 =
        _computeSalaireCoordonne(salaire100);

    // Coordinated salary at current taux
    final salaireCoordonneActuel =
        _computeSalaireCoordonne(input.revenuAnnuel);

    // Get contribution rate for current age
    final tauxCotis = _getTauxCotisation(input.age);

    // Project LPP capital at retirement for 100% activity
    final capital100 = _projectCapital(
      avoirActuel: input.avoirLpp,
      salaireCoordonne: salaireCoordonne100,
      tauxCotisation: tauxCotis,
      anneesRestantes: anneesRestantes,
      age: input.age,
    );

    // Project LPP capital at retirement for current taux
    final capitalActuel = _projectCapital(
      avoirActuel: input.avoirLpp,
      salaireCoordonne: salaireCoordonneActuel,
      tauxCotisation: tauxCotis,
      anneesRestantes: anneesRestantes,
      age: input.age,
    );

    // Convert capital to annual pension
    final renteAt100 = capital100 * tauxConversion;
    final renteAtCurrentTaux = capitalActuel * tauxConversion;
    final lacuneAnnuelle = renteAt100 - renteAtCurrentTaux;
    final lacuneTotale = lacuneAnnuelle * 20; // approx 20 years of retirement

    // Build recommendations
    final recommendations = _buildRecommendations(
      input: input,
      lacuneAnnuelle: lacuneAnnuelle,
      salaireCoordonneActuel: salaireCoordonneActuel,
    );

    return GenderGapResult(
      renteAt100Pct: renteAt100,
      renteAtCurrentTaux: renteAtCurrentTaux,
      lacuneAnnuelle: lacuneAnnuelle,
      lacuneTotale: lacuneTotale,
      salaireCoordonne100: salaireCoordonne100,
      salaireCoordonneActuel: salaireCoordonneActuel,
      deductionCoordination: deductionCoordination,
      anneesRestantes: anneesRestantes,
      recommendations: recommendations,
      statistiqueOfs: statistiqueOfs,
    );
  }

  // ── Private helpers ────────────────────────────────────────

  /// Compute the coordinated salary (salaire coordonne).
  static double _computeSalaireCoordonne(double salaireBrut) {
    final coordonne = salaireBrut - deductionCoordination;
    if (coordonne < minSalaireCoordonne) {
      return salaireBrut > deductionCoordination ? minSalaireCoordonne : 0;
    }
    return coordonne.clamp(0.0, maxSalaireCoordonne);
  }

  /// Get the LPP contribution rate for a given age.
  static double _getTauxCotisation(int age) {
    if (age >= 55) return 0.18;
    if (age >= 45) return 0.15;
    if (age >= 35) return 0.10;
    if (age >= 25) return 0.07;
    return 0.0;
  }

  /// Projected annual return on LPP capital (conservative estimate).
  static const double projectedReturn = 0.015;

  /// Project LPP capital at retirement using age-varying contribution rates.
  /// Includes 1.5% projected annual return (aligned with backend).
  static double _projectCapital({
    required double avoirActuel,
    required double salaireCoordonne,
    required double tauxCotisation,
    required int anneesRestantes,
    required int age,
  }) {
    double capital = avoirActuel;
    for (int i = 0; i < anneesRestantes; i++) {
      final ageYear = age + i;
      final taux = _getTauxCotisation(ageYear);
      capital = capital * (1 + projectedReturn) + salaireCoordonne * taux;
    }
    return capital;
  }

  /// Build personalised recommendations.
  static List<GenderGapRecommendation> _buildRecommendations({
    required GenderGapInput input,
    required double lacuneAnnuelle,
    required double salaireCoordonneActuel,
  }) {
    final recs = <GenderGapRecommendation>[];

    // 1. Rachat LPP
    if (lacuneAnnuelle > 0) {
      recs.add(const GenderGapRecommendation(
        title: 'Rachat LPP volontaire',
        description:
            'Un rachat volontaire permet de combler partiellement la '
            'lacune de prevoyance tout en beneficiant d\'une deduction '
            'fiscale. Verifiez le montant de rachat possible aupres '
            'de ta caisse de pension.',
        source: 'LPP art. 79b',
        icon: 'account_balance',
      ));
    }

    // 2. 3a maximise
    recs.add(const GenderGapRecommendation(
      title: '3e pilier maximise',
      description:
          'Versez le plafond annuel de CHF\u00A07\'056 (salaries) pour '
          'compenser partiellement la lacune LPP. La deduction fiscale '
          'est immediate et le capital reste disponible sous certaines '
          'conditions.',
      source: 'OPP3 art. 7',
      icon: 'savings',
    ));

    // 3. Proratisation coordination
    if (input.tauxActivite < 100 && salaireCoordonneActuel < maxSalaireCoordonne * 0.5) {
      recs.add(const GenderGapRecommendation(
        title: 'Verifier la proratisation de la coordination',
        description:
            'Plusieurs caisses de pension proratisent la deduction '
            'de coordination en fonction du taux d\'activite, ce qui '
            'ameliore significativement le salaire coordonne. Discutez-en '
            'avec ton employeur ou ta caisse de pension.',
        source: 'LPP art. 8 / Reglement de caisse',
        icon: 'balance',
      ));
    }

    // 4. Augmenter taux d'activite
    if (input.tauxActivite < 80) {
      recs.add(const GenderGapRecommendation(
        title: 'Explorer une augmentation du taux d\'activite',
        description:
            'Meme une augmentation de 10 a 20 points de pourcentage '
            'du taux d\'activite peut reduire significativement la '
            'lacune de prevoyance, surtout si la deduction de '
            'coordination n\'est pas proratisee.',
        source: 'Analyse prevoyance MINT',
        icon: 'trending_up',
      ));
    }

    return recs;
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ════════════════════════════════════════════════════════════
//  2. FRONTALIER SERVICE
// ════════════════════════════════════════════════════════════

/// Residence country for cross-border workers.
enum PaysResidence { fr, de, it, at, li }

/// Marital status for frontalier analysis.
enum EtatCivilFrontalier { celibataire, marie, divorce, veuf }

/// Input model for frontalier analysis.
class FrontalierInput {
  final PaysResidence paysResidence;
  final String cantonTravail; // e.g. "GE", "VD", "BS", "TI", "ZH"
  final double revenuBrut;
  final EtatCivilFrontalier etatCivil;

  const FrontalierInput({
    required this.paysResidence,
    required this.cantonTravail,
    required this.revenuBrut,
    required this.etatCivil,
  });
}

/// A single rule/alert for a frontalier.
class FrontalierRule {
  final String category; // "fiscal", "3a", "lpp", "avs"
  final String title;
  final String description;
  final String source;
  final bool isAlert; // red alert vs informational

  const FrontalierRule({
    required this.category,
    required this.title,
    required this.description,
    required this.source,
    this.isAlert = false,
  });
}

/// Quasi-resident eligibility result.
class QuasiResidentResult {
  final bool isEligible;
  final String cantonConcerne;
  final String description;
  final String source;

  const QuasiResidentResult({
    required this.isEligible,
    required this.cantonConcerne,
    required this.description,
    required this.source,
  });
}

/// Full frontalier analysis result.
class FrontalierResult {
  final PaysResidence pays;
  final String paysLabel;
  final String flagEmoji;
  final List<FrontalierRule> rules;
  final QuasiResidentResult? quasiResident;
  final List<String> checklist;

  const FrontalierResult({
    required this.pays,
    required this.paysLabel,
    required this.flagEmoji,
    required this.rules,
    this.quasiResident,
    required this.checklist,
  });
}

/// Service for cross-border workers (frontaliers).
///
/// Rules vary per country of residence and canton of work.
/// Covers: 3a rights, fiscal regime, LPP libre passage, AVS coordination.
class FrontalierService {
  // ── Constants ──────────────────────────────────────────────

  static const Map<PaysResidence, String> _paysLabels = {
    PaysResidence.fr: 'France',
    PaysResidence.de: 'Allemagne',
    PaysResidence.it: 'Italie',
    PaysResidence.at: 'Autriche',
    PaysResidence.li: 'Liechtenstein',
  };

  static const Map<PaysResidence, String> _flagEmojis = {
    PaysResidence.fr: 'FR',
    PaysResidence.de: 'DE',
    PaysResidence.it: 'IT',
    PaysResidence.at: 'AT',
    PaysResidence.li: 'LI',
  };

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the situation of a cross-border worker.
  static FrontalierResult analyse({required FrontalierInput input}) {
    final rules = <FrontalierRule>[];

    // Add country-specific rules
    _addFiscalRules(input, rules);
    _add3aRules(input, rules);
    _addLppRules(input, rules);
    _addAvsRules(input, rules);

    // Check quasi-resident eligibility (GE only)
    final quasiResident = _checkQuasiResident(input);

    // Build checklist
    final checklist = _buildChecklist(input);

    return FrontalierResult(
      pays: input.paysResidence,
      paysLabel: _paysLabels[input.paysResidence] ?? '',
      flagEmoji: _flagEmojis[input.paysResidence] ?? '',
      rules: rules,
      quasiResident: quasiResident,
      checklist: checklist,
    );
  }

  /// Get the label for a country.
  static String getPaysLabel(PaysResidence pays) {
    return _paysLabels[pays] ?? '';
  }

  /// Get the flag code for a country.
  static String getFlagCode(PaysResidence pays) {
    return _flagEmojis[pays] ?? '';
  }

  // ── Private rule builders ──────────────────────────────────

  static void _addFiscalRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
  ) {
    switch (input.paysResidence) {
      case PaysResidence.fr:
        if (input.cantonTravail == 'GE') {
          rules.add(const FrontalierRule(
            category: 'fiscal',
            title: 'Imposition a la source en Suisse (GE)',
            description:
                'Les frontaliers travaillant a Geneve sont imposes a la '
                'source en Suisse (accord CH-FR de 1983 specifique GE). '
                'Une retenue de 4.5% est cependant reversee a la France.',
            source: 'Accord CH-FR du 11.04.1983 / CDI CH-FR',
          ));
        } else {
          rules.add(const FrontalierRule(
            category: 'fiscal',
            title: 'Imposition en France (residence)',
            description:
                'Les frontaliers residant en France et travaillant hors '
                'du canton de Geneve sont imposes en France sur leurs '
                'revenus suisses. L\'employeur ne preleve pas d\'impot '
                'a la source.',
            source: 'CDI CH-FR art. 17 / Accord frontalier 1983',
          ));
        }

      case PaysResidence.de:
        rules.add(const FrontalierRule(
          category: 'fiscal',
          title: 'Imposition en Allemagne (residence)',
          description:
              'Les frontaliers residant en Allemagne sont en principe '
              'imposes en Allemagne. La Suisse retient un impot a la '
              'source de max. 4.5%, imputable en Allemagne.',
          source: 'CDI CH-DE art. 15a',
        ));

      case PaysResidence.it:
        rules.add(const FrontalierRule(
          category: 'fiscal',
          title: 'Nouvel accord fiscal CH-IT (2024)',
          description:
              'Le nouvel accord frontalier CH-IT prevoit une imposition '
              'concurrente : la Suisse preleve un impot a la source '
              '(max. 80% du taux normal), et l\'Italie peut imposer '
              'la difference. Verifie ta situation exacte.',
          source: 'Accord frontalier CH-IT 2020 / entre en vigueur 2024',
          isAlert: true,
        ));

      case PaysResidence.at:
        rules.add(const FrontalierRule(
          category: 'fiscal',
          title: 'Imposition en Suisse (source)',
          description:
              'Les frontaliers residant en Autriche sont en principe '
              'imposes a la source en Suisse. L\'Autriche peut '
              'egalement imposer ces revenus avec credit d\'impot.',
          source: 'CDI CH-AT art. 15',
        ));

      case PaysResidence.li:
        rules.add(const FrontalierRule(
          category: 'fiscal',
          title: 'Accord special CH-LI',
          description:
              'Les frontaliers du Liechtenstein beneficient d\'un accord '
              'special. L\'imposition se fait generalement dans le pays '
              'd\'emploi (Suisse). Le Liechtenstein pratique des taux bas.',
          source: 'Accord CH-LI / EEE',
        ));
    }
  }

  static void _add3aRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
  ) {
    // By default, non-resident workers cannot deduct 3a
    final isGE = input.cantonTravail == 'GE';

    if (isGE) {
      rules.add(const FrontalierRule(
        category: '3a',
        title: '3e pilier : possible si quasi-resident GE',
        description:
            'Les frontaliers travaillant a Geneve peuvent deduire '
            'le 3e pilier s\'ils obtiennent le statut de quasi-resident '
            '(>= 90% des revenus du menage provenant de Suisse). '
            'Condition : passage a la declaration ordinaire.',
        source: 'LIPP GE art. 6 al. 1 / LIFD art. 83 al. 3',
      ));
    } else {
      rules.add(const FrontalierRule(
        category: '3a',
        title: '3e pilier : pas de deduction possible',
        description:
            'En tant que frontalier impose dans ton pays de '
            'residence, tu ne peux pas deduire les versements '
            '3a de tes impots suisses. Le 3e pilier reste possible '
            'mais sans avantage fiscal en Suisse.',
        source: 'OPP3 art. 7 / LIFD art. 33a',
        isAlert: true,
      ));
    }
  }

  static void _addLppRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
  ) {
    rules.add(const FrontalierRule(
      category: 'lpp',
      title: 'LPP : affiliation obligatoire',
      description:
          'Les frontaliers sont obligatoirement affilies a la LPP '
          'de leur employeur suisse, comme tout employe. Les memes '
          'regles de cotisation et de prestation s\'appliquent.',
      source: 'LPP art. 2',
    ));

    rules.add(const FrontalierRule(
      category: 'lpp',
      title: 'Libre passage au depart',
      description:
          'En quittant la Suisse, ton avoir LPP est transfere '
          'sur un compte de libre passage. Si tu resides dans '
          'l\'UE/AELE, le transfert de la part obligatoire en cash '
          'n\'est pas possible (reste sur libre passage en CH). '
          'La part surobligatoire peut etre versee.',
      source: 'LFLP art. 25f / Accord CH-UE',
      isAlert: true,
    ));
  }

  static void _addAvsRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
  ) {
    rules.add(FrontalierRule(
      category: 'avs',
      title: 'AVS : cotisation en Suisse',
      description:
          'Les frontaliers cotisent a l\'AVS suisse (1er pilier). '
          'Les periodes de cotisation en Suisse sont totalisees '
          'avec les periodes dans ton pays de residence '
          '(${_paysLabels[input.paysResidence]}) pour le calcul '
          'de ton droit a la rente.',
      source: 'LAVS / Accord CH-UE sur la coordination',
    ));

    rules.add(const FrontalierRule(
      category: 'avs',
      title: 'Rente AVS : calcul pro rata',
      description:
          'Ta rente AVS suisse sera calculee proportionnellement '
          'aux annees de cotisation en Suisse. Tu recevras '
          'egalement une rente de ton pays de residence pour '
          'les periodes cotisees la-bas.',
      source: 'Reglement CE 883/2004',
    ));
  }

  /// Check quasi-resident eligibility (GE only, >= 90% income from CH).
  static QuasiResidentResult? _checkQuasiResident(FrontalierInput input) {
    if (input.cantonTravail != 'GE') return null;

    return const QuasiResidentResult(
      isEligible: true, // depends on actual income proportion
      cantonConcerne: 'GE',
      description:
          'Le statut de quasi-resident est accessible si au moins 90% '
          'des revenus de ton menage proviennent de Suisse. Ce statut '
          'te permet de passer a la declaration ordinaire et de '
          'beneficier des memes deductions que les residents '
          '(3e pilier, frais effectifs, rachats LPP, etc.).',
      source: 'LIPP GE art. 6 / ATF 136 II 241',
    );
  }

  /// Build a checklist for frontaliers.
  static List<String> _buildChecklist(FrontalierInput input) {
    final checklist = <String>[
      'Verifier ton regime fiscal exact avec un fiduciaire',
      'Demander ton certificat de salaire annuel',
      'Verifier les cotisations AVS (extrait de compte AVS)',
      'Demander le certificat LPP de ta caisse de pension',
      'Verifier les prestations en cas d\'invalidite et de deces',
    ];

    if (input.cantonTravail == 'GE') {
      checklist.add(
        'Evaluer l\'interet du statut de quasi-resident (si >= 90% revenus CH)',
      );
    }

    checklist.addAll([
      'Conserver les justificatifs pour la declaration dans ton pays',
      'Verifier ta couverture maladie (LAMal ou pays de residence)',
      'Planifier le libre passage en cas de depart de Suisse',
    ]);

    return checklist;
  }
}

// ════════════════════════════════════════════════════════════
//  3. INDEPENDANT SERVICE
// ════════════════════════════════════════════════════════════

/// Input model for self-employed analysis.
class IndependantInput {
  final double revenuNet; // net annual income
  final int age;
  final bool hasLpp; // voluntary LPP affiliation
  final bool hasIjm; // daily sickness benefit insurance
  final bool hasLaa; // accident insurance
  final bool has3a;
  final String canton;

  const IndependantInput({
    required this.revenuNet,
    required this.age,
    this.hasLpp = false,
    this.hasIjm = false,
    this.hasLaa = false,
    this.has3a = false,
    required this.canton,
  });
}

/// Coverage gap item.
class CoverageGapItem {
  final String label;
  final String description;
  final bool isCovered;
  final String urgency; // "critique", "haute", "moyenne", "basse"
  final String recommendation;
  final String source;

  const CoverageGapItem({
    required this.label,
    required this.description,
    required this.isCovered,
    required this.urgency,
    required this.recommendation,
    required this.source,
  });
}

/// Protection cost breakdown.
class ProtectionCost {
  final double avsMensuel;
  final double ijmMensuel;
  final double laaMensuel;
  final double pillar3aMensuel;
  final double totalMensuel;
  final double totalAnnuel;

  const ProtectionCost({
    required this.avsMensuel,
    required this.ijmMensuel,
    required this.laaMensuel,
    required this.pillar3aMensuel,
    required this.totalMensuel,
    required this.totalAnnuel,
  });
}

/// Full self-employed analysis result.
class IndependantResult {
  final List<CoverageGapItem> coverageGaps;
  final ProtectionCost protectionCost;
  final double cotisationAvsAnnuelle;
  final double plafond3a; // max 3a amount (20% of net income, max 36'288)
  final List<String> alerts;
  final List<String> recommendations;

  const IndependantResult({
    required this.coverageGaps,
    required this.protectionCost,
    required this.cotisationAvsAnnuelle,
    required this.plafond3a,
    required this.alerts,
    required this.recommendations,
  });
}

/// Service for self-employed workers.
///
/// Analyses coverage gaps and estimates protection costs.
/// Key risks: no mandatory LPP, no mandatory IJM (CRITICAL),
/// no mandatory LAA.
class IndependantService {
  // ── Constants ──────────────────────────────────────────────

  /// 3a ceiling for self-employed without LPP (20% of net income, OPP3 art. 7).
  static const double plafond3aMax = 36288;

  /// 3a ceiling for self-employed WITH voluntary LPP (OPP3 art. 7, 2025/2026).
  static const double plafond3aAvecLpp = 7258;

  /// AVS rate for self-employed (full rate at income > 58'800).
  static const double tauxAvsPlein = 0.106;

  /// Swiss legal retirement age.
  static const int ageRetraite = 65;

  /// Simplified degressive AVS rates for low incomes.
  /// Key: income threshold, Value: effective rate.
  static const List<_AvsDegressifBracket> _avsDegressifBrackets = [
    _AvsDegressifBracket(threshold: 9800, rate: 0.0),
    _AvsDegressifBracket(threshold: 17400, rate: 0.043),
    _AvsDegressifBracket(threshold: 21100, rate: 0.046),
    _AvsDegressifBracket(threshold: 24900, rate: 0.049),
    _AvsDegressifBracket(threshold: 28600, rate: 0.052),
    _AvsDegressifBracket(threshold: 32400, rate: 0.056),
    _AvsDegressifBracket(threshold: 36100, rate: 0.060),
    _AvsDegressifBracket(threshold: 39900, rate: 0.064),
    _AvsDegressifBracket(threshold: 43600, rate: 0.069),
    _AvsDegressifBracket(threshold: 47400, rate: 0.074),
    _AvsDegressifBracket(threshold: 51100, rate: 0.079),
    _AvsDegressifBracket(threshold: 54900, rate: 0.085),
    _AvsDegressifBracket(threshold: 58800, rate: 0.092),
  ];

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the coverage situation of a self-employed person.
  static IndependantResult analyse({required IndependantInput input}) {
    // Coverage gaps
    final coverageGaps = _analyseCoverageGaps(input);

    // AVS contribution
    final cotisationAvs = _computeAvsContribution(input.revenuNet);

    // 3a ceiling: 20% of net income if no LPP, max 35'280
    // If voluntary LPP: standard 7'258
    final plafond3a = input.hasLpp
        ? plafond3aAvecLpp
        : min(input.revenuNet * 0.20, plafond3aMax);

    // Protection cost simulation
    final protectionCost = _computeProtectionCost(
      revenuNet: input.revenuNet,
      cotisationAvs: cotisationAvs,
      plafond3a: plafond3a,
      hasIjm: input.hasIjm,
      hasLaa: input.hasLaa,
    );

    // Alerts
    final alerts = _buildAlerts(input);

    // Recommendations
    final recommendations = _buildRecommendations(input, plafond3a);

    return IndependantResult(
      coverageGaps: coverageGaps,
      protectionCost: protectionCost,
      cotisationAvsAnnuelle: cotisationAvs,
      plafond3a: plafond3a,
      alerts: alerts,
      recommendations: recommendations,
    );
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  // ── Private helpers ────────────────────────────────────────

  /// Analyse coverage gaps.
  static List<CoverageGapItem> _analyseCoverageGaps(IndependantInput input) {
    return [
      CoverageGapItem(
        label: 'LPP (2e pilier)',
        description: 'Prevoyance professionnelle obligatoire pour les salaries',
        isCovered: input.hasLpp,
        urgency: input.hasLpp ? 'basse' : 'haute',
        recommendation: input.hasLpp
            ? 'Tu es affilie volontairement. Verifie tes prestations.'
            : 'Envisagez une affiliation volontaire a une caisse de pension '
                '(fondation collective ou caisse de ta branche).',
        source: 'LPP art. 4 / art. 44',
      ),
      CoverageGapItem(
        label: 'IJM (Indemnite journaliere maladie)',
        description: 'Couverture du revenu en cas de maladie',
        isCovered: input.hasIjm,
        urgency: input.hasIjm ? 'basse' : 'critique',
        recommendation: input.hasIjm
            ? 'Ta couverture IJM est en place. Verifie le delai de carence '
                'et le montant assure.'
            : 'URGENT : sans IJM, tu n\'as aucun revenu en cas de maladie. '
                'Souscrivez une assurance IJM individuelle (indemnite journaliere '
                'en cas de maladie).',
        source: 'LAMal / Pratique independants',
      ),
      CoverageGapItem(
        label: 'LAA (Assurance accident)',
        description: 'Couverture en cas d\'accident professionnel ou prive',
        isCovered: input.hasLaa,
        urgency: input.hasLaa ? 'basse' : 'haute',
        recommendation: input.hasLaa
            ? 'Ta couverture accident est en place.'
            : 'Souscrivez une assurance accident individuelle. '
                'Sans LAA, les frais medicaux et la perte de gain '
                'en cas d\'accident ne sont pas couverts.',
        source: 'LAA art. 4',
      ),
      CoverageGapItem(
        label: '3e pilier (3a)',
        description: 'Prevoyance individuelle avec avantage fiscal',
        isCovered: input.has3a,
        urgency: input.has3a ? 'basse' : 'haute',
        recommendation: input.has3a
            ? 'Verifie que tu verses le plafond '
                '(${formatChf(input.hasLpp ? plafond3aAvecLpp : plafond3aMax)}).'
            : 'Ouvrez un 3e pilier et versez le maximum '
                '(${formatChf(input.hasLpp ? plafond3aAvecLpp : plafond3aMax)}). '
                'Sans LPP, le 3a est ton principal outil de prevoyance.',
        source: 'OPP3 art. 7',
      ),
    ];
  }

  /// Compute AVS contribution for self-employed (degressive scale).
  static double _computeAvsContribution(double revenuNet) {
    if (revenuNet <= 0) return 0;
    if (revenuNet >= 58800) return revenuNet * tauxAvsPlein;

    // Find applicable bracket
    for (int i = _avsDegressifBrackets.length - 1; i >= 0; i--) {
      if (revenuNet >= _avsDegressifBrackets[i].threshold) {
        return revenuNet * _avsDegressifBrackets[i].rate;
      }
    }
    return 0; // below minimum threshold
  }

  /// Compute estimated monthly protection costs.
  static ProtectionCost _computeProtectionCost({
    required double revenuNet,
    required double cotisationAvs,
    required double plafond3a,
    required bool hasIjm,
    required bool hasLaa,
  }) {
    final avsMensuel = cotisationAvs / 12;

    // IJM estimate: ~1-3% of insured income (use 2% middle estimate, aligned with backend)
    final ijmMensuel = hasIjm ? 0.0 : (revenuNet * 0.02) / 12;

    // LAA estimate: ~1-2% of insured income (use 1.5% average)
    final laaMensuel = hasLaa ? 0.0 : (revenuNet * 0.015) / 12;

    // 3a monthly (max possible)
    final pillar3aMensuel = plafond3a / 12;

    final totalMensuel = avsMensuel + ijmMensuel + laaMensuel + pillar3aMensuel;
    final totalAnnuel = totalMensuel * 12;

    return ProtectionCost(
      avsMensuel: avsMensuel,
      ijmMensuel: ijmMensuel,
      laaMensuel: laaMensuel,
      pillar3aMensuel: pillar3aMensuel,
      totalMensuel: totalMensuel,
      totalAnnuel: totalAnnuel,
    );
  }

  /// Build alerts for critical gaps.
  static List<String> _buildAlerts(IndependantInput input) {
    final alerts = <String>[];

    if (!input.hasIjm) {
      alerts.add(
        'CRITIQUE : Tu n\'as pas d\'assurance IJM (indemnite '
        'journaliere maladie). En cas de maladie, tu n\'auras '
        'aucun revenu de remplacement. C\'est le risque le plus '
        'important pour un independant.',
      );
    }

    if (!input.hasLaa) {
      alerts.add(
        'IMPORTANT : Sans assurance accident individuelle (LAA), '
        'les frais medicaux en cas d\'accident et la perte de '
        'gain ne sont pas couverts de maniere adequate.',
      );
    }

    if (!input.hasLpp) {
      alerts.add(
        'Ta prevoyance repose uniquement sur l\'AVS (1er pilier) '
        'et le 3e pilier. La rente AVS seule ne couvre generalement '
        'que 40 a 50% du dernier revenu.',
      );
    }

    if (!input.has3a) {
      alerts.add(
        'Tu ne profites pas du 3e pilier. En tant qu\'independant '
        'sans LPP, tu peux deduire jusqu\'a '
        'CHF\u00A035\'280 par an (20% du revenu net).',
      );
    }

    return alerts;
  }

  /// Build recommendations.
  static List<String> _buildRecommendations(
    IndependantInput input,
    double plafond3a,
  ) {
    final recs = <String>[];

    if (!input.hasIjm) {
      recs.add(
        'Souscrire une assurance IJM individuelle : '
        'comparer les offres (delai de carence 30, 60 ou 90 jours, '
        'couverture 80% du revenu).',
      );
    }

    if (!input.hasLaa) {
      recs.add(
        'Souscrire une assurance accident individuelle (LAA) : '
        'verifier que la couverture inclut l\'accident professionnel '
        'et non-professionnel.',
      );
    }

    if (!input.hasLpp) {
      recs.add(
        'Explorer l\'affiliation volontaire a une caisse de pension : '
        'fondation collective, caisse de branche, ou fondation '
        'individuelle. Comparer les conditions.',
      );
    }

    if (!input.has3a) {
      recs.add(
        'Ouvrir un 3e pilier et verser le maximum annuel de '
        '${formatChf(plafond3a)}. L\'economie fiscale est '
        'significative.',
      );
    }

    // Always recommend
    recs.add(
      'Verifier ton extrait AVS (compte individuel) pour '
      'confirmer que toutes les annees de cotisation sont '
      'enregistrees.',
    );

    recs.add(
      'Etablir un budget previsionnel pour anticiper les '
      'cotisations sociales (AVS, IJM, LAA, 3a).',
    );

    return recs;
  }
}

/// Internal helper for AVS degressive brackets.
class _AvsDegressifBracket {
  final double threshold;
  final double rate;

  const _AvsDegressifBracket({
    required this.threshold,
    required this.rate,
  });
}
