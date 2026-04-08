import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/coach_profile.dart'
    show CoachCivilStatus, CoachProfile;
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Whether the intent screen was reached from the onboarding golden path
/// (post-auth). Post-Phase-10-02a: both paths now land on /coach/chat with
/// an enriched CoachEntryPayload — this flag only controls whether the
/// coach bootstrap considers this the user's first-ever entry.
bool _isFromOnboarding(Map<String, dynamic>? extra) {
  if (extra == null) return true; // Default: onboarding path
  return extra['fromOnboarding'] as bool? ?? true;
}

/// Intent-based onboarding screen.
///
/// Replaces the old form-based Quick Start / Smart Onboarding.
/// Shows 6 situational chips — user taps one, triggers the full onboarding
/// pipeline: intent routing, premier eclairage computation, CapMemory seeding,
/// and navigation to /coach/chat (Phase 10-02a: unified merged path).
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
      // P-S1-01 (Phase 8c hot-fix): intentChipBilan + intentChipPrevoyance
      // removed from rendered list per anti-shame doctrine #3 (curriculum
      // framing) + CLAUDE.md anti-pattern #16 (retirement-default framing).
      // ARB keys + IntentRouter mapping kept for legacy deep-link / golden
      // journey routing (Pierre, Marc) — UI surface only is removed.
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
      // P-S1-01 (Phase 8c hot-fix): intentChipNouvelEmploi removed from
      // rendered list per Phase 3 DELETE #1 (redundant with premierEmploi +
      // changement). ARB key + IntentRouter mapping kept for Anna golden
      // journey + legacy routing.
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
                        // AESTH-05 per AUDIT_RETRAIT S1 (D-03 swap map)
                        color: MintColors.textSecondaryAaa,
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
                          // AESTH-05 per AUDIT_RETRAIT S1 (D-03 swap map)
                          color: MintColors.textMutedAaa,
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

    // Capture ALL BuildContext-dependent values BEFORE the first await
    // (STAB-07 / D-16: no use_build_context_synchronously across async gaps).
    final router = GoRouter.of(context);
    final coachProfile = context.read<CoachProfileProvider>().profile;
    final payloadProvider = context.read<CoachEntryPayloadProvider>();
    final profile = _buildMinimalProfileFor(coachProfile);

    AnalyticsService().trackCTAClick(
      'intent_chip_tapped',
      screenName: '/onboarding/intent',
      data: {'chipKey': chip.chipKey, 'label': chip.label},
    );

    // Persist selected intent. Onboarding-done is written later by
    // coach_chat_screen on first successful chat entry from an intent payload
    // (Phase 10-02a: conversation is the only honest "onboarding done" signal).
    await ReportPersistenceService.setSelectedOnboardingIntent(chip.chipKey);

    // ── Unified path (Phase 10-02a): both onboarding and non-onboarding
    // land on /coach/chat with an enriched CoachEntryPayload. No more
    // branch to quick-start. The `fromOnboarding` flag is forwarded via
    // the payload so the chat bootstrap can detect first-entry.

    // Resolve intent mapping.
    final mapping = IntentRouter.forChipKey(chip.chipKey);

    if (mapping != null) {
      // Compute premier eclairage.
      final choc = PremierEclairageSelector.select(
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

    // Build coach payload. `fromOnboarding` is forwarded via `data` so
    // coach_chat_screen can detect first-entry and set miniOnboardingCompleted.
    final payload = CoachEntryPayload(
      source: CoachEntrySource.onboardingIntent,
      userMessage: chip.message,
      data: {'fromOnboarding': fromOnboarding},
    );
    payloadProvider.setPayload(payload);

    // Phase 10-02a: unified target = /coach/chat (merged from /home?tab=0).
    // Screens-before-first-insight reduced from 5 to 2 (landing + intent).
    router.go('/coach/chat', extra: payload);
  }

  /// Build a [MinimalProfileResult] from an already-captured [CoachProfile].
  ///
  /// Accepting the profile directly (instead of reading from BuildContext)
  /// keeps the call-site free of post-await BuildContext usage (STAB-07).
  MinimalProfileResult _buildMinimalProfileFor(CoachProfile? coachProfile) {
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

    // Zero-valued profile — PremierEclairageSelector pedagogical fallback (D-08).
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
