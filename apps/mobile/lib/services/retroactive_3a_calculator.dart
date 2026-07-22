import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// A single year entry in the retroactive 3a breakdown.
class YearlyRetroactiveEntry {
  /// The calendar year this entry represents.
  final int year;

  /// The 3a limit applicable for that year.
  final double limit;

  /// Whether this contribution is tax-deductible in the reference year.
  final bool deductible;

  const YearlyRetroactiveEntry({
    required this.year,
    required this.limit,
    this.deductible = true,
  });
}

/// Result of a retroactive 3a calculation.
class Retroactive3aResult {
  /// Number of gap years effectively filled (bounded by eligibility AND the
  /// per-calendar-year cap — in practice 1 for a full unpaid gap).
  final int gapYears;

  /// Sum of all retroactive yearly amounts (capped at one "petit" 3a max
  /// per calendar year of buy-in — OPP3 art. 7a).
  final double totalRetroactive;

  /// Current year 3a limit (not part of retroactive).
  final double totalCurrentYear;

  /// totalRetroactive + totalCurrentYear.
  final double totalContribution;

  /// Estimated tax savings: totalRetroactive * tauxMarginal.
  final double economiesFiscales;

  /// Per-year breakdown (most recent gap year first).
  final List<YearlyRetroactiveEntry> breakdown;

  /// One-liner impact number for the user.
  final String premierEclairage;

  /// Educational disclaimer (LSFin / OPP3).
  final String disclaimer;

  /// Legal references.
  final List<String> sources;

  const Retroactive3aResult({
    required this.gapYears,
    required this.totalRetroactive,
    required this.totalCurrentYear,
    required this.totalContribution,
    required this.economiesFiscales,
    required this.breakdown,
    required this.premierEclairage,
    required this.disclaimer,
    required this.sources,
  });
}

/// Pure-function calculator for the retroactive Pillar 3a catch-up
/// (réforme OPP3 art. 7a, en vigueur 2025-01-01 — RO 2024 687).
///
/// Doctrine (parité avec le backend `retroactive_3a_service.py`,
/// MINT_nosync-cli / MINT_nosync-i0v) :
///   - seules les lacunes >= 2025 sont rachetables (fenêtre 10 ans) ;
///     premier rachat possible en 2026 (pour l'année 2025) ;
///   - le rachat rétroactif payable au cours d'UNE année civile est
///     plafonné au « petit » maximum 3a (CHF 7'258 en 2025/2026),
///     identique avec ou sans LPP (asymétrie documentée de la réforme —
///     le grand 3a ne s'applique qu'à la cotisation ordinaire courante) ;
///   - les lacunes les plus anciennes sont comblées d'abord (proches de
///     sortir de la fenêtre de 10 ans).
class Retroactive3aCalculator {
  Retroactive3aCalculator._();

