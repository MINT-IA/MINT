import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/independent_ledger_facts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/disability_red_screen_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  P4 — INVALIDITÉ INDÉPENDANT
//  L'Écran rouge (C) + Compte à rebours (F)
//  Source : LAMal art. 67-77, CO art. 324a, LAI art. 28
// ────────────────────────────────────────────────────────────

class DisabilitySelfEmployedScreen extends StatefulWidget {
  const DisabilitySelfEmployedScreen({super.key});

  @override
  State<DisabilitySelfEmployedScreen> createState() =>
      _DisabilitySelfEmployedScreenState();
}

class _DisabilitySelfEmployedScreenState
    extends State<DisabilitySelfEmployedScreen> {
  bool _hasPerteDegain = false;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _annualIncome(CoachProfileProvider? provider) {
    return IndependentLedgerFacts.selfEmployedAnnualIncome(provider?.profile);
  }

  double? _liquidSavings(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    if (profile == null ||
        !profile.userProvidedFields.contains('liquidSavings')) {
      return null;
    }
    final savings = profile.patrimoine.epargneLiquide;
    if (savings < 0) return null;
    return savings.toDouble();
  }

  double? _monthlyExpenses(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    if (profile == null ||
        !profile.userProvidedFields.contains('monthlyExpenses')) {
      return null;
    }
    final expenses = profile.depenses.totalMensuel;
    if (expenses <= 0) return null;
    return expenses.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final provider = _profileProvider(context);
    final annualIncome = _annualIncome(provider);
    final liquidSavings = _liquidSavings(provider);
    final monthlyExpenses = _monthlyExpenses(provider);

    return Scaffold(
      backgroundColor: MintColors.redBgLight, // fond rouge très pale
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 20),
                        MintEntrance(
                            child: _buildLedgerFactsCard(
                          context,
                          s,
                          annualIncome: annualIncome,
                          liquidSavings: liquidSavings,
                          monthlyExpenses: monthlyExpenses,
                        )),
                        const SizedBox(height: 20),
                        if (annualIncome != null &&
                            monthlyExpenses != null) ...[
                          Semantics(
                            key: const Key('disability_self_result_cards'),
                            identifier: 'disability_self_result_cards',
                            child: Column(
                              children: [
                                MintEntrance(
                                    delay: const Duration(milliseconds: 100),
                                    child: DisabilityRedScreenWidget(
                                      monthlyExpenses: monthlyExpenses,
                                      hasPerteDegain: _hasPerteDegain,
                                    )),
                                const SizedBox(height: 20),
                                MintEntrance(
                                    delay: const Duration(milliseconds: 200),
                                    child: liquidSavings == null
                                        ? const SizedBox.shrink()
                                        : DisabilityCountdownWidget(
                                            monthlyExpenses: monthlyExpenses,
                                            initialSavings: liquidSavings,
                                            allowSavingsAdjustment: false,
                                          )),
                                if (liquidSavings != null)
                                  const SizedBox(height: 20),
                                MintEntrance(
                                    delay: const Duration(milliseconds: 300),
                                    child: _buildPerteDegainToggle()),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                        MintEntrance(
                            delay: const Duration(milliseconds: 400),
                            child: EduDisclaimer(
                              text: S
                                  .of(context)!
                                  .disabilitySelfEmployedDisclaimer,
                            )),
                        const SizedBox(height: 8),
                        EduLegalSources(
                          sources: S.of(context)!.disabilitySelfEmployedSources,
                        ),
                      ]),
                    ),
                  ),
                ],
              ))),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.critical,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.critical, MintColors.deepRed],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MintColors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.of(context)!.disabilitySelfEmployedAlertLabel,
                      style: MintTextStyles.labelSmall(color: MintColors.white)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    S.of(context)!.disabilitySelfEmployedTitle,
                    style:
                        MintTextStyles.headlineMedium(color: MintColors.white)
                            .copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        S.of(context)!.disabilitySelfEmployedAppBarTitle,
        style: MintTextStyles.bodyLarge(color: MintColors.white)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildLedgerFactsCard(
    BuildContext context,
    S s, {
    required double? annualIncome,
    required double? liquidSavings,
    required double? monthlyExpenses,
  }) {
    final missingIncome = annualIncome == null;
    final missingSavings = liquidSavings == null;
    final missingExpenses = monthlyExpenses == null;
    final hasMissing = missingIncome || missingSavings || missingExpenses;
    final route = missingIncome
        ? '/data-block/revenu?inputKey=q_self_employed_income'
        : missingSavings
            ? '/data-block/patrimoine?inputKey=q_cash_total'
            : missingExpenses
                ? '/budget/setup'
                : '/data-block/revenu?inputKey=q_self_employed_income';
    final incomeLabel = missingIncome
        ? s.dataBlockStatusMissing
        : 'CHF ${_fmtChf(annualIncome)}';
    final savingsLabel = missingSavings
        ? s.dataBlockStatusMissing
        : 'CHF ${_fmtChf(liquidSavings)}';
    final expensesLabel = missingExpenses
        ? s.dataBlockStatusMissing
        : 'CHF ${_fmtChf(monthlyExpenses)}';
    return Semantics(
      key: const Key('disability_self_ledger_facts'),
      identifier: 'disability_self_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasMissing
                      ? Icons.manage_search_outlined
                      : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    hasMissing
                        ? s.dataQualityMissingSection
                        : s.dataQualityKnownSection,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(route),
                  icon: Icon(
                    hasMissing ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              key: const Key('disability_self_income_fact'),
              identifier: 'disability_self_income_fact',
              label: s.independantRevenueTitle,
              value: incomeLabel,
              isMissing: missingIncome,
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildFactRow(
              key: const Key('disability_self_savings_fact'),
              identifier: 'disability_self_savings_fact',
              label: s.disabilityAvailableSavings,
              value: savingsLabel,
              isMissing: missingSavings,
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildFactRow(
              key: const Key('disability_self_expenses_fact'),
              identifier: 'disability_self_expenses_fact',
              label: s.emergencyFundChargesLabel,
              value: expensesLabel,
              isMissing: missingExpenses,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required Key key,
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
    return Semantics(
      key: key,
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(
              color: isMissing ? MintColors.warning : MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPerteDegainToggle() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.disabilitySelfEmployedInsuranceQuestion,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToggleChip(
                    S.of(context)!.disabilitySelfEmployedYes,
                    _hasPerteDegain,
                    () => setState(() => _hasPerteDegain = true),
                    color: MintColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleChip(
                    S.of(context)!.disabilitySelfEmployedNo,
                    !_hasPerteDegain,
                    () => setState(() => _hasPerteDegain = false),
                    color: MintColors.critical),
              ),
            ],
          ),
          if (!_hasPerteDegain) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MintColors.warningBgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.of(context)!.disabilitySelfEmployedApgTip,
                      style:
                          MintTextStyles.labelSmall(color: MintColors.amberDark)
                              .copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, bool selected, VoidCallback onTap,
      {required Color color}) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.08)
                : MintColors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : MintColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(
                color: selected ? color : MintColors.textSecondary,
              ).copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtChf(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }
}
