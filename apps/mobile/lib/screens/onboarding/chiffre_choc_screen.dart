import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Chiffre Choc screen — Category A (Hero).
///
/// Full-screen card with ONE dominant animated number.
/// Max 2 sections above fold, 1 primary CTA, avant/apres expandable.
///
/// Sprint S31 (created) / S52 (upgraded to Design System v2).
/// Receives age, grossSalary, canton via route extra.
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
  bool _avantApresExpanded = false;

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
    if (extra is! Map<String, dynamic>) {
      // No valid data — redirect to onboarding instead of infinite spinner
      if (mounted) context.go('/onboarding/quick');
      return;
    }

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

  /// Returns avant/apres texts based on chiffre choc type.
  ({String actText, String noActText}) _avantApresTexts(S l10n, ChiffreChocType type) {
    return switch (type) {
      ChiffreChocType.liquidityAlert => (
        actText: l10n.chiffreChocAvantApresLiquidityAct,
        noActText: l10n.chiffreChocAvantApresLiquidityNoAct,
      ),
      ChiffreChocType.retirementGap => (
        actText: l10n.chiffreChocAvantApresGapAct,
        noActText: l10n.chiffreChocAvantApresGapNoAct,
      ),
      ChiffreChocType.taxSaving3a => (
        actText: l10n.chiffreChocAvantApresTaxAct,
        noActText: l10n.chiffreChocAvantApresTaxNoAct,
      ),
      ChiffreChocType.retirementIncome => (
        actText: l10n.chiffreChocAvantApresIncomeAct,
        noActText: l10n.chiffreChocAvantApresIncomeNoAct,
      ),
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
    final l10n = S.of(context)!;

    if (choc == null || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final accentColor = _colorForKey(choc.colorKey);
    final infoCount = profile.providedFieldsCount;
    final avantApres = _avantApresTexts(l10n, choc.type);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: MintSpacing.md),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: l10n.chiffreChocBack,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(flex: 2),

              // ── Hero card with animated chiffre choc ──
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(MintSpacing.xl),
                    decoration: BoxDecoration(
                      color: MintColors.card,
                      borderRadius: BorderRadius.circular(24),
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
                        const SizedBox(height: MintSpacing.md),

                        // Title (category label above the number)
                        Text(
                          choc.title,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: MintSpacing.sm),

                        // THE NUMBER — displayLarge (48pt, Hero A)
                        Semantics(
                          label: choc.value,
                          child: Text(
                            choc.value,
                            style: MintTextStyles.displayLarge(
                              color: accentColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: MintSpacing.md),

                        // Caption — human impact, not jargon
                        Text(
                          choc.subtitle,
                          style: MintTextStyles.bodyMedium(
                            color: MintColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: MintSpacing.md),

              // ── Avant/Apres expandable (L2 requirement) ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Semantics(
                  button: true,
                  label: _avantApresExpanded
                      ? l10n.chiffreChocHideComparison
                      : l10n.chiffreChocShowComparison,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _avantApresExpanded = !_avantApresExpanded),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MintSpacing.md,
                        vertical: MintSpacing.sm + MintSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tap row
                          Row(
                            children: [
                              Icon(
                                _avantApresExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 20,
                                color: MintColors.textMuted,
                              ),
                              const SizedBox(width: MintSpacing.sm),
                              Expanded(
                                child: Text(
                                  '${l10n.chiffreChocIfYouAct} / ${l10n.chiffreChocIfYouDontAct}',
                                  style: MintTextStyles.bodySmall(
                                    color: MintColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Expanded content
                          if (_avantApresExpanded) ...[
                            const SizedBox(height: MintSpacing.sm + MintSpacing.xs),

                            // "Si tu agis"
                            _AvantApresRow(
                              icon: Icons.trending_up_rounded,
                              iconColor: MintColors.success,
                              label: l10n.chiffreChocIfYouAct,
                              text: avantApres.actText,
                            ),
                            const SizedBox(height: MintSpacing.sm),

                            // "Si tu ne fais rien"
                            _AvantApresRow(
                              icon: Icons.trending_flat_rounded,
                              iconColor: MintColors.warning,
                              label: l10n.chiffreChocIfYouDontAct,
                              text: avantApres.noActText,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: MintSpacing.sm),

              // ── Confidence indicator — simplified ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: MintSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: MintColors.textMuted,
                      ),
                      const SizedBox(width: MintSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.chiffreChocConfidenceSimple(
                            infoCount.toString(),
                          ),
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Primary CTA (single) ──
              Semantics(
                button: true,
                label: l10n.chiffreChocAction,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.chiffreChocAction,
                      style: MintTextStyles.titleMedium(
                        color: MintColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.md),

              // ── Disclaimer (micro pattern) ──
              Text(
                l10n.chiffreChocDisclaimer,
                style: MintTextStyles.micro(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private helper widget for avant/apres rows ──

class _AvantApresRow extends StatelessWidget {
  const _AvantApresRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: MintSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MintTextStyles.bodySmall(color: iconColor),
              ),
              const SizedBox(height: MintSpacing.xs),
              Text(
                text,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
