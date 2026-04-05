import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Intent-based onboarding screen.
///
/// Replaces the old form-based Quick Start / Smart Onboarding.
/// Shows 7 situational chips — user taps one, opens coach chat
/// with the chip text as `userMessage` via [CoachEntryPayload].
///
/// No data collection. No formulaire. The coach handles everything.
///
/// Design System category: A (Hero) — single intention, minimal UI.
class IntentScreen extends StatelessWidget {
  const IntentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    // Ordered list of chips: label + userMessage for coach.
    // "Autre…" sends null userMessage → coach shows silent opener.
    final chips = <_IntentChip>[
      _IntentChip(label: l10n.intentChip3a, message: l10n.intentChip3a),
      _IntentChip(label: l10n.intentChipBilan, message: l10n.intentChipBilan),
      _IntentChip(
        label: l10n.intentChipPrevoyance,
        message: l10n.intentChipPrevoyance,
      ),
      _IntentChip(
        label: l10n.intentChipFiscalite,
        message: l10n.intentChipFiscalite,
      ),
      _IntentChip(label: l10n.intentChipProjet, message: l10n.intentChipProjet),
      _IntentChip(
        label: l10n.intentChipChangement,
        message: l10n.intentChipChangement,
      ),
      _IntentChip(label: l10n.intentChipAutre, message: null),
    ];

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: MintEntrance(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: MintSpacing.xxxl),
                    // ── Hero ──
                    Text(
                      l10n.intentScreenTitle,
                      style: MintTextStyles.headlineLarge(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      l10n.intentScreenSubtitle,
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: MintSpacing.xl),
                    // ── Chips ──
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: chips.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: MintSpacing.sm),
                        itemBuilder: (context, index) {
                          final chip = chips[index];
                          return _IntentChipTile(
                            label: chip.label,
                            onTap: () => _onChipTap(
                              context,
                              chip,
                            ),
                          );
                        },
                      ),
                    ),
                    // ── Microcopy ──
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: MintSpacing.xl,
                        top: MintSpacing.sm,
                      ),
                      child: Text(
                        l10n.intentScreenMicrocopy,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onChipTap(BuildContext context, _IntentChip chip) async {
    AnalyticsService().trackCTAClick(
      'intent_chip_tapped',
      screenName: '/onboarding/intent',
      data: {'label': chip.label},
    );

    // Persist that onboarding intent was completed + which intent was chosen.
    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    await ReportPersistenceService.setSelectedOnboardingIntent(chip.label);

    if (!context.mounted) return;

    // Build payload: userMessage for named intents, null for "Autre…".
    final payload = CoachEntryPayload(
      source: CoachEntrySource.onboardingIntent,
      userMessage: chip.message,
    );

    context.read<CoachEntryPayloadProvider>().setPayload(payload);
    context.go('/home?tab=1');
  }
}

// ---------------------------------------------------------------------------
// Private data class for chip config
// ---------------------------------------------------------------------------

class _IntentChip {
  final String label;

  /// The message sent to the coach. Null for "Autre…" (silent opener).
  final String? message;

  const _IntentChip({required this.label, this.message});
}

// ---------------------------------------------------------------------------
// Chip tile widget
// ---------------------------------------------------------------------------

class _IntentChipTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _IntentChipTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MintColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: MintSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: MintColors.lightBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: MintTextStyles.bodyLarge(),
          ),
        ),
      ),
    );
  }
}
