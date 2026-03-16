import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Chiffre Choc screen — full-screen card with ONE impactful number.
///
/// Sprint S31 — Onboarding Redesign.
/// Receives age, grossSalary, canton via route extra.
/// Shows animated number with context, confidence indicator, and two CTAs.
class ChiffreChocScreen extends StatefulWidget {
  const ChiffreChocScreen({super.key});

  @override
  State<ChiffreChocScreen> createState() => _ChiffreChocScreenState();
}

class _ChiffreChocScreenState extends State<ChiffreChocScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  bool _didStartLoad = false;
  MinimalProfileResult? _profile;
  ChiffreChoc? _chiffreChoc;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStartLoad) {
      _didStartLoad = true;
      _computeFromRouteExtra();
    }
  }

  Future<void> _computeFromRouteExtra() async {
    final extra = GoRouterState.of(context).extra;
    if (extra is! Map<String, dynamic>) return;

    final age = extra['age'] as int? ?? 35;
    final grossSalary = (extra['grossSalary'] as num?)?.toDouble() ?? 80000;
    final canton = extra['canton'] as String? ?? 'ZH';
    final targetRetirementAge = extra['targetRetirementAge'] as int?;

    // Optional enrichment fields
    final householdType = extra['householdType'] as String?;
    final currentSavings = (extra['currentSavings'] as num?)?.toDouble();
    final isPropertyOwner = extra['isPropertyOwner'] as bool?;
    final existing3a = (extra['existing3a'] as num?)?.toDouble();
    final existingLpp = (extra['existingLpp'] as num?)?.toDouble();

    try {
      final profile = await ApiService.computeMinimalProfile(
        age: age,
        grossSalary: grossSalary,
        canton: canton,
        householdType: householdType,
        currentSavings: currentSavings,
        isPropertyOwner: isPropertyOwner,
        existing3a: existing3a,
        existingLpp: existingLpp,
      );
      final choc = await ApiService.computeOnboardingChiffreChoc(
        age: age,
        grossSalary: grossSalary,
        canton: canton,
        householdType: householdType,
        currentSavings: currentSavings,
        isPropertyOwner: isPropertyOwner,
        existing3a: existing3a,
        existingLpp: existingLpp,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _chiffreChoc = choc;
      });
    } catch (_) {
      final profile = MinimalProfileService.compute(
        age: age,
        grossSalary: grossSalary,
        canton: canton,
        householdType: householdType,
        currentSavings: currentSavings,
        isPropertyOwner: isPropertyOwner,
        existing3a: existing3a,
        existingLpp: existingLpp,
        targetRetirementAge: targetRetirementAge,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _chiffreChoc = ChiffreChocSelector.select(profile);
      });
    }

    _animController.forward(from: 0);

    // Analytics: chiffre choc viewed with type and severity
    if (_chiffreChoc != null && _profile != null) {
      AnalyticsService().trackEvent(
        'chiffre_choc_viewed',
        category: 'conversion',
        data: {
          'type': _chiffreChoc!.type.name,
          'color_key': _chiffreChoc!.colorKey,
          'info_count': _profile!.providedFieldsCount,
        },
        screenName: 'chiffre_choc',
      );
    }
  }

  Color _colorForKey(String key) {
    return switch (key) {
      'error' => MintColors.error,
      'warning' => MintColors.warning,
      'success' => MintColors.success,
      'info' => MintColors.info,
      _ => MintColors.primary,
    };
  }

  IconData _iconForName(String name) {
    return switch (name) {
      'warning_amber' => Icons.warning_amber_rounded,
      'trending_down' => Icons.trending_down_rounded,
      'savings' => Icons.savings_rounded,
      'account_balance' => Icons.account_balance_rounded,
      _ => Icons.insights_rounded,
    };
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choc = _chiffreChoc;
    final profile = _profile;

    if (choc == null || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final accentColor = _colorForKey(choc.colorKey);
    final infoCount = profile.providedFieldsCount;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: MintColors.textSecondary,
                ),
              ),
              const Spacer(flex: 2),

              // Animated chiffre choc card
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: MintColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: MintColors.lightBorder),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withAlpha(25),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForName(choc.iconName),
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          choc.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: MintColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // THE NUMBER
                        Text(
                          choc.value,
                          style: GoogleFonts.montserrat(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          choc.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MintColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Confidence indicator
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: MintColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimation basée sur $infoCount informations. '
                          'Plus tu précises, plus c\'est fiable.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // CTA 1: Action
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Navigate to relevant simulation based on chiffre choc type
                    final route = switch (choc.type) {
                      ChiffreChocType.liquidityAlert => '/budget',
                      ChiffreChocType.retirementGap => '/coach/cockpit',
                      ChiffreChocType.taxSaving3a => '/pilier-3a',
                      ChiffreChocType.retirementIncome => '/coach/cockpit',
                    };
                    AnalyticsService().trackCTAClick(
                      'chiffre_choc_action',
                      screenName: 'chiffre_choc',
                      data: {
                        'choc_type': choc.type.name,
                        'target_route': route,
                      },
                    );
                    context.go(route);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Qu\'est-ce que je peux faire ?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // CTA 2: Enrich profile
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    AnalyticsService().trackCTAClick(
                      'chiffre_choc_enrich',
                      screenName: 'chiffre_choc',
                      data: {'choc_type': choc.type.name},
                    );
                    context.push('/profile/bilan');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side:
                        const BorderSide(color: MintColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Affiner mon profil',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Disclaimer
              Text(
                'Outil educatif — ne constitue pas un conseil financier (LSFin). '
                'Sources : LAVS art. 34, LPP art. 14-16, OPP3 art. 7.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