  /// Petit plafond 3a de l'année — plafond légal du rachat rétroactif
  /// payable en une année civile, identique avec ou sans LPP.
  static double _petitMaxForYear(int year) =>
      pilier3aHistoricalLimits[year] ??
      reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);

  /// Calculate retroactive 3a potential.
  ///
  /// [gapYears] — number of past years without 3a contributions (bounded to
  /// the eligible years >= 2025 within the 10-year window).
  /// [tauxMarginal] — user's marginal tax rate as a decimal (0.0-1.0).
  /// [hasLpp] — affects ONLY the ordinary current-year contribution (grand 3a
  /// sans LPP) ; the retroactive buy-in is capped at the petit max for all.
  /// [revenuNetAnnuel] — only used when [hasLpp] is false (20% income cap on
  /// the current-year contribution).
  /// [referenceYear] — the year the catch-up payment is made.
  /// Defaults to the current calendar year (pas de hardcode 2026).
  static Retroactive3aResult calculate({
    required int gapYears,
    required double tauxMarginal,
    bool hasLpp = true,
    double? revenuNetAnnuel,
    int? referenceYear,
  }) {
    final effectiveRefYear = referenceYear ?? DateTime.now().year;
    // Clamp taux marginal at the realistic Swiss maximum (~45%).
    // Audit simulateur 2026-04-18 P1-9 : ancien clamp à 60% surestimait
    // l'économie de 15-33%. Cohérent avec tax_calculator.dart. (NB : le
    // backend clampe à 0.60 — divergence connue, voir MINT_nosync-i0v.)
    final effectiveTaux = tauxMarginal.clamp(0.0, 0.45);

    // ── Cotisation ordinaire de l'année courante (séparée du rachat) ──
    double currentYearLimit;
    if (hasLpp) {
      currentYearLimit = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    } else if (revenuNetAnnuel != null) {
      currentYearLimit = (revenuNetAnnuel *
              reg('pillar3a.income_rate_without_lpp', pilier3aTauxRevenuSansLpp))
          .clamp(0, reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp))
          .toDouble();
    } else {
      currentYearLimit = reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp);
    }

    // ── Années de lacune ÉLIGIBLES (>= 2025, fenêtre 10 ans) ──
    final earliest = effectiveRefYear - pilier3aMaxRetroactiveYears >
            pilier3aRetroactiveFirstEligibleYear
        ? effectiveRefYear - pilier3aMaxRetroactiveYears
        : pilier3aRetroactiveFirstEligibleYear;
    final requestedCount = gapYears < 1 ? 1 : gapYears;
    final eligible = <int>[
      for (int i = requestedCount; i >= 1; i--)
        if (effectiveRefYear - i >= earliest) effectiveRefYear - i,
    ]; // ascendant = lacunes les plus anciennes d'abord

    // ── Rachat rétroactif : plafonné au petit max TOTAL sur l'année civile ──
    double annualCap = _petitMaxForYear(effectiveRefYear);
    // Sans LPP à revenu nul : aucune capacité de rachat.
    if (!hasLpp && revenuNetAnnuel != null && currentYearLimit <= 0) {
      annualCap = 0;
    }

    final filled = <YearlyRetroactiveEntry>[];
    double totalRetroactive = 0;
    for (final year in eligible) {
      if (totalRetroactive >= annualCap) break;
      final room = annualCap - totalRetroactive;
      final petitMax = _petitMaxForYear(year);
      final amount = petitMax < room ? petitMax : room;
      if (amount <= 0) continue;
      totalRetroactive += amount;
      filled.add(YearlyRetroactiveEntry(year: year, limit: amount));
    }
    // Affichage : plus récentes d'abord.
    final breakdown = filled.reversed.toList();

    final totalContribution = totalRetroactive + currentYearLimit;
    final economiesFiscales = totalRetroactive * effectiveTaux;

    final n = breakdown.length;
    final String premierEclairage;
    if (n == 0) {
      premierEclairage =
          'En $effectiveRefYear, aucune année de lacune 3a n’est '
          'encore rachetable (le rachat rétroactif s’applique aux '
          'lacunes dès $pilier3aRetroactiveFirstEligibleYear).';
    } else {
      premierEclairage = 'Tu peux rattraper $n an${n > 1 ? "s" : ""} '
          "d'épargne 3a et économiser "
          "CHF ${formatChf(economiesFiscales)} d'impôts "
          'en $effectiveRefYear.';
    }

    return Retroactive3aResult(
      gapYears: n,
      totalRetroactive: totalRetroactive,
      totalCurrentYear: currentYearLimit,
      totalContribution: totalContribution,
      economiesFiscales: economiesFiscales,
      breakdown: breakdown,
      premierEclairage: premierEclairage,
      disclaimer:
          'Outil éducatif — ne constitue pas un conseil fiscal (LSFin). '
          'Le rachat 3a rétroactif (OPP3 art. 7a, en vigueur depuis 2025) '
          'comble les lacunes dès 2025, plafonné au petit maximum 3a '
          'par année civile. '
          "L'économie fiscale dépend de ton taux marginal réel.",
      sources: const [
        'OPP3 art. 7a (en vigueur 2025-01-01)',
        'LIFD art. 33 al. 1 let. e',
        'Plafonds annuels BSV/OFAS',
      ],
    );
  }
}
