import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  EXPAT SERVICE — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for cross-border & expatriation planning:
//   1. calculateSourceTax          — Bareme C source tax
//   2. checkQuasiResident          — 90% rule (GE)
//   3. simulate90DayRule           — Home office risk gauge
//   4. compareSocialCharges        — CH vs neighbour charges
//   5. simulateForfaitFiscal       — Lump-sum taxation
//   6. estimateAvsGap              — Pension gap abroad
//   7. planDeparture               — Departure checklist
//   8. compareTaxBurden            — Side-by-side tax comparison
//
// All constants match 2025/2026 Swiss legislation.
// No banned terms ("garanti", "certain", "assure", "sans risque").
// ────────────────────────────────────────────────────────────

class ExpatService {
  ExpatService._();

  // ════════════════════════════════════════════════════════════
  //  DISCLAIMER
  // ════════════════════════════════════════════════════════════

  static const String disclaimer =
      'Estimations simplifiees a but educatif — ne constitue pas '
      'un conseil fiscal ou juridique. Les montants dependent de nombreux '
      'facteurs (deductions, commune, fortune, convention internationale, etc.). '
      'Consulte un-e specialiste fiscal-e pour une analyse personnalisee.';

  // ════════════════════════════════════════════════════════════
  //  FRONTALIER — SOURCE TAX (Bareme C) BY CANTON
  // ════════════════════════════════════════════════════════════
  //
  // LIMITATION: Mobile source tax uses simplified flat rates per canton.
  // Backend frontalier_service.py uses progressive brackets with cantonal multipliers.
  // For precise calculations, the backend endpoint /expat/frontalier/source-tax should
  // be called. This local service is for educational quick estimates only.
  // TODO: Wire mobile to backend API for authoritative source tax calculations.

  static const Map<String, double> sourceTaxRates = {
    'GE': 0.1548,
    'VD': 0.1489,
    'VS': 0.1456,
    'NE': 0.1423,
    'FR': 0.1412,
    'BE': 0.1345,
    'ZH': 0.1287,
    'LU': 0.1234,
    'BS': 0.1578,
    'BL': 0.1456,
    'AG': 0.1212,
    'SG': 0.1245,
    'TG': 0.1189,
    'GR': 0.1267,
    'TI': 0.0000, // Taxed in Italy (new agreement 2024)
    'AR': 0.1178,
    'AI': 0.1145,
    'SH': 0.1223,
    'OW': 0.1112,
    'NW': 0.1123,
    'GL': 0.1201,
    'ZG': 0.1089,
    'UR': 0.1156,
    'SZ': 0.1134,
    'SO': 0.1312,
    'JU': 0.1512,
  };

  // ════════════════════════════════════════════════════════════
  //  SOCIAL CHARGES CH
  // ════════════════════════════════════════════════════════════

  /// AVS/AI/APG employee share (%).
  static double get avsAiApgRate => reg('avs.employee_rate', avsCotisationSalarie);

  /// AC employee share up to CHF 148'200.
  static double get acRate => reg('ac.employee_rate', acCotisationSalarie);

  /// AC solidarite above CHF 148'200.
  static double get acSolidariteRate => reg('ac.solidarity_rate', acCotisationSolidariteSalarie);

  /// AC ceiling.
  static double get acCeiling => reg('ac.salary_ceiling', acPlafondSalaireAssure);

  /// Quasi-resident threshold: 90% of worldwide income in CH.
  static const double quasiResidentThreshold = 0.90;

  /// 90-day rule threshold.
  static const int ninetyDayRuleThreshold = 90;

  // ════════════════════════════════════════════════════════════
  //  FORFAIT FISCAL MINIMUMS BY CANTON
  // ════════════════════════════════════════════════════════════

  /// Federal forfait minimum.
  static const double forfaitFederalMinimum = 400000.0;

