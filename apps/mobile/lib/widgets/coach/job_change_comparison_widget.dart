import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P11-A  Le Prix du changement — avant/après nouveau job
//  Charte : L2 (Avant/Après) + L6 (Chiffre-choc)
//  Source : CO art. 335, LPP art. 14-16
// ────────────────────────────────────────────────────────────

class JobAxis {
  const JobAxis({
    required this.label,
    required this.emoji,
    required this.currentValue,
    required this.newValue,
    required this.unit,
    this.higherIsBetter = true,
    this.note,
  });

  final String label;
  final String emoji;
  final double currentValue;
  final double newValue;
  final String unit;
  final bool higherIsBetter;
  final String? note;
}

class JobChangeComparisonWidget extends StatelessWidget {
  const JobChangeComparisonWidget({
    super.key,
    required this.currentJobLabel,
    required this.newJobLabel,
    required this.axes,
  });

  final String currentJobLabel;
  final String newJobLabel;
  final List<JobAxis> axes;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }


  @override
  Widget build(BuildContext context) {
    final netMonthly = axes
        .where((a) => a.unit == 'CHF/mois')
        .fold<double>(0, (s, a) => s + (a.newValue - a.currentValue));

    return Semantics(
      label: 'Prix du changement comparaison emploi avant après',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(netMonthly),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildColumnHeaders(),
                  const SizedBox(height: 10),
                  ...axes.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildAxisRow(a),
                  )),
                  const SizedBox(height: 8),
                  _buildNetCallout(netMonthly),
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

  Widget _buildHeader(double netMonthly) {
    final positive = netMonthly >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: positive
            ? MintColors.scoreExcellent.withValues(alpha: 0.1)
            : MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💼', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le prix du changement',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currentJobLabel → $newJobLabel',
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Row(
      children: [
        const Expanded(flex: 3, child: SizedBox()),
        Expanded(
          flex: 2,
          child: Text(
            'Actuel',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Nouveau',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Delta',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAxisRow(JobAxis a) {
    final delta = a.newValue - a.currentValue;
    final isPositive = a.higherIsBetter ? delta >= 0 : delta <= 0;
    final color = delta == 0
        ? MintColors.textSecondary
        : isPositive
            ? MintColors.scoreExcellent
            : MintColors.scoreCritique;
    final sign = delta > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(a.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.label,
                        style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary),
                      ),
                      if (a.note != null)
                        Text(
                          a.note!,
                          style: GoogleFonts.inter(fontSize: 9, color: MintColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmt(a.currentValue)} ${a.unit.replaceAll('CHF/', '')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmt(a.newValue)} ${a.unit.replaceAll('CHF/', '')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$sign${_fmt(delta)} ${a.unit.replaceAll('CHF/', '')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetCallout(double netMonthly) {
    final positive = netMonthly >= 0;
    final sign = netMonthly >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (positive ? MintColors.scoreExcellent : MintColors.scoreCritique)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (positive ? MintColors.scoreExcellent : MintColors.scoreCritique)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(positive ? '💰' : '⚠️', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact réel : $sign CHF ${_fmt(netMonthly.abs())}/mois',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: positive ? MintColors.scoreExcellent : MintColors.scoreCritique,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  positive
                      ? 'Ton nouveau job est financièrement avantageux — négocie fort !'
                      : 'Pense à négocier pour compenser. Chaque CHF compte sur 20 ans de LPP.',
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

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CO art. 335, LPP art. 14-16.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
