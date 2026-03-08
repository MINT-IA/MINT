import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/widgets/analytics_consent_banner.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'dart:ui' as ui;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final AnalyticsService _analytics = AnalyticsService();

  // Mini-simulator state
  double _age = 45;
  double _salary = 85000;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/');
  }

  // ---------------------------------------------------------------------------
  // Estimation via financial_core (landing page teaser).
  // Uses AvsCalculator + LppCalculator — same formulas as the dashboard.
  // Simplified inputs (no canton, no lacunes) but NEVER duplicates logic.
  // ---------------------------------------------------------------------------
  double _estimatedLppBalance(int currentAge, double grossAnnualSalary) {
    if (grossAnnualSalary < lppSeuilEntree) return 0.0;
    final salaireBase = (grossAnnualSalary - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    double balance = 0;
    for (int a = 25; a < currentAge && a < 65; a++) {
      balance *= 1.01;
      balance += salaireBase * getLppBonificationRate(a);
    }
    return balance;
  }

  Map<String, double> _estimateRetirement() {
    final age = _age.round();
    final avsMonthly = AvsCalculator.renteFromRAMD(_salary);
    final pastBalance = _estimatedLppBalance(age, _salary);
    final lppAnnualRente = LppCalculator.projectToRetirement(
      currentBalance: pastBalance,
      currentAge: age,
      retirementAge: 65,
      grossAnnualSalary: _salary,
      caisseReturn: 0.01,
      conversionRate: 0.068,
    );
    final lppMonthly = lppAnnualRente / 12;
    final totalMonthly = avsMonthly + lppMonthly;
    final currentMonthly = _salary / 12;
    final ratio = currentMonthly > 0 ? totalMonthly / currentMonthly : 0.0;

    return {
      'total': totalMonthly,
      'current': currentMonthly,
      'ratio': ratio,
      'yearsLeft': (65 - age).toDouble(),
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final est = _estimateRetirement();

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
                          MintAnimateFadeUp(
                            child: _buildHeader(context),
                          ),

                          const SizedBox(height: 36),

                          // Hero — dynamic countdown
                          MintAnimateFadeUp(
                            delayInMs: 150,
                            child: _buildHero(),
                          ),

                          const SizedBox(height: 24),

                          // Interactive Simulator
                          MintAnimateFadeUp(
                            delayInMs: 400,
                            child: _buildSimulatorCard(est),
                          ),

                          const SizedBox(height: 24),

                          // Pourquoi MINT — 3 features
                          MintAnimateFadeUp(
                            delayInMs: 550,
                            child: _buildPourquoiMint(),
                          ),

                          const SizedBox(height: 20),

                          // Trust bar
                          MintAnimateFadeUp(
                            delayInMs: 650,
                            child: _buildTrustBar(),
                          ),

                          const SizedBox(height: 28),

                          // Single primary CTA
                          MintAnimateFadeUp(
                            delayInMs: 750,
                            child: _buildPrimaryCTA(context),
                          ),

                          const SizedBox(height: 32),

                          // Legal disclaimer — bottom only, small
                          _buildLegalFooter(),

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

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo + MINT + tagline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLogoPill(),
                const SizedBox(width: 10),
                Text(
                  'MINT',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ton coach financier suisse',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        // Auth buttons — no "Beta Privée" badge
        Row(
          children: [
            TextButton(
              onPressed: () {
                _analytics.trackCTAClick('cta_login_clicked', screenName: '/');
                context.go('/auth/login');
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                _analytics.trackCTAClick('cta_register_clicked',
                    screenName: '/');
                context.go('/auth/register');
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: MintColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "S'inscrire",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero — dynamic countdown to retirement
  // ---------------------------------------------------------------------------
  Widget _buildHero() {
    final yearsLeft = 65 - _age.round();

    final String line1;
    final String line2;
    if (yearsLeft <= 0) {
      line1 = 'Ta retraite,';
      line2 = "c'est maintenant.";
    } else if (yearsLeft == 1) {
      line1 = 'Dans 1 an,';
      line2 = 'ta retraite commence.';
    } else {
      line1 = 'Dans $yearsLeft ans,';
      line2 = 'ta retraite commence.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: MintColors.textSecondary,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [MintColors.primary, Color(0xFF6E6E73)],
          ).createShader(bounds),
          child: Text(
            line2,
            style: GoogleFonts.outfit(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'La plupart des Suisses découvrent leur écart de retraite trop tard.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Simulator Card — sliders + avant/apres + conclusion hook
  // ---------------------------------------------------------------------------
  Widget _buildSimulatorCard(Map<String, double> est) {
    final totalMonthly = est['total']!;
    final currentMonthly = est['current']!;
    final ratio = est['ratio']!;
    final gapMonthly = (currentMonthly - totalMonthly).round();
    final dropPercent = currentMonthly > 0
        ? ((currentMonthly - totalMonthly) / currentMonthly * 100).round()
        : 0;
    final isCapped = _salary > lppSalaireMax;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: MintColors.lightBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- Age slider ---
          _buildSliderRow(
            label: 'Ton age',
            formattedValue: '${_age.round()} ans',
            slider: Slider(
              value: _age,
              min: 25,
              max: 65,
              divisions: 40,
              onChanged: (v) => setState(() => _age = v),
            ),
          ),

          const SizedBox(height: 8),

          // --- Salary slider ---
          _buildSliderRow(
            label: 'Ton salaire brut',
            formattedValue: "${formatChf(_salary)} CHF/an",
            slider: Slider(
              value: _salary,
              min: 30000,
              max: 200000,
              divisions: 34,
              onChanged: (v) => setState(() => _salary = v),
            ),
          ),

          const SizedBox(height: 16),

          // --- Divider ---
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  MintColors.lightBorder.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Avant / Apres comparison ---
          _buildAvantApres(currentMonthly, totalMonthly),

          const SizedBox(height: 16),

          // --- Gap bar ---
          _buildGapBar(ratio),

          const SizedBox(height: 12),

          // --- Drop percentage (chiffre choc) ---
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: dropPercent.toDouble()),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                '-${value.round()}% de pouvoir d\'achat',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning,
                ),
              );
            },
          ),

          // --- LPP cap notice ---
          if (isCapped) ...[
            const SizedBox(height: 8),
            Text(
              'Au-dela de ${formatChf(lppSalaireMax)} CHF/an, '
              'la rente obligatoire est plafonnee.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // --- Dynamic conclusion hook ---
          _buildSimulatorHook(gapMonthly, dropPercent),
        ],
      ),
    );
  }

  // Dynamic hook that bridges the chiffre choc → action
  Widget _buildSimulatorHook(int gapChf, int dropPercent) {
    final String message;
    final Color color;

    if (dropPercent >= 40) {
      message =
          'Un ecart de ${formatChfWithPrefix(gapChf.toDouble())}/mois, '
          "c'est significatif. MINT t'aide a comprendre où agir.";
      color = MintColors.warning;
    } else if (dropPercent >= 20) {
      message =
          'Ton gap est gérable. MINT te montre les leviers concrets '
          '(rachat LPP, 3a, retraite anticipée).';
      color = MintColors.primary;
    } else {
      message =
          "Tu es en bonne posture. MINT te montre comment maintenir le cap "
          'et optimiser tes piliers.';
      color = MintColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward_rounded, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avant / Apres — two-column CHF comparison
  // ---------------------------------------------------------------------------
  Widget _buildAvantApres(double currentMonthly, double totalMonthly) {
    return Row(
      children: [
        // Today
        Expanded(
          child: Column(
            children: [
              Text(
                "Aujourd'hui",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: currentMonthly),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  formatChf(value),
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                'CHF/mois',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Arrow
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: MintColors.textMuted,
            size: 20,
          ),
        ),

        // Retirement
        Expanded(
          child: Column(
            children: [
              Text(
                'A la retraite*',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: totalMonthly),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  formatChf(value),
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: MintColors.warning,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                'CHF/mois',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Gap bar — visual ratio comparison
  // ---------------------------------------------------------------------------
  Widget _buildGapBar(double ratio) {
    final clampedRatio = (ratio * 100).round().clamp(1, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: clampedRatio / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final filled = (value * 100).round().clamp(1, 100);
            return Row(
              children: [
                Flexible(
                  flex: filled,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: filled < 60
                            ? [MintColors.warning, const Color(0xFFFF6B35)]
                            : [MintColors.success, const Color(0xFF34D058)],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: 100 - filled,
                  child: Container(color: MintColors.surface),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pourquoi MINT — 3 features (replaces vague "MINT t'aide à comprendre")
  // ---------------------------------------------------------------------------
  Widget _buildPourquoiMint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pourquoi MINT ?',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureRow(
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF4F46E5),
          title: 'Tous tes piliers, un seul tableau de bord',
          subtitle: 'AVS, LPP et 3a calculés selon ta situation réelle — '
              'pas des moyennes suisses.',
        ),
        const SizedBox(height: 10),
        _buildFeatureRow(
          icon: Icons.tips_and_updates_outlined,
          color: MintColors.primary,
          title: 'Coach adapté à ton stade de vie',
          subtitle: '25 ans ou 60 ans, frontalier ou indépendant — '
              'les conseils changent selon qui tu es.',
        ),
        const SizedBox(height: 10),
        _buildFeatureRow(
          icon: Icons.smartphone_outlined,
          color: const Color(0xFF0EA5E9),
          title: '100% privé, données sur ton appareil',
          subtitle: 'Aucun partage, aucune pub. '
              'Ton profil reste local sauf si tu crées un compte.',
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slider row (reused for age + salary)
  // ---------------------------------------------------------------------------
  Widget _buildSliderRow({
    required String label,
    required String formattedValue,
    required Widget slider,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              formattedValue,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: MintColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.lightBorder,
            thumbColor: MintColors.primary,
            overlayColor: MintColors.primary.withValues(alpha: 0.08),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: slider,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Trust bar
  // ---------------------------------------------------------------------------
  Widget _buildTrustBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustChip(Icons.shield_outlined, 'Concu en Suisse'),
        _trustDot(),
        _buildTrustChip(Icons.lock_outline_rounded, '100% prive'),
        _trustDot(),
        _buildTrustChip(Icons.check_circle_outline_rounded, 'Sans engagement'),
      ],
    );
  }

  Widget _buildTrustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: MintColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textSecondary,
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

  // ---------------------------------------------------------------------------
  // CTA — single, no competing button
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryCTA(BuildContext context) {
    return MintPremiumButton(
      title: 'Ton plan en 30 secondes',
      subtitle: '3 questions \u2022 Gratuit \u2022 Sans engagement',
      onTap: () async {
        _analytics.trackCTAClick('cta_plan_clicked', screenName: '/');
        final isCompleted = await ReportPersistenceService.isCompleted();
        final isMiniCompleted =
            await ReportPersistenceService.isMiniOnboardingCompleted();
        if (context.mounted) {
          if (isCompleted || isMiniCompleted) {
            context.go('/home');
          } else {
            context.go('/onboarding/smart');
          }
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Legal footer — very small, bottom only
  // ---------------------------------------------------------------------------
  Widget _buildLegalFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          '*Estimation indicative (1er + 2e pilier), basee sur le salaire '
          'actuel comme proxy de carriere. Ne constitue pas un conseil '
          'financier au sens de la LSFin. Tes donnees restent sur ton appareil.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Decorations
  // ---------------------------------------------------------------------------
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
}
