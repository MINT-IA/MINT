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
    final l10n = S.of(context)!;
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
          suffix: l10n.chiffreChocSectionSuffixPerYear,
          message: l10n.chiffreChocSectionTaxSavings3a(
              anneesRestantes, _formatChf(economieCumulee)),
          narrativeMessage: narratives['fiscalite'],
          source: 'OPP3 art. 7 \u00b7 LIFD',
          ctaLabel: l10n.chiffreChocSectionCta3a,
          ctaRoute: '/simulator/3a',
          icon: Icons.savings,
          color: MintColors.indigo,
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
        message: l10n.chiffreChocSectionLppBuybackMessage(
            _formatChf(lacuneLpp)),
        narrativeMessage: narratives['prevoyance'],
        source: 'LPP art. 79b',
        ctaLabel: l10n.chiffreChocSectionCtaLppBuyback,
        ctaRoute: '/lpp-deep/rachat',
        icon: Icons.account_balance,
        color: MintColors.coachAccent,
      ));
    }

    // 3. AVS gap cost — each missing year = -1/44 of max rente (LAVS art. 29ter)
    final lacunesAVS = profile.prevoyance.lacunesAVS ?? 0;
    if (lacunesAVS > 0) {
      final perteTotaleAnnuelle =
          AvsCalculator.annualRente(AvsCalculator.monthlyLossFromGap(lacunesAVS));
      // Over ~20 years of retirement
      final perteTotaleRetraite = perteTotaleAnnuelle * 20;

      cards.add(ChiffreChocCard(
        value: perteTotaleRetraite,
        message: lacunesAVS > 1
            ? l10n.chiffreChocSectionAvsGapMessagePlural(lacunesAVS)
            : l10n.chiffreChocSectionAvsGapMessageSingular(lacunesAVS),
        narrativeMessage: narratives['avs'],
        source: 'LAVS art. 29',
        ctaLabel: l10n.chiffreChocSectionCtaAvsGap,
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
          l10n.coachShockTitle,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.coachShockSubtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ...cards.expand((card) => [card, const SizedBox(height: 12)]),
        Text(
          l10n.chiffreChocSectionDisclaimer,
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