  /// Cantonal forfait minimums (depenses de vie minimum).
  /// null means abolished / not available.
  /// Source: LIFD art. 14 al. 3 (base fédérale CHF 400'000), lois cantonales.
  static const Map<String, double?> forfaitMinimumByCanton = {
    'VD': 1000000.0,  // LI-VD art. 60
    'GE': 600000.0,   // LIPP-GE art. 15
    'VS': 250000.0,   // LF-VS art. 12
    'ZG': 500000.0,   // StG-ZG § 12
    'FR': 400000.0,   // LICD-FR art. 12
    'LU': 400000.0,   // StG-LU § 14 (base fédérale)
    'BE': 400000.0,   // StG-BE art. 14
    'NE': 500000.0,   // LCdir-NE art. 14
    'TI': 400000.0,   // LT-TI art. 7 (base fédérale)
    'GR': 400000.0,   // StG-GR art. 11
    'SG': 400000.0,   // StG-SG art. 12
    'TG': 400000.0,   // StG-TG § 12
    'AG': 400000.0,   // StG-AG § 12
    'SO': 400000.0,   // StG-SO § 11
    'OW': 400000.0,   // StG-OW art. 12 (base fédérale)
    'NW': 400000.0,   // StG-NW art. 12 (base fédérale)
    'GL': 400000.0,   // StG-GL art. 12 (base fédérale)
    'UR': 400000.0,   // StG-UR art. 12 (base fédérale)
    'SZ': 400000.0,   // StG-SZ § 12
    'JU': 400000.0,   // LI-JU art. 12
    // Abolished:
    'ZH': null,
    'SH': null,
    'AR': null,
    'AI': null,
    'BS': null,
    'BL': null,
  };

  /// Cantons where forfait is abolished.
  static const Set<String> forfaitAbolishedCantons = {
    'ZH', 'SH', 'AR', 'AI', 'BS', 'BL',
  };

  /// List of eligible cantons for forfait (sorted).
  static List<String> get eligibleForfaitCantons {
    final eligible = forfaitMinimumByCanton.entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .toList()
      ..sort();
    return eligible;
  }

  // ════════════════════════════════════════════════════════════
  //  AVS VOLUNTARY ABROAD
  // ════════════════════════════════════════════════════════════

  /// AVS voluntary minimum contribution per year.
  static double get avsVoluntaryMin => reg('avs.voluntary_min', avsVolontaireCotisationMin);

  /// AVS voluntary maximum contribution per year.
  static double get avsVoluntaryMax => reg('avs.voluntary_max', avsVolontaireCotisationMax);

