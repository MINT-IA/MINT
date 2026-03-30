import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de simulation du rendement reel 3a avec economie fiscale.
///
/// Compare le rendement d'un 3a fintech avec un compte epargne classique
/// en tenant compte de l'economie fiscale et de l'inflation.
/// Base legale : OPP3, LIFD art. 33 al. 1 let. e.
class RealReturnScreen extends StatefulWidget {
  const RealReturnScreen({super.key});

  @override
  State<RealReturnScreen> createState() => _RealReturnScreenState();
}

class _RealReturnScreenState extends State<RealReturnScreen> {
  double _versementAnnuel = pilier3aPlafondAvecLpp;
  double _tauxMarginal = 0.32;
  double _rendementBrut = 0.045;
  double _fraisGestion = 0.005;
  int _dureeAnnees = 30;
  bool _hasUserInteracted = false;

  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  RealReturnResult get _result => RealReturnCalculator.calculate(
        versementAnnuel: _versementAnnuel,
        tauxMarginal: _tauxMarginal,
        rendementBrut: _rendementBrut,
        fraisGestion: _fraisGestion,
        dureeAnnees: _dureeAnnees,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
      _initializeFromProfile();
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {}
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      ScreenCompletionTracker.markCompletedWithReturn('real_return_3a',
        ScreenReturn.abandoned(
          route: '/3a-deep/real-return',
          runId: _seqRunId, stepId: _seqStepId,
          eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
        ));
      return;
    }

