import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/chiffre_choc_card.dart';

/// Section displaying personalized "chiffre-choc" cards.
///
/// Computes up to 3 shock-value cards: 3a tax gap, LPP buyback, AVS gap.
/// Pure presentational widget — all data passed as parameters.
class ChiffreChocSection extends StatelessWidget {
  final CoachProfile profile;
  final Map<String, String> narratives;

  const ChiffreChocSection({
    super.key,
    required this.profile,
    required this.narratives,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final revenuBrutAnnuel = profile.revenuBrutAnnuel;
    final cards = <Widget>[];

    // 1. 3a tax savings gap — if not maxing out the pillar 3a.
    // Guard: only show if we have substantive data AND we know the actual
    // 3a contribution status. If the user already has 3a capital but no
    // declared contribution, they're clearly contributing — we just don't
    // know how much, so we can't compute a meaningful gap.
    final cotisation3aAnnuelle = profile.total3aMensuel * 12;
    const plafond3a = pilier3aPlafondAvecLpp; // OPP3 art. 7
    final has3aCapitalButNoContribDeclared =
        profile.prevoyance.totalEpargne3a > 0 && cotisation3aAnnuelle <= 0;
    final hasSubstantiveData = profile.prevoyance.avoirLppTotal != null ||
        profile.prevoyance.totalEpargne3a > 0;
    if (hasSubstantiveData &&
        !has3aCapitalButNoContribDeclared &&
        cotisation3aAnnuelle < plafond3a &&
        profile.prevoyance.canContribute3a) {
      final tauxMarginal =
          RetirementTaxCalculator.estimateMarginalRate(revenuBrutAnnuel, profile.canton);
      final economieAnnuelle =
          (plafond3a - cotisation3aAnnuelle) * tauxMarginal;
      final anneesRestantes = profile.anneesAvantRetraite;
      final economieCumulee = economieAnnuelle * anneesRestantes;
      // Show ANNUAL savings as the headline number — honest and actionable.
      // Mention cumulative in the message for motivation.
      if (economieAnnuelle > 500) {
        cards.add(ChiffreChocCard(
          value: economieAnnuelle,
          suffix: '/an',
          message: '\u00c9conomie d\'imp\u00f4ts potentielle chaque ann\u00e9e en '
              'maximisant ton 3a. '
              'Sur $anneesRestantes ans, cela repr\u00e9sente ~CHF\u00A0${_formatChf(economieCumulee)}.',
          narrativeMessage: narratives['fiscalite'],
          source: 'OPP3 art. 7 \u00b7 LIFD',
          ctaLabel: 'Simuler mon 3a',
          ctaRoute: '/simulator/3a',
          icon: Icons.savings,
          color: const Color(0xFF4F46E5),
        ));
      }
    }

    // 2. LPP buyback tax deduction potential
    final lacuneLpp = profile.prevoyance.lacuneRachatRestante;
    if (lacuneLpp > 5000) {
      final tauxMarginal =
          RetirementTaxCalculator.estimateMarginalRate(revenuBrutAnnuel, profile.canton);
      final economieRachat = lacuneLpp * tauxMarginal;

      cards.add(ChiffreChocCard(
        value: economieRachat,
        message: 'D\u00e9duction fiscale potentielle en rachetant '
            'ta lacune LPP de CHF ${_formatChf(lacuneLpp)}.',
        narrativeMessage: narratives['prevoyance'],
        source: 'LPP art. 79b',
        ctaLabel: 'Explorer le rachat',
        ctaRoute: '/lpp-deep/rachat',
        icon: Icons.account_balance,
        color: MintColors.coachAccent,
      ));
    }

    // 3. AVS gap cost — each missing year = -1/44 of max rente (LAVS art. 29ter)
    final lacunesAVS = profile.prevoyance.lacunesAVS ?? 0;
    if (lacunesAVS > 0) {
      final perteTotaleAnnuelle =
          AvsCalculator.monthlyLossFromGap(lacunesAVS) * 12;
      // Over ~20 years of retirement
      final perteTotaleRetraite = perteTotaleAnnuelle * 20;

      cards.add(ChiffreChocCard(
        value: perteTotaleRetraite,
        message: 'Rente AVS perdue sur 20 ans de retraite avec '
            '$lacunesAVS ann\u00e9e${lacunesAVS > 1 ? 's' : ''} '
            'de cotisation manquante${lacunesAVS > 1 ? 's' : ''}.',
        narrativeMessage: narratives['avs'],
        source: 'LAVS art. 29',
        ctaLabel: 'V\u00e9rifier mes lacunes',
        ctaRoute: '/retirement',
        icon: Icons.shield_outlined,
        color: MintColors.scoreAttention,
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachShockTitle ?? 'Tes chiffres-chocs',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n?.coachShockSubtitle ??
              'Des montants personnalis\u00e9s pour \u00e9clairer tes d\u00e9cisions',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ...cards.expand((card) => [card, const SizedBox(height: 12)]),
        Text(
          'Simulation \u00e0 titre \u00e9ducatif uniquement. '
          'Ne constitue pas un conseil en placement ou pr\u00e9voyance (LSFin). '
          'Hypoth\u00e8ses modifiables \u2014 r\u00e9sultats non garantis.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Format CHF with Swiss thousands separator (apostrophe).
  static String _formatChf(double amount) {
    final formatted = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = formatted.length - 1; i >= 0; i--) {
      buffer.write(formatted[i]);
      count++;
      if (count % 3 == 0 && i > 0) buffer.write("'");
    }
    return buffer.toString().split('').reversed.join();
  }
}