  /// Rente reduction per missing year (~2.3% per year on 44 years).
  static double get reductionPerMissingYear => 1.0 / reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble());

  /// Full contribution years for max AVS rente.
  static int get fullContributionYears => reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();

  // ════════════════════════════════════════════════════════════
  //  NEIGHBOURING COUNTRY SOCIAL CHARGES (approx employee share)
  // ════════════════════════════════════════════════════════════

  /// Source: backend CHARGES_SOCIALES_PAYS (CSS, SGB IV, INPS, ASVG).
  static const Map<String, Map<String, double>> foreignSocialCharges = {
    'France': {
      'maladie': 0.0000, // CSG/CRDS handled differently
      'vieillesse_base': 0.0690,
      'vieillesse_compl': 0.0400,
      'chomage': 0.0240,
      'csg_crds': 0.0920,
      'total': 0.225,  // ~22.5% (aligned with backend)
    },
    'Allemagne': {
      'krankenversicherung': 0.0730,
      'rentenversicherung': 0.0930,
      'arbeitslosenversicherung': 0.0130,
      'pflegeversicherung': 0.0260,
      'total': 0.205,  // ~20.5% (aligned with backend)
    },
    'Italie': {
      'inps_pensione': 0.0700,
      'inps_malattia': 0.0150,
      'disoccupazione': 0.0150,
      'total': 0.10,   // ~10% (aligned with backend)
    },
    'Autriche': {
      'krankenversicherung': 0.0387,
      'pensionsversicherung': 0.1025,
      'arbeitslosenversicherung': 0.0300,
      'wohnbaufoerderung': 0.0088,
      'total': 0.18,   // ~18% (aligned with backend)
    },
  };

  /// Approximate effective tax rates for comparison countries.
  static const Map<String, double> foreignEffectiveTaxRate = {
    'France': 0.30,
    'Allemagne': 0.35,
    'Italie': 0.38,
    'Autriche': 0.33,
    'Portugal': 0.20,
    'Dubai': 0.00,
    'Singapour': 0.15,
    'UK': 0.32,
  };

  // ════════════════════════════════════════════════════════════
  //  CANTON NAMES (French)
  // ════════════════════════════════════════════════════════════

  static const Map<String, String> cantonNames = {
    'ZH': 'Zurich',
    'BE': 'Berne',
    'LU': 'Lucerne',
    'UR': 'Uri',
    'SZ': 'Schwyz',
    'OW': 'Obwald',
    'NW': 'Nidwald',
    'GL': 'Glaris',
    'ZG': 'Zoug',
    'FR': 'Fribourg',
    'SO': 'Soleure',
    'BS': 'Bale-Ville',
    'BL': 'Bale-Campagne',
    'SH': 'Schaffhouse',
    'AR': 'Appenzell RE',
    'AI': 'Appenzell RI',
    'SG': 'Saint-Gall',
    'GR': 'Grisons',
    'AG': 'Argovie',
    'TG': 'Thurgovie',
    'TI': 'Tessin',
    'VD': 'Vaud',
    'VS': 'Valais',
    'NE': 'Neuchatel',
    'GE': 'Geneve',
    'JU': 'Jura',
  };

  /// Sorted canton codes (alphabetical).
  static List<String> get sortedCantonCodes {
    final codes = cantonNames.keys.toList()..sort();
    return codes;
  }

  // ════════════════════════════════════════════════════════════
  //  1. CALCULATE SOURCE TAX (Bareme C)
  // ════════════════════════════════════════════════════════════

  /// Calculate monthly source tax for a frontalier.
  ///
  /// [salary] — gross monthly salary in CHF.
  /// [canton] — canton of work (2-letter code).
  /// [isMarried] — married status.
  /// [children] — number of dependent children.
  ///
  /// Returns effective tax, rate, annual total.
  static Map<String, dynamic> calculateSourceTax({
    required double salary,
    required String canton,
    bool isMarried = false,
    int children = 0,
  }) {
    // Wave 7 edge-case audit P0-E33 : un canton en minuscule ou avec
    // espace ("ge", "GE ", "Geneva") tombait silencieusement sur le
    // fallback 13 % au lieu du vrai taux cantonal. resolveCanton()
    // normalise + valide.
    final cantonCode = resolveCanton(canton).code;
    final baseRate = sourceTaxRates[cantonCode] ?? 0.13;

    // TI special case: taxed in Italy, not at source in CH
    if (cantonCode == 'TI') {
      return {
        'monthlySalary': salary,
        'canton': canton,
        'cantonNom': cantonNames[canton] ?? canton,
        'monthlyTax': 0.0,
        'effectiveRate': 0.0,
        'annualTax': 0.0,
        'isMarried': isMarried,
        'children': children,
        'isTessin': true,
        'note': 'Depuis le nouvel accord CH-IT (2024), les frontaliers '
            'travaillant au Tessin sont imposes en Italie. '
            'La Suisse ne preleve pas d\'impot a la source.',
        'disclaimer': disclaimer,
      };
    }

    // Married reduction factor (~8%)
    double marriedFactor = isMarried ? 0.92 : 1.0;

    // Children reduction: ~2.5% per child
    double childrenFactor = 1.0 - (children * 0.025);
    childrenFactor = max(0.70, childrenFactor); // floor at 70%

    final effectiveRate = baseRate * marriedFactor * childrenFactor;
    final monthlyTax = salary * effectiveRate;
    final annualTax = monthlyTax * 12;

    return {
      'monthlySalary': salary,
      'canton': cantonCode,
      'cantonNom': cantonNames[cantonCode] ?? cantonCode,
      'monthlyTax': monthlyTax,
      'effectiveRate': effectiveRate,
      'annualTax': annualTax,
      'baseRate': baseRate,
      'isMarried': isMarried,
      'children': children,
      'isTessin': false,
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. CHECK QUASI-RESIDENT ELIGIBILITY
  // ════════════════════════════════════════════════════════════

  /// Check quasi-resident status (mainly relevant for GE).
  ///
  /// If >= 90% of worldwide income is earned in CH, the frontalier
  /// can request ordinary taxation (with deductions).
  static Map<String, dynamic> checkQuasiResident({
    required double chIncome,
    required double worldwideIncome,
    required String canton,
  }) {
    if (worldwideIncome <= 0) {
      return {
        'eligible': false,
        'ratio': 0.0,
        'potentialSavings': 0.0,
        'canton': canton,
        'disclaimer': disclaimer,
      };
    }

    final ratio = chIncome / worldwideIncome;
    final eligible = ratio >= quasiResidentThreshold;

    // Potential savings: difference between source tax and ordinary tax
    // Ordinary tax allows deductions (3a, frais effectifs, etc.)
    // Rough estimate: ~15-25% savings on source tax
    double potentialSavings = 0.0;
    if (eligible) {
      final sourceRate = sourceTaxRates[canton] ?? 0.13;
      // Assume ~20% reduction thanks to deductions
      potentialSavings = chIncome * sourceRate * 0.20;
    }

    return {
      'eligible': eligible,
      'ratio': ratio,
      'ratioPercent': (ratio * 100),
      'threshold': quasiResidentThreshold * 100,
      'chIncome': chIncome,
      'worldwideIncome': worldwideIncome,
      'potentialSavings': potentialSavings,
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'recommendation': eligible
          ? 'Tu es éligible au statut de quasi-résident. Cela te permet de '
              'faire une taxation ordinaire avec déductions (3a, frais effectifs, etc.). '
              'L\'économie potentielle est estimée à ${formatChf(potentialSavings)}/an.'
          : 'Tu n\'es pas éligible au statut de quasi-résident. '
              'Il te faudrait que ${(quasiResidentThreshold * 100).toStringAsFixed(0)}% '
              'de tes revenus mondiaux proviennent de Suisse.',
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  3. SIMULATE 90-DAY RULE
  // ════════════════════════════════════════════════════════════

  /// Simulate the 90-day home office rule for frontaliers.
  ///
  /// If a frontalier works more than 90 days/year outside CH,
  /// the taxation may shift to the country of residence.
  static Map<String, dynamic> simulate90DayRule({
    required int homeOfficeDays,
    required int commuteDays,
  }) {
    final totalWorkDays = homeOfficeDays + commuteDays;
    final riskDays = homeOfficeDays;

    String riskLevel;
    String riskColor;
    String recommendation;

    if (riskDays < 70) {
      riskLevel = 'low';
      riskColor = 'green';
      recommendation =
          'Pas de risque fiscal. Tu es largement sous le seuil de 90 jours. '
          'Tu peux continuer a travailler depuis ton domicile a l\'etranger '
          'sans impact sur ton imposition a la source en Suisse.';
    } else if (riskDays < 90) {
      riskLevel = 'medium';
      riskColor = 'orange';
      recommendation =
          'Zone d\'attention ! Tu t\'approches du seuil de 90 jours. '
          'Il te reste ${90 - riskDays} jours de marge. '
          'Documente bien tes jours de presence au bureau en Suisse.';
    } else {
      riskLevel = 'high';
      riskColor = 'red';
      recommendation =
          'Risque fiscal — l\'imposition peut basculer vers ton pays de residence. '
          'Avec $riskDays jours de home office, tu depasses le seuil de 90 jours. '
          'Ton employeur pourrait devoir cotiser dans ton pays de residence. '
          'Consulte un-e specialiste en fiscalite internationale.';
    }

    return {
      'homeOfficeDays': homeOfficeDays,
      'commuteDays': commuteDays,
      'totalWorkDays': totalWorkDays,
      'riskDays': riskDays,
      'riskLevel': riskLevel,
      'riskColor': riskColor,
      'threshold': ninetyDayRuleThreshold,
      'daysRemaining': max(0, ninetyDayRuleThreshold - riskDays),
      'isOverThreshold': riskDays >= ninetyDayRuleThreshold,
      'recommendation': recommendation,
      'legalReference':
          'Art. 15 al. 4 CDI CH-FR / Accord amiable du 22 decembre 2022 / '
          'Reglement CE 883/2004 art. 13',
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  4. COMPARE SOCIAL CHARGES
  // ════════════════════════════════════════════════════════════

  /// Compare Swiss social charges vs a neighbouring country.
  static Map<String, dynamic> compareSocialCharges({
    required double salary,
    required String residenceCountry,
  }) {
    final annualSalary = salary * 12;

    // ── CH charges ──
    final chAvs = annualSalary * avsAiApgRate;
    final chAcBase = min(annualSalary, acCeiling) * acRate;
    final chAcSolidarite =
        annualSalary > acCeiling ? (annualSalary - acCeiling) * acSolidariteRate : 0.0;
    final chAc = chAcBase + chAcSolidarite;

    // Estimated LPP contribution (employee ~7% of coordinated salary)
    final coordinatedSalary = max(0.0, min(annualSalary, reg('lpp.max_insured_salary', lppSalaireMax)) - reg('lpp.coordination_deduction', lppDeductionCoordination));
    final chLpp = coordinatedSalary * 0.07;

    final chTotal = chAvs + chAc + chLpp;

    // ── Foreign charges ──
    final foreignData = foreignSocialCharges[residenceCountry];
    final foreignTotalRate = foreignData?['total'] ?? 0.20;
    final foreignTotal = annualSalary * foreignTotalRate;

    final difference = chTotal - foreignTotal;

    return {
      'monthlySalary': salary,
      'annualSalary': annualSalary,
      'residenceCountry': residenceCountry,
      'ch': {
        'avs_ai_apg': chAvs,
        'ac': chAc,
        'lpp': chLpp,
        'total': chTotal,
        'totalRate': chTotal / annualSalary,
      },
      'foreign': {
        'details': foreignData ?? {},
        'total': foreignTotal,
        'totalRate': foreignTotalRate,
      },
      'difference': difference,
      'chLessCostly': difference < 0,
      'monthlyDifference': difference / 12,
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  5. SIMULATE FORFAIT FISCAL (lump-sum taxation)
  // ════════════════════════════════════════════════════════════

  /// Simulate forfait fiscal for a wealthy expatriate.
  ///
  /// The forfait is based on living expenses (minimum canton threshold).
  /// Compared to ordinary taxation on actual income.
  static Map<String, dynamic> simulateForfaitFiscal({
    required String canton,
    required double livingExpenses,
    required double actualIncome,
  }) {
    final cantonMin = forfaitMinimumByCanton[canton];

    if (cantonMin == null) {
      return {
        'canton': canton,
        'cantonNom': cantonNames[canton] ?? canton,
        'eligible': false,
        'abolished': true,
        'note': 'Le forfait fiscal a ete aboli dans le canton de '
            '${cantonNames[canton] ?? canton}. Il n\'est plus possible '
            'd\'en beneficier.',
        'disclaimer': disclaimer,
      };
    }

    // Forfait base = max(living expenses, cantonal minimum, federal minimum)
    final forfaitBase = [livingExpenses, cantonMin, forfaitFederalMinimum]
        .reduce(max);

    // Forfait tax: apply a simplified effective rate (~25% on forfait base)
    // This is an approximation; actual rates vary by canton
    const forfaitTaxRate = 0.25;
    final forfaitTax = forfaitBase * forfaitTaxRate;

    // Ordinary tax on actual income
    const ordinaryTaxRate = 0.35; // High earner marginal rate estimate
    final ordinaryTax = actualIncome * ordinaryTaxRate;

    final savings = ordinaryTax - forfaitTax;
    final savingsPercent = ordinaryTax > 0 ? savings / ordinaryTax * 100 : 0.0;

    return {
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'eligible': true,
      'abolished': false,
      'livingExpenses': livingExpenses,
      'actualIncome': actualIncome,
      'forfaitBase': forfaitBase,
      'cantonMinimum': cantonMin,
      'federalMinimum': forfaitFederalMinimum,
      'forfaitTax': forfaitTax,
      'ordinaryTax': ordinaryTax,
      'savings': savings,
      'savingsPercent': savingsPercent,
      'isFavorable': savings > 0,
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  6. ESTIMATE AVS GAP
  // ════════════════════════════════════════════════════════════

  /// Estimate pension reduction for years spent abroad.
  ///
  /// Full AVS rente requires 44 complete contribution years.
  /// Each missing year reduces the rente by ~2.3%.
  static Map<String, dynamic> estimateAvsGap({
    required int yearsAbroad,
    required int yearsInCh,
  }) {
    final totalYears = yearsAbroad + yearsInCh;
    final missingYears = max(0, fullContributionYears - yearsInCh);
    final completeness = min(1.0, yearsInCh / fullContributionYears);
    final reductionPercent = (missingYears * reductionPerMissingYear * 100).clamp(0.0, 100.0);

    // Max monthly AVS rente (LAVS art. 34)
    final maxRenteMensuelle = reg('avs.max_monthly_pension', avsRenteMaxMensuelle);
    final estimatedRente = maxRenteMensuelle * completeness;
    final monthlyLoss = maxRenteMensuelle - estimatedRente;

    // Voluntary contribution info
    final canVolunteer = yearsAbroad > 0;

    String recommendation;
    if (completeness >= 1.0) {
      recommendation =
          'Tu as tes $fullContributionYears annees completes de cotisation. '
          'Ta rente AVS ne devrait pas etre reduite.';
    } else if (completeness >= 0.80) {
      recommendation =
          'Ta rente pourrait etre reduite d\'environ ${reductionPercent.toStringAsFixed(1)}%. '
          'Si tu vis a l\'etranger, tu peux cotiser volontairement a l\'AVS '
          '(entre ${formatChf(avsVoluntaryMin)} et ${formatChf(avsVoluntaryMax)}/an) '
          'pour combler les lacunes.';
    } else {
      recommendation =
          'Attention, ta rente serait significativement reduite '
          '(-${reductionPercent.toStringAsFixed(1)}%). '
          'La cotisation volontaire a l\'AVS depuis l\'etranger est fortement '
          'recommandee pour limiter la perte. '
          'Delai d\'inscription : 1 an apres le depart de Suisse.';
    }

    return {
      'yearsAbroad': yearsAbroad,
      'yearsInCh': yearsInCh,
      'totalYears': totalYears,
      'missingYears': missingYears,
      'completeness': completeness,
      'completenessPercent': completeness * 100,
      'reductionPercent': reductionPercent,
      'maxRente': maxRenteMensuelle,
      'estimatedRente': estimatedRente,
      'monthlyLoss': monthlyLoss,
      'annualLoss': monthlyLoss * 12,
      'canVolunteer': canVolunteer,
      'voluntaryMin': avsVoluntaryMin,
      'voluntaryMax': avsVoluntaryMax,
      'recommendation': recommendation,
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  7. PLAN DEPARTURE
  // ════════════════════════════════════════════════════════════

  /// Generate a departure checklist with timing.
  static Map<String, dynamic> planDeparture({
    required DateTime departureDate,
    required String canton,
    double pillar3aBalance = 0,
    double lppBalance = 0,
  }) {
    final now = DateTime.now();
    final daysUntilDeparture = departureDate.difference(now).inDays;
    // Wave 7 edge-case audit P0-E36 (2026-04-18) : une date de départ
    // passée affichait les items comme "priority: high" et un
    // daysUntilDeparture négatif rendu brut à l'UI. On surface un
    // état `already_departed` explicite à la place.
    if (daysUntilDeparture < 0) {
      return {
        'status': 'already_departed',
        'departureDate': departureDate.toIso8601String(),
        'canton': canton,
        'cantonNom': cantonNames[canton] ?? canton,
        'daysSinceDeparture': -daysUntilDeparture,
        'checklist': const <Map<String, dynamic>>[],
        'note':
            'Date de départ dans le passé. Si tu viens de quitter la Suisse, '
                'les démarches fiscales (déclaration prorata temporis, '
                'retrait 3a/LPP) doivent être engagées sans tarder.',
        'disclaimer': disclaimer,
      };
    }

    final checklist = <Map<String, dynamic>>[
      {
        'id': 'pillar3a',
        'title': 'Retirer pilier 3a',
        // Wave 7 fiscal audit P0-E1 (2026-04-18) : la phrase précédente
        // « Impot de sortie reduit » est factuellement fausse. Le retrait
        // 3a pour départ définitif est taxé séparément (LIFD art. 38
        // al. 2 — barème 1/5 du taux ordinaire) + impôt cantonal à la
        // source sur prestations en capital prévoyance (3-9 % selon
        // canton du dernier domicile). Pour une US person, ce retrait
        // déclenche aussi un exit event côté IRS (3a non-qualified).
        'subtitle':
            'Conditions OPP3 art. 3 al. 1 let. b : possible dès départ '
                'définitif. Imposition séparée LIFD art. 38 + impôt '
                'cantonal à la source (3-9 %).',
        'timing': 'Avant le depart ou juste apres',
        'balance': pillar3aBalance,
        'priority': pillar3aBalance > 0 ? 'high' : 'low',
        'legalRef': 'OPP3 art. 3 al. 1 let. b + LIFD art. 38',
        'usPersonWarning':
            'US person : retrait 3a = exit event IRS (foreign trust / PFIC). '
                'Consulte un·e fiscaliste CH-US avant.',
      },
      {
        'id': 'lpp',
        'title': 'Transferer LPP en libre passage',
        // Wave 7 fiscal audit P0-E2 (2026-04-18) : le libellé précédent
        // suggérait que toute la LPP était bloquée sur libre passage si
        // destination UE/AELE. En réalité, seule la PART OBLIGATOIRE
        // (LPP art. 7-8) est bloquée (LFLP art. 25f al. 1, en vigueur
        // 01.06.2007) quand l'assuré est soumis à l'assurance obligatoire
        // retraite/invalidité/décès dans le pays UE/AELE. La PART
        // SUROBLIGATOIRE peut être retirée en capital (al. 2).
        'subtitle':
            'UE/AELE + affiliation sécu locale → part obligatoire sur '
                'libre passage, part surobligatoire retirable en capital. '
                'Hors UE/AELE (ou sans affiliation sécu) → retrait '
                'intégral possible (LFLP art. 25f al. 1-2).',
        'timing': 'A organiser avant le depart',
        'balance': lppBalance,
        'priority': lppBalance > 0 ? 'high' : 'low',
        'legalRef': 'LFLP art. 25f al. 1-2',
      },
      {
        'id': 'commune',
        'title': 'Annoncer depart a la commune',
        'subtitle': 'Formulaire de depart + desinscription registre des habitants.',
        'timing': '2-4 semaines avant le depart',
        'priority': 'high',
      },
      {
        'id': 'lamal',
        'title': 'Resilier LAMal',
        'subtitle':
            'Resiliation effective a la date de depart. Prevoir une assurance '
                'dans le pays de destination.',
        'timing': 'Des la confirmation de depart',
        'priority': 'high',
      },
      {
        'id': 'cdi',
        'title': 'Verifier CDI avec pays de destination',
        'subtitle':
            'Convention de double imposition : eviter de payer 2x les impots. '
                'La Suisse a signe des CDI avec plus de 100 pays.',
        'timing': 'Avant le depart',
        'priority': 'medium',
      },
      {
        'id': 'caution',
        'title': 'Recuperer caution de loyer',
        'subtitle':
            'Demander la liberation aupres de la banque. '
                'Delai: jusqu\'a 1 an si le bailleur ne repond pas.',
        'timing': 'Apres la remise des cles',
        'priority': 'medium',
      },
      {
        'id': 'impots_prorata',
        'title': 'Declarer impots prorata temporis',
        'subtitle':
            'Tu seras impose sur les revenus du 1er janvier jusqu\'a la date de depart. '
                'Delai de depot: 30 jours apres le depart.',
        'timing': '30 jours apres le depart',
        'priority': 'high',
      },
    ];

    return {
      'departureDate': departureDate.toIso8601String(),
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'daysUntilDeparture': daysUntilDeparture,
      'pillar3aBalance': pillar3aBalance,
      'lppBalance': lppBalance,
      'checklist': checklist,
      'noExitTax': true,
      'exitTaxNote':
          'La Suisse ne preleve pas de taxe de sortie (exit tax). '
          'Tes gains en capital ne sont pas imposes au depart — '
          'contrairement a certains pays (USA, France, etc.).',
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  8. COMPARE TAX BURDEN
  // ════════════════════════════════════════════════════════════

  /// Side-by-side tax comparison: CH canton vs target country.
  static Map<String, dynamic> compareTaxBurden({
    required double salary,
    required String canton,
    required String targetCountry,
  }) {
    final annualSalary = salary * 12;

    // CH effective rate (simplified)
    final chSourceRate = sourceTaxRates[canton] ?? 0.13;
    final chSocialRate = avsAiApgRate + acRate; // ~6.4%
    final chTotalRate = chSourceRate + chSocialRate;
    final chTotalTax = annualSalary * chTotalRate;

    // Foreign effective rate
    final foreignTaxRate = foreignEffectiveTaxRate[targetCountry] ?? 0.30;
    final foreignSocialRate =
        foreignSocialCharges[targetCountry]?['total'] ?? 0.20;
    final foreignTotalRate = foreignTaxRate + foreignSocialRate;
    // Avoid double social charges: just combine
    final foreignTotalTax = annualSalary * foreignTotalRate;

    final difference = chTotalTax - foreignTotalTax;

    return {
      'monthlySalary': salary,
      'annualSalary': annualSalary,
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'targetCountry': targetCountry,
      'ch': {
        'taxRate': chSourceRate,
        'socialRate': chSocialRate,
        'totalRate': chTotalRate,
        'totalTax': chTotalTax,
        'netSalary': annualSalary - chTotalTax,
      },
      'foreign': {
        'taxRate': foreignTaxRate,
        'socialRate': foreignSocialRate,
        'totalRate': foreignTotalRate,
        'totalTax': foreignTotalTax,
        'netSalary': annualSalary - foreignTotalTax,
      },
      'difference': difference,
      'chCheaper': difference < 0,
      'disclaimer': disclaimer,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }

  /// Format percentage.
  static String formatPercent(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  /// Country labels in French.
  static const Map<String, String> countryLabels = {
    'France': 'France',
    'Allemagne': 'Allemagne',
    'Italie': 'Italie',
    'Autriche': 'Autriche',
  };

  /// Country labels for tax comparison (extended).
  static const Map<String, String> taxComparisonCountries = {
    'France': 'France',
    'Allemagne': 'Allemagne',
    'Italie': 'Italie',
    'Autriche': 'Autriche',
    'Portugal': 'Portugal',
    'Dubai': 'Dubai',
    'Singapour': 'Singapour',
    'UK': 'Royaume-Uni',
  };
}
