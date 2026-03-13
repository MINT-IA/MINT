import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-B  Le Reset silencieux — Perte d'ancienneté LPP
//  Charte : L1 (CHF/mois) + L7 (Métaphore reset/rewind)
//  Source : LPP art. 16 (bonifications par âge), LPP art. 23
// ────────────────────────────────────────────────────────────

class DisabilityResetWidget extends StatelessWidget {
  const DisabilityResetWidget({
    super.key,
    required this.currentAge,
    required this.currentSalary,
    required this.reducedSalary,
    required this.capitalBefore,
    required this.capitalAfter,
  });

  final int currentAge;
  final double currentSalary;
  final double reducedSalary;
  final double capitalBefore;
  final double capitalAfter;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000000) {
      return "${(v / 1000000).toStringAsFixed(1)}M";
    }
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = getLppBonificationRate(currentAge);
    final bonificationBefore = currentSalary * currentRate;
    final bonificationAfter = reducedSalary * currentRate;
    final capitalDelta = capitalBefore - capitalAfter;
    final conversionRate = lppTauxConversionMin / 100;
    final renteMonthlyDelta = capitalDelta * conversionRate / 12;

    return Semantics(
      label: 'Reset silencieux invalidité LPP ancienneté',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
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
                  _buildContext(currentRate * 100, bonificationBefore, bonificationAfter),
                  const SizedBox(height: 20),
                  _buildCapitalComparison(capitalDelta),
                  const SizedBox(height: 16),
                  _buildRenteImpact(renteMonthlyDelta),
                  const SizedBox(height: 16),
                  _buildNarrative(),
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
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('⏪', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le reset silencieux',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'L\'invalidité ne détruit pas que ton revenu actuel — elle rétrécit ta retraite.',
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

  Widget _buildContext(double rate, double bonifBefore, double bonifAfter) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À $currentAge ans — taux de bonification LPP : ${rate.toStringAsFixed(0)}% (LPP art. 16)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildBonifRow('Avant invalidité', currentSalary, bonifBefore, MintColors.primary),
          const SizedBox(height: 8),
          _buildBonifRow('Après reconversion', reducedSalary, bonifAfter, MintColors.scoreAttention),
        ],
      ),
    );
  }

  Widget _buildBonifRow(String label, double salary, double bonif, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                'Salaire ${_fmt(salary)} → bonification LPP : CHF ${_fmt(bonif)}/an',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapitalComparison(double delta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton 2e pilier à 65 ans',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCapitalCard(
              label: 'Sans invalidité',
              amount: capitalBefore,
              color: MintColors.scoreExcellent,
              emoji: '✅',
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildCapitalCard(
              label: 'Avec invalidité',
              amount: capitalAfter,
              color: MintColors.scoreCritique,
              emoji: '❌',
            )),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MintColors.scoreCritique.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '△ Différence : -CHF ${_fmt(delta)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapitalCard({
    required String label,
    required double amount,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '$emoji CHF ${_fmt(amount)}',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenteImpact(double monthlyDelta) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rente mensuelle perdue',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '-CHF ${_fmt(monthlyDelta)}/mois',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MintColors.scoreCritique,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Chaque mois.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Pour toujours.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.scoreCritique,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNarrative() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'C\'est pas juste ton salaire qui baisse.\nC\'est ta retraite qui rétrécit.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LPP art. 16, 23-26. Taux de conversion minimum : 6.8% (LPP art. 14).',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
