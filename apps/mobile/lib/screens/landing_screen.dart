import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/widgets/analytics_consent_banner.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
        context.go('/onboarding/smart');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
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
                        const SizedBox(height: 80),
                        _buildHeroPunchline(),
                        const SizedBox(height: 64),
                        _buildTranslator(),
                        const SizedBox(height: 56),
                        _buildHiddenNumber(),
                        const SizedBox(height: 48),
                        _buildCta(),
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

  // ---------------------------------------------------------------------------
  // Header — MINT wordmark + ghost login
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MINT',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
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

  // ---------------------------------------------------------------------------
  // Section 1: Hero — two-line punchline, warm coral on line 2
  // ---------------------------------------------------------------------------
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
              style: MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.landingPunchline2,
              style: MintTextStyles.headlineLarge(color: MintColors.corailDiscret),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Translator — 3 jargon/clear pairs in individual MintSurface cards
  // ---------------------------------------------------------------------------
  Widget _buildTranslator() {
    final l10n = S.of(context)!;

    // Indices 0, 3, 2 from original list:
    // "Deduction de coordination", "Lacune de prevoyance", "Taux marginal"
    final pairs = [
      (l10n.landingJargon1, l10n.landingClear1),
      (l10n.landingJargon4, l10n.landingClear4),
      (l10n.landingJargon3, l10n.landingClear3),
    ];

    return AnimatedBuilder(
      animation: _translatorController,
      builder: (context, _) {
        return Column(
          children: [
            for (int i = 0; i < pairs.length; i++) ...[
              _buildTranslatorCard(pairs[i].$1, pairs[i].$2, i),
              if (i < pairs.length - 1)
                const SizedBox(height: MintSpacing.md),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTranslatorCard(String jargon, String clear, int index) {
    // Stagger: each card appears 150ms after the previous
    final staggerDelay = index * 0.25; // 0.25 of total animation = ~150ms
    final begin = staggerDelay;
    final end = (staggerDelay + 0.75).clamp(0.0, 1.0);

    final opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _translatorController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );

    final offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _translatorController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: offset,
        child: MintSurface(
          tone: MintSurfaceTone.sauge,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Jargon — struck through, muted
              Expanded(
                child: Text(
                  jargon,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: MintColors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Arrow — coral
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: MintColors.corailDiscret,
                ),
              ),
              // Clear translation — bold, primary
              Expanded(
                child: Text(
                  clear,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Hidden number — CHF ···· teaser
  // ---------------------------------------------------------------------------
  Widget _buildHiddenNumber() {
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
        child: MintSurface(
          tone: MintSurfaceTone.peche,
          child: Column(
            children: [
              Text(
                l10n.landingHiddenAmount,
                style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l10n.landingHiddenSubtitle,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA — pill-shaped filled button
  // ---------------------------------------------------------------------------
  Widget _buildCta() {
    final l10n = S.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        label: l10n.landingCtaCommencer,
        button: true,
        child: FilledButton(
          onPressed: _onCtaTap,
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          ),
          child: Text(
            l10n.landingCtaCommencer,
            style: MintTextStyles.titleMedium(color: MintColors.white),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trust bar
  // ---------------------------------------------------------------------------
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
        Icon(icon, size: 12, color: MintColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted.withValues(alpha: 0.6)),
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
        decoration: BoxDecoration(
          color: MintColors.textMuted.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Legal footer
  // ---------------------------------------------------------------------------
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
