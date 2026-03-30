import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de diagnostic du ratio d'endettement.
///
/// Affiche une gauge visuelle (semi-cercle vert/orange/rouge) avec le ratio,
/// le minimum vital et des recommandations.
/// Base legale : LP art. 93 (minimum vital), LCC.
class DebtRatioScreen extends StatefulWidget {
  const DebtRatioScreen({super.key});

  @override
  State<DebtRatioScreen> createState() => _DebtRatioScreenState();
}

class _DebtRatioScreenState extends State<DebtRatioScreen> {
  bool _hasUserInteracted = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('debt');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/dette-ratio',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn('debt_ratio', screenReturn);
      return;
    }

    final result = _result;
    final screenReturn = ScreenReturn.completed(
      route: '/dette-ratio',
      stepOutputs: {
        'ratio_endettement': result.ratio,
        'marge_mensuelle': result.margeDisponible,
      },
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('debt_ratio', screenReturn);
  }

  double _revenusMensuels = 6000;
  double _chargesDetteMensuelles = 500;
  double _loyer = 1500;
  double _autresCharges = 300;
  bool _estCelibataire = true;
  int _nombreEnfants = 0;

  DebtRatioResult get _result => DebtRatioCalculator.calculate(
        revenusMensuels: _revenusMensuels,
        chargesDetteMensuelles: _chargesDetteMensuelles,
        loyer: _loyer,
        autresChargesFixes: _autresCharges,
        estCelibataire: _estCelibataire,
        nombreEnfants: _nombreEnfants,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
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
            title: Text(
              S.of(context)!.debtRatioTitle,
              style: MintTextStyles.titleMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chiffre choc gauge
                MintEntrance(child: _buildGaugeSection(result)),
                const SizedBox(height: MintSpacing.lg),

                // Sliders
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: _buildSlidersSection(),
                ),
                const SizedBox(height: MintSpacing.lg),

                // Minimum vital
                MintEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: _buildMinimumVitalCard(result),
                ),
                const SizedBox(height: MintSpacing.lg),

                // Recommandations
                MintEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _buildRecommandationsSection(result),
                ),
                const SizedBox(height: MintSpacing.md),

                // CTA contextuel → Plan de remboursement
                if (result.niveau != DebtRiskLevel.vert)
                  MintEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: _buildRepaymentCta(result),
                  ),
                if (result.niveau != DebtRiskLevel.vert)
                  const SizedBox(height: MintSpacing.lg),

                // Aide professionnelle
                if (result.niveau == DebtRiskLevel.rouge) ...[
                  MintEntrance(
                    delay: const Duration(milliseconds: 450),
                    child: _buildAideProfessionnelleSection(),
                  ),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.lg),

                // Navigation croisée dette
                const DebtToolsNav(currentRoute: '/debt/ratio'),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildGaugeSection(DebtRatioResult result) {
    final color = switch (result.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    final label = switch (result.niveau) {
      DebtRiskLevel.vert => S.of(context)!.debtRatioLevelSain,
      DebtRiskLevel.orange => S.of(context)!.debtRatioLevelAttention,
      DebtRiskLevel.rouge => S.of(context)!.debtRatioLevelCritique,
    };

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        children: [
          // Semi-circle gauge
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(200, 150),
              painter: _GaugePainter(
                ratio: result.ratio,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          MintCountUp(
            value: result.ratio,
            suffix: '\u00a0%',
            decimals: 1,
            color: color,
            showLigne: false,
            contextText: S.of(context)!.debtRatioSubLabel,
            semanticsLabel: '${result.ratio.toStringAsFixed(1)}% — $label',
          ),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4, vertical: MintSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          // Legende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(MintColors.success, '< 15%'),
              const SizedBox(width: MintSpacing.md),
              _buildLegendDot(MintColors.warning, '15-30%'),
              const SizedBox(width: MintSpacing.md),
              _buildLegendDot(MintColors.error, '> 30%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
        ),
      ],
    );
  }

  bool _showDetails = false;

  Widget _buildSlidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Paramètres essentiels (toujours visibles) ──
        Row(
          children: [
            Expanded(
              child: _buildValueCard(
                label: S.of(context)!.debtRatioRevenuNet,
                value: _revenusMensuels,
                prefix: 'CHF',
                step: 500,
                min: 2000,
                max: 20000,
                icon: Icons.account_balance_wallet_outlined,
                onChanged: (v) => setState(() { _hasUserInteracted = true; _revenusMensuels = v; }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildValueCard(
                label: S.of(context)!.debtRatioChargesDette,
                value: _chargesDetteMensuelles,
                prefix: 'CHF',
                step: 100,
                min: 0,
                max: 10000,
                icon: Icons.credit_card_outlined,
                accentColor: _chargesDetteMensuelles > _revenusMensuels * 0.3
                    ? MintColors.error
                    : null,
                onChanged: (v) =>
                    setState(() { _hasUserInteracted = true; _chargesDetteMensuelles = v; }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Affiner le diagnostic ──
        GestureDetector(
          onTap: () => setState(() => _showDetails = !_showDetails),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _showDetails
                      ? Icons.tune
                      : Icons.tune,
                  color: MintColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.debtRatioRefineLabel,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  ),
                ),
                Text(
                  _showDetails ? '' : S.of(context)!.debtRatioRefineSuffix,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _showDetails ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: MintColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Détails (expandable) ──
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildValueCard(
                        label: S.of(context)!.debtRatioLoyer,
                        value: _loyer,
                        prefix: 'CHF',
                        step: 100,
                        min: 0,
                        max: 5000,
                        icon: Icons.home_outlined,
                        onChanged: (v) => setState(() { _hasUserInteracted = true; _loyer = v; }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValueCard(
                        label: S.of(context)!.debtRatioAutresCharges,
                        value: _autresCharges,
                        prefix: 'CHF',
                        step: 50,
                        min: 0,
                        max: 3000,
                        icon: Icons.receipt_long_outlined,
                        onChanged: (v) => setState(() { _hasUserInteracted = true; _autresCharges = v; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleCard(
                        label: S.of(context)!.debtRatioSituation,
                        options: [S.of(context)!.debtRatioSeul, S.of(context)!.debtRatioEnCouple],
                        selectedIndex: _estCelibataire ? 0 : 1,
                        onChanged: (i) =>
                            setState(() { _hasUserInteracted = true; _estCelibataire = i == 0; }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPillSelector(
                        label: S.of(context)!.debtRatioEnfants,
                        value: _nombreEnfants,
                        options: const [0, 1, 2, 3, 4],
                        onChanged: (v) =>
                            setState(() { _hasUserInteracted = true; _nombreEnfants = v; }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          crossFadeState: _showDetails
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  /// Carte de valeur avec stepper -/+ et tap pour saisie clavier.
  Widget _buildValueCard({
    required String label,
    required double value,
    required String prefix,
    required double step,
    required double min,
    required double max,
    required IconData icon,
    required ValueChanged<double> onChanged,
    Color? accentColor,
  }) {
    final color = accentColor ?? MintColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor != null
              ? accentColor.withValues(alpha: 0.3)
              : MintColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tappable value — opens keyboard input
          GestureDetector(
            onTap: () => _showValueEditor(
              label: label,
              currentValue: value,
              min: min,
              max: max,
              step: step,
              prefix: prefix,
              onChanged: onChanged,
            ),
            child: Center(
              child: Text(
                '$prefix\u00a0${formatChf(value)}',
                style: MintTextStyles.headlineMedium(color: MintColors.textPrimary)
                    ,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Stepper buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepperButton(
                icon: Icons.remove,
                enabled: value > min,
                onTap: () {
                  final newVal = (value - step).clamp(min, max);
                  onChanged(newVal);
                },
              ),
              const SizedBox(width: 24),
              _buildStepperButton(
                icon: Icons.add,
                enabled: value < max,
                onTap: () {
                  final newVal = (value + step).clamp(min, max);
                  onChanged(newVal);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? MintColors.surface : MintColors.lightBorder,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? MintColors.primary : MintColors.border,
        ),
      ),
    );
  }

  /// Toggle entre 2 options (célibataire / en couple).
  Widget _buildToggleCard({
    required String label,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: List.generate(options.length, (i) {
                final isSelected = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MintColors.primary
                            : MintColors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        options[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? MintColors.white
                              : MintColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Pills pour sélection rapide (nombre d'enfants).
  Widget _buildPillSelector({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((opt) {
              final isSelected = opt == value;
              final display = opt >= 4 ? '4+' : '$opt';
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    display,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? MintColors.white
                          : MintColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet pour saisie précise au clavier.
  void _showValueEditor({
    required String label,
    required double currentValue,
    required double min,
    required double max,
    required double step,
    required String prefix,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(
      text: currentValue.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.transparent,
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
                  Text(
                    '$prefix ',
                    style: MintTextStyles.headlineMedium(color: MintColors.textMuted)
                        ,
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.debtRatioMinMaxDisplay(formatChf(min), formatChf(max)),
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
                    S.of(context)!.debtRatioValidate,
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
    ).then((_) => controller.dispose());
  }

  Widget _buildMinimumVitalCard(DebtRatioResult result) {
    final isMenace = result.minimumVitalMenace;

    return MintSurface(
      tone: isMenace ? MintSurfaceTone.peche : MintSurfaceTone.blanc,
      elevated: isMenace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.debtRatioMinVital,
            style: MintTextStyles.bodySmall(
              color: isMenace ? MintColors.redMedium : MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            S.of(context)!.debtRatioMinimumVitalLabel,
            'CHF ${formatChf(result.minimumVital)} / mois',
          ),
          const Divider(height: 20),
          _buildInfoRow(
            S.of(context)!.debtRatioMargeDisponible,
            'CHF ${formatChf(result.margeDisponible)} / mois',
            color: result.margeDisponible > result.minimumVital
                ? MintColors.success
                : MintColors.error,
            isBold: true,
          ),
          if (isMenace) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.redBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: MintColors.redMedium, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context)!.debtRatioMinVitalWarning,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.redDark,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                : MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
                .copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommandationsSection(DebtRatioResult result) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.debtRatioRecommandations,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          for (final reco in result.recommandations)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward,
                      color: MintColors.primary, size: 16),
                  const SizedBox(width: MintSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      reco,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepaymentCta(DebtRatioResult result) {
    final isRouge = result.niveau == DebtRiskLevel.rouge;
    final color = isRouge ? MintColors.error : MintColors.warning;
    final bgColor = isRouge ? MintColors.urgentBg : MintColors.warningBg;

    return Semantics(
      label: S.of(context)!.debtRatioCtaSemantics,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/debt/repayment');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_down, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRouge
                          ? S.of(context)!.debtRatioCtaRouge
                          : S.of(context)!.debtRatioCtaOrange,
                      style: MintTextStyles.bodyMedium(
                        color: isRouge ? MintColors.redDark : MintColors.deepOrange,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.of(context)!.debtRatioCtaDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRouge ? MintColors.redDark : MintColors.deepOrange,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAideProfessionnelleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MintColors.urgentBg, MintColors.warningBg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.redBg, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent, color: MintColors.redMedium, size: 24),
              const SizedBox(width: 12),
              Text(
                S.of(context)!.debtRatioAidePro,
                style: MintTextStyles.bodyMedium(color: MintColors.redDark)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dettes Conseils
          _buildResourceLink(
            nom: S.of(context)!.debtRatioDetteConseilNom,
            description: S.of(context)!.debtRatioDetteConseilDesc,
            url: 'https://www.dettes.ch',
            telephone: '0800 40 40 40',
          ),
          const SizedBox(height: 12),

          // Caritas
          _buildResourceLink(
            nom: S.of(context)!.debtRatioCaritasNom,
            description: S.of(context)!.debtRatioCaritasDesc,
            url: 'https://www.caritas.ch/dettes',
            telephone: '0800 708 708',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink({
    required String nom,
    required String description,
    required String url,
    String? telephone,
  }) {
    return Semantics(
      label: nom,
      button: true,
      child: InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                  ),
                  if (telephone != null) ...[
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      telephone,
                      style: MintTextStyles.labelSmall(color: MintColors.info)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                color: MintColors.textMuted, size: 18),
          ],
        ),
      ),
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

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gauge Painter (semi-cercle)
// ─────────────────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _GaugePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2.5;

    // Background arc (gray)
    final bgPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Green zone (0-15%)
    final greenPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * 0.5, // 0-15% = first half
      false,
      greenPaint,
    );

    // Orange zone (15-30%)
    final orangePaint = Paint()
      ..color = MintColors.warning.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.5,
      pi * 0.25,
      false,
      orangePaint,
    );

    // Red zone (30%+)
    final redPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi * 0.75,
      pi * 0.25,
      false,
      redPaint,
    );

    // Needle position (ratio mapped to 0-pi)
    final clampedRatio = ratio.clamp(0.0, 50.0);
    final angle = pi + (clampedRatio / 50.0) * pi;

    // Needle
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleLength = radius - 10;
    final needleEnd = Offset(
      center.dx + needleLength * cos(angle),
      center.dy + needleLength * sin(angle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}
