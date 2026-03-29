import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show RachatEchelonneSimulator, RachatEchelonneResult, RachatYearPlan;
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Ecran de simulation du rachat LPP echelonne vs bloc.
///
/// Permet de comparer l'economie fiscale entre un rachat en une fois
/// et un rachat reparti sur plusieurs annees.
/// Base legale : LPP art. 79b al. 3.
class RachatEchelonneScreen extends StatefulWidget {
  const RachatEchelonneScreen({super.key});

  @override
  State<RachatEchelonneScreen> createState() => _RachatEchelonneScreenState();
}

class _RachatEchelonneScreenState extends State<RachatEchelonneScreen>
    with SingleTickerProviderStateMixin {
  // --- Inputs ---
  double _avoirActuel = 200000;
  double _rachatMax = 80000;
  double _revenu = 120000;
  int _horizon = 3;

  // --- Fiscal situation ---
  String _canton = 'ZH';
  String _civilStatus = 'single';
  bool _manualTauxOverride = false;
  double _manualTaux = 0.32;

  // --- Animation ---
  late AnimationController _heroController;

  static const List<String> _cantonCodes = [
    'ZH', 'BE', 'LU', 'UR', 'SZ', 'OW', 'NW', 'GL', 'ZG', 'FR',
    'SO', 'BS', 'BL', 'SH', 'AR', 'AI', 'SG', 'GR', 'AG', 'TG',
    'TI', 'VD', 'VS', 'NE', 'GE', 'JU',
  ];

  static const Map<String, String> _cantonNames = {
    'ZH': 'Zurich', 'BE': 'Berne', 'LU': 'Lucerne', 'UR': 'Uri',
    'SZ': 'Schwyz', 'OW': 'Obwald', 'NW': 'Nidwald', 'GL': 'Glaris',
    'ZG': 'Zoug', 'FR': 'Fribourg', 'SO': 'Soleure', 'BS': 'Bâle-Ville',
    'BL': 'Bâle-Campagne', 'SH': 'Schaffhouse', 'AR': 'Appenzell RE',
    'AI': 'Appenzell RI', 'SG': 'Saint-Gall', 'GR': 'Grisons',
    'AG': 'Argovie', 'TG': 'Thurgovie', 'TI': 'Tessin', 'VD': 'Vaud',
    'VS': 'Valais', 'NE': 'Neuchâtel', 'GE': 'Genève', 'JU': 'Jura',
  };

  double get _autoTaux => TaxEstimatorService.estimateMarginalTaxRate(
        netMonthlyIncome: _revenu / 12,
        cantonCode: _canton,
        civilStatus: _civilStatus,
      );

  double get _effectiveTaux => _manualTauxOverride ? _manualTaux : _autoTaux;

  RachatEchelonneResult get _result => RachatEchelonneSimulator.compare(
        avoirActuel: _avoirActuel,
        rachatMax: _rachatMax,
        revenuImposable: _revenu,
        canton: _canton,
        civilStatus: _civilStatus,
        horizon: _horizon,
      );

  bool _prefilled = false;
  bool _hasUserInteracted = false;

  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map<String, dynamic>) {
          _seqRunId = extra['runId'] as String?;
          _seqStepId = extra['stepId'] as String?;
        }
      } catch (_) {}
      if (_seqRunId == null) {
        ReportPersistenceService.markSimulatorExplored('lpp_deep');
      }
    });
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      ScreenCompletionTracker.markCompletedWithReturn('rachat_echelonne',
        ScreenReturn.abandoned(
          route: '/rachat-lpp',
          runId: _seqRunId, stepId: _seqStepId,
          eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
        ));
      return;
    }

    final result = _result;
    ScreenCompletionTracker.markCompletedWithReturn('rachat_echelonne',
      ScreenReturn.completed(
        route: '/rachat-lpp',
        stepOutputs: {'economie_rachat': result.delta},
        runId: _seqRunId, stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled) {
      _prefilled = true;
      _prefillFromProfile();
    }
  }

  void _prefillFromProfile() {
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    final prev = profile.prevoyance;
    if (prev.avoirLppTotal != null && prev.avoirLppTotal! > 0) {
      _avoirActuel = prev.avoirLppTotal!;
    }
    if (prev.lacuneRachatRestante > 0) {
      _rachatMax = prev.lacuneRachatRestante;
    }
    final revenuBrut = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (revenuBrut > 0) {
      _revenu = revenuBrut;
    }
    if (profile.canton.isNotEmpty) {
      _canton = profile.canton.toUpperCase();
    }
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    _civilStatus = isMarried ? 'married' : 'single';
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    _hasUserInteracted = true;
    _heroController.forward(from: 0);
    setState(() {});
    _emitScreenReturn();
  }

  void _emitScreenReturn() {
    if (!_hasUserInteracted) return;
    if (_seqRunId != null) return;
    ScreenCompletionTracker.markCompletedWithReturn(
      'rachat_echelonne',
      ScreenReturn.completed(
        route: '/rachat-lpp',
        updatedFields: {
          'rachatOptimalAnnuel': _rachatMax / _horizon,
          'rachatEconomieFiscale': _result.delta,
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: 'pilier_3a',
      ),
    );
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            title: Text(
              l.rachatEchelonneTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildIntroCard(l)),
                const SizedBox(height: MintSpacing.md),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildHeroChiffreChoc(result, l)),
                const SizedBox(height: MintSpacing.lg),
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildLppSituationCard(l)),
                const SizedBox(height: MintSpacing.md),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildFiscalSituationCard(l)),
                const SizedBox(height: MintSpacing.md),
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildStrategieCard(l)),
                const SizedBox(height: MintSpacing.lg),
                _buildComparisonSection(result, l),
                const SizedBox(height: MintSpacing.lg),
                const EarlyRetirementSlider(
                  monthlyIncomeAt65: 4000,
                  scenarios: [
                    RetirementAgeScenario(age: 60, monthlyIncome: 3400, deltaPercent: -15, lifetimeDelta: -18000),
                    RetirementAgeScenario(age: 62, monthlyIncome: 3600, deltaPercent: -10, lifetimeDelta: -12000),
                    RetirementAgeScenario(age: 63, monthlyIncome: 3760, deltaPercent: -6, lifetimeDelta: -7200),
                    RetirementAgeScenario(age: 64, monthlyIncome: 3880, deltaPercent: -3, lifetimeDelta: -3600),
                    RetirementAgeScenario(age: 65, monthlyIncome: 4000, deltaPercent: 0),
                  ],
                ),
                const SizedBox(height: MintSpacing.lg),
                _buildWaterfallSection(l),
                const SizedBox(height: MintSpacing.lg),
                _buildTimelineSection(result, l),
                const SizedBox(height: MintSpacing.lg),
                _buildBlockageAlert(l),
                const SizedBox(height: MintSpacing.lg),
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      )),
    );
  }

  Widget _buildIntroCard(S l) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.rachatEchelonneIntroTitle, style: MintTextStyles.titleMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(l.rachatEchelonneIntroBody, style: MintTextStyles.bodyMedium().copyWith(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHeroChiffreChoc(RachatEchelonneResult result, S l) {
    final delta = result.delta;
    final showSavings = delta > 0;

    return MintResultHeroCard(
      eyebrow: 'Rachat LPP \u00e9chelonn\u00e9', // TODO: i18n
      primaryValue: showSavings
          ? 'CHF\u00a0${formatChf(delta)}'
          : 'CHF\u00a00',
      primaryLabel: showSavings
          ? l.rachatEchelonneSavingsCaption
          : l.rachatEchelonneBlocBetter,
      narrative: showSavings
          ? '\u00c9chelonner le rachat sur $_horizon ans '
            'r\u00e9duit ta charge fiscale totale.' // TODO: i18n
          : 'Dans ta situation, le rachat en bloc est plus avantageux.', // TODO: i18n
      accentColor: showSavings ? MintColors.success : MintColors.textSecondary,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  Widget _buildLppSituationCard(S l) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.account_balance, l.rachatEchelonneSituationLpp),
          const SizedBox(height: MintSpacing.lg),
          _buildSliderRow(label: l.rachatEchelonneAvoirActuel, value: _avoirActuel, min: 0, max: 500000, divisions: 100, format: 'CHF ${formatChf(_avoirActuel)}', onChanged: (v) { _avoirActuel = v; _onInputChanged(); }),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildSliderRow(label: l.rachatEchelonneRachatMax, value: _rachatMax, min: 0, max: 500000, divisions: 100, format: 'CHF ${formatChf(_rachatMax)}', onChanged: (v) { _rachatMax = v; _onInputChanged(); }),
        ],
      ),
    );
  }

  Widget _buildFiscalSituationCard(S l) {
    final displayRate = _effectiveTaux;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.receipt_long, l.rachatEchelonneSituationFiscale),
          const SizedBox(height: MintSpacing.lg),

          // Canton dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.rachatEchelonneCanton, style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
              Semantics(
                label: l.rachatEchelonneCanton,
                child: MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  radius: 8,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _canton,
                      isDense: true,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      items: _cantonCodes.map((code) {
                        return DropdownMenuItem(value: code, child: Text('$code — ${_cantonNames[code]}'));
                      }).toList(),
                      onChanged: (v) { if (v != null) { _canton = v; _onInputChanged(); } },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Civil status toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.rachatEchelonneEtatCivil, style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
              MintSurface(
                tone: MintSurfaceTone.porcelaine,
                radius: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip(l.rachatEchelonneCelibataire, 'single'),
                    _buildStatusChip(l.rachatEchelonneMarieE, 'married'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          _buildSliderRow(label: l.rachatEchelonneRevenuImposable, value: _revenu, min: 50000, max: 300000, divisions: 50, format: 'CHF ${formatChf(_revenu)}', onChanged: (v) { _revenu = v; _onInputChanged(); }),
          const SizedBox(height: MintSpacing.lg),

          // Auto-calculated taux marginal
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(MintSpacing.md),
            radius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(l.rachatEchelonneTauxMarginal, style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
                              const SizedBox(width: 6),
                              Semantics(
                                label: l.rachatEchelonneTauxMarginalSemantics,
                                button: true,
                                child: GestureDetector(
                                  onTap: () => _showTauxMarginalInfo(context, l),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: MintColors.primary.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.info_outline, size: 16, color: MintColors.primary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: MintSpacing.xs),
                          Text(
                            _manualTauxOverride ? l.rachatEchelonneTauxManuel : '$_canton, ${_civilStatus == 'married' ? l.rachatEchelonneMarieE.toLowerCase() : l.rachatEchelonneCelibataire.toLowerCase()}',
                            style: MintTextStyles.labelSmall(),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: MintColors.primary, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${(displayRate * 100).toStringAsFixed(1)}\u00a0%',
                        style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                if (!_manualTauxOverride)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: l.rachatEchelonneAjuster,
                      child: TextButton.icon(
                        onPressed: () { setState(() { _manualTauxOverride = true; _manualTaux = _autoTaux; }); },
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(l.rachatEchelonneAjuster),
                        style: TextButton.styleFrom(foregroundColor: MintColors.textMuted, textStyle: MintTextStyles.labelSmall(), padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      ),
                    ),
                  ),
                if (_manualTauxOverride) ...[
                  const SizedBox(height: MintSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: MintCompactSlider(value: _manualTaux, min: 0.10, max: 0.45, divisions: 35, onChanged: (v) { _manualTaux = v; _onInputChanged(); })),
                      Semantics(
                        button: true,
                        label: l.rachatEchelonneAuto,
                        child: TextButton(
                          onPressed: () { setState(() { _manualTauxOverride = false; }); _onInputChanged(); },
                          style: TextButton.styleFrom(foregroundColor: MintColors.info, textStyle: MintTextStyles.labelSmall(), padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                          child: Text(l.rachatEchelonneAuto),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final selected = _civilStatus == value;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); _civilStatus = value; _onInputChanged(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? MintColors.primary : MintColors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label, style: MintTextStyles.labelSmall(color: selected ? MintColors.white : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }

  void _showTauxMarginalInfo(BuildContext context, S l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: MintColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: MintSpacing.lg),
              Text(l.rachatEchelonneTauxMarginalTitle, style: MintTextStyles.headlineMedium().copyWith(fontSize: 18)),
              const SizedBox(height: MintSpacing.md),
              Text(l.rachatEchelonneTauxMarginalBody, style: MintTextStyles.bodyLarge().copyWith(fontSize: 15, color: MintColors.textPrimary, height: 1.6)),
              const SizedBox(height: MintSpacing.md),
              Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(color: MintColors.accentPastel, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20, color: MintColors.primary),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(child: Text(l.rachatEchelonneTauxMarginalTip, style: MintTextStyles.bodySmall(color: MintColors.greenForest).copyWith(fontStyle: FontStyle.italic, height: 1.4))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStrategieCard(S l) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.timeline, l.rachatEchelonneStrategie),
          const SizedBox(height: MintSpacing.lg),
          _buildSliderRow(label: l.rachatEchelonneHorizon, value: _horizon.toDouble(), min: 1, max: 15, divisions: 14, format: '$_horizon an${_horizon > 1 ? 's' : ''}', onChanged: (v) { _horizon = v.round(); _onInputChanged(); }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(MintSpacing.sm),
          decoration: BoxDecoration(color: MintColors.accentPastel, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: MintColors.primary),
        ),
        const SizedBox(width: MintSpacing.sm + 4),
        Text(label, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSliderRow({required String label, required double value, required double min, required double max, required int divisions, required String format, required ValueChanged<double> onChanged}) {
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

  Widget _buildComparisonSection(RachatEchelonneResult result, S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.rachatEchelonneComparaison, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(
          children: [
            Expanded(child: _buildComparisonCard(title: l.rachatEchelonneBlocTitle, subtitle: l.rachatEchelonneBlocSubtitle, amount: result.economieBlocTotal, color: MintColors.warning, isWinner: result.delta <= 0, adaptedLabel: l.rachatEchelonnePlusAdapte, savingsLabel: l.rachatEchelonneEconomieFiscale)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(child: _buildComparisonCard(title: '$_horizon ${l.staggered3aAns}', subtitle: l.rachatEchelonneEchelonneSubtitle, amount: result.economieEchelonneTotal, color: MintColors.success, isWinner: result.delta > 0, adaptedLabel: l.rachatEchelonnePlusAdapte, savingsLabel: l.rachatEchelonneEconomieFiscale)),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonCard({required String title, required String subtitle, required double amount, required Color color, required bool isWinner, required String adaptedLabel, required String savingsLabel}) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWinner)
            Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
              child: Text(adaptedLabel, style: MintTextStyles.micro(color: color).copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.normal, letterSpacing: 0.5, fontSize: 9)),
            ),
          Text(title, style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: MintSpacing.xs),
          Text(subtitle, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12)),
          const SizedBox(height: MintSpacing.sm + 4),
          Text('CHF ${formatChf(amount)}', style: MintTextStyles.displayMedium(color: color).copyWith(fontSize: 22)),
          const SizedBox(height: MintSpacing.xs),
          Text(savingsLabel, style: MintTextStyles.labelSmall()),
        ],
      ),
    );
  }

  Widget _buildWaterfallSection(S l) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.rachatEchelonneImpactTranche, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: MintSpacing.sm),
          Text(l.rachatEchelonneImpactBlocExplain, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, height: 1.4)),
          const SizedBox(height: MintSpacing.md),
          SizedBox(
            height: 240,
            child: CustomPaint(
              size: const Size(double.infinity, 240),
              painter: _WaterfallPainter(revenu: _revenu, rachatMax: _rachatMax, horizon: _horizon),
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(MintColors.warning, l.rachatEchelonneBloc),
              const SizedBox(width: MintSpacing.lg),
              _buildLegendDot(MintColors.success, l.rachatEchelonneEchelonne),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTimelineSection(RachatEchelonneResult result, S l) {
    final cumulativeRachat = <double>[];
    double cumul = 0;
    for (final year in result.yearlyPlan) { cumul += year.montantRachat; cumulativeRachat.add(cumul); }

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.rachatEchelonnePlanAnnuel, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: MintSpacing.md),
          for (int i = 0; i < result.yearlyPlan.length; i++)
            _buildTimelineNode(year: result.yearlyPlan[i], index: i, total: result.yearlyPlan.length, lacunePercent: _rachatMax > 0 ? (cumulativeRachat[i] / _rachatMax * 100).clamp(0.0, 100.0) : 0.0, l: l),
          const SizedBox(height: MintSpacing.sm),
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(MintSpacing.md),
            radius: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.rachatEchelonneTotal, style: MintTextStyles.titleMedium().copyWith(fontSize: 14)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${l.rachatEchelonneEconomieFiscale}\u00a0: CHF ${formatChf(result.economieEchelonneTotal)}', style: MintTextStyles.bodySmall(color: MintColors.greenDark).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('CHF ${formatChf(_rachatMax - result.economieEchelonneTotal)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({required RachatYearPlan year, required int index, required int total, required double lacunePercent, required S l}) {
    final isLast = index == total - 1;
    final progress = (index + 1) / total;
    final lineColor = Color.lerp(MintColors.primary, MintColors.success, progress)!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
                  child: Center(child: Text('${year.annee}', style: MintTextStyles.bodySmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w800, fontSize: 14))),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 3, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [lineColor, Color.lerp(MintColors.primary, MintColors.success, (index + 2) / total)!]), borderRadius: BorderRadius.circular(2)))),
              ],
            ),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: MintSurface(
              tone: MintSurfaceTone.porcelaine,
              padding: const EdgeInsets.all(14),
              radius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CHF ${formatChf(year.montantRachat)}', style: MintTextStyles.titleMedium().copyWith(fontSize: 16)),
                      Text('-CHF ${formatChf(year.economieFiscale)}', style: MintTextStyles.bodySmall(color: MintColors.greenDark).copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.rachatEchelonneRachat, style: MintTextStyles.labelSmall()),
                      Text(l.rachatEchelonneEconomieFiscale, style: MintTextStyles.labelSmall(color: MintColors.greenPastel)),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Row(
                    children: [
                      Text('CHF ${formatChf(year.coutNet)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: lineColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                        child: Text('${lacunePercent.toStringAsFixed(0)}\u00a0%', style: MintTextStyles.micro(color: lineColor).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal, fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockageAlert(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.redBg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: MintColors.redMedium, size: 22),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.rachatEchelonneBlockageTitle, style: MintTextStyles.bodySmall(color: MintColors.redDark).copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: MintSpacing.xs),
                Text(l.rachatEchelonneBlockageBody, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, color: MintColors.redMedium, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(color: MintColors.warningBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: MintColors.orangeRetroWarm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: Text(disclaimer, style: MintTextStyles.micro(color: MintColors.deepOrange).copyWith(height: 1.4))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Waterfall Painter — Progressive tax bracket visualization
// ═══════════════════════════════════════════════════════════════════════════

class _WaterfallPainter extends CustomPainter {
  final double revenu;
  final double rachatMax;
  final int horizon;

  _WaterfallPainter({required this.revenu, required this.rachatMax, required this.horizon});

  static const List<_TaxBracket> _brackets = [
    _TaxBracket(label: '0-50k', rate: 15, upperBound: 50000),
    _TaxBracket(label: '50-100k', rate: 25, upperBound: 100000),
    _TaxBracket(label: '100-150k', rate: 32, upperBound: 150000),
    _TaxBracket(label: '150k+', rate: 38, upperBound: 300000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const double chartLeft = 70;
    final double chartRight = size.width - 16;
    const double chartTop = 10;
    final double chartBottom = size.height - 40;
    final double chartWidth = chartRight - chartLeft;
    final double chartHeight = chartBottom - chartTop;

    final gridPaint = Paint()..color = MintColors.lightBorder..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < _brackets.length; i++) {
      final y = chartTop + (i / _brackets.length) * chartHeight;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      textPainter.text = TextSpan(
        text: '${_brackets[_brackets.length - 1 - i].label}\n${_brackets[_brackets.length - 1 - i].rate}%',
        style: const TextStyle(fontSize: 10, color: MintColors.textMuted, height: 1.3),
      );
      textPainter.layout(maxWidth: 60);
      textPainter.paint(canvas, Offset(4, y + 2));
    }
    canvas.drawLine(Offset(chartLeft, chartBottom), Offset(chartRight, chartBottom), gridPaint);

    final blocDeduction = rachatMax;
    final echelonneDeduction = rachatMax / horizon;
    final groupWidth = chartWidth / 2;
    final barWidth = groupWidth * 0.5;
    final blocX = chartLeft + groupWidth * 0.25;
    final echelX = chartLeft + groupWidth + groupWidth * 0.25;

    _drawDeductionBar(canvas: canvas, x: blocX, width: barWidth, deduction: blocDeduction, chartTop: chartTop, chartBottom: chartBottom, color: MintColors.warning);
    _drawDeductionBar(canvas: canvas, x: echelX, width: barWidth, deduction: echelonneDeduction, chartTop: chartTop, chartBottom: chartBottom, color: MintColors.success);

    textPainter.text = const TextSpan(text: 'Bloc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MintColors.textSecondary));
    textPainter.layout();
    textPainter.paint(canvas, Offset(blocX + barWidth / 2 - textPainter.width / 2, chartBottom + 8));

    final echelLabel = 'x$horizon';
    textPainter.text = TextSpan(text: echelLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MintColors.textSecondary));
    textPainter.layout();
    textPainter.paint(canvas, Offset(echelX + barWidth / 2 - textPainter.width / 2, chartBottom + 8));

    final blocBarHeight = _getBarHeight(blocDeduction, chartHeight);
    textPainter.text = TextSpan(text: 'CHF ${_formatShort(blocDeduction)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.primary));
    textPainter.layout();
    textPainter.paint(canvas, Offset(blocX + barWidth / 2 - textPainter.width / 2, (chartBottom - blocBarHeight - 14).clamp(0.0, chartBottom)));

    final echelBarHeight = _getBarHeight(echelonneDeduction, chartHeight);
    textPainter.text = TextSpan(text: 'CHF ${_formatShort(echelonneDeduction)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.primary));
    textPainter.layout();
    textPainter.paint(canvas, Offset(echelX + barWidth / 2 - textPainter.width / 2, (chartBottom - echelBarHeight - 14).clamp(0.0, chartBottom)));
  }

  double _getBarHeight(double deduction, double chartHeight) {
    const maxDeduction = 500000.0;
    return (deduction / maxDeduction * chartHeight).clamp(8.0, chartHeight);
  }

  void _drawDeductionBar({required Canvas canvas, required double x, required double width, required double deduction, required double chartTop, required double chartBottom, required Color color}) {
    final chartHeight = chartBottom - chartTop;
    final barHeight = _getBarHeight(deduction, chartHeight);
    final barRect = RRect.fromRectAndRadius(Rect.fromLTWH(x, chartBottom - barHeight, width, barHeight), const Radius.circular(4));
    final paint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withAlpha(160)]).createShader(barRect.outerRect);
    canvas.drawRRect(barRect, paint);
  }

  String _formatShort(double amount) {
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) {
    return oldDelegate.revenu != revenu || oldDelegate.rachatMax != rachatMax || oldDelegate.horizon != horizon;
  }
}

class _TaxBracket {
  final String label;
  final int rate;
  final double upperBound;
  const _TaxBracket({required this.label, required this.rate, required this.upperBound});
}
