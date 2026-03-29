import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de simulation du retrait EPL (Encouragement a la Propriete du Logement).
///
/// Permet d'estimer le montant retirable, l'impot et l'impact sur
/// les prestations de risque (invalidite, deces).
/// Base legale : art. 30c LPP, OEPL.
class EplScreen extends StatefulWidget {
  const EplScreen({super.key});

  @override
  State<EplScreen> createState() => _EplScreenState();
}

class _EplScreenState extends State<EplScreen> {
  bool _hasUserInteracted = false;

  /// Sequence IDs read from GoRouter.extra (Tier A when present).
  /// Null when navigated without sequence context (Tier B legacy).
  String? _seqRunId;
  String? _seqStepId;

  /// Guard: ensures _emitFinalReturn fires exactly once.
  bool _finalReturnEmitted = false;

  double _avoirTotal = 300000;
  int _age = 40;
  double _montantSouhaite = 100000;
  bool _aRachete = false;
  int _anneesSDepuisRachat = 0;
  String _canton = 'ZH';
  double _obligRatio = 0.6;
  double _grossAnnualSalary = 100000;

  EplResult get _result {
    // Repartition oblig / suroblig from profile or default ratio
    final oblig = _avoirTotal * _obligRatio;
    final suroblig = _avoirTotal * (1 - _obligRatio);

    return EplSimulator.simulate(
      avoirTotal: _avoirTotal,
      avoirObligatoire: oblig,
      avoirSurobligatoire: suroblig,
      age: _age,
      montantSouhaite: _montantSouhaite,
      aRachete: _aRachete,
      anneesSDepuisRachat: _anneesSDepuisRachat,
      canton: _canton,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
      _initializeFromProfile();
    });
  }

  /// Read sequence runId/stepId/prefill from GoRouter.extra if present.
  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
        final prefill = extra['prefill'] as Map<String, dynamic>?;
        if (prefill != null) _applyPrefill(prefill);
      }
    } catch (_) {
      // Not navigated via GoRouter or no extra — stay Tier B.
    }
  }

  /// Apply prefill values from preceding sequence step.
  /// Mapping: montant_bien_cible → target property price (informational),
  /// montant_necessaire → fonds propres requis (can inform withdrawal amount).
  void _applyPrefill(Map<String, dynamic> prefill) {
    final fonds = prefill['montant_necessaire'];
    if (fonds is num && fonds > 0) {
      setState(() {
        // Suggest the required own funds as default withdrawal amount.
        _montantSouhaite = fonds.toDouble().clamp(20000, 500000);
      });
    }
  }

  /// Emits a terminal ScreenReturn when the user leaves the screen.
  /// If in a guided sequence (Tier A), includes runId/stepId/eventId
  /// and stepOutputs for the SequenceCoordinator to advance the run.
  /// If user didn't interact → abandoned (so coordinator can retry).
  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      // User opened screen but left without interacting → abandoned.
      // The coordinator will offer a retry instead of leaving sequence stuck.
      final screenReturn = ScreenReturn.abandoned(
        route: '/epl',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn('epl', screenReturn);
      return;
    }

    final result = _result;
    final eplImpact = LppCalculator.computeEplImpact(
      currentBalance: _avoirTotal,
      eplAmount: result.montantSouhaiteApplicable,
      eplRepaid: 0,
      currentAge: _age,
      retirementAge: avsAgeReferenceHomme,
      grossAnnualSalary: _grossAnnualSalary,
      caisseReturn: lppTauxInteretMin / 100,
      conversionRate: lppTauxConversionMinDecimal,
    );
    final screenReturn = ScreenReturn.completed(
      route: '/epl',
      stepOutputs: {
        'montant_epl': result.montantSouhaiteApplicable,
        'impact_rente': eplImpact.monthlyGapFromEpl,
      },
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('epl', screenReturn);
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        // LPP total balance
        final lppTotal = profile.prevoyance.avoirLppTotal;
        if (lppTotal != null && lppTotal > 0) _avoirTotal = lppTotal;

        // Age
        final age = profile.age;
        if (age >= 25 && age <= avsAgeReferenceHomme) _age = age;

        // Canton
        if (cantonFullNames.containsKey(profile.canton)) {
          _canton = profile.canton;
        }

        // Oblig / surob split from profile if available
        final oblig = profile.prevoyance.avoirLppObligatoire;
        final surob = profile.prevoyance.avoirLppSurobligatoire;
        if (oblig != null && surob != null && (oblig + surob) > 0) {
          _obligRatio = oblig / (oblig + surob);
        }

        // Gross annual salary
        final revenu = profile.revenuBrutAnnuel;
        if (revenu > 0) _grossAnnualSalary = revenu;
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
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
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              l.eplAppBarTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Narrative intro
                MintEntrance(child: MintNarrativeCard(
                  headline: 'Retrait EPL\u00a0: avantages et blocage 3 ans', // TODO: i18n
                  body: 'L\u2019art.\u00a030c LPP permet de retirer ton 2e pilier pour financer '
                      'un logement en propri\u00e9t\u00e9. Attention\u00a0: si tu as effectu\u00e9 des rachats, '
                      'un d\u00e9lai de blocage de 3 ans s\u2019applique (OPP2 art.\u00a05).', // TODO: i18n
                  tone: MintSurfaceTone.bleu,
                  badge: '2e pilier \u2014 EPL', // TODO: i18n
                )),
                const SizedBox(height: MintSpacing.lg),

                // Introduction
                _buildIntroCard(l),
                const SizedBox(height: MintSpacing.lg),

                // Sliders
                _buildSlidersSection(l),
                const SizedBox(height: MintSpacing.lg),

                // Results
                _buildResultsSection(result, l),
                const SizedBox(height: MintSpacing.lg),

                // Impact on benefits
                if (result.montantSouhaiteApplicable > 0) ...[
                  _buildImpactSection(result, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Impact on retirement rente
                if (result.montantSouhaiteApplicable > 0) ...[
                  _buildRenteImpactSection(result, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Tax estimate
                if (result.montantSouhaiteApplicable > 0) ...[
                  _buildTaxCard(result, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Alerts
                if (result.alerts.isNotEmpty) ...[
                  _buildAlertsSection(result.alerts, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ))),
    ));
  }

  Widget _buildIntroCard(S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.eplIntroTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.eplIntroBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(
            l.eplSectionParametres,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),

          // Avoir total
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildSliderRow(
            label: l.eplLabelAvoirTotal,
            value: _avoirTotal,
            min: 0,
            max: 800000,
            divisions: 160,
            format: 'CHF ${formatChf(_avoirTotal)}',
            onChanged: (v) => setState(() { _hasUserInteracted = true; _avoirTotal = v; }),
          )),
          const SizedBox(height: MintSpacing.sm + 4),

          // Age
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSliderRow(
            label: l.eplLabelAge,
            value: _age.toDouble(),
            min: 25,
            max: 65,
            divisions: 40,
            format: l.eplLabelAgeFormat(_age),
            onChanged: (v) => setState(() { _hasUserInteracted = true; _age = v.round(); }),
          )),
          const SizedBox(height: MintSpacing.sm + 4),

          // Montant souhaite
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildSliderRow(
            label: l.eplLabelMontantSouhaite,
            value: _montantSouhaite,
            min: 20000,
            max: 500000,
            divisions: 96,
            format: 'CHF ${formatChf(_montantSouhaite)}',
            onChanged: (v) => setState(() { _hasUserInteracted = true; _montantSouhaite = v; }),
          )),
          const SizedBox(height: MintSpacing.sm + 4),

          // Canton (pour l'impot sur retrait)
          MintEntrance(delay: const Duration(milliseconds: 400), child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.eplLabelCanton,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              Semantics(
                label: l.eplLabelCanton,
                child: DropdownButton<String>(
                  value: _canton,
                  underline: const SizedBox(),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  items: sortedCantonCodes.map((code) {
                    final name = cantonFullNames[code] ?? code;
                    return DropdownMenuItem(
                      value: code,
                      child: Text('$code — $name'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() { _hasUserInteracted = true; _canton = v; });
                  },
                ),
              ),
            ],
          )),
          const SizedBox(height: MintSpacing.md),

          // Rachats recents
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.eplLabelRachatsRecents,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.eplLabelRachatsQuestion,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: l.eplLabelRachatsRecents,
                toggled: _aRachete,
                child: Switch(
                  value: _aRachete,
                  activeTrackColor: MintColors.primary,
                  onChanged: (v) => setState(() {
                    _hasUserInteracted = true;
                    _aRachete = v;
                    if (!v) _anneesSDepuisRachat = 0;
                  }),
                ),
              ),
            ],
          ),

          if (_aRachete) ...[
            const SizedBox(height: MintSpacing.sm + 4),
            _buildSliderRow(
              label: l.eplLabelAnneesSDepuisRachat,
              value: _anneesSDepuisRachat.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              format: l.eplLabelAnneesSDepuisRachatFormat(_anneesSDepuisRachat, _anneesSDepuisRachat > 1 ? 's' : ''),
              onChanged: (v) =>
                  setState(() { _hasUserInteracted = true; _anneesSDepuisRachat = v.round(); }),
            ),
          ],
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

  Widget _buildResultsSection(EplResult result, S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.eplSectionResultat,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            l.eplMontantMaxRetirable,
            'CHF ${formatChf(result.montantMaxRetirable)}',
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.eplMontantApplicable,
            'CHF ${formatChf(result.montantSouhaiteApplicable)}',
            isBold: true,
            color: result.montantSouhaiteApplicable > 0
                ? MintColors.success
                : MintColors.error,
          ),
          if (result.montantSouhaiteApplicable == 0 &&
              result.alerts.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.eplRetraitImpossible,
              style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
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

  Widget _buildImpactSection(EplResult result, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.eplSectionImpactPrestations,
            style: MintTextStyles.bodySmall(color: MintColors.error),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildImpactRow(
            icon: Icons.accessible,
            label: l.eplReductionInvalidite,
            amount: '-CHF ${formatChf(result.reductionRenteInvalidite)}',
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildImpactRow(
            icon: Icons.heart_broken_outlined,
            label: l.eplReductionDeces,
            amount: '-CHF ${formatChf(result.reductionCapitalDeces)}',
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            l.eplImpactPrestationsNote,
            style: MintTextStyles.labelSmall(color: MintColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow({
    required IconData icon,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: MintTextStyles.labelSmall(color: MintColors.textPrimary)),
        ),
        Text(
          amount,
          style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRenteImpactSection(EplResult result, S l) {
    final eplImpact = LppCalculator.computeEplImpact(
      currentBalance: _avoirTotal,
      eplAmount: result.montantSouhaiteApplicable,
      eplRepaid: 0,
      currentAge: _age,
      retirementAge: avsAgeReferenceHomme,
      grossAnnualSalary: _grossAnnualSalary,
      caisseReturn: lppTauxInteretMin / 100,
      conversionRate: lppTauxConversionMinDecimal,
    );

    final renteWithout = eplImpact.renteWithoutEpl / 12;
    final renteWith = eplImpact.renteWithEplOutstanding / 12;
    final perteMensuelle = eplImpact.monthlyGapFromEpl;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.eplSectionImpactRente,
            style: MintTextStyles.bodySmall(color: MintColors.warning),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            l.eplRenteSansEpl,
            'CHF ${formatChf(renteWithout)}/mois',
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.eplRenteAvecEpl,
            'CHF ${formatChf(renteWith)}/mois',
            color: MintColors.warning,
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.eplPerteMensuelle,
            '-CHF ${formatChf(perteMensuelle)}/mois',
            isBold: true,
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            l.eplImpactRenteNote,
            style: MintTextStyles.labelSmall(color: MintColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCard(EplResult result, S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.eplSectionFiscale,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(
            l.eplMontantRetire,
            'CHF ${formatChf(result.montantSouhaiteApplicable)}',
          ),
          _buildResultRow(
            l.eplImpotEstime,
            'CHF ${formatChf(result.impotEstime)}',
            color: MintColors.error,
          ),
          const Divider(height: 20),
          _buildResultRow(
            l.eplMontantNet,
            'CHF ${formatChf(result.montantSouhaiteApplicable - result.impotEstime)}',
            isBold: true,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.eplFiscaleNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<String> alerts, S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.eplSectionPointsAttention,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        for (final alert in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MintColors.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: MintColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert,
                    style: MintTextStyles.labelSmall(color: MintColors.warning),
                  ),
                ),
              ],
            ),
          ),
      ],
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
