import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Privacy-first analytics consent banner
///
/// Displays a bottom banner on first launch asking for analytics consent.
/// LPD (Swiss Privacy Law) compliant - opt-in required.
///
/// Usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Scaffold(
///     body: Stack(
///       children: [
///         // Your screen content
///         AnalyticsConsentBanner(),
///       ],
///     ),
///   );
/// }
/// ```
class AnalyticsConsentBanner extends StatefulWidget {
  const AnalyticsConsentBanner({super.key});

  @override
  State<AnalyticsConsentBanner> createState() => _AnalyticsConsentBannerState();
}

class _AnalyticsConsentBannerState extends State<AnalyticsConsentBanner>
    with SingleTickerProviderStateMixin {
  bool _shouldShow = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Check if we should show the banner
    _checkShouldShow();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkShouldShow() async {
    final hasAsked = await AnalyticsService.hasAskedForConsent();
    if (!hasAsked && mounted) {
      setState(() {
        _shouldShow = true;
      });
      _animationController.forward();
    }
  }

  Future<void> _handleAccept() async {
    await AnalyticsService().setConsent(true);
    await _hide();
  }

  Future<void> _handleRefuse() async {
    await AnalyticsService().setConsent(false);
    await _hide();
  }

  Future<void> _hide() async {
    await _animationController.reverse();
    if (mounted) {
      setState(() {
        _shouldShow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    final s = S.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: MintColors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: MintColors.lightBorder,
              width: 1,
            ),
          ),
          child: Material(
            color: MintColors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: MintColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s?.analyticsConsentTitle ?? 'Statistiques anonymes',
                          style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, letterSpacing: -0.3),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Message
                  Text(
                    s?.analyticsConsentMessage ??
                        'MINT utilise des statistiques anonymes pour améliorer l\'expérience. Aucune donnée personnelle n\'est collectée.',
                    style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(height: 1.5, letterSpacing: -0.1),
                  ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleRefuse,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MintColors.textSecondary,
                            side: const BorderSide(
                              color: MintColors.border,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            s?.analyticsRefuse ?? 'Refuser',
                            style: MintTextStyles.bodyLarge(color: MintColors.textSecondary).copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _handleAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: MintColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: Text(
                            s?.analyticsAccept ?? 'Accepter',
                            style: MintTextStyles.bodyLarge(color: MintColors.white).copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
