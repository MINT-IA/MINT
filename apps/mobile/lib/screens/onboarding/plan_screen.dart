import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/common/mint_loading_state.dart';
import 'package:mint_mobile/widgets/common/mint_error_state.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Plan screen — onboarding pipeline Screen 6.
///
/// Shows a financial plan summary based on the user's selected intent.
/// For firstJob: checklist of key financial steps to take.
/// CTA navigates to the coach tab and marks onboarding as completed.
///
/// Design System category: B (Summary) — vertical list, single CTA.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  String? _intent;
  bool _didInit = false;
  bool _navigating = false;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map<String, dynamic>) {
          _intent = extra['intent'] as String?;
        }
      } catch (_) {
        setState(() => _hasError = true);
      }
    }
  }

  List<_PlanStep> _stepsForIntent(S l10n) {
    // Generate plan steps based on intent.
    // Currently all intents show the same foundational steps.
    // Future: customize per intent (e.g., housing, retirement).
    debugPrint('[PlanScreen] Generating steps for intent: $_intent');
    return [
      _PlanStep(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.planStepSalaryTitle,
        description: l10n.planStepSalaryBody,
      ),
      _PlanStep(
        icon: Icons.savings_outlined,
        title: l10n.planStep3aTitle,
        description: l10n.planStep3aBody,
      ),
      _PlanStep(
        icon: Icons.shield_outlined,
        title: l10n.planStepInsuranceTitle,
        description: l10n.planStepInsuranceBody,
      ),
      _PlanStep(
        icon: Icons.verified_outlined,
        title: l10n.planStepAvsTitle,
        description: l10n.planStepAvsBody,
      ),
    ];
  }

  Future<void> _onContinue() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    // Mark onboarding as completed (Research Pitfall 3: set at END of pipeline).
    await ReportPersistenceService.setMiniOnboardingCompleted(true);

    if (!mounted) return;
    // Navigate to Coach tab.
    context.go('/home?tab=1');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    if (_hasError) {
      return Scaffold(
        backgroundColor: MintColors.porcelaine,
        body: MintErrorState(
          title: l10n.errorGenericTitle,
          body: l10n.errorGenericBody,
          retryLabel: l10n.errorRetry,
          onRetry: () => setState(() {
            _hasError = false;
            _didInit = false;
          }),
        ),
      );
    }

    if (!_didInit) {
      return Scaffold(
        backgroundColor: MintColors.porcelaine,
        body: MintLoadingState(message: l10n.loadingDefault),
      );
    }

    final steps = _stepsForIntent(l10n);

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const SizedBox(height: MintSpacing.xxxl),
                // ── Headline ──
                MintEntrance(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.lg,
                    ),
                    child: Text(
                      l10n.planHeadline,
                      style: MintTextStyles.headlineLarge(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.lg,
                    ),
                    child: Text(
                      l10n.planSubtitle,
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),

                // ── Plan steps ──
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.lg,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: steps.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MintSpacing.md),
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return MintEntrance(
                        delay: Duration(milliseconds: 150 + index * 80),
                        child: MintSurface(
                          tone: MintSurfaceTone.craie,
                          padding: const EdgeInsets.all(MintSpacing.lg),
                          radius: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                step.icon,
                                size: 24,
                                color: MintColors.primary,
                              ),
                              const SizedBox(width: MintSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: MintTextStyles.headlineSmall(),
                                    ),
                                    const SizedBox(height: MintSpacing.xs),
                                    Text(
                                      step.description,
                                      style: MintTextStyles.bodyMedium(
                                        color: MintColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── CTA ──
                MintEntrance(
                  delay: const Duration(milliseconds: 500),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MintSpacing.lg,
                      MintSpacing.sm,
                      MintSpacing.lg,
                      MintSpacing.lg,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Semantics(
                        button: true,
                        label: l10n.planCta,
                        child: FilledButton(
                          onPressed: _navigating ? null : _onContinue,
                          style: FilledButton.styleFrom(
                            backgroundColor: MintColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _navigating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MintColors.white,
                                  ),
                                )
                              : Text(
                                  l10n.planCta,
                                  style: MintTextStyles.titleMedium(
                                    color: MintColors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanStep {
  final IconData icon;
  final String title;
  final String description;

  const _PlanStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}