    // Last step of 3a template — no outputMapping, but emit completed
    // so the coordinator knows the sequence is done.
    ScreenCompletionTracker.markCompletedWithReturn('real_return_3a',
      ScreenReturn.completed(
        route: '/3a-deep/real-return',
        runId: _seqRunId, stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      ));
  }

  void _initializeFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      bool changed = false;
      if (profile.revenuBrutAnnuel > 0) {
        _tauxMarginal = RetirementTaxCalculator.estimateMarginalRate(
          profile.revenuBrutAnnuel,
          profile.canton,
        ).clamp(0.0, 0.50);
        changed = true;
      }
      final yearsToRetirement = profile.anneesAvantRetraite;
      if (yearsToRetirement >= 5 && yearsToRetirement <= 40) {
        _dureeAnnees = yearsToRetirement;
        changed = true;
      }
      if (changed) setState(() {});
    } catch (_) {
      // Provider not available
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        title: Text(l.realReturnTitle, style: MintTextStyles.headlineMedium()),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          // Narrative intro
          MintEntrance(child: MintNarrativeCard(
            headline: S.of(context)!.narrativeRealReturnHeadline,
            body: S.of(context)!.narrativeRealReturnBody,
            tone: MintSurfaceTone.sauge,
            badge: S.of(context)!.narrativeRealReturnBadge,
          )),
          const SizedBox(height: MintSpacing.lg),

          // Chiffre choc
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildChiffreChoc(result)),
          const SizedBox(height: MintSpacing.lg),

          // Aha moment narrative
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildAhaMoment(result)),
          const SizedBox(height: MintSpacing.lg),

          // Sliders
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSlidersSection()),
          const SizedBox(height: MintSpacing.lg),

          // Resultat rendement
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildRendementSection(result)),
          const SizedBox(height: MintSpacing.lg),

          // Comparaison barres
          MintEntrance(delay: const Duration(milliseconds: 500), child: _buildComparisonBars(result)),
          const SizedBox(height: MintSpacing.lg),

          // Detail economie fiscale
          _buildFiscalDetail(result),
          const SizedBox(height: MintSpacing.lg),

          // Disclaimer
          _buildDisclaimer(result.disclaimer),
          const SizedBox(height: MintSpacing.xl),
        ],
      )))),
    );
  }

  Widget _buildChiffreChoc(RealReturnResult result) {
    final l = S.of(context)!;
    return MintResultHeroCard(
      eyebrow: l.realReturnChiffreChocLabel,
      primaryValue: '${result.rendementReel.toStringAsFixed(1)}\u00a0%',
      primaryLabel: l.realReturnPrimaryLabel,
      secondaryValue: '${result.rendementNominal.toStringAsFixed(1)}\u00a0%',
      secondaryLabel: l.realReturnVsNominal(result.rendementNominal.toStringAsFixed(1)),
      narrative: l.realReturnNarrative,
      accentColor: MintColors.success,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  Widget _buildAhaMoment(RealReturnResult result) {
    final l = S.of(context)!;
    final effortNet = _versementAnnuel * (1 - _tauxMarginal);
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              l.realReturnAhaMoment('CHF\u00a0${formatChf(effortNet)}'),
              style: MintTextStyles.bodyMedium(color: MintColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection() {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.realReturnParams, style: MintTextStyles.labelSmall()),
          const SizedBox(height: MintSpacing.md),

          _buildSliderRow(
            label: l.realReturnAnnualPayment,
            value: _versementAnnuel,
            min: 1000,
            max: pilier3aPlafondAvecLpp,
            divisions: 125,
            format: 'CHF\u00a0${formatChf(_versementAnnuel)}',
            onChanged: (v) =>
                setState(() { _hasUserInteracted = true; _versementAnnuel = (v / 50).round() * 50.0; }),
          ),
          const SizedBox(height: MintSpacing.sm),

          _buildSliderRow(
            label: l.realReturnMarginalRate,
            value: _tauxMarginal,
            min: 0.00,
            max: 0.50,
            divisions: 50,
            format: '${(_tauxMarginal * 100).toStringAsFixed(0)}\u00a0%',
            onChanged: (v) => setState(() { _hasUserInteracted = true; _tauxMarginal = v; }),
          ),
          const SizedBox(height: MintSpacing.sm),

          _buildSliderRow(
            label: l.realReturnGrossReturn,
            value: _rendementBrut,
            min: 0.01,
            max: 0.08,
            divisions: 14,
            format: '${(_rendementBrut * 100).toStringAsFixed(1)}\u00a0%',
            onChanged: (v) => setState(() { _hasUserInteracted = true; _rendementBrut = v; }),
          ),
          const SizedBox(height: MintSpacing.sm),

          _buildSliderRow(
            label: l.realReturnMgmtFees,
            value: _fraisGestion,
            min: 0.0,
            max: 0.02,
            divisions: 20,
            format: '${(_fraisGestion * 100).toStringAsFixed(2)}\u00a0%',
            onChanged: (v) => setState(() { _hasUserInteracted = true; _fraisGestion = v; }),
          ),
          const SizedBox(height: MintSpacing.sm),

          _buildSliderRow(
            label: l.realReturnDuration,
            value: _dureeAnnees.toDouble(),
            min: 5,
            max: 40,
            divisions: 35,
            format: l.realReturnYearsSuffix(_dureeAnnees),
            onChanged: (v) => setState(() { _hasUserInteracted = true; _dureeAnnees = v.round(); }),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: (_) => format,
      onChanged: onChanged,
    );
  }

  Widget _buildRendementSection(RealReturnResult result) {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.realReturnCompared, style: MintTextStyles.labelSmall()),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            l.realReturnNominal3a,
            '${result.rendementNominal.toStringAsFixed(1)}\u00a0% ${l.realReturnPerYear}',
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.realReturnRealWithFiscal,
            '${result.rendementReel.toStringAsFixed(1)}\u00a0% ${l.realReturnPerYear}',
            isBold: true,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.realReturnEquivNote,
            style: MintTextStyles.labelSmall(),
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.realReturnSavingsAccount,
            '${result.rendementEpargne.toStringAsFixed(1)}\u00a0% ${l.realReturnPerYear}',
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBars(RealReturnResult result) {
    final l = S.of(context)!;
    final maxVal = [
      result.capitalFinal3a + result.economieFiscaleTotale,
      result.capitalFinalEpargne,
    ].reduce((a, b) => a > b ? a : b);

    final ratio3a = maxVal > 0
        ? ((result.capitalFinal3a + result.economieFiscaleTotale) / maxVal)
        : 0.0;
    final ratioEpargne =
        maxVal > 0 ? (result.capitalFinalEpargne / maxVal) : 0.0;

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.realReturnFinalCapital(_dureeAnnees),
            style: MintTextStyles.labelSmall(),
          ),
          const SizedBox(height: MintSpacing.md),

          _buildBar(
            label: l.realReturn3aFintech,
            amount: result.capitalFinal3a + result.economieFiscaleTotale,
            ratio: ratio3a,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.md),

          _buildBar(
            label: l.realReturnSavings15,
            amount: result.capitalFinalEpargne,
            ratio: ratioEpargne,
            color: MintColors.textMuted,
          ),

          const SizedBox(height: MintSpacing.md),
          Semantics(
            label: S.of(context)!.semanticsRealReturnGain(formatChf(result.gainVsEpargne)),
            child: Container(
              padding: const EdgeInsets.all(MintSpacing.sm),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: const Icon(Icons.trending_up, color: MintColors.success, size: 20)),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      l.realReturnGainVsSavings(formatChf(result.gainVsEpargne)),
                      style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required double amount,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: MintTextStyles.labelSmall(color: MintColors.textPrimary)),
            Text(
              'CHF\u00a0${formatChf(amount)}',
              style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildFiscalDetail(RealReturnResult result) {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.realReturnFiscalDetail, style: MintTextStyles.labelSmall()),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            l.realReturnTotalPayments,
            'CHF\u00a0${formatChf(result.totalVersements)}',
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.realReturnFinalCapital3a,
            'CHF\u00a0${formatChf(result.capitalFinal3a)}',
          ),
          _buildResultRow(
            l.realReturnCumulativeFiscal,
            'CHF\u00a0${formatChf(result.economieFiscaleTotale)}',
            color: MintColors.success,
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.realReturnTotalWithFiscal,
            'CHF\u00a0${formatChf(result.capitalFinal3a + result.economieFiscaleTotale)}',
            isBold: true,
            color: MintColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Semantics(
      label: S.of(context)!.semanticsMetricLabelValue(label, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: MintTextStyles.bodySmall(
                  color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
                ).copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            Text(
              value,
              style: MintTextStyles.bodySmall(
                color: color ?? MintColors.textPrimary,
              ).copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
            ),
          ],
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
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
