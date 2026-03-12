import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
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
    return Semantics(
      label: 'Rente survivant mariage concubin décès LAVS LPP comparaison',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildComparison(),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(),
                  const SizedBox(height: 16),
                  _buildDetailRows(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  'Rentes de survivant',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si ton·ta partenaire décède — combien touches-tu ?',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    return Row(
      children: [
        Expanded(child: _buildScenarioCard(
          emoji: '💍',
          label: 'Marié·e',
          total: _totalMarried,
          color: MintColors.scoreExcellent,
          detail: '80% AVS + 60% LPP',
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildScenarioCard(
          emoji: '🏠',
          label: 'Concubin·e',
          total: _totalConcubin,
          color: MintColors.scoreCritique,
          detail: '0 CHF si pas de désignation',
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
            '${formatChfWithPrefix(total)}/mois',
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

  Widget _buildChiffreChoc() {
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
                  'Le mariage vaut ${formatChfWithPrefix(_marriageBonus)}/mois de rente survivant',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreCritique,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Concubin·e sans désignation LPP ni testament = 0 CHF automatique. '
                  'LAVS art. 23 : seul·e le·la conjoint·e légal·e a droit à la rente de veuf/veuve.',
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

  Widget _buildDetailRows() {
    final survivor = _survivorResult;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildDetailRow('AVS rente veuf/veuve (80%)', _avsMarried, 'LAVS art. 23', true),
          const Divider(height: 1),
          _buildDetailRow('LPP rente partenaire (60%)', _lppMarried, 'LPP art. 19', true),
          if (!survivor.conjointGetsRente && survivor.conjointLumpSum > 0) ...[
            const Divider(height: 1),
            _buildDetailRow(
              'LPP capital unique (3× rente)',
              survivor.conjointLumpSum,
              'LPP art. 19 al. 2 — conditions non remplies',
              true,
            ),
          ],
          if (numberOfChildren > 0) ...[
            const Divider(height: 1),
            _buildDetailRow(
              'LPP rente orphelin ($numberOfChildren enfant${numberOfChildren > 1 ? 's' : ''}, 20%/enf.)',
              survivor.orphanMonthlyTotal,
              'LPP art. 20',
              true,
            ),
          ],
          const Divider(height: 1),
          _buildDetailRow(
            'AVS concubin·e',
            0,
            'Non applicable',
            false,
          ),
          const Divider(height: 1),
          _buildDetailRow(
            'LPP sans désignation',
            0,
            'Exige désignation explicite',
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
            amount > 0 ? formatChfWithPrefix(amount) : '0 CHF',
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

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAVS art. 23-24 (rente veuf/veuve), LPP art. 19 (rente partenaire). '
      'Taux AVS survivant : ${(avsSurvivorFactor * 100).toInt()}%.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
