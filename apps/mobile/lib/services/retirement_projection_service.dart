import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/retirement_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT PROJECTION SERVICE
// ────────────────────────────────────────────────────────────
//
// Orchestrates financial_core calculators + RetirementService + constants
// to produce a unified household retirement income projection.
//
// Key questions answered:
//   1. What will our household income be at 65?
//   2. Can I take early retirement? What's the impact?
//   3. With age difference in couple, what happens between retirements?
//   4. What budget will we need? Tax simulation, AVS indexation?
//
// All computations are pure and deterministic.
// No banned terms ("garanti", "certain", "assuré", "sans risque").
// ────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════

/// Source de revenu a la retraite.
class RetirementIncomeSource {
  final String id;
  final String label;
  final double monthlyAmount;
  final Color color;
  final bool isIndexed;

  /// True for LPP capital withdrawal (SWR from net capital).
  /// Capital is already taxed at withdrawal (LIFD art. 38), so the
  /// SWR drawdown is consumption of own patrimony — NOT taxable income.
  final bool isCapitalWithdrawal;

  const RetirementIncomeSource({
    required this.id,
    required this.label,
    required this.monthlyAmount,
    required this.color,
    this.isIndexed = false,
    this.isCapitalWithdrawal = false,
  });

  double get annualAmount => monthlyAmount * 12;
}

/// Phase de revenu (ex: "Julien retraite, Lauren active").
class RetirementPhase {
  final String label;
  final int startYear;
  final int? endYear;
  final List<RetirementIncomeSource> sources;

  const RetirementPhase({
    required this.label,
    required this.startYear,
    this.endYear,
    required this.sources,
  });

  double get totalMonthly =>
      sources.fold(0.0, (sum, s) => sum + s.monthlyAmount);
}

/// Scenario de retraite anticipee/ajournee pour un age donne.
class EarlyRetirementScenario {
  final int retirementAge;
  final List<RetirementIncomeSource> sources;
  final double totalMonthly;
  final double adjustmentPct;
  final double cumulativeDifference;

  const EarlyRetirementScenario({
    required this.retirementAge,
    required this.sources,
    required this.totalMonthly,
    required this.adjustmentPct,
    required this.cumulativeDifference,
  });
}

/// Budget gap a la retraite.
class RetirementBudgetGap {
  final double totalRevenusMensuel;
  final double avsMensuel;
  final double lppMensuel;
  final double troisAMensuel;
  final double libreMensuel;
  final double impotEstimeMensuel;
  final double depensesMensuelles;
  final double soldeMensuel;
  final double tauxRemplacement;
  final List<String> alertes;

  const RetirementBudgetGap({
    required this.totalRevenusMensuel,
    required this.avsMensuel,
    required this.lppMensuel,
    required this.troisAMensuel,
    required this.libreMensuel,
    required this.impotEstimeMensuel,
    required this.depensesMensuelles,
    required this.soldeMensuel,
    required this.tauxRemplacement,
    required this.alertes,
  });
}

/// Point de projection indexee (annee par annee).
class IndexedProjectionPoint {
  final int year;
  final int age;
  final double revenuNominal;
  final double revenuIndexe;
  final double pouvoirAchat;

  const IndexedProjectionPoint({
    required this.year,
    required this.age,
    required this.revenuNominal,
    required this.revenuIndexe,
    required this.pouvoirAchat,
  });
}

/// Resultat complet de la projection retraite.
class RetirementProjectionResult {
  final double revenuMensuelAt65;
  final double tauxRemplacement;
  final double revenuPreRetraiteMensuel;
  final bool isCouple;
  final List<RetirementPhase> phases;
  final List<EarlyRetirementScenario> earlyRetirementComparisons;
  final RetirementBudgetGap budgetGap;
  final List<IndexedProjectionPoint> indexedProjection;
  final String disclaimer;
  final List<String> sources;

  const RetirementProjectionResult({
    required this.revenuMensuelAt65,
    required this.tauxRemplacement,
    required this.revenuPreRetraiteMensuel,
    required this.isCouple,
    required this.phases,
    required this.earlyRetirementComparisons,
    required this.budgetGap,
    required this.indexedProjection,
    required this.disclaimer,
    required this.sources,
  });
}

// ════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════

class RetirementProjectionService {
  RetirementProjectionService._();

  // ── Couleurs par source ─────────────────────────────────
  static const Color colorAvs = MintColors.info;
  static const Color colorLpp = MintColors.success;
  static const Color color3a = MintColors.purple;
  static const Color colorLibre = MintColors.teal;
  static const Color colorSalary = MintColors.amber;

  // ── Constantes ──────────────────────────────────────────
  static const double _avsIndexationRate = 0.01;
  static const double _inflationRate = 0.015;
  static const int _projectionYears = 25;
  static const int _lifeExpectancy = 87;
  static const double _3aAnnualizationYears = 20.0;
  static const double _safeWithdrawalRate = 0.04;

