import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ════════════════════════════════════════════════════════════════════════════
//  WITHDRAWAL SEQUENCING SERVICE — Optimisation de la sequence de retrait
// ════════════════════════════════════════════════════════════════════════════
//
// Optimise l'ordre et le timing des retraits de capital (3a, LPP) a la
// retraite pour minimiser la charge fiscale totale.
//
// Base legale:
//   - LIFD art. 38: imposition separee du capital de prevoyance
//   - OPP3 art. 3: retrait anticipe 3a (5 ans avant age de reference AVS)
//   - LPP art. 37: prestations en capital
//
// Principe: les tranches progressives se reinitialisant chaque annee
// fiscale, echelonner les retraits sur plusieurs annees reduit le taux
// moyen d'imposition.
// ════════════════════════════════════════════════════════════════════════════

/// Un evenement de retrait dans la sequence optimisee.
class WithdrawalEvent {
  /// Annee civile du retrait.
  final int year;

  /// Age au moment du retrait.
  final int age;

  /// Identifiant de la source: '3a_1', '3a_2', 'lpp_capital', 'libre'.
  final String source;

  /// Libelle en francais pour l'affichage.
  final String label;

  /// Montant brut en CHF.
  final double amount;

  /// Impot sur ce retrait.
  final double tax;

  /// Montant net apres impot.
  final double netAmount;

  /// Taux effectif (impot / montant brut).
  final double effectiveRate;

  const WithdrawalEvent({
    required this.year,
    required this.age,
    required this.source,
    required this.label,
    required this.amount,
    required this.tax,
    required this.netAmount,
    required this.effectiveRate,
  });
}

/// Resultat de l'optimisation de la sequence de retrait.
class WithdrawalSequencingResult {
  /// Sequence optimisee (chronologique).
  final List<WithdrawalEvent> optimizedSequence;

  /// Sequence naive (tout a la retraite).
  final List<WithdrawalEvent> naiveSequence;

  /// Impot total avec la sequence optimisee.
  final double totalTaxOptimized;

  /// Impot total avec la sequence naive.
  final double totalTaxNaive;

  /// Economies d'impot (naive - optimisee).
  final double taxSavings;

  /// Pourcentage d'economies (taxSavings / totalTaxNaive).
  final double savingsPercent;

  /// Disclaimer reglementaire.
  final String disclaimer;

  /// Sources legales.
  final List<String> sources;

  const WithdrawalSequencingResult({
    required this.optimizedSequence,
    required this.naiveSequence,
    required this.totalTaxOptimized,
    required this.totalTaxNaive,
    required this.taxSavings,
    required this.savingsPercent,
    required this.disclaimer,
    required this.sources,
  });
}

/// Service d'optimisation de la sequence de retrait en capital.
///
/// Calcule la sequence de retraits (3a, LPP capital) qui minimise la
/// charge fiscale totale en echelonnant les retraits sur plusieurs
/// annees fiscales. Pure static, sans etat.
class WithdrawalSequencingService {
  WithdrawalSequencingService._();

  static const String _disclaimer =
      'Simulation pedagogique de la sequence de retrait en capital. '
      "L'optimisation fiscale depend de la legislation cantonale et "
      'de la situation personnelle. Base legale : LIFD art. 38, OPP3 art. 3. '
      'Consulte un ou une specialiste avant toute decision. '
      'Cette simulation ne constitue pas un conseil financier au sens de la LSFin.';

  static const List<String> _sources = [
    'LIFD art. 38 (imposition separee capital prevoyance)',
    'OPP3 art. 3 (retrait anticipe 3a)',
    'LPP art. 37 (prestations en capital)',
  ];

