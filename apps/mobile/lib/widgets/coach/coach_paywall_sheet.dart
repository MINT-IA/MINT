import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/ios_iap_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/subscription_service.dart';

/// Multi-tier paywall bottom sheet displayed when a free user taps a
/// Coach-locked feature.
///
/// Shows a tier comparison (Starter / Premium / Couple+):
/// - Feature highlights per tier
/// - CTA button per tier
/// - 14-day free trial badge
/// - Restore purchases option
/// - Required LSFin disclaimer
///
/// Usage:
/// ```dart
/// CoachPaywallSheet.show(context);
/// ```
class CoachPaywallSheet extends StatefulWidget {
  const CoachPaywallSheet({super.key});

  /// Show the paywall as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    AnalyticsService().trackEvent(
      'paywall_shown',
      category: 'conversion',
      screenName: 'coach_paywall',
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SubscriptionProvider>(),
        child: const CoachPaywallSheet(),
      ),
    );
  }

  @override
  State<CoachPaywallSheet> createState() => _CoachPaywallSheetState();
}

class _CoachPaywallSheetState extends State<CoachPaywallSheet> {
  SubscriptionTier _selectedTier = SubscriptionTier.premium;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          _buildHeader(context),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Tier comparison cards
                  _buildTierComparison(),

                  const SizedBox(height: 24),

                  // Trial badge
                  _buildTrialBadge(),

                  const SizedBox(height: 16),

                  // Primary CTA
                  _buildPrimaryCTA(context),

                  const SizedBox(height: 12),

                  // Restore purchases
                  _buildRestoreButton(context),

                  const SizedBox(height: 16),

                  // Disclaimer
                  _buildDisclaimer(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle + close button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Close button
              Semantics(
                label: S.of(context)!.paywallClose,
                button: true,
                child: GestureDetector(
                  onTap: () {
                    AnalyticsService().trackEvent(
                    'paywall_dismissed',
                    category: 'conversion',
                    screenName: 'coach_paywall',
                  );
                  context.pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MintColors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: MintColors.white,
                    size: 20,
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.paywallTitle,
            style: MintTextStyles.headlineMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.paywallSubtitle,
            style: MintTextStyles.labelLarge(color: MintColors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Tier comparison
  // ──────────────────────────────────────────────────────────────────

  Widget _buildTierComparison() {
    final showCouplePlus = FeatureFlags.enableCouplePlusTier;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTierCard(
            tier: SubscriptionTier.starter,
            name: 'Starter',
            price: '4.90',
            isRecommended: false,
            features: const [
              'Dashboard trajectoire',
              'Forecast adaptatif',
              'Check-in mensuel',
              'Alertes proactives',
            ],
          ),
          const SizedBox(width: 12),
          _buildTierCard(
            tier: SubscriptionTier.premium,
            name: 'Premium',
            price: '9.90',
            isRecommended: true,
            features: const [
              'Tout Starter +',
              'Score evolutif',
              'Coach LLM',
              'Scenarios "Et si..."',
              'Export PDF',
              'Monte Carlo',
              'Modules arbitrage',
            ],
          ),
          if (showCouplePlus) ...[
            const SizedBox(width: 12),
            _buildTierCard(
              tier: SubscriptionTier.couplePlus,
              name: 'Couple+',
              price: '14.90',
              isRecommended: false,
              features: const [
                'Tout Premium +',
                '2 profils actifs',
                'Optimisation conjointe',
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required SubscriptionTier tier,
    required String name,
    required String price,
    required bool isRecommended,
    required List<String> features,
  }) {
    final isSelected = _selectedTier == tier;

    return Semantics(
      label: S.of(context)!.paywallSelectTier(name),
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _selectedTier = tier),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.coachBubble
              : MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MintColors.primary
                : MintColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier name + recommended badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.scoreExcellent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      S.of(context)!.paywallFeatureTop,
                      style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Price
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$price CHF',
                    style: MintTextStyles.headlineSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: ' ${S.of(context)!.paywallPricePerMonth}',
                    style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Feature list
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: MintColors.scoreExcellent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Selection indicator
            Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.border,
                    width: 2,
                  ),
                  color: isSelected ? MintColors.primary : MintColors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: MintColors.white, size: 14)
                    : null,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Trial badge
  // ──────────────────────────────────────────────────────────────────

  Widget _buildTrialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: MintColors.scoreExcellent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.paywallTrialBadge,
            style: MintTextStyles.bodyMedium(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Primary CTA
  // ──────────────────────────────────────────────────────────────────

  Widget _buildPrimaryCTA(BuildContext context) {
    final isIosIap = IosIapService.isSupportedPlatform;
    final tierLabel = switch (_selectedTier) {
      SubscriptionTier.starter => 'Starter',
      SubscriptionTier.premium => 'Premium',
      SubscriptionTier.couplePlus => 'Couple+',
      SubscriptionTier.free => 'Starter',
    };

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () async {
          AnalyticsService().trackCTAClick(
            isIosIap ? 'paywall_upgrade' : 'paywall_trial_start',
            screenName: 'coach_paywall',
          );
          AnalyticsService().trackEvent(
            'paywall_tier_selected',
            category: 'conversion',
            data: {'tier': _selectedTier.apiValue},
            screenName: 'coach_paywall',
          );
          final provider = context.read<SubscriptionProvider>();
          final success = isIosIap
              ? await provider.upgrade(_selectedTier)
              : await provider.startTrial();
          if (success && context.mounted) {
            AnalyticsService().trackEvent(
              'paywall_conversion',
              category: 'conversion',
              data: {
                'method': isIosIap ? 'iap' : 'trial',
                'tier': _selectedTier.apiValue,
              },
              screenName: 'coach_paywall',
            );
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isIosIap
                      ? S.of(context)!.paywallSubscriptionActivated(tierLabel)
                      : S.of(context)!.paywallTrialActivated,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          isIosIap
              ? S.of(context)!.paywallChooseTier(tierLabel)
              : S.of(context)!.paywallStartTrial,
          style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Restore button
  // ──────────────────────────────────────────────────────────────────

  Widget _buildRestoreButton(BuildContext context) {
    return TextButton(
      onPressed: () async {
        AnalyticsService().trackCTAClick(
          'paywall_restore',
          screenName: 'coach_paywall',
        );
        final provider = context.read<SubscriptionProvider>();
        await provider.restore();
        if (context.mounted) {
          final isCoach = provider.isCoach;
          if (isCoach) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.of(context)!.paywallRestoreSuccess)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.of(context)!.paywallRestoreNoPurchase)),
            );
          }
        }
      },
      child: Text(
        S.of(context)!.paywallRestoreButton,
        style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Disclaimer
  // ──────────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.paywallDisclaimer,
      textAlign: TextAlign.center,
      style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.4),
    );
  }
}
