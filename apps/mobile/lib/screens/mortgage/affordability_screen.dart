import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/coach/mortgage_journey_widget.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';

/// Ecran de capacite d'achat immobilier (Cat B — Decision Canvas).
///
/// Layout S55: enjeu d'abord, consequence avant controle, matiere chaude.
/// Le resultat (prix max accessible) domine. Les sliders suivent.
/// Base legale : directive ASB sur le credit hypothecaire.
class AffordabilityScreen extends StatefulWidget {
  const AffordabilityScreen({super.key});

  @override
  State<AffordabilityScreen> createState() => _AffordabilityScreenState();
}

class _AffordabilityScreenState extends State<AffordabilityScreen> {
  bool _hasUserInteracted = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;
  final Set<String> _prefilledFields = {};

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('mortgage');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
      _readSequenceContext();
    });
  }

  /// Auto-fill from CoachProfile — replaces hardcoded defaults (120000, 200000).
  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      final profile = provider.profile;
      if (profile == null) return;

      bool changed = false;
      final revenuAnnuel = profile.salaireBrutMensuel * profile.nombreDeMois;
      if (revenuAnnuel > 0) {
        _revenuBrut = revenuAnnuel;
        _prefilledFields.add('revenu_brut');
        changed = true;
      }
      final avoirLpp = profile.prevoyance.avoirLppTotal;
      if (avoirLpp != null && avoirLpp > 0) {
        _avoirLpp = avoirLpp;
        _prefilledFields.add('avoir_lpp');
        changed = true;
      }
      final epargne = profile.patrimoine.epargneLiquide;
      if (epargne > 0) {
        _epargneDispo = epargne;
        _prefilledFields.add('epargne_dispo');
        changed = true;
      }
      final canton = profile.canton;
      if (canton.isNotEmpty) {
        _canton = canton.toUpperCase();
        changed = true;
      }
      if (changed) setState(() {});
    } catch (_) {
      // CoachProfileProvider not available — keep hardcoded defaults.
    }
  }

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

  /// Apply prefill from GoRouter coach suggestion (overrides profile auto-fill).
  void _applyPrefill(Map<String, dynamic> prefill) {
    bool changed = false;

    final salaireBrut = prefill['salaireBrut'];
    if (salaireBrut is num && salaireBrut > 0) {
      // Monthly value — multiply by 13 for annual
      _revenuBrut = salaireBrut.toDouble() * 13;
      _prefilledFields.add('revenu_brut');
      changed = true;
    }

    final epargne = prefill['epargne'];
    if (epargne is num && epargne >= 0) {
      _epargneDispo = epargne.toDouble();
      _prefilledFields.add('epargne_dispo');
      changed = true;
    }

    final avoirLpp = prefill['avoirLpp'];
    if (avoirLpp is num && avoirLpp >= 0) {
      _avoirLpp = avoirLpp.toDouble();
      _prefilledFields.add('avoir_lpp');
      changed = true;
    }

    if (changed) setState(() {});
  }

  /// Write computed mortgage capacity back to CoachProfile.
  void _writeBackResult() {
    if (!_hasUserInteracted) return;
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    try {
      final result = _result;
      final updated = profile.copyWith(
        patrimoine: profile.patrimoine.copyWith(
          mortgageCapacity: result.prixMaxAccessible > 0
              ? result.prixMaxAccessible
              : null,
          estimatedMonthlyPayment: result.chargesTheoriquesMensuelles > 0
              ? result.chargesTheoriquesMensuelles
              : null,
        ),
      );
      provider.updateProfile(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context)!.profileUpdatedSnackbar,
            style: MintTextStyles.bodySmall().copyWith(color: MintColors.white),
          ),
          backgroundColor: MintColors.primary,
          duration: const Duration(milliseconds: 2500),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context)!.profileUpdateErrorSnackbar,
            style: MintTextStyles.bodySmall().copyWith(color: MintColors.white),
          ),
          backgroundColor: MintColors.error,
          duration: const Duration(milliseconds: 3000),
        ),
      );
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      final screenReturn = ScreenReturn.abandoned(
        route: '/hypotheque',
        runId: _seqRunId,
        stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      ScreenCompletionTracker.markCompletedWithReturn('affordability', screenReturn);
      return;
    }

    final result = _result;
    final screenReturn = ScreenReturn.completed(
      route: '/hypotheque',
      stepOutputs: {
        'capacite_achat': result.prixMaxAccessible,
        'fonds_propres_requis': result.fondsPropresRequis,
      },
      runId: _seqRunId,
      stepId: _seqStepId,
      eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    ScreenCompletionTracker.markCompletedWithReturn('affordability', screenReturn);
  }

  double _revenuBrut = 120000;
  double _prixAchat = 800000;
  double _epargneDispo = 100000;
  double _avoir3a = 50000;
  double _avoirLpp = 200000;
  String _canton = 'VD';
  bool _showAdvancedParams = false;

  static const _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  AffordabilityResult get _result => AffordabilityCalculator.calculate(
        revenuBrutAnnuel: _revenuBrut,
        epargneDispo: _epargneDispo,
        avoir3a: _avoir3a,
        avoirLpp: _avoirLpp,
        prixAchat: _prixAchat,
        canton: _canton,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: CustomScrollView(
        slivers: [
          // ── White standard AppBar (Design System §4.5) ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l.affordabilityTitle,
                style: MintTextStyles.headlineMedium(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 1 — L'ENJEU : la question hero
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                Text(
                  l.affordabilityEmotionalPositif,
                  style: MintTextStyles.headlineLarge(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 2 — LE RESULTAT : consequence financiere
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                MintResultHeroCard(
                  eyebrow: result.chiffreChocPositif
                      ? l.affordabilityParameters
                      : l.affordabilityInsightEquityTitle,
                  primaryValue: result.chiffreChocPositif
                      ? 'CHF\u00a0${formatChf(result.prixMaxAccessible)}'
                      : 'CHF\u00a0${formatChf(result.manqueFondsPropres)}',
                  primaryLabel: result.chiffreChocPositif
                      ? l.affordabilityCalculationDetail
                      : l.affordabilityExceeded,
                  narrative: result.chiffreChocTexte,
                  accentColor: result.chiffreChocPositif
                      ? MintColors.success
                      : MintColors.error,
                  tone: MintSurfaceTone.porcelaine,
                ),
                const SizedBox(height: MintSpacing.xl),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 3 — INDICATEURS : signaux, pas jauges
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.affordabilityIndicators,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
                        ),
                      ),
                      MintSignalRow(
                        label: l.affordabilityChargesRatio,
                        value: '${(result.ratioCharges * 100).toStringAsFixed(1)}\u00a0%',
                        valueColor: result.capaciteOk
                            ? MintColors.success
                            : MintColors.error,
                      ),
                      MintSignalRow(
                        label: l.affordabilityEquityRatio,
                        value:
                            'CHF\u00a0${formatChf(result.fondsPropresTotal)} / ${formatChf(result.fondsPropresRequis)}',
                        valueColor: result.fondsPropresOk
                            ? MintColors.success
                            : MintColors.error,
                      ),
                      MintSignalRow(
                        label: l.affordabilityMonthlyCharges,
                        value:
                            'CHF\u00a0${formatChf(result.chargesTheoriquesMensuelles)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 4 — INSIGHT pedagogique
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                _buildInsightCard(result, l),
                const SizedBox(height: MintSpacing.lg),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 5 — CONFIDENCE NOTICE (donnees estimees)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                MintConfidenceNotice(
                  percent: 45,
                  message: l.affordabilityCalculationNote,
                ),
                const SizedBox(height: MintSpacing.xl),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 6 — CONTROLES : sliders SOUS le resultat
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                MintSurface(
                  tone: MintSurfaceTone.craie,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.affordabilityParameters,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.md),

                      // Canton
                      Semantics(
                        label: l.affordabilityCanton,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.affordabilityCanton,
                              style: MintTextStyles.bodySmall(
                                color: MintColors.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MintSpacing.sm + MintSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: MintColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _canton,
                                  items: _cantons
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c,
                                                style: MintTextStyles.bodySmall(
                                                    color: MintColors
                                                        .textPrimary)),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() { _hasUserInteracted = true; _canton = v; });
                                      WidgetsBinding.instance.addPostFrameCallback((_) => _writeBackResult());
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MintSpacing.lg),

                      // Revenu brut annuel
                      _buildAmountFieldWithBadge(
                        label: l.affordabilityGrossIncome,
                        value: _revenuBrut,
                        fieldKey: 'revenu_brut',
                        onChanged: (v) {
                          setState(() { _hasUserInteracted = true; _revenuBrut = v; });
                          WidgetsBinding.instance.addPostFrameCallback((_) => _writeBackResult());
                        },
                        min: 50000,
                        max: 300000,
                      ),
                      const SizedBox(height: MintSpacing.md),

                      // Prix d'achat
                      MintAmountField(
                        label: l.affordabilityTargetPrice,
                        value: _prixAchat,
                        formatValue: (v) => 'CHF\u00a0${formatChf(v)}',
                        onChanged: (v) => setState(() { _hasUserInteracted = true; _prixAchat = v; }),
                        min: 200000,
                        max: 3000000,
                      ),
                      const SizedBox(height: MintSpacing.md),

                      // Epargne disponible
                      MintAmountField(
                        label: l.affordabilityAvailableSavings,
                        value: _epargneDispo,
                        formatValue: (v) => 'CHF\u00a0${formatChf(v)}',
                        onChanged: (v) => setState(() { _hasUserInteracted = true; _epargneDispo = v; }),
                        min: 0,
                        max: 500000,
                      ),

                      // Progressive disclosure: 3a + LPP behind toggle
                      const SizedBox(height: MintSpacing.md),
                      Semantics(
                        button: true,
                        label: l.affordabilityAdvancedParams,
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _showAdvancedParams = !_showAdvancedParams),
                          child: Row(
                            children: [
                              Icon(
                                _showAdvancedParams
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: MintColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: MintSpacing.xs),
                              Text(
                                l.affordabilityAdvancedParams,
                                style: MintTextStyles.bodySmall(
                                    color: MintColors.info),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showAdvancedParams) ...[
                        const SizedBox(height: MintSpacing.md),
                        MintAmountField(
                          label: l.affordabilityPillar3a,
                          value: _avoir3a,
                          formatValue: (v) => 'CHF\u00a0${formatChf(v)}',
                          onChanged: (v) => setState(() { _hasUserInteracted = true; _avoir3a = v; }),
                          min: 0,
                          max: 300000,
                        ),
                        const SizedBox(height: MintSpacing.md),
                        _buildAmountFieldWithBadge(
                          label: l.affordabilityPillarLpp,
                          value: _avoirLpp,
                          fieldKey: 'avoir_lpp',
                          onChanged: (v) => setState(() { _hasUserInteracted = true; _avoirLpp = v; }),
                          min: 0,
                          max: 500000,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 7 — DETAIL calcul (progressive disclosure)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                _buildDetailSection(result, l),
                const SizedBox(height: MintSpacing.lg),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 8 — EXPLORER AUSSI
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                _buildRelatedSections(l),
                const SizedBox(height: MintSpacing.lg),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // SECTION 9 — DISCLAIMER (micro)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                Text(
                  result.disclaimer,
                  style: MintTextStyles.micro(),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── P3-E : Parcours achat immobilier ──
                const MortgageJourneyWidget(),
                const SizedBox(height: MintSpacing.sm),

                // ── Source legale ──
                Semantics(
                  label: l.affordabilitySource,
                  child: Text(
                    l.affordabilitySource,
                    style: MintTextStyles.micro(),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    ));
  }

  /// Builds a MintAmountField with an optional SmartDefaultIndicator badge
  /// shown above the field when the field key is in _prefilledFields.
  Widget _buildAmountFieldWithBadge({
    required String label,
    required double value,
    required String fieldKey,
    required ValueChanged<double> onChanged,
    double? min,
    double? max,
  }) {
    final isPrefilled = _prefilledFields.contains(fieldKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPrefilled) ...[
          Row(
            children: [
              Text(label,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary)),
              const SmartDefaultIndicator(
                source: 'Depuis ton profil MINT',
                confidence: 0.60,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        MintAmountField(
          label: isPrefilled ? label : label,
          value: value,
          formatValue: (v) => 'CHF\u00a0${formatChf(v)}',
          onChanged: onChanged,
          min: min,
          max: max,
        ),
      ],
    );
  }

  Widget _buildInsightCard(AffordabilityResult result, S l) {
    final lppNonUtilise = _avoirLpp - result.lppUtilise;

    // Determine insight content based on binding constraint
    final String title;
    final String body;

    if (result.isRevenueConstrained && result.fondsPropresOk) {
      title = l.affordabilityInsightRevenueTitle;
      body = l.affordabilityInsightRevenueBody(
        formatChf(result.chargesTheoriquesMensuelles),
        formatChf(result.chargesReellesMensuelles),
      );
    } else if (!result.fondsPropresOk) {
      title = l.affordabilityInsightEquityTitle;
      body = l.affordabilityInsightEquityBody(
        formatChf(result.manqueFondsPropres),
      );
    } else {
      title = l.affordabilityInsightOkTitle;
      body = l.affordabilityInsightOkBody;
    }

    return MintSurface(
      tone: MintSurfaceTone.bleu,
      child: Semantics(
        label: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              body,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            if (lppNonUtilise > 0) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.affordabilityInsightLppCap(
                  formatChf(result.lppUtilise),
                  formatChf(_avoirLpp),
                ),
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(AffordabilityResult result, S l) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.affordabilityCalculationDetail,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          MintSignalRow(
            label: l.affordabilityTargetPrice,
            value: 'CHF\u00a0${formatChf(_prixAchat)}',
          ),
          MintSignalRow(
            label: l.affordabilityEquityRequired,
            value: 'CHF\u00a0${formatChf(result.fondsPropresRequis)}',
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.3),
            height: 1,
          ),
          MintSignalRow(
            label: l.affordabilitySavingsLabel,
            value: 'CHF\u00a0${formatChf(_epargneDispo)}',
          ),
          MintSignalRow(
            label: l.affordabilityPillar3a,
            value: 'CHF\u00a0${formatChf(_avoir3a)}',
          ),
          MintSignalRow(
            label: l.affordabilityLppMax10,
            value:
                'CHF\u00a0${formatChf(min(_avoirLpp, _prixAchat * 0.10))}',
          ),
          MintSignalRow(
            label: l.affordabilityTotalEquity,
            value: 'CHF\u00a0${formatChf(result.fondsPropresTotal)}',
            valueColor: result.fondsPropresOk
                ? MintColors.success
                : MintColors.error,
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.3),
            height: 1,
          ),
          () {
            final hypothequeReelle =
                max(0.0, _prixAchat - result.fondsPropresTotal);
            final ltvPct = _prixAchat > 0
                ? (hypothequeReelle / _prixAchat * 100).toStringAsFixed(0)
                : '0';
            return MintSignalRow(
              label: l.affordabilityMortgagePercent(ltvPct),
              value: 'CHF\u00a0${formatChf(hypothequeReelle)}',
            );
          }(),
          MintSignalRow(
            label: l.affordabilityChargesRatio,
            value:
                '${(result.ratioCharges * 100).toStringAsFixed(1)}\u00a0%',
            valueColor: result.capaciteOk
                ? MintColors.success
                : MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSections(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.affordabilityExploreAlso,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm),
        CollapsibleSection(
          title: l.affordabilityRelatedAmortTitle,
          subtitle: l.affordabilityRelatedAmortSubtitle,
          icon: Icons.compare_arrows,
          child: _buildSectionCta(
              l.affordabilityRelatedSimulate, '/mortgage/amortization'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedSaronTitle,
          subtitle: l.affordabilityRelatedSaronSubtitle,
          icon: Icons.swap_horiz,
          child: _buildSectionCta(
              l.affordabilityRelatedCompare, '/mortgage/saron-vs-fixed'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedValeurTitle,
          subtitle: l.affordabilityRelatedValeurSubtitle,
          icon: Icons.home_work_outlined,
          child: _buildSectionCta(
              l.affordabilityRelatedCalculate, '/mortgage/imputed-rental'),
        ),
        CollapsibleSection(
          title: l.affordabilityRelatedEplTitle,
          subtitle: l.affordabilityRelatedEplSubtitle,
          icon: Icons.account_balance_outlined,
          child: _buildSectionCta(
              l.affordabilityRelatedSimulate, '/mortgage/epl-combined'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => context.push(route),
        child: Text(label),
      ),
    );
  }
}