  /// Calcule la sequence de retrait optimale.
  ///
  /// [profile]: profil financier complet.
  /// [retirementAge]: age de retraite prevu (defaut 65).
  /// [lppCapitalPct]: fraction du LPP retiree en capital (0.0 = 100% rente).
  static WithdrawalSequencingResult optimize({
    required CoachProfile profile,
    int retirementAge = 65,
    double lppCapitalPct = 0.0,
  }) {
    final currentYear = DateTime.now().year;
    final currentAge = profile.age;

    // Guard: si la personne est deja a l'age de retraite ou au-dela,
    // aucune optimisation de sequencage n'est possible.
    if (currentAge >= retirementAge) {
      // Personne deja a l'age de retraite ou au-dela
      return const WithdrawalSequencingResult(
        optimizedSequence: [],
        naiveSequence: [],
        totalTaxOptimized: 0,
        totalTaxNaive: 0,
        taxSavings: 0,
        savingsPercent: 0,
        disclaimer: _disclaimer,
        sources: _sources,
      );
    }

    final canton = profile.canton.isNotEmpty
        ? profile.canton.toUpperCase()
        : 'ZH';
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;

    // ── 1. Collecter les sources de capital ───────────────────────
    final capitalSources = _collectCapitalSources(
      profile: profile,
      currentAge: currentAge,
      retirementAge: retirementAge,
      lppCapitalPct: lppCapitalPct,
      currentYear: currentYear,
    );

    // Si aucun capital, retourner des sequences vides.
    if (capitalSources.isEmpty) {
      return const WithdrawalSequencingResult(
        optimizedSequence: [],
        naiveSequence: [],
        totalTaxOptimized: 0,
        totalTaxNaive: 0,
        taxSavings: 0,
        savingsPercent: 0,
        disclaimer: _disclaimer,
        sources: _sources,
      );
    }

    // ── 2. Scenario NAIF: tout retirer a l'age de retraite ───────
    final naiveSequence = _buildNaiveSequence(
      capitalSources: capitalSources,
      retirementAge: retirementAge,
      currentAge: currentAge,
      currentYear: currentYear,
      canton: canton,
      isMarried: isMarried,
    );
    final totalTaxNaive =
        naiveSequence.fold(0.0, (sum, e) => sum + e.tax);

    // ── 3. Scenario OPTIMISE: echelonner les retraits ────────────
    final optimizedSequence = _buildOptimizedSequence(
      capitalSources: capitalSources,
      retirementAge: retirementAge,
      currentAge: currentAge,
      currentYear: currentYear,
      canton: canton,
      isMarried: isMarried,
    );
    final totalTaxOptimized =
        optimizedSequence.fold(0.0, (sum, e) => sum + e.tax);

    // ── 4. Calculer les economies ────────────────────────────────
    final taxSavings = totalTaxNaive - totalTaxOptimized;
    final savingsPercent =
        totalTaxNaive > 0 ? taxSavings / totalTaxNaive : 0.0;

    return WithdrawalSequencingResult(
      optimizedSequence: optimizedSequence,
      naiveSequence: naiveSequence,
      totalTaxOptimized: totalTaxOptimized,
      totalTaxNaive: totalTaxNaive,
      taxSavings: taxSavings,
      savingsPercent: savingsPercent,
      disclaimer: _disclaimer,
      sources: _sources,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════

  /// Source de capital brut pour le sequencage.
  static List<_CapitalSource> _collectCapitalSources({
    required CoachProfile profile,
    required int currentAge,
    required int retirementAge,
    required double lppCapitalPct,
    required int currentYear,
  }) {
    final sources = <_CapitalSource>[];

    // --- 3a accounts ---
    final comptes3a = profile.prevoyance.comptes3a;
    final nombre3a = profile.prevoyance.nombre3a;
    final total3a = profile.prevoyance.totalEpargne3a;

    if (comptes3a.isNotEmpty) {
      // Comptes 3a detailles
      for (int i = 0; i < comptes3a.length; i++) {
        final compte = comptes3a[i];
        if (compte.solde <= 0) continue;

        // Projeter le solde jusqu'au retrait (compose au rendement estime).
        // L'annee de retrait sera determinee par le sequenceur.
        sources.add(_CapitalSource(
          id: '3a_${i + 1}',
          label: '3e pilier (compte ${i + 1})',
          currentBalance: compte.solde,
          annualReturn: compte.rendementEstime,
          type: _SourceType.pilier3a,
        ));
      }
    } else if (nombre3a > 0 && total3a > 0) {
      // Pas de detail individuel: repartir uniformement.
      final perAccount = total3a / nombre3a;
      for (int i = 0; i < nombre3a; i++) {
        sources.add(_CapitalSource(
          id: '3a_${i + 1}',
          label: '3e pilier (compte ${i + 1})',
          currentBalance: perAccount,
          annualReturn: 0.02, // Rendement moyen prudent
          type: _SourceType.pilier3a,
        ));
      }
    }

    // --- LPP capital portion ---
    if (lppCapitalPct > 0) {
      final lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      if (lppBalance > 0) {
        // Projeter le LPP a la retraite.
        final projectedLppRente = LppCalculator.projectToRetirement(
          currentBalance: lppBalance,
          currentAge: currentAge,
          retirementAge: retirementAge,
          grossAnnualSalary: profile.revenuBrutAnnuel,
          caisseReturn: profile.prevoyance.rendementCaisse,
          conversionRate: profile.prevoyance.tauxConversion,
        );
        // Back-calculate balance from annual rente.
        final effectiveConversion = profile.prevoyance.tauxConversion > 0
            ? profile.prevoyance.tauxConversion
            : 0.068;
        final projectedBalance = projectedLppRente / effectiveConversion;
        final capitalPortion = projectedBalance * lppCapitalPct;

        if (capitalPortion > 0) {
          sources.add(_CapitalSource(
            id: 'lpp_capital',
            label: 'LPP capital',
            // Already projected to retirement, no additional compounding.
            currentBalance: capitalPortion,
            annualReturn: 0, // Already projected
            type: _SourceType.lppCapital,
            alreadyProjected: true,
          ));
        }
      }
    }

    return sources;
  }

  /// Projette un solde sur N annees avec rendement compose.
  static double _projectBalance(
      double balance, double annualReturn, int years) {
    if (years <= 0 || annualReturn == 0) return balance;
    double result = balance;
    for (int i = 0; i < years; i++) {
      result *= (1 + annualReturn);
    }
    return result;
  }

  /// Scenario naif: tout retirer la meme annee (a la retraite).
  static List<WithdrawalEvent> _buildNaiveSequence({
    required List<_CapitalSource> capitalSources,
    required int retirementAge,
    required int currentAge,
    required int currentYear,
    required String canton,
    required bool isMarried,
  }) {
    final retirementYear = currentYear + (retirementAge - currentAge);

    // Projeter chaque source a l'annee de retraite.
    final events = <WithdrawalEvent>[];
    double totalCapitalInYear = 0;

    final projectedAmounts = <_CapitalSource, double>{};
    for (final src in capitalSources) {
      final years = src.alreadyProjected
          ? 0
          : (retirementAge - currentAge).clamp(0, 50);
      final projected = _projectBalance(
          src.currentBalance, src.annualReturn, years);
      projectedAmounts[src] = projected;
      totalCapitalInYear += projected;
    }

    // Impot total sur le retrait cumule de l'annee.
    final totalTax = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: totalCapitalInYear,
      canton: canton,
      isMarried: isMarried,
    );

    // Repartir l'impot au prorata de chaque source.
    for (final src in capitalSources) {
      final projected = projectedAmounts[src]!;
      final proportion = totalCapitalInYear > 0
          ? projected / totalCapitalInYear
          : 0.0;
      final sourceTax = totalTax * proportion;
      events.add(WithdrawalEvent(
        year: retirementYear,
        age: retirementAge,
        source: src.id,
        label: src.label,
        amount: projected,
        tax: sourceTax,
        netAmount: projected - sourceTax,
        effectiveRate: projected > 0 ? sourceTax / projected : 0,
      ));
    }

    return events;
  }

  /// Scenario optimise: echelonner les retraits 3a sur plusieurs annees
  /// et retirer le LPP capital a la retraite.
  static List<WithdrawalEvent> _buildOptimizedSequence({
    required List<_CapitalSource> capitalSources,
    required int retirementAge,
    required int currentAge,
    required int currentYear,
    required String canton,
    required bool isMarried,
  }) {
    // Separer les sources 3a et non-3a.
    final sources3a = capitalSources
        .where((s) => s.type == _SourceType.pilier3a)
        .toList();
    // Trier les comptes 3a par solde decroissant: le plus gros compte
    // est isole dans sa propre annee fiscale pour minimiser l'impact
    // des tranches progressives.
    sources3a.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
    final sourcesOther = capitalSources
        .where((s) => s.type != _SourceType.pilier3a)
        .toList();

    // --- Planifier les retraits 3a ---
    // OPP3 art. 3: retrait anticipe 3a possible 5 ans avant l'age AVS
    // de reference (65), soit au plus tot a 60 ans. La fenetre ne depend
    // PAS de l'age de retraite choisi par l'utilisateur.
    const int avsReferenceAge = 65;
    final earliestWithdrawalAge =
        (avsReferenceAge - 5).clamp(currentAge, 99); // = max(currentAge, 60)
    final latestWithdrawalAge =
        retirementAge.clamp(earliestWithdrawalAge, 70);

    // Echelonner les comptes 3a: un par annee, en commencant le plus tot.
    // Strategie: repartir uniformement dans la fenetre disponible.
    final withdrawalAges3a = _scheduleWithdrawals(
      count: sources3a.length,
      earliestAge: earliestWithdrawalAge,
      latestAge: latestWithdrawalAge,
    );

    // Eviter la cumulation du dernier retrait 3a avec le capital LPP
    // dans la meme annee fiscale (annee de retraite). Si le dernier 3a
    // tombe sur retirementAge et qu'il y a aussi du LPP, on le decale
    // d'un an en arriere pour reduire l'impact des tranches progressives.
    if (sources3a.isNotEmpty && sourcesOther.isNotEmpty) {
      final lastIdx = withdrawalAges3a.length - 1;
      if (withdrawalAges3a[lastIdx] == retirementAge &&
          withdrawalAges3a[lastIdx] > earliestWithdrawalAge) {
        withdrawalAges3a[lastIdx] = withdrawalAges3a[lastIdx] - 1;
      }
    }

    // Construire les evenements par annee fiscale pour calculer
    // l'imposition progressive correctement.
    // Map<int year, List<(source, projectedAmount)>>
    final yearlyWithdrawals = <int, List<_PlannedWithdrawal>>{};

    for (int i = 0; i < sources3a.length; i++) {
      final src = sources3a[i];
      final withdrawalAge = withdrawalAges3a[i];
      final years = (withdrawalAge - currentAge).clamp(0, 50);
      final projected = _projectBalance(
          src.currentBalance, src.annualReturn, years);
      final year = currentYear + (withdrawalAge - currentAge);

      yearlyWithdrawals.putIfAbsent(year, () => []);
      yearlyWithdrawals[year]!.add(_PlannedWithdrawal(
        source: src,
        age: withdrawalAge,
        year: year,
        projectedAmount: projected,
      ));
    }

    // LPP capital + autres: a l'age de retraite.
    final retirementYear = currentYear + (retirementAge - currentAge);
    for (final src in sourcesOther) {
      final years = src.alreadyProjected
          ? 0
          : (retirementAge - currentAge).clamp(0, 50);
      final projected = _projectBalance(
          src.currentBalance, src.annualReturn, years);

      yearlyWithdrawals.putIfAbsent(retirementYear, () => []);
      yearlyWithdrawals[retirementYear]!.add(_PlannedWithdrawal(
        source: src,
        age: retirementAge,
        year: retirementYear,
        projectedAmount: projected,
      ));
    }

    // Calculer l'impot pour chaque annee fiscale.
    final events = <WithdrawalEvent>[];
    final sortedYears = yearlyWithdrawals.keys.toList()..sort();

    for (final year in sortedYears) {
      final withdrawals = yearlyWithdrawals[year]!;
      final totalInYear =
          withdrawals.fold(0.0, (sum, w) => sum + w.projectedAmount);

      final yearTax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: totalInYear,
        canton: canton,
        isMarried: isMarried,
      );

      // Repartir l'impot au prorata des montants retires cette annee.
      for (final w in withdrawals) {
        final proportion = totalInYear > 0
            ? w.projectedAmount / totalInYear
            : 0.0;
        final sourceTax = yearTax * proportion;
        events.add(WithdrawalEvent(
          year: w.year,
          age: w.age,
          source: w.source.id,
          label: w.source.label,
          amount: w.projectedAmount,
          tax: sourceTax,
          netAmount: w.projectedAmount - sourceTax,
          effectiveRate:
              w.projectedAmount > 0 ? sourceTax / w.projectedAmount : 0,
        ));
      }
    }

    // Trier par annee puis par source.
    events.sort((a, b) {
      final yearCmp = a.year.compareTo(b.year);
      if (yearCmp != 0) return yearCmp;
      return a.source.compareTo(b.source);
    });

    return events;
  }

