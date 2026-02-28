import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  COUPLE PHASE TIMELINE — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  Affiche la timeline des phases de retraite en couple :
//    Phase 1 : Un·e partenaire a la retraite, l'autre travaille
//    Phase 2 : Les deux a la retraite
//
//  Montre le changement de revenu a chaque transition.
//  Visible uniquement si profile.conjoint != null.
//
//  Source : RetirementProjectionResult.phases
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class CouplePhaseTimeline extends StatelessWidget {
  final String userName;
  final String conjointName;
  final int userRetirementYear;
  final int conjointRetirementYear;
  final List<RetirementPhase> phases;

  const CouplePhaseTimeline({
    super.key,
    required this.userName,
    required this.conjointName,
    required this.userRetirementYear,
    required this.conjointRetirementYear,
    required this.phases,
  });

  @override
  Widget build(BuildContext context) {
    if (phases.length < 2) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MintColors.indigo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: MintColors.indigo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Timeline couple',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Retirement dates summary
          _buildRetirementDate(
            name: userName,
            year: userRetirementYear,
            color: MintColors.info,
          ),
          const SizedBox(height: 6),
          _buildRetirementDate(
            name: conjointName,
            year: conjointRetirementYear,
            color: MintColors.purple,
          ),
          const SizedBox(height: 16),

          // Phase timeline
          ...phases.asMap().entries.map((entry) {
            final index = entry.key;
            final phase = entry.value;
            final isLast = index == phases.length - 1;
            return _buildPhaseRow(phase, isLast);
          }),

          const SizedBox(height: 10),
          Text(
            'Projection \u00e9ducative. Les dates et montants sont '
            'des estimations qui peuvent varier (LSFin).',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementDate({
    required String name,
    required int year,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$name\u00a0: retraite en $year',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseRow(RetirementPhase phase, bool isLast) {
    final yearRange = phase.endYear != null
        ? '${phase.startYear}\u2013${phase.endYear}'
        : '${phase.startYear}+';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isLast ? MintColors.success : MintColors.info,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MintColors.card,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 50,
                  color: MintColors.lightBorder,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        yearRange,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MintColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phase.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Revenu m\u00e9nage\u00a0: ${_formatChf(phase.totalMonthly)}/mois',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Income sources breakdown (compact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: phase.sources
                        .where((s) => s.monthlyAmount > 0)
                        .map((s) => Text(
                              '${s.label}\u00a0: ${_formatChf(s.monthlyAmount)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: MintColors.textMuted,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00a0${buffer.toString()}';
  }
}
