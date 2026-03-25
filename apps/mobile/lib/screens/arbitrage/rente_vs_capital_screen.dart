import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/precision/field_help_tooltip.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Rente vs Capital arbitrage screen — the "a-ha" moment.
///
/// 4-bloc layout for neophytes:
///   A. Accroche (chiffre-choc + hero CHF/mois + micro-légendes)
///   B. Explorer (slider espérance de vie + trajectory chart fused)
///   C. Comprendre (3 educational before/after cards)
///   D. Affiner (hypotheses + impact cards + tornado in ExpansionTile)
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu". No banned terms.
class RenteVsCapitalScreen extends StatefulWidget {
  const RenteVsCapitalScreen({super.key});

  @override
  State<RenteVsCapitalScreen> createState() => _RenteVsCapitalScreenState();
}

enum _InputMode { estimate, certificate }

class _RenteVsCapitalScreenState extends State<RenteVsCapitalScreen> {
  // ── Input mode ──
  _InputMode _inputMode = _InputMode.estimate;

  // ── Estimate mode controllers ──
  final _ageCtrl = TextEditingController(text: '50');
  final _ageRetraiteSlider = ValueNotifier<double>(avsAgeReferenceHomme.toDouble());
  final _salaryCtrl = TextEditingController(text: '100000');
  final _lppTotalCtrl = TextEditingController(text: '350000');

  // ── Certificate mode controllers ──
  final _capitalObligCtrl = TextEditingController(text: '500000');
  final _capitalSurobCtrl = TextEditingController(text: '150000');
  final _renteCtrl = TextEditingController(text: '37000');
  final _tcObligCtrl = TextEditingController(text: '6.8');
  final _tcSurobCtrl = TextEditingController(text: '5.0');

