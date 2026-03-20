import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/coach/debt_survival_widget.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';

/// Ecran de planification du remboursement de dettes.
///
/// Compare les strategies avalanche (taux haut d'abord) et
/// boule de neige (petit solde d'abord).
class RepaymentScreen extends StatefulWidget {
  const RepaymentScreen({super.key});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  final List<_DebtInput> _dettes = [
    _DebtInput(
      nom: 'Credit conso',
      montant: 15000,
      tauxAnnuel: 9.9,
      mensualiteMin: 300,
    ),
    _DebtInput(
      nom: 'Leasing auto',
      montant: 8000,
      tauxAnnuel: 4.5,
      mensualiteMin: 250,
    ),
  ];

  double _budgetMensuel = 800;

  RepaymentComparisonResult? get _result {
    if (_dettes.isEmpty) return null;
    final dettes = _dettes
        .where((d) => d.montant > 0)
        .map((d) => Debt(
              nom: d.nom,
              montant: d.montant,
              tauxAnnuel: d.tauxAnnuel / 100,
              mensualiteMin: d.mensualiteMin,
            ))
        .toList();
    if (dettes.isEmpty) return null;
    return RepaymentPlanner.plan(
      dettes: dettes,
      budgetMensuelRemboursement: _budgetMensuel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: MintColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              S.of(context)!.repaymentTitle,
              style: MintTextStyles.titleMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P10-F : Mode survie MINT ──────────────────────
                DebtSurvivalWidget(
                  totalDebt: _dettes.fold<double>(0, (s, d) => s + d.montant),
                  monthlyMargin: _budgetMensuel -
                      _dettes.fold<double>(0, (s, d) => s + d.mensualiteMin),
                  daysSinceLastLate: 0,
                  monthlyIncome: 6000,
                ),
                const SizedBox(height: MintSpacing.lg),

                // Chiffre choc
                if (result != null) ...[
                  _buildChiffreChoc(result),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Liste des dettes
                _buildDettesSection(),
                const SizedBox(height: MintSpacing.lg),

                // Budget mensuel
                _buildBudgetSection(),
                const SizedBox(height: MintSpacing.lg),

                // Comparaison strategies
                if (result != null) ...[
                  _buildComparisonSection(result),
                  const SizedBox(height: MintSpacing.sm + 4),
                  _buildStrategyNote(),
                  const SizedBox(height: MintSpacing.lg),

                  // Timeline
                  _buildTimelineSection(result),
                  const SizedBox(height: MintSpacing.lg),

                  // Disclaimer
                  _buildDisclaimer(result.disclaimer),
                ] else
                  _buildEmptyState(),

                const SizedBox(height: MintSpacing.lg),

                // Navigation croisée dette
                const DebtToolsNav(currentRoute: '/debt/repayment'),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(RepaymentComparisonResult result) {
    final color = switch (result.chiffreChoc.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    // Show the shorter duration between both strategies (no ranking)
    final strategiePrioritaire = result.avalanche.moisJusquaLiberation <=
            result.bouleDeNeige.moisJusquaLiberation
        ? result.avalanche
        : result.bouleDeNeige;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.repaymentLibereDans,
            style: MintTextStyles.bodySmall(color: color)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            '${strategiePrioritaire.moisJusquaLiberation} mois',
            style: MintTextStyles.displayMedium(color: color),
          ),
          const SizedBox(height: 4),
          if (result.economieInterets > 0)
            Text(
              S.of(context)!.repaymentDiffStrategies(formatChf(result.economieInterets)),
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDettesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.repaymentMesDettes,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: MintColors.primary),
                onPressed: _addDebt,
                tooltip: S.of(context)!.repaymentAddDebtTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int i = 0; i < _dettes.length; i++) ...[
            _buildDebtCard(i),
            if (i < _dettes.length - 1) const SizedBox(height: 12),
          ],

          if (_dettes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  S.of(context)!.repaymentAddDebtHint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(int index) {
    final dette = _dettes[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: nom éditable + supprimer
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: dette.nom,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: S.of(context)!.repaymentDebtNameHint,
                    hintStyle: TextStyle(
                      color: MintColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => dette.nom = v),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dettes.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MintColors.redBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      color: MintColors.redMedium, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 inline value fields
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildInlineValue(
                  label: S.of(context)!.repaymentFieldAmount,
                  display: 'CHF\u00a0${formatChf(dette.montant)}',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldAmountLabel,
                    currentValue: dette.montant,
                    min: 500,
                    max: 100000,
                    prefix: 'CHF',
                    onChanged: (v) => setState(() => dette.montant = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildInlineValue(
                  label: S.of(context)!.repaymentFieldRate,
                  display: '${dette.tauxAnnuel.toStringAsFixed(1)}\u00a0%',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldRateLabel,
                    currentValue: dette.tauxAnnuel,
                    min: 0.5,
                    max: 20.0,
                    prefix: '',
                    suffix: '%',
                    decimals: true,
                    onChanged: (v) => setState(() => dette.tauxAnnuel = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildInlineValue(
                  label: S.of(context)!.repaymentFieldInstallment,
                  display: 'CHF\u00a0${formatChf(dette.mensualiteMin)}',
                  onTap: () => _showValueEditor(
                    label: S.of(context)!.repaymentFieldInstallmentLabel,
                    currentValue: dette.mensualiteMin,
                    min: 50,
                    max: 3000,
                    prefix: 'CHF',
                    onChanged: (v) =>
                        setState(() => dette.mensualiteMin = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Champ inline tappable — label + valeur.
  Widget _buildInlineValue({
    required String label,
    required String display,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: MintColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              display,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet pour saisie précise au clavier.
  void _showValueEditor({
    required String label,
    required double currentValue,
    required double min,
    required double max,
    required String prefix,
    String? suffix,
    bool decimals = false,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(
      text: decimals
          ? currentValue.toStringAsFixed(1)
          : currentValue.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: MintSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (prefix.isNotEmpty)
                    Text(
                      '$prefix ',
                      style: MintTextStyles.headlineMedium(color: MintColors.textMuted)
                          .copyWith(fontSize: 28),
                    ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: decimals,
                      ),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (suffix != null)
                    Text(
                      ' $suffix',
                      style: MintTextStyles.headlineMedium(color: MintColors.textMuted)
                          .copyWith(fontSize: 28),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.repaymentMinMax(
                  decimals ? min.toStringAsFixed(1) : formatChf(min),
                  decimals ? max.toStringAsFixed(1) : formatChf(max),
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(
                      controller.text
                          .replaceAll("'", '')
                          .replaceAll(',', '.')
                          .replaceAll(RegExp(r"[^0-9.]"), ''),
                    );
                    if (parsed != null) {
                      onChanged(parsed.clamp(min, max));
                    }
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.repaymentValidate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _addDebt() {
    setState(() {
      _dettes.add(_DebtInput(
        nom: S.of(context)!.repaymentNewDebt,
        montant: 5000,
        tauxAnnuel: 5.0,
        mensualiteMin: 100,
      ));
    });
  }

  Widget _buildBudgetSection() {
    return GestureDetector(
      onTap: () => _showValueEditor(
        label: S.of(context)!.repaymentBudgetEditorLabel,
        currentValue: _budgetMensuel,
        min: 200,
        max: 5000,
        prefix: 'CHF',
        onChanged: (v) => setState(() => _budgetMensuel = v),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments_outlined,
                  color: MintColors.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.repaymentBudgetLabel,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.repaymentBudgetDisplay(formatChf(_budgetMensuel)),
                    style: MintTextStyles.headlineMedium(color: MintColors.primary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                color: MintColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonSection(RepaymentComparisonResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.repaymentComparaisonStrategies,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStrategyCard(
                title: S.of(context)!.repaymentAvalancheTitle,
                subtitle: S.of(context)!.repaymentAvalancheSubtitle,
                pro: S.of(context)!.repaymentAvalanchePro,
                mois: result.avalanche.moisJusquaLiberation,
                interets: result.avalanche.interetsTotaux,
                icon: Icons.trending_down,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStrategyCard(
                title: S.of(context)!.repaymentSnowballTitle,
                subtitle: S.of(context)!.repaymentSnowballSubtitle,
                pro: S.of(context)!.repaymentSnowballPro,
                mois: result.bouleDeNeige.moisJusquaLiberation,
                interets: result.bouleDeNeige.interetsTotaux,
                icon: Icons.ac_unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildComparisonRow(
                S.of(context)!.repaymentRowLiberation,
                S.of(context)!.repaymentDurationDisplay(result.avalanche.moisJusquaLiberation),
                S.of(context)!.repaymentDurationDisplay(result.bouleDeNeige.moisJusquaLiberation),
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                S.of(context)!.repaymentRowInterets,
                S.of(context)!.repaymentInteretsDisplay(formatChf(result.avalanche.interetsTotaux)),
                S.of(context)!.repaymentInteretsDisplay(formatChf(result.bouleDeNeige.interetsTotaux)),
              ),
              if (result.economieInterets > 0) ...[
                const Divider(height: 16),
                Text(
                  S.of(context)!.repaymentDifference(formatChf(result.economieInterets)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String title,
    required String subtitle,
    required String pro,
    required int mois,
    required double interets,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 6),
              Text(
                title,
                style: MintTextStyles.micro(color: MintColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            S.of(context)!.repaymentDurationDisplay(mois),
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.repaymentInteretsDisplay(formatChf(interets)),
            style: const TextStyle(
              fontSize: 11,
              color: MintColors.redDeep,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '✓ $pro',
            style: const TextStyle(
              fontSize: 10,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
      String label, String valueA, String valueB) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            valueA,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            valueB,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        S.of(context)!.repaymentStrategyNote,
        style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
            .copyWith(fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimelineSection(RepaymentComparisonResult result) {
    // Show avalanche timeline as example
    final timeline = result.avalanche.timeline;
    if (timeline.isEmpty) return const SizedBox.shrink();

    // Sample: show every N months to avoid too many rows
    final step = timeline.length > 24 ? (timeline.length ~/ 12) : 1;
    final sampled = <RepaymentMonth>[];
    for (int i = 0; i < timeline.length; i += step) {
      sampled.add(timeline[i]);
    }
    // Always include last month
    if (sampled.last.mois != timeline.last.mois) {
      sampled.add(timeline.last);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.repaymentTimelineTitle,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(S.of(context)!.repaymentTimelineMois,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(S.of(context)!.repaymentTimelinePaiement,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              Expanded(
                child: Text(S.of(context)!.repaymentTimelineSolde,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable rows
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sampled.length,
              itemBuilder: (context, index) {
                final month = sampled[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${month.mois}',
                          style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.paiementTotal)}',
                          style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.soldeTotal)}',
                          style: MintTextStyles.labelSmall(
                            color: month.soldeTotal <= 0.01
                                ? MintColors.success
                                : MintColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: MintColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.repaymentEmptyState,
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modele mutable pour les inputs de dette
class _DebtInput {
  String nom;
  double montant;
  double tauxAnnuel; // en % (ex: 9.9)
  double mensualiteMin;

  _DebtInput({
    required this.nom,
    required this.montant,
    required this.tauxAnnuel,
    required this.mensualiteMin,
  });
}
