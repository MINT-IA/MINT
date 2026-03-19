import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Generic card for displaying a financial summary section.
///
/// Used in FinancialSummaryScreen — each section (Revenus, Prévoyance,
/// Patrimoine, Dépenses, Dettes) uses this same widget with different data.
///
/// Supports:
/// - Standard lines (label + value)
/// - Section headers (divider with label)
/// - Subtotal lines (intermediate bold lines)
/// - Hero line (highlighted key number with colored background)
/// - Hint text (small educational note)
class FinancialSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<FinancialLine> lines;
  final FinancialLine? totalLine;
  final VoidCallback? onScanCertificate;
  final String? scanLabel;
  final VoidCallback? onEdit;
  final String? footnote;

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
    this.footnote,
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
                  Semantics(
                    label: 'Modifier',
                    button: true,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: MintColors.primary,
                      ),
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
                for (final line in lines) _buildLineWidget(line),
              ],
            ),
          ),
          // Total line
          if (totalLine != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (totalLine!.isHero)
              _buildHeroLine(totalLine!)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildLine(totalLine!, isBold: true),
              ),
          ],
          // Footnote
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                footnote!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.3,
                ),
              ),
            ),
          // Scan certificate CTA
          if (onScanCertificate != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Semantics(
              label: scanLabel ?? 'Scanner un certificat',
              button: true,
              child: InkWell(
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
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Route to appropriate rendering based on line type.
  Widget _buildLineWidget(FinancialLine line) {
    if (line.isSectionHeader) return _buildSectionHeader(line);
    if (line.isSubtotal) return _buildSubtotalLine(line);
    if (line.isHero) return _buildHeroLine(line);
    if (line.isHint) return _buildHintLine(line);
    return _buildLine(line);
  }

  /// Section header: "── Déductions salariales ──"
  Widget _buildSectionHeader(FinancialLine line) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              line.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: MintColors.textMuted,
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  /// Subtotal line: bold, with top divider.
  Widget _buildSubtotalLine(FinancialLine line) {
    return Column(
      children: [
        const Divider(height: 8),
        _buildLine(line, isBold: true),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Hero line: highlighted key number with colored background.
  Widget _buildHeroLine(FinancialLine line) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ),
          Text(
            line.formattedValue,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Hint line: small educational note with lightbulb.
  Widget _buildHintLine(FinancialLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u{1F4A1} ',
            style: GoogleFonts.inter(fontSize: 11),
          ),
          Expanded(
            child: Text(
              line.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MintColors.textMuted,
                height: 1.3,
              ),
            ),
          ),
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
          if (line.formattedValue.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.formattedValue,
                  style: GoogleFonts.inter(
                    fontSize: isBold ? 14 : 13,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    color: line.isDeduction
                        ? MintColors.error
                        : MintColors.textPrimary,
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
      ProfileDataSource.crossValidated => ('\u2713', MintColors.success),
      ProfileDataSource.estimated => ('~', MintColors.warning),
      ProfileDataSource.certificate => ('\u2B06', MintColors.info),
      ProfileDataSource.openBanking => ('\u2B06', MintColors.info),
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
///
/// Supports multiple rendering modes:
/// - Standard line: label + value (default)
/// - Section header: divider with centered label (isSectionHeader)
/// - Subtotal: bold intermediate total (isSubtotal)
/// - Hero: highlighted key number with colored background (isHero)
/// - Hint: small educational note with lightbulb (isHint)
/// - Deduction: value displayed in red with − prefix (isDeduction)
class FinancialLine {
  final String label;
  final String formattedValue;
  final ProfileDataSource? source;
  final bool indent;
  final bool isLast;
  final bool isSectionHeader;
  final bool isSubtotal;
  final bool isHero;
  final bool isHint;
  final bool isDeduction;

  const FinancialLine({
    required this.label,
    this.formattedValue = '',
    this.source,
    this.indent = false,
    this.isLast = false,
    this.isSectionHeader = false,
    this.isSubtotal = false,
    this.isHero = false,
    this.isHint = false,
    this.isDeduction = false,
  })  : assert(
          !(isSectionHeader && isSubtotal) &&
              !(isSectionHeader && isHero) &&
              !(isSectionHeader && isHint) &&
              !(isSubtotal && isHero) &&
              !(isSubtotal && isHint) &&
              !(isHero && isHint),
          'FinancialLine: isSectionHeader, isSubtotal, isHero, isHint '
          'are mutually exclusive rendering modes.',
        );
}