  // ── Shared inputs ──
  String _canton = 'VD';
  bool _isMarried = false;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement': 3.0,
    'swr': 4.0,
    'inflation': 2.0,
  };

  // ── Life expectancy slider ──
  double _lifeExpectancy = 85;

  bool _isLoading = false;
  bool _hasError = false;
  int _requestCounter = 0;
  ArbitrageResult? _result;

  // ── CoachProfile auto-fill ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;

  // ── New fields ──
  double? _avsRenteMensuelle;
  final _rachatAnnuelCtrl = TextEditingController(text: '0');
  final _rachatMaxCtrl = TextEditingController(text: '0');
  bool _hasEpl = false;
  final _eplAmountCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFill) {
      _didAutoFill = true;
      _autoFillFromProfile();
    }
  }

  void _autoFillFromProfile() {
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    final sources = profile.dataSources;
    bool changed = false;
    bool hasEstimates = false;

    void apply(TextEditingController ctrl, String? value, String field) {
      if (value != null && value.isNotEmpty) {
        ctrl.text = value;
        changed = true;
        final src = sources[field];
        if (src != null && src != ProfileDataSource.certificate) {
          hasEstimates = true;
        }
      }
    }

    // Age from birth year
    final currentYear = DateTime.now().year;
    final age = currentYear - profile.birthYear;
    apply(_ageCtrl, age.toString(), 'age');

    // Gross annual salary
    final salaryAnnuel = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (salaryAnnuel > 0) {
      apply(_salaryCtrl, salaryAnnuel.round().toString(), 'salaire_brut');
    }

    // LPP balance
    final lpp = profile.prevoyance.avoirLppTotal;
    if (lpp != null && lpp > 0) {
      apply(_lppTotalCtrl, lpp.round().toString(), 'prevoyance.avoirLppTotal');
    }

    // Canton
    final canton = profile.canton;
    if (cantonFullNames.containsKey(canton)) {
      _canton = canton;
      changed = true;
    }

    // Married
    final married = profile.etatCivil == CoachCivilStatus.marie;
    _isMarried = married;

    // LPP oblig/surob split — use direct values if available, else 70/30 will be used
    final lppOblig = profile.prevoyance.avoirLppObligatoire;
    final lppSurob = profile.prevoyance.avoirLppSurobligatoire;
    if (lppOblig != null && lppOblig > 0) {
      apply(_capitalObligCtrl, lppOblig.round().toString(), 'prevoyance.avoirLppObligatoire');
    }
    if (lppSurob != null && lppSurob > 0) {
      apply(_capitalSurobCtrl, lppSurob.round().toString(), 'prevoyance.avoirLppSurobligatoire');
    }

    // Conversion rates from certificate
    final tcProfile = profile.prevoyance.tauxConversion;
    if (tcProfile > 0) {
      apply(_tcObligCtrl, (tcProfile * 100).toStringAsFixed(1), 'prevoyance.tauxConversion');
    }
    final tcSurobProfile = profile.prevoyance.tauxConversionSuroblig;
    if (tcSurobProfile != null && tcSurobProfile > 0) {
      apply(_tcSurobCtrl, (tcSurobProfile * 100).toStringAsFixed(1), 'prevoyance.tauxConversionSuroblig');
    }

    // AVS estimated monthly rente — used for display only (not engine input)
    final avsRente = profile.prevoyance.renteAVSEstimeeMensuelle;
    if (avsRente != null && avsRente > 0) {
      _avsRenteMensuelle = avsRente;
      changed = true;
    }

    // Retirement age from profile if available
    final retirementAge = profile.targetRetirementAge;
    if (retirementAge != null && retirementAge >= 58 && retirementAge <= 70) {
      _ageRetraiteSlider.value = retirementAge.toDouble();
      changed = true;
    }

    // Rachat potential from profile
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 0) {
      _rachatMaxCtrl.text = lacune.round().toString();
      changed = true;
    }

    if (changed) {
      _dataSources = Map.from(sources);
      _hasEstimatedValues = hasEstimates;
      _recalculate();
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _salaryCtrl.dispose();
    _lppTotalCtrl.dispose();
    _capitalObligCtrl.dispose();
    _capitalSurobCtrl.dispose();
    _renteCtrl.dispose();
    _tcObligCtrl.dispose();
    _tcSurobCtrl.dispose();
    _ageRetraiteSlider.dispose();
    _rachatAnnuelCtrl.dispose();
    _rachatMaxCtrl.dispose();
    _eplAmountCtrl.dispose();
    super.dispose();
  }

  /// Compute estimate-mode inputs from the LPP total entered by the user.
  void _recalculate() {
    _recalculateAsync();
  }

  Future<void> _recalculateAsync() async {
    final requestId = ++_requestCounter;
    final ageRetraite = _ageRetraiteSlider.value.round();

    double capitalOblig, capitalSurob, renteAnnuelle;
    double tcOblig, tcSurob;
    int? currentAge;
    double? salary;

    if (_inputMode == _InputMode.estimate) {
      // Estimate mode: use LPP total with 70/30 split as starting point
      final lppTotal =
          double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 350000;
      capitalOblig = lppTotal * 0.7;
      capitalSurob = lppTotal * 0.3;
      tcOblig = lppTauxConversionMin / 100;
      tcSurob = 0.05;
      renteAnnuelle = capitalOblig * tcOblig;
      currentAge = int.tryParse(_ageCtrl.text);
      salary = double.tryParse(_salaryCtrl.text.replaceAll("'", ''));
    } else {
      // Certificate mode: direct values
      capitalOblig =
          double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 500000;
      capitalSurob =
          double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 150000;
      renteAnnuelle =
          double.tryParse(_renteCtrl.text.replaceAll("'", '')) ?? 37000;
      tcOblig = (double.tryParse(_tcObligCtrl.text) ?? 6.8) / 100;
      tcSurob = (double.tryParse(_tcSurobCtrl.text) ?? 5.0) / 100;
      currentAge = null;
      salary = null;
    }

    // Rachat LPP: add future value of annual buybacks to current LPP
    // FV annuity = annualBuyback × ((1+r)^n - 1) / r  (LPP growth rate 1.25%)
    final rachatAnnuel = double.tryParse(_rachatAnnuelCtrl.text.replaceAll("'", '')) ?? 0;
    if (rachatAnnuel > 0 && currentAge != null) {
      final yearsToRetirement = math.max(0, _ageRetraite - currentAge);
      const lppReturn = 0.0125;
      final fvRachat = yearsToRetirement > 0
          ? rachatAnnuel * (math.pow(1 + lppReturn, yearsToRetirement) - 1) / lppReturn
          : rachatAnnuel;
      capitalOblig += fvRachat * 0.7;
      capitalSurob += fvRachat * 0.3;
    }

    // EPL: withdrawal for real estate reduces capital
    final eplAmount = _hasEpl
        ? (double.tryParse(_eplAmountCtrl.text.replaceAll("'", '')) ?? 0)
        : 0.0;
    if (eplAmount > 0) {
      // EPL reduces proportionally from oblig/surob
      final ratio = capitalOblig / math.max(1, capitalOblig + capitalSurob);
      capitalOblig = math.max(0, capitalOblig - eplAmount * ratio);
      capitalSurob = math.max(0, capitalSurob - eplAmount * (1 - ratio));
    }

    final capitalTotal = capitalOblig + capitalSurob;
    final horizon = math.max(30, (_lifeExpectancy - ageRetraite).round());

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await ApiService.compareRenteVsCapital(
        capitalLppTotal: capitalTotal,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: capitalSurob,
        renteAnnuelleProposee: renteAnnuelle,
        tauxConversionObligatoire: tcOblig,
        tauxConversionSurobligatoire: tcSurob,
        canton: _canton,
        ageRetraite: ageRetraite,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: horizon,
        isMarried: _isMarried,
      );
      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = result);
      _emitScreenReturn(result);
      return;
    } catch (_) {
      try {
        final fallback = ArbitrageEngine.compareRenteVsCapital(
          capitalLppTotal: capitalTotal,
          capitalObligatoire: capitalOblig,
          capitalSurobligatoire: capitalSurob,
          renteAnnuelleProposee: renteAnnuelle,
          tauxConversionObligatoire: tcOblig,
          tauxConversionSurobligatoire: tcSurob,
          canton: _canton,
          ageRetraite: ageRetraite,
          tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
          rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
          inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
          horizon: horizon,
          isMarried: _isMarried,
          dataSources: _dataSources,
          currentAge: currentAge,
          grossAnnualSalary: salary,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() => _result = fallback);
        _emitScreenReturn(fallback);
      } catch (_) {
        if (!mounted || requestId != _requestCounter) return;
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted && requestId == _requestCounter) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _emitScreenReturn(ArbitrageResult result) {
    final mode = _inputMode == _InputMode.certificate
        ? 'certificate'
        : 'estimate';
    final screenReturn = ScreenReturn.completed(
      route: '/rente-vs-capital',
      updatedFields: {'retirementMode': mode},
      confidenceDelta: 0.02,
    );
    ScreenCompletionTracker.markCompletedWithReturn(
      'rente_vs_capital',
      screenReturn,
    );
  }

  int get _ageRetraite => _ageRetraiteSlider.value.round();

  List<TrajectoireOption> _optionsAsAgeTrajectories(
    List<TrajectoireOption> options,
  ) {
    return options.map((option) {
      final mappedTrajectory = <YearlySnapshot>[];
      for (int i = 0; i < option.trajectory.length; i++) {
        final snap = option.trajectory[i];
        mappedTrajectory.add(
          YearlySnapshot(
            year: _ageRetraite + i,
            netPatrimony: snap.netPatrimony,
            annualCashflow: snap.annualCashflow,
            cumulativeTaxDelta: snap.cumulativeTaxDelta,
          ),
        );
      }
      return TrajectoireOption(
        id: option.id,
        label: option.label,
        trajectory: mappedTrajectory,
        terminalValue: option.terminalValue,
        cumulativeTaxImpact: option.cumulativeTaxImpact,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD — 4 BLOCS
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final chartOptions = _result == null
        ? const <TrajectoireOption>[]
        : _optionsAsAgeTrajectories(_result!.options);

    return Scaffold(
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          // ── SliverAppBar (white standard — Simulator screen) ──
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            surfaceTintColor: MintColors.white,
            title: Text(
              S.of(context)!.renteVsCapitalAppBarTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero intro (why this matters) ──
                _buildHeroIntro(),
                const SizedBox(height: MintSpacing.lg),

                // ── Inputs (2 modes) ──
                _buildInputSection(),
                const SizedBox(height: MintSpacing.lg),

                if (_isLoading && _result == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: MintSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_hasError && _result == null)
                  Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                        const SizedBox(width: MintSpacing.sm),
                        Expanded(child: Text(
                          S.of(context)!.renteVsCapitalErrorRetry,
                          style: MintTextStyles.bodySmall(color: MintColors.error),
                        )),
                      ],
                    ),
                  ),

                if (_result != null) ...[
                  // ── Confidence banner ──
                  IndicatifBanner(
                    confidenceScore: _result!.confidenceScore,
                    topEnrichmentCategory: 'lpp',
                  ),

                  if (_hasEstimatedValues && _inputMode == _InputMode.estimate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                      child: SmartDefaultIndicator(
                        source: S.of(context)!.renteVsCapitalProfileAutoFill,
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),

                  // ══════════════════════════════════════════════
                  //  BLOC A — ACCROCHE
                  //  Chiffre-choc + Hero CHF/mois + micro-légendes
                  // ══════════════════════════════════════════════
                  _buildChiffreChocAccroche(),
                  const SizedBox(height: MintSpacing.md),
                  _buildHeroMonthly(),
                  const SizedBox(height: MintSpacing.lg),

                  // ══════════════════════════════════════════════
                  //  BLOC C — COMPRENDRE
                  //  3 cartes éducatives (fiscalité, inflation, transmission)
                  // ══════════════════════════════════════════════
                  _buildEducationalCards(),
                  const SizedBox(height: MintSpacing.lg),

                  // ══════════════════════════════════════════════
                  //  BLOC B — EXPLORER
                  //  Slider espérance + chart trajectoire (fused)
                  // ══════════════════════════════════════════════
                  _buildExplorerBloc(chartOptions),
                  const SizedBox(height: MintSpacing.lg),

                  // ══════════════════════════════════════════════
                  //  BLOC D — AFFINER
                  //  Hypothèses + impact cards + tornado (ExpansionTile)
                  // ══════════════════════════════════════════════
                  _buildAffinerBloc(),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Disclaimer ──
                  _buildDisclaimerCard(),
                  const SizedBox(height: MintSpacing.xl),
                ],
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HERO INTRO — pourquoi tu devrais t'en soucier
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroIntro() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.renteVsCapitalIntro,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          _introPuce(
            S.of(context)!.renteVsCapitalRenteLabel,
            S.of(context)!.renteVsCapitalRenteExplanation,
          ),
          _introPuce(
            S.of(context)!.renteVsCapitalCapitalLabel,
            S.of(context)!.renteVsCapitalCapitalExplanation,
          ),
          _introPuce(
            S.of(context)!.renteVsCapitalMixteLabel,
            S.of(context)!.renteVsCapitalMixteExplanation,
          ),
        ],
      ),
    );
  }

  Widget _introPuce(String term, String explanation) {
    return Padding(
      padding: const EdgeInsets.only(top: MintSpacing.xs),
      child: Semantics(
        label: term,
        button: true,
        child: InkWell(
        onTap: () => _showExplanation(term, explanation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('  \u2022  ', style: TextStyle(color: MintColors.info)),
              Text(
                term,
                style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: MintColors.info.withAlpha(60),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showExplanation(String term, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Text(
              term,
              style: MintTextStyles.headlineMedium(color: MintColors.primary).copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              text,
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
                fontSize: 15, height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  INPUTS — 2 modes via SegmentedButton
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInputSection() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector
          Semantics(
            label: S.of(context)!.renteVsCapitalEstimateMode,
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_InputMode>(
                segments: [
                  ButtonSegment(
                    value: _InputMode.estimate,
                    label: Text(S.of(context)!.renteVsCapitalEstimateMode),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                  ),
                  ButtonSegment(
                    value: _InputMode.certificate,
                    label: Text(S.of(context)!.renteVsCapitalCertificateMode),
                    icon: const Icon(Icons.description_outlined, size: 16),
                  ),
                ],
                selected: {_inputMode},
                onSelectionChanged: (v) {
                  setState(() => _inputMode = v.first);
                  _recalculate();
                },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          if (_inputMode == _InputMode.estimate) ...[
            _buildLabeledField(
              controller: _ageCtrl,
              label: S.of(context)!.renteVsCapitalAge,
              fieldName: 'age',
            ),
            const SizedBox(height: MintSpacing.sm),
            // Retirement age slider
            _buildRetirementAgeSlider(),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _salaryCtrl,
              label: S.of(context)!.renteVsCapitalSalary,
              fieldName: 'salaire_brut',
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _lppTotalCtrl,
              label: S.of(context)!.renteVsCapitalLppTotal,
              fieldName: 'lpp_total',
            ),
            const SizedBox(height: MintSpacing.sm),
            // Rachat LPP
            _buildRachatSection(),
            const SizedBox(height: MintSpacing.sm),
            // EPL
            _buildEplSection(),
            // Auto-computed readout
            if (_result != null && _result!.isProjected) ...[
              const SizedBox(height: MintSpacing.sm),
              MintSurface(
                tone: MintSurfaceTone.porcelaine,
                padding: const EdgeInsets.all(MintSpacing.sm),
                radius: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.renteVsCapitalEstimatedCapital(
                        _ageRetraite,
                        formatChf(_result!.capitalProjecte),
                      ),
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.renteVsCapitalEstimatedRente(
                        formatChf(_result!.renteNetMensuelle * 12),
                      ),
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Row(
                      children: [
                        SmartDefaultIndicator(
                          source: S.of(context)!.renteVsCapitalProjectionSource,
                          confidence: _result!.confidenceScore / 100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // Certificate mode
            _buildLabeledField(
              controller: _capitalObligCtrl,
              label: S.of(context)!.renteVsCapitalLppOblig,
              fieldName: 'lpp_obligatoire',
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _capitalSurobCtrl,
              label: S.of(context)!.renteVsCapitalLppSurob,
              fieldName: 'lpp_surobligatoire',
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _renteCtrl,
              label: S.of(context)!.renteVsCapitalRenteProposed,
              fieldName: 'rente_projetee',
            ),
            const SizedBox(height: MintSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcObligCtrl,
                    label: S.of(context)!.renteVsCapitalTcOblig,
                    isPercent: true,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcSurobCtrl,
                    label: S.of(context)!.renteVsCapitalTcSurob,
                    isPercent: true,
                  ),
                ),
              ],
            ),
            // Confidence gratification
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: MintSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: MintColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MintColors.success.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 20, color: MintColors.success),
                      const SizedBox(width: MintSpacing.sm),
                      Expanded(
                        child: Text(
                          S.of(context)!.renteVsCapitalMaxPrecision,
                          style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: MintSpacing.md),
          // Canton + Married
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context)!.renteVsCapitalCanton, style: _labelStyle),
                    const SizedBox(height: MintSpacing.xs),
                    MintSurface(
                      tone: MintSurfaceTone.porcelaine,
                      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                      radius: 12,
                      child: DropdownButton<String>(
                        value: _canton,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: sortedCantonCodes.map((code) {
                          final name = cantonFullNames[code] ?? code;
                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name',
                                style: MintTextStyles.bodyMedium()),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) { _canton = v; _recalculate(); }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MintSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context)!.renteVsCapitalMarried, style: _labelStyle),
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    label: S.of(context)!.renteVsCapitalMarried,
                    toggled: _isMarried,
                    child: Switch(
                      value: _isMarried,
                      activeTrackColor: MintColors.primary,
                      onChanged: (v) { _isMarried = v; _recalculate(); },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementAgeSlider() {
    final l = S.of(context)!;
    // Retirement age chips: 58 to 70.
    const ageOptions = [58, 60, 62, 63, 64, 65, 66, 67, 70];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.renteVsCapitalRetirementAgeChips, style: _labelStyle),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.xs,
          runSpacing: MintSpacing.xs,
          children: ageOptions.map((age) {
            final isSelected = _ageRetraiteSlider.value.round() == age;
            return ChoiceChip(
              label: Text('$age'),
              selected: isSelected,
              onSelected: (_) {
                _ageRetraiteSlider.value = age.toDouble();
                _recalculate();
              },
              selectedColor: MintColors.primary.withValues(alpha: 0.15),
              backgroundColor: MintColors.surface,
              labelStyle: MintTextStyles.bodySmall(
                color: isSelected ? MintColors.primary : MintColors.textPrimary,
              ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
              side: BorderSide(
                color: isSelected ? MintColors.primary : MintColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? fieldName,
    bool isPercent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: _labelStyle)),
            if (fieldName != null)
              FieldHelpTooltip(fieldName: fieldName),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: isPercent
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: isPercent
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: 14,
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BLOC A — ACCROCHE
  // ═══════════════════════════════════════════════════════════════

  /// Chiffre-choc en haut — pourquoi cette decision compte.
  Widget _buildChiffreChocAccroche() {
    final r = _result!;
    // Build a punchy one-liner from the engine's chiffreChoc
    final taxDelta = (r.impotCumulRente - r.impotRetraitCapital).abs();
    final epuiseAge = r.capitalEpuiseAge;

    // Dynamic accroche that adapts to the user's numbers
    String accroche;
    if (taxDelta > 10000 && epuiseAge != null) {
      accroche = S.of(context)!.renteVsCapitalAccrocheTaxEpuise(
        formatChf(taxDelta), epuiseAge,
      );
    } else if (taxDelta > 10000) {
      accroche = S.of(context)!.renteVsCapitalAccrocheTax(
        formatChf(taxDelta),
      );
    } else if (epuiseAge != null) {
      accroche = S.of(context)!.renteVsCapitalAccrocheEpuise(epuiseAge);
    } else {
      accroche = r.chiffreChoc;
    }

    return Semantics(
      label: accroche,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.info.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MintColors.info.withAlpha(30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt_rounded, size: 20, color: MintColors.info),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                accroche,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero CHF/mois — side-by-side with micro-légendes.
  Widget _buildHeroMonthly() {
    final r = _result!;
    final renteMois = r.renteNetMensuelle;
    final capitalMois = r.capitalRetraitMensuel;
    final delta = (capitalMois - renteMois).abs();
    final capitalDuration = r.capitalEpuiseAge != null
        ? '~${r.capitalEpuiseAge! - _ageRetraite} ans'
        : '30+ ans';
    final swr = (_hypotheses['swr'] ?? 4.0);
    final rendement = (_hypotheses['rendement'] ?? 3.0);

    final higherIsCapital = capitalMois > renteMois;
    final synthese = higherIsCapital
        ? S.of(context)!.renteVsCapitalSyntheseCapitalHigher(formatChf(delta))
        : S.of(context)!.renteVsCapitalSyntheseRenteHigher(formatChf(delta));

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      elevated: true,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Rente column ──
              Expanded(
                child: Column(
                  children: [
                    Text(S.of(context)!.renteVsCapitalHeroRente,
                      style: MintTextStyles.labelSmall(color: MintColors.retirementAvs).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      formatChf(renteMois),
                      style: MintTextStyles.displayMedium().copyWith(
                        fontSize: 26,
                      ),
                    ),
                    Text(S.of(context)!.renteVsCapitalPerMonth,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementAvs.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(S.of(context)!.renteVsCapitalForLife,
                        style: MintTextStyles.labelSmall(color: MintColors.retirementAvs).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    // ── Micro-légende ──
                    Text(
                      S.of(context)!.renteVsCapitalMicroRente,
                      style: MintTextStyles.micro(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Divider
              Container(width: 1, height: 100, color: MintColors.lightBorder),
              // ── Capital column ──
              Expanded(
                child: Column(
                  children: [
                    Text(S.of(context)!.renteVsCapitalHeroCapital,
                      style: MintTextStyles.labelSmall(color: MintColors.retirementLpp).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      formatChf(capitalMois),
                      style: MintTextStyles.displayMedium().copyWith(
                        fontSize: 26,
                      ),
                    ),
                    Text(S.of(context)!.renteVsCapitalPerMonth,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementLpp.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(S.of(context)!.renteVsCapitalDuration(capitalDuration),
                        style: MintTextStyles.labelSmall(color: MintColors.retirementLpp).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    // ── Micro-légende ──
                    Text(
                      S.of(context)!.renteVsCapitalMicroCapital(
                        swr.toStringAsFixed(0),
                        rendement.toStringAsFixed(0),
                      ),
                      style: MintTextStyles.micro(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(MintSpacing.sm),
            radius: 10,
            child: Text(
              synthese,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          // AVS complement if available
          if (_avsRenteMensuelle != null && _avsRenteMensuelle! > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            MintSurface(
              tone: MintSurfaceTone.porcelaine,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              radius: 10,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, size: 16, color: MintColors.textMuted),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(text: S.of(context)!.renteVsCapitalAvsEstimated),
                          TextSpan(
                            text: S.of(context)!.renteVsCapitalAvsAmount(
                              formatChf(_avsRenteMensuelle!),
                            ),
                            style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(
                              fontSize: 12, fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: S.of(context)!.renteVsCapitalAvsSupplementary),
                        ],
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

  // ═══════════════════════════════════════════════════════════════
  //  BLOC B — EXPLORER (slider + chart fused)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildExplorerBloc(List<TrajectoireOption> chartOptions) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Life expectancy: chips ──
          MintEntrance(child: Text(
            S.of(context)!.renteVsCapitalLifeExpectancyChips,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          )),
          const SizedBox(height: MintSpacing.sm),
          MintEntrance(delay: const Duration(milliseconds: 100), child: Wrap(
            spacing: MintSpacing.xs,
            runSpacing: MintSpacing.xs,
            children: [75, 80, 85, 90, 95, 100].map((age) {
              final isSelected = _lifeExpectancy.round() == age;
              return ChoiceChip(
                label: Text(S.of(context)!.renteVsCapitalAgeYears(age)),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _lifeExpectancy = age.toDouble());
                  _recalculate();
                },
                selectedColor: MintColors.primary.withValues(alpha: 0.15),
                backgroundColor: MintColors.surface,
                labelStyle: MintTextStyles.bodySmall(
                  color: isSelected ? MintColors.primary : MintColors.textPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                side: BorderSide(
                  color: isSelected ? MintColors.primary : MintColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          )),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildDeltaAtAge(_lifeExpectancy.round())),
          const SizedBox(height: MintSpacing.xs),
          MintEntrance(delay: const Duration(milliseconds: 300), child: Text(
            S.of(context)!.renteVsCapitalLifeExpectancyRef,
            style: MintTextStyles.labelSmall(),
          )),

          const SizedBox(height: MintSpacing.lg),

          // ── Chart: capital restant vs revenus cumules de la rente ──
          MintEntrance(delay: const Duration(milliseconds: 400), child: Text(
            S.of(context)!.renteVsCapitalChartTitle,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          )),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalChartSubtitle,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
              fontSize: 12,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          TrajectoryComparisonChart(
            options: chartOptions,
            breakevenYear: _result!.breakevenYear,
            selectedAxisLabel: S.of(context)!.renteVsCapitalChartAxisLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaAtAge(int age) {
    if (_result == null) return const SizedBox.shrink();
    final yearIndex = age - _ageRetraite;
    if (yearIndex < 0) return const SizedBox.shrink();

    final renteOption = _result!.options.firstWhere(
      (o) => o.id == 'full_rente', orElse: () => _result!.options.first,
    );
    final capitalOption = _result!.options.firstWhere(
      (o) => o.id == 'full_capital', orElse: () => _result!.options.last,
    );

    if (yearIndex >= renteOption.trajectory.length ||
        yearIndex >= capitalOption.trajectory.length) {
      // Should not happen now that horizon is dynamic, but safety fallback
      return Text(
        S.of(context)!.renteVsCapitalBeyondHorizon(age),
        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
      );
    }

    final renteVal = renteOption.trajectory[yearIndex].netPatrimony;
    final capitalVal = capitalOption.trajectory[yearIndex].netPatrimony;
    final delta = capitalVal - renteVal;
    final winner = delta > 0
        ? S.of(context)!.renteVsCapitalCapitalLabel
        : S.of(context)!.renteVsCapitalRenteLabel;
    final winnerColor = delta > 0 ? MintColors.retirementLpp : MintColors.retirementAvs;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.sm),
      decoration: BoxDecoration(
        color: winnerColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            delta > 0 ? Icons.trending_up : Icons.trending_down,
            color: winnerColor, size: 20,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAtAge(age),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                TextSpan(
                  text: '$winner = +${formatChf(delta.abs())} ',
                  style: MintTextStyles.bodySmall(color: winnerColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAdvance,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BLOC C — COMPRENDRE (3 educational before/after cards)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEducationalCards() {
    final r = _result!;
    final inflation = (_hypotheses['inflation'] ?? 2.0) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalEducationalTitle,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 1: Fiscalite
        _educationalCard(
          icon: Icons.receipt_long,
          iconColor: MintColors.pillarLpp,
          title: S.of(context)!.renteVsCapitalFiscalTitle,
          leftTitle: S.of(context)!.renteVsCapitalRenteLabel,
          leftSubtitle: S.of(context)!.renteVsCapitalFiscalLeftSubtitle,
          leftValue: '~${formatChf(r.impotCumulRente)}',
          leftDetail: S.of(context)!.renteVsCapitalFiscalOver30years,
          rightTitle: S.of(context)!.renteVsCapitalCapitalLabel,
          rightSubtitle: S.of(context)!.renteVsCapitalFiscalRightSubtitle,
          rightValue: '~${formatChf(r.impotRetraitCapital)}',
          rightDetail: S.of(context)!.renteVsCapitalFiscalAtRetrait,
          bottomText: r.impotCumulRente > r.impotRetraitCapital
              ? S.of(context)!.renteVsCapitalFiscalCapitalSaves(
                  formatChf(r.impotCumulRente - r.impotRetraitCapital),
                )
              : S.of(context)!.renteVsCapitalFiscalRenteSaves(
                  formatChf(r.impotRetraitCapital - r.impotCumulRente),
                ),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 2: Inflation
        _educationalCard(
          icon: Icons.trending_down,
          iconColor: MintColors.warning,
          title: S.of(context)!.renteVsCapitalInflationTitle,
          leftTitle: S.of(context)!.renteVsCapitalInflationToday,
          leftSubtitle: '',
          leftValue: formatChf(r.renteNetMensuelle),
          leftDetail: S.of(context)!.renteVsCapitalPerMonth,
          rightTitle: S.of(context)!.renteVsCapitalInflationIn20Years,
          rightSubtitle: S.of(context)!.renteVsCapitalInflationPurchasingPower,
          rightValue: formatChf(r.renteReelleAn20 / 12),
          rightDetail: S.of(context)!.renteVsCapitalPerMonth,
          bottomText: S.of(context)!.renteVsCapitalInflationBottomText(
            ((1 - 1 / math.pow(1 + inflation, 20)) * 100).round(),
          ),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 3: Transmission
        _educationalCard(
          icon: Icons.family_restroom,
          iconColor: MintColors.primary,
          title: S.of(context)!.renteVsCapitalTransmissionTitle,
          leftTitle: S.of(context)!.renteVsCapitalRenteLabel,
          leftSubtitle: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftMarried
              : S.of(context)!.renteVsCapitalTransmissionLeftSingle,
          leftValue: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftValueMarried(
                  formatChf(r.renteSurvivant / 12),
                )
              : S.of(context)!.renteVsCapitalTransmissionLeftValueSingle,
          leftDetail: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftDetailMarried
              : S.of(context)!.renteVsCapitalTransmissionLeftDetailSingle,
          rightTitle: S.of(context)!.renteVsCapitalCapitalLabel,
          rightSubtitle: S.of(context)!.renteVsCapitalTransmissionRightSubtitle,
          rightValue: S.of(context)!.renteVsCapitalTransmissionRightValue,
          rightDetail: S.of(context)!.renteVsCapitalTransmissionRightDetail,
          bottomText: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionBottomMarried
              : S.of(context)!.renteVsCapitalTransmissionBottomSingle,
        ),
      ],
    );
  }

  Widget _educationalCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String leftTitle,
    required String leftSubtitle,
    required String leftValue,
    required String leftDetail,
    required String rightTitle,
    required String rightSubtitle,
    required String rightValue,
    required String rightDetail,
    required String bottomText,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(title, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Before/After comparison
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(leftTitle, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    if (leftSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(leftSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(leftValue, style: MintTextStyles.titleMedium(), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(leftDetail, style: MintTextStyles.micro()),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: MintColors.lightBorder),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(rightTitle, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    if (rightSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rightSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(rightValue, style: MintTextStyles.titleMedium(), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(rightDetail, style: MintTextStyles.micro()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          // Bottom insight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bottomText,
              style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(
                fontSize: 12, height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BLOC D — AFFINER (hypothèses + impact cards + tornado)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAffinerBloc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalAffinerTitle,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.renteVsCapitalAffinerSubtitle,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MintSpacing.md),

        // ── Hypothesis sliders (vulgarized labels) ──
        HypothesisEditorWidget(
          hypotheses: [
            HypothesisConfig(
              key: 'rendement',
              label: S.of(context)!.renteVsCapitalHypRendement,
              min: 0, max: 8, divisions: 16, defaultValue: 3,
            ),
            HypothesisConfig(
              key: 'swr',
              label: S.of(context)!.renteVsCapitalHypSwr,
              min: 2, max: 6, divisions: 8, defaultValue: 4,
            ),
            HypothesisConfig(
              key: 'inflation',
              label: S.of(context)!.renteVsCapitalHypInflation,
              min: 0, max: 4, divisions: 8, defaultValue: 2,
            ),
          ],
          values: _hypotheses,
          onChanged: (updated) {
            _hypotheses = updated;
            _recalculate();
          },
        ),
        const SizedBox(height: MintSpacing.lg),

        // ── Impact cards (simplified sensitivity) ──
        _buildImpactCards(),
        const SizedBox(height: MintSpacing.sm),

        // ── Tornado in ExpansionTile ──
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
          title: Text(
            S.of(context)!.renteVsCapitalTornadoToggle,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          children: [ArbitrageTornadoSection(result: _result!)],
        ),
        const SizedBox(height: MintSpacing.md),

        // ── Hypothèses détaillées ──
        _buildHypothesesSection(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  IMPACT CARDS (simplified sensitivity)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildImpactCards() {
    if (_result == null) return const SizedBox.shrink();
    final variables = _result!.tornadoVariables;
    if (variables.isEmpty) return const SizedBox.shrink();

    // Filter out variables with negligible or zero swing — showing "+0" is
    // worse than not showing the row at all (misleads the user).
    final top = variables.where((v) => v.swing > 50).take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxSwing = top.first.swing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalImpactTitle,
          style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.renteVsCapitalImpactSubtitle,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        for (int i = 0; i < top.length; i++) ...[
          _impactCard(i + 1, top[i], maxSwing),
          if (i < top.length - 1) const SizedBox(height: MintSpacing.sm),
        ],
      ],
    );
  }

  Widget _impactCard(int rank, ArbitrageTornadoVariable v, double maxSwing) {
    final barFraction = maxSwing > 0 ? v.swing / maxSwing : 0.0;
    final lowDelta = v.lowValue - v.baseValue;
    final highDelta = v.highValue - v.baseValue;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('#$rank', style: MintTextStyles.micro(color: MintColors.primary).copyWith(
                    fontWeight: FontWeight.w700, fontStyle: FontStyle.normal,
                  )),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(v.label, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          // Impact bar
          Semantics(
            label: '${v.label}: ${_formatDelta(lowDelta)} / ${_formatDelta(highDelta)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barFraction,
                minHeight: 6,
                backgroundColor: MintColors.border.withAlpha(60),
                valueColor: AlwaysStoppedAnimation(MintColors.primary.withAlpha(180)),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${v.lowLabel} : ${_formatDelta(lowDelta)}',
                style: MintTextStyles.labelSmall(
                  color: lowDelta < 0
                      ? MintColors.danger
                      : MintColors.success,
                ),
              ),
              Text(
                '${v.highLabel} : ${_formatDelta(highDelta)}',
                style: MintTextStyles.labelSmall(
                  color: highDelta >= 0
                      ? MintColors.success
                      : MintColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONFIDENCE BANNER
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  //  HYPOTHESES EXPANDABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHypothesesSection() {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
      title: Text(
        S.of(context)!.renteVsCapitalHypothesesTitle,
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        for (final h in _result!.hypotheses)
          Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  \u2022  ',
                    style: TextStyle(color: MintColors.textMuted)),
                Expanded(
                  child: Text(h, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                    fontSize: 12, height: 1.4,
                  )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISCLAIMER CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDisclaimerCard() {
    if (_result == null) return const SizedBox.shrink();
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(S.of(context)!.renteVsCapitalWarning,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(_result!.disclaimer,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.renteVsCapitalSources(_result!.sources.join(' | ')),
            style: MintTextStyles.micro(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════════════

  static final _labelStyle = MintTextStyles.bodySmall(color: MintColors.textSecondary);

  Widget _buildRachatSection() {
    final maxRachat = double.tryParse(_rachatMaxCtrl.text.replaceAll("'", '')) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.of(context)!.renteVsCapitalRachatLabel,
                style: _labelStyle,
              ),
            ),
            if (maxRachat > 0)
              Text(
                S.of(context)!.renteVsCapitalRachatMax(formatChf(maxRachat)),
                style: MintTextStyles.labelSmall(),
              ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: _rachatAnnuelCtrl,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          decoration: InputDecoration(
            hintText: S.of(context)!.renteVsCapitalRachatHint,
            hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            prefixText: 'CHF ',
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Tooltip(
              message: S.of(context)!.renteVsCapitalRachatTooltip,
              child: const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  Widget _buildEplSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.of(context)!.renteVsCapitalEplLabel,
                style: _labelStyle,
              ),
            ),
            Semantics(
              label: S.of(context)!.renteVsCapitalEplLabel,
              toggled: _hasEpl,
              child: Switch(
                value: _hasEpl,
                activeTrackColor: MintColors.primary,
                onChanged: (v) => setState(() { _hasEpl = v; _recalculate(); }),
              ),
            ),
          ],
        ),
        if (_hasEpl) ...[
          const SizedBox(height: MintSpacing.xs),
          TextField(
            controller: _eplAmountCtrl,
            keyboardType: TextInputType.number,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            decoration: InputDecoration(
              hintText: S.of(context)!.renteVsCapitalEplHint,
              hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
              prefixText: 'CHF ',
              filled: true,
              fillColor: MintColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Tooltip(
                message: S.of(context)!.renteVsCapitalEplTooltip,
                child: const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
              ),
            ),
            onChanged: (_) => _recalculate(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalEplLegalRef,
            style: MintTextStyles.micro(),
          ),
        ],
      ],
    );
  }

  static String _formatDelta(double delta) {
    final abs = delta.abs();
    String formatted;
    if (abs >= 1000000) {
      formatted = '${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 10000) {
      formatted = '${(abs / 1000).round()}k';
    } else {
      formatted = formatChf(abs);
    }
    return '${delta >= 0 ? '+' : '-'}$formatted';
  }
}
