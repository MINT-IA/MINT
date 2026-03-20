import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Reusable S46 card for a single enrichment action.
class EnrichmentSuggestionCard extends StatelessWidget {
  final String action;
  final int impactPoints;
  final String method;
  final VoidCallback? onTap;

  const EnrichmentSuggestionCard({
    super.key,
    required this.action,
    required this.impactPoints,
    required this.method,
    this.onTap,
  });

  IconData _iconForMethod() {
    switch (method) {
      case 'documentScan':
      case 'documentScanVerified':
      case 'document_scan':
        return Icons.document_scanner_outlined;
      case 'openBanking':
      case 'open_banking':
        return Icons.account_balance_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MintColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        label: 'interactive element',
        button: true,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            children: [
              Icon(_iconForMethod(), color: MintColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+$impactPoints',
                style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),),
    );
  }
}
