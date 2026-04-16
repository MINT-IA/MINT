import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/widgets/coach/coach_paywall_sheet.dart';

/// Gate widget that restricts access to Coach-only features.
///
/// If the user has an active Coach subscription or trial,
/// [child] is shown normally.
///
/// If the user is on the free tier, the child is rendered
/// with a blur/dim overlay, a lock icon, and a "Debloquer"
/// button that opens the [CoachPaywallSheet].
///
/// Similar pattern to [SafeModeGate] but for subscription gating.
///
/// Usage:
/// ```dart
/// CoachGate(
///   feature: CoachFeature.dashboard,
///   child: DashboardTrajectoireWidget(),
/// )
/// ```
class CoachGate extends StatelessWidget {
  /// The content to show when the user has Coach access.
  final Widget child;

  /// The Coach feature this gate protects.
  final CoachFeature feature;

  /// Optional custom locked state widget.
  /// If null, a default blurred overlay with lock icon is shown.
  final Widget? lockedPlaceholder;

  const CoachGate({
    super.key,
    required this.child,
    required this.feature,
    this.lockedPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    final hasAccess = subscription.hasAccess(feature);

    if (hasAccess) {
      return child;
    }

    // Locked state
    if (lockedPlaceholder != null) {
      return lockedPlaceholder!;
    }

    return _buildLockedOverlay(context);
  }

  Widget _buildLockedOverlay(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Blurred child preview
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Opacity(
                opacity: 0.4,
                child: child,
              ),
            ),
          ),

          // Dark overlay with lock + CTA
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MintColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MintColors.coachBubble,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MintColors.coachAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: MintColors.coachAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Label
                    Text(
                      S.of(context)!.coachGateTitle,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.of(context)!.coachGateSubtitle,
                      style: MintTextStyles.labelMedium(color: MintColors.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // Unlock button
                    ElevatedButton.icon(
                      onPressed: () => CoachPaywallSheet.show(context),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: Text(
                        S.of(context)!.coachGateUnlock,
                        style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: MintColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
