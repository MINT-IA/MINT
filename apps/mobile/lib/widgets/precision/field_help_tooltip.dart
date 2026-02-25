import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/precision/precision_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Reusable tooltip widget for financial fields.
///
/// Displays an info icon next to a form field. On tap, opens a
/// bottom sheet showing:
/// - Where to find the exact number
/// - Document name (FR + DE)
/// - Fallback estimation if the user doesn't have the document
///
/// Usage:
/// ```dart
/// Row(
///   children: [
///     Text('Avoir LPP total'),
///     FieldHelpTooltip(fieldName: 'lpp_total'),
///   ],
/// )
/// ```
class FieldHelpTooltip extends StatelessWidget {
  /// Field identifier matching [PrecisionService] field-help keys.
  final String fieldName;

  /// Optional estimated fallback value to display.
  final double? estimatedValue;

  /// Optional callback when user taps "Utiliser l'estimation".
  final VoidCallback? onUseEstimate;

  const FieldHelpTooltip({
    super.key,
    required this.fieldName,
    this.estimatedValue,
    this.onUseEstimate,
  });

  @override
  Widget build(BuildContext context) {
    final help = PrecisionService.getFieldHelp(fieldName);
    if (help == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _showHelpSheet(context, help),
      borderRadius: const Borderconst Radius.circular(20),
      child: const Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline,
          size: 18,
          color: MintColors.info,
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context, FieldHelp help) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: const Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: const Borderconst Radius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Ou trouver ce chiffre ?',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Where to find
              _InfoRow(
                icon: Icons.search,
                label: 'Localisation',
                text: help.whereToFind,
              ),
              const SizedBox(height: 12),

              // Document name
              _InfoRow(
                icon: Icons.description_outlined,
                label: 'Document',
                text: help.documentName,
              ),
              const SizedBox(height: 12),

              // German name
              _InfoRow(
                icon: Icons.translate,
                label: 'En allemand',
                text: help.germanName,
              ),

              // Fallback estimation
              if (help.fallbackEstimation != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MintColors.info.withAlpha(15),
                    borderRadius: const Borderconst Radius.circular(12),
                    border: Border.all(color: MintColors.info.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Si tu n\'as pas le document',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MintColors.info,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        help.fallbackEstimation!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (estimatedValue != null && onUseEstimate != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              onUseEstimate?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MintColors.info,
                              side: const BorderSide(color: MintColors.info),
                              shape: RoundedRectangleBorder(
                                borderRadius: const Borderconst Radius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              'Utiliser l\'estimation '
                              '(~CHF ${_formatValue(estimatedValue!)})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static String _formatValue(double v) {
    final intV = v.round();
    if (intV >= 1000) {
      final str = intV.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return intV.toString();
  }
}

/// Internal row widget used inside the help bottom sheet.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MintColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
