import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';
import 'package:mint_mobile/widgets/mon_argent/budget_summary_card.dart';
import 'package:mint_mobile/widgets/mon_argent/patrimoine_summary_card.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Mon argent tab — financial state at a glance.
///
/// Navigation V11, Category G: Dashboard Screen.
/// Two calm numbers: budget remaining + patrimoine net.
/// Architecture A→B: ready for spending synthesis card (Phase B).
class MonArgentScreen extends StatefulWidget {
  const MonArgentScreen({super.key});

  @override
  State<MonArgentScreen> createState() => _MonArgentScreenState();
}

class _MonArgentScreenState extends State<MonArgentScreen> {
  bool _budgetLoading = true;
  bool _budgetError = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    setState(() {
      _budgetLoading = true;
      _budgetError = false;
    });
    try {
      await context.read<BudgetProvider>().loadFromStorage();
    } catch (_) {
      if (mounted) setState(() => _budgetError = true);
    } finally {
      if (mounted) setState(() => _budgetLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadBudget();
    // CoachProfileProvider refreshes reactively via watch
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final budgetProvider = context.watch<BudgetProvider>();
    final coachProfile = context.watch<CoachProfileProvider>().profile;
    final patrimoine = PatrimoineAggregator.compute(coachProfile);
    final whisper = CoachWhisperService.evaluate(
      budgetInputs: budgetProvider.inputs,
      budgetPlan: budgetProvider.plan,
      patrimoine: patrimoine,
      profile: coachProfile,
    );

    return Scaffold(
      backgroundColor: MintColors.craie,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          l10n.monArgentTabTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => MintShell.openDrawer(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: MintColors.success,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(MintSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card 1: Budget
                    MintEntrance(
                      child: BudgetSummaryCard(
                        inputs: budgetProvider.inputs,
                        plan: budgetProvider.plan,
                        isLoading: _budgetLoading,
                        hasError: _budgetError,
                        onTap: () => context.push('/budget'),
                        onRetry: _loadBudget,
                        // Route the empty-state "Commencer" directly to the
                        // structured setup form rather than /budget (which
                        // loops back to the coach chat topic=budget path).
                        // See MVP-PLAN-2026-04-21 § P0-MVP-3.
                        onSetup: () => context.push('/budget/setup'),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.lg),

                    // Card 2: Patrimoine
                    MintEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: PatrimoineSummaryCard(
                        summary: patrimoine,
                        onTap: () => context.push('/profile/bilan'),
                        onScan: () => context.push('/scan'),
                        onTapAmount: (topic) =>
                            context.go('/coach/chat?topic=$topic'),
                      ),
                    ),

                    // Coach whisper (deterministic, may be null = silence)
                    if (whisper != null) ...[
                      const SizedBox(height: MintSpacing.lg),
                      MintEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: () =>
                              context.go('/coach/chat?topic=budget'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MintSpacing.sm,
                            ),
                            child: Text(
                              '\u{1F4A1} $whisper',
                              style: MintTextStyles.bodyMedium(
                                color: MintColors.textSecondary,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // CTA: Enrich your dossier
                    const SizedBox(height: MintSpacing.xl),
                    MintEntrance(
                      delay: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: () => context.push('/scan'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.monArgentEnrichCta,
                                style: MintTextStyles.bodyMedium(
                                  color: MintColors.ardoise,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.add_circle_outline,
                              color: MintColors.ardoise,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Phase B slot (commented, not rendered)
                    // TODO(nav-v11-phase-b): SpendingSynthesisCard goes here
                    // when Open Banking data is available.
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
