import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-E  Le Bulletin scolaire de ta couverture invalidité
//  Charte : L5 (1 action) + L2 (Avant/Après notes)
//  Source : LAMal, LAVS, LPP art. 23-26
// ────────────────────────────────────────────────────────────

class CoverageItem {
  const CoverageItem({
    required this.label,
    required this.grade,
    required this.detail,
    this.legalRef,
    this.emoji,
  });

  final String label;
  final String grade; // A+, A, B+, B, C, D, F
  final String detail;
  final String? legalRef;
  final String? emoji;
}

class DisabilityScorecardWidget extends StatelessWidget {
  const DisabilityScorecardWidget({
    super.key,
    required this.items,
    required this.overallGrade,
    required this.lifeDropPercent,
  });

  final List<CoverageItem> items;
  final String overallGrade;
  final double lifeDropPercent;

  static Color _gradeColor(String grade) {
    return switch (grade) {
      'A+' || 'A' || 'A-' => MintColors.scoreExcellent,
      'B+' || 'B' || 'B-' => MintColors.scoreBon,
      'C+' || 'C' || 'C-' => MintColors.scoreAttention,
      'D' => const Color(0xFFFF7043),
      _ => MintColors.scoreCritique,
    };
  }

  static double _gradeToScore(String grade) {
    return switch (grade) {
      'A+' => 1.0,
      'A' => 0.95,
      'A-' => 0.88,
      'B+' => 0.82,
      'B' => 0.78,
      'B-' => 0.72,
      'C+' => 0.66,
      'C' => 0.62,
      'C-' => 0.58,
      'D' => 0.45,
      _ => 0.20,
    };
  }

  CoverageItem? get _worstItem {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => _gradeToScore(a.grade) < _gradeToScore(b.grade) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final worst = _worstItem;
    final overallColor = _gradeColor(overallGrade);

    return Semantics(
      label: 'Bulletin couverture invalidité notes A-F',
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
                  _buildGradeTable(),
                  const SizedBox(height: 20),
                  _buildOverallGrade(overallGrade, overallColor),
                  const SizedBox(height: 16),
                  if (worst != null) _buildWeakestSubject(worst),
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
        color: Color(0xFFF3E5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('📋', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton bulletin de couverture invalidité',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Note A–F sur chaque pilier de ta protection',
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

  Widget _buildGradeTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MintColors.lightBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1),
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                _buildTableRow(e.value),
                if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Couverture',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'Note',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Détail',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(CoverageItem item) {
    final gradeColor = _gradeColor(item.grade);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (item.emoji != null) ...[
                  Text(item.emoji!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.grade,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: gradeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.detail,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallGrade(String grade, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Moyenne',
                style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
              ),
              Text(
                grade,
                style: GoogleFonts.montserrat(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu survivrais, mais ton niveau de vie baisserait de ${lifeDropPercent.toStringAsFixed(0)}%.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    fontWeight: FontWeight.w600,
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

  Widget _buildWeakestSubject(CoverageItem worst) {
    final worstColor = _gradeColor(worst.grade);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: worstColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: worstColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matière la plus faible : ${worst.label}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: worstColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            worst.detail,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (worst.legalRef != null) ...[
            const SizedBox(height: 4),
            Text(
              worst.legalRef!,
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAMal, LAVS, LPP art. 23-26.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
