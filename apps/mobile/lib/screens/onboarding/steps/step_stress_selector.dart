import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const _options = [
    _StressOption(
      id: 'stress_retraite',
      icon: Icons.trending_up,
      label: 'Ma retraite',
      subtitle: 'Vais-je avoir assez pour vivre ?',
    ),
    _StressOption(
      id: 'stress_impots',
      icon: Icons.receipt_long,
      label: 'Mes impots',
      subtitle: 'Est-ce que je paie trop ?',
    ),
    _StressOption(
      id: 'stress_budget',
      icon: Icons.account_balance_wallet,
      label: 'Mon budget',
      subtitle: 'Ou passe mon argent ?',
    ),
    _StressOption(
      id: 'stress_patrimoine',
      icon: Icons.savings,
      label: 'Mon patrimoine',
      subtitle: 'Comment le faire grandir ?',
    ),
    _StressOption(
      id: 'stress_couple',
      icon: Icons.people,
      label: 'En couple',
      subtitle: 'Optimiser a deux',
    ),
    _StressOption(
      id: 'stress_general',
      icon: Icons.explore,
      label: 'Juste curieux',
      subtitle: 'Je veux comprendre ma situation',
    ),
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
                'Qu\'est-ce qui te preoccupe le plus ?',
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
                    'Choisis un theme — on personnalise ton experience.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  )),
                  const SizedBox(height: 24),
                  ..._options.map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StressCard(
                          option: opt,
                          isSelected: viewModel.stressType == opt.id,
                          onTap: () => _select(context, opt.id),
                        ),
                      )),
                  const SizedBox(height: 16),
                  MintEntrance(delay: Duration(milliseconds: 100), child: Text(
                    'Outil educatif — ne constitue pas un conseil financier (LSFin).',
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

class _StressOption {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;

  const _StressOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
  });
}

class _StressCard extends StatelessWidget {
  final _StressOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StressCard({
    required this.option,
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
        label: option.label,
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
                  option.icon,
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
                      option.label,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
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
