import 'dart:math' as math;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  ARBITRAGE SUMMARY SERVICE — S45 Phase 1
// ────────────────────────────────────────────────────────────
//
//  Orchestrates all 5 ArbitrageEngine comparisons from a
//  CoachProfile. No calculation duplication — calls ArbitrageEngine
//  for each, aggregates results.
//
//  Pure static methods — no side effects, no Provider dependency.
// ────────────────────────────────────────────────────────────

/// A single arbitrage result summary item.
class ArbitrageSummaryItem {
  final String id;
  final String title;
  final String verdict;
  final String keyInsight;
  final double monthlyImpactChf;
  final double confidenceScore;
  final String route;
  final ArbitrageResult fullResult;

  const ArbitrageSummaryItem({
    required this.id,
    required this.title,
    required this.verdict,
    required this.keyInsight,
    required this.monthlyImpactChf,
    required this.confidenceScore,
    required this.route,
    required this.fullResult,
  });
}

/// An arbitrage that cannot be computed due to missing data.
class ArbitrageLocked {
  final String id;
  final String title;
  final String missingDataPrompt;
  final String enrichmentRoute;

  const ArbitrageLocked({
    required this.id,
    required this.title,
    required this.missingDataPrompt,
    required this.enrichmentRoute,
  });
}

/// Full summary of all arbitrages for a given profile.
class ArbitrageSummary {
  final List<ArbitrageSummaryItem> items;
  final List<ArbitrageLocked> lockedItems;
  final double aggregateMonthlyImpact;
  final DateTime computedAt;

  const ArbitrageSummary({
    required this.items,
    required this.lockedItems,
    required this.aggregateMonthlyImpact,
    required this.computedAt,
  });
}

class ArbitrageSummaryService {
  ArbitrageSummaryService._();

  /// Compute all arbitrages from a profile.
  /// Returns items sorted by absolute monthly impact (descending).
  ///
  /// Pass [l] (S) for localized titles and prompts.
  static ArbitrageSummary compute(CoachProfile profile, {S? l}) {
    final items = <ArbitrageSummaryItem>[];
    final locked = <ArbitrageLocked>[];

    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final lppAvoir = profile.prevoyance.avoirLppTotal ?? 0;
    final total3a = profile.prevoyance.totalEpargne3a;
    final lacune = profile.prevoyance.lacuneRachatRestante;
    final loyer = profile.depenses.loyer;
    final salary = profile.revenuBrutAnnuel;
    final anneesRetraite = profile.anneesAvantRetraite;

    // ── 1. Rente vs Capital ──
    if (lppAvoir > 0) {
      final item = _computeRenteVsCapital(
        profile: profile,
        canton: canton,
        isMarried: isMarried,
        lppAvoir: lppAvoir,
      );
      if (item != null) items.add(item);
    } else {
      locked.add(ArbitrageLocked(
        id: 'rente_vs_capital',
        title: l?.arbitrageTitleRenteVsCapital ?? 'Rente vs Capital',
        missingDataPrompt:
            l?.arbitrageMissingLpp ?? 'Ajoute ton avoir LPP pour voir cette comparaison',
        enrichmentRoute: '/scan',
      ));
    }

    // ── 2. Calendrier retraits ──
    if (lppAvoir > 0 && total3a > 0) {
      final item = _computeCalendrierRetraits(
        profile: profile,
        canton: canton,
        isMarried: isMarried,
        lppAvoir: lppAvoir,
        total3a: total3a,
      );
      if (item != null) items.add(item);
    } else if (lppAvoir <= 0 || total3a <= 0) {
      locked.add(ArbitrageLocked(
        id: 'calendrier_retraits',
        title: l?.arbitrageTitleCalendrierRetraits ?? 'Calendrier de retraits',
        missingDataPrompt:
            l?.arbitrageMissingLppAnd3a ?? 'Ajoute ton avoir LPP et 3a pour voir le calendrier',
        enrichmentRoute: '/scan',
      ));
    }

    // ── 3. Rachat LPP vs Marche ──
    if (lacune > 1000 && salary > 0) {
      final item = _computeRachatVsMarche(
        profile: profile,
        canton: canton,
        isMarried: isMarried,
        lacune: lacune,
        salary: salary,
        anneesRetraite: anneesRetraite,
      );
      if (item != null) items.add(item);
    } else if (lppAvoir > 0 && lacune <= 1000) {
      // No locked card — no buyback gap, that's fine
    } else {
      locked.add(ArbitrageLocked(
        id: 'rachat_vs_marche',
        title: l?.arbitrageTitleRachatVsMarche ?? 'Rachat LPP vs March\u00e9',
        missingDataPrompt:
            l?.arbitrageMissingLppCertificat ?? 'Scanne ton certificat LPP pour conna\u00eetre ta lacune de rachat',
        enrichmentRoute: '/scan',
      ));
    }

    // ── 4. Allocation annuelle ──
    if (salary > 0) {
      final item = _computeAllocationAnnuelle(
        profile: profile,
        canton: canton,
        lacune: lacune,
        salary: salary,
        anneesRetraite: anneesRetraite,
      );
      if (item != null) items.add(item);
    }

    // ── 5. Location vs Propriete ──
    if (loyer > 0 && profile.housingStatus != 'proprietaire') {
      final item = _computeLocationVsPropriete(
        profile: profile,
        canton: canton,
        isMarried: isMarried,
        loyer: loyer,
      );
      if (item != null) items.add(item);
    }

    // ── 6. Échelonnement couple ──
    if (profile.isCouple && profile.conjoint != null && lppAvoir > 0) {
      final conjLpp = profile.conjoint!.prevoyance?.avoirLppTotal ?? 0;
      if (conjLpp > 0) {
        final item = _computeCoupleSequencing(
          profile: profile,
          canton: canton,
          isMarried: isMarried,
          userCapital: lppAvoir,
          conjointCapital: conjLpp,
        );
        if (item != null) items.add(item);
      }
    }

    // Sort by absolute impact descending
    items.sort(
        (a, b) => b.monthlyImpactChf.abs().compareTo(a.monthlyImpactChf.abs()));

    final aggregate = items.fold(0.0, (sum, i) => sum + i.monthlyImpactChf);

    return ArbitrageSummary(
      items: items,
      lockedItems: locked,
      aggregateMonthlyImpact: aggregate,
      computedAt: DateTime.now(),
    );
  }

