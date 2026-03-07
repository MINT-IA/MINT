import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P7-B  Crash-test budget — Budget actuel vs mode survie
//  Charte : L1 (CHF/mois) + L2 (Avant/Après) + L5 (1 action)
// ────────────────────────────────────────────────────────────

enum BudgetLineStatus { locked, cut, paused }

class BudgetLine {
  const BudgetLine({
    required this.label,
    required this.emoji,
    required this.normalAmount,
    required this.survivalAmount,
    required this.status,
  });

  final String label;
  final String emoji;
  final double normalAmount;
  final double survivalAmount;
  final BudgetLineStatus status;
}

class CrashTestBudgetWidget extends StatelessWidget {
  const CrashTestBudgetWidget({
    super.key,
    required this.monthlyIncome,
    required this.survivalIncome,
    required this.lines,
    this.reserveMonths,
  });

  final double monthlyIncome;
  final double survivalIncome;
  final List<BudgetLine> lines;
  final double? reserveMonths;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      return remainder == 0 ? "$thousands'000" : "$thousands'${remainder.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final totalNormal = lines.fold<double>(0, (s, l) => s + l.normalAmount);
    final totalSurvival = lines.fold<double>(0, (s, l) => s + l.survivalAmount);
    final marginNormal = monthlyIncome - totalNormal;
    final marginSurvival = survivalIncome - totalSurvival;
    final saving = totalNormal - totalSurvival;

    return Semantics(
      label: 'Crash-test budget chômage',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(saving),
            const Divider(height: 1),
            _buildColumnHeaders(),
            ...lines.map((l) => _buildLine(l)),
            const Divider(height: 1),
            _buildTotalsRow(totalNormal, totalSurvival),
            _buildMarginRow(marginNormal, marginSurvival),
            if (reserveMonths != null) _buildReservePanel(marginSurvival),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double saving) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3E0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚗', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crash-test budget',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mode normal vs mode survie',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.scoreCritique.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.content_cut, color: MintColors.scoreCritique, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Tu économises CHF ${_fmt(saving)}/mois en mode survie',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreCritique,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 80,
            child: Text(
              'Normal',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MintColors.primary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Survie',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreCritique,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildLine(BudgetLine line) {
    final (icon, color) = switch (line.status) {
      BudgetLineStatus.locked => ('🔒', MintColors.textSecondary),
      BudgetLineStatus.cut => ('✂️', MintColors.scoreAttention),
      BudgetLineStatus.paused => ('⏸️', MintColors.scoreCritique),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(line.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(line.normalAmount),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(line.survivalAmount),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: line.status != BudgetLineStatus.locked ? FontWeight.w700 : FontWeight.w400,
                color: line.status == BudgetLineStatus.locked ? MintColors.textSecondary : color,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              icon,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(double normal, double survival) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TOTAL charges',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(normal),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _fmt(survival),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreCritique,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMarginRow(double normal, double survival) {
    final survivalColor = survival >= 0 ? MintColors.scoreExcellent : MintColors.scoreCritique;
    final survivalLabel = survival >= 0 ? '+${_fmt(survival)}' : '-${_fmt(survival.abs())}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: survivalColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: survivalColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Marge mensuelle',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              normal >= 0 ? '+${_fmt(normal)}' : '-${_fmt(normal.abs())}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: normal >= 0 ? MintColors.scoreExcellent : MintColors.scoreCritique,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              survivalLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: survivalColor,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildReservePanel(double marginSurvival) {
    final months = reserveMonths!;
    final color = months >= 6
        ? MintColors.scoreExcellent
        : months >= 3
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;
    final label = months >= 6
        ? 'Tes réserves tiennent — tu as une marge de sécurité.'
        : months >= 3
            ? 'Attention : moins de 6 mois de réserve.'
            : 'Danger : moins de 3 mois de réserve !';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tes réserves : ${months.toStringAsFixed(1)} mois',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Text(
        'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin.',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: MintColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
