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
  //  3. LOCATION VS PROPRIETE
  // ════════════════════════════════════════════════════════════

  /// Compare renting + investing surplus vs buying property.
  ///
  /// Option A: Rent, invest the down payment at market return.
  /// Option B: Buy with 80% mortgage, 1% amortization/year,
  ///   1% maintenance/year, valeur locative taxable.
  ///
  /// Legal basis: FINMA affordability (5% theoretical rate),
  ///   LIFD art. 21 (valeur locative), LIFD art. 33 (interest deduction).
  static ArbitrageResult compareLocationVsPropriete({
    required double capitalDisponible,
    required double loyerMensuelActuel,
    required double prixBien,
    String canton = 'VD',
    int horizonAnnees = 20,
    double rendementMarche = 0.04,
    double appreciationImmo = 0.015,
    double tauxHypotheque = 0.02,
    double tauxEntretien = 0.01,
    bool isMarried = false,
  }) {
    final startYear = DateTime.now().year;

    // ── Option A: Rent + Invest ──
    final loyerAnnuel = loyerMensuelActuel * 12;
    double investCapital = capitalDisponible;
    final rentSnapshots = <YearlySnapshot>[];
    double rentCumulCashflow = 0;

    for (int y = 0; y <= horizonAnnees; y++) {
      if (y == 0) {
        rentSnapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: investCapital,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      // Capital grows at market return
      investCapital *= (1 + rendementMarche);
      // Pay rent out of pocket (not from invested capital)
      rentCumulCashflow -= loyerAnnuel;

      rentSnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: investCapital + rentCumulCashflow,
        annualCashflow: -loyerAnnuel,
        cumulativeTaxDelta: 0,
      ));
    }

    // ── Option B: Buy ──
    final fondsPropresPct = capitalDisponible / prixBien;
    final fondsPropres = capitalDisponible.clamp(0.0, prixBien);
    double hypotheque = prixBien - fondsPropres;
    double valeurBien = prixBien;
    final buySnapshots = <YearlySnapshot>[];
    double buyCumulCost = 0;

    for (int y = 0; y <= horizonAnnees; y++) {
      if (y == 0) {
        // Net patrimony = property value - mortgage
        buySnapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: valeurBien - hypotheque,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      // Property appreciates
      valeurBien *= (1 + appreciationImmo);

      // Annual costs
      final interets = hypotheque * tauxHypotheque;
      final amortissement = prixBien * 0.01; // 1% of initial price/year
      final entretien = prixBien * tauxEntretien;

      // Valeur locative = ~3.5% of property value (Swiss average)
      final valeurLocative = valeurBien * 0.035;
      // Tax impact: valeur locative as income minus interest deduction
      final netTaxableIncome = valeurLocative - interets;
      final taxImpact = netTaxableIncome > 0
          ? RetirementTaxCalculator.estimateMonthlyIncomeTax(
                revenuAnnuelImposable: netTaxableIncome,
                canton: canton,
                etatCivil: isMarried ? 'marie' : 'celibataire',
              ) *
              12
          : 0.0;

      final totalAnnualCost = interets + amortissement + entretien + taxImpact;
      buyCumulCost += totalAnnualCost;

      // Reduce mortgage by amortization
      hypotheque = math.max(0, hypotheque - amortissement);

      buySnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: valeurBien - hypotheque - buyCumulCost,
        annualCashflow: -totalAnnualCost,
        cumulativeTaxDelta: taxImpact * y,
      ));
    }

    final optionA = TrajectoireOption(
      id: 'location',
      label: 'Louer + investir',
      trajectory: rentSnapshots,
      terminalValue: rentSnapshots.last.netPatrimony,
      cumulativeTaxImpact: 0,
    );

    final optionB = TrajectoireOption(
      id: 'propriete',
      label: 'Acheter',
      trajectory: buySnapshots,
      terminalValue: buySnapshots.last.netPatrimony,
      cumulativeTaxImpact: buySnapshots.last.cumulativeTaxDelta,
    );

    final options = [optionA, optionB];
    final breakevenYear = _findBreakevenYear(rentSnapshots, buySnapshots);

    final delta =
        (optionA.terminalValue - optionB.terminalValue).abs();
    final betterLabel =
        optionA.terminalValue > optionB.terminalValue ? 'louer' : 'acheter';
    final chiffreChoc =
        'Dans ce scenario simule, $betterLabel genere '
        '~${_formatChf(delta)} de patrimoine net supplementaire sur '
        '$horizonAnnees ans.';

    // FINMA affordability check
    final alertes = <String>[];
    final chargesTheorique = prixBien * 0.05 + prixBien * 0.01 + prixBien * 0.01;
    // We can't know gross income here, but flag the theoretical charge
    alertes.add(
      'Charge theorique FINMA : ${_formatChf(chargesTheorique)}/an '
      '(taux theorique 5 % + amortissement 1 % + entretien 1 %). '
      'Verifie que cela ne depasse pas 1/3 de ton revenu brut.',
    );

    final displaySummary = breakevenYear != null
        ? 'Les trajectoires se croisent vers ${startYear + breakevenYear!}. '
            'Avant ce point, une option domine ; apres, l\'autre prend le relais.'
        : 'Sur l\'horizon de $horizonAnnees ans, les trajectoires ne se croisent pas. '
            'L\'ecart final est de ${_formatChf(delta)}.';

    // Sensitivity
    final senUp = _buildLocationInvestTrajectory(
      capital: capitalDisponible,
      loyerAnnuel: loyerAnnuel,
      rendement: rendementMarche + 0.01,
      horizon: horizonAnnees,
      startYear: startYear,
    );
    final senDown = _buildLocationInvestTrajectory(
      capital: capitalDisponible,
      loyerAnnuel: loyerAnnuel,
      rendement: math.max(0, rendementMarche - 0.01),
      horizon: horizonAnnees,
      startYear: startYear,
    );

    return ArbitrageResult(
      options: options,
      breakevenYear: breakevenYear,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Rendement marche : ${(rendementMarche * 100).toStringAsFixed(1)} % par an',
        'Appreciation immobiliere : ${(appreciationImmo * 100).toStringAsFixed(1)} % par an',
        'Taux hypothecaire : ${(tauxHypotheque * 100).toStringAsFixed(1)} %',
        'Entretien : ${(tauxEntretien * 100).toStringAsFixed(1)} % du prix par an',
        'Horizon : $horizonAnnees ans',
        'Canton : $canton',
        'Fonds propres : ${(fondsPropresPct * 100).toStringAsFixed(0)} %',
        if (isMarried) 'Splitting marie',
        ...alertes,
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'FINMA (Tragbarkeitsrechnung, taux theorique 5 %)',
        'LIFD art. 21 (valeur locative)',
        'LIFD art. 33 (deduction des interets hypothecaires)',
      ],
      confidenceScore: 55.0,
      sensitivity: {
        'rendement_marche_plus_1': senUp.last.netPatrimony,
        'rendement_marche_moins_1': senDown.last.netPatrimony,
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  4. RACHAT LPP VS INVESTISSEMENT LIBRE
  // ════════════════════════════════════════════════════════════

  /// Compare LPP buyback (tax deduction + caisse growth + conversion)
  /// vs free market investment (no deduction, market growth, wealth tax).
  ///
  /// Legal basis: LPP art. 79b (rachat), LIFD art. 33 (deduction),
  ///   LPP art. 14 (taux conversion), LIFD art. 38 (retrait capital).
  static ArbitrageResult compareRachatVsMarche({
    required double montant,
    required double tauxMarginal,
    int anneesAvantRetraite = 20,
    double rendementLpp = 0.0125,
    double rendementMarche = 0.04,
    double tauxConversion = 0.068,
    String canton = 'VD',
    bool isMarried = false,
  }) {
    final startYear = DateTime.now().year;

    // ── Option A: LPP Buyback ──
    final taxSavingRachat = montant * tauxMarginal;
    double balanceLpp = montant;
    final rachatSnapshots = <YearlySnapshot>[];

    for (int y = 0; y <= anneesAvantRetraite; y++) {
      if (y == 0) {
        rachatSnapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: montant + taxSavingRachat,
          annualCashflow: 0,
          cumulativeTaxDelta: -taxSavingRachat,
        ));
        continue;
      }
      balanceLpp *= (1 + rendementLpp);
      rachatSnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: balanceLpp + taxSavingRachat,
        annualCashflow: 0,
        cumulativeTaxDelta: -taxSavingRachat,
      ));
    }

    // At retirement: convert to rente or withdraw as capital
    // Show both: net capital value after withdrawal tax
    final withdrawalTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: balanceLpp,
      canton: canton,
      isMarried: isMarried,
    );
    final netCapitalLpp = balanceLpp - withdrawalTax + taxSavingRachat;

    // Adjust terminal snapshot
    rachatSnapshots[rachatSnapshots.length - 1] = YearlySnapshot(
      year: startYear + anneesAvantRetraite,
      netPatrimony: netCapitalLpp,
      annualCashflow: 0,
      cumulativeTaxDelta: withdrawalTax - taxSavingRachat,
    );

    // ── Option B: Free Market ──
    double balanceMarche = montant;
    final marcheSnapshots = <YearlySnapshot>[];

    for (int y = 0; y <= anneesAvantRetraite; y++) {
      if (y == 0) {
        marcheSnapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: montant,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      balanceMarche *= (1 + rendementMarche);
      // Wealth tax ~0.3% per year on average
      final wealthTax = balanceMarche * 0.003;
      balanceMarche -= wealthTax;

      marcheSnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: balanceMarche,
        annualCashflow: 0,
        cumulativeTaxDelta: wealthTax * y,
      ));
    }

    final optionA = TrajectoireOption(
      id: 'rachat_lpp',
      label: 'Rachat LPP',
      trajectory: rachatSnapshots,
      terminalValue: netCapitalLpp,
      cumulativeTaxImpact: withdrawalTax - taxSavingRachat,
    );

    final optionB = TrajectoireOption(
      id: 'invest_libre',
      label: 'Investissement libre',
      trajectory: marcheSnapshots,
      terminalValue: balanceMarche,
      cumulativeTaxImpact: marcheSnapshots.last.cumulativeTaxDelta,
    );

    final options = [optionA, optionB];
    final breakevenYear = _findBreakevenYear(rachatSnapshots, marcheSnapshots);

    final delta = (netCapitalLpp - balanceMarche).abs();
    final chiffreChoc =
        'Economie d\'impot au rachat : ${_formatChf(taxSavingRachat)}. '
        'Ecart final simule : ${_formatChf(delta)} sur $anneesAvantRetraite ans.';

    final displaySummary =
        'Le rachat LPP offre une deduction fiscale immediate de '
        '${_formatChf(taxSavingRachat)}, mais le capital est bloque (LPP art. 79b al. 3). '
        'L\'investissement libre est accessible a tout moment.';

    // Sensitivity
    final senUpLpp = montant * math.pow(1 + rendementLpp + 0.005, anneesAvantRetraite);
    final senDownLpp = montant * math.pow(1 + math.max(0, rendementLpp - 0.005), anneesAvantRetraite);

    return ArbitrageResult(
      options: options,
      breakevenYear: breakevenYear,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Montant : ${_formatChf(montant)}',
        'Taux marginal : ${(tauxMarginal * 100).toStringAsFixed(0)} %',
        'Rendement LPP : ${(rendementLpp * 100).toStringAsFixed(2)} %',
        'Rendement marche : ${(rendementMarche * 100).toStringAsFixed(1)} %',
        'Taux de conversion : ${(tauxConversion * 100).toStringAsFixed(1)} %',
        'Horizon : $anneesAvantRetraite ans',
        'Canton : $canton',
        'Blocage : 3 ans apres rachat (LPP art. 79b al. 3)',
        if (isMarried) 'Splitting marie',
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'LPP art. 79b (rachat)',
        'LPP art. 79b al. 3 (blocage 3 ans)',
        'LPP art. 14 (taux de conversion)',
        'LIFD art. 33 (deduction rachat)',
        'LIFD art. 38 (impot retrait capital)',
      ],
      confidenceScore: 60.0,
      sensitivity: {
        'rendement_lpp_plus_0_5': senUpLpp + taxSavingRachat,
        'rendement_lpp_moins_0_5': senDownLpp + taxSavingRachat,
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  5. CALENDRIER DE RETRAITS
  // ════════════════════════════════════════════════════════════

  /// Compare withdrawing all retirement assets in the same year
  /// vs staggering withdrawals over multiple years.
  ///
  /// MUST use RetirementTaxCalculator.capitalWithdrawalTax() for each
  /// withdrawal to correctly apply progressive brackets.
  ///
  /// Legal basis: LIFD art. 38 (progressive capital withdrawal tax).
  static ArbitrageResult compareCalendrierRetraits({
    required List<RetirementAsset> assets,
    int ageRetraite = 65,
    String canton = 'VD',
    bool isMarried = false,
  }) {
    if (assets.isEmpty) {
      return ArbitrageResult(
        options: [],
        breakevenYear: null,
        chiffreChoc: 'Ajoute au moins un avoir pour voir la comparaison.',
        displaySummary: '',
        hypotheses: [],
        disclaimer:
            'Outil educatif — ne constitue pas un conseil financier (LSFin).',
        sources: ['LIFD art. 38 (impot sur retrait en capital)'],
        confidenceScore: 0,
        sensitivity: {},
      );
    }

    final totalCapital = assets.fold(0.0, (sum, a) => sum + a.amount);
    final startYear = DateTime.now().year;

    // ── Option A: Tout en une fois (at retirement age) ──
    final taxToutEnUn = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: totalCapital,
      canton: canton,
      isMarried: isMarried,
    );
    final netToutEnUn = totalCapital - taxToutEnUn;

    // Build simple 2-point trajectory
    final toutEnUnSnapshots = [
      YearlySnapshot(
        year: startYear,
        netPatrimony: 0,
        annualCashflow: 0,
        cumulativeTaxDelta: 0,
      ),
      YearlySnapshot(
        year: startYear + 1,
        netPatrimony: netToutEnUn,
        annualCashflow: netToutEnUn,
        cumulativeTaxDelta: taxToutEnUn,
      ),
    ];

    // ── Option B: Etale sur plusieurs annees ──
    // Sort assets by earliest withdrawal age (ascending)
    final sortedAssets = List<RetirementAsset>.from(assets)
      ..sort((a, b) => a.earliestWithdrawalAge.compareTo(b.earliestWithdrawalAge));

    double totalTaxEtale = 0;
    final withdrawalPlan = <({String type, double amount, int age, double tax})>[];

    for (final asset in sortedAssets) {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: asset.amount,
        canton: canton,
        isMarried: isMarried,
      );
      totalTaxEtale += tax;
      withdrawalPlan.add((
        type: asset.type,
        amount: asset.amount,
        age: asset.earliestWithdrawalAge,
        tax: tax,
      ));
    }

    final netEtale = totalCapital - totalTaxEtale;

    // Build trajectory for staggered
    // Determine the span from earliest to latest withdrawal age
    final earliestAge = sortedAssets.first.earliestWithdrawalAge;
    final latestAge = ageRetraite;
    final spanYears = (latestAge - earliestAge).clamp(1, 20);

    final etaleSnapshots = <YearlySnapshot>[];
    double cumulativeNet = 0;
    double cumulativeTax = 0;

    etaleSnapshots.add(YearlySnapshot(
      year: startYear,
      netPatrimony: 0,
      annualCashflow: 0,
      cumulativeTaxDelta: 0,
    ));

    for (int y = 1; y <= spanYears + 1; y++) {
      final currentAge = earliestAge + y - 1;
      double yearCashflow = 0;
      double yearTax = 0;

      for (final w in withdrawalPlan) {
        if (w.age == currentAge) {
          yearCashflow += w.amount - w.tax;
          yearTax += w.tax;
        }
      }

      cumulativeNet += yearCashflow;
      cumulativeTax += yearTax;

      etaleSnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: cumulativeNet,
        annualCashflow: yearCashflow,
        cumulativeTaxDelta: cumulativeTax,
      ));
    }

    final optionA = TrajectoireOption(
      id: 'tout_en_un',
      label: 'Tout en une fois',
      trajectory: toutEnUnSnapshots,
      terminalValue: netToutEnUn,
      cumulativeTaxImpact: taxToutEnUn,
    );

    final optionB = TrajectoireOption(
      id: 'etale',
      label: 'Etale sur plusieurs annees',
      trajectory: etaleSnapshots,
      terminalValue: netEtale,
      cumulativeTaxImpact: totalTaxEtale,
    );

    final options = [optionA, optionB];
    final taxSaved = taxToutEnUn - totalTaxEtale;

    final chiffreChoc = taxSaved > 0
        ? 'Tu economiserais ~${_formatChf(taxSaved)} d\'impot en etalant tes retraits.'
        : 'Dans ce cas, l\'ecart d\'impot est de ${_formatChf(taxSaved.abs())}.';

    final displaySummary =
        'Retrait total : ${_formatChf(totalCapital)}. '
        'Impot "tout en un" : ${_formatChf(taxToutEnUn)} vs '
        'impot etale : ${_formatChf(totalTaxEtale)}.';

    final withdrawalDetails = withdrawalPlan
        .map((w) => '${w.type.toUpperCase()} : ${_formatChf(w.amount)} a ${w.age} ans '
            '(impot : ${_formatChf(w.tax)})')
        .toList();

    return ArbitrageResult(
      options: options,
      breakevenYear: null,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Capital total : ${_formatChf(totalCapital)}',
        'Canton : $canton',
        'Age de retraite : $ageRetraite',
        if (isMarried) 'Splitting marie',
        ...withdrawalDetails,
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'L\'impot effectif depend des circonstances individuelles.',
      sources: [
        'LIFD art. 38 (impot progressif sur retrait en capital)',
        'Legislations fiscales cantonales',
      ],
      confidenceScore: 70.0,
      sensitivity: {},
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

  /// Build a simplified location + invest trajectory (for sensitivity analysis).
  static List<YearlySnapshot> _buildLocationInvestTrajectory({
    required double capital,
    required double loyerAnnuel,
    required double rendement,
    required int horizon,
    required int startYear,
  }) {
    final snapshots = <YearlySnapshot>[];
    double investCapital = capital;
    double cumulCashflow = 0;

    for (int y = 0; y <= horizon; y++) {
      if (y == 0) {
        snapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: investCapital,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      investCapital *= (1 + rendement);
      cumulCashflow -= loyerAnnuel;
      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: investCapital + cumulCashflow,
        annualCashflow: -loyerAnnuel,
        cumulativeTaxDelta: 0,
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
