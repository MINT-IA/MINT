import 'dart:math' as math;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// Arbitrage engine — pure static functions for rente vs capital and
/// annual allocation comparisons.
///
/// Sprint S32 — Arbitrage Phase 1.
///
/// MUST use RetirementTaxCalculator for all tax calculations.
/// MUST use constants from social_insurance.dart.
/// NEVER rank options — side-by-side only.
///
/// Legal basis: LPP art. 14 (taux conversion), LIFD art. 22 (rente taxation),
/// LIFD art. 38 (capital withdrawal), OPP3 art. 7 (3a limits).
class ArbitrageEngine {
  ArbitrageEngine._();

  // ════════════════════════════════════════════════════════════
  //  1. RENTE VS CAPITAL
  // ════════════════════════════════════════════════════════════

  /// Compare full rente, full capital, and mixed (obligatoire rente +
  /// surobligatoire capital) strategies over [horizon] years.
  ///
  /// [capitalLppTotal] Total LPP balance at retirement.
  /// [capitalObligatoire] Obligatory LPP portion.
  /// [capitalSurobligatoire] Supra-obligatory LPP portion.
  /// [renteAnnuelleProposee] Annual rente proposed by the caisse de pension.
  /// [canton] Canton code for tax calculation.
  /// [tauxRetrait] Safe withdrawal rate (default 4%).
  /// [rendementCapital] Expected return on invested capital (default 3%).
  /// [inflation] Expected inflation rate (default 2%).
  /// [horizon] Projection horizon in years (default 25).
  static ArbitrageResult compareRenteVsCapital({
    required double capitalLppTotal,
    required double capitalObligatoire,
    required double capitalSurobligatoire,
    required double renteAnnuelleProposee,
    double tauxConversionObligatoire = 0.068,
    double tauxConversionSurobligatoire = 0.05,
    required String canton,
    int ageRetraite = 65,
    double tauxRetrait = 0.04,
    double rendementCapital = 0.03,
    double inflation = 0.02,
    int horizon = 25,
    bool isMarried = false,
  }) {
    final startYear = DateTime.now().year;

    // ── Option A: Full Rente ──
    final renteTrajectory = _buildRenteTrajectory(
      renteAnnuelle: renteAnnuelleProposee,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      isMarried: isMarried,
    );

    // ── Option B: Full Capital ──
    final capitalTrajectory = _buildCapitalTrajectory(
      capitalBrut: capitalLppTotal,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      tauxRetrait: tauxRetrait,
      rendement: rendementCapital,
      inflation: inflation,
      isMarried: isMarried,
    );

    // ── Option C: Mixed ──
    final renteMixte = capitalObligatoire * tauxConversionObligatoire;
    final mixedTrajectory = _buildMixedTrajectory(
      renteObligatoire: renteMixte,
      capitalSurobligatoire: capitalSurobligatoire,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      tauxRetrait: tauxRetrait,
      rendement: rendementCapital,
      inflation: inflation,
      isMarried: isMarried,
    );

    final optionA = TrajectoireOption(
      id: 'full_rente',
      label: '100 % Rente',
      trajectory: renteTrajectory,
      terminalValue: renteTrajectory.last.netPatrimony,
      cumulativeTaxImpact: renteTrajectory.last.cumulativeTaxDelta,
    );

    final optionB = TrajectoireOption(
      id: 'full_capital',
      label: '100 % Capital',
      trajectory: capitalTrajectory,
      terminalValue: capitalTrajectory.last.netPatrimony,
      cumulativeTaxImpact: capitalTrajectory.last.cumulativeTaxDelta,
    );

    final optionC = TrajectoireOption(
      id: 'mixed',
      label: 'Mixte (oblig. rente + surob. capital)',
      trajectory: mixedTrajectory,
      terminalValue: mixedTrajectory.last.netPatrimony,
      cumulativeTaxImpact: mixedTrajectory.last.cumulativeTaxDelta,
    );

    final options = [optionA, optionB, optionC];

    // Breakeven: year where capital cumulative cashflow exceeds rente
    final breakevenYear = _findBreakevenYear(renteTrajectory, capitalTrajectory);

    // Sensitivity: rendement +/- 1%
    final sensitivityUp = _buildCapitalTrajectory(
      capitalBrut: capitalLppTotal,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      tauxRetrait: tauxRetrait,
      rendement: rendementCapital + 0.01,
      inflation: inflation,
      isMarried: isMarried,
    );
    final sensitivityDown = _buildCapitalTrajectory(
      capitalBrut: capitalLppTotal,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      tauxRetrait: tauxRetrait,
      rendement: math.max(0, rendementCapital - 0.01),
      inflation: inflation,
      isMarried: isMarried,
    );

    final sensitivity = <String, double>{
      'rendement_plus_1': sensitivityUp.last.netPatrimony,
      'rendement_moins_1': sensitivityDown.last.netPatrimony,
    };

    // Chiffre choc: cumulative cashflow difference at horizon
    final renteCashflow = renteTrajectory.last.netPatrimony;
    final capitalCashflow = capitalTrajectory.last.netPatrimony;
    final delta = (capitalCashflow - renteCashflow).abs();
    final betterOption = capitalCashflow > renteCashflow ? 'capital' : 'rente';
    final chiffreChoc =
        'Dans ce scenario simule, l\'option $betterOption genere '
        '~${_formatChf(delta)} de patrimoine net supplementaire sur $horizon ans.';

    final displaySummary = breakevenYear != null
        ? 'Les trajectoires se croisent vers ${startYear + breakevenYear!} '
            '(age ${ageRetraite + breakevenYear!}). '
            'Avant ce point, la rente procure un revenu regulier. '
            'Apres, le capital retire peut constituer un patrimoine plus important.'
        : 'Sur l\'horizon de $horizon ans, les trajectoires ne se croisent pas. '
            'L\'ecart final est de ${_formatChf(delta)}.';

    return ArbitrageResult(
      options: options,
      breakevenYear: breakevenYear,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Rendement du capital : ${(rendementCapital * 100).toStringAsFixed(1)} % par an',
        'Taux de retrait (SWR) : ${(tauxRetrait * 100).toStringAsFixed(1)} % par an',
        'Inflation : ${(inflation * 100).toStringAsFixed(1)} % par an',
        'Horizon : $horizon ans (age ${ageRetraite + horizon})',
        'Canton : $canton',
        'Taux de conversion obligatoire : ${(tauxConversionObligatoire * 100).toStringAsFixed(1)} %',
        'Taux de conversion surobligatoire : ${(tauxConversionSurobligatoire * 100).toStringAsFixed(1)} %',
        if (isMarried) 'Splitting marie : reduction ~15 % sur impot retrait',
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'LPP art. 14 (taux de conversion)',
        'LIFD art. 22 (imposition des rentes)',
        'LIFD art. 38 (impot sur retrait en capital)',
      ],
      confidenceScore: 65.0,
      sensitivity: sensitivity,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  2. ALLOCATION ANNUELLE
  // ════════════════════════════════════════════════════════════

  /// Compare annual allocation options: 3a, rachat LPP,
  /// amortissement indirect, investissement libre.
  ///
  /// Only builds eligible options based on user profile flags.
  static ArbitrageResult compareAllocationAnnuelle({
    required double montantDisponible,
    required double tauxMarginal,
    bool a3aMaxed = false,
    double potentielRachatLpp = 0,
    bool isPropertyOwner = false,
    double tauxHypothecaire = 0.015,
    int anneesAvantRetraite = 20,
    double rendement3a = 0.02,
    double rendementLpp = 0.0125,
    double rendementMarche = 0.04,
    String canton = 'VD',
  }) {
    final startYear = DateTime.now().year;
    final options = <TrajectoireOption>[];

    // ── Option 1: Pilier 3a ──
    if (!a3aMaxed) {
      final max3a = pilier3aPlafondAvecLpp;
      final montant3a = math.min(montantDisponible, max3a);
      final trajectory3a = _buildAllocationTrajectory(
        montantAnnuel: montant3a,
        rendement: rendement3a,
        tauxMarginal: tauxMarginal,
        deductible: true,
        horizon: anneesAvantRetraite,
        startYear: startYear,
        canton: canton,
        label: '3a',
      );
      options.add(TrajectoireOption(
        id: '3a',
        label: 'Pilier 3a (max ${_formatChf(max3a)}/an)',
        trajectory: trajectory3a,
        terminalValue: trajectory3a.last.netPatrimony,
        cumulativeTaxImpact: trajectory3a.last.cumulativeTaxDelta,
      ));
    }

    // ── Option 2: Rachat LPP ──
    if (potentielRachatLpp > 0) {
      final montantRachat = math.min(montantDisponible, potentielRachatLpp);
      final anneesBlocage = 3;
      final trajectoryLpp = _buildAllocationTrajectory(
        montantAnnuel: montantRachat,
        rendement: rendementLpp,
        tauxMarginal: tauxMarginal,
        deductible: true,
        horizon: anneesAvantRetraite,
        startYear: startYear,
        canton: canton,
        label: 'rachat_lpp',
        blocageYears: anneesBlocage,
      );
      options.add(TrajectoireOption(
        id: 'rachat_lpp',
        label: 'Rachat LPP (blocage $anneesBlocage ans)',
        trajectory: trajectoryLpp,
        terminalValue: trajectoryLpp.last.netPatrimony,
        cumulativeTaxImpact: trajectoryLpp.last.cumulativeTaxDelta,
      ));
    }

    // ── Option 3: Amortissement indirect ──
    if (isPropertyOwner) {
      final trajectoryAmort = _buildAmortIndirectTrajectory(
        montantAnnuel: montantDisponible,
        tauxHypothecaire: tauxHypothecaire,
        tauxMarginal: tauxMarginal,
        horizon: anneesAvantRetraite,
        startYear: startYear,
      );
      options.add(TrajectoireOption(
        id: 'amort_indirect',
        label: 'Amortissement indirect',
        trajectory: trajectoryAmort,
        terminalValue: trajectoryAmort.last.netPatrimony,
        cumulativeTaxImpact: trajectoryAmort.last.cumulativeTaxDelta,
      ));
    }

    // ── Option 4: Investissement libre (always available) ──
    final trajectoryLibre = _buildAllocationTrajectory(
      montantAnnuel: montantDisponible,
      rendement: rendementMarche,
      tauxMarginal: tauxMarginal,
      deductible: false,
      horizon: anneesAvantRetraite,
      startYear: startYear,
      canton: canton,
      label: 'invest_libre',
    );
    options.add(TrajectoireOption(
      id: 'invest_libre',
      label: 'Investissement libre',
      trajectory: trajectoryLibre,
      terminalValue: trajectoryLibre.last.netPatrimony,
      cumulativeTaxImpact: trajectoryLibre.last.cumulativeTaxDelta,
    ));

    // Find best and worst terminal values for chiffre choc
    double maxTerminal = double.negativeInfinity;
    double minTerminal = double.infinity;
    String maxLabel = '';
    String minLabel = '';
    for (final o in options) {
      if (o.terminalValue > maxTerminal) {
        maxTerminal = o.terminalValue;
        maxLabel = o.label;
      }
      if (o.terminalValue < minTerminal) {
        minTerminal = o.terminalValue;
        minLabel = o.label;
      }
    }
    final ecart = maxTerminal - minTerminal;

    final chiffreChoc =
        'Dans ce scenario simule, l\'ecart entre les options atteint '
        '${_formatChf(ecart)} sur $anneesAvantRetraite ans.';

    final displaySummary =
        'Comparaison de ${options.length} strategies pour un versement annuel '
        'de ${_formatChf(montantDisponible)} sur $anneesAvantRetraite ans.';

    // Sensitivity: rendement marche +/- 1%
    final senUp = _buildAllocationTrajectory(
      montantAnnuel: montantDisponible,
      rendement: rendementMarche + 0.01,
      tauxMarginal: tauxMarginal,
      deductible: false,
      horizon: anneesAvantRetraite,
      startYear: startYear,
      canton: canton,
      label: 'invest_libre',
    );
    final senDown = _buildAllocationTrajectory(
      montantAnnuel: montantDisponible,
      rendement: math.max(0, rendementMarche - 0.01),
      tauxMarginal: tauxMarginal,
      deductible: false,
      horizon: anneesAvantRetraite,
      startYear: startYear,
      canton: canton,
      label: 'invest_libre',
    );

    return ArbitrageResult(
      options: options,
      breakevenYear: null,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Montant disponible : ${_formatChf(montantDisponible)}/an',
        'Taux marginal d\'imposition estime : ${(tauxMarginal * 100).toStringAsFixed(0)} %',
        'Rendement 3a : ${(rendement3a * 100).toStringAsFixed(1)} %',
        'Rendement LPP : ${(rendementLpp * 100).toStringAsFixed(2)} %',
        'Rendement marche : ${(rendementMarche * 100).toStringAsFixed(1)} %',
        'Horizon : $anneesAvantRetraite ans',
        if (isPropertyOwner)
          'Taux hypothecaire : ${(tauxHypothecaire * 100).toStringAsFixed(2)} %',
        if (potentielRachatLpp > 0)
          'Potentiel de rachat LPP : ${_formatChf(potentielRachatLpp)}',
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 79b al. 3 (blocage rachat 3 ans)',
        'LIFD art. 33 (deductions)',
      ],
      confidenceScore: 60.0,
      sensitivity: {
        'rendement_marche_plus_1': senUp.last.netPatrimony,
        'rendement_marche_moins_1': senDown.last.netPatrimony,
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS — Trajectory builders
  // ════════════════════════════════════════════════════════════

  /// Build year-by-year trajectory for full rente option.
  ///
  /// Rente is taxed as income every year (LIFD art. 22).
  /// No capital patrimony — cumulative cashflow only.
  static List<YearlySnapshot> _buildRenteTrajectory({
    required double renteAnnuelle,
    required String canton,
    required int horizon,
    required int startYear,
    required bool isMarried,
  }) {
    final snapshots = <YearlySnapshot>[];
    double cumulativeCashflow = 0;
    double cumulativeTax = 0;

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: 0,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      // Annual income tax on rente
      final annualTax = RetirementTaxCalculator.estimateMonthlyIncomeTax(
            revenuAnnuelImposable: renteAnnuelle,
            canton: canton,
            etatCivil: isMarried ? 'marie' : 'celibataire',
          ) *
          12;
      final netAnnual = renteAnnuelle - annualTax;
      cumulativeCashflow += netAnnual;
      cumulativeTax += annualTax;

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: cumulativeCashflow,
        annualCashflow: netAnnual,
        cumulativeTaxDelta: cumulativeTax,
      ));
    }
    return snapshots;
  }

