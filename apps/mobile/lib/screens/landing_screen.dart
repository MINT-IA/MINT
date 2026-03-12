import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
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
      backgroundColor: Colors.white,
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
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 48),
                        _buildHeroPunchline(),
                        const SizedBox(height: 44),
                        _buildTranslator(),
                        const SizedBox(height: 44),
                        _buildFooterCta(),
                        const SizedBox(height: 40),
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
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: 2,
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
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
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
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: MintColors.textPrimary,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF1DB954), Color(0xFF0A8F6C)],
              ).createShader(bounds),
              child: Text(
                l10n.landingPunchline2,
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
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
            color: const Color(0xFFF5F6F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (int i = 0; i < pairs.length; i++) ...[
                _buildTranslatorRow(pairs[i].$1, pairs[i].$2),
                if (i < pairs.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      color: Colors.black.withValues(alpha: 0.04),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: MintColors.textMuted.withValues(alpha: 0.4),
              height: 1.4,
            ),
          ),
        ),
        // Arrow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
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
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 24),
            // Full-width CTA
            SizedBox(
              width: double.infinity,
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
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
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
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
