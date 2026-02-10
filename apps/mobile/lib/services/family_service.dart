import 'dart:math';

// ────────────────────────────────────────────────────────────
//  FAMILY SERVICE — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for Swiss family financial planning:
//   1. compareFiscalMariage       — Marriage penalty/bonus
//   2. simulateCongeParental      — APG parental leave
//   3. estimateAllocations        — Cantonal family allowances
//   4. calculateImpactFiscalEnfant — Tax impact of children
//   5. compareMariageVsConcubinage — Full comparison
//   6. estimateInheritanceTax     — Inheritance tax comparison
//
// All constants match 2025/2026 Swiss legislation.
// No banned terms ("garanti", "certain", "assure", "sans risque").
// ────────────────────────────────────────────────────────────

class FamilyService {
  FamilyService._();

  // ════════════════════════════════════════════════════════════
  //  MARIAGE FISCAL CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// Double-earner deduction (LIFD art. 33 al. 2).
  static const double deductionDoubleRevenu = 2800.0;

  /// Married couple deduction (LIFD).
  static const double deductionMarie = 2700.0;

  /// Insurance deduction — married couple.
  static const double deductionAssuranceMarie = 3600.0;

  /// Insurance deduction — single person.
  static const double deductionAssuranceCelibataire = 1800.0;

  /// Deduction per child (LIFD art. 35 al. 1 let. a).
  static const double deductionParEnfant = 6700.0;

  /// Maximum childcare deduction (LIFD art. 33 al. 3).
  static const double deductionGardeMax = 25500.0;

  // ════════════════════════════════════════════════════════════
  //  SURVIVOR BENEFITS CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// AVS survivor rente: 80% of deceased's rente (LAVS art. 35).
  static const double avsSurvivorFactor = 0.80;

  /// LPP survivor rente: 60% of insured rente (LPP art. 19).
  static const double lppSurvivorFactor = 0.60;

  /// AVS max single rente mensuelle (2025/2026).
  static const double avsMaxRenteMensuelle = 2520.0;

  // ════════════════════════════════════════════════════════════
  //  APG / PARENTAL LEAVE CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// APG daily max (LAPG art. 16e).
  static const double apgDailyMax = 220.0;

  /// APG maternity duration in calendar days (14 weeks = 98 days).
  static const int apgMaternityDays = 98;

  /// APG maternity duration in weeks.
  static const int apgMaternityWeeks = 14;

  /// APG paternity duration in working days.
  static const int apgPaternityWorkingDays = 10;

  /// APG paternity duration in weeks.
  static const int apgPaternityWeeks = 2;

  /// APG replacement rate (80% of salary).
  static const double apgReplacementRate = 0.80;

