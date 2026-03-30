import 'dart:math' as math;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/housing_cost_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

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

  /// Compute dynamic confidence for an arbitrage result based on data sources.
  ///
  /// [inputKeys] The input field names used in this arbitrage.
  /// [dataSources] Data quality per field (from CoachProfile.dataSources).
  /// Returns 50 in standalone mode (no profile), 30-95 otherwise.
  static double _computeArbitrageConfidence(
    List<String> inputKeys,
    Map<String, ProfileDataSource>? dataSources,
  ) {
    if (dataSources == null || dataSources.isEmpty) return 50.0;
    int known = 0;
    final total = inputKeys.length;
    if (total == 0) return 50.0;
    for (final key in inputKeys) {
      if (dataSources[key] == ProfileDataSource.certificate ||
          dataSources[key] == ProfileDataSource.openBanking) {
        known += 2;
      } else if (dataSources[key] == ProfileDataSource.userInput ||
          dataSources[key] == ProfileDataSource.crossValidated) {
        known += 1;
      }
    }
    return (known / (total * 2) * 100).clamp(30, 95);
  }

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
    double tauxConversionObligatoire = lppTauxConversionMinDecimal,
    double tauxConversionSurobligatoire = 0.05,
    required String canton,
    int ageRetraite = avsAgeReferenceHomme,
    double tauxRetrait = 0.04,
    double rendementCapital = 0.03,
    double inflation = 0.02,
    int horizon = 30,
    bool isMarried = false,
    Map<String, ProfileDataSource>? dataSources,
    // ── Projection params (estimate mode) ──
    int? currentAge,
    double? grossAnnualSalary,
    double? caisseReturn,
    S? l,
  }) {
    final startYear = DateTime.now().year;

    // ── Project capital if current age provided (estimate mode) ──
    double effectiveCapitalOblig = capitalObligatoire;
    double effectiveCapitalSurob = capitalSurobligatoire;
    double effectiveCapitalTotal = capitalLppTotal;
    double effectiveRente = renteAnnuelleProposee;
    bool isProjected = false;

    if (currentAge != null &&
        currentAge < ageRetraite &&
        grossAnnualSalary != null &&
        grossAnnualSalary > 0) {
      final effectiveCaisseReturn = caisseReturn ?? 0.015;
      // Project obligatoire
      final projectedRenteOblig = LppCalculator.projectToRetirement(
        currentBalance: capitalObligatoire,
        currentAge: currentAge,
        retirementAge: ageRetraite,
        grossAnnualSalary: grossAnnualSalary,
        caisseReturn: effectiveCaisseReturn,
        conversionRate: tauxConversionObligatoire,
      );
      // Project surobligatoire (no statutory bonification)
      final projectedRenteSurob = LppCalculator.projectToRetirement(
        currentBalance: capitalSurobligatoire,
        currentAge: currentAge,
        retirementAge: ageRetraite,
        grossAnnualSalary: grossAnnualSalary,
        caisseReturn: effectiveCaisseReturn,
        conversionRate: tauxConversionSurobligatoire,
        bonificationRateOverride: 0.0,
      );
      effectiveCapitalOblig = tauxConversionObligatoire > 0
          ? projectedRenteOblig / tauxConversionObligatoire
          : capitalObligatoire;
      effectiveCapitalSurob = tauxConversionSurobligatoire > 0
          ? projectedRenteSurob / tauxConversionSurobligatoire
          : capitalSurobligatoire;
      effectiveCapitalTotal = effectiveCapitalOblig + effectiveCapitalSurob;
      effectiveRente = projectedRenteOblig + projectedRenteSurob;
      isProjected = true;
    }

    // ── Option A: Full Rente ──
    final renteTrajectory = _buildRenteTrajectory(
      renteAnnuelle: effectiveRente,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      isMarried: isMarried,
      inflation: inflation,
    );

    // ── Option B: Full Capital ──
    final capitalTrajectory = _buildCapitalTrajectory(
      capitalBrut: effectiveCapitalTotal,
      canton: canton,
      horizon: horizon,
      startYear: startYear,
      tauxRetrait: tauxRetrait,
      rendement: rendementCapital,
      inflation: inflation,
      isMarried: isMarried,
    );

    // ── Option C: Mixed ──
    final renteMixte = effectiveCapitalOblig * tauxConversionObligatoire;
    final mixedTrajectory = _buildMixedTrajectory(
      renteObligatoire: renteMixte,
      capitalSurobligatoire: effectiveCapitalSurob,
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
      label: l?.arbitrageOptionFullRente ?? '100\u00a0% Rente',
      trajectory: renteTrajectory,
      terminalValue: renteTrajectory.last.netPatrimony,
      cumulativeTaxImpact: renteTrajectory.last.cumulativeTaxDelta,
    );

    final optionB = TrajectoireOption(
      id: 'full_capital',
      label: l?.arbitrageOptionFullCapital ?? '100\u00a0% Capital',
      trajectory: capitalTrajectory,
      terminalValue: capitalTrajectory.last.netPatrimony,
      cumulativeTaxImpact: capitalTrajectory.last.cumulativeTaxDelta,
    );

    final optionC = TrajectoireOption(
      id: 'mixed',
      label: l?.arbitrageOptionMixed ?? 'Mixte (oblig. rente + surob. capital)',
      trajectory: mixedTrajectory,
      terminalValue: mixedTrajectory.last.netPatrimony,
      cumulativeTaxImpact: mixedTrajectory.last.cumulativeTaxDelta,
    );

    final options = [optionA, optionB, optionC];

    // Breakeven: year where capital cumulative cashflow exceeds rente
    final breakevenYear =
        _findBreakevenYear(renteTrajectory, capitalTrajectory);

    final sensitivity = <String, double>{};
    final baseSpread = _terminalSpreadFromOptions(options);

    double spreadVariant({
      double variantTauxRetrait = 0.04,
      double variantRendement = 0.03,
      double variantTcOblig = lppTauxConversionMinDecimal,
      double variantTcSurob = 0.05,
    }) {
      final variantCapital = _buildCapitalTrajectory(
        capitalBrut: effectiveCapitalTotal,
        canton: canton,
        horizon: horizon,
        startYear: startYear,
        tauxRetrait: variantTauxRetrait,
        rendement: variantRendement,
        inflation: inflation,
        isMarried: isMarried,
      );
      final variantRenteMixte = (effectiveCapitalOblig * variantTcOblig) +
          (effectiveCapitalSurob * variantTcSurob);
      final variantMixed = _buildMixedTrajectory(
        renteObligatoire: variantRenteMixte,
        capitalSurobligatoire: effectiveCapitalSurob,
        canton: canton,
        horizon: horizon,
        startYear: startYear,
        tauxRetrait: variantTauxRetrait,
        rendement: variantRendement,
        inflation: inflation,
        isMarried: isMarried,
      );
      return _terminalSpreadFromValues([
        optionA.terminalValue,
        variantCapital.last.netPatrimony,
        variantMixed.last.netPatrimony,
      ]);
    }

    final rendementLow = math.max(0.0, rendementCapital - 0.01);
    final rendementHigh = rendementCapital + 0.01;
    final rendementSpreadLow = spreadVariant(
      variantTauxRetrait: tauxRetrait,
      variantRendement: rendementLow,
      variantTcOblig: tauxConversionObligatoire,
      variantTcSurob: tauxConversionSurobligatoire,
    );
    final rendementSpreadHigh = spreadVariant(
      variantTauxRetrait: tauxRetrait,
      variantRendement: rendementHigh,
      variantTcOblig: tauxConversionObligatoire,
      variantTcSurob: tauxConversionSurobligatoire,
    );
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_capital',
      baseValue: baseSpread,
      lowValue: rendementSpreadLow,
      highValue: rendementSpreadHigh,
      assumptionLow: rendementLow,
      assumptionHigh: rendementHigh,
    );

    final retraitLow = math.max(0.01, tauxRetrait - 0.005);
    final retraitHigh = math.min(0.08, tauxRetrait + 0.005);
    _addTornadoSensitivity(
      sensitivity,
      key: 'taux_retrait',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxRetrait: retraitLow,
        variantRendement: rendementCapital,
        variantTcOblig: tauxConversionObligatoire,
        variantTcSurob: tauxConversionSurobligatoire,
      ),
      highValue: spreadVariant(
        variantTauxRetrait: retraitHigh,
        variantRendement: rendementCapital,
        variantTcOblig: tauxConversionObligatoire,
        variantTcSurob: tauxConversionSurobligatoire,
      ),
      assumptionLow: retraitLow,
      assumptionHigh: retraitHigh,
    );

    final tcObligLow = math.max(reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal), tauxConversionObligatoire - 0.005);
    final tcObligHigh = tauxConversionObligatoire + 0.005;
    _addTornadoSensitivity(
      sensitivity,
      key: 'taux_conversion_obligatoire',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxRetrait: tauxRetrait,
        variantRendement: rendementCapital,
        variantTcOblig: tcObligLow,
        variantTcSurob: tauxConversionSurobligatoire,
      ),
      highValue: spreadVariant(
        variantTauxRetrait: tauxRetrait,
        variantRendement: rendementCapital,
        variantTcOblig: tcObligHigh,
        variantTcSurob: tauxConversionSurobligatoire,
      ),
      assumptionLow: tcObligLow,
      assumptionHigh: tcObligHigh,
    );

    final tcSurobLow = math.max(0.035, tauxConversionSurobligatoire - 0.005);
    final tcSurobHigh = math.min(0.10, tauxConversionSurobligatoire + 0.005);
    _addTornadoSensitivity(
      sensitivity,
      key: 'taux_conversion_surobligatoire',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxRetrait: tauxRetrait,
        variantRendement: rendementCapital,
        variantTcOblig: tauxConversionObligatoire,
        variantTcSurob: tcSurobLow,
      ),
      highValue: spreadVariant(
        variantTauxRetrait: tauxRetrait,
        variantRendement: rendementCapital,
        variantTcOblig: tauxConversionObligatoire,
        variantTcSurob: tcSurobHigh,
      ),
      assumptionLow: tcSurobLow,
      assumptionHigh: tcSurobHigh,
    );

    // ── Compute hero + educational card data ──

    // Rente net mensuelle (year 1, nominal)
    final renteAnnualTaxY1 = RetirementTaxCalculator.estimateMonthlyIncomeTax(
          revenuAnnuelImposable: effectiveRente,
          canton: canton,
          etatCivil: isMarried ? 'marie' : 'celibataire',
        ) *
        12;
    final renteNetAnnuelleY1 = effectiveRente - renteAnnualTaxY1;
    final renteNetMensuelle = renteNetAnnuelleY1 / 12;

    // Capital retrait mensuel (year 1, SWR-based)
    final withdrawalTaxTotal = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: effectiveCapitalTotal,
      canton: canton,
      isMarried: isMarried,
    );
    final capitalNetStart = effectiveCapitalTotal - withdrawalTaxTotal;
    // Year 1: capital grows then withdraw
    final capitalAfterReturn = capitalNetStart * (1 + rendementCapital);
    final initialWithdrawal = capitalAfterReturn * tauxRetrait;
    final capitalRetraitMensuel = initialWithdrawal / 12;

    // Capital exhaustion age
    int? capitalEpuiseAge;
    for (int i = 1; i < capitalTrajectory.length; i++) {
      // Capital trajectory netPatrimony includes cumulative cashflow,
      // so check if the remaining capital portion is <= 0.
      // We detect exhaustion when annual cashflow drops to near-zero
      // (the capital portion is drained).
      final snap = capitalTrajectory[i];
      // Extract remaining capital: netPatrimony - cumulativeCashflow
      // Since we don't track separately, use the trajectory's design:
      // when the withdrawal is capped to remaining capital and capital is 0
      if (i > 1 && snap.annualCashflow < capitalTrajectory[1].annualCashflow * 0.1) {
        capitalEpuiseAge = ageRetraite + i;
        break;
      }
    }

    // Impot cumul rente (total taxes on rente over horizon)
    final impotCumulRente = renteTrajectory.last.cumulativeTaxDelta;

    // Rente reelle an 20 (deflated)
    final renteReelleAn20 = effectiveRente / math.pow(1 + inflation, 20);

    // Rente survivant (60%, LPP art. 19)
    final renteSurvivant = isMarried ? effectiveRente * 0.6 : 0.0;

    // Chiffre choc — compare total economic value in real terms:
    // Rente: cumulative net income (no residual capital)
    final renteTotalValue = renteTrajectory.last.netPatrimony;
    // Capital: cumulative real withdrawals + remaining portfolio
    double capitalCumulativeWithdrawals = 0;
    for (final snap in capitalTrajectory) {
      capitalCumulativeWithdrawals += snap.annualCashflow;
    }
    final capitalResidual = capitalTrajectory.last.netPatrimony;
    final capitalTotalValue = capitalCumulativeWithdrawals + capitalResidual;

    final delta = (capitalTotalValue - renteTotalValue).abs();
    final betterOption =
        capitalTotalValue > renteTotalValue ? 'capital' : 'rente';

    // Income gap: what you actually receive to live on
    final incomeGap = (renteTotalValue - capitalCumulativeWithdrawals).abs();
    final moreIncome =
        renteTotalValue > capitalCumulativeWithdrawals ? 'rente' : 'capital';

    String chiffreChoc;
    if (capitalResidual > 10000 && moreIncome == 'rente') {
      // Typical case: rente gives more income, but capital preserves wealth
      chiffreChoc =
          'La rente te verse ~${chf.formatChfWithPrefix(incomeGap)} de revenu net '
          'de plus sur $horizon ans. Mais avec le capital, tu conserves '
          '~${chf.formatChfWithPrefix(capitalResidual)} de patrimoine transmissible.';
    } else {
      chiffreChoc =
          'Sur $horizon ans, l\'option $betterOption genere '
          '~${chf.formatChfWithPrefix(delta)} de valeur economique nette supplementaire.';
    }

    final displaySummary = breakevenYear != null
        ? 'Les trajectoires se croisent vers l\'age de '
            '${ageRetraite + breakevenYear} ans. '
            'Avant ce point, la rente procure un revenu regulier. '
            'Apres, le capital retire peut constituer un patrimoine plus important.'
        : 'Sur l\'horizon de $horizon ans, les trajectoires ne se croisent pas. '
            'L\'ecart de valeur totale est de ${chf.formatChfWithPrefix(delta)}.';

    return ArbitrageResult(
      options: options,
      breakevenYear: breakevenYear,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Ce que ton capital rapporte : ${(rendementCapital * 100).toStringAsFixed(1)} % par an',
        'Retrait annuel du capital : ${(tauxRetrait * 100).toStringAsFixed(1)} % par an',
        'Inflation : ${(inflation * 100).toStringAsFixed(1)} % par an',
        'Horizon : $horizon ans (age ${ageRetraite + horizon})',
        'Canton : $canton',
        'Taux de conversion obligatoire : ${(tauxConversionObligatoire * 100).toStringAsFixed(1)} %',
        'Taux de conversion surobligatoire : ${(tauxConversionSurobligatoire * 100).toStringAsFixed(1)} %',
        'Valeurs en francs d\'aujourd\'hui (pouvoir d\'achat reel)',
        if (isMarried) 'Splitting marie : reduction ~15 % sur impot retrait',
        if (isMarried) 'Rente de survivant : 60 % (LPP art. 19)',
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Les projections reposent sur des hypotheses simplifiees. '
          'Les rendements passes ne presagent pas des rendements futurs.',
      sources: [
        'LPP art. 14 (taux de conversion)',
        'LIFD art. 22 (imposition des rentes)',
        'LIFD art. 38 (impot sur retrait en capital)',
        if (isMarried) 'LPP art. 19 (rente de survivant)',
      ],
      confidenceScore: _computeArbitrageConfidence(
        ['capitalLppTotal', 'tauxConversion', 'renteAnnuelle', 'canton'],
        dataSources,
      ),
      sensitivity: sensitivity,
      // ── New hero + card fields ──
      renteNetMensuelle: renteNetMensuelle,
      capitalRetraitMensuel: capitalRetraitMensuel,
      capitalEpuiseAge: capitalEpuiseAge,
      impotCumulRente: impotCumulRente,
      impotRetraitCapital: withdrawalTaxTotal,
      renteReelleAn20: renteReelleAn20,
      renteSurvivant: renteSurvivant,
      capitalProjecte: effectiveCapitalTotal,
      isProjected: isProjected,
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
    double mortgageBalance = 0,
    int anneesAvantRetraite = 20,
    double rendement3a = 0.02,
    double rendementLpp = 0.0125,
    double rendementMarche = 0.04,
    String canton = 'ZH',
    Map<String, ProfileDataSource>? dataSources,
    S? l,
  }) {
    final startYear = DateTime.now().year;
    final options = <TrajectoireOption>[];

    // ── Option 1: Pilier 3a ──
    if (!a3aMaxed) {
      const max3a = pilier3aPlafondAvecLpp;
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
        label: 'Pilier 3a (max ${chf.formatChfWithPrefix(max3a)}/an)',
        trajectory: trajectory3a,
        terminalValue: trajectory3a.last.netPatrimony,
        cumulativeTaxImpact: trajectory3a.last.cumulativeTaxDelta,
      ));
    }

    // ── Option 2: Rachat LPP ──
    if (potentielRachatLpp > 0) {
      final montantRachat = math.min(montantDisponible, potentielRachatLpp);
      const anneesBlocage = 3;
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
        mortgageBalance: mortgageBalance,
      );
      options.add(TrajectoireOption(
        id: 'amort_indirect',
        label: l?.arbitrageOptionAmortIndirect ?? 'Amortissement indirect',
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
      label: l?.arbitrageOptionInvestLibre ?? 'Investissement libre',
      trajectory: trajectoryLibre,
      terminalValue: trajectoryLibre.last.netPatrimony,
      cumulativeTaxImpact: trajectoryLibre.last.cumulativeTaxDelta,
    ));

    // Find best and worst terminal values for chiffre choc
    double maxTerminal = double.negativeInfinity;
    double minTerminal = double.infinity;
    for (final o in options) {
      if (o.terminalValue > maxTerminal) {
        maxTerminal = o.terminalValue;
      }
      if (o.terminalValue < minTerminal) {
        minTerminal = o.terminalValue;
      }
    }
    final ecart = maxTerminal - minTerminal;

    final chiffreChoc =
        'Dans ce scenario simule, l\'ecart entre les options atteint '
        '${chf.formatChfWithPrefix(ecart)} sur $anneesAvantRetraite ans.';

    final displaySummary =
        'Comparaison de ${options.length} strategies pour un versement annuel '
        'de ${chf.formatChfWithPrefix(montantDisponible)} sur $anneesAvantRetraite ans.';

    final sensitivity = <String, double>{};
    final baseSpread = _terminalSpreadFromOptions(options);

    List<TrajectoireOption> buildVariantOptions({
      required double variantTauxMarginal,
      required double variantRendement3a,
      required double variantRendementLpp,
      required double variantRendementMarche,
      required double variantTauxHypothecaire,
    }) {
      final variantOptions = <TrajectoireOption>[];

      if (!a3aMaxed) {
        const max3a = pilier3aPlafondAvecLpp;
        final montant3a = math.min(montantDisponible, max3a);
        final trajectory3a = _buildAllocationTrajectory(
          montantAnnuel: montant3a,
          rendement: variantRendement3a,
          tauxMarginal: variantTauxMarginal,
          deductible: true,
          horizon: anneesAvantRetraite,
          startYear: startYear,
          canton: canton,
          label: '3a',
        );
        variantOptions.add(TrajectoireOption(
          id: '3a',
          label: 'Pilier 3a (max ${chf.formatChfWithPrefix(max3a)}/an)',
          trajectory: trajectory3a,
          terminalValue: trajectory3a.last.netPatrimony,
          cumulativeTaxImpact: trajectory3a.last.cumulativeTaxDelta,
        ));
      }

      if (potentielRachatLpp > 0) {
        final montantRachat = math.min(montantDisponible, potentielRachatLpp);
        final trajectoryLpp = _buildAllocationTrajectory(
          montantAnnuel: montantRachat,
          rendement: variantRendementLpp,
          tauxMarginal: variantTauxMarginal,
          deductible: true,
          horizon: anneesAvantRetraite,
          startYear: startYear,
          canton: canton,
          label: 'rachat_lpp',
          blocageYears: 3,
        );
        variantOptions.add(TrajectoireOption(
          id: 'rachat_lpp',
          label: 'Rachat LPP (blocage 3 ans)',
          trajectory: trajectoryLpp,
          terminalValue: trajectoryLpp.last.netPatrimony,
          cumulativeTaxImpact: trajectoryLpp.last.cumulativeTaxDelta,
        ));
      }

      if (isPropertyOwner) {
        final trajectoryAmort = _buildAmortIndirectTrajectory(
          montantAnnuel: montantDisponible,
          tauxHypothecaire: variantTauxHypothecaire,
          tauxMarginal: variantTauxMarginal,
          horizon: anneesAvantRetraite,
          startYear: startYear,
          mortgageBalance: mortgageBalance,
        );
        variantOptions.add(TrajectoireOption(
          id: 'amort_indirect',
          label: l?.arbitrageOptionAmortIndirect ?? 'Amortissement indirect',
          trajectory: trajectoryAmort,
          terminalValue: trajectoryAmort.last.netPatrimony,
          cumulativeTaxImpact: trajectoryAmort.last.cumulativeTaxDelta,
        ));
      }

      final trajectoryLibre = _buildAllocationTrajectory(
        montantAnnuel: montantDisponible,
        rendement: variantRendementMarche,
        tauxMarginal: variantTauxMarginal,
        deductible: false,
        horizon: anneesAvantRetraite,
        startYear: startYear,
        canton: canton,
        label: 'invest_libre',
      );
      variantOptions.add(TrajectoireOption(
        id: 'invest_libre',
        label: l?.arbitrageOptionInvestLibre ?? 'Investissement libre',
        trajectory: trajectoryLibre,
        terminalValue: trajectoryLibre.last.netPatrimony,
        cumulativeTaxImpact: trajectoryLibre.last.cumulativeTaxDelta,
      ));

      return variantOptions;
    }

    double spreadVariant({
      required double variantTauxMarginal,
      required double variantRendement3a,
      required double variantRendementLpp,
      required double variantRendementMarche,
      required double variantTauxHypothecaire,
    }) {
      final variantOptions = buildVariantOptions(
        variantTauxMarginal: variantTauxMarginal,
        variantRendement3a: variantRendement3a,
        variantRendementLpp: variantRendementLpp,
        variantRendementMarche: variantRendementMarche,
        variantTauxHypothecaire: variantTauxHypothecaire,
      );
      return _terminalSpreadFromOptions(variantOptions);
    }

    final rendementMarcheLow = math.max(0.0, rendementMarche - 0.01);
    final rendementMarcheHigh = rendementMarche + 0.01;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_marche',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarcheLow,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarcheHigh,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      assumptionLow: rendementMarcheLow,
      assumptionHigh: rendementMarcheHigh,
    );

    final tauxMarginalLow = math.max(0.0, tauxMarginal - 0.02);
    final tauxMarginalHigh = math.min(0.50, tauxMarginal + 0.02);
    _addTornadoSensitivity(
      sensitivity,
      key: 'taux_marginal',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginalLow,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginalHigh,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      assumptionLow: tauxMarginalLow,
      assumptionHigh: tauxMarginalHigh,
    );

    final rendement3aLow = math.max(0.0, rendement3a - 0.005);
    final rendement3aHigh = rendement3a + 0.005;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_3a',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3aLow,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3aHigh,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      assumptionLow: rendement3aLow,
      assumptionHigh: rendement3aHigh,
    );

    final rendementLppLow = math.max(0.0, rendementLpp - 0.005);
    final rendementLppHigh = rendementLpp + 0.005;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_lpp',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLppLow,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendement3a: rendement3a,
        variantRendementLpp: rendementLppHigh,
        variantRendementMarche: rendementMarche,
        variantTauxHypothecaire: tauxHypothecaire,
      ),
      assumptionLow: rendementLppLow,
      assumptionHigh: rendementLppHigh,
    );

    if (isPropertyOwner) {
      final tauxHypoLow = math.max(0.0, tauxHypothecaire - 0.005);
      final tauxHypoHigh = tauxHypothecaire + 0.005;
      _addTornadoSensitivity(
        sensitivity,
        key: 'taux_hypothecaire',
        baseValue: baseSpread,
        lowValue: spreadVariant(
          variantTauxMarginal: tauxMarginal,
          variantRendement3a: rendement3a,
          variantRendementLpp: rendementLpp,
          variantRendementMarche: rendementMarche,
          variantTauxHypothecaire: tauxHypoLow,
        ),
        highValue: spreadVariant(
          variantTauxMarginal: tauxMarginal,
          variantRendement3a: rendement3a,
          variantRendementLpp: rendementLpp,
          variantRendementMarche: rendementMarche,
          variantTauxHypothecaire: tauxHypoHigh,
        ),
        assumptionLow: tauxHypoLow,
        assumptionHigh: tauxHypoHigh,
      );
    }

    return ArbitrageResult(
      options: options,
      breakevenYear: null,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Montant disponible : ${chf.formatChfWithPrefix(montantDisponible)}/an',
        'Taux marginal d\'imposition estime : ${(tauxMarginal * 100).toStringAsFixed(0)} %',
        'Rendement 3a : ${(rendement3a * 100).toStringAsFixed(1)} %',
        'Rendement LPP : ${(rendementLpp * 100).toStringAsFixed(2)} %',
        'Rendement marche : ${(rendementMarche * 100).toStringAsFixed(1)} %',
        'Horizon : $anneesAvantRetraite ans',
        if (isPropertyOwner)
          'Taux hypothecaire : ${(tauxHypothecaire * 100).toStringAsFixed(2)} %',
        if (potentielRachatLpp > 0)
          'Potentiel de rachat LPP : ${chf.formatChfWithPrefix(potentielRachatLpp)}',
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
      confidenceScore: _computeArbitrageConfidence(
        ['montantDisponible', 'tauxMarginal', 'potentielRachatLpp', 'canton'],
        dataSources,
      ),
      sensitivity: sensitivity,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  3. LOCATION VS PROPRIETE
  // ════════════════════════════════════════════════════════════

  /// Compare renting + investing surplus vs buying property.
  ///
  /// Option A: Rent, invest the down payment at market return.
  /// Option B: Buy with 80% mortgage, amortize 2nd rank (80->65% LTV)
  ///   over 15 years, 1% maintenance/year, valeur locative taxable.
  ///
  /// Legal basis: FINMA affordability (5% theoretical rate),
  ///   LIFD art. 21 (valeur locative), LIFD art. 33 (interest deduction).
  static ArbitrageResult compareLocationVsPropriete({
    required double capitalDisponible,
    required double loyerMensuelActuel,
    required double prixBien,
    String canton = 'ZH',
    int horizonAnnees = 20,
    double rendementMarche = 0.04,
    double appreciationImmo = 0.015,
    double tauxHypotheque = 0.02,
    double tauxEntretien = 0.01,
    bool isMarried = false,
    Map<String, ProfileDataSource>? dataSources,
  }) {
    final startYear = DateTime.now().year;

    // ── Approach: compare net patrimony including cashflow delta ──
    // Both options have annual costs (rent vs charges proprio).
    // The DELTA in cashflow is reinvested by the cheaper option.
    // This gives a fair apples-to-apples comparison.

    final loyerAnnuel = loyerMensuelActuel * 12;
    final fondsPropres = capitalDisponible.clamp(0.0, prixBien);
    double hypotheque = prixBien - fondsPropres;
    double valeurBien = prixBien;

    // 2nd rank: from 80% LTV to 65% LTV over max 15 years
    final seuil1erRang = prixBien * 0.65;
    final deuxiemeRang = math.max(0.0, hypotheque - seuil1erRang);
    final amortAnnuel2ndRank = deuxiemeRang > 0 ? deuxiemeRang / 15 : 0.0;

    // First pass: compute annual proprio costs to get the cashflow delta
    final annualProprioCharges = <double>[];
    double tempHyp = hypotheque;
    double tempVal = prixBien;
    for (int y = 0; y <= horizonAnnees; y++) {
      if (y == 0) {
        annualProprioCharges.add(0);
        continue;
      }
      tempVal *= (1 + appreciationImmo);
      final interets = tempHyp * tauxHypotheque;
      // Amortization: 2nd rank only, stops when mortgage reaches 1st rank level
      final amortissement = tempHyp > seuil1erRang ? amortAnnuel2ndRank : 0.0;
      final entretien = prixBien * tauxEntretien;
      final tauxVL = HousingCostCalculator.getValeurLocativeRate(canton);
      final valeurLocative = tempVal * tauxVL;
      final netTaxableIncome = valeurLocative - interets;
      final taxImpact = netTaxableIncome > 0
          ? RetirementTaxCalculator.estimateMonthlyIncomeTax(
                revenuAnnuelImposable: netTaxableIncome,
                canton: canton,
                etatCivil: isMarried ? 'marie' : 'celibataire',
              ) *
              12
          : 0.0;
      annualProprioCharges.add(interets + amortissement + entretien + taxImpact);
      tempHyp = math.max(seuil1erRang, tempHyp - amortissement);
    }

    // ── Option A: Rent + Invest ──
    // Capital = capitalDisponible invested at market return.
    // Each year, if renting is cheaper than owning, the savings are reinvested.
    // If renting is more expensive, the extra cost is withdrawn from capital.
    double investCapital = capitalDisponible;
    final rentSnapshots = <YearlySnapshot>[];

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
      // Cashflow delta: proprio charges - loyer (positive = renting is cheaper)
      final cashflowDelta = annualProprioCharges[y] - loyerAnnuel;
      // If renting is cheaper, surplus is invested. If more expensive, withdrawn.
      investCapital += cashflowDelta;

      rentSnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: investCapital,
        annualCashflow: -loyerAnnuel,
        cumulativeTaxDelta: 0,
      ));
    }

    // ── Option B: Buy ──
    // Net patrimony = property value - remaining mortgage.
    // All charges are paid from income (like rent is for option A).
    hypotheque = prixBien - fondsPropres;
    valeurBien = prixBien;
    final buySnapshots = <YearlySnapshot>[];

    for (int y = 0; y <= horizonAnnees; y++) {
      if (y == 0) {
        buySnapshots.add(YearlySnapshot(
          year: startYear,
          netPatrimony: valeurBien - hypotheque,
          annualCashflow: 0,
          cumulativeTaxDelta: 0,
        ));
        continue;
      }
      valeurBien *= (1 + appreciationImmo);
      // Amortization: 2nd rank only, stops when mortgage reaches 1st rank level
      final amortissement = hypotheque > seuil1erRang ? amortAnnuel2ndRank : 0.0;
      hypotheque = math.max(seuil1erRang, hypotheque - amortissement);

      buySnapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: valeurBien - hypotheque,
        annualCashflow: -annualProprioCharges[y],
        cumulativeTaxDelta: 0,
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

    final delta = (optionA.terminalValue - optionB.terminalValue).abs();
    final betterLabel =
        optionA.terminalValue > optionB.terminalValue ? 'louer' : 'acheter';
    final chiffreChoc = 'Dans ce scenario simule, $betterLabel genere '
        '~${chf.formatChfWithPrefix(delta)} de patrimoine net supplementaire sur '
        '$horizonAnnees ans.';

    // FINMA affordability check
    final alertes = <String>[];
    final chargesTheorique =
        prixBien * 0.05 + prixBien * 0.01 + prixBien * 0.01;
    // We can't know gross income here, but flag the theoretical charge
    alertes.add(
      'Charge theorique FINMA : ${chf.formatChfWithPrefix(chargesTheorique)}/an '
      '(taux theorique 5 % + amortissement 1 % + entretien 1 %). '
      'Verifie que cela ne depasse pas 1/3 de ton revenu brut.',
    );

    final displaySummary = breakevenYear != null
        ? 'Les trajectoires se croisent vers ${startYear + breakevenYear}. '
            'Avant ce point, une option domine ; apres, l\'autre prend le relais.'
        : 'Sur l\'horizon de $horizonAnnees ans, les trajectoires ne se croisent pas. '
            'L\'ecart final est de ${chf.formatChfWithPrefix(delta)}.';

    final sensitivity = <String, double>{};
    final baseSpread = _terminalSpreadFromOptions(options);

    double spreadVariantLocation({
      required double variantLoyerMensuel,
      required double variantRendementMarche,
    }) {
      final variantLocation = _buildLocationInvestTrajectory(
        capital: capitalDisponible,
        loyerAnnuel: variantLoyerMensuel * 12,
        rendement: variantRendementMarche,
        horizon: horizonAnnees,
        startYear: startYear,
      );
      return _terminalSpreadFromValues([
        variantLocation.last.netPatrimony,
        optionB.terminalValue,
      ]);
    }

    final rendementLow = math.max(0.0, rendementMarche - 0.01);
    final rendementHigh = rendementMarche + 0.01;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_marche',
      baseValue: baseSpread,
      lowValue: spreadVariantLocation(
        variantLoyerMensuel: loyerMensuelActuel,
        variantRendementMarche: rendementLow,
      ),
      highValue: spreadVariantLocation(
        variantLoyerMensuel: loyerMensuelActuel,
        variantRendementMarche: rendementHigh,
      ),
      assumptionLow: rendementLow,
      assumptionHigh: rendementHigh,
    );

    final loyerLow = loyerMensuelActuel * 0.90;
    final loyerHigh = loyerMensuelActuel * 1.10;
    _addTornadoSensitivity(
      sensitivity,
      key: 'loyer_mensuel',
      baseValue: baseSpread,
      lowValue: spreadVariantLocation(
        variantLoyerMensuel: loyerLow,
        variantRendementMarche: rendementMarche,
      ),
      highValue: spreadVariantLocation(
        variantLoyerMensuel: loyerHigh,
        variantRendementMarche: rendementMarche,
      ),
      assumptionLow: loyerLow,
      assumptionHigh: loyerHigh,
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
        'Fonds propres : ${(capitalDisponible / prixBien * 100).toStringAsFixed(0)} %',
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
      confidenceScore: _computeArbitrageConfidence(
        ['capitalDisponible', 'loyerMensuel', 'prixBien', 'canton'],
        dataSources,
      ),
      sensitivity: sensitivity,
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
    double tauxConversion = lppTauxConversionMinDecimal,
    String canton = 'ZH',
    bool isMarried = false,
    Map<String, ProfileDataSource>? dataSources,
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
        'Economie d\'impot au rachat : ${chf.formatChfWithPrefix(taxSavingRachat)}. '
        'Ecart final simule : ${chf.formatChfWithPrefix(delta)} sur $anneesAvantRetraite ans.';

    final displaySummary =
        'Le rachat LPP offre une deduction fiscale immediate de '
        '${chf.formatChfWithPrefix(taxSavingRachat)}, mais le capital est bloque (LPP art. 79b al. 3). '
        'L\'investissement libre est accessible a tout moment.';

    final sensitivity = <String, double>{};
    final baseSpread = _terminalSpreadFromOptions(options);

    double spreadVariant({
      required double variantTauxMarginal,
      required double variantRendementLpp,
      required double variantRendementMarche,
      required int variantAnnees,
    }) {
      final taxSavingVariant = montant * variantTauxMarginal;

      double balanceLppVariant = montant;
      for (int i = 0; i < variantAnnees; i++) {
        balanceLppVariant *= (1 + variantRendementLpp);
      }
      final withdrawalTaxVariant = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: balanceLppVariant,
        canton: canton,
        isMarried: isMarried,
      );
      final netLppVariant =
          balanceLppVariant - withdrawalTaxVariant + taxSavingVariant;

      double balanceMarcheVariant = montant;
      for (int i = 0; i < variantAnnees; i++) {
        balanceMarcheVariant *= (1 + variantRendementMarche);
        balanceMarcheVariant -= balanceMarcheVariant * 0.003;
      }

      return (netLppVariant - balanceMarcheVariant).abs();
    }

    final rendementMarcheLow = math.max(0.0, rendementMarche - 0.01);
    final rendementMarcheHigh = rendementMarche + 0.01;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_marche',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarcheLow,
        variantAnnees: anneesAvantRetraite,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarcheHigh,
        variantAnnees: anneesAvantRetraite,
      ),
      assumptionLow: rendementMarcheLow,
      assumptionHigh: rendementMarcheHigh,
    );

    final tauxMarginalLow = math.max(0.0, tauxMarginal - 0.02);
    final tauxMarginalHigh = math.min(0.50, tauxMarginal + 0.02);
    _addTornadoSensitivity(
      sensitivity,
      key: 'taux_marginal',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginalLow,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesAvantRetraite,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginalHigh,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesAvantRetraite,
      ),
      assumptionLow: tauxMarginalLow,
      assumptionHigh: tauxMarginalHigh,
    );

    final rendementLppLow = math.max(0.0, rendementLpp - 0.005);
    final rendementLppHigh = rendementLpp + 0.005;
    _addTornadoSensitivity(
      sensitivity,
      key: 'rendement_lpp',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLppLow,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesAvantRetraite,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLppHigh,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesAvantRetraite,
      ),
      assumptionLow: rendementLppLow,
      assumptionHigh: rendementLppHigh,
    );

    final anneesLow = math.max(1, anneesAvantRetraite - 2);
    final anneesHigh = math.min(40, anneesAvantRetraite + 2);
    _addTornadoSensitivity(
      sensitivity,
      key: 'annees_avant_retraite',
      baseValue: baseSpread,
      lowValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesLow,
      ),
      highValue: spreadVariant(
        variantTauxMarginal: tauxMarginal,
        variantRendementLpp: rendementLpp,
        variantRendementMarche: rendementMarche,
        variantAnnees: anneesHigh,
      ),
      assumptionLow: anneesLow.toDouble(),
      assumptionHigh: anneesHigh.toDouble(),
    );

    return ArbitrageResult(
      options: options,
      breakevenYear: breakevenYear,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Montant : ${chf.formatChfWithPrefix(montant)}',
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
      confidenceScore: _computeArbitrageConfidence(
        ['montant', 'tauxMarginal', 'capitalLpp', 'canton'],
        dataSources,
      ),
      sensitivity: sensitivity,
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
    int ageRetraite = avsAgeReferenceHomme,
    String canton = 'ZH',
    bool isMarried = false,
    Map<String, ProfileDataSource>? dataSources,
  }) {
    if (assets.isEmpty) {
      return ArbitrageResult(
        options: const [],
        breakevenYear: null,
        chiffreChoc: 'Ajoute au moins un avoir pour voir la comparaison.',
        displaySummary: '',
        hypotheses: const [],
        disclaimer:
            'Outil educatif — ne constitue pas un conseil financier (LSFin).',
        sources: const ['LIFD art. 38 (impot sur retrait en capital)'],
        confidenceScore: _computeArbitrageConfidence([], dataSources),
        sensitivity: const {},
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
      ..sort(
          (a, b) => a.earliestWithdrawalAge.compareTo(b.earliestWithdrawalAge));

    double totalTaxEtale = 0;
    final withdrawalPlan =
        <({String type, double amount, int age, double tax})>[];

    // Group assets by withdrawal year to compute progressive tax on combined total.
    final yearGroups = <int, List<RetirementAsset>>{};
    for (final asset in sortedAssets) {
      yearGroups.putIfAbsent(asset.earliestWithdrawalAge, () => []).add(asset);
    }

    for (final entry in yearGroups.entries) {
      final age = entry.key;
      final groupAssets = entry.value;
      final groupTotal = groupAssets.fold<double>(0, (s, a) => s + a.amount);

      // Compute progressive tax on the combined year total
      final groupTax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: groupTotal,
        canton: canton,
        isMarried: isMarried,
      );
      totalTaxEtale += groupTax;

      // Split tax proportionally back to each asset
      for (final asset in groupAssets) {
        final share = groupTotal > 0 ? asset.amount / groupTotal : 0.0;
        withdrawalPlan.add((
          type: asset.type,
          amount: asset.amount,
          age: age,
          tax: groupTax * share,
        ));
      }
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
        ? 'Tu economiserais ~${chf.formatChfWithPrefix(taxSaved)} d\'impot en etalant tes retraits.'
        : 'Dans ce cas, l\'ecart d\'impot est de ${chf.formatChfWithPrefix(taxSaved.abs())}.';

    final displaySummary = 'Retrait total : ${chf.formatChfWithPrefix(totalCapital)}. '
        'Impot "tout en un" : ${chf.formatChfWithPrefix(taxToutEnUn)} vs '
        'impot etale : ${chf.formatChfWithPrefix(totalTaxEtale)}.';

    final withdrawalDetails = withdrawalPlan
        .map((w) =>
            '${w.type.toUpperCase()} : ${chf.formatChfWithPrefix(w.amount)} a ${w.age} ans '
            '(impot : ${chf.formatChfWithPrefix(w.tax)})')
        .toList();

    final sensitivity = <String, double>{};
    final baseSpread = _terminalSpreadFromOptions(options);

    double spreadForCapitalScale(double scale) {
      final scaledTotal = totalCapital * scale;
      final scaledTaxToutEnUn = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: scaledTotal,
        canton: canton,
        isMarried: isMarried,
      );
      var scaledTaxEtale = 0.0;
      for (final asset in sortedAssets) {
        scaledTaxEtale += RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: asset.amount * scale,
          canton: canton,
          isMarried: isMarried,
        );
      }
      final scaledNetToutEnUn = scaledTotal - scaledTaxToutEnUn;
      final scaledNetEtale = scaledTotal - scaledTaxEtale;
      return (scaledNetEtale - scaledNetToutEnUn).abs();
    }

    _addTornadoSensitivity(
      sensitivity,
      key: 'capital_total',
      baseValue: baseSpread,
      lowValue: spreadForCapitalScale(0.90),
      highValue: spreadForCapitalScale(1.10),
      assumptionLow: totalCapital * 0.90,
      assumptionHigh: totalCapital * 1.10,
    );

    return ArbitrageResult(
      options: options,
      breakevenYear: null,
      chiffreChoc: chiffreChoc,
      displaySummary: displaySummary,
      hypotheses: [
        'Capital total : ${chf.formatChfWithPrefix(totalCapital)}',
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
      confidenceScore: _computeArbitrageConfidence(
        ['capitaux3a', 'capitalLpp', 'canton', 'ageRetraite'],
        dataSources,
      ),
      sensitivity: sensitivity,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS — Trajectory builders
  // ════════════════════════════════════════════════════════════

  static double _terminalSpreadFromOptions(List<TrajectoireOption> options) {
    if (options.length < 2) return 0;
    final terminals = options.map((o) => o.terminalValue);
    final minVal = terminals.reduce(math.min);
    final maxVal = terminals.reduce(math.max);
    return maxVal - minVal;
  }

  static double _terminalSpreadFromValues(List<double> values) {
    if (values.length < 2) return 0;
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    return maxVal - minVal;
  }

  static void _addTornadoSensitivity(
    Map<String, double> sensitivity, {
    required String key,
    required double baseValue,
    required double lowValue,
    required double highValue,
    double? assumptionLow,
    double? assumptionHigh,
  }) {
    final swing = (highValue - lowValue).abs();
    sensitivity[key] = swing;
    sensitivity['tornado_${key}_base'] = baseValue;
    sensitivity['tornado_${key}_low'] = lowValue;
    sensitivity['tornado_${key}_high'] = highValue;
    sensitivity['tornado_${key}_swing'] = swing;
    if (assumptionLow != null) {
      sensitivity['tornado_${key}_assumption_low'] = assumptionLow;
    }
    if (assumptionHigh != null) {
      sensitivity['tornado_${key}_assumption_high'] = assumptionHigh;
    }
  }

  /// Build year-by-year trajectory for full rente option.
  ///
  /// Rente is taxed as income every year (LIFD art. 22).
  /// LPP rente is NOT indexed — purchasing power erodes with inflation.
  /// All values expressed in real terms (francs d'aujourd'hui).
  static List<YearlySnapshot> _buildRenteTrajectory({
    required double renteAnnuelle,
    required String canton,
    required int horizon,
    required int startYear,
    required bool isMarried,
    double inflation = 0.0,
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
      // Rente LPP is NOT indexed — real value decreases with inflation
      final realRente = renteAnnuelle / math.pow(1 + inflation, y);
      final annualTax = RetirementTaxCalculator.estimateMonthlyIncomeTax(
            revenuAnnuelImposable: realRente,
            canton: canton,
            etatCivil: isMarried ? 'marie' : 'celibataire',
          ) *
          12;
      final netAnnual = realRente - annualTax;
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
  /// Then invested and drawn down using Trinity Study SWR:
  ///   - Year 1: withdraw initialCapital × SWR
  ///   - Each following year: adjust that amount for inflation
  /// SWR withdrawals are NOT taxable income (consumption of patrimony).
  /// All values expressed in real terms (francs d'aujourd'hui).
  /// netPatrimony = remaining invested capital in real terms (francs today)
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
    final capitalNetAtStart = capitalNet;

    final snapshots = <YearlySnapshot>[];
    double initialWithdrawal = 0;

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
      // Capital grows at NOMINAL return
      capitalNet *= (1 + rendement);

      // Trinity Study SWR: fixed initial withdrawal, inflation-adjusted
      if (y == 1) {
        initialWithdrawal = capitalNetAtStart * tauxRetrait;
      }
      final nominalWithdrawal =
          initialWithdrawal * math.pow(1 + inflation, y - 1);
      // Cap withdrawal to remaining capital (can't withdraw more than exists)
      final actualWithdrawal = math.min(nominalWithdrawal, math.max(0, capitalNet));
      capitalNet -= actualWithdrawal;

      // Express in real terms (deflate to today's purchasing power)
      final realPatrimony = capitalNet / math.pow(1 + inflation, y);
      final realCashflow = actualWithdrawal / math.pow(1 + inflation, y);

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: realPatrimony,
        annualCashflow: realCashflow,
        cumulativeTaxDelta: withdrawalTax,
      ));
    }
    return snapshots;
  }

  /// Build year-by-year trajectory for mixed option:
  /// obligatoire as rente (6.8%) + surobligatoire as capital.
  /// Rente deflated for inflation. Capital uses Trinity Study SWR.
  /// All values in real terms.
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
    final capitalNetAtStart = capitalNet;

    final snapshots = <YearlySnapshot>[];
    double cumulativeCashflow = 0;
    double cumulativeTax = withdrawalTax;
    double initialCapitalWithdrawal = 0;

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
      // Rente part: NOT indexed, deflated by inflation
      final realRente = renteObligatoire / math.pow(1 + inflation, y);
      final renteTax = RetirementTaxCalculator.estimateMonthlyIncomeTax(
            revenuAnnuelImposable: realRente,
            canton: canton,
            etatCivil: isMarried ? 'marie' : 'celibataire',
          ) *
          12;
      // Capital part: nominal growth + Trinity SWR
      capitalNet *= (1 + rendement);
      if (y == 1) {
        initialCapitalWithdrawal = capitalNetAtStart * tauxRetrait;
      }
      final nominalWithdrawal =
          initialCapitalWithdrawal * math.pow(1 + inflation, y - 1);
      final capitalWithdrawal =
          math.min(nominalWithdrawal, math.max(0, capitalNet));
      capitalNet -= capitalWithdrawal;

      final totalNominalCashflow = renteObligatoire - renteTax + capitalWithdrawal;
      cumulativeCashflow += totalNominalCashflow;
      cumulativeTax += renteTax;

      // Express in real terms
      final realPatrimony =
          (capitalNet + cumulativeCashflow) / math.pow(1 + inflation, y);
      final realCashflow = totalNominalCashflow / math.pow(1 + inflation, y);

      snapshots.add(YearlySnapshot(
        year: startYear + y,
        netPatrimony: realPatrimony,
        annualCashflow: realCashflow,
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
      // Apply return on last year's balance first (consistent with LPP calculator)
      balance *= (1 + rendement);
      // Then add this year's contribution
      balance += montantAnnuel;

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
    double mortgageBalance = 0,
  }) {
    final snapshots = <YearlySnapshot>[];
    double balance3a = 0;
    double cumulativeSaving = 0;
    const rendement3a = 0.02; // Conservative 3a return

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
      final contribution = math.min(montantAnnuel, reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp));
      balance3a += contribution;
      balance3a *= (1 + rendement3a);

      // Tax benefits: 3a deduction + maintained mortgage interest deduction
      final taxSaving3a = contribution * tauxMarginal;
      // Mortgage interest deduction maintained (full mortgage balance stays,
      // since capital goes to 3a instead of direct amortization)
      final interestDeduction = mortgageBalance > 0
          ? mortgageBalance * tauxHypothecaire * tauxMarginal
          : 0.0;
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

  /// Find the first year index where the ordering between trajectories changes.
  /// Returns null if they never cross on the horizon.
  static int? _findBreakevenYear(
    List<YearlySnapshot> renteTrajectory,
    List<YearlySnapshot> capitalTrajectory,
  ) {
    final maxLen = math.min(renteTrajectory.length, capitalTrajectory.length);
    if (maxLen <= 1) return null;

    for (int i = 1; i < maxLen; i++) {
      final prevDelta = capitalTrajectory[i - 1].netPatrimony -
          renteTrajectory[i - 1].netPatrimony;
      final currDelta =
          capitalTrajectory[i].netPatrimony - renteTrajectory[i].netPatrimony;

      if (currDelta == 0) {
        return i;
      }

      final hasSignChange =
          (prevDelta < 0 && currDelta > 0) || (prevDelta > 0 && currDelta < 0);
      if (hasSignChange) {
        return i;
      }
    }
    return null;
  }

  // F3: _formatChf removed — use centralized chf.formatChfWithPrefix()
}
