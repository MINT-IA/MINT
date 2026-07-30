import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/precision/field_help_tooltip.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:go_router/go_router.dart';
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
///
/// PREFILL: When navigated from coach via RouteSuggestionCard,
/// GoRouterState.extra may contain {'prefill': Map<String, dynamic>}
/// with pre-computed values. Currently reads from CoachProfileProvider.
/// DECISION: prefill merge deferred to Phase 2 (S62+ coach-driven defaults).
/// Current: CoachProfileProvider supplies defaults; coach prefill via GoRouter extra.
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
  // ILLOG-01 (MATRIX D5) : NO fiction defaults. Fields start empty so the
  // screen never renders an invented avoir/salaire/âge as if it were the
  // user's data (which bypassed ProfileDataSource and computed a phantom
  // « Capital estimé à 65 ans »). The ONLY fill path is
  // _autoFillFromProfile (ProfileDataSource-tagged) ; without usable
  // profile data the fields stay empty and an explicit empty state invites
  // the user to complete their profile or type their values.
  final _ageCtrl = TextEditingController();
  final _ageRetraiteSlider =
      ValueNotifier<double>(avsAgeReferenceHomme.toDouble());
  final _salaryCtrl = TextEditingController();
  final _lppTotalCtrl = TextEditingController();

  // ── Certificate mode controllers ──
  // Capital / rente fields are the user's OWN certificate values — never
  // pre-invented (ILLOG-01). The conversion-rate fields keep the Swiss LPP
  // statutory minima (6.8% obligatoire / 5.0% surobligatoire) as a starting
  // hypothesis — these are regulatory constants, NOT user-data fiction, and
  // are clearly editable.
  final _capitalObligCtrl = TextEditingController();
  final _capitalSurobCtrl = TextEditingController();
  final _renteCtrl = TextEditingController();
  final _tcObligCtrl = TextEditingController(text: '6.8');
  final _tcSurobCtrl = TextEditingController(text: '5.0');

  // ── Shared inputs ──
  String _canton = 'ZH';
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

  // P2-9: Debounce recomputation to avoid 200-300ms lag per keystroke.
  Timer? _debounceTimer;

  // ── CoachProfile auto-fill ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;
  // D12 : confiance canonique du profil (EnhancedConfidence.combined), capturee
  // a l'auto-fill et passee au fallback local pour qu'un profil = un score sur
  // toutes les surfaces (plus de moteur de confiance d'arbitrage divergent).
  double? _canonicalConfidence;
  // Couche 4 (audit T05-F03, MINT_nosync-84r) : on garde l'EnhancedConfidence
  // COMPLET — ses axisPrompts alimentent le CTA d'enrichissement de la
  // banniere (avant : categorie 'lpp' codee en dur, la couche 4 etait jetee).
  EnhancedConfidence? _canonicalEnhanced;

  // ── GoRouter prefill from coach suggestion ──
  // The prefill map is read from GoRouterState.extra in the postFrameCallback
  // and applied immediately (it is not stored — see _applyPrefill / Codex W3 fix).
  final Set<String> _prefilledFields = {};

  // ── F2-6: Gate ScreenReturn behind user interaction ──
  bool _hasUserInteracted = false;

  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;
  bool _routeProofLogged = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map<String, dynamic>) {
          _seqRunId = extra['runId'] as String?;
          _seqStepId = extra['stepId'] as String?;
          final prefill = extra['prefill'] as Map<String, dynamic>?;
          if (prefill != null) {
            // Codex W3 fix : the postFrameCallback runs AFTER didChangeDependencies
            // (so AFTER _autoFillFromProfile), and the GoRouter extra is only
            // readable here — apply the coach prefill now. _applyPrefill running
            // last preserves the "coach values win over profile autofill"
            // invariant, and it runs independent of profile presence (a coach
            // suggestion can target a user with no stored profile).
            if (!mounted) return;
            _applyPrefill(prefill);
          }
        }
      } catch (_) {}
    });
  }

  void _emitFinalReturnOnPop() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted || !_hasCompleteCalculationReceipt(_result)) {
      ScreenCompletionTracker.markCompletedWithReturn(
          'rente_vs_capital',
          ScreenReturn.abandoned(
            route: '/retraite/rente-vs-capital',
            runId: _seqRunId,
            stepId: _seqStepId,
            eventId:
                'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
          ));
      return;
    }

    // decision_mixte: which option the user was viewing when they left
    final mode =
        _inputMode == _InputMode.certificate ? 'certificate' : 'estimate';
    ScreenCompletionTracker.markCompletedWithReturn(
        'rente_vs_capital',
        ScreenReturn.completed(
          route: '/retraite/rente-vs-capital',
          stepOutputs: {'decision_mixte': mode},
          runId: _seqRunId,
          stepId: _seqStepId,
          eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
        ));
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

    // D12 : score canonique unique, calcule sur ce profil.
    _canonicalEnhanced = ConfidenceScorer.scoreEnhanced(profile);
    _canonicalConfidence = _canonicalEnhanced!.combined;

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

    final age = profile.ageOrNull;
    if (age != null) {
      apply(_ageCtrl, age.toString(), 'age');
    }

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
      apply(_capitalObligCtrl, lppOblig.round().toString(),
          'prevoyance.avoirLppObligatoire');
    }
    if (lppSurob != null && lppSurob > 0) {
      apply(_capitalSurobCtrl, lppSurob.round().toString(),
          'prevoyance.avoirLppSurobligatoire');
    }

    // Conversion rates from certificate
    final tcProfile = profile.prevoyance.tauxConversion;
    if (tcProfile > 0) {
      apply(_tcObligCtrl, (tcProfile * 100).toStringAsFixed(1),
          'prevoyance.tauxConversion');
    }
    final tcSurobProfile = profile.prevoyance.tauxConversionSuroblig;
    if (tcSurobProfile != null && tcSurobProfile > 0) {
      apply(_tcSurobCtrl, (tcSurobProfile * 100).toStringAsFixed(1),
          'prevoyance.tauxConversionSuroblig');
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

    // Coach prefill is applied from the postFrameCallback (the only place the
    // GoRouter extra is readable, and which runs AFTER this profile auto-fill
    // so coach values win). It is intentionally NOT applied here: the prefill
    // is not yet available because didChangeDependencies fires before the
    // first frame. (Codex W3 fix.)
  }

  /// Write computed results back to CoachProfile.
  /// Only called after user has interacted (_hasUserInteracted == true).
  /// Guard prevents infinite recalculation loop with _didAutoFill.
  void _writeBackResult() {
    if (!_hasUserInteracted) return;
    if (_result == null) return;
    if (!_hasCompleteCalculationReceipt(_result)) return;
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    try {
      final updated = profile.copyWith(
        prevoyance: profile.prevoyance.copyWith(
          projectedRenteLpp: _result!.renteNetMensuelle > 0
              ? _result!.renteNetMensuelle * 12
              : null,
          projectedCapital65:
              _result!.capitalProjecte > 0 ? _result!.capitalProjecte : null,
        ),
        targetRetirementAge: _ageRetraiteSlider.value.round(),
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

  /// Apply prefill values from a coach suggestion (GoRouter extra['prefill']).
  /// Called after _autoFillFromProfile() to ensure coach values override estimates.
  void _applyPrefill(Map<String, dynamic> prefill) {
    bool changed = false;

    final avoirLpp = prefill['avoirLpp'];
    if (avoirLpp is num && avoirLpp > 0) {
      _lppTotalCtrl.text =
          avoirLpp.toDouble().clamp(0, 5000000).round().toString();
      _prefilledFields.add('lpp_total');
      changed = true;
    }

    final tauxConversion = prefill['tauxConversion'];
    if (tauxConversion is num && tauxConversion > 0) {
      final tc = tauxConversion.toDouble().clamp(0.01, 0.10);
      _tcObligCtrl.text = (tc * 100).toStringAsFixed(1);
      _prefilledFields.add('lpp_obligatoire');
      changed = true;
    }

    final salaireBrut = prefill['salaireBrut'];
    if (salaireBrut is num && salaireBrut > 0) {
      // salaireBrut from prefill is monthly — multiply by nombreDeMois
      const nombreDeMois = 13;
      final annualSalary = salaireBrut.toDouble() * nombreDeMois;
      _salaryCtrl.text = annualSalary.round().toString();
      _prefilledFields.add('salaire_brut');
      changed = true;
    }

    final ageRetraite = prefill['ageRetraite'];
    if (ageRetraite is num) {
      final age = ageRetraite.toDouble().clamp(58.0, 70.0);
      _ageRetraiteSlider.value = age;
      _prefilledFields.add('ageRetraite');
      changed = true;
    }

    if (changed) {
      setState(() {});
      _recalculate();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
  /// P2-9: Debounced (300ms) to avoid recomputing on every keystroke.
  void _recalculate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _recalculateAsync();
    });
  }

  /// F2-6: User-triggered recalculation — marks interaction before recalc.
  /// Used by all user-facing onChanged handlers.
  void _userRecalculate() {
    _hasUserInteracted = true;
    _recalculate();
    // Write-back is deferred until after async recalculation completes.
    // Call _writeBackResult after a brief delay to let result settle.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _writeBackResult();
    });
  }

  /// ILLOG-01 : whether there is a usable LPP input to project on. Without
  /// it the screen shows the explicit empty state instead of computing a
  /// projection on a phantom (invented) avoir.
  bool get _hasUsableInputs {
    if (_inputMode == _InputMode.estimate) {
      final lpp = double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 0;
      return lpp > 0;
    }
    final oblig =
        double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 0;
    final surob =
        double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 0;
    return oblig > 0 || surob > 0;
  }

  Future<void> _recalculateAsync() async {
    final requestId = ++_requestCounter;
    final ageRetraite = _ageRetraiteSlider.value.round();

    // ILLOG-01 : never compute on a phantom avoir. With no usable LPP input,
    // clear any prior result so the explicit empty state renders.
    if (!_hasUsableInputs) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    double capitalOblig, capitalSurob, renteAnnuelle;
    double tcOblig, tcSurob;
    int? currentAge;
    double? salary;

    if (_inputMode == _InputMode.estimate) {
      // Estimate mode: use LPP total with 70/30 split as starting point.
      // No fiction fallback — _hasUsableInputs already guaranteed lpp > 0.
      final lppTotal =
          double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 0;
      capitalOblig = lppTotal * 0.7;
      capitalSurob = lppTotal * 0.3;
      tcOblig = lppTauxConversionMin / 100;
      tcSurob = 0.05;
      renteAnnuelle = capitalOblig * tcOblig;
      currentAge = int.tryParse(_ageCtrl.text);
      salary = double.tryParse(_salaryCtrl.text.replaceAll("'", ''));
    } else {
      // Certificate mode: direct values. No fiction fallback — empty fields
      // parse to 0 (the user's own values are the only source).
      capitalOblig =
          double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 0;
      capitalSurob =
          double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 0;
      renteAnnuelle = double.tryParse(_renteCtrl.text.replaceAll("'", '')) ?? 0;
      tcOblig = (double.tryParse(_tcObligCtrl.text) ?? 6.8) / 100;
      tcSurob = (double.tryParse(_tcSurobCtrl.text) ?? 5.0) / 100;
      currentAge = null;
      salary = null;
    }

    // Rachat LPP: add future value of annual buybacks to current LPP
    // FV annuity = annualBuyback × ((1+r)^n - 1) / r  (LPP growth rate 1.25%)
    final rachatAnnuel =
        double.tryParse(_rachatAnnuelCtrl.text.replaceAll("'", '')) ?? 0;
    if (rachatAnnuel > 0 && currentAge != null) {
      final yearsToRetirement = math.max(0, _ageRetraite - currentAge);
      // -b6k : taux d'intérêt minimal LPP (OPP2, décision annuelle du
      // Conseil fédéral) — registre + fallback via le helper ratio.
      final lppReturn = lppMinInterestRatio();
      final fvRachat = yearsToRetirement > 0
          ? rachatAnnuel *
              (math.pow(1 + lppReturn, yearsToRetirement) - 1) /
              lppReturn
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
        currentAge: currentAge,
        inputMode: _inputMode == _InputMode.certificate
            ? 'certificate'
            : 'estimate',
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
          canonicalConfidence: _canonicalConfidence,
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
    // F2-6: Only emit ScreenReturn after user has actively interacted.
    // Prevents premature completion on initial auto-fill + auto-calc.
    if (!_hasUserInteracted) return;
    if (!_hasCompleteCalculationReceipt(result)) return;
    if (_seqRunId != null) return; // Sequence mode: terminal only on pop
    final mode =
        _inputMode == _InputMode.certificate ? 'certificate' : 'estimate';
    final screenReturn = ScreenReturn.completed(
      route: '/retraite/rente-vs-capital',
      updatedFields: {'retirementMode': mode},
      confidenceDelta: 0.02,
    );
    ScreenCompletionTracker.markCompletedWithReturn(
      'rente_vs_capital',
      screenReturn,
    );
  }

  bool _hasCompleteCalculationReceipt(ArbitrageResult? result) =>
      result?.calculationReceipt?.isComplete ?? false;

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
    final hasCompleteReceipt = _hasCompleteCalculationReceipt(_result);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturnOnPop();
      },
      // AX iOS 26.2 (ADR 2026-07-30, pilote + Étape 2) : plus de Semantics
      // racine ET plus de SliverAppBar. ILLOG-02 avait ajouté un conteneur
      // racine ; sur iOS 26.2 ce conteneur fait DOUBLE frontière avec le
      // scopesRoute de ModalRoute et effondre la route poussée à 1 nœud (cf.
      // project_ios26_ax_tree_collapse). Retour au défaut du framework. Le
      // SliverAppBar (2e déclencheur : ré-effondrement au scroll) est migré en
      // AppBar fixe (Scaffold.appBar, voir _buildAppBar). Ancre de flow : id
      // interne rvc_route_state (proof anchors) ou titre AppBar.
      child: Scaffold(
            // AX iOS 26.2 (ADR 2026-07-30, Étape 2) : AppBar classique en
            // Scaffold.appBar, plus de SliverAppBar dans le CustomScrollView.
            // Le SliverAppBar ré-effondre l'arbre AX des routes poussées au
            // scroll sur iOS 26.2 ; l'AppBar fixe garde un arbre riche et stable
            // (cf. project_ios26_ax_tree_collapse). Rendu inchangé : l'ancien
            // SliverAppBar n'avait ni expandedHeight ni flexibleSpace (aucun
            // grand titre repliable). L'ancre de preuve rvc_route_state reste
            // le premier sliver du corps.
            appBar: _buildAppBar(context),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildRouteProofAnchors(context),
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
                                  padding: EdgeInsets.symmetric(
                                      vertical: MintSpacing.lg),
                                  child: MintLoadingSkeleton(),
                                ),

                              if (_hasError && _result == null)
                                Container(
                                  padding: const EdgeInsets.all(MintSpacing.md),
                                  margin: const EdgeInsets.only(
                                      bottom: MintSpacing.md),
                                  decoration: BoxDecoration(
                                    color: MintColors.error
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: MintColors.error, size: 20),
                                      const SizedBox(width: MintSpacing.sm),
                                      Expanded(
                                          child: Text(
                                        S.of(context)!.renteVsCapitalErrorRetry,
                                        style: MintTextStyles.bodySmall(
                                            color: MintColors.error),
                                      )),
                                    ],
                                  ),
                                ),

                              if (_result != null && !hasCompleteReceipt) ...[
                                _buildReceiptRequiredCard(
                                    _result!.calculationReceipt),
                                const SizedBox(height: MintSpacing.xl),
                              ],

                              if (_result != null && hasCompleteReceipt) ...[
                                _buildCalculationReceiptCard(
                                    _result!.calculationReceipt!),
                                const SizedBox(height: MintSpacing.md),

                                // ── Confidence banner ──
                                IndicatifBanner(
                                  // -7vv : contrat MUST de fromBareScore — trame 4 axes RÉELLE
                                  // (le score de visibilité reste _result.confidenceScore).
                                  confidence: _canonicalEnhanced,
                                  confidenceScore: _result!.confidenceScore,
                                  // Couche 4 : categorie du prompt au plus
                                  // FORT impact du profil reel — axisPrompts
                                  // n'est PAS trie (ordre d'emission, cf.
                                  // confidence_scorer.dart:425), on prend le
                                  // max. Plus de 'lpp' code en dur
                                  // (MINT_nosync-84r).
                                  topEnrichmentCategory: IndicatifBanner.topEnrichmentCategoryFrom(
                                      _canonicalEnhanced),
                                ),

                                if (_hasEstimatedValues &&
                                    _inputMode == _InputMode.estimate)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: MintSpacing.sm),
                                    child: SmartDefaultIndicator(
                                      source: S
                                          .of(context)!
                                          .renteVsCapitalProfileAutoFill,
                                      confidence:
                                          _result!.confidenceScore / 100,
                                    ),
                                  ),

                                // ══════════════════════════════════════════════
                                //  BLOC A — ACCROCHE (RepaintBoundary for perf)
                                //  Chiffre-choc + Hero CHF/mois + micro-légendes
                                // ══════════════════════════════════════════════
                                RepaintBoundary(
                                  child: Column(
                                    children: [
                                      _buildPremierEclairageAccroche(),
                                      const SizedBox(height: MintSpacing.md),
                                      _buildHeroMonthly(),
                                    ],
                                  ),
                                ),
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
      ),
    );
  }

  // ── App Bar (white standard — Simulator screen) ──────────────
  // Migré de SliverAppBar vers AppBar classique (ADR AX iOS 26.2, Étape 2) :
  // le rendu est identique (aucun expandedHeight/flexibleSpace sur l'ancien
  // SliverAppBar), mais l'arbre AX ne s'effondre plus au scroll.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      surfaceTintColor: MintColors.white,
      title: Text(
        S.of(context)!.renteVsCapitalAppBarTitle,
        style: MintTextStyles.titleGambarino18Medium(
          color: MintColors.inkPrimary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HERO INTRO — contexte utilisateur
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroIntro() {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.renteVsCapitalIntro,
            style: MintTextStyles.bodySupreme15Regular(
              color: MintColors.inkPrimary,
            ),
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
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: MintColors.mintForest,
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  term,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.mintForest,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: MintColors.mintForest.withAlpha(90),
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
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Text(
              term,
              style: MintTextStyles.titleLarge(color: MintColors.primary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              text,
              style: MintTextStyles.labelLarge(color: MintColors.textPrimary)
                  .copyWith(
                height: 1.6,
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
                  HapticFeedback.lightImpact();
                  setState(() => _inputMode = v.first);
                  _userRecalculate();
                },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    MintTextStyles.labelMedium()
                        .copyWith(fontWeight: FontWeight.w600),
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
            // ILLOG-01 : explicit empty state when no usable input — replaces
            // the removed fiction defaults. No projection on a phantom avoir.
            if (!_hasUsableInputs) ...[
              const SizedBox(height: MintSpacing.sm),
              _buildEmptyStateHint(),
            ],
            // Auto-computed readout
            if (_result != null &&
                _result!.isProjected &&
                _hasCompleteCalculationReceipt(_result)) ...[
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
                      style: MintTextStyles.bodySmall(
                              color: MintColors.textPrimary)
                          .copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.renteVsCapitalEstimatedRente(
                            formatChf(_result!.renteNetMensuelle * 12),
                          ),
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
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
            // ILLOG-01 : explicit empty state when no usable certificate
            // capital entered — no projection on a phantom avoir.
            if (!_hasUsableInputs) ...[
              const SizedBox(height: MintSpacing.sm),
              _buildEmptyStateHint(),
            ],
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
                          style: MintTextStyles.labelSmall(
                              color: MintColors.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: MintSpacing.md),
          _buildAdvancedInputSection(
            includeRachatAndEpl: _inputMode == _InputMode.estimate,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedInputSection({required bool includeRachatAndEpl}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
      title: Text(
        S.of(context)!.renteVsCapitalAdvancedParameters,
        style:
            MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        if (includeRachatAndEpl) ...[
          _buildRachatSection(),
          const SizedBox(height: MintSpacing.sm),
          _buildEplSection(),
          const SizedBox(height: MintSpacing.sm),
        ],
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
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
                        if (v != null) {
                          _canton = v;
                          _userRecalculate();
                        }
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
                    onChanged: (v) {
                      _isMarried = v;
                      _userRecalculate();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetirementAgeSlider() {
    final l = S.of(context)!;
    // Retirement age chips: 58 to 70.
    const ageOptions = [58, 60, 62, 63, 64, 65, 66, 67, 70];

    return ValueListenableBuilder<double>(
      valueListenable: _ageRetraiteSlider,
      builder: (context, ageValue, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.renteVsCapitalRetirementAgeChips, style: _labelStyle),
          const SizedBox(height: MintSpacing.sm),
          Wrap(
            spacing: MintSpacing.xs,
            runSpacing: MintSpacing.xs,
            children: ageOptions.map((age) {
              final isSelected = ageValue.round() == age;
              return ChoiceChip(
                label: Text('$age'),
                selected: isSelected,
                onSelected: (_) {
                  _ageRetraiteSlider.value = age.toDouble();
                  _userRecalculate();
                },
                selectedColor: MintColors.primary.withValues(alpha: 0.15),
                backgroundColor: MintColors.surface,
                labelStyle: MintTextStyles.bodySmall(
                  color:
                      isSelected ? MintColors.primary : MintColors.textPrimary,
                ).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
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
      ),
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? fieldName,
    bool isPercent = false,
  }) {
    final isPrefilled =
        fieldName != null && _prefilledFields.contains(fieldName);
    // ILLOG-02: scope each field to its own semantics container whose
    // accessible name is the field [label], so the label is exposed as a
    // single discrete node on the iOS accessibility tree (and is findable by
    // Maestro `assertVisible`) rather than being merged into one big blob
    // with every other label in the input section. The inner visual label
    // `Text` is `ExcludeSemantics`-wrapped to avoid duplicating the name.
    final semanticsValue = controller.text.trim();
    return Semantics(
      container: true,
      label: label,
      value: semanticsValue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(child: Text(label, style: _labelStyle)),
              ),
              if (isPrefilled)
                const SmartDefaultIndicator(
                  source: 'Depuis ton profil MINT',
                  confidence: 0.60,
                ),
              if (fieldName != null) FieldHelpTooltip(fieldName: fieldName),
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
            style: MintTextStyles.labelLarge(color: MintColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: MintColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: 14,
              ),
            ),
            onChanged: (_) => _userRecalculate(),
          ),
        ],
      ),
    );
  }

  /// ILLOG-01 (MATRIX D5) : explicit empty-state invitation shown in place of
  /// the removed fiction defaults. Renders when no usable LPP input exists, so
  /// the user sees a clear « complète ton profil ou saisis tes valeurs » call
  /// to action rather than an invented projection presented as their data.
  Widget _buildEmptyStateHint() {
    return Semantics(
      label: S.of(context)!.renteVsCapitalEmptyState,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note_outlined,
                size: 20, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  S.of(context)!.renteVsCapitalEmptyState,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BLOC A — ACCROCHE
  // ═══════════════════════════════════════════════════════════════

  /// Chiffre-choc en haut — pourquoi cette decision compte.
  Widget _buildPremierEclairageAccroche() {
    final r = _result!;
    // Build a punchy one-liner from the engine's premierEclairage
    final taxDelta = (r.impotCumulRente - r.impotRetraitCapital).abs();
    final epuiseAge = r.capitalEpuiseAge;

    // Dynamic accroche that adapts to the user's numbers
    String accroche;
    if (taxDelta > 10000 && epuiseAge != null) {
      accroche = S.of(context)!.renteVsCapitalAccrocheTaxEpuise(
            formatChf(taxDelta),
            epuiseAge,
          );
    } else if (taxDelta > 10000) {
      accroche = S.of(context)!.renteVsCapitalAccrocheTax(
            formatChf(taxDelta),
          );
    } else if (epuiseAge != null) {
      accroche = S.of(context)!.renteVsCapitalAccrocheEpuise(epuiseAge);
    } else {
      accroche = r.premierEclairage;
    }

    return Semantics(
      label: accroche,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md, vertical: 14),
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
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                    .copyWith(
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
                    Text(
                      S.of(context)!.renteVsCapitalHeroRente,
                      style: MintTextStyles.labelSmall(
                              color: MintColors.retirementAvs)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    MintCountUp(
                      value: renteMois,
                      prefix: 'CHF\u00a0',
                      showLigne: false,
                      fullReveal: false,
                    ),
                    Text(
                      S.of(context)!.renteVsCapitalPerMonth,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementAvs.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        S.of(context)!.renteVsCapitalForLife,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.retirementAvs)
                            .copyWith(
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
                    Text(
                      S.of(context)!.renteVsCapitalHeroCapital,
                      style: MintTextStyles.labelSmall(
                              color: MintColors.retirementLpp)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      formatChf(capitalMois),
                      style: MintTextStyles.headlineLarge(),
                    ),
                    Text(
                      S.of(context)!.renteVsCapitalPerMonth,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementLpp.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        S.of(context)!.renteVsCapitalDuration(capitalDuration),
                        style: MintTextStyles.labelSmall(
                                color: MintColors.retirementLpp)
                            .copyWith(
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
                  const Icon(Icons.add_circle_outline,
                      size: 16, color: MintColors.textMuted),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                        children: [
                          TextSpan(
                              text: S.of(context)!.renteVsCapitalAvsEstimated),
                          TextSpan(
                            text: S.of(context)!.renteVsCapitalAvsAmount(
                                  formatChf(_avsRenteMensuelle!),
                                ),
                            style: MintTextStyles.labelSmall(
                                    color: MintColors.textPrimary)
                                .copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                              text: S
                                  .of(context)!
                                  .renteVsCapitalAvsSupplementary),
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
          MintEntrance(
              child: Text(
            S.of(context)!.renteVsCapitalLifeExpectancyChips,
            style: MintTextStyles.labelLarge(),
          )),
          const SizedBox(height: MintSpacing.sm),
          MintEntrance(
              delay: const Duration(milliseconds: 100),
              child: Wrap(
                spacing: MintSpacing.xs,
                runSpacing: MintSpacing.xs,
                children: [75, 80, 85, 90, 95, 100].map((age) {
                  final isSelected = _lifeExpectancy.round() == age;
                  return ChoiceChip(
                    label: Text(S.of(context)!.renteVsCapitalAgeYears(age)),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _lifeExpectancy = age.toDouble());
                      _userRecalculate();
                    },
                    selectedColor: MintColors.primary.withValues(alpha: 0.15),
                    backgroundColor: MintColors.surface,
                    labelStyle: MintTextStyles.bodySmall(
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.textPrimary,
                    ).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400),
                    side: BorderSide(
                      color:
                          isSelected ? MintColors.primary : MintColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              )),
          MintEntrance(
              delay: const Duration(milliseconds: 200),
              child: _buildDeltaAtAge(_lifeExpectancy.round())),
          const SizedBox(height: MintSpacing.xs),
          MintEntrance(
              delay: const Duration(milliseconds: 300),
              child: Text(
                S.of(context)!.renteVsCapitalLifeExpectancyRef,
                style: MintTextStyles.labelSmall(),
              )),

          const SizedBox(height: MintSpacing.lg),

          // ── Chart: capital restant vs revenus cumules de la rente ──
          MintEntrance(
              delay: const Duration(milliseconds: 400),
              child: Text(
                S.of(context)!.renteVsCapitalChartTitle,
                style: MintTextStyles.labelLarge(),
              )),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalChartSubtitle,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
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
      (o) => o.id == 'full_rente',
      orElse: () => _result!.options.first,
    );
    final capitalOption = _result!.options.firstWhere(
      (o) => o.id == 'full_capital',
      orElse: () => _result!.options.last,
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
    final delta = (capitalVal - renteVal).abs();
    const varianceColor = MintColors.ardoise;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.sm),
      decoration: BoxDecoration(
        color: varianceColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            color: varianceColor,
            size: 20,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAtAge(age),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                TextSpan(
                  text: '${formatChf(delta)} ',
                  style:
                      MintTextStyles.bodySmall(color: varianceColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAdvance,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
                child: Text(title,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(
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
                    Text(leftTitle,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.textSecondary)
                            .copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    if (leftSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(leftSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(leftValue,
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center),
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
                    Text(rightTitle,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.textSecondary)
                            .copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    if (rightSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rightSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(rightValue,
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center),
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
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary)
                  .copyWith(
                height: 1.5,
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
          style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.md),

        // ── Hypothesis sliders (vulgarized labels) ──
        HypothesisEditorWidget(
          hypotheses: [
            HypothesisConfig(
              key: 'rendement',
              label: S.of(context)!.renteVsCapitalHypRendement,
              min: 0,
              max: 8,
              divisions: 16,
              defaultValue: 3,
            ),
            HypothesisConfig(
              key: 'swr',
              label: S.of(context)!.renteVsCapitalHypSwr,
              min: 2,
              max: 6,
              divisions: 8,
              defaultValue: 4,
            ),
            HypothesisConfig(
              key: 'inflation',
              label: S.of(context)!.renteVsCapitalHypInflation,
              min: 0,
              max: 4,
              divisions: 8,
              defaultValue: 2,
            ),
          ],
          values: _hypotheses,
          onChanged: (updated) {
            _hypotheses = updated;
            _userRecalculate();
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
    final visibleVariables =
        variables.where((v) => v.swing > 50).take(4).toList();
    if (visibleVariables.isEmpty) return const SizedBox.shrink();
    final maxSwing = visibleVariables.first.swing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalImpactTitle,
          style: MintTextStyles.labelLarge(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.renteVsCapitalImpactSubtitle,
          style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.sm),
        for (int i = 0; i < visibleVariables.length; i++) ...[
          _impactCard(visibleVariables[i], maxSwing),
          if (i < visibleVariables.length - 1)
            const SizedBox(height: MintSpacing.sm),
        ],
      ],
    );
  }

  Widget _impactCard(ArbitrageTornadoVariable v, double maxSwing) {
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
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: MintColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(v.label,
                    style:
                        MintTextStyles.bodySmall(color: MintColors.textPrimary)
                            .copyWith(
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          // Impact bar
          Semantics(
            label:
                '${v.label}: ${_formatDelta(lowDelta)} / ${_formatDelta(highDelta)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barFraction,
                minHeight: 6,
                backgroundColor: MintColors.border.withAlpha(60),
                valueColor:
                    AlwaysStoppedAnimation(MintColors.primary.withAlpha(180)),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${v.lowLabel} : ${_formatDelta(lowDelta)}',
                  style: MintTextStyles.labelSmall(
                    color:
                        lowDelta < 0 ? MintColors.danger : MintColors.success,
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  '${v.highLabel} : ${_formatDelta(highDelta)}',
                  textAlign: TextAlign.end,
                  style: MintTextStyles.labelSmall(
                    color:
                        highDelta >= 0 ? MintColors.success : MintColors.danger,
                  ),
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
  //  RECEIPT GATE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRouteProofAnchors(BuildContext context) {
    if (!E2eRuntimeFlags.proofAnchors) return const SizedBox.shrink();

    final route = GoRouterState.of(context).uri.path;
    final routeLabel = 'route=$route';
    final ageProof = _ageCtrl.text.trim();
    if (!_routeProofLogged) {
      _routeProofLogged = true;
      debugPrint('[MINT_E2E_ROUTE_STATE] $routeLabel');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProofAnchor(
          key: const Key('rvc_route_state'),
          identifier: 'rvc_route_state',
          label: routeLabel,
        ),
        if (ageProof.isNotEmpty)
          _buildProofAnchor(
            key: const Key('rvc_age_state'),
            identifier: 'rvc_age_state_$ageProof',
            label: 'rvc_age=$ageProof',
          ),
      ],
    );
  }

  Widget _buildProofAnchor({
    required Key key,
    required String identifier,
    required String label,
  }) {
    return Semantics(
      key: key,
      identifier: identifier,
      container: true,
      label: label,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Color(0x01000000), // lint-ignore: prefer_mint_color_token
          fontSize: 1, // lint-ignore: prefer_mint_text_style
          height: 1,
        ),
      ),
    );
  }

  Widget _buildReceiptRequiredCard(ArbitrageCalculationReceipt? receipt) {
    final l = S.of(context)!;
    final readiness = _receiptReadinessText(l, receipt);
    final missingInputs = _receiptMissingInputsText(l, receipt);
    final label =
        '${l.renteVsCapitalReceiptRequiredTitle}. ${l.renteVsCapitalReceiptRequiredBody} '
        '${l.renteVsCapitalReceiptReadinessLabel}: $readiness. '
        '${l.renteVsCapitalReceiptMissingLabel}: $missingInputs';

    return Semantics(
      key: const Key('rente_vs_capital_receipt_required'),
      identifier: 'rente_vs_capital_receipt_required',
      container: true,
      label: label,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: MintColors.warning),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    l.renteVsCapitalReceiptRequiredTitle,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.renteVsCapitalReceiptRequiredBody,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              '${l.renteVsCapitalReceiptReadinessLabel}: $readiness',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            Text(
              '${l.renteVsCapitalReceiptMissingLabel}: $missingInputs',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationReceiptCard(ArbitrageCalculationReceipt receipt) {
    final l = S.of(context)!;
    final rows = <String>[
      '${l.renteVsCapitalReceiptOriginLabel}: ${receipt.calculationOrigin}',
      '${l.renteVsCapitalReceiptVersionLabel}: ${receipt.calculationVersion}',
      '${l.renteVsCapitalReceiptConstantsLabel}: ${_receiptConstantsVersionText(receipt.constantsVersionHash)}',
      '${l.renteVsCapitalReceiptReadinessLabel}: ${_receiptReadinessText(l, receipt)}',
      '${l.renteVsCapitalReceiptUnitLabel}: ${_receiptUnitText(receipt.unit)}',
      '${l.renteVsCapitalReceiptConfidenceLabel}: ${receipt.confidenceScore.round()} %',
      '${l.renteVsCapitalReceiptMissingLabel}: ${_receiptMissingInputsText(l, receipt)}',
      '${l.renteVsCapitalReceiptAssumptionsLabel}: ${_receiptAssumptionsText(l, receipt)}',
      '${l.renteVsCapitalReceiptSourcesLabel}: ${receipt.sources.join(' | ')}',
    ];

    return Semantics(
      key: const Key('rente_vs_capital_calculation_receipt'),
      identifier: 'rente_vs_capital_calculation_receipt',
      container: true,
      label: '${l.renteVsCapitalReceiptTitle}. ${rows.join('. ')}',
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: MintColors.textMuted),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    l.renteVsCapitalReceiptTitle,
                    style: MintTextStyles.labelMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                child: Text(
                  row,
                  style: MintTextStyles.micro(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _receiptReadinessText(
    S l,
    ArbitrageCalculationReceipt? receipt,
  ) {
    if (receipt == null) return l.renteVsCapitalReceiptReadinessMissing;
    if (!receipt.isComplete) {
      if (receipt.readiness == 'missing_required_inputs') {
        return l.renteVsCapitalReceiptReadinessMissingRequiredInputs;
      }
      return l.renteVsCapitalReceiptReadinessIncomplete;
    }
    return switch (receipt.readiness) {
      'ready' => l.renteVsCapitalReceiptReadinessReady,
      'missing_required_inputs' =>
        l.renteVsCapitalReceiptReadinessMissingRequiredInputs,
      _ => receipt.readiness.replaceAll('_', ' '),
    };
  }

  String _receiptMissingInputsText(
    S l,
    ArbitrageCalculationReceipt? receipt,
  ) {
    if (receipt == null) return l.renteVsCapitalReceiptMissingFallback;
    final missingInputs = receipt.missingRequiredInputs;
    if (missingInputs.isEmpty) {
      return l.renteVsCapitalReceiptMissingNone;
    }
    return missingInputs
        .map((input) => _receiptMissingInputText(l, input))
        .join(', ');
  }

  String _receiptMissingInputText(S l, String input) {
    return switch (input) {
      'capital_lpp_total' => l.renteVsCapitalReceiptMissingCapitalLppTotal,
      'rente_annuelle_proposee' =>
        l.renteVsCapitalReceiptMissingRenteAnnuelleProposee,
      'canton' => l.renteVsCapitalReceiptMissingCanton,
      'current_age' => l.renteVsCapitalReceiptMissingCurrentAge,
      'horizon_years' => l.renteVsCapitalReceiptMissingHorizonYears,
      'safe_withdrawal_rate' =>
        l.renteVsCapitalReceiptMissingSafeWithdrawalRate,
      'conversion_rate_obligatory' =>
        l.renteVsCapitalReceiptMissingConversionRateObligatory,
      'conversion_rate_surobligatory' =>
        l.renteVsCapitalReceiptMissingConversionRateSurobligatory,
      _ => l.renteVsCapitalReceiptMissingFallback,
    };
  }

  String _receiptConstantsVersionText(String hash) {
    if (hash.length <= 12) return hash;
    return '${hash.substring(0, 12)}...';
  }

  String _receiptUnitText(String unit) {
    return unit.replaceAll('percent', '%').replaceAll('years', 'ans');
  }

  String _receiptAssumptionsText(
    S l,
    ArbitrageCalculationReceipt receipt,
  ) {
    final entries = receipt.assumptions.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${_receiptAssumptionLabel(l, entry.key)}: ${_receiptAssumptionValue(entry.key, entry.value)}',
        )
        .toList(growable: false);
    if (entries.isEmpty) return l.renteVsCapitalReceiptMissingFallback;
    return entries.join(' | ');
  }

  String _receiptAssumptionLabel(S l, String key) {
    return switch (key) {
      'safe_withdrawal_rate' =>
        l.renteVsCapitalReceiptMissingSafeWithdrawalRate,
      'expected_return' => l.renteVsCapitalHypRendement,
      'inflation' => l.renteVsCapitalHypInflation,
      'horizon_years' => l.renteVsCapitalReceiptMissingHorizonYears,
      'canton' => l.renteVsCapitalReceiptMissingCanton,
      'current_age' => l.renteVsCapitalReceiptMissingCurrentAge,
      'conversion_rate_obligatory' =>
        l.renteVsCapitalReceiptMissingConversionRateObligatory,
      'conversion_rate_surobligatory' =>
        l.renteVsCapitalReceiptMissingConversionRateSurobligatory,
      _ => key.replaceAll('_', ' '),
    };
  }

  String _receiptAssumptionValue(String key, Object? value) {
    if (value is num) {
      if (key.contains('rate') ||
          key == 'expected_return' ||
          key == 'inflation') {
        return '${(value * 100).toStringAsFixed(1)} %';
      }
      if (key == 'horizon_years') {
        return '${value.round()} ans';
      }
      return value.toString();
    }
    return value.toString();
  }

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
        style:
            MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
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
                  child: Text(h,
                      style: MintTextStyles.labelMedium(
                              color: MintColors.textSecondary)
                          .copyWith(
                        height: 1.4,
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
    final sources =
        S.of(context)!.renteVsCapitalSources(_result!.sources.join(' | '));
    return Semantics(
      key: const Key('rente_vs_capital_disclaimer_card'),
      identifier: 'rente_vs_capital_disclaimer_card',
      container: true,
      focusable: true,
      label:
          '${S.of(context)!.renteVsCapitalWarning}. ${_result!.disclaimer}. $sources',
      child: MintSurface(
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
                Text(
                  S.of(context)!.renteVsCapitalWarning,
                  style: MintTextStyles.labelMedium(color: MintColors.textMuted)
                      .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _result!.disclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                  .copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              sources,
              style: MintTextStyles.micro(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════════════

  static final _labelStyle =
      MintTextStyles.bodySmall(color: MintColors.textSecondary);

  Widget _buildRachatSection() {
    final maxRachat =
        double.tryParse(_rachatMaxCtrl.text.replaceAll("'", '')) ?? 0;
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
              child: const Icon(Icons.info_outline,
                  size: 18, color: MintColors.textMuted),
            ),
          ),
          onChanged: (_) => _userRecalculate(),
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
                onChanged: (v) => setState(() {
                  _hasEpl = v;
                  _userRecalculate();
                }),
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
                child: const Icon(Icons.info_outline,
                    size: 18, color: MintColors.textMuted),
              ),
            ),
            onChanged: (_) => _userRecalculate(),
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