  /// Build year-by-year trajectory for full capital option.
  ///
  /// Capital is taxed once at withdrawal (LIFD art. 38, progressive brackets).
  /// Then invested and drawn down at SWR. SWR withdrawals are NOT taxable
  /// income — they are consumption of own patrimony.
  static List<YearlySnapshot> _buildCapitalTrajectory({
    required double capitalBrut,
    required String canton,
    required int horizon,
    required int startYear,
    required double tauxRetrait,
    required double rendement,
    required double inflation,
    required bool isMarried,
  }) {
    // One-time withdrawal tax
    final withdrawalTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: capitalBrut,
      canton: canton,
      isMarried: isMarried,
    );
    double capitalNet = capitalBrut - withdrawalTax;

    final snapshots = <YearlySnapshot>[];
    double cumulativeCashflow = 0;
    final realReturn = rendement - inflation;

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: capitalNet,
          annualCashflow: 0,
          cumulativeTaxDelta: withdrawalTax,
        ));
        continue;
      }
      // Capital grows at real return
      capitalNet *= (1 + realReturn);
      // Withdraw at SWR (not taxed — consumption of patrimony)
      final annualWithdrawal = capitalNet * tauxRetrait;
      capitalNet -= annualWithdrawal;
      cumulativeCashflow += annualWithdrawal;

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: capitalNet + cumulativeCashflow,
        annualCashflow: annualWithdrawal,
        cumulativeTaxDelta: withdrawalTax,
      ));
    }
    return snapshots;
  }

  /// Build year-by-year trajectory for mixed option:
  /// obligatoire as rente (6.8%) + surobligatoire as capital.
  static List<YearlySnapshot> _buildMixedTrajectory({
    required double renteObligatoire,
    required double capitalSurobligatoire,
    required String canton,
    required int horizon,
    required int startYear,
    required double tauxRetrait,
    required double rendement,
    required double inflation,
    required bool isMarried,
  }) {
    // Capital part: withdrawal tax on surobligatoire only
    final withdrawalTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: capitalSurobligatoire,
      canton: canton,
      isMarried: isMarried,
    );
    double capitalNet = capitalSurobligatoire - withdrawalTax;
    final realReturn = rendement - inflation;

    final snapshots = <YearlySnapshot>[];
    double cumulativeCashflow = 0;
    double cumulativeTax = withdrawalTax;

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: capitalNet,
          annualCashflow: 0,
          cumulativeTaxDelta: withdrawalTax,
        ));
        continue;
      }
      // Rente part (income tax)
      final renteTax = RetirementTaxCalculator.estimateMonthlyIncomeTax(
            revenuAnnuelImposable: renteObligatoire,
            canton: canton,
            etatCivil: isMarried ? 'marie' : 'celibataire',
          ) *
          12;
      final renteNet = renteObligatoire - renteTax;

      // Capital part grows and is drawn
      capitalNet *= (1 + realReturn);
      final capitalWithdrawal = capitalNet * tauxRetrait;
      capitalNet -= capitalWithdrawal;

      final totalCashflow = renteNet + capitalWithdrawal;
      cumulativeCashflow += totalCashflow;
      cumulativeTax += renteTax;

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: capitalNet + cumulativeCashflow,
        annualCashflow: totalCashflow,
        cumulativeTaxDelta: cumulativeTax,
      ));
    }
    return snapshots;
  }

  /// Build trajectory for a regular annual allocation (3a, rachat LPP,
  /// investissement libre).
  static List<YearlySnapshot> _buildAllocationTrajectory({
    required double montantAnnuel,
    required double rendement,
    required double tauxMarginal,
    required bool deductible,
    required int horizon,
    required int startYear,
    required String canton,
    required String label,
    int blocageYears = 0,
  }) {
    final snapshots = <YearlySnapshot>[];
    double balance = 0;
    double cumulativeTaxSaving = 0;

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: 0,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      // Add annual contribution
      balance += montantAnnuel;
      // Apply return
      balance *= (1 + rendement);

      // Tax saving from deduction
      final taxSaving = deductible ? montantAnnuel * tauxMarginal : 0.0;
      cumulativeTaxSaving += taxSaving;

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: balance + cumulativeTaxSaving,
        annualCashflow: montantAnnuel,
        cumulativeTaxDelta: -cumulativeTaxSaving, // negative = savings
      ));
    }

    // At withdrawal, deductible instruments are taxed at withdrawal
    if (deductible && snapshots.isNotEmpty) {
      final withdrawalTax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: balance,
        canton: canton,
      );
      // Adjust terminal snapshot to account for withdrawal tax
      final last = snapshots.last;
      snapshots[snapshots.length - 1] = YearlySnapshot(
        year: last.year,
        netPatrimony: (balance - withdrawalTax) + cumulativeTaxSaving,
        annualCashflow: last.annualCashflow,
        cumulativeTaxDelta: withdrawalTax - cumulativeTaxSaving,
      );
    }
    return snapshots;
  }

  /// Build trajectory for amortissement indirect.
  ///
  /// Money goes into 3a, maintaining mortgage interest deduction.
  /// At retirement, 3a capital is used to amortize the mortgage.
  static List<YearlySnapshot> _buildAmortIndirectTrajectory({
    required double montantAnnuel,
    required double tauxHypothecaire,
    required double tauxMarginal,
    required int horizon,
    required int startYear,
  }) {
    final snapshots = <YearlySnapshot>[];
    double balance3a = 0;
    double cumulativeSaving = 0;
    final rendement3a = 0.02; // Conservative 3a return

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: 0,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      // 3a contribution
      final contribution = math.min(montantAnnuel, pilier3aPlafondAvecLpp);
      balance3a += contribution;
      balance3a *= (1 + rendement3a);

      // Tax benefits: 3a deduction + maintained mortgage interest deduction
      final taxSaving3a = contribution * tauxMarginal;
      // Mortgage interest deduction maintained (not amortized directly)
      final interestDeduction = contribution * tauxHypothecaire * tauxMarginal;
      final totalSaving = taxSaving3a + interestDeduction;
      cumulativeSaving += totalSaving;

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: balance3a + cumulativeSaving,
        annualCashflow: contribution,
        cumulativeTaxDelta: -cumulativeSaving,
      ));
    }
    return snapshots;
  }

  /// Find the year where capital cumulative patrimony exceeds rente.
  /// Returns null if they never cross.
  static int? _findBreakevenYear(
    List<YearlySnapshot> renteTrajectory,
    List<YearlySnapshot> capitalTrajectory,
  ) {
    final maxLen =
        math.min(renteTrajectory.length, capitalTrajectory.length);
    // Check if capital starts below rente (typical case)
    bool capitalStartsBelow = false;
    for (int i = 1; i < maxLen; i++) {
      if (capitalTrajectory[i].netPatrimony <
          renteTrajectory[i].netPatrimony) {
        capitalStartsBelow = true;
        break;
      }
    }
    if (!capitalStartsBelow) return null;

    for (int i = 1; i < maxLen; i++) {
      if (capitalTrajectory[i].netPatrimony >=
          renteTrajectory[i].netPatrimony) {
        return i;
      }
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ════════════════════════════════════════════════════════════

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}