  /// Repartit N retraits uniformement dans la fenetre [earliestAge, latestAge].
  ///
  /// Si un seul retrait, il est place a l'age le plus tot.
  /// Si N retraits et N >= plage, un par annee.
  /// Sinon, espace regulier dans la plage.
  static List<int> _scheduleWithdrawals({
    required int count,
    required int earliestAge,
    required int latestAge,
  }) {
    if (count <= 0) return [];
    if (count == 1) return [earliestAge];

    // Plage d'annees disponible (bornes incluses).
    final span = latestAge - earliestAge;
    if (span <= 0) {
      // Tout au meme age.
      return List.filled(count, earliestAge);
    }

    if (count >= span + 1) {
      // Plus de comptes que d'annees: repartir au mieux.
      final ages = <int>[];
      for (int i = 0; i < count; i++) {
        ages.add(earliestAge + (i % (span + 1)));
      }
      ages.sort();
      return ages;
    }

    // Espace regulier.
    final step = span / (count - 1);
    final ages = <int>[];
    for (int i = 0; i < count; i++) {
      ages.add(earliestAge + (step * i).round());
    }
    return ages;
  }
}

// ══════════════════════════════════════════════════════════════════
//  INTERNAL MODELS
// ══════════════════════════════════════════════════════════════════

enum _SourceType { pilier3a, lppCapital }

class _CapitalSource {
  final String id;
  final String label;
  final double currentBalance;
  final double annualReturn;
  final _SourceType type;

  /// True if the balance is already projected to the target date
  /// (e.g. LPP projected via LppCalculator).
  final bool alreadyProjected;

  const _CapitalSource({
    required this.id,
    required this.label,
    required this.currentBalance,
    required this.annualReturn,
    required this.type,
    this.alreadyProjected = false,
  });
}

class _PlannedWithdrawal {
  final _CapitalSource source;
  final int age;
  final int year;
  final double projectedAmount;

  const _PlannedWithdrawal({
    required this.source,
    required this.age,
    required this.year,
    required this.projectedAmount,
  });
}
