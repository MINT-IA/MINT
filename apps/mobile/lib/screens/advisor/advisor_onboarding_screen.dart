import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────────────────────────────────────
//  MINI-ONBOARDING — "60 secondes to value"
// ────────────────────────────────────────────────────────────
//
// Remplace l'ancien ecran d'information statique par un
// questionnaire en 4 etapes rapides. Apres quelques questions
// essentielles, l'utilisateur obtient un chiffre choc
// personnalise sur le dashboard.
//
// Etape 1 : Stress check (ta priorite financiere)
// Etape 2 : Age + Canton (2 champs combines)
// Etape 3 : Revenu + Statut professionnel
// Etape 4 : Objectif principal + preview projection
//
// Le wizard complet reste accessible pour enrichir le profil.
// Les reponses sont sauvegardees via ReportPersistenceService
// pour que le wizard puisse reprendre sans redemander.
// ────────────────────────────────────────────────────────────

class AdvisorOnboardingScreen extends StatefulWidget {
  const AdvisorOnboardingScreen({super.key});

  @override
  State<AdvisorOnboardingScreen> createState() =>
      _AdvisorOnboardingScreenState();
}

class _StressOption {
  const _StressOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _AdvisorOnboardingScreenState extends State<AdvisorOnboardingScreen> {
  final PageController _pageController = PageController();
  final AnalyticsService _analytics = AnalyticsService();
  static const String _onboardingExperimentName = 'mini_onboarding_v4';
  int _currentStep = 0;

  // Answers
  String? _stressChoice;
  String? _canton;
  String? _employmentStatus;
  String? _householdType;
  String? _mainGoal;

  // Controllers
  final _birthYearController = TextEditingController();
  final _incomeController = TextEditingController();
  final _taxProvisionController = TextEditingController();
  final _lamalController = TextEditingController();
  final _otherFixedController = TextEditingController();

  // Saved wizard progress
  bool _hasSavedWizardProgress = false;
  int _savedWizardProgress = 0;

  // Canton list (sorted by name)
  late final List<MapEntry<String, CantonProfile>> _sortedCantons;
  late final DateTime _onboardingStartedAt;
  final Map<int, DateTime> _stepEnteredAt = {};
  bool _isOnboardingCompleted = false;
  String _miniOnboardingVariant = 'control';
  bool _usedBirthYearPreset = false;
  bool _usedIncomePreset = false;
  bool _usedBirthYearManual = false;
  bool _usedIncomeManual = false;
  bool _step2AhaTracked = false;
  bool _cohortStartedTracked = false;
  Map<String, int> _variantMetrics = const {};
  Timer? _autoSaveDebounce;
  DateTime? _lastAutoSaveAt;
  bool get _isInternalDebugEnabled => kDebugMode;

  void _incMetric(String key, {int by = 1}) {
    unawaited(() async {
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        _miniOnboardingVariant,
        key,
        by: by,
      );
      await _refreshVariantMetrics();
    }());
  }

  Future<void> _refreshVariantMetrics() async {
    final metrics = await ReportPersistenceService.loadMiniOnboardingMetrics(
      _miniOnboardingVariant,
    );
    if (!mounted) return;
    setState(() => _variantMetrics = metrics);
  }

  @override
  void initState() {
    super.initState();
    _onboardingStartedAt = DateTime.now();
    _stepEnteredAt[0] = _onboardingStartedAt;
    _analytics.trackScreenView('/advisor');
    _initExperimentContext();
    _sortedCantons = CantonalDataService.cantons.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    _checkSavedProgress();
  }

  Future<void> _initExperimentContext() async {
    try {
      final variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      final exposureTracked =
          await ReportPersistenceService.isMiniOnboardingExposureTracked();
      if (!mounted) return;
      setState(() => _miniOnboardingVariant = variant);
      await _refreshVariantMetrics();
      _analytics.trackOnboardingStarted(data: _onboardingContextData());
      _incMetric('started');
      if (!exposureTracked) {
        _analytics.trackExperimentExposure(
          _onboardingExperimentName,
          variant,
          screenName: '/advisor',
        );
        await ReportPersistenceService.setMiniOnboardingExposureTracked(true);
      }
    } catch (_) {
      _analytics.trackOnboardingStarted(data: _onboardingContextData());
      _incMetric('started');
    }
  }

  Map<String, dynamic> _onboardingContextData() {
    return {
      'experiment': _onboardingExperimentName,
      'variant': _miniOnboardingVariant,
    };
  }

  Map<String, dynamic> _withOnboardingContext([Map<String, dynamic>? data]) {
    return {
      ..._onboardingContextData(),
      if (data != null) ...data,
    };
  }

  String _incomeBucket(double? incomeMonthly) {
    if (incomeMonthly == null || incomeMonthly <= 0) return 'inc_unknown';
    if (incomeMonthly <= 5000) return 'inc_low';
    if (incomeMonthly <= 9000) return 'inc_mid';
    return 'inc_high';
  }