  // ════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════

  /// Projette les revenus du menage a la retraite.
  static RetirementProjectionResult project({
    required CoachProfile profile,
    int retirementAgeUser = 65,
    int? retirementAgeConjoint,
    double? depensesMensuelles,
    double lppCapitalPct = 0.0,
  }) {
    final conjAge = retirementAgeConjoint ?? 65;
    final expenses =
        depensesMensuelles ?? _estimateRetirementExpenses(profile);

    // 1. Income at user's chosen retirement age
    final incomes = _computeIncomes(
      profile: profile,
      ageUser: retirementAgeUser,
      ageConjoint: conjAge,
      lppCapitalPct: lppCapitalPct,
    );
    final revenuMensuel =
        incomes.fold(0.0, (sum, s) => sum + s.monthlyAmount);

    // Pre-retirement income (net)
    final revenuPreRetraite = profile.revenuBrutAnnuel * 0.87 / 12 +
        (profile.conjoint?.revenuBrutAnnuel ?? 0) * 0.87 / 12;
    final tauxRemplacement =
        revenuPreRetraite > 0 ? revenuMensuel / revenuPreRetraite * 100 : 0.0;

    // 2. Couple phases
    final phases = _computePhases(
      profile: profile,
      ageUser: retirementAgeUser,
      ageConjoint: conjAge,
      lppCapitalPct: lppCapitalPct,
    );

    // 3. Early retirement comparison (63-70)
    final earlyComparisons = _computeEarlyRetirementComparisons(
      profile: profile,
      ageConjoint: conjAge,
      lppCapitalPct: lppCapitalPct,
    );

    // 4. Budget gap
    final budgetGap = _computeBudgetGap(
      profile: profile,
      incomes: incomes,
      depensesMensuelles: expenses,
    );

    // 5. Indexed projection (25 years)
    final indexedProjection = _computeIndexedProjection(
      profile: profile,
      retirementAge: retirementAgeUser,
      incomeSources: incomes,
    );

    return RetirementProjectionResult(
      revenuMensuelAt65: revenuMensuel,
      tauxRemplacement: tauxRemplacement,
      revenuPreRetraiteMensuel: revenuPreRetraite,
      isCouple: profile.isCouple && profile.conjoint != null,
      phases: phases,
      earlyRetirementComparisons: earlyComparisons,
      budgetGap: budgetGap,
      indexedProjection: indexedProjection,
      disclaimer:
          'Projection educative basee sur les baremes AVS/LPP 2025. '
          'Ne constitue pas un conseil financier ou en prevoyance. '
          'Les montants sont des estimations qui peuvent varier selon '
          'l\'evolution legale et ta situation personnelle. '
          'Consulte un·e specialiste pour un plan personnalise. LSFin.',
      sources: [
        'LAVS art. 21-29 (rente AVS, anticipation, ajournement)',
        'LPP art. 14 (taux de conversion minimum 6.8%)',
        'LIFD art. 38 (imposition des prestations en capital)',
        'OPC (prestations complementaires)',
        'LAVS art. 33ter (indexation indice mixte)',
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  INCOME COMPUTATION (both retired)
  // ════════════════════════════════════════════════════════════

  static List<RetirementIncomeSource> _computeIncomes({
    required CoachProfile profile,
    required int ageUser,
    int ageConjoint = 65,
    double lppCapitalPct = 0.0,
  }) {
    final sources = <RetirementIncomeSource>[];
    final userName = profile.firstName ?? 'Toi';
    final hasConjoint = profile.isCouple && profile.conjoint != null;
    final conjName = profile.conjoint?.firstName ?? 'Conjoint·e';

    // ── AVS ──────────────────────────────────────────────
    final avsUser = AvsCalculator.computeMonthlyRente(
      currentAge: profile.age,
      retirementAge: ageUser,
      lacunes: profile.prevoyance.lacunesAVS ?? 0,
      anneesContribuees: profile.prevoyance.anneesContribuees,
      arrivalAge: profile.arrivalAge,
      grossAnnualSalary: profile.revenuBrutAnnuel,
    );

    double avsConj = 0;
    if (hasConjoint) {
      avsConj = AvsCalculator.computeMonthlyRente(
        currentAge: profile.conjoint!.age ?? 45,
        retirementAge: ageConjoint,
        lacunes: profile.conjoint?.prevoyance?.lacunesAVS ?? 0,
        anneesContribuees: profile.conjoint?.prevoyance?.anneesContribuees,
        arrivalAge: profile.conjoint!.arrivalAge,
        grossAnnualSalary: profile.conjoint!.revenuBrutAnnuel,
      );
    }

    // Couple cap 150% — LAVS art. 35: ONLY for married couples.
    // Concubins are two singles, each gets their own rente uncapped.
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    if (hasConjoint && isMarried) {
      final couple = AvsCalculator.computeCouple(
        avsUser: avsUser,
        avsConjoint: avsConj,
        isMarried: true,
      );
      sources.add(RetirementIncomeSource(
        id: 'avs_user',
        label: 'AVS $userName',
        monthlyAmount: couple.user,
        color: colorAvs,
        isIndexed: true,
      ));
      if (couple.conjoint > 0) {
        sources.add(RetirementIncomeSource(
          id: 'avs_conjoint',
          label: 'AVS $conjName',
          monthlyAmount: couple.conjoint,
          color: const Color(0xFF4DA6FF),
          isIndexed: true,
        ));
      }
    } else if (hasConjoint) {
      // Concubins: each gets their own rente, no cap (LAVS art. 35 n/a)
      sources.add(RetirementIncomeSource(
        id: 'avs_user',
        label: 'AVS $userName',
        monthlyAmount: avsUser,
        color: colorAvs,
        isIndexed: true,
      ));
      if (avsConj > 0) {
        sources.add(RetirementIncomeSource(
          id: 'avs_conjoint',
          label: 'AVS $conjName',
          monthlyAmount: avsConj,
          color: const Color(0xFF4DA6FF),
          isIndexed: true,
        ));
      }
    } else {
      sources.add(RetirementIncomeSource(
        id: 'avs_user',
        label: 'AVS',
        monthlyAmount: avsUser,
        color: colorAvs,
        isIndexed: true,
      ));
    }

    // ── LPP user ─────────────────────────────────────────
    // Independants without LPP affiliation (LPP art. 4): no bonifications
    // projected. Only existing capital (if any) fructifies.
    final userHasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0 ||
        profile.employmentStatus != 'independant';
    final userBuyback = _userLppBuyback(profile);
    final lppUserRente = LppCalculator.projectToRetirement(
      currentBalance: profile.prevoyance.avoirLppTotal ?? 0,
      currentAge: profile.age,
      retirementAge: ageUser,
      grossAnnualSalary: userHasLpp ? profile.revenuBrutAnnuel : 0,
      caisseReturn: profile.prevoyance.rendementCaisse,
      conversionRate: profile.prevoyance.tauxConversion,
      monthlyBuyback: userBuyback,
      buybackCap: profile.prevoyance.lacuneRachatRestante,
    );
    final lppSuffix = lppCapitalPct >= 1.0
        ? ' (capital)'
        : lppCapitalPct > 0
            ? ' (mixte)'
            : '';
    final isMarriedForTax =
        profile.etatCivil == CoachCivilStatus.marie;
    final lppUserMonthly = LppCalculator.blendedMonthly(
      annualRente: lppUserRente,
      conversionRate: profile.prevoyance.tauxConversion,
      lppCapitalPct: lppCapitalPct,
      canton: profile.canton,
      isMarried: isMarriedForTax,
    );
    sources.add(RetirementIncomeSource(
      id: 'lpp_user',
      label: hasConjoint ? 'LPP $userName$lppSuffix' : 'LPP$lppSuffix',
      monthlyAmount: lppUserMonthly,
      color: colorLpp,
      // Capital SWR is consumption of own patrimony, already taxed at
      // withdrawal (LIFD art. 38) — not taxable as income.
      isCapitalWithdrawal: lppCapitalPct > 0,
    ));

    // ── LPP conjoint ─────────────────────────────────────
    if (hasConjoint) {
      final conjPrev = profile.conjoint!.prevoyance;
      final conjBuyback = _conjointLppBuyback(profile);
      final lppConjRente = LppCalculator.projectToRetirement(
        currentBalance: conjPrev?.avoirLppTotal ?? 0,
        currentAge: profile.conjoint!.age ?? 45,
        retirementAge: ageConjoint,
        grossAnnualSalary: profile.conjoint!.revenuBrutAnnuel,
        caisseReturn: conjPrev?.rendementCaisse ?? 0.02,
        conversionRate: conjPrev?.tauxConversion ?? 0.068,
        monthlyBuyback: conjBuyback,
        buybackCap: conjPrev?.lacuneRachatRestante ?? 0,
      );
      if (lppConjRente > 0) {
        final lppConjMonthly = LppCalculator.blendedMonthly(
          annualRente: lppConjRente,
          conversionRate: conjPrev?.tauxConversion ?? 0.068,
          lppCapitalPct: lppCapitalPct,
          canton: profile.canton,
          isMarried: isMarriedForTax,
        );
        sources.add(RetirementIncomeSource(
          id: 'lpp_conjoint',
          label: 'LPP $conjName$lppSuffix',
          monthlyAmount: lppConjMonthly,
          color: const Color(0xFF4CAF50),
          isCapitalWithdrawal: lppCapitalPct > 0,
        ));
      }
    }

    // ── 3a ───────────────────────────────────────────────
    final isIndepSansLpp = profile.employmentStatus == 'independant' &&
        profile.revenuBrutAnnuel < lppSeuilEntree;
    final threeACapitalBrut = _project3aToRetirement(
      currentBalance: profile.prevoyance.totalEpargne3a +
          (profile.conjoint?.prevoyance?.totalEpargne3a ?? 0),
      monthly3a: profile.total3aMensuel,
      yearsToRetirement: (ageUser - profile.age).clamp(0, 50),
      averageReturn: _average3aReturn(profile),
      isIndependantSansLpp: isIndepSansLpp,
    );
    // Apply capital withdrawal tax (LIFD art. 38) before annualizing
    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final threeACapital = threeACapitalBrut -
        RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: threeACapitalBrut,
          canton: canton,
        );
    if (threeACapital > 0) {
      sources.add(RetirementIncomeSource(
        id: '3a',
        label: '3e pilier',
        monthlyAmount: threeACapital / _3aAnnualizationYears / 12,
        color: color3a,
      ));
    }

    // ── Libre ────────────────────────────────────────────
    final libreCapital = _projectLibreToRetirement(
      currentInvestments: profile.patrimoine.investissements,
      currentSavings: profile.patrimoine.epargneLiquide,
      monthlyInvestment: profile.totalEpargneLibreMensuel,
      yearsToRetirement: (ageUser - profile.age).clamp(0, 50),
    );
    if (libreCapital > 0) {
      sources.add(RetirementIncomeSource(
        id: 'libre',
        label: 'Patrimoine libre',
        monthlyAmount: libreCapital * _safeWithdrawalRate / 12,
        color: colorLibre,
      ));
    }

    return sources;
  }

  // ════════════════════════════════════════════════════════════
  //  3a PROJECTION
  // ════════════════════════════════════════════════════════════

  static double _project3aToRetirement({
    required double currentBalance,
    required double monthly3a,
    required int yearsToRetirement,
    required double averageReturn,
    bool isIndependantSansLpp = false,
  }) {
    double balance = currentBalance;
    // Plafond legal: 7'258 CHF/an si affilie LPP, 36'288 CHF/an si
    // independant sans LPP (OPP3 art. 7). Pour un couple on cumule les deux.
    final plafondIndividuel = isIndependantSansLpp
        ? pilier3aPlafondSansLpp
        : pilier3aPlafondAvecLpp;
    // Max 2 personnes dans le menage
    final annual3a = (monthly3a * 12).clamp(0.0, plafondIndividuel * 2);

    for (int y = 0; y < yearsToRetirement; y++) {
      balance *= (1 + averageReturn);
      balance += annual3a;
    }
    return balance;
  }

  static double _average3aReturn(CoachProfile profile) {
    final comptes = profile.prevoyance.comptes3a;
    if (comptes.isEmpty) return 0.04;
    final weightedSum =
        comptes.fold(0.0, (s, c) => s + c.rendementEstime * c.solde);
    final totalSolde = comptes.fold(0.0, (s, c) => s + c.solde);
    return totalSolde > 0 ? weightedSum / totalSolde : 0.04;
  }

  // ════════════════════════════════════════════════════════════
  //  LIBRE PROJECTION
  // ════════════════════════════════════════════════════════════

  static double _projectLibreToRetirement({
    required double currentInvestments,
    required double currentSavings,
    required double monthlyInvestment,
    required int yearsToRetirement,
  }) {
    double invest = currentInvestments;
    double savings = currentSavings;

    for (int y = 0; y < yearsToRetirement; y++) {
      invest *= 1.05;
      invest += monthlyInvestment * 12;
      savings *= 1.01;
    }
    return invest + savings;
  }

  // ════════════════════════════════════════════════════════════
  //  COUPLE PHASES
  // ════════════════════════════════════════════════════════════

  static List<RetirementPhase> _computePhases({
    required CoachProfile profile,
    required int ageUser,
    int ageConjoint = 65,
    double lppCapitalPct = 0.0,
  }) {
    final hasConjoint =
        profile.isCouple && profile.conjoint?.birthYear != null;
    final userName = profile.firstName ?? 'Toi';

    if (!hasConjoint) {
      return [
        RetirementPhase(
          label: 'Retraite',
          startYear: profile.birthYear + ageUser,
          sources: _computeIncomes(profile: profile, ageUser: ageUser, lppCapitalPct: lppCapitalPct),
        ),
      ];
    }

    final conjName = profile.conjoint!.firstName ?? 'Conjoint·e';
    final retireYearUser = profile.birthYear + ageUser;
    final retireYearConj = profile.conjoint!.birthYear! + ageConjoint;

    if (retireYearUser == retireYearConj) {
      return [
        RetirementPhase(
          label: 'Les deux a la retraite',
          startYear: retireYearUser,
          sources: _computeIncomes(
              profile: profile, ageUser: ageUser, ageConjoint: ageConjoint, lppCapitalPct: lppCapitalPct),
        ),
      ];
    }

    final userFirst = retireYearUser < retireYearConj;
    final firstYear = min(retireYearUser, retireYearConj);
    final secondYear = max(retireYearUser, retireYearConj);

    // Phase 1: first person retired, second still working
    final phase1 = _buildTransitionPhase(
      profile: profile,
      ageUser: ageUser,
      ageConjoint: ageConjoint,
      userRetiresFirst: userFirst,
      lppCapitalPct: lppCapitalPct,
    );

    // Phase 2: both retired — adjust 3a/libre for capital already consumed
    // during Phase 1 transition period.
    final phase2Sources = _computeIncomes(
      profile: profile,
      ageUser: ageUser,
      ageConjoint: ageConjoint,
      lppCapitalPct: lppCapitalPct,
    );

    // Deduplication: Phase 1 already drew down 3a/libre capital.
    // Reduce Phase 2 amounts by what was consumed during transition years.
    final transitionYears = (secondYear - firstYear).clamp(0, 10);
    if (transitionYears > 0) {
      for (int i = 0; i < phase2Sources.length; i++) {
        final src = phase2Sources[i];
        if (src.id == '3a') {
          // 3a capital consumed during Phase 1
          final phase1_3a = phase1
              .where((s) => s.id == '3a')
              .fold(0.0, (sum, s) => sum + s.monthlyAmount);
          final consumed = phase1_3a * 12 * transitionYears;
          // Remaining 3a capital = original - consumed, re-annualized
          final original3aMonthly =
              src.monthlyAmount * _3aAnnualizationYears * 12;
          final remaining = (original3aMonthly - consumed).clamp(0.0, double.infinity);
          phase2Sources[i] = RetirementIncomeSource(
            id: src.id,
            label: src.label,
            monthlyAmount: remaining / _3aAnnualizationYears / 12,
            color: src.color,
            isIndexed: src.isIndexed,
          );
        } else if (src.id == 'libre') {
          // Libre: 4% SWR means capital is largely preserved (Trinity study),
          // no deduction needed — the withdrawal rate is sustainable.
        }
      }
    }

    return [
      RetirementPhase(
        label: userFirst
            ? '$userName retraite·e, $conjName actif·ve'
            : '$conjName retraite·e, $userName actif·ve',
        startYear: firstYear,
        endYear: secondYear,
        sources: phase1,
      ),
      RetirementPhase(
        label: 'Les deux a la retraite',
        startYear: secondYear,
        sources: phase2Sources,
      ),
    ];
  }

  static List<RetirementIncomeSource> _buildTransitionPhase({
    required CoachProfile profile,
    required int ageUser,
    required int ageConjoint,
    required bool userRetiresFirst,
    double lppCapitalPct = 0.0,
  }) {
    final sources = <RetirementIncomeSource>[];
    final userName = profile.firstName ?? 'Toi';
    final conjName = profile.conjoint?.firstName ?? 'Conjoint·e';

    if (userRetiresFirst) {
      // User AVS (no couple cap — only user receives)
      final avsUser = AvsCalculator.computeMonthlyRente(
        currentAge: profile.age,
        retirementAge: ageUser,
        lacunes: profile.prevoyance.lacunesAVS ?? 0,
        anneesContribuees: profile.prevoyance.anneesContribuees,
        arrivalAge: profile.arrivalAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
      );
      sources.add(RetirementIncomeSource(
        id: 'avs_user',
        label: 'AVS $userName',
        monthlyAmount: avsUser,
        color: colorAvs,
        isIndexed: true,
      ));

      // User LPP — independants without LPP: no bonifications (LPP art. 4)
      final userHasLpp = (profile.prevoyance.avoirLppTotal ?? 0) > 0 ||
          profile.employmentStatus != 'independant';
      final lppUser = LppCalculator.projectToRetirement(
        currentBalance: profile.prevoyance.avoirLppTotal ?? 0,
        currentAge: profile.age,
        retirementAge: ageUser,
        grossAnnualSalary: userHasLpp ? profile.revenuBrutAnnuel : 0,
        caisseReturn: profile.prevoyance.rendementCaisse,
        conversionRate: profile.prevoyance.tauxConversion,
        monthlyBuyback: _userLppBuyback(profile),
        buybackCap: profile.prevoyance.lacuneRachatRestante,
      );
      final lppSuffix = lppCapitalPct >= 1.0
          ? ' (capital)'
          : lppCapitalPct > 0
              ? ' (mixte)'
              : '';
      final isMarriedForTax =
          profile.etatCivil == CoachCivilStatus.marie;
      final lppUserMonthly = LppCalculator.blendedMonthly(
        annualRente: lppUser,
        conversionRate: profile.prevoyance.tauxConversion,
        lppCapitalPct: lppCapitalPct,
        canton: profile.canton,
        isMarried: isMarriedForTax,
      );
      sources.add(RetirementIncomeSource(
        id: 'lpp_user',
        label: 'LPP $userName$lppSuffix',
        monthlyAmount: lppUserMonthly,
        color: colorLpp,
        isCapitalWithdrawal: lppCapitalPct > 0,
      ));

      // Conjoint salary (still working)
      final conjNet = profile.conjoint!.revenuBrutAnnuel * 0.87 / 12;
      if (conjNet > 0) {
        sources.add(RetirementIncomeSource(
          id: 'salary_conjoint',
          label: 'Salaire $conjName',
          monthlyAmount: conjNet,
          color: colorSalary,
        ));
      }
    } else {
      // Conjoint AVS (no couple cap — only conjoint receives)
      final avsConj = AvsCalculator.computeMonthlyRente(
        currentAge: profile.conjoint!.age ?? 45,
        retirementAge: ageConjoint,
        lacunes: profile.conjoint?.prevoyance?.lacunesAVS ?? 0,
        anneesContribuees: profile.conjoint?.prevoyance?.anneesContribuees,
        arrivalAge: profile.conjoint!.arrivalAge,
        grossAnnualSalary: profile.conjoint!.revenuBrutAnnuel,
      );
      sources.add(RetirementIncomeSource(
        id: 'avs_conjoint',
        label: 'AVS $conjName',
        monthlyAmount: avsConj,
        color: const Color(0xFF4DA6FF),
        isIndexed: true,
      ));

      // Conjoint LPP
      final conjPrev = profile.conjoint!.prevoyance;
      final lppConj = LppCalculator.projectToRetirement(
        currentBalance: conjPrev?.avoirLppTotal ?? 0,
        currentAge: profile.conjoint!.age ?? 45,
        retirementAge: ageConjoint,
        grossAnnualSalary: profile.conjoint!.revenuBrutAnnuel,
        caisseReturn: conjPrev?.rendementCaisse ?? 0.02,
        conversionRate: conjPrev?.tauxConversion ?? 0.068,
        monthlyBuyback: _conjointLppBuyback(profile),
        buybackCap: conjPrev?.lacuneRachatRestante ?? 0,
      );
      if (lppConj > 0) {
        final lppSuffix = lppCapitalPct >= 1.0
            ? ' (capital)'
            : lppCapitalPct > 0
                ? ' (mixte)'
                : '';
        final isMarriedForTax =
            profile.etatCivil == CoachCivilStatus.marie;
        final lppConjMonthly = LppCalculator.blendedMonthly(
          annualRente: lppConj,
          conversionRate: conjPrev?.tauxConversion ?? 0.068,
          lppCapitalPct: lppCapitalPct,
          canton: profile.canton,
          isMarried: isMarriedForTax,
        );
        sources.add(RetirementIncomeSource(
          id: 'lpp_conjoint',
          label: 'LPP $conjName$lppSuffix',
          monthlyAmount: lppConjMonthly,
          color: const Color(0xFF4CAF50),
          isCapitalWithdrawal: lppCapitalPct > 0,
        ));
      }

      // User salary (still working)
      final userNet = profile.revenuBrutAnnuel * 0.87 / 12;
      if (userNet > 0) {
        sources.add(RetirementIncomeSource(
          id: 'salary_user',
          label: 'Salaire $userName',
          monthlyAmount: userNet,
          color: colorSalary,
        ));
      }
    }

    // 3a + libre — project to the FIRST retiree's horizon, not always user's.
    // If conjoint retires first, capital stops accumulating at that date.
    final firstRetirementAge = userRetiresFirst
        ? ageUser
        : ageConjoint;
    final conjAge = profile.conjoint?.age ?? 45;
    final yearsToFirstRetirement = userRetiresFirst
        ? (firstRetirementAge - profile.age).clamp(0, 50)
        : (firstRetirementAge - conjAge).clamp(0, 50);

    final isIndepSansLpp = profile.employmentStatus == 'independant' &&
        profile.revenuBrutAnnuel < lppSeuilEntree;
    final threeACapitalBrut = _project3aToRetirement(
      currentBalance: profile.prevoyance.totalEpargne3a +
          (profile.conjoint?.prevoyance?.totalEpargne3a ?? 0),
      monthly3a: profile.total3aMensuel,
      yearsToRetirement: yearsToFirstRetirement,
      averageReturn: _average3aReturn(profile),
      isIndependantSansLpp: isIndepSansLpp,
    );
    // Apply capital withdrawal tax (LIFD art. 38) before annualizing
    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final threeACapital = threeACapitalBrut -
        RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: threeACapitalBrut,
          canton: canton,
        );
    if (threeACapital > 0) {
      sources.add(RetirementIncomeSource(
        id: '3a',
        label: '3e pilier',
        monthlyAmount: threeACapital / _3aAnnualizationYears / 12,
        color: color3a,
      ));
    }

    final libreCapital = _projectLibreToRetirement(
      currentInvestments: profile.patrimoine.investissements,
      currentSavings: profile.patrimoine.epargneLiquide,
      monthlyInvestment: profile.totalEpargneLibreMensuel,
      yearsToRetirement: yearsToFirstRetirement,
    );
    if (libreCapital > 0) {
      sources.add(RetirementIncomeSource(
        id: 'libre',
        label: 'Patrimoine libre',
        monthlyAmount: libreCapital * _safeWithdrawalRate / 12,
        color: colorLibre,
      ));
    }

    return sources;
  }

  // ════════════════════════════════════════════════════════════
  //  EARLY RETIREMENT COMPARISON (63-70)
  // ════════════════════════════════════════════════════════════

  static List<EarlyRetirementScenario> _computeEarlyRetirementComparisons({
    required CoachProfile profile,
    int ageConjoint = 65,
    double lppCapitalPct = 0.0,
  }) {
    final hasConjoint =
        profile.isCouple && profile.conjoint?.birthYear != null;

    // Helper: for a given user retirement age, compute the correct income
    // sources respecting whether the conjoint is also retired at that point.
    List<RetirementIncomeSource> sourcesForAge(int userAge) {
      if (!hasConjoint) {
        return _computeIncomes(profile: profile, ageUser: userAge, lppCapitalPct: lppCapitalPct);
      }
      // Year the user reaches userAge
      final yearUser = profile.birthYear + userAge;
      final yearConj = profile.conjoint!.birthYear! + ageConjoint;

      if (yearUser >= yearConj) {
        // Both retired → use full _computeIncomes (couple AVS cap if married)
        return _computeIncomes(
          profile: profile,
          ageUser: userAge,
          ageConjoint: ageConjoint,
          lppCapitalPct: lppCapitalPct,
        );
      } else {
        // Only user retired, conjoint still working → transition phase
        return _buildTransitionPhase(
          profile: profile,
          ageUser: userAge,
          ageConjoint: ageConjoint,
          userRetiresFirst: true,
          lppCapitalPct: lppCapitalPct,
        );
      }
    }

    final ref = sourcesForAge(65);
    final refTotal = ref.fold(0.0, (sum, s) => sum + s.monthlyAmount);
    final scenarios = <EarlyRetirementScenario>[];

    for (int age = 63; age <= 70; age++) {
      final sources = sourcesForAge(age);
      final total = sources.fold(0.0, (sum, s) => sum + s.monthlyAmount);

      double adjustmentPct = 0;
      if (age < 65) {
        adjustmentPct = -(avsReductionAnticipation * (65 - age) * 100);
      } else if (age > 65) {
        final bonus =
            RetirementService.avsDeferralBonus[(age - 65).clamp(1, 5)];
        adjustmentPct = (bonus ?? 0) * 100;
      }

      final yearsThis = _lifeExpectancy - age;
      final yearsRef = _lifeExpectancy - 65;
      final cumulative =
          (total * 12 * yearsThis) - (refTotal * 12 * yearsRef);

      scenarios.add(EarlyRetirementScenario(
        retirementAge: age,
        sources: sources,
        totalMonthly: total,
        adjustmentPct: adjustmentPct,
        cumulativeDifference: cumulative,
      ));
    }

    return scenarios;
  }

  // ════════════════════════════════════════════════════════════
  //  BUDGET GAP
  // ════════════════════════════════════════════════════════════

  static RetirementBudgetGap _computeBudgetGap({
    required CoachProfile profile,
    required List<RetirementIncomeSource> incomes,
    required double depensesMensuelles,
  }) {
    final totalRevenus =
        incomes.fold(0.0, (sum, s) => sum + s.monthlyAmount);

    double avs = 0, lpp = 0, troisA = 0, libre = 0;
    for (final s in incomes) {
      if (s.id.startsWith('avs')) {
        avs += s.monthlyAmount;
      } else if (s.id.startsWith('lpp')) {
        lpp += s.monthlyAmount;
      } else if (s.id == '3a') {
        troisA += s.monthlyAmount;
      } else if (s.id == 'libre') {
        libre += s.monthlyAmount;
      }
    }

    // Estimate tax at retirement.
    // Exclude capital withdrawal sources (LPP capital SWR) from taxable
    // income: capital is already taxed at withdrawal under LIFD art. 38.
    // The SWR drawdown is consumption of own patrimony, not taxable income.
    final revenuImposableMensuel = incomes
        .where((s) => !s.isCapitalWithdrawal)
        .fold(0.0, (sum, s) => sum + s.monthlyAmount);
    final impotMensuel = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: revenuImposableMensuel * 12,
      canton: profile.canton,
      etatCivil: profile.isCouple ? 'marie' : 'celibataire',
    );

    final revenuPreRetraite = profile.revenuBrutAnnuel * 0.87 / 12 +
        (profile.conjoint?.revenuBrutAnnuel ?? 0) * 0.87 / 12;
    final tauxRemplacement =
        revenuPreRetraite > 0 ? totalRevenus / revenuPreRetraite * 100 : 0.0;

    final solde = totalRevenus - impotMensuel - depensesMensuelles;

    final alertes = <String>[];
    if (solde < 0) {
      alertes.add(
        'Deficit mensuel estime de CHF ${solde.abs().toStringAsFixed(0)}. '
        'Des ajustements de budget ou de prevoyance pourraient etre envisages.',
      );
    }
    if (tauxRemplacement < 60) {
      alertes.add(
        'Taux de remplacement de ${tauxRemplacement.toStringAsFixed(0)}% — '
        'en dessous du seuil de confort habituel (60-80%).',
      );
    }
    final pcSeuil = profile.isCouple ? 4500.0 : 3000.0;
    if (totalRevenus < pcSeuil) {
      alertes.add(
        'Tu pourrais potentiellement etre eligible aux prestations '
        'complementaires (PC). Renseigne-toi aupres de ton office cantonal.',
      );
    }

    return RetirementBudgetGap(
      totalRevenusMensuel: totalRevenus,
      avsMensuel: avs,
      lppMensuel: lpp,
      troisAMensuel: troisA,
      libreMensuel: libre,
      impotEstimeMensuel: impotMensuel,
      depensesMensuelles: depensesMensuelles,
      soldeMensuel: solde,
      tauxRemplacement: tauxRemplacement,
      alertes: alertes,
    );
  }

