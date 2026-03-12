import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Compact enrichment CTA prompting the user to scan a document
/// and showing the count of missing profile fields.
class EnrichmentCta extends StatelessWidget {
  final int missingFieldsCount;
  final VoidCallback? onTap;

  const EnrichmentCta({
    super.key,
    required this.missingFieldsCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.document_scanner,
              color: MintColors.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.enrichmentCtaScan,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.enrichmentCtaMissing(missingFieldsCount),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: MintColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
