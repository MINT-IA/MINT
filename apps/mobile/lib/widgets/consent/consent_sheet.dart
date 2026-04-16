// ConsentSheet — bottom sheet shown before any operation that needs granular
// consent (document upload, couple projection).
//
// v2.7 Phase 29 / PRIV-01.
//
// Displays one row per purpose: what, why, duration, revocable. User must
// affirmatively tap "Accepter". "Refuser" closes the sheet and returns false;
// the calling flow is responsible for aborting the operation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class ConsentSheet extends StatelessWidget {
  final List<ConsentPurpose> purposes;

  const ConsentSheet({super.key, required this.purposes});

  static Future<bool?> show(
    BuildContext context, {
    required List<ConsentPurpose> purposes,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConsentSheet(purposes: purposes),
    );
  }

  String _titleForPurpose(S l, ConsentPurpose p) {
    switch (p) {
      case ConsentPurpose.visionExtraction:
        return l.consentPurposeVisionExtraction;
      case ConsentPurpose.persistence365d:
        return l.consentPurposePersistence365d;
      case ConsentPurpose.transferUsAnthropic:
        return l.consentPurposeTransferUsAnthropic;
      case ConsentPurpose.coupleProjection:
        return l.consentPurposeCoupleProjection;
    }
  }

  String _whyForPurpose(S l, ConsentPurpose p) {
    switch (p) {
      case ConsentPurpose.visionExtraction:
        return l.consentPurposeVisionExtractionWhy;
      case ConsentPurpose.persistence365d:
        return l.consentPurposePersistence365dWhy;
      case ConsentPurpose.transferUsAnthropic:
        return l.consentPurposeTransferUsAnthropicWhy;
      case ConsentPurpose.coupleProjection:
        return l.consentPurposeCoupleProjectionWhy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.consentSheetTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.consentSheetSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: purposes.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (_, i) {
                      final p = purposes[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleForPurpose(l, p),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _whyForPurpose(l, p),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: MintColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l.consentSheetRefuse),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: MintColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l.consentSheetAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