  static double _estimateRetirementExpenses(CoachProfile profile) {
    final householdNet = profile.salaireBrutMensuel * 0.87 +
        (profile.conjoint?.salaireBrutMensuel ?? 0) * 0.87;
    // Income-based floor: 70% of household net (Swiss retirement planning standard)
    final incomeFloor = householdNet * 0.70;

    final current = profile.depenses.totalMensuel;
    if (current > 0) {
      // 85% of current expenses (retirement rule), floored by income estimate
      // to catch incomplete budget data.
      return max(current * 0.85, incomeFloor);
    }
    // No expense data: 75% of household net income
    return householdNet > 0 ? householdNet * 0.75 : 5000;
  }

  // ════════════════════════════════════════════════════════════
  //  INDEXED PROJECTION (25 years)
  // ════════════════════════════════════════════════════════════

  static List<IndexedProjectionPoint> _computeIndexedProjection({
    required CoachProfile profile,
    required int retirementAge,
    required List<RetirementIncomeSource> incomeSources,
  }) {
    final startYear = profile.birthYear + retirementAge;

    double indexedMonthly = 0;
    double nonIndexedMonthly = 0;
    for (final s in incomeSources) {
      if (s.isIndexed) {
        indexedMonthly += s.monthlyAmount;
      } else {
        nonIndexedMonthly += s.monthlyAmount;
      }
    }

    final points = <IndexedProjectionPoint>[];
    for (int y = 0; y <= _projectionYears; y++) {
      final indexedAtYear = indexedMonthly * pow(1 + _avsIndexationRate, y);
      final nominal = indexedMonthly + nonIndexedMonthly;
      final indexed = indexedAtYear + nonIndexedMonthly;
      final pouvoirAchat = indexed / pow(1 + _inflationRate, y);

      points.add(IndexedProjectionPoint(
        year: startYear + y,
        age: retirementAge + y,
        revenuNominal: nominal,
        revenuIndexe: indexed,
        pouvoirAchat: pouvoirAchat,
      ));
    }

    return points;
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  static double _userLppBuyback(CoachProfile profile) {
    double total = 0;
    for (final c in profile.plannedContributions) {
      if (c.category == 'lpp_buyback' && !_isConjointContrib(c, profile)) {
        total += c.amount;
      }
    }
    return total;
  }

  static double _conjointLppBuyback(CoachProfile profile) {
    double total = 0;
    for (final c in profile.plannedContributions) {
      if (c.category == 'lpp_buyback' && _isConjointContrib(c, profile)) {
        total += c.amount;
      }
    }
    return total;
  }

  static bool _isConjointContrib(
    PlannedMonthlyContribution c,
    CoachProfile profile,
  ) {
    if (profile.conjoint?.firstName == null) return false;
    final name = profile.conjoint!.firstName!.toLowerCase();
    return c.id.toLowerCase().contains(name) ||
        c.label.toLowerCase().contains(name);
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    final prefix = intVal < 0 ? '-' : '';
    return '${prefix}CHF\u00A0${buffer.toString()}';
  }
}
