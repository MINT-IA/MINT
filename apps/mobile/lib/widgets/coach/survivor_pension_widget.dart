import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P14-B  Les Rentes de survivant — mariage vs concubinage
//  Charte : L1 (CHF/mois) + L6 (Chiffre-choc)
//  Source : LAVS art. 23-24 (rente veuf/veuve), LPP art. 19
// ────────────────────────────────────────────────────────────

class SurvivorPensionWidget extends StatelessWidget {
  const SurvivorPensionWidget({
    super.key,
    required this.partnerAvsRente,
    required this.partnerLppMonthly,
    this.isConcubin = true,
    this.numberOfChildren = 0,
    this.conjointAge,
    this.marriageDurationYears,
  });

  final double partnerAvsRente;
  final double partnerLppMonthly;
  final bool isConcubin;
  final int numberOfChildren;
  final int? conjointAge;
  final int? marriageDurationYears;

  double get _avsMarried => partnerAvsRente * avsSurvivorFactor; // 80%

  ({
    double conjointMonthly,
    double conjointLumpSum,
    double orphanMonthlyPerChild,
    double orphanMonthlyTotal,
    double totalMonthly,
    bool conjointGetsRente,
  }) get _survivorResult => LppCalculator.computeSurvivorPension(
        projectedAnnualRente: partnerLppMonthly * 12,
        isMarried: !isConcubin,
        numberOfChildren: numberOfChildren,
        conjointAge: conjointAge,
        marriageDurationYears: marriageDurationYears,
      );

  double get _lppMarried => _survivorResult.conjointMonthly;
  double get _totalMarried => _avsMarried + _survivorResult.totalMonthly;

  // Concubin: 0 AVS, LPP only if explicitly named
  double get _avsConcubin => 0;
  double get _lppConcubin => 0; // default: not named
  double get _totalConcubin => _avsConcubin + _lppConcubin;

  double get _marriageBonus => _totalMarried - _totalConcubin;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      label: s.survivorPensionSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildComparison(s),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(s),
                  const SizedBox(height: 16),
                  _buildDetailRows(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.ecruBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('🏛️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.survivorPensionTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.survivorPensionSubtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison(S s) {
    return Row(
      children: [
        Expanded(child: _buildScenarioCard(
          emoji: '💍',
          label: s.survivorPensionMarried,
          total: _totalMarried,
          color: MintColors.scoreExcellent,
          detail: s.survivorPensionMarriedDetail,
          amountPerMonth: s.survivorPensionAmountPerMonth(formatChfWithPrefix(_totalMarried)),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildScenarioCard(
          emoji: '🏠',
          label: s.survivorPensionConcubin,
          total: _totalConcubin,
          color: MintColors.scoreCritique,
          detail: s.survivorPensionConcubinDetail,
          amountPerMonth: s.survivorPensionAmountPerMonth(formatChfWithPrefix(_totalConcubin)),
        )),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String emoji,
    required String label,
    required double total,
    required Color color,
    required String detail,
    required String amountPerMonth,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amountPerMonth,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.survivorPensionChiffreChoc(formatChfWithPrefix(_marriageBonus)),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreCritique,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.survivorPensionChiffreChocBody,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRows(S s) {
    final survivor = _survivorResult;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildDetailRow(s.survivorPensionAvsWidow, _avsMarried, 'LAVS art. 23', true),
          const Divider(height: 1),
          _buildDetailRow(s.survivorPensionLppPartner, _lppMarried, 'LPP art. 19', true),
          if (!survivor.conjointGetsRente && survivor.conjointLumpSum > 0) ...[
            const Divider(height: 1),
            _buildDetailRow(
              s.survivorPensionLppLumpSum,
              survivor.conjointLumpSum,
              s.survivorPensionLppLumpSumRef,
              true,
            ),
          ],
          if (numberOfChildren > 0) ...[
            const Divider(height: 1),
            _buildDetailRow(
              s.survivorPensionLppOrphan(numberOfChildren),
              survivor.orphanMonthlyTotal,
              'LPP art. 20',
              true,
            ),
          ],
          const Divider(height: 1),
          _buildDetailRow(
            s.survivorPensionAvsConcubin,
            0,
            s.survivorPensionNotApplicable,
            false,
          ),
          const Divider(height: 1),
          _buildDetailRow(
            s.survivorPensionLppNoDesignation,
            0,
            s.survivorPensionRequiresDesignation,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, String ref, bool isMarried) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            isMarried ? '💍' : '🏠',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary),
                ),
                Text(
                  ref,
                  style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            amount > 0 ? formatChfWithPrefix(amount) : '0\u00a0CHF',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: amount > 0 ? MintColors.scoreExcellent : MintColors.scoreCritique,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.survivorPensionDisclaimer((avsSurvivorFactor * 100).toInt().toString()),
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
