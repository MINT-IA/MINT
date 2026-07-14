import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class RetirementProjectionCard extends StatelessWidget {
  final RetirementProjection projection;

  const RetirementProjectionCard({
    super.key,
    required this.projection,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'financial_report_avs_pending',
          container: true,
          explicitChildNodes: true,
          child: Container(
            key: const Key('financial_report_avs_pending'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MintColors.info.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.avsGuideHeaderTitle,
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  l.avsGuideHeaderSubtitle,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  child: OutlinedButton(
                    onPressed: () => context.push('/scan/avs-guide'),
                    child: Text(l.visibilityHintCommandeAvs),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          identifier: 'financial_report_lpp_pending',
          container: true,
          explicitChildNodes: true,
          child: Container(
            key: const Key('financial_report_lpp_pending'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MintColors.info.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(l.futurRenteLpp, l.coverageCheckAVerifier),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/scan?type=${DocumentType.lppCertificate.name}',
                    ),
                    child: Text(l.dataBlockLppCta),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          identifier: 'financial_report_3a_pending',
          container: true,
          explicitChildNodes: true,
          child: Container(
            key: const Key('financial_report_3a_pending'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MintColors.info.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  l.reportPdfRetirementPillar3aCapital,
                  l.coverageCheckAVerifier,
                ),
                const SizedBox(height: 6),
                Text(
                  l.report3aPendingBody,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  child: OutlinedButton(
                    onPressed: () => context.push('/data-block/3a'),
                    child: Text(l.report3aPendingCta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: MintTextStyles.bodySmall(
            color: MintColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