  String _profileCohortBucket() {
    final income = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    final stress = _stressChoice ?? 'unknown';
    final employment = _employmentStatus ?? 'unknown';
    final household = _householdType ?? 'unknown';
    return 'stress_$stress|emp_$employment|house_$household|${_incomeBucket(income)}';
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    if (!_isOnboardingCompleted) {
      unawaited(_saveMiniProgressSnapshot(reason: 'dispose_abandon'));
      _incMetric('abandoned');
      final elapsedSeconds =
          DateTime.now().difference(_onboardingStartedAt).inSeconds;
      _analytics.trackEvent(
        'onboarding_abandoned',
        category: 'engagement',
        data: _withOnboardingContext({
          'step': _currentStep + 1,
          'step_name': _stepName(_currentStep),
          'elapsed_seconds': elapsedSeconds,
        }),
      );
    }
    _pageController.dispose();
    _birthYearController.dispose();
    _incomeController.dispose();
    _taxProvisionController.dispose();
    _lamalController.dispose();
    _otherFixedController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedProgress() async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isNotEmpty && mounted) {
      _hydrateFromSavedAnswers(savedAnswers);
      setState(() {
        _hasSavedWizardProgress = true;
        _savedWizardProgress =
            ((savedAnswers.length / 24) * 100).round().clamp(0, 99);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetStep = _computeResumeStep();
        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetStep);
        }
        setState(() => _currentStep = targetStep);
        _maybeTrackStep2Aha();
      });
    }
  }

  void _hydrateFromSavedAnswers(Map<String, dynamic> answers) {
    final stress = answers['q_financial_stress_check'] as String?;
    final birthYear = answers['q_birth_year'];
    final canton = answers['q_canton'] as String?;
    final income = answers['q_net_income_period_chf'];
    final birthYearDraft = answers['mini_draft_birth_year'];
    final incomeDraft = answers['mini_draft_income'];
    final taxProvision = answers['q_tax_provision_monthly_chf'];
    final lamal = answers['q_lamal_premium_monthly_chf'];
    final otherFixed = answers['q_other_fixed_costs_monthly_chf'];
    final taxProvisionDraft = answers['mini_draft_tax_provision'];
    final lamalDraft = answers['mini_draft_lamal'];
    final otherFixedDraft = answers['mini_draft_other_fixed'];
    final employment = answers['q_employment_status'] as String?;
    final household = answers['q_household_type'] as String?;
    final civilStatus = answers['q_civil_status'] as String?;
    final childrenRaw = answers['q_children'];
    final goal = answers['q_main_goal'] as String?;

    _stressChoice = stress ?? _stressChoice;
    _canton = canton ?? _canton;
    _employmentStatus = employment ?? _employmentStatus;
    _householdType = household ?? _householdType;
    _mainGoal = goal ?? _mainGoal;
    if (_householdType == null && civilStatus != null) {
      if (civilStatus == 'married' || civilStatus == 'concubinage') {
        final children = childrenRaw is num
            ? childrenRaw.toInt()
            : int.tryParse(childrenRaw?.toString() ?? '');
        _householdType = (children ?? 0) > 0 ? 'family' : 'couple';
      } else {
        _householdType = 'single';
      }
    }

    if (birthYear != null || birthYearDraft != null) {
      final source = birthYear ?? birthYearDraft;
      final parsedBirthYear =
          source is num ? source.toInt().toString() : source.toString();
      _birthYearController.text = parsedBirthYear;
    }

    if (income != null || incomeDraft != null) {
      final source = income ?? incomeDraft;
      final parsedIncome =
          source is num ? source.toInt().toString() : source.toString();
      _incomeController.text = parsedIncome;
    }
    if (taxProvision != null || taxProvisionDraft != null) {
      final source = taxProvision ?? taxProvisionDraft;
      final parsed =
          source is num ? source.toInt().toString() : source.toString();
      _taxProvisionController.text = parsed;
    }
    if (lamal != null || lamalDraft != null) {
      final source = lamal ?? lamalDraft;
      final parsed =
          source is num ? source.toInt().toString() : source.toString();
      _lamalController.text = parsed;
    }
    if (otherFixed != null || otherFixedDraft != null) {
      final source = otherFixed ?? otherFixedDraft;
      final parsed =
          source is num ? source.toInt().toString() : source.toString();
      _otherFixedController.text = parsed;
    }
  }

  int _computeResumeStep() {
    final step1Done = _stressChoice != null;
    final step2Done = _birthYearController.text.length == 4 && _canton != null;
    final parsedIncome = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    final step3Done = (parsedIncome ?? 0) > 0 &&
        _employmentStatus != null &&
        _householdType != null;
    final step4Done = _mainGoal != null;

    if (!step1Done) return 0;
    if (!step2Done) return 1;
    if (!step3Done) return 2;
    if (!step4Done) return 3;
    return 3;
  }

  String _suggestGoalFromStress() {
    switch (_stressChoice) {
      case 'budget':
      case 'debt':
        return 'debt_free';
      case 'tax':
        return 'real_estate';
      case 'pension':
        return 'retirement';
      default:
        return 'retirement';
    }
  }

  void _goToStep(int step) {
    if (step == _currentStep) return;
    _trackStepTransition(from: _currentStep, to: step);
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      _handleClosePressed();
    }
  }

  void _trackStepTransition({required int from, required int to}) {
    final now = DateTime.now();
    final enteredAt = _stepEnteredAt[from];
    final stepDuration =
        enteredAt != null ? now.difference(enteredAt).inSeconds : null;

    _analytics.trackOnboardingStep(
      from + 1,
      _stepName(from),
      totalSteps: 4,
      data: _onboardingContextData(),
    );
    _incMetric('step_${from + 1}');
    if (stepDuration != null && stepDuration > 0) {
      _incMetric('duration_step_${from + 1}_sum', by: stepDuration);
      _incMetric('duration_step_${from + 1}_count');
    }
    if (from == 1 && to == 2 && _step2AhaTracked) {
      _incMetric('step2_to_step3_after_aha');
    }
    if (from == 2 && to == 3 && !_cohortStartedTracked) {
      _cohortStartedTracked = true;
      final bucket = _profileCohortBucket();
      unawaited(
        ReportPersistenceService.incrementMiniOnboardingCohortMetric(
          _miniOnboardingVariant,
          bucket,
          'started',
        ),
      );
    }
    _analytics.trackEvent(
      'onboarding_step_duration',
      category: 'engagement',
      data: _withOnboardingContext({
        'step': from + 1,
        'step_name': _stepName(from),
        if (stepDuration != null) 'duration_seconds': stepDuration,
      }),
    );

    _stepEnteredAt[to] = now;
    unawaited(_saveMiniProgressSnapshot(reason: 'step_transition'));
  }

  Future<void> _saveMiniProgressSnapshot({required String reason}) async {
    if (_isOnboardingCompleted) return;
    final snapshot = _currentMiniAnswersSnapshot();
    if (snapshot.isEmpty) return;
    final existing = await ReportPersistenceService.loadAnswers();
    final merged = {...existing, ...snapshot};
    await ReportPersistenceService.saveAnswers(merged);
    _analytics.trackEvent(
      'onboarding_progress_saved',
      category: 'engagement',
      data: _withOnboardingContext({
        'reason': reason,
        'keys_count': snapshot.length,
        'step': _currentStep + 1,
      }),
    );
  }

  Map<String, dynamic> _currentMiniAnswersSnapshot() {
    final parsedBirthYear = int.tryParse(_birthYearController.text);
    final parsedIncome = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    final taxProvision = _parseChfController(_taxProvisionController);
    final lamal = _parseChfController(_lamalController);
    final otherFixed = _parseChfController(_otherFixedController);
    final snapshot = <String, dynamic>{};
    if (_stressChoice != null) {
      snapshot['q_financial_stress_check'] = _stressChoice;
    }
    final currentYear = DateTime.now().year;
    final isBirthYearValid = parsedBirthYear != null &&
        parsedBirthYear >= 1940 &&
        parsedBirthYear <= currentYear - 16;
    if (isBirthYearValid) {
      snapshot['q_birth_year'] = parsedBirthYear;
    }
    if (_canton != null) {
      snapshot['q_canton'] = _canton;
    }
    if (parsedIncome != null && parsedIncome > 0) {
      snapshot['q_net_income_period_chf'] = parsedIncome;
    }
    if (_employmentStatus != null) {
      snapshot['q_employment_status'] = _employmentStatus;
    }
    final household = _householdType ?? 'single';
    snapshot['q_household_type'] = household;
    snapshot['q_civil_status'] = _civilStatusForHousehold(household);
    snapshot['q_children'] = _childrenCountFromHousehold(household);
    if (taxProvision != null && taxProvision > 0) {
      snapshot['q_tax_provision_monthly_chf'] = taxProvision;
    }
    if (lamal != null && lamal > 0) {
      snapshot['q_lamal_premium_monthly_chf'] = lamal;
    }
    if (otherFixed != null && otherFixed > 0) {
      snapshot['q_other_fixed_costs_monthly_chf'] = otherFixed;
    }
    if (_mainGoal != null) {
      snapshot['q_main_goal'] = _mainGoal;
    }
    if (_birthYearController.text.trim().isNotEmpty) {
      snapshot['mini_draft_birth_year'] = _birthYearController.text.trim();
    }
    if (_incomeController.text.trim().isNotEmpty) {
      snapshot['mini_draft_income'] = _incomeController.text.trim();
    }
    if (_taxProvisionController.text.trim().isNotEmpty) {
      snapshot['mini_draft_tax_provision'] =
          _taxProvisionController.text.trim();
    }
    if (_lamalController.text.trim().isNotEmpty) {
      snapshot['mini_draft_lamal'] = _lamalController.text.trim();
    }
    if (_otherFixedController.text.trim().isNotEmpty) {
      snapshot['mini_draft_other_fixed'] = _otherFixedController.text.trim();
    }
    if (_employmentStatus == 'employee' &&
        parsedIncome != null &&
        parsedIncome * 12 > 22680) {
      snapshot['q_has_pension_fund'] = 'yes';
    }
    return snapshot;
  }

  void _scheduleAutoSave([String reason = 'field_change']) {
    if (_isOnboardingCompleted) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      final now = DateTime.now();
      final last = _lastAutoSaveAt;
      if (last != null && now.difference(last).inMilliseconds < 800) return;
      _lastAutoSaveAt = now;
      unawaited(_saveMiniProgressSnapshot(reason: reason));
    });
  }

  Future<void> _handleClosePressed() async {
    if (_isOnboardingCompleted) {
      if (mounted) context.pop();
      return;
    }
    if (_currentStep == 0) {
      await _closeAndTrack();
      return;
    }

    final l10n = S.of(context);
    _analytics.trackEvent(
      'onboarding_exit_prompt_shown',
      category: 'engagement',
      data: _withOnboardingContext({'step': _currentStep + 1}),
    );
    _incMetric('exit_prompt_shown');
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isChallenge = _miniOnboardingVariant == 'challenge';
        return AlertDialog(
          title: Text(
            l10n?.advisorMiniExitTitle ?? 'Tu quittes maintenant ?',
          ),
          content: Text(
            isChallenge
                ? (l10n?.advisorMiniExitBodyChallenge ??
                    'Encore quelques secondes et tu obtiens ta trajectoire personnalisée.')
                : (l10n?.advisorMiniExitBodyControl ??
                    'Ta progression est sauvegardée. Tu peux reprendre plus tard.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                l10n?.advisorMiniExitStay ?? 'Continuer',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n?.advisorMiniExitLeave ?? 'Quitter',
              ),
            ),
          ],
        );
      },
    );
    if (leave == true) {
      _analytics.trackEvent(
        'onboarding_exit_prompt_action',
        category: 'engagement',
        data: _withOnboardingContext({'action': 'leave'}),
      );
      _incMetric('exit_prompt_leave');
      await _saveMiniProgressSnapshot(reason: 'exit_prompt_leave');
      await _closeAndTrack();
    } else {
      _analytics.trackEvent(
        'onboarding_exit_prompt_action',
        category: 'engagement',
        data: _withOnboardingContext({'action': 'stay'}),
      );
      _incMetric('exit_prompt_stay');
    }
  }

  Future<void> _closeAndTrack() async {
    final elapsedSeconds =
        DateTime.now().difference(_onboardingStartedAt).inSeconds;
    _analytics.trackEvent(
      'onboarding_closed',
      category: 'engagement',
      data: _withOnboardingContext({
        'step': _currentStep + 1,
        'step_name': _stepName(_currentStep),
        'elapsed_seconds': elapsedSeconds,
      }),
    );
    if (mounted) context.pop();
  }

  String _stepName(int index) {
    switch (index) {
      case 0:
        return 'stress';
      case 1:
        return 'essentials';
      case 2:
        return 'income_status';
      case 3:
        return 'goal_preview';
      default:
        return 'unknown';
    }
  }

  Future<void> _completeMiniOnboarding() async {
    // Parse inputs
    final birthYear = int.tryParse(_birthYearController.text);
    final income = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    final taxProvision = _parseChfController(_taxProvisionController);
    final lamal = _parseChfController(_lamalController);
    final otherFixed = _parseChfController(_otherFixedController);

    if (_stressChoice == null ||
        birthYear == null ||
        _validateBirthYear(_birthYearController.text) != null ||
        _canton == null ||
        income == null ||
        _mainGoal == null) {
      return;
    }

    // Resolve employment status (default: employee)
    final empStatus = _employmentStatus ?? 'employee';
    final household = _householdType ?? 'single';

    // Build answers map (compatible with wizard question IDs)
    final answers = <String, dynamic>{
      'q_financial_stress_check': _stressChoice,
      'q_birth_year': birthYear,
      'q_canton': _canton,
      'q_net_income_period_chf': income,
      'q_employment_status': empStatus,
      'q_household_type': household,
      'q_civil_status': _civilStatusForHousehold(household),
      'q_children': _childrenCountFromHousehold(household),
      'q_main_goal': _mainGoal ?? 'retirement',
      if (taxProvision != null && taxProvision > 0)
        'q_tax_provision_monthly_chf': taxProvision,
      if (lamal != null && lamal > 0) 'q_lamal_premium_monthly_chf': lamal,
      if (otherFixed != null && otherFixed > 0)
        'q_other_fixed_costs_monthly_chf': otherFixed,
    };

    // Auto-infer LPP for employees above threshold (LPP art. 7)
    if (empStatus == 'employee' && income * 12 > 22680) {
      answers['q_has_pension_fund'] = 'yes';
    }

    // Merge with existing wizard answers (don't overwrite prior progress)
    final existing = await ReportPersistenceService.loadAnswers();
    final merged = {...existing, ...answers};
    await ReportPersistenceService.saveAnswers(merged);
    await ReportPersistenceService.setMiniOnboardingCompleted(true);

    // Create partial profile
    if (mounted) {
      final now = DateTime.now();
      final enteredAt = _stepEnteredAt[3];
      final step4Duration =
          enteredAt != null ? now.difference(enteredAt).inSeconds : null;
      final totalDuration = now.difference(_onboardingStartedAt).inSeconds;
      _analytics.trackOnboardingStep(
        4,
        _stepName(3),
        totalSteps: 4,
        data: _onboardingContextData(),
      );
      _incMetric('step_4');
      _analytics.trackEvent(
        'onboarding_step_duration',
        category: 'engagement',
        data: _withOnboardingContext({
          'step': 4,
          'step_name': _stepName(3),
          if (step4Duration != null) 'duration_seconds': step4Duration,
        }),
      );
      if (step4Duration != null && step4Duration > 0) {
        _incMetric('duration_step_4_sum', by: step4Duration);
        _incMetric('duration_step_4_count');
      }
      _analytics.trackOnboardingCompleted(
        timeSpentSeconds: totalDuration,
        data: _withOnboardingContext({
          'used_birth_year_preset': _usedBirthYearPreset,
          'used_income_preset': _usedIncomePreset,
          'used_birth_year_manual': _usedBirthYearManual,
          'used_income_manual': _usedIncomeManual,
        }),
      );
      _incMetric('completed');
      if (_cohortStartedTracked) {
        unawaited(
          ReportPersistenceService.incrementMiniOnboardingCohortMetric(
            _miniOnboardingVariant,
            _profileCohortBucket(),
            'completed',
          ),
        );
      }
      _isOnboardingCompleted = true;
      context.read<CoachProfileProvider>().updateFromMiniOnboarding(merged);
      final preview = _computePreviewProjection();
      final action = await _showCompletionSheet(preview);
      if (!mounted) return;
      if (action == 'wizard') {
        _analytics.trackCTAClick(
          'advisor_completion_full_diagnostic',
          screenName: '/advisor',
          data: _onboardingContextData(),
        );
        context.push('/advisor/wizard');
      } else if (action == 'plan30') {
        _analytics.trackCTAClick(
          'advisor_completion_open_plan_30_days',
          screenName: '/advisor',
          data: _withOnboardingContext({
            'stress_choice': _stressChoice,
            'main_goal': _mainGoal ?? 'retirement',
          }),
        );
        context.go(
          '/advisor/plan-30-days',
          extra: {
            'stress_choice': _stressChoice,
            'main_goal': _mainGoal ?? 'retirement',
          },
        );
      } else {
        _analytics.trackCTAClick(
          'advisor_completion_open_dashboard',
          screenName: '/advisor',
          data: _onboardingContextData(),
        );
        context.go('/home');
      }
    }
  }

  Future<String?> _showCompletionSheet(Map<String, dynamic>? preview) {
    final l10n = S.of(context);
    final baseValue = preview?['base'] as double?;
    final yearsLeft = preview?['yearsLeft'];
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rocket_launch_outlined,
                          color: MintColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n?.coachTrajectory ?? 'Ta trajectoire',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (yearsLeft != null)
                  Text(
                    l10n?.advisorMiniPreviewSubtitle('$yearsLeft') ??
                        'Projection indicative sur ~$yearsLeft ans',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                if (baseValue != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MintColors.coachBubble,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MintColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n?.advisorMiniPreviewBase ?? 'Base',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          ForecasterService.formatChf(baseValue),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MintColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('plan30'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Voir mon plan 30 jours',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('dashboard'),
                    child: Text(
                      l10n?.advisorMiniActivateDashboard ??
                          'Activer mon dashboard',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleClosePressed();
      },
      child: Scaffold(
        backgroundColor: MintColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with back/close + step indicator
              _buildTopBar(),

              // Step indicator dots
              _buildStepIndicator(),
              _buildEtaHint(),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _buildStep1StressCheck(),
                    _buildStep2Essentials(),
                    _buildStep3Income(),
                    _buildStep4GoalAndPreview(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateBirthYear(String value) {
    final l10n = S.of(context);
    if (value.length != 4) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return l10n?.advisorMiniBirthYearInvalid ?? 'Année invalide';
    }
    final currentYear = DateTime.now().year;
    if (parsed < 1940 || parsed > currentYear - 16) {
      return l10n?.advisorMiniBirthYearRange('${currentYear - 16}') ??
          'Entre 1940 et ${currentYear - 16}';
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final l10n = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: MintColors.textPrimary,
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          // Step label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n?.onboardingProgress('${_currentStep + 1}', '4') ??
                  '${_currentStep + 1}/4',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.insights_outlined, size: 20),
                color: MintColors.textMuted,
                onPressed: _isInternalDebugEnabled
                    ? _showOnboardingMetricsPanel
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                color: MintColors.textMuted,
                onPressed: _handleClosePressed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showOnboardingMetricsPanel() async {
    if (!_isInternalDebugEnabled) return;
    final l10n = S.of(context);
    final control =
        await ReportPersistenceService.loadMiniOnboardingMetrics('control');
    final challenge =
        await ReportPersistenceService.loadMiniOnboardingMetrics('challenge');
    final cohorts =
        await ReportPersistenceService.loadMiniOnboardingCohortMetrics();
    final cohortCsv =
        await ReportPersistenceService.exportMiniOnboardingCohortCsv();
    final cohortJson = jsonEncode(cohorts);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.advisorMiniMetricsTitle ?? 'Onboarding Metrics',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.advisorMiniMetricsSubtitle ??
                        'Pilotage local des variantes control/challenge',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetricsVariantCard(
                    title: l10n?.advisorMiniMetricsControl ?? 'Control',
                    metrics: control,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricsVariantCard(
                    title: l10n?.advisorMiniMetricsChallenge ?? 'Challenge',
                    metrics: challenge,
                  ),
                  const SizedBox(height: 10),
                  _buildCohortSummaryCard(cohorts),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: cohortCsv),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('CSV cohortes copié'),
                              ),
                            );
                          },
                          icon:
                              const Icon(Icons.table_chart_outlined, size: 16),
                          label: const Text('Copier CSV'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: cohortJson),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('JSON cohortes copié'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.code_outlined, size: 16),
                          label: const Text('Copier JSON'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await ReportPersistenceService
                            .clearMiniOnboardingMetrics();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(
                        l10n?.advisorMiniMetricsReset ?? 'Reset metrics',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _computeOnboardingQualityScore(Map<String, int> metrics) {
    final started = metrics['started'] ?? 0;
    final completed = metrics['completed'] ?? 0;
    final exitsShown = metrics['exit_prompt_shown'] ?? 0;
    final exitsStay = metrics['exit_prompt_stay'] ?? 0;
    final ahaShown = metrics['step2_aha_shown'] ?? 0;
    final ahaToStep3 = metrics['step2_to_step3_after_aha'] ?? 0;
    final quickBirth = metrics['quick_pick_birth_year'] ?? 0;
    final quickIncome = metrics['quick_pick_income'] ?? 0;
    final durationSum = (metrics['duration_step_1_sum'] ?? 0) +
        (metrics['duration_step_2_sum'] ?? 0) +
        (metrics['duration_step_3_sum'] ?? 0) +
        (metrics['duration_step_4_sum'] ?? 0);
    final durationCount = (metrics['duration_step_1_count'] ?? 0) +
        (metrics['duration_step_2_count'] ?? 0) +
        (metrics['duration_step_3_count'] ?? 0) +
        (metrics['duration_step_4_count'] ?? 0);

    final completion = started > 0 ? completed / started : 0.0; // 0..1
    final stayRate = exitsShown > 0 ? exitsStay / exitsShown : 0.0;
    final ahaRate = ahaShown > 0 ? ahaToStep3 / ahaShown : 0.0;
    final quickRate = started > 0 ? (quickBirth + quickIncome) / started : 0.0;
    final avgStep = durationCount > 0 ? (durationSum / durationCount) : 999.0;
    final speedScore = avgStep <= 20
        ? 1.0
        : avgStep <= 35
            ? 0.7
            : avgStep <= 55
                ? 0.4
                : 0.2;

    final score = (completion * 45) +
        (stayRate * 20) +
        (ahaRate * 15) +
        (quickRate.clamp(0, 1) * 10) +
        (speedScore * 10);
    return score.clamp(0, 100).toDouble();
  }

  Widget _buildCohortSummaryCard(Map<String, dynamic> cohorts) {
    final control =
        Map<String, dynamic>.from((cohorts['control'] as Map?) ?? const {});
    final challenge =
        Map<String, dynamic>.from((cohorts['challenge'] as Map?) ?? const {});

    int started(Map<String, dynamic> variant) {
      var total = 0;
      for (final value in variant.values) {
        if (value is Map) {
          total += (value['started'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }

    int completed(Map<String, dynamic> variant) {
      var total = 0;
      for (final value in variant.values) {
        if (value is Map) {
          total += (value['completed'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }

    String rate(int done, int total) {
      if (total <= 0) return '0%';
      return '${((done / total) * 100).toStringAsFixed(1)}%';
    }

    final controlStarted = started(control);
    final controlCompleted = completed(control);
    final challengeStarted = started(challenge);
    final challengeCompleted = completed(challenge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cohortes (A/B + profil)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _metricRow(
              'Control completion', rate(controlCompleted, controlStarted)),
          _metricRow('Challenge completion',
              rate(challengeCompleted, challengeStarted)),
          _metricRow('Control started', '$controlStarted'),
          _metricRow('Challenge started', '$challengeStarted'),
        ],
      ),
    );
  }

  Widget _buildMetricsVariantCard({
    required String title,
    required Map<String, int> metrics,
  }) {
    final l10n = S.of(context);
    final started = metrics['started'] ?? 0;
    final completed = metrics['completed'] ?? 0;
    final exitsShown = metrics['exit_prompt_shown'] ?? 0;
    final exitsStay = metrics['exit_prompt_stay'] ?? 0;
    final ahaShown = metrics['step2_aha_shown'] ?? 0;
    final ahaToStep3 = metrics['step2_to_step3_after_aha'] ?? 0;
    final quickBirth = metrics['quick_pick_birth_year'] ?? 0;
    final quickIncome = metrics['quick_pick_income'] ?? 0;
    final durationSum = (metrics['duration_step_1_sum'] ?? 0) +
        (metrics['duration_step_2_sum'] ?? 0) +
        (metrics['duration_step_3_sum'] ?? 0) +
        (metrics['duration_step_4_sum'] ?? 0);
    final durationCount = (metrics['duration_step_1_count'] ?? 0) +
        (metrics['duration_step_2_count'] ?? 0) +
        (metrics['duration_step_3_count'] ?? 0) +
        (metrics['duration_step_4_count'] ?? 0);
    final avgStep = durationCount <= 0
        ? '-'
        : '${(durationSum / durationCount).toStringAsFixed(1)}s';
    final qualityScore = _computeOnboardingQualityScore(metrics);
    final step1 = metrics['step_1'] ?? 0;
    final step2 = metrics['step_2'] ?? 0;
    final step3 = metrics['step_3'] ?? 0;
    final avgStep1 = _avgStepDuration(metrics, 1);
    final avgStep2 = _avgStepDuration(metrics, 2);
    final avgStep3 = _avgStepDuration(metrics, 3);
    final avgStep4 = _avgStepDuration(metrics, 4);

    String pct(int num, int den) {
      if (den <= 0) return '0%';
      return '${((num / den) * 100).toStringAsFixed(1)}%';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _metricRow(
            l10n?.advisorMiniMetricsStarts ?? 'Starts',
            '$started',
          ),
          _metricRow(
            l10n?.advisorMiniMetricsCompletionRate ?? 'Completion rate',
            pct(completed, started),
          ),
          _metricRow(
            l10n?.advisorMiniMetricsExitStayRate ?? 'Exit stay rate',
            pct(exitsStay, exitsShown),
          ),
          _metricRow(
            l10n?.advisorMiniMetricsAhaToStep3 ?? 'Step2 A-ha -> Step3',
            pct(ahaToStep3, ahaShown),
          ),
          _metricRow(
            l10n?.advisorMiniMetricsQuickPicks ?? 'Quick picks',
            '${quickBirth + quickIncome}',
          ),
          _metricRow(
            l10n?.advisorMiniMetricsAvgStepTime ?? 'Avg step time',
            avgStep,
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qualite par step',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _metricRow(
                  'S1 -> S2',
                  '${pct(step1, started)} · $avgStep1',
                ),
                _metricRow(
                  'S2 -> S3',
                  '${pct(step2, step1)} · $avgStep2',
                ),
                _metricRow(
                  'S3 -> S4',
                  '${pct(step3, step2)} · $avgStep3',
                ),
                _metricRow(
                  'S4 -> Done',
                  '${pct(completed, step3)} · $avgStep4',
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded,
                    size: 16, color: MintColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qualite onboarding',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${qualityScore.toStringAsFixed(1)}/100',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _avgStepDuration(Map<String, int> metrics, int step) {
    final sum = metrics['duration_step_${step}_sum'] ?? 0;
    final count = metrics['duration_step_${step}_count'] ?? 0;
    if (count <= 0) return '-';
    return '${(sum / count).toStringAsFixed(1)}s';
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  int _avgStepDurationSeconds(int step) {
    final sum = _variantMetrics['duration_step_${step}_sum'] ?? 0;
    final count = _variantMetrics['duration_step_${step}_count'] ?? 0;
    if (count <= 0) {
      const fallback = {1: 18, 2: 22, 3: 24, 4: 20};
      return fallback[step] ?? 20;
    }
    return (sum / count).round().clamp(5, 90);
  }

  int _estimateRemainingSeconds() {
    if (_currentStep >= 3) return 0;
    final current = _currentStep + 1;
    int total = 0;
    for (int step = current + 1; step <= 4; step++) {
      total += _avgStepDurationSeconds(step);
    }
    total += (_avgStepDurationSeconds(current) / 2).round();
    return total;
  }

  Widget _buildEtaHint() {
    final l10n = S.of(context);
    final eta = _estimateRemainingSeconds();
    final starts = _variantMetrics['started'] ?? 0;
    final confidence = starts >= 10
        ? (l10n?.advisorMiniEtaConfidenceHigh ?? 'Confiance haute')
        : (l10n?.advisorMiniEtaConfidenceLow ?? 'Confiance moyenne');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                size: 16, color: MintColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n?.advisorMiniEtaLabel('$eta') ??
                    'Temps restant estimé: ${eta}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              confidence,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP INDICATOR DOTS
  // ════════════════════════════════════════════════════════════════

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDone
                  ? MintColors.primary
                  : isActive
                      ? MintColors.primary
                      : MintColors.lightBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 1 : STRESS CHECK
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep1StressCheck() {
    final l10n = S.of(context);
    final options = _stressOptionsForVariant(l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n?.advisorMiniStep1Title ?? 'Quelle est ta priorite ?',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.advisorMiniStep1Subtitle ??
                'MINT s\'adapte a ce qui compte pour toi maintenant',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          for (int i = 0; i < options.length; i++) ...[
            _buildStressCard(
              icon: options[i].icon,
              label: options[i].label,
              value: options[i].value,
              color: options[i].color,
            ),
            if (i < options.length - 1) const SizedBox(height: 12),
          ],
          if (_stressChoice != null) ...[
            const SizedBox(height: 14),
            _buildStepReadyHint(
              title: l10n?.advisorMiniReadyTitle ?? 'Validation',
              body: l10n?.advisorMiniReadyStep1 ??
                  'Priorité enregistrée. On personnalise la trajectoire.',
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _stressChoice != null ? () => _goToStep(1) : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.textPrimary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n?.onboardingContinue ?? 'Suivant',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Secondary option (single path to limit decision overload)
          Center(
            child: _hasSavedWizardProgress
                ? TextButton.icon(
                    onPressed: () {
                      _analytics.trackCTAClick('advisor_resume_full_diagnostic',
                          screenName: '/advisor');
                      context.push('/advisor/wizard');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      l10n?.advisorMiniResumeDiagnostic(
                              '$_savedWizardProgress') ??
                          'Reprendre mon diagnostic ($_savedWizardProgress%)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: MintColors.primary,
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      _analytics.trackCTAClick('advisor_full_diagnostic_step1',
                          screenName: '/advisor');
                      context.push('/advisor/wizard');
                    },
                    child: Text(
                      l10n?.advisorMiniFullDiagnostic ??
                          'Diagnostic complet (10 min)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<_StressOption> _stressOptionsForVariant(S? l10n) {
    final options = [
      _StressOption(
        icon: Icons.savings_outlined,
        label: l10n?.advisorMiniStressBudget ?? 'Maitriser mon budget',
        value: 'budget',
        color: const Color(0xFF10B981),
      ),
      _StressOption(
        icon: Icons.money_off_outlined,
        label: l10n?.advisorMiniStressDebt ?? 'Reduire mes dettes',
        value: 'debt',
        color: const Color(0xFFEF4444),
      ),
      _StressOption(
        icon: Icons.account_balance_outlined,
        label: l10n?.advisorMiniStressTax ?? 'Optimiser mes impots',
        value: 'tax',
        color: const Color(0xFF6366F1),
      ),
      _StressOption(
        icon: Icons.beach_access_outlined,
        label: l10n?.advisorMiniStressRetirement ?? 'Securiser ma retraite',
        value: 'pension',
        color: const Color(0xFF0EA5E9),
      ),
    ];

    if (_miniOnboardingVariant != 'challenge') {
      return options;
    }

    return [
      options[1], // debt first in challenge variant
      options[3], // then pension
      options[0], // then budget
      options[2], // then tax
    ];
  }

  Widget _buildStressCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = _stressChoice == value;

    return GestureDetector(
      onTap: () {
        setState(() => _stressChoice = value);
        _scheduleAutoSave('stress_selected');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isSelected ? color : MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 2 : AGE + CANTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep2Essentials() {
    final l10n = S.of(context);
    final birthYearError = _validateBirthYear(_birthYearController.text);
    final canGoNext = birthYearError == null &&
        _birthYearController.text.length == 4 &&
        _canton != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n?.advisorMiniStep2Title ?? 'L\'essentiel',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.advisorMiniStep2Subtitle ??
                'Age et canton changent tout en Suisse',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Birth year
          Text(
            l10n?.advisorMiniBirthYearLabel ?? 'Annee de naissance',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.advisorMiniQuickPickLabel ?? 'Choix rapide',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _birthYearQuickPicks().map((year) {
              return _buildQuickChoiceChip(
                label: '$year',
                isSelected: _birthYearController.text == '$year',
                onTap: () => _applyBirthYearQuickPick(year),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _birthYearController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (_) {
              _usedBirthYearManual = true;
              _maybeTrackStep2Aha();
              setState(() {});
              _scheduleAutoSave('birth_year_changed');
            },
            decoration: InputDecoration(
              hintText: '1990',
              hintStyle: TextStyle(
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 2),
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          if (birthYearError != null) ...[
            const SizedBox(height: 8),
            Text(
              birthYearError,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.error,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Canton
          Text(
            l10n?.advisorMiniCantonLabel ?? 'Canton de residence',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: DropdownButtonFormField<String>(
              value: _canton,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: InputBorder.none,
                hintText: l10n?.advisorMiniCantonHint ?? 'Selectionner',
                hintStyle: TextStyle(
                  color: MintColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: MintColors.textMuted),
              items: _sortedCantons.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.value.name} (${entry.key})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _canton = value);
                _maybeTrackStep2Aha();
                _scheduleAutoSave('canton_changed');
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_computeStep2AhaData() case final aha?) _buildStep2AhaCard(aha),
          if (canGoNext) ...[
            const SizedBox(height: 10),
            _buildStepReadyHint(
              title: l10n?.advisorMiniReadyTitle ?? 'Validation',
              body: l10n?.advisorMiniReadyStep2 ??
                  'Base fiscale prête. Le contexte cantonal est calibré.',
            ),
          ],

          const SizedBox(height: 40),

          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canGoNext ? () => _goToStep(2) : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.textPrimary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n?.onboardingContinue ?? 'Suivant',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 3 : INCOME + STATUS
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep3Income() {
    final l10n = S.of(context);
    final hasIncome = _incomeController.text.isNotEmpty &&
        (double.tryParse(_incomeController.text
                    .replaceAll("'", '')
                    .replaceAll(' ', '')) ??
                0) >
            0;
    final canContinue =
        hasIncome && _employmentStatus != null && _householdType != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n?.advisorMiniStep3Title ?? 'Ton revenu',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.advisorMiniStep3Subtitle ??
                'Pour calculer ton potentiel d\'economie',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Monthly net income
          Text(
            l10n?.advisorMiniIncomeLabel ?? 'Revenu net mensuel (CHF)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.advisorMiniQuickPickIncomeLabel ?? 'Montants frequents',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _incomeQuickPicks().map((amount) {
              return _buildQuickChoiceChip(
                label: 'CHF ${amount.toString()}',
                isSelected: _incomeController.text == '$amount',
                onTap: () => _applyIncomeQuickPick(amount),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (_) {
              _usedIncomeManual = true;
              setState(() {});
              _scheduleAutoSave('income_changed');
            },
            decoration: InputDecoration(
              hintText: '5000',
              prefixText: 'CHF  ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
              hintStyle: TextStyle(
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 2),
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),

          const SizedBox(height: 28),

          // Employment status
          Text(
            l10n?.advisorMiniEmploymentLabel ?? 'Statut professionnel',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusChip(
            label: l10n?.advisorMiniEmploymentEmployee ?? 'Salarie\u00B7e',
            value: 'employee',
            icon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label:
                l10n?.advisorMiniEmploymentSelfEmployed ?? 'Independant\u00B7e',
            value: 'self_employed',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label: l10n?.advisorMiniEmploymentStudent ??
                'Etudiant\u00B7e / Apprenti\u00B7e',
            value: 'student',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label: l10n?.advisorMiniEmploymentUnemployed ?? 'Sans emploi',
            value: 'unemployed',
            icon: Icons.pause_circle_outline,
          ),

          const SizedBox(height: 24),
          Text(
            l10n?.advisorMiniHouseholdLabel ?? 'Ton foyer',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.advisorMiniHouseholdSubtitle ??
                'On ajuste impôts et charges fixes selon ta situation',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildHouseholdChip(
            label: l10n?.onboardingHouseholdSingle ?? 'Seul(e)',
            description: l10n?.onboardingHouseholdSingleDesc ??
                'Je gère mes finances en solo',
            value: 'single',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 8),
          _buildHouseholdChip(
            label: l10n?.onboardingHouseholdCouple ?? 'En couple',
            description: l10n?.onboardingHouseholdCoupleDesc ??
                'Nous partageons nos objectifs financiers',
            value: 'couple',
            icon: Icons.people_outline,
          ),
          const SizedBox(height: 8),
          _buildHouseholdChip(
            label: l10n?.onboardingHouseholdFamily ?? 'Famille',
            description: l10n?.onboardingHouseholdFamilyDesc ??
                'Avec enfant(s) à charge',
            value: 'family',
            icon: Icons.family_restroom_outlined,
          ),

          const SizedBox(height: 16),
          _buildQuickInsightCard(),
          const SizedBox(height: 20),
          _buildFixedCostsSection(),
          if (canContinue) ...[
            const SizedBox(height: 10),
            _buildStepReadyHint(
              title: l10n?.advisorMiniReadyTitle ?? 'Validation',
              body: l10n?.advisorMiniReadyStep3 ??
                  'Profil minimum prêt. Projection fiable activée.',
            ),
          ],

          const SizedBox(height: 36),

          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canContinue
                  ? () {
                      if (_mainGoal == null) {
                        setState(() => _mainGoal = _suggestGoalFromStress());
                        _scheduleAutoSave('goal_auto_suggested');
                      }
                      _goToStep(3);
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.advisorMiniSeeProjection ?? 'Voir ma projection',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary: full diagnostic
          Center(
            child: TextButton(
              onPressed: () {
                _analytics.trackCTAClick('advisor_full_diagnostic_step3',
                    screenName: '/advisor');
                context.push('/advisor/wizard');
              },
              child: Text(
                l10n?.advisorMiniPreferFullDiagnostic ??
                    'Je prefere le diagnostic complet (10 min)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _employmentStatus == value;

    return GestureDetector(
      onTap: () {
        setState(() => _employmentStatus = value);
        _scheduleAutoSave('employment_changed');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? MintColors.primary : MintColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? MintColors.primary : MintColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: MintColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildStepReadyHint({
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: MintColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdChip({
    required String label,
    required String description,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _householdType == value;

    return GestureDetector(
      onTap: () {
        setState(() => _householdType = value);
        _scheduleAutoSave('household_changed');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? MintColors.primary : MintColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: MintColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedCostsSection() {
    final l10n = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 18, color: MintColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n?.advisorMiniFixedCostsTitle ?? 'Charges fixes (optionnel)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n?.advisorMiniFixedCostsSubtitle ??
                'Ajoute impôts, LAMal et autres fixes pour un budget réaliste dès le dashboard.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _prefillFixedCostsEstimates,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                l10n?.advisorMiniPrefillEstimates ?? 'Préremplir estimations',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.primary,
                side: const BorderSide(color: MintColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildChfOptionalField(
            controller: _taxProvisionController,
            label:
                l10n?.advisorMiniTaxProvisionLabel ?? 'Provision impôts / mois',
            hint: '900',
          ),
          const SizedBox(height: 8),
          _buildChfOptionalField(
            controller: _lamalController,
            label: l10n?.advisorMiniLamalLabel ?? 'Primes LAMal / mois',
            hint: '430',
          ),
          const SizedBox(height: 8),
          _buildChfOptionalField(
            controller: _otherFixedController,
            label: l10n?.advisorMiniOtherFixedLabel ??
                'Autres charges fixes / mois',
            hint: '300',
          ),
        ],
      ),
    );
  }

  Widget _buildChfOptionalField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {
            setState(() {});
            _scheduleAutoSave('fixed_cost_changed');
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixText: 'CHF  ',
            prefixStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted,
            ),
            hintStyle: TextStyle(
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: MintColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: MintColors.primary, width: 1.8),
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  double? _parseChfController(TextEditingController controller) {
    final raw = controller.text.replaceAll("'", '').replaceAll(' ', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _prefillFixedCostsEstimates() {
    final income = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    if (income == null || income <= 0 || _canton == null) return;
    final household = _householdType ?? 'single';
    final parsedBirthYear = int.tryParse(_birthYearController.text);
    final age = parsedBirthYear != null
        ? (DateTime.now().year - parsedBirthYear).clamp(18, 80)
        : 35;

    final monthlyTax = TaxEstimatorService.estimateMonthlyProvision(
      TaxEstimatorService.estimateAnnualTax(
        netMonthlyIncome: income,
        cantonCode: _canton!,
        civilStatus: _civilStatusForHousehold(household),
        childrenCount: _childrenCountFromHousehold(household),
        age: age,
        isSourceTaxed: false,
      ),
    );
    final lamal = _estimateLamalFromCanton(_canton!, householdType: household);

    if (_taxProvisionController.text.trim().isEmpty) {
      _taxProvisionController.text = monthlyTax.round().toString();
    }
    if (_lamalController.text.trim().isEmpty) {
      _lamalController.text = lamal.round().toString();
    }
    setState(() {});
    _scheduleAutoSave('fixed_cost_prefill');
  }

  double _estimateLamalFromCanton(
    String cantonCode, {
    String householdType = 'single',
  }) {
    const highCantons = {'GE', 'VD', 'BS', 'NE'};
    const lowCantons = {'ZG', 'AI', 'UR', 'OW', 'NW'};
    final baseAdultPremium = highCantons.contains(cantonCode)
        ? 520.0
        : lowCantons.contains(cantonCode)
            ? 350.0
            : 430.0;
    final adults = _adultCountFromHousehold(householdType);
    final children = _childrenCountFromHousehold(householdType);
    final childPremium = (baseAdultPremium * 0.27).roundToDouble();
    return (baseAdultPremium * adults) + (childPremium * children);
  }

  String _civilStatusForHousehold(String householdType) {
    switch (householdType) {
      case 'couple':
      case 'family':
        return 'married';
      default:
        return 'single';
    }
  }

  int _childrenCountFromHousehold(String householdType) {
    return householdType == 'family' ? 1 : 0;
  }

  int _adultCountFromHousehold(String householdType) {
    return householdType == 'single' ? 1 : 2;
  }

  List<int> _birthYearQuickPicks() {
    final currentYear = DateTime.now().year;
    return [
      currentYear - 25,
      currentYear - 35,
      currentYear - 45,
      currentYear - 55,
    ];
  }

  List<int> _incomeQuickPicks() => [4000, 6000, 8000, 10000];

  void _applyBirthYearQuickPick(int year) {
    _usedBirthYearPreset = true;
    _incMetric('quick_pick_birth_year');
    _birthYearController.text = '$year';
    _analytics.trackEvent(
      'onboarding_quick_pick_used',
      category: 'engagement',
      data: _withOnboardingContext({
        'field': 'birth_year',
        'value': year,
      }),
    );
    _maybeTrackStep2Aha();
    setState(() {});
    _scheduleAutoSave('birth_year_quick_pick');
  }

  void _applyIncomeQuickPick(int amount) {
    _usedIncomePreset = true;
    _incMetric('quick_pick_income');
    _incomeController.text = '$amount';
    _analytics.trackEvent(
      'onboarding_quick_pick_used',
      category: 'engagement',
      data: _withOnboardingContext({
        'field': 'income_monthly',
        'value': amount,
      }),
    );
    setState(() {});
    _scheduleAutoSave('income_quick_pick');
  }

  Widget _buildQuickChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? MintColors.primary : MintColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _computeStep2AhaData() {
    final birthYear = int.tryParse(_birthYearController.text);
    if (birthYear == null ||
        _validateBirthYear(_birthYearController.text) != null) {
      return null;
    }
    if (_canton == null) return null;

    final nowYear = DateTime.now().year;
    final age = nowYear - birthYear;
    final yearsToRetirement = (65 - age).clamp(0, 60);
    final cantonProfile = CantonalDataService.getByCode(_canton);
    final avgRate = cantonProfile.averageMarginalRate;
    final swissAvg = CantonalDataService.getByCode(null).averageMarginalRate;
    final deltaRate = avgRate - swissAvg;
    final estimatedTaxOn100k = (avgRate * 100000).round();
    final annualDeltaOn100k = (deltaRate * 100000).round();

    return {
      'age': age,
      'years_to_retirement': yearsToRetirement,
      'canton_code': _canton,
      'canton_name': cantonProfile.name,
      'avg_rate_percent': (avgRate * 100),
      'tax_on_100k': estimatedTaxOn100k,
      'delta_vs_ch_percent': (deltaRate * 100),
      'annual_delta_on_100k': annualDeltaOn100k,
    };
  }

  void _maybeTrackStep2Aha() {
    if (_step2AhaTracked) return;
    final aha = _computeStep2AhaData();
    if (aha == null) return;
    _step2AhaTracked = true;
    _incMetric('step2_aha_shown');
    _analytics.trackEvent(
      'onboarding_step2_aha_shown',
      category: 'engagement',
      data: _withOnboardingContext({
        ...aha,
        'tone': _miniOnboardingVariant == 'challenge' ? 'emotional' : 'factual',
      }),
    );
  }

  Widget _buildStep2AhaCard(Map<String, dynamic> aha) {
    final l10n = S.of(context);
    final yearsToRetirement = aha['years_to_retirement'] as int;
    final cantonCode = aha['canton_code'] as String;
    final avgRatePercent = aha['avg_rate_percent'] as double;
    final taxOn100k = aha['tax_on_100k'] as int;
    final deltaVsCh = aha['delta_vs_ch_percent'] as double;
    final annualDelta = aha['annual_delta_on_100k'] as int;
    final isChallenge = _miniOnboardingVariant == 'challenge';
    final directionLabel = deltaVsCh >= 0
        ? (l10n?.advisorMiniStep2AhaDirectionAbove ?? 'au-dessus')
        : (l10n?.advisorMiniStep2AhaDirectionBelow ?? 'en-dessous');
    final annualDeltaAbs = annualDelta.abs();
    final deltaRateAbs = deltaVsCh.abs().toStringAsFixed(1);

    final body = isChallenge
        ? (l10n?.advisorMiniStep2AhaEmotional(
              '$yearsToRetirement',
              cantonCode,
              avgRatePercent.toStringAsFixed(1),
              deltaVsCh.abs().toStringAsFixed(1),
              directionLabel,
              '$annualDeltaAbs',
            ) ??
            'Tu as environ $yearsToRetirement ans avant 65 ans. Dans le canton de $cantonCode, le taux marginal moyen est ~${avgRatePercent.toStringAsFixed(1)}% (${deltaVsCh.abs().toStringAsFixed(1)} pts $directionLabel la moyenne CH), soit un enjeu d\'environ CHF $annualDeltaAbs/an pour CHF 100\'000 imposables.')
        : (l10n?.advisorMiniStep2AhaFactual(
              '$yearsToRetirement',
              cantonCode,
              avgRatePercent.toStringAsFixed(1),
              deltaVsCh.abs().toStringAsFixed(1),
              directionLabel,
              '$annualDeltaAbs',
            ) ??
            'Horizon retraite: ~$yearsToRetirement ans. En $cantonCode, taux marginal moyen ~${avgRatePercent.toStringAsFixed(1)}% (${deltaVsCh.abs().toStringAsFixed(1)} pts $directionLabel la moyenne CH), soit ~CHF $annualDeltaAbs/an pour CHF 100\'000 imposables.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isChallenge ? Icons.bolt : Icons.insights,
                size: 18,
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.advisorMiniStep2AhaTitle ?? 'Point clé instantané',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildAhaChip(
                  'Taux marginal estimé: ${avgRatePercent.toStringAsFixed(1)}%'),
              _buildAhaChip('Impôt estimé sur CHF 100\'000: CHF $taxOn100k/an'),
              _buildAhaChip(
                  'Écart vs CH: ${annualDelta >= 0 ? '+' : '-'}CHF $annualDeltaAbs/an (${annualDelta >= 0 ? '+' : '-'}$deltaRateAbs pts)'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.advisorMiniStep2AhaDisclaimer ??
                'Ordre de grandeur éducatif, basé sur données cantonales de référence MINT.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAhaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: MintColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildQuickInsightCard() {
    final l10n = S.of(context);
    final income = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );
    if (income == null || income <= 0 || _employmentStatus == null) {
      return const SizedBox.shrink();
    }

    final isLowCapacity =
        _employmentStatus == 'student' || _employmentStatus == 'unemployed';
    final minRate = isLowCapacity ? 0.02 : 0.08;
    final maxRate = isLowCapacity ? 0.08 : 0.15;
    final low = (income * minRate).round();
    final high = (income * maxRate).round();

    final birthYear = int.tryParse(_birthYearController.text);
    String horizon = '';
    if (birthYear != null) {
      final age = DateTime.now().year - birthYear;
      final yearsLeft = (65 - age).clamp(0, 60);
      horizon = l10n?.advisorMiniHorizon('$yearsLeft') ??
          'Horizon retraite: ~$yearsLeft ans.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, size: 18, color: MintColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n?.advisorMiniQuickInsight('$low', '$high', horizon) ??
                  'Estimation rapide: une épargne régulière entre CHF $low et CHF $high/mois peut déjà changer ta trajectoire. $horizon',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4GoalAndPreview() {
    final l10n = S.of(context);
    final canComplete = _mainGoal != null;
    final preview = _mainGoal != null ? _computePreviewProjection() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n?.advisorMiniStep4Title ?? 'Ton objectif',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.advisorMiniStep4Subtitle ??
                'MINT personnalise ton plan selon ta priorite principale',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.coachBubble,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Text(
              _mainGoal == null
                  ? 'Choisis 1 priorité. Tu pourras en ajouter d’autres ensuite.'
                  : 'Priorité active: ${_labelForGoal(_mainGoal!, l10n)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _buildGoalChip(
            label: l10n?.advisorMiniGoalRetirement ?? 'Preparer ma retraite',
            value: 'retirement',
            icon: Icons.beach_access_outlined,
          ),
          const SizedBox(height: 8),
          _buildGoalChip(
            label:
                l10n?.advisorMiniGoalRealEstate ?? 'Acheter un bien immobilier',
            value: 'real_estate',
            icon: Icons.house_outlined,
          ),
          const SizedBox(height: 8),
          _buildGoalChip(
            label: l10n?.advisorMiniGoalDebtFree ?? 'Reduire mes dettes',
            value: 'debt_free',
            icon: Icons.money_off_outlined,
          ),
          const SizedBox(height: 8),
          _buildGoalChip(
            label: l10n?.advisorMiniGoalIndependence ??
                'Construire mon independance financiere',
            value: 'independence',
            icon: Icons.trending_up_outlined,
          ),
          const SizedBox(height: 16),
          if (preview != null) _buildProjectionPreviewCard(preview),
          if (preview != null) ...[
            const SizedBox(height: 10),
            _buildMintUnderstoodCard(preview),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canComplete ? _completeMiniOnboarding : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.advisorMiniActivateDashboard ??
                        'Activer mon dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n?.advisorMiniAdjustLater ??
                  'Tu pourras tout ajuster ensuite depuis Dashboard et Agir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGoalChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _mainGoal == value;
    return GestureDetector(
      onTap: () {
        setState(() => _mainGoal = value);
        _scheduleAutoSave('goal_selected');
        _analytics.trackEvent(
          'onboarding_goal_selected',
          category: 'engagement',
          data: _withOnboardingContext({'goal': value}),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? MintColors.primary : MintColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? MintColors.primary : MintColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: MintColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  String _labelForGoal(String goal, S? l10n) {
    switch (goal) {
      case 'retirement':
        return l10n?.advisorMiniGoalRetirement ?? 'Préparer ma retraite';
      case 'real_estate':
        return l10n?.advisorMiniGoalRealEstate ?? 'Acheter un bien immobilier';
      case 'debt_free':
        return l10n?.advisorMiniGoalDebtFree ?? 'Réduire mes dettes';
      case 'independence':
        return l10n?.advisorMiniGoalIndependence ??
            'Construire mon indépendance financière';
      default:
        return goal;
    }
  }

  Map<String, dynamic>? _computePreviewProjection() {
    try {
      final birthYear = int.tryParse(_birthYearController.text);
      final income = double.tryParse(
        _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
      );
      final empStatus = _employmentStatus ?? 'employee';
      if (birthYear == null ||
          income == null ||
          income <= 0 ||
          _canton == null) {
        return null;
      }

      // Keep preview assumptions aligned with mini-onboarding completion:
      // employee + annual income above LPP threshold => pension fund "yes".
      final hasPensionFund = empStatus == 'employee' && income * 12 > 22680;
      final monthlySavings = (income * 0.10).clamp(100.0, 1200.0);

      final answers = <String, dynamic>{
        'q_birth_year': birthYear,
        'q_canton': _canton,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': income,
        'q_employment_status': empStatus,
        'q_has_pension_fund': hasPensionFund ? 'yes' : 'no',
        'q_savings_monthly': monthlySavings,
        'q_savings_allocation': const ['epargne_libre'],
        'q_main_goal': _mainGoal ?? 'retirement',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      final projection = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final age = DateTime.now().year - birthYear;
      final yearsLeft = (65 - age).clamp(0, 60);

      return {
        'targetLabel': profile.goalA.label,
        'prudent': projection.prudent.capitalFinal,
        'base': projection.base.capitalFinal,
        'optimiste': projection.optimiste.capitalFinal,
        'yearsLeft': yearsLeft,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MiniOnboarding] Preview projection error: $e');
      }
      return null;
    }
  }

  Widget _buildProjectionPreviewCard(Map<String, dynamic> preview) {
    final l10n = S.of(context);
    final prudent = preview['prudent'] as double;
    final base = preview['base'] as double;
    final optimiste = preview['optimiste'] as double;
    final targetLabel = preview['targetLabel'] as String;
    final yearsLeft = preview['yearsLeft'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 18, color: MintColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.advisorMiniPreviewTitle(targetLabel) ??
                      'Preview trajectoire: $targetLabel',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.advisorMiniPreviewSubtitle('$yearsLeft') ??
                'Projection indicative sur ~$yearsLeft ans',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _buildProjectionRow(
            l10n?.advisorMiniPreviewPrudent ?? 'Prudent',
            prudent,
            const Color(0xFF6B7280),
          ),
          const SizedBox(height: 6),
          _buildProjectionRow(
            l10n?.advisorMiniPreviewBase ?? 'Base',
            base,
            MintColors.primary,
          ),
          const SizedBox(height: 6),
          _buildProjectionRow(
            l10n?.advisorMiniPreviewOptimistic ?? 'Optimiste',
            optimiste,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.advisorMiniProjectionDisclaimer ??
                'Outil educatif — ne constitue pas un conseil financier (LAVS/LPP).',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionRow(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          ForecasterService.formatChf(value),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMintUnderstoodCard(Map<String, dynamic> preview) {
    final l10n = S.of(context);
    final income = double.tryParse(
          _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
        ) ??
        0;
    final fixedCount = [
      _parseChfController(_taxProvisionController),
      _parseChfController(_lamalController),
      _parseChfController(_otherFixedController),
    ].where((v) => (v ?? 0) > 0).length;
    final horizon = '~${preview['yearsLeft']} ans';
    final goalLabel = _labelForGoal(_mainGoal ?? 'retirement', l10n);
    final employmentLabel = _labelForEmployment(_employmentStatus, l10n);
    final householdLabel = _labelForHousehold(_householdType, l10n);
    final cantonLabel = _canton ?? '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.advisorMiniReadyLabel ?? 'Ce que MINT a compris',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyStress(goalLabel) ?? 'Priorité: $goalLabel',
          ),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyProfile(employmentLabel, householdLabel) ??
                'Profil: $employmentLabel · $householdLabel',
          ),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyLocation(cantonLabel, horizon) ??
                'Base fiscale: $cantonLabel · $horizon',
          ),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyIncome(income.round().toString()) ??
                'Revenu net: CHF ${income.round()}/mois',
          ),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyFixed('$fixedCount') ??
                'Charges fixes captées: $fixedCount/3',
          ),
        ],
      ),
    );
  }

  Widget _mintUnderstoodRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 6, color: MintColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForEmployment(String? employment, S? l10n) {
    switch (employment) {
      case 'employee':
        return l10n?.advisorMiniEmploymentEmployee ?? 'Salarié·e';
      case 'self_employed':
        return l10n?.advisorMiniEmploymentSelfEmployed ?? 'Indépendant·e';
      case 'student':
        return l10n?.advisorMiniEmploymentStudent ?? 'Étudiant·e';
      case 'unemployed':
        return l10n?.advisorMiniEmploymentUnemployed ?? 'Sans emploi';
      default:
        return l10n?.advisorMiniEmploymentEmployee ?? 'Salarié·e';
    }
  }

  String _labelForHousehold(String? household, S? l10n) {
    switch (household) {
      case 'couple':
        return l10n?.onboardingHouseholdCouple ?? 'En couple';
      case 'family':
        return l10n?.onboardingHouseholdFamily ?? 'Famille';
      default:
        return l10n?.onboardingHouseholdSingle ?? 'Seul(e)';
    }
  }
}
