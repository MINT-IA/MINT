import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/widgets/analytics_consent_banner.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();

  late final AnimationController _heroController;
  late final AnimationController _translatorController;
  late final AnimationController _footerController;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/');

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _translatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _translatorController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _footerController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _translatorController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _onCtaTap() async {
    _analytics.trackCTAClick('cta_commencer_clicked', screenName: '/');
    final isCompleted = await ReportPersistenceService.isCompleted();
    final isMiniCompleted =
        await ReportPersistenceService.isMiniOnboardingCompleted();
    if (mounted) {
      if (isCompleted || isMiniCompleted) {
        context.go('/home');
      } else {
        context.go('/onboarding/quick');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: MintSpacing.xxl),
                        _buildHeroPunchline(),
                        const SizedBox(height: 44),
                        _buildTranslator(),
                        const SizedBox(height: 44),
                        _buildFooterCta(),
                        const SizedBox(height: MintSpacing.xxl),
                        _buildTrustBar(),
                        const SizedBox(height: 12),
                        _buildLegalFooter(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Analytics consent
          const AnalyticsConsentBanner(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header — clean text logo + login
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MINT',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
          TextButton(
            onPressed: () {
              _analytics.trackCTAClick('cta_login_clicked', screenName: '/');
              context.go('/auth/login');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              S.of(context)!.authLogin,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 1: La Punchline — full gradient on line 2
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroPunchline() {
    final l10n = S.of(context)!;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _heroController,
          curve: Curves.easeOut,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.landingPunchline1,
              style: MintTextStyles.displayMedium(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: MintSpacing.xs),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [MintColors.brandGreen, MintColors.brandGreenDark],
              ).createShader(bounds),
              child: Text(
                l10n.landingPunchline2,
                style: MintTextStyles.displayMedium(color: MintColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 2: Le Traducteur — subtle card background
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTranslator() {
    final l10n = S.of(context)!;

    final pairs = [
      (l10n.landingJargon1, l10n.landingClear1),
      (l10n.landingJargon2, l10n.landingClear2),
      (l10n.landingJargon3, l10n.landingClear3),
      (l10n.landingJargon4, l10n.landingClear4),
      (l10n.landingJargon5, l10n.landingClear5),
    ];

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _translatorController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _translatorController,
          curve: Curves.easeOut,
        )),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: MintColors.landingSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (int i = 0; i < pairs.length; i++) ...[
                _buildTranslatorRow(pairs[i].$1, pairs[i].$2),
                if (i < pairs.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm),
                    child: Divider(
                      height: 1,
                      color: MintColors.black.withValues(alpha: 0.04),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslatorRow(String jargon, String clear) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Jargon (left, muted, strikethrough)
        Expanded(
          child: Text(
            jargon,
            style: MintTextStyles.bodySmall().copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: MintColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
        ),
        // Arrow
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: MintSpacing.sm),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: MintColors.primary,
          ),
        ),
        // Clear (right, bold)
        Expanded(
          child: Text(
            clear,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 3: Loss frame + full-width CTA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFooterCta() {
    final l10n = S.of(context)!;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _footerController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _footerController,
          curve: Curves.easeOut,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loss frame — darker, slightly larger
            Text(
              l10n.landingWhyNobody,
              style: MintTextStyles.headlineMedium(),
            ),
            const SizedBox(height: MintSpacing.lg),
            // Full-width CTA
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: l10n.landingCtaCommencer,
                button: true,
                child: GestureDetector(
                onTap: _onCtaTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: MintColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      l10n.landingCtaCommencer,
                      style: MintTextStyles.titleMedium(color: MintColors.white),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Trust bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTrustBar() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTrustChip(
              Icons.shield_outlined, S.of(context)!.landingTrustSwiss),
          _trustDot(),
          _buildTrustChip(
              Icons.lock_outline_rounded, S.of(context)!.landingTrustPrivate),
          _trustDot(),
          _buildTrustChip(Icons.check_circle_outline_rounded,
              S.of(context)!.landingTrustNoCommitment),
        ],
      ),
    );
  }

  Widget _buildTrustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: MintColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }

  Widget _trustDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: MintColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Legal footer
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLegalFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          S.of(context)!.landingLegalFooterShort,
          textAlign: TextAlign.center,
          style: MintTextStyles.micro(color: MintColors.textMuted.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
