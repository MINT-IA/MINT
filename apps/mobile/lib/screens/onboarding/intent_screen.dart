import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/coach_profile.dart' show CoachCivilStatus;
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Whether the intent screen was reached from the onboarding golden path
/// (post-auth). When true, navigates to quick-start instead of computing
/// premier eclairage and going to /home.
bool _isFromOnboarding(Map<String, dynamic>? extra) {
  if (extra == null) return true; // Default: onboarding path
  return extra['fromOnboarding'] as bool? ?? true;
}

/// Intent-based onboarding screen.
///
/// Replaces the old form-based Quick Start / Smart Onboarding.
/// Shows 7 situational chips — user taps one, triggers the full onboarding
/// pipeline: intent routing, premier eclairage computation, CapMemory seeding,
/// and navigation to /home?tab=0 (Aujourd'hui).
///
/// No data collection. No formulaire. The coach handles everything.
///
/// Design System category: A (Hero) — single intention, minimal UI.
class IntentScreen extends StatelessWidget {
  const IntentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    // Detect onboarding context from route extra.
    Map<String, dynamic>? routeExtra;
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) routeExtra = extra;
    } catch (_) {}
    final fromOnboarding = _isFromOnboarding(routeExtra);

    // Ordered list of chips: chipKey (ARB identifier) + label + userMessage.
    // "Autre…" sends null userMessage → coach shows silent opener.
    final chips = <_IntentChip>[
      _IntentChip(
        chipKey: 'intentChip3a',
        label: l10n.intentChip3a,
        message: l10n.intentChip3a,
      ),
      _IntentChip(
        chipKey: 'intentChipBilan',
        label: l10n.intentChipBilan,
        message: l10n.intentChipBilan,
      ),
      _IntentChip(
        chipKey: 'intentChipPrevoyance',
        label: l10n.intentChipPrevoyance,
        message: l10n.intentChipPrevoyance,
      ),
      _IntentChip(
        chipKey: 'intentChipFiscalite',
        label: l10n.intentChipFiscalite,
        message: l10n.intentChipFiscalite,
      ),
      _IntentChip(
        chipKey: 'intentChipProjet',
        label: l10n.intentChipProjet,
        message: l10n.intentChipProjet,
      ),
      _IntentChip(
        chipKey: 'intentChipChangement',
        label: l10n.intentChipChangement,
        message: l10n.intentChipChangement,
      ),
      _IntentChip(
        chipKey: 'intentChipPremierEmploi',
        label: l10n.intentChipPremierEmploi,
        message: l10n.intentChipPremierEmploi,
      ),
      _IntentChip(
        chipKey: 'intentChipNouvelEmploi',
        label: l10n.intentChipNouvelEmploi,
        message: l10n.intentChipNouvelEmploi,
      ),
      _IntentChip(
        chipKey: 'intentChipAutre',
        label: l10n.intentChipAutre,
        message: null,
      ),
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
                              fromOnboarding: fromOnboarding,
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

  Future<void> _onChipTap(
    BuildContext context,
    _IntentChip chip, {
    required bool fromOnboarding,
  }) async {
    final l10n = S.of(context)!;

    AnalyticsService().trackCTAClick(
      'intent_chip_tapped',
      screenName: '/onboarding/intent',
      data: {'chipKey': chip.chipKey, 'label': chip.label},
    );

    // Persist selected intent (but NOT onboarding completion — that moves to
    // plan_screen per Research Pitfall 3).
    await ReportPersistenceService.setSelectedOnboardingIntent(chip.chipKey);

    // ── Golden path: navigate to quick-start for data collection ──
    if (fromOnboarding) {
      if (!context.mounted) return;
      context.go('/onboarding/quick-start', extra: {'intent': chip.chipKey});
      return;
    }

    // ── Non-onboarding path (settings, re-selection): legacy behavior ──
    // Capture context-dependent values BEFORE any async gap.
    final profile = _buildMinimalProfile(context);
    final coachProfile = context.read<CoachProfileProvider>().profile;

    // Resolve intent mapping.
    final mapping = IntentRouter.forChipKey(chip.chipKey);

    if (mapping != null) {
      // Compute premier eclairage.
      final choc = ChiffreChocSelector.select(
        profile,
        stressType: mapping.stressType,
      );

      // Persist premier eclairage snapshot — display fields ONLY, no PII.
      await ReportPersistenceService.savePremierEclairageSnapshot({
        'value': choc.value,
        'title': choc.title,
        'subtitle': choc.subtitle,
        'colorKey': choc.colorKey,
        'suggestedRoute': mapping.suggestedRoute,
        'confidenceMode': choc.confidenceMode.name,
      });

      // Seed CapMemoryStore with goalIntentTag.
      final memory = await CapMemoryStore.load();
      final updated = memory.copyWith(
        declaredGoals: [mapping.goalIntentTag],
      );
      await CapMemoryStore.save(updated);

      // Seed CapSequenceEngine — requires CoachProfile.
      if (coachProfile != null) {
        CapSequenceEngine.build(
          profile: coachProfile,
          memory: updated,
          goalIntentTag: mapping.goalIntentTag,
          l: l10n,
        );
      }
    }

    if (!context.mounted) return;

    // Build coach payload (preserved from current behavior).
    final payload = CoachEntryPayload(
      source: CoachEntrySource.onboardingIntent,
      userMessage: chip.message,
    );
    context.read<CoachEntryPayloadProvider>().setPayload(payload);

    // Navigate to Aujourd'hui tab.
    context.go('/home?tab=0');
  }

  /// Build a [MinimalProfileResult] from available [CoachProfileProvider] data.
  ///
  /// If the user has completed QuickStart, the profile data drives the calculation.
  /// If no profile is available (fresh install), zero values produce a pedagogical
  /// chiffre choc per D-08 (ChiffreChocSelector handles the fallback internally).
  MinimalProfileResult _buildMinimalProfile(BuildContext context) {
    final coachProfile =
        context.read<CoachProfileProvider>().profile;

    if (coachProfile != null && coachProfile.salaireBrutMensuel > 0) {
      // Map etatCivil to MinimalProfileService householdType string.
      final householdType = switch (coachProfile.etatCivil) {
        CoachCivilStatus.marie || CoachCivilStatus.concubinage => 'couple',
        _ => 'single',
      };

      return MinimalProfileService.compute(
        age: coachProfile.age,
        grossSalary: coachProfile.revenuBrutAnnuel,
        canton: coachProfile.canton,
        employmentStatus: coachProfile.employmentStatus,
        householdType: householdType,
      );
    }

    // Zero-valued profile — ChiffreChocSelector pedagogical fallback (D-08).
    return const MinimalProfileResult(
      avsMonthlyRente: 0,
      lppAnnualRente: 0,
      lppMonthlyRente: 0,
      totalMonthlyRetirement: 0,
      grossMonthlySalary: 0,
      replacementRate: 0,
      retirementGapMonthly: 0,
      taxSaving3a: 0,
      marginalTaxRate: 0,
      currentSavings: 0,
      estimatedMonthlyExpenses: 0,
      monthlyDebtImpact: 0,
      liquidityMonths: 0,
      canton: 'VD',
      age: 35,
      grossAnnualSalary: 0,
      householdType: 'single',
      isPropertyOwner: false,
      existing3a: 0,
      existingLpp: 0,
      estimatedFields: [
        'householdType',
        'isPropertyOwner',
        'currentSavings',
        'existing3a',
        'existingLpp',
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private data class for chip config
// ---------------------------------------------------------------------------

class _IntentChip {
  /// ARB identifier key (e.g. 'intentChip3a'). Persisted to SharedPreferences.
  ///
  /// IMPORTANT: This is the chipKey, NOT the resolved localized string.
  /// Always pass chipKey to persistence and routing — never chip.label.
  final String chipKey;

  final String label;

  /// The message sent to the coach. Null for "Autre…" (silent opener).
  final String? message;

  const _IntentChip({
    required this.chipKey,
    required this.label,
    this.message,
  });
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
