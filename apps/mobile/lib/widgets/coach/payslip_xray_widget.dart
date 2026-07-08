import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
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
  final IconData icon;
  final double amount;
  final double percentage;
  final String explanation;
  final String? legalRef;

  const PayslipLine({
    required this.label,
    required this.icon,
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
    final l = S.of(context)!;
    return Semantics(
      label: l.payslipXraySemantics(
        formatChfWithPrefix(widget.grossSalary),
        formatChfWithPrefix(widget.netSalary),
      ),
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
              l.payslipXrayTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l.payslipXraySubtitle,
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
            const SizedBox(height: 16),

            // ── Gross ──
            _buildHeaderLine(l.payslipXrayGrossSalary, widget.grossSalary, true),
            const Divider(height: 16),

            // ── Deductions ──
            ...widget.deductions.asMap().entries.map((e) =>
                _buildDeductionLine(e.key, e.value)),

            const Divider(height: 16),

            // ── Net ──
            _buildHeaderLine(l.payslipXrayNetSalary, widget.netSalary, false),

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
                    const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.payslipXrayEmployerCost(
                          formatChfWithPrefix(widget.employerHiddenCost!),
                        ),
                        style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              l.payslipXrayDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
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
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          formatChfWithPrefix(amount),
          style: MintTextStyles.titleMedium(color: isGross ? MintColors.textPrimary : MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w800),
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
                Icon(line.icon, size: 16, color: MintColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${line.label} (${line.percentage.toStringAsFixed(1)}%)',
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                  ),
                ),
                Text(
                  '-${formatChfWithPrefix(line.amount)}',
                  style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w600),
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
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
