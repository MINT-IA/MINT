import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/widgets/analytics_consent_banner.dart';
import 'dart:ui' as ui;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Aurora Mesh
          Positioned(
            top: -100,
            left: -50,
            child: _buildBlurBlob(const Color(0xFFE5E5E7), 300),
          ),
          Positioned(
            top: 200,
            right: -100,
            child: _buildBlurBlob(const Color(0xFF4F46E5), 350),
          ),
          Positioned(
            bottom: -100,
            left: 50,
            child: _buildBlurBlob(const Color(0xFF0EA5E9), 300),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          _buildHeader(context),

                          const SizedBox(height: 48),

                          // Hero — user-centered, no jargon
                          Text(
                            'Tes finances',
                            style: GoogleFonts.outfit(
                              fontSize: 56,
                              fontWeight: FontWeight.w400,
                              color: MintColors.textPrimary,
                              height: 0.9,
                              letterSpacing: -2.5,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [MintColors.primary, Color(0xFF6E6E73)],
                            ).createShader(bounds),
                            child: Text(
                              'Enfin claires.',
                              style: GoogleFonts.outfit(
                                fontSize: 62,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 0.95,
                                letterSpacing: -2.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Subtitle — emotional hook, compliant
                          Text(
                            '3a, LPP, impots, retraite —\nMINT t\'explique tout, simplement.',
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              color: MintColors.textSecondary,
                              height: 1.6,
                              letterSpacing: -0.2,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Glass Card — user outcomes, not features
                          _buildValuePropsCard(context),

                          const SizedBox(height: 56),

                          // Primary CTA
                          _buildPrimaryCTA(context),

                          const SizedBox(height: 24),

                          // Tertiary CTA — explore path
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _analytics.trackCTAClick('cta_explore',
                                    screenName: '/');
                                context.go('/home');
                              },
                              icon:
                                  const Icon(Icons.explore_outlined, size: 18),
                              label: const Text('Explorer librement'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MintColors.textPrimary,
                                side:
                                    const BorderSide(color: MintColors.border),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Trust footer
                          _buildTrustFooter(),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Analytics consent banner
          const AnalyticsConsentBanner(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLogoPill(),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white),
              ),
              child: Text(
                S.of(context)?.landingBetaBadge ?? 'Beta Privee',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                _analytics.trackCTAClick('cta_login_clicked', screenName: '/');
                context.go('/auth/login');
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                S.of(context)?.authLogin ?? 'Se connecter',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValuePropsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(36),
        border:
            Border.all(color: MintColors.lightBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            Icons.speed_rounded,
            'Ton score financier',
            'Sache exactement ou tu en es.',
            MintColors.primary,
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(
            Icons.show_chart_rounded,
            'Ta trajectoire retraite',
            'Visualise l\'impact de tes decisions.',
            MintColors.primary,
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(
            Icons.lock_rounded,
            '100% sur ton appareil',
            'Tes donnees ne quittent jamais ton telephone.',
            MintColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCTA(BuildContext context) {
    return MintPremiumButton(
      title: 'Decouvrir mon score',
      subtitle: 'Gratuit \u2022 5 minutes',
      onTap: () async {
        _analytics.trackCTAClick('cta_score_clicked', screenName: '/');
        final isCompleted = await ReportPersistenceService.isCompleted();
        final isMiniCompleted =
            await ReportPersistenceService.isMiniOnboardingCompleted();
        if (context.mounted) {
          if (isCompleted || isMiniCompleted) {
            context.go('/home');
          } else {
            context.go('/advisor');
          }
        }
      },
    );
  }

  Widget _buildTrustFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Outil educatif — ne constitue pas un conseil financier. '
          'Tes donnees restent sur ton appareil.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildBlurBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildLogoPill() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          const Icon(Icons.token_rounded, color: MintColors.primary, size: 28),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