  // ── Private computation helpers ──

  static ArbitrageSummaryItem? _computeRenteVsCapital({
    required CoachProfile profile,
    required String canton,
    required bool isMarried,
    required double lppAvoir,
  }) {
    final convRate = profile.prevoyance.tauxConversion;
    final result = ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: lppAvoir,
      capitalObligatoire: lppAvoir * 0.6,
      capitalSurobligatoire: lppAvoir * 0.4,
      renteAnnuelleProposee: lppAvoir * convRate,
      tauxConversionObligatoire: reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal),
      tauxConversionSurobligatoire: convRate,
      canton: canton,
      isMarried: isMarried,
      dataSources: profile.dataSources,
      currentAge: profile.age,
      grossAnnualSalary: profile.revenuBrutAnnuel,
      caisseReturn: profile.prevoyance.rendementCaisse,
    );

    final diff =
        (result.capitalRetraitMensuel - result.renteNetMensuelle).abs();
    if (diff < 10) return null;

    final betterLabel = result.capitalRetraitMensuel > result.renteNetMensuelle
        ? 'retrait en capital'
        : 'rente viagere';

    return ArbitrageSummaryItem(
      id: 'rente_vs_capital',
      title: 'Rente vs Capital',
      verdict:
          'L\'option $betterLabel pourrait donner +${formatChfWithPrefix(diff)}/mois nets',
      keyInsight:
          'Le taux de conversion de 6.8% sur la part obligatoire equivaut '
          'a un rendement implicite d\'environ 5%.',
      monthlyImpactChf: diff,
      confidenceScore: result.confidenceScore,
      route: '/rente-vs-capital',
      fullResult: result,
    );
  }

  static ArbitrageSummaryItem? _computeCalendrierRetraits({
    required CoachProfile profile,
    required String canton,
    required bool isMarried,
    required double lppAvoir,
    required double total3a,
  }) {
    final assets = <RetirementAsset>[
      RetirementAsset(
        type: 'lpp',
        amount: lppAvoir * 0.4, // 40% capital assumption
        earliestWithdrawalAge: profile.effectiveRetirementAge,
      ),
      RetirementAsset(
        type: '3a',
        amount: total3a,
        earliestWithdrawalAge: profile.effectiveRetirementAge - 5,
      ),
    ];

    // Add conjoint assets if couple
    if (profile.isCouple && profile.conjoint != null) {
      final conj = profile.conjoint!;
      final conjLpp = conj.prevoyance?.avoirLppTotal ?? 0;
      final conj3a = conj.prevoyance?.totalEpargne3a ?? 0;
      if (conjLpp > 0) {
        assets.add(RetirementAsset(
          type: 'lpp',
          amount: conjLpp * 0.4,
          earliestWithdrawalAge: conj.effectiveRetirementAge,
        ));
      }
      if (conj3a > 0) {
        assets.add(RetirementAsset(
          type: '3a',
          amount: conj3a,
          earliestWithdrawalAge: conj.effectiveRetirementAge - 5,
        ));
      }
    }

    final result = ArbitrageEngine.compareCalendrierRetraits(
      assets: assets,
      ageRetraite: profile.effectiveRetirementAge,
      canton: canton,
      isMarried: isMarried,
      dataSources: profile.dataSources,
    );

    // Extract tax saving: compare option A (tout en 1 fois) vs option B (echelonne)
    if (result.options.length < 2) return null;
    final taxAllAtOnce = result.options.first.cumulativeTaxImpact;
    final taxStaggered = result.options.last.cumulativeTaxImpact;
    final saving = (taxAllAtOnce - taxStaggered).abs();
    if (saving < 500) return null;

    return ArbitrageSummaryItem(
      id: 'calendrier_retraits',
      title: 'Calendrier de retraits',
      verdict:
          'Echelonner tes retraits pourrait economiser ~${formatChfWithPrefix(saving)} d\'impot',
      keyInsight: 'En Suisse, les retraits de prevoyance sont taxes '
          'progressivement — retirer tout la meme annee coute significativement plus.',
      monthlyImpactChf: saving / (profile.anneesAvantRetraite * 12).clamp(1, 999),
      confidenceScore: result.confidenceScore,
      route: '/decaissement',
      fullResult: result,
    );
  }

  static ArbitrageSummaryItem? _computeRachatVsMarche({
    required CoachProfile profile,
    required String canton,
    required bool isMarried,
    required double lacune,
    required double salary,
    required int anneesRetraite,
  }) {
    final tauxMarginal = salary > 150000
        ? 0.35
        : salary > 100000
            ? 0.30
            : 0.25;
    final montant = math.min(lacune, 30000.0); // typical annual buyback

    // Wave 7 A7 wiring (2026-04-18): plumb the planned capital withdrawal
    // horizon so the ATF 142 II 399 / LPP art. 79b al. 3 anti-abuse alert
    // actually fires when the user is planning an EPL (achat immo) within
    // 3 years of the rachat. Retirement itself also counts as a capital
    // retrait (rente vs capital choice), so we signal both goal types.
    final now = DateTime.now();
    final goalYears = profile.goalA.targetDate.year - now.year;
    int? plannedWithdrawalYears;
    if (profile.goalA.type == GoalAType.achatImmo && goalYears >= 0) {
      plannedWithdrawalYears = goalYears;
    } else if (profile.goalA.type == GoalAType.retraite &&
        goalYears >= 0 &&
        goalYears < 3) {
      // Retraite effective dans < 3 ans → même trap si rachat maintenant.
      plannedWithdrawalYears = goalYears;
    }

    final result = ArbitrageEngine.compareRachatVsMarche(
      montant: montant,
      tauxMarginal: tauxMarginal,
      anneesAvantRetraite: anneesRetraite,
      canton: canton,
      isMarried: isMarried,
      dataSources: profile.dataSources,
      plannedCapitalWithdrawalYearsFromNow: plannedWithdrawalYears,
    );

    final taxSaving = montant * tauxMarginal;
    if (taxSaving < 500) return null;

    return ArbitrageSummaryItem(
      id: 'rachat_vs_marche',
      title: 'Rachat LPP vs Marche',
      verdict:
          'Un rachat de ${formatChfWithPrefix(montant)} pourrait reduire ton impot de ~${formatChfWithPrefix(taxSaving)}',
      keyInsight: 'L\'economie fiscale du rachat est immediate, mais ton '
          'capital est bloque jusqu\'a la retraite (LPP art. 79b).',
      monthlyImpactChf: taxSaving / 12,
      confidenceScore: result.confidenceScore,
      route: '/rachat-lpp',
      fullResult: result,
    );
  }

  static ArbitrageSummaryItem? _computeAllocationAnnuelle({
    required CoachProfile profile,
    required String canton,
    required double lacune,
    required double salary,
    required int anneesRetraite,
  }) {
    final tauxMarginal = salary > 150000
        ? 0.35
        : salary > 100000
            ? 0.30
            : 0.25;

    final result = ArbitrageEngine.compareAllocationAnnuelle(
      montantDisponible: reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp),
      tauxMarginal: tauxMarginal,
      potentielRachatLpp: lacune,
      anneesAvantRetraite: anneesRetraite,
      canton: canton,
      dataSources: profile.dataSources,
    );

    // The premierEclairage tells the story — extract monthly impact
    // 3a deduction gives immediate tax savings
    final impact3a = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) * tauxMarginal / 12;

    return ArbitrageSummaryItem(
      id: 'allocation_annuelle',
      title: 'Allocation annuelle',
      verdict:
          '${formatChfWithPrefix(reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp))} a placer — 3a, rachat LPP ou libre, les trajectoires divergent',
      keyInsight:
          'Le 3e pilier offre une deduction fiscale immediate et un rendement '
          'net apres impot souvent superieur.',
      monthlyImpactChf: impact3a,
      confidenceScore: result.confidenceScore,
      route: '/arbitrage/allocation-annuelle',
      fullResult: result,
    );
  }

  static ArbitrageSummaryItem? _computeLocationVsPropriete({
    required CoachProfile profile,
    required String canton,
    required bool isMarried,
    required double loyer,
  }) {
    final capitalDispo = profile.patrimoine.epargneLiquide +
        profile.patrimoine.investissements;
    if (capitalDispo < 50000) return null;

    // Estimate property price from rent: ~3.5% gross yield
    final prixBien = loyer * 12 / 0.035;

    final result = ArbitrageEngine.compareLocationVsPropriete(
      capitalDisponible: capitalDispo,
      loyerMensuelActuel: loyer,
      prixBien: prixBien,
      canton: canton,
      isMarried: isMarried,
      dataSources: profile.dataSources,
    );

    // Compare terminal values
    if (result.options.length < 2) return null;
    final locataire = result.options.first.terminalValue;
    final proprio = result.options.last.terminalValue;
    final delta = (proprio - locataire).abs();
    final deltaMonthly = delta / (20 * 12);
    if (deltaMonthly < 50) return null;

    final betterLabel = proprio > locataire ? 'acheter' : 'rester locataire';

    return ArbitrageSummaryItem(
      id: 'location_vs_propriete',
      title: 'Location vs Propriete',
      verdict:
          'Sur 20 ans, $betterLabel pourrait generer ~${formatChfWithPrefix(delta)} de patrimoine net en plus',
      keyInsight:
          'La propriete bloque 20% de fonds propres a rendement nul — '
          'un cout d\'opportunite rarement mesure.',
      monthlyImpactChf: deltaMonthly,
      confidenceScore: result.confidenceScore,
      route: '/arbitrage/location-vs-propriete',
      fullResult: result,
    );
  }

  static ArbitrageSummaryItem? _computeCoupleSequencing({
    required CoachProfile profile,
    required String canton,
    required bool isMarried,
    required double userCapital,
    required double conjointCapital,
  }) {
    final result = LppCalculator.compareRetirementSequencing(
      userCapital: userCapital,
      conjointCapital: conjointCapital,
      canton: canton,
      isMarried: isMarried,
    );

    if (result.taxSaving < 500) return null;

    final monthlyImpact =
        result.taxSaving / (profile.anneesAvantRetraite * 12).clamp(1, 999);

    // Build a minimal ArbitrageResult to satisfy the fullResult field
    final fullResult = ArbitrageResult(
      options: [
        TrajectoireOption(
          id: 'same_year',
          label: 'Retrait simultané',
          trajectory: const [],
          terminalValue: 0,
          cumulativeTaxImpact: result.taxSameYear,
        ),
        TrajectoireOption(
          id: 'staggered',
          label: 'Retrait échelonné',
          trajectory: const [],
          terminalValue: 0,
          cumulativeTaxImpact: result.taxStaggered,
        ),
      ],
      breakevenYear: null,
      premierEclairage:
          '${formatChfWithPrefix(result.taxSaving)} d\'impot en moins en echelonnant les retraits',
      displaySummary: result.recommendation,
      hypotheses: const [
        'Taux cantonal applique au capital LPP retire',
        'Retraits en 2 annees fiscales distinctes',
      ],
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier au sens de la LSFin.',
      sources: const ['LIFD art. 38', 'LPP art. 37'],
      confidenceScore: 60.0,
      sensitivity: const {},
    );

    return ArbitrageSummaryItem(
      id: 'couple_sequencing',
      title: 'Echelonnement couple',
      verdict: result.recommendation,
      keyInsight:
          'Retirer le capital LPP en 2 annees fiscales distinctes '
          'reduit la progressivite de l\'impot (LIFD art. 38).',
      monthlyImpactChf: monthlyImpact,
      confidenceScore: 60.0,
      route: '/decaissement',
      fullResult: fullResult,
    );
  }
}
