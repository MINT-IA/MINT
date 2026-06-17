import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  ARBITRAGE TEASER CARDS — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  Cartes teaser affichant des estimations rapides receipt-safe :
//    1. Calendrier retraits — indicative tax impact from staggering
//    2. Rachat LPP — indicative tax impact from buyback
//
//  Affichees quand les donnees necessaires sont presentes.
//  Estimations rapides depuis financial_core, pas de calcul lourd.
//  Rente vs Capital reste hors dashboard tant qu'un receipt complet
//  n'est pas disponible dans ce widget.
//
//  Widget pur — aucune dependance Provider.
//  Compliance : formulation conditionnelle et educative.
// ────────────────────────────────────────────────────────────

/// Container widget for arbitrage teasers.
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Pistes d\u2019arbitrage',
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Semantics(
              label: 'Voir tout',
              button: true,
              child: GestureDetector(
                onTap: () => context.push('/arbitrage/bilan'),
                child: Text(
                  'Voir tout \u2192',
                  style: MintTextStyles.labelMedium(color: MintColors.primary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Estimations rapides \u2014 appuie pour explorer en d\u00e9tail',
          style: MintTextStyles.labelMedium(color: MintColors.textMuted),
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
    final resolvedCanton = resolveCanton(profile.canton);
    if (!resolvedCanton.isResolved) return teasers;
    final canton = resolvedCanton.code;

    final lppAvoir = profile.prevoyance.avoirLppTotal ?? 0;

    // 1. Calendrier retraits — estimate indicative staggering impact
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
          premierEclairage:
              '\u00c9chelonner tes retraits\u00a0: impact fiscal indicatif ~CHF\u00a0${_fmt(saving)}',
          route: '/decaissement',
        ));
      }
    }

    // 2. Rachat LPP
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
        premierEclairage:
            'Un rachat de CHF\u00a0${_fmt(lacune)}\u00a0: impact fiscal indicatif ~CHF\u00a0${_fmt(saving)}',
        route: '/rachat-lpp',
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
  final String premierEclairage;
  final String route;

  const _TeaserData({
    required this.icon,
    required this.color,
    required this.title,
    required this.premierEclairage,
    required this.route,
  });
}

class _ArbitrageTeaserTile extends StatelessWidget {
  final _TeaserData teaser;

  const _ArbitrageTeaserTile({required this.teaser});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: teaser.title,
      button: true,
      child: InkWell(
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
                      style: MintTextStyles.bodySmall(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teaser.premierEclairage,
                      style: MintTextStyles.labelMedium(
                              color: MintColors.textSecondary)
                          .copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dans ce sc\u00e9nario simul\u00e9 \u2014 \u00e0 explorer en d\u00e9tail',
                      style: MintTextStyles.micro(color: MintColors.textMuted)
                          .copyWith(fontStyle: FontStyle.italic),
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
      ),
    );
  }
}
