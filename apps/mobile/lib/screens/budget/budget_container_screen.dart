import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';

class BudgetContainerScreen extends StatefulWidget {
  final Object? routeExtra;

  const BudgetContainerScreen({super.key, this.routeExtra});

  @override
  State<BudgetContainerScreen> createState() => _BudgetContainerScreenState();
}

class _BudgetContainerScreenState extends State<BudgetContainerScreen> {
  bool _isLoading = true;
  bool _isHydratingBudget = false;
  CoachProfileProvider? _profileProvider;

  @override
  void initState() {
    super.initState();
    _loadSavedBudget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProfileProvider = _readCoachProfileProviderIfAvailable();
    if (identical(_profileProvider, nextProfileProvider)) return;

    _profileProvider?.removeListener(_handleProfileProviderChanged);
    _profileProvider = nextProfileProvider;
    _profileProvider?.addListener(_handleProfileProviderChanged);

    if (_hasUsableProfileState(nextProfileProvider)) {
      _handleProfileProviderChanged();
    }
  }

  @override
  void dispose() {
    _profileProvider?.removeListener(_handleProfileProviderChanged);
    super.dispose();
  }

  Future<void> _loadSavedBudget() async {
    final budgetProvider = context.read<BudgetProvider>();
    final profileProvider = _readCoachProfileProviderIfAvailable();

    if (profileProvider != null && !_hasUsableProfileState(profileProvider)) {
      final restored = await budgetProvider.loadFromStorage();
      if (!mounted) return;
      if (restored) {
        setState(() => _isLoading = false);
        return;
      }
      if (!_hasUsableProfileState(profileProvider)) {
        if (!profileProvider.isLoading) {
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    await _hydrateFromProfileProvider(profileProvider);
  }

  void _handleProfileProviderChanged() {
    final profileProvider = _profileProvider;
    if (!_hasUsableProfileState(profileProvider)) {
      if (profileProvider != null && !profileProvider.isLoading && _isLoading) {
        setState(() => _isLoading = false);
      }
      return;
    }
    unawaited(_hydrateFromProfileProvider(profileProvider));
  }

  bool _hasUsableProfileState(CoachProfileProvider? profileProvider) {
    return profileProvider != null &&
        (profileProvider.isLoaded || profileProvider.profile != null);
  }

  Future<void> _hydrateFromProfileProvider(
    CoachProfileProvider? profileProvider,
  ) async {
    if (_isHydratingBudget) return;
    _isHydratingBudget = true;
    try {
      final budgetProvider = context.read<BudgetProvider>();
      await budgetProvider.hydrateFromProfileState(
        profile: profileProvider?.profile,
        isPartialProfile: profileProvider?.isPartialProfile ?? false,
      );
    } finally {
      _isHydratingBudget = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Prefer a complete canonical profile. Partial profiles are useful when no
  /// budget cache exists, but must not overwrite a fuller saved budget.
  CoachProfileProvider? _readCoachProfileProviderIfAvailable() {
    try {
      return context.read<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = context.watch<BudgetProvider>().inputs;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context)!.budgetTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const MintLoadingSkeleton(),
          ),
        ),
      );
    }

    if (inputs == null) {
      return _buildEmptyState(context);
    }

    return BudgetScreen(inputs: inputs, routeExtra: widget.routeExtra);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context)!.budgetTitle)),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MintEntrance(
                          child: ExcludeSemantics(
                              child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: MintColors.primary),
                      ))),
                      const SizedBox(height: 24),
                      MintEntrance(
                          delay: const Duration(milliseconds: 100),
                          child: Text(
                            S.of(context)!.budgetCardEmptyTitle,
                            textAlign: TextAlign.center,
                            style: MintTextStyles.titleLarge(),
                          )),
                      const SizedBox(height: MintSpacing.md),
                      MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            S.of(context)!.budgetCardEmptyBody,
                            textAlign: TextAlign.center,
                            style: MintTextStyles.bodyMedium(),
                          )),
                      const SizedBox(height: 32),
                      Semantics(
                        button: true,
                        label: S.of(context)!.semanticsBudgetStartButton,
                        child: FilledButton.icon(
                          onPressed: () => context.push('/budget/setup'),
                          icon: const Icon(Icons.edit_note),
                          label: Text(S.of(context)!.budgetCardEmptyAction),
                          style: FilledButton.styleFrom(
                            backgroundColor: MintColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ))),
    );
  }
}
