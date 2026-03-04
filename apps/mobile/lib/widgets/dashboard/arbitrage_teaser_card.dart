import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  ARBITRAGE TEASER CARDS — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  3 cartes teaser affichant des chiffres chocs rapides :
//    1. Rente vs Capital — blendedMonthly comparison
//    2. Calendrier retraits — staggering tax saving estimate
//    3. Rachat LPP — tax saving from buyback
//
//  Visible uniquement si age >= 45 (State A).
//  Estimations rapides depuis financial_core, pas de calcul lourd.
//
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
//  Compliance : "Dans ce scenario simule..."
// ────────────────────────────────────────────────────────────

/// Container widget for the 3 arbitrage teasers.
class ArbitrageTeaserSection extends StatelessWidget {
  final CoachProfile profile;

  const ArbitrageTeaserSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.enableDecisionScaffold) {
      return const SizedBox.shrink();
    }

    final teasers = _computeTeasers(profile);
    if (teasers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pistes d\u2019arbitrage',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Estimations rapides \u2014 appuie pour explorer en d\u00e9tail',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ...teasers.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ArbitrageTeaserTile(teaser: t),
            )),
      ],
    );
  }

  static List<_TeaserData> _computeTeasers(CoachProfile profile) {
    final teasers = <_TeaserData>[];
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final targetRetirementAge = profile.effectiveRetirementAge > profile.age
        ? profile.effectiveRetirementAge
        : 65;

    // 1. Rente vs Capital
    final lppAvoir = profile.prevoyance.avoirLppTotal ?? 0;
    if (lppAvoir > 0) {
      final convRate = profile.prevoyance.tauxConversion;
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: lppAvoir,
        currentAge: profile.age,
        retirementAge: targetRetirementAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
        caisseReturn: profile.prevoyance.rendementCaisse,
        conversionRate: convRate,
      );

      // Compare 100% rente vs 60% rente + 40% capital
      final monthlyFullRente = LppCalculator.blendedMonthly(
        annualRente: annualRente,
        conversionRate: convRate,
        lppCapitalPct: 0.0,
        canton: canton,
        isMarried: isMarried,
      );
      final monthlyMixed = LppCalculator.blendedMonthly(
        annualRente: annualRente,
        conversionRate: convRate,
        lppCapitalPct: 0.4,
        canton: canton,
        isMarried: isMarried,
      );

      final diff = (monthlyMixed - monthlyFullRente).abs();
      if (diff > 50) {
        final betterOption = monthlyMixed > monthlyFullRente
            ? '60% rente + 40% capital'
            : '100% rente';
        teasers.add(_TeaserData(
          icon: Icons.compare_arrows_rounded,
          color: MintColors.purple,
          title: 'Rente vs Capital',
          chiffreChoc:
              'L\u2019option $betterOption pourrait donner +CHF\u00a0${_fmt(diff)}/mois nets',
          route: '/arbitrage/rente-vs-capital',
        ));
      }
    }

    // 2. Calendrier retraits — estimate staggering tax saving
    final total3a = profile.prevoyance.totalEpargne3a;
    if (lppAvoir > 0 && total3a > 0) {
      // Rough estimate: unstaggered = all in one year → higher progressive rate
      // Staggered = spread over 3 years → lower marginal brackets
      final totalCapital = lppAvoir * 0.4 + total3a; // assuming 40% capital
      final taxOneShot = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: totalCapital,
        canton: canton,
        isMarried: isMarried,
      );
      final taxStaggered = RetirementTaxCalculator.capitalWithdrawalTax(
            capitalBrut: totalCapital * 0.33,
            canton: canton,
            isMarried: isMarried,
          ) *
          3;
      final saving = (taxOneShot - taxStaggered).abs();

      if (saving > 500) {
        teasers.add(_TeaserData(
          icon: Icons.calendar_month_outlined,
          color: MintColors.info,
          title: 'Calendrier de retraits',
          chiffreChoc:
              '\u00c9chelonner tes retraits pourrait \u00e9conomiser ~CHF\u00a0${_fmt(saving)} d\u2019imp\u00f4t',
          route: '/arbitrage/calendrier-retraits',
        ));
      }
    }

    // 3. Rachat LPP
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 1000) {
      // Rough marginal tax rate estimate: 25-35% for median Swiss incomes
      final revenuBrut = profile.revenuBrutAnnuel;
      final tauxMarginal = revenuBrut > 150000
          ? 0.35
          : revenuBrut > 100000
              ? 0.30
              : 0.25;
      final saving = lacune * tauxMarginal;

      teasers.add(_TeaserData(
        icon: Icons.add_chart_rounded,
        color: MintColors.success,
        title: 'Rachat LPP',
        chiffreChoc:
            'Un rachat de CHF\u00a0${_fmt(lacune)} pourrait r\u00e9duire ton imp\u00f4t de ~CHF\u00a0${_fmt(saving)}',
        route: '/lpp-deep/rachat',
      ));
    }

    return teasers;
  }

  static String _fmt(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _TeaserData {
  final IconData icon;
  final Color color;
  final String title;
  final String chiffreChoc;
  final String route;

  const _TeaserData({
    required this.icon,
    required this.color,
    required this.title,
    required this.chiffreChoc,
    required this.route,
  });
}

class _ArbitrageTeaserTile extends StatelessWidget {
  final _TeaserData teaser;

  const _ArbitrageTeaserTile({required this.teaser});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(teaser.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: teaser.color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: teaser.color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: teaser.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(teaser.icon, size: 20, color: teaser.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teaser.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    teaser.chiffreChoc,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dans ce sc\u00e9nario simul\u00e9 \u2014 \u00e0 explorer en d\u00e9tail',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: teaser.color.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