  // ════════════════════════════════════════════════════════════
  //  CANTONAL FAMILY ALLOCATIONS (CHF/month per child)
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> allocationsMensuelles = {
    'GE': 300.0,
    'VD': 300.0,
    'VS': 305.0,
    'NE': 220.0,
    'FR': 265.0,
    'BE': 230.0,
    'ZH': 200.0,
    'BS': 200.0,
    'LU': 210.0,
    'AG': 200.0,
    'SG': 200.0,
    'TI': 200.0,
    'GR': 220.0,
    'SO': 200.0,
    'TG': 200.0,
    'BL': 200.0,
    'AR': 200.0,
    'AI': 200.0,
    'GL': 200.0,
    'SH': 200.0,
    'ZG': 300.0,
    'SZ': 200.0,
    'OW': 200.0,
    'NW': 200.0,
    'UR': 200.0,
    'JU': 275.0,
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
  //  SIMPLIFIED TAX RATES (effective rates for 100k single)
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> _effectiveRates100kSingle = {
    'ZG': 0.0823,
    'NW': 0.0891,
    'OW': 0.0934,
    'AI': 0.0956,
    'AR': 0.1012,
    'SZ': 0.1034,
    'UR': 0.1067,
    'LU': 0.1089,
    'GL': 0.1102,
    'TG': 0.1145,
    'SH': 0.1167,
    'AG': 0.1189,
    'GR': 0.1203,
    'BL': 0.1256,
    'SG': 0.1278,
    'ZH': 0.1290,
    'FR': 0.1312,
    'SO': 0.1334,
    'TI': 0.1356,
    'BE': 0.1389,
    'NE': 0.1423,
    'VS': 0.1456,
    'VD': 0.1489,
    'JU': 0.1512,
    'GE': 0.1545,
    'BS': 0.1578,
  };

  /// Inheritance tax rates for non-married partners by canton (taux "tiers").
  /// Married partners are tax-exempt in all cantons.
  /// Source: Lois cantonales sur les droits de succession, 2024.
  static const Map<String, double> _inheritanceTaxRatesNonMarie = {
    'ZH': 0.18,
    'BE': 0.15,
    'LU': 0.20,
    'UR': 0.15,
    'SZ': 0.00,   // SZ: pas d'impot succession
    'OW': 0.00,   // OW: pas d'impot succession
    'NW': 0.00,   // NW: pas d'impot succession
    'GL': 0.15,
    'ZG': 0.10,
    'FR': 0.25,
    'SO': 0.15,
    'BS': 0.20,
    'BL': 0.20,
    'SH': 0.20,
    'AR': 0.15,
    'AI': 0.12,
    'SG': 0.15,
    'GR': 0.20,
    'AG': 0.15,
    'TG': 0.15,
    'TI': 0.20,
    'VD': 0.25,
    'VS': 0.25,
    'NE': 0.20,
    'GE': 0.24,
    'JU': 0.20,
  };

  // ════════════════════════════════════════════════════════════
  //  1. COMPARE FISCAL MARIAGE
  // ════════════════════════════════════════════════════════════

  /// Compare tax burden: married vs two single persons.
  ///
  /// Returns a map with tax amounts for both scenarios, the
  /// difference (penalty or bonus), and deduction details.
  static Map<String, dynamic> compareFiscalMariage({
    required double revenu1,
    required double revenu2,
    required String canton,
    int nbEnfants = 0,
  }) {
    final baseRate = _effectiveRates100kSingle[canton] ?? 0.13;

    // ── Two singles ──────────────────────────────────
    final taxSingle1 = _estimateSingleTax(revenu1, baseRate);
    final taxSingle2 = _estimateSingleTax(revenu2, baseRate);
    final totalCelibataires = taxSingle1 + taxSingle2;

    // ── Married couple ──────────────────────────────
    final revenuCumule = revenu1 + revenu2;

    // Deductions for married
    double deductions = deductionMarie;
    deductions += deductionAssuranceMarie;
    deductions += nbEnfants * deductionParEnfant;

    // Double-earner deduction if both earn
    final hasDoubleRevenu = revenu1 > 0 && revenu2 > 0;
    if (hasDoubleRevenu) {
      deductions += deductionDoubleRevenu;
    }

    final revenuImposableMarie = max(0.0, revenuCumule - deductions);

    // Progressive married rate (higher combined income = higher bracket)
    final marriedRate = _marriedEffectiveRate(revenuImposableMarie, baseRate);
    final taxMarie = revenuImposableMarie * marriedRate;

    // ── Difference ──────────────────────────────────
    final difference = taxMarie - totalCelibataires;
    final isPenalite = difference > 0;

    return {
      'revenu1': revenu1,
      'revenu2': revenu2,
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'nbEnfants': nbEnfants,
      'totalCelibataires': totalCelibataires,
      'taxSingle1': taxSingle1,
      'taxSingle2': taxSingle2,
      'totalMarie': taxMarie,
      'revenuImposableMarie': revenuImposableMarie,
      'difference': difference,
      'isPenalite': isPenalite,
      'deductionMarie': deductionMarie,
      'deductionAssurance': deductionAssuranceMarie,
      'deductionDoubleRevenu': hasDoubleRevenu ? deductionDoubleRevenu : 0.0,
      'deductionEnfants': nbEnfants * deductionParEnfant,
      'totalDeductions': deductions,
    };
  }

  static double _estimateSingleTax(double revenu, double baseRate) {
    if (revenu <= 0) return 0.0;
    final deductions = deductionAssuranceCelibataire;
    final imposable = max(0.0, revenu - deductions);
    final adj = _incomeAdjustment(imposable);
    return imposable * baseRate * adj;
  }

  static double _marriedEffectiveRate(double revenuImposable, double baseRate) {
    // Progressive adjustment for married (splitting-like effect)
    final adj = _incomeAdjustment(revenuImposable);
    // Married couples benefit from a ~0.92 factor (splitting effect)
    return baseRate * adj * 0.92;
  }

  static double _incomeAdjustment(double income) {
    if (income <= 50000) return 0.75;
    if (income <= 80000) return 0.75 + (income - 50000) / 30000 * 0.15;
    if (income <= 100000) return 0.90 + (income - 80000) / 20000 * 0.10;
    if (income <= 150000) return 1.00 + (income - 100000) / 50000 * 0.10;
    if (income <= 200000) return 1.10 + (income - 150000) / 50000 * 0.08;
    if (income <= 300000) return 1.18 + (income - 200000) / 100000 * 0.07;
    return 1.25 + (income - 300000) / 200000 * 0.07;
  }

  // ════════════════════════════════════════════════════════════
  //  2. SIMULATE CONGE PARENTAL
  // ════════════════════════════════════════════════════════════

  /// Calculate APG for parental leave.
  ///
  /// Returns: daily APG, total APG, duration, salary loss.
  static Map<String, dynamic> simulateCongeParental({
    required double salaireMensuel,
    required bool isMother,
  }) {
    final salaireAnnuel = salaireMensuel * 12;
    // APG method uses 360 days (30 days × 12 months) — LAPG art. 16e
    final salaireJournalier = salaireAnnuel / 360;

    // APG = 80% of salary, capped at CHF 220/day
    final apgJournalier = min(salaireJournalier * apgReplacementRate, apgDailyMax);

    final dureeSemaines = isMother ? apgMaternityWeeks : apgPaternityWeeks;
    // LAPG art. 16i: 14 indemnites journalieres pour le conge paternite
    final joursIndemnises = isMother ? apgMaternityDays : 14;
    final dureeJours = joursIndemnises;

    final totalApg = apgJournalier * joursIndemnises;

    // What you would have earned during the same period
    final salairePendant = salaireMensuel * (dureeSemaines / 4.33);
    final perteSalaire = max(0.0, salairePendant - totalApg);

    final isCapped = salaireJournalier * apgReplacementRate > apgDailyMax;
    final plafondMensuel = apgDailyMax * 30;

    return {
      'isMother': isMother,
      'salaireMensuel': salaireMensuel,
      'salaireJournalier': salaireJournalier,
      'apgJournalier': apgJournalier,
      'dureeSemaines': dureeSemaines,
      'dureeJours': dureeJours,
      'joursIndemnises': joursIndemnises,
      'totalApg': totalApg,
      'salairePendant': salairePendant,
      'perteSalaire': perteSalaire,
      'isCapped': isCapped,
      'plafondMensuel': plafondMensuel,
      'type': isMother ? 'Maternite' : 'Paternite',
    };
  }

  // ════════════════════════════════════════════════════════════
  //  3. ESTIMATE ALLOCATIONS
  // ════════════════════════════════════════════════════════════

  /// Estimate family allowances for a canton.
  static Map<String, dynamic> estimateAllocations({
    required String canton,
    int nbEnfants = 1,
  }) {
    final mensuelParEnfant = allocationsMensuelles[canton] ?? 200.0;
    final mensuelTotal = mensuelParEnfant * nbEnfants;
    final annuelTotal = mensuelTotal * 12;

    // Ranking
    final sorted = allocationsMensuelles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = sorted.indexWhere((e) => e.key == canton) + 1;

    // Best and worst
    final best = sorted.first;
    final worst = sorted.last;
    final differenceVsBest = (best.value - mensuelParEnfant) * 12 * nbEnfants;

    return {
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'nbEnfants': nbEnfants,
      'mensuelParEnfant': mensuelParEnfant,
      'mensuelTotal': mensuelTotal,
      'annuelTotal': annuelTotal,
      'rank': rank,
      'bestCanton': best.key,
      'bestCantonNom': cantonNames[best.key] ?? best.key,
      'bestMontant': best.value,
      'worstCanton': worst.key,
      'worstCantonNom': cantonNames[worst.key] ?? worst.key,
      'worstMontant': worst.value,
      'differenceVsBest': differenceVsBest,
    };
  }

  /// Get all cantons sorted by allocation amount (descending).
  static List<Map<String, dynamic>> getAllocationsRanking({
    int nbEnfants = 1,
  }) {
    final sorted = allocationsMensuelles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.asMap().entries.map((entry) {
      final idx = entry.key;
      final e = entry.value;
      return {
        'canton': e.key,
        'cantonNom': cantonNames[e.key] ?? e.key,
        'mensuelParEnfant': e.value,
        'mensuelTotal': e.value * nbEnfants,
        'annuelTotal': e.value * nbEnfants * 12,
        'rank': idx + 1,
      };
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  4. CALCULATE IMPACT FISCAL ENFANT
  // ════════════════════════════════════════════════════════════

  /// Calculate the tax savings from having children.
  static Map<String, dynamic> calculateImpactFiscalEnfant({
    required double revenuImposable,
    required double tauxMarginal,
    int nbEnfants = 1,
    double fraisGarde = 0,
  }) {
    // Deduction for children
    final deductionEnfants = deductionParEnfant * nbEnfants;

    // Childcare deduction (capped)
    final deductionGarde = min(fraisGarde * 12, deductionGardeMax) * nbEnfants;

    // Total deduction
    final totalDeduction = deductionEnfants + deductionGarde;

    // Tax savings (deduction * marginal rate)
    final rate = tauxMarginal > 0 ? tauxMarginal : 0.15;
    final economieFiscale = totalDeduction * rate;

    return {
      'nbEnfants': nbEnfants,
      'deductionEnfants': deductionEnfants,
      'fraisGardeMensuel': fraisGarde,
      'deductionGarde': deductionGarde,
      'totalDeduction': totalDeduction,
      'tauxMarginal': rate,
      'economieFiscale': economieFiscale,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  5. COMPARE MARIAGE VS CONCUBINAGE
  // ════════════════════════════════════════════════════════════

  /// Full comparison: marriage vs cohabitation.
  static Map<String, dynamic> compareMariageVsConcubinage({
    required double revenu1,
    required double revenu2,
    required String canton,
    int nbEnfants = 0,
    double patrimoine = 0,
  }) {
    // Fiscal comparison
    final fiscal = compareFiscalMariage(
      revenu1: revenu1,
      revenu2: revenu2,
      canton: canton,
      nbEnfants: nbEnfants,
    );

    // Inheritance comparison
    final inheritance = estimateInheritanceTax(
      patrimoine: patrimoine,
      canton: canton,
      isMarried: false,
    );
    final inheritanceMarried = estimateInheritanceTax(
      patrimoine: patrimoine,
      canton: canton,
      isMarried: true,
    );

    // AVS survivor
    final avsSurvivorRente = avsMaxRenteMensuelle * avsSurvivorFactor;

    // Score comparison
    int scoreMariage = 0;
    int scoreConcubinage = 0;

    // Tax advantage
    if ((fiscal['difference'] as double) < 0) {
      scoreMariage++;
    } else if ((fiscal['difference'] as double) > 0) {
      scoreConcubinage++;
    }

    // AVS survivor: married always wins
    scoreMariage++;

    // LPP survivor: married = automatic, concubinage = requires clause
    scoreMariage++;

    // Inheritance: married = exonerated
    scoreMariage++;

    // Pension alimentaire: married = protected
    scoreMariage++;

    // Simplicity of separation: concubinage wins
    scoreConcubinage++;

    return {
      'fiscal': fiscal,
      'inheritance': inheritance,
      'inheritanceMarried': inheritanceMarried,
      'avsSurvivorRente': avsSurvivorRente,
      'lppSurvivorFactor': lppSurvivorFactor,
      'scoreMariage': scoreMariage,
      'scoreConcubinage': scoreConcubinage,
      'fiscalAdvantage': (fiscal['difference'] as double) < 0 ? 'mariage' : 'concubinage',
    };
  }

  // ════════════════════════════════════════════════════════════
  //  6. ESTIMATE INHERITANCE TAX
  // ════════════════════════════════════════════════════════════

  /// Estimate inheritance tax for married vs non-married.
  static Map<String, dynamic> estimateInheritanceTax({
    required double patrimoine,
    required String canton,
    required bool isMarried,
  }) {
    if (isMarried) {
      // Married partners are tax-exempt in all cantons
      return {
        'patrimoine': patrimoine,
        'canton': canton,
        'isMarried': true,
        'taux': 0.0,
        'impot': 0.0,
        'netHerite': patrimoine,
      };
    }

    final taux = _inheritanceTaxRatesNonMarie[canton] ?? 0.08;
    final impot = patrimoine * taux;
    final netHerite = patrimoine - impot;

    return {
      'patrimoine': patrimoine,
      'canton': canton,
      'isMarried': false,
      'taux': taux,
      'impot': impot,
      'netHerite': netHerite,
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
}
