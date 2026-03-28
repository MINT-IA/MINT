import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Step 0: Stress/intention selector — a single tap auto-advances.
///
/// This is NOT a data question — it captures the user's motivation
/// to personalise the coaching experience. Does NOT count towards
/// the "3 questions before chiffre choc" rule.
class StepStressSelector extends StatelessWidget {
  final SmartOnboardingViewModel viewModel;
  final VoidCallback onNext;

  const StepStressSelector({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  static const _optionIds = [
    'stress_retraite',
    'stress_impots',
    'stress_budget',
    'stress_patrimoine',
    'stress_couple',
    'stress_general',
  ];

  static const _optionIcons = [
    Icons.trending_up,
    Icons.receipt_long,
    Icons.account_balance_wallet,
    Icons.savings,
    Icons.people,
    Icons.explore,
  ];

  void _select(BuildContext context, String id) {
    viewModel.setStressType(id);
    AnalyticsService().trackEvent(
      'onboarding_stress_selected',
      category: 'engagement',
      data: {'stress_type': id},
      screenName: 'smart_onboarding_stress',
    );
    // Auto-advance after short delay for visual feedback
    Future.delayed(const Duration(milliseconds: 250), onNext);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    final labels = [
      l.stepStressRetirement,
      l.stepStressTaxes,
      l.stepStressBudget,
      l.stepStressWealth,
      l.stepStressCouple,
      l.stepStressCurious,
    ];
    final subtitles = [
      l.stepStressRetirementSub,
      l.stepStressTaxesSub,
      l.stepStressBudgetSub,
      l.stepStressWealthSub,
      l.stepStressCoupleSub,
      l.stepStressCuriousSub,
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 16, right: 24),
              title: Text(
                l.stepStressTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: MintColors.white,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MintEntrance(child: Text(
                    l.stepStressSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  )),
                  const SizedBox(height: 24),
                  ...List.generate(_optionIds.length, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StressCard(
                          icon: _optionIcons[i],
                          label: labels[i],
                          subtitle: subtitles[i],
                          isSelected: viewModel.stressType == _optionIds[i],
                          onTap: () => _select(context, _optionIds[i]),
                        ),
                      )),
                  const SizedBox(height: 16),
                  MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                    l.stepStressDisclaimer,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StressCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _StressCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? MintColors.primary.withAlpha(20)
          : MintColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? MintColors.primary : MintColors.lightBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? MintColors.primary.withAlpha(30)
                      : MintColors.lightBorder.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isSelected
                    ? MintColors.primary
                    : MintColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
