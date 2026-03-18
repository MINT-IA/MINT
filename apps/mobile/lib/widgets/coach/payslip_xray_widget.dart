import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  PAYSLIP X-RAY WIDGET — P5-C / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Reproduction visuelle d'une fiche de paie suisse.
//  Tap sur chaque ligne → explication en une phrase.
//
//  Widget pur — aucune dependance Provider.
//  Lois : L1 (CHF/mois) + L4 (raconte, ne montre pas)
// ────────────────────────────────────────────────────────────

/// Single deduction line on the payslip.
class PayslipLine {
  final String label;
  final String emoji;
  final double amount;
  final double percentage;
  final String explanation;
  final String? legalRef;

  const PayslipLine({
    required this.label,
    required this.emoji,
    required this.amount,
    required this.percentage,
    required this.explanation,
    this.legalRef,
  });
}

class PayslipXRayWidget extends StatefulWidget {
  final double grossSalary;
  final double netSalary;
  final List<PayslipLine> deductions;
  final double? employerHiddenCost;

  const PayslipXRayWidget({
    super.key,
    required this.grossSalary,
    required this.netSalary,
    required this.deductions,
    this.employerHiddenCost,
  });

  @override
  State<PayslipXRayWidget> createState() => _PayslipXRayWidgetState();
}

class _PayslipXRayWidgetState extends State<PayslipXRayWidget> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Radiographie fiche de paie. '
          'Brut\u00a0: ${formatChfWithPrefix(widget.grossSalary)}, '
          'Net\u00a0: ${formatChfWithPrefix(widget.netSalary)}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radiographie de ta fiche de paie',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tape sur chaque ligne pour comprendre',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // ── Gross ──
            _buildHeaderLine('Salaire brut', widget.grossSalary, true),
            const Divider(height: 16),

            // ── Deductions ──
            ...widget.deductions.asMap().entries.map((e) =>
                _buildDeductionLine(e.key, e.value)),

            const Divider(height: 16),

            // ── Net ──
            _buildHeaderLine('Salaire net', widget.netSalary, false),

            // ── Employer hidden cost ──
            if (widget.employerHiddenCost != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MintColors.primary.withValues(alpha: 0.15),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('\ud83d\udca1',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ton vrai salaire\u00a0: '
                        '${formatChfWithPrefix(widget.employerHiddenCost!)} '
                        '(cotisations employeur incluses)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLine(String label, double amount, bool isGross) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Text(
          formatChfWithPrefix(amount),
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isGross ? MintColors.textPrimary : MintColors.scoreExcellent,
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionLine(int index, PayslipLine line) {
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() {
        _expandedIndex = isExpanded ? null : index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isExpanded
              ? MintColors.primary.withValues(alpha: 0.04)
              : MintColors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(line.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${line.label} (${line.percentage.toStringAsFixed(1)}%)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '-${formatChfWithPrefix(line.amount)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.scoreCritique,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: MintColors.textMuted,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  line.explanation +
                      (line.legalRef != null ? ' (${line.legalRef})' : ''),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
