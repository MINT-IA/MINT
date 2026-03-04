import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Generic card for displaying a financial summary section.
///
/// Used in FinancialSummaryScreen — each section (Revenus, Prévoyance,
/// Patrimoine, Dépenses, Dettes) uses this same widget with different data.
class FinancialSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<FinancialLine> lines;
  final FinancialLine? totalLine;
  final VoidCallback? onScanCertificate;
  final String? scanLabel;
  final VoidCallback? onEdit;

  const FinancialSummaryCard({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor = MintColors.primary,
    required this.lines,
    this.totalLine,
    this.onScanCertificate,
    this.scanLabel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: MintColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Lines
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                for (final line in lines) _buildLine(line),
              ],
            ),
          ),
          // Total line
          if (totalLine != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildLine(totalLine!, isBold: true),
            ),
          ],
          // Scan certificate CTA
          if (onScanCertificate != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: onScanCertificate,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner_outlined,
                        size: 16, color: MintColors.info),
                    const SizedBox(width: 8),
                    Text(
                      scanLabel ?? 'Scanner un certificat',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLine(FinancialLine line, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: line.indent ? 16 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indent prefix
          if (line.indent)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                line.isLast ? '\u2514 ' : '\u251C ',
                style: TextStyle(
                  fontSize: 12,
                  color: MintColors.textMuted,
                  fontFamily: GoogleFonts.inter().fontFamily,
                ),
              ),
            ),
          // Label
          Expanded(
            child: Text(
              line.label,
              style: GoogleFonts.inter(
                fontSize: isBold ? 13 : 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color:
                    isBold ? MintColors.textPrimary : MintColors.textSecondary,
              ),
            ),
          ),
          // Value + source indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line.formattedValue,
                style: GoogleFonts.inter(
                  fontSize: isBold ? 14 : 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              if (line.source != null) ...[
                const SizedBox(width: 6),
                _sourceIndicator(line.source!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceIndicator(ProfileDataSource source) {
    final (String label, Color color) = switch (source) {
      ProfileDataSource.userInput => ('\u2713', MintColors.success),
      ProfileDataSource.estimated => ('~', MintColors.warning),
      ProfileDataSource.certificate => ('\u2B06', MintColors.info),
    };
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// A single line in a FinancialSummaryCard.
class FinancialLine {
  final String label;
  final String formattedValue;
  final ProfileDataSource? source;
  final bool indent;
  final bool isLast;

  const FinancialLine({
    required this.label,
    required this.formattedValue,
    this.source,
    this.indent = false,
    this.isLast = false,
  });
}
