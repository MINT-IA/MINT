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
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_constants.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_stress.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_essentials.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_step_income.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
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

class _AdvisorOnboardingScreenState extends State<AdvisorOnboardingScreen> {
  final PageController _pageController = PageController();
  final AnalyticsService _analytics = AnalyticsService();
  static const String _onboardingExperimentName = 'mini_onboarding_v4';
  int _currentStep = 0;

  // Answer state is now in OnboardingProvider — these accessors read from it.
  late OnboardingProvider _onboardingProvider;
  bool _providerBound = false;
  OnboardingProvider get _provider =>
      _providerBound ? _onboardingProvider : context.read<OnboardingProvider>();
  Set<String> get _stressChoices => _provider.stressChoices;
  String? get _canton => _provider.canton;
  String? get _employmentStatus => _provider.employmentStatus;
  String? get _householdType => _provider.householdType;
  String? get _mainGoal => _provider.mainGoal;

  // Controllers (widget-owned, synced from provider on init)
  final _firstNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _incomeController = TextEditingController();
  final _housingController = TextEditingController();
  final _debtPaymentsController = TextEditingController();
  final _cashSavingsController = TextEditingController();
  final _investmentsController = TextEditingController();
  final _pillar3aTotalController = TextEditingController();
  final _taxProvisionController = TextEditingController();
  final _lamalController = TextEditingController();
  final _otherFixedController = TextEditingController();
  final _partnerIncomeController = TextEditingController();
  final _partnerBirthYearController = TextEditingController();
  final _partnerFirstNameController = TextEditingController();

  // Saved wizard progress (read from provider)
  bool get _hasSavedWizardProgress => _provider.hasSavedWizardProgress;
  int get _savedWizardProgress => _provider.savedWizardProgress;

  late final DateTime _onboardingStartedAt;
  final Map<int, DateTime> _stepEnteredAt = {};
  bool _isOnboardingCompleted = false;
  String _miniOnboardingVariant = 'control';
  final bool _usedBirthYearPreset = false;
  bool _usedIncomePreset = false;
  bool _usedBirthYearManual = false;
  bool _usedIncomeManual = false;
  bool _step2AhaTracked = false;
  bool _cohortStartedTracked = false;
  Map<String, int> _variantMetrics = const {};
  Timer? _autoSaveDebounce;
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
    _checkSavedProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_providerBound) {
      _onboardingProvider = context.read<OnboardingProvider>();
      _providerBound = true;
    }
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
    final stress =
        _stressChoices.isNotEmpty ? _stressChoices.join(',') : 'unknown';
    final employment = _employmentStatus ?? 'unknown';
    final household = _householdType ?? 'unknown';
    return 'stress_$stress|emp_$employment|house_$household|${_incomeBucket(income)}';
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    if (!_isOnboardingCompleted && _providerBound) {
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
    _firstNameController.dispose();
    _birthYearController.dispose();
    _incomeController.dispose();
    _housingController.dispose();
    _debtPaymentsController.dispose();
    _cashSavingsController.dispose();
    _investmentsController.dispose();
    _pillar3aTotalController.dispose();
    _taxProvisionController.dispose();
    _lamalController.dispose();
    _otherFixedController.dispose();
    _partnerIncomeController.dispose();
    _partnerBirthYearController.dispose();
    _partnerFirstNameController.dispose();
    super.dispose();
  }

  /// Syncs text controllers from provider's already-hydrated state.
  void _syncControllersFromProvider() {
    final p = _provider;
    if (p.draftFirstName != null && p.draftFirstName!.isNotEmpty) {
      _firstNameController.text = p.draftFirstName!;
    } else if (p.firstName != null) {
      _firstNameController.text = p.firstName!;
    }
    if (p.draftBirthYear != null && p.draftBirthYear!.isNotEmpty) {
      _birthYearController.text = p.draftBirthYear!;
    } else if (p.birthYear != null) {
      _birthYearController.text = p.birthYear.toString();
    }
    if (p.draftIncome != null && p.draftIncome!.isNotEmpty) {
      _incomeController.text = p.draftIncome!;
    } else if (p.incomeMonthly != null) {
      _incomeController.text = p.incomeMonthly!.toInt().toString();
    }
    if (p.draftHousingCost != null && p.draftHousingCost!.isNotEmpty) {
      _housingController.text = p.draftHousingCost!;
    } else if (p.housingCostMonthly != null) {
      _housingController.text = p.housingCostMonthly!.toInt().toString();
    }
    if (p.draftDebtPayments != null && p.draftDebtPayments!.isNotEmpty) {
      _debtPaymentsController.text = p.draftDebtPayments!;
    } else if (p.debtPaymentsMonthly != null) {
      _debtPaymentsController.text = p.debtPaymentsMonthly!.toInt().toString();
    }
    if (p.draftCashSavings != null && p.draftCashSavings!.isNotEmpty) {
      _cashSavingsController.text = p.draftCashSavings!;
    } else if (p.cashSavingsTotal != null) {
      _cashSavingsController.text = p.cashSavingsTotal!.toInt().toString();
    }
    if (p.draftInvestmentsTotal != null &&
        p.draftInvestmentsTotal!.isNotEmpty) {
      _investmentsController.text = p.draftInvestmentsTotal!;
    } else if (p.investmentsTotal != null) {
      _investmentsController.text = p.investmentsTotal!.toInt().toString();
    }
    if (p.draftPillar3aTotal != null && p.draftPillar3aTotal!.isNotEmpty) {
      _pillar3aTotalController.text = p.draftPillar3aTotal!;
    } else if (p.pillar3aTotal != null) {
      _pillar3aTotalController.text = p.pillar3aTotal!.toInt().toString();
    }
    if (p.draftTaxProvision != null && p.draftTaxProvision!.isNotEmpty) {
      _taxProvisionController.text = p.draftTaxProvision!;
    } else if (p.taxProvisionMonthly != null) {
      _taxProvisionController.text = p.taxProvisionMonthly!.toInt().toString();
    }
    if (p.draftLamal != null && p.draftLamal!.isNotEmpty) {
      _lamalController.text = p.draftLamal!;
    } else if (p.lamalPremiumMonthly != null) {
      _lamalController.text = p.lamalPremiumMonthly!.toInt().toString();
    }
    if (p.draftOtherFixed != null && p.draftOtherFixed!.isNotEmpty) {
      _otherFixedController.text = p.draftOtherFixed!;
    } else if (p.otherFixedCostsMonthly != null) {
      _otherFixedController.text = p.otherFixedCostsMonthly!.toInt().toString();
    }
    // Partner controllers
    if (p.draftPartnerIncome != null && p.draftPartnerIncome!.isNotEmpty) {
      _partnerIncomeController.text = p.draftPartnerIncome!;
    } else if (p.partnerIncome != null) {
      _partnerIncomeController.text = p.partnerIncome!.toInt().toString();
    }
    if (p.draftPartnerBirthYear != null &&
        p.draftPartnerBirthYear!.isNotEmpty) {
      _partnerBirthYearController.text = p.draftPartnerBirthYear!;
    } else if (p.partnerBirthYear != null) {
      _partnerBirthYearController.text = p.partnerBirthYear.toString();
    }
    if (p.draftPartnerFirstName != null &&
        p.draftPartnerFirstName!.isNotEmpty) {
      _partnerFirstNameController.text = p.draftPartnerFirstName!;
    } else if (p.partnerFirstName != null) {
      _partnerFirstNameController.text = p.partnerFirstName!;
    }
  }

  Future<void> _checkSavedProgress() async {
    // Provider is already hydrated via init() in MultiProvider.
    // Just sync text controllers and jump to resume step.
    if (_hasSavedWizardProgress && mounted) {
      _syncControllersFromProvider();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetStep = _provider.computeResumeStep();
        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetStep);
        }
        setState(() => _currentStep = targetStep);
        _maybeTrackStep2Aha();
      });
    }
  }

  String _suggestGoalFromStress() => _provider.suggestGoalFromStress();

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
      totalSteps: OnboardingConstants.totalSteps,
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

  Map<String, dynamic> _currentMiniAnswersSnapshot() =>
      _provider.buildAnswersSnapshot();

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
    // Delegate persistence + validation to provider
    final merged = await _provider.completeMiniOnboarding();
    if (merged == null) return;

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
        totalSteps: OnboardingConstants.totalSteps,
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
        _incMetric('completion_action_wizard');
        _analytics.trackCTAClick(
          'advisor_completion_full_diagnostic',
          screenName: '/advisor',
          data: _onboardingContextData(),
        );
        context.push('/advisor/wizard?section=identity');
      } else if (action == 'plan30') {
        _incMetric('completion_action_plan30');
        _analytics.trackCTAClick(
          'advisor_completion_open_plan_30_days',
          screenName: '/advisor',
          data: _withOnboardingContext({
            'stress_choice': _stressChoices.toList(),
            'main_goal': _mainGoal ?? 'retirement',
          }),
        );
        context.go(
          '/advisor/plan-30-days',
          extra: {
            'stress_choice':
                _stressChoices.isNotEmpty ? _stressChoices.first : null,
            'stress_choices': _stressChoices.toList(),
            'main_goal': _mainGoal ?? 'retirement',
          },
        );
      } else {
        _incMetric('completion_action_dashboard');
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
    final isChallenge = _miniOnboardingVariant == 'challenge';
    _incMetric('completion_sheet_shown');
    _incMetric('completion_sheet_shown_$_miniOnboardingVariant');
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.90;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Welcome header (Phase 2 — Coach Feel Uplift)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.celebration_outlined,
                          color: MintColors.success, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n?.advisorMiniWelcomeTitle ?? 'Bienvenue !',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.advisorMiniWelcomeBody ??
                      'Ton espace financier est prêt. Découvre ce que ton coach a préparé.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Trajectory section
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
                const SizedBox(height: 14),
                _buildCoachIntroBlock(),
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
                      isChallenge
                          ? (l10n?.advisorMiniWeekOneCta ??
                              'Lancer ma semaine 1')
                          : 'Voir mon plan 30 jours',
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
                      isChallenge
                          ? (l10n?.advisorMiniStartWithDashboard ??
                              'Commencer avec le dashboard')
                          : (l10n?.advisorMiniActivateDashboard ??
                              'Activer mon dashboard'),
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

  Widget _buildCoachIntroBlock() {
    final l10n = S.of(context);
    final priorities = _coachIntroPriorities();
    final isChallenge = _miniOnboardingVariant == 'challenge';
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
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: MintColors.info,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.advisorMiniCoachIntroTitle ?? 'Ton coach MINT',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Warmth phrase (Phase 2 — Coach Feel Uplift)
          Text(
            l10n?.advisorMiniCoachIntroWarmth ??
                'On y va ensemble. Chaque semaine, je t\'aide à avancer sur un point concret.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isChallenge
                ? (S.of(context)?.advisorMiniCoachIntroChallenge ??
                    'Objectif: passer de l analyse a l action cette semaine. On commence maintenant avec 3 priorites.')
                : (l10n?.advisorMiniCoachIntroControl ??
                    'Tu as maintenant un plan concret. On avance en 3 priorites sur 7 jours, puis on ajuste avec ton coach.'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          ...priorities.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${entry.key + 1}. ${entry.value}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  List<String> _coachIntroPriorities() {
    final l10n = S.of(context);
    final stress =
        _stressChoices.isNotEmpty ? _stressChoices.first : 'retirement';
    final goal = _mainGoal ?? 'retirement';
    final household = _householdType ?? 'single';
    final priorities = <String>[
      l10n?.advisorMiniCoachPriorityBaseline ??
          'Confirmer ton score et ta trajectoire de depart',
    ];
    if (household == 'couple' || household == 'family') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityCouple ??
            'Aligner la strategie du foyer pour eviter les angles morts de couple',
      );
    } else if (household == 'single_parent') {
      priorities.add(
        l10n?.advisorMiniCoachPrioritySingleParent ??
            'Prioriser la protection du foyer et le matelas de securite',
      );
    }
    if (stress == 'debt' || stress == 'budget') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityBudget ??
            'Stabiliser ton budget et tes charges fixes en premier',
      );
    } else if (stress == 'tax') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityTax ??
            'Identifier les optimisations fiscales prioritaires',
      );
    } else {
      priorities.add(l10n?.advisorMiniCoachPriorityRetirement ??
          'Renforcer ta trajectoire retraite avec des actions concretes');
    }
    if (goal == 'real_estate') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityRealEstate ??
            'Verifier la soutenabilite de ton projet immobilier',
      );
    } else if (goal == 'debt_free') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityDebtFree ??
            'Accelerer ton desendettement sans casser ta liquidite',
      );
    } else if (goal == 'wealth') {
      priorities.add(
        l10n?.advisorMiniCoachPriorityWealth ??
            'Construire un plan d accumulation de patrimoine robuste',
      );
    } else {
      priorities.add(
        l10n?.advisorMiniCoachPriorityPension ??
            'Optimiser 3a/LPP et le niveau de revenu a la retraite',
      );
    }
    return priorities.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleClosePressed();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
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
              l10n?.onboardingProgress('${_currentStep + 1}',
                      '${OnboardingConstants.totalSteps}') ??
                  '${_currentStep + 1}/${OnboardingConstants.totalSteps}',
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
    final provider = context.read<OnboardingProvider>();
    final liveQuality = _computeLiveMiniQualityScore(provider).round();
    final liveSection = _recommendedSectionFromMini(provider);
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
                  _buildLiveOnboardingQualityCard(
                    provider: provider,
                    qualityPct: liveQuality,
                    recommendedSection: liveSection,
                  ),
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
    final l10n = S.of(context);
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
    final controlRate =
        controlStarted > 0 ? (controlCompleted / controlStarted) : 0.0;
    final challengeRate =
        challengeStarted > 0 ? (challengeCompleted / challengeStarted) : 0.0;
    final hasComparableData = controlStarted >= 10 && challengeStarted >= 10;
    final winner = !hasComparableData
        ? 'Insuffisant'
        : challengeRate > controlRate
            ? 'Challenge'
            : controlRate > challengeRate
                ? 'Control'
                : 'Égalité';
    final upliftPct =
        hasComparableData ? ((challengeRate - controlRate) * 100) : 0.0;

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
          const SizedBox(height: 6),
          _metricRow(
            l10n?.advisorMiniMetricsWinnerLive ?? 'Winner live',
            winner,
          ),
          if (hasComparableData)
            _metricRow(
              l10n?.advisorMiniMetricsUplift ?? 'Uplift challenge vs control',
              '${upliftPct >= 0 ? '+' : ''}${upliftPct.toStringAsFixed(1)} pts',
            )
          else
            _metricRow(
              l10n?.advisorMiniMetricsSignal ?? 'Signal',
              l10n?.advisorMiniMetricsSignalInsufficient ??
                  'Attendre >=10 starts par variante',
            ),
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
    final qualityLabel = qualityScore >= 80
        ? 'Excellent'
        : qualityScore >= 60
            ? 'Solide'
            : qualityScore >= 40
                ? 'Moyen'
                : 'Fragile';
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
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    qualityLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MintColors.primary,
                    ),
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

  String _sectionLabel(String section) {
    final s = S.of(context);
    switch (section) {
      case 'identity':
        return s?.profileSectionIdentity ?? 'Identite & Foyer';
      case 'income':
        return s?.profileSectionIncome ?? 'Revenus & Epargne';
      case 'pension':
        return s?.profileSectionPension ?? 'Prevoyance (LPP)';
      case 'property':
        return s?.profileSectionProperty ?? 'Immobilier & Dettes';
      default:
        return s?.advisorMiniFullDiagnostic ?? 'Diagnostic complet';
    }
  }

  Widget _buildLiveOnboardingQualityCard({
    required OnboardingProvider provider,
    required int qualityPct,
    required String recommendedSection,
  }) {
    final s = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.advisorMiniMetricsLiveTitle ?? 'Qualite onboarding live',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _metricRow(
            s?.advisorMiniMetricsLiveStep ?? 'Step courant',
            '${provider.currentStep + 1}/${OnboardingConstants.totalSteps}',
          ),
          _metricRow(
            s?.advisorMiniMetricsLiveQuality ?? 'Score qualite',
            '$qualityPct%',
          ),
          _metricRow(
            s?.advisorMiniMetricsLiveNext ?? 'Section recommandee',
            _sectionLabel(recommendedSection),
          ),
        ],
      ),
    );
  }

  double _computeLiveMiniQualityScore(OnboardingProvider provider) {
    var points = 0;
    var total = 8;
    if (provider.stressChoices.isNotEmpty) points += 1;
    if (provider.birthYear != null) points += 1;
    if (provider.canton != null) points += 1;
    if ((provider.incomeMonthly ?? 0) > 0) points += 1;
    if (provider.employmentStatus != null) points += 1;
    if (provider.householdType != null) points += 1;
    if (provider.mainGoal != null) points += 1;
    if ((provider.taxProvisionMonthly ?? 0) > 0 ||
        (provider.lamalPremiumMonthly ?? 0) > 0 ||
        (provider.otherFixedCostsMonthly ?? 0) > 0) {
      points += 1;
    }

    if (provider.isHouseholdWithPartner) {
      total += 4;
      if (provider.civilStatusChoice != null) points += 1;
      if ((provider.partnerIncome ?? 0) > 0) points += 1;
      if (provider.partnerBirthYear != null) points += 1;
      if (provider.partnerEmploymentStatus != null) points += 1;
    }
    if (total <= 0) return 0;
    return (points / total * 100).clamp(0, 100);
  }

  String _recommendedSectionFromMini(OnboardingProvider provider) {
    if (!provider.canAdvanceFromStep2) return 'identity';
    if (!provider.canAdvanceFromStep3) return 'income';
    if (!provider.canAdvanceFromStep4) return 'pension';
    return 'property';
  }

  int _avgStepDurationSeconds(int step) {
    final sum = _variantMetrics['duration_step_${step}_sum'] ?? 0;
    final count = _variantMetrics['duration_step_${step}_count'] ?? 0;
    if (count <= 0) {
      return OnboardingConstants.fallbackStepDurations[step] ?? 20;
    }
    return (sum / count).round().clamp(5, 90);
  }

  int _estimateRemainingSeconds() {
    if (_currentStep >= 3) return 0;
    final current = _currentStep + 1;
    int total = 0;
    for (int step = current + 1;
        step <= OnboardingConstants.totalSteps;
        step++) {
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
        children: List.generate(OnboardingConstants.totalSteps, (i) {
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
    return Column(
      children: [
        Expanded(
          child: OnboardingStepStress(
            firstNameController: _firstNameController,
            onContinue: () => _goToStep(1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Center(
            child: _hasSavedWizardProgress
                ? TextButton.icon(
                    onPressed: () {
                      _analytics.trackCTAClick('advisor_resume_full_diagnostic',
                          screenName: '/advisor');
                      context.push('/advisor/wizard?section=identity');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      l10n?.advisorMiniResumeDiagnostic(
                              '$_savedWizardProgress') ??
                          'Reprendre mon diagnostic ($_savedWizardProgress%)',
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      _analytics.trackCTAClick('advisor_full_diagnostic_step1',
                          screenName: '/advisor');
                      context.push('/advisor/wizard?section=identity');
                    },
                    child: Text(
                      l10n?.advisorMiniFullDiagnostic ??
                          'Diagnostic complet (10 min)',
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 2 : AGE + CANTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep2Essentials() {
    final birthYearError = _validateBirthYear(_birthYearController.text);
    final canGoNext = birthYearError == null &&
        _birthYearController.text.length == 4 &&
        _canton != null;

    return Column(
      children: [
        Expanded(
          child: OnboardingStepEssentials(
            birthYearController: _birthYearController,
            onContinue: () {
              FocusScope.of(context).unfocus();
              _maybeTrackStep2Aha();
              _goToStep(2);
            },
          ),
        ),
        if (_computeStep2AhaData() case final aha?)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: _buildStep2AhaCard(aha),
          ),
        if (canGoNext)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _buildStepReadyHint(
              title: S.of(context)?.advisorMiniReadyTitle ?? 'Validation',
              body: S.of(context)?.advisorMiniReadyStep2 ??
                  'Base fiscale prête. Le contexte cantonal est calibré.',
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 3 : INCOME + STATUS
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep3Income() {
    // Keep readiness hint aligned with the actual CTA gating in OnboardingStepIncome.
    // This avoids showing "Profil minimum pret" while the CTA remains disabled.
    final canContinue = _provider.canAdvanceFromStep3;
    if (_housingController.text.isEmpty) {
      final draft = _provider.draftHousingCost;
      final value = _provider.housingCostMonthly;
      if (draft != null && draft.isNotEmpty) {
        _housingController.text = draft;
      } else if (value != null && value > 0) {
        _housingController.text = value.toInt().toString();
      }
    }

    return Column(
      children: [
        Expanded(
          child: OnboardingStepIncome(
            incomeController: _incomeController,
            housingController: _housingController,
            debtPaymentsController: _debtPaymentsController,
            cashSavingsController: _cashSavingsController,
            investmentsController: _investmentsController,
            pillar3aTotalController: _pillar3aTotalController,
            taxController: _taxProvisionController,
            lamalController: _lamalController,
            otherFixedController: _otherFixedController,
            partnerIncomeController: _partnerIncomeController,
            partnerBirthYearController: _partnerBirthYearController,
            partnerFirstNameController: _partnerFirstNameController,
            onIncomeQuickPick: (amount) => _applyIncomeQuickPick(amount),
            onContinue: () {
              FocusScope.of(context).unfocus();
              if (_mainGoal == null) {
                _provider.setMainGoal(_suggestGoalFromStress());
              }
              _goToStep(3);
            },
          ),
        ),
        if (canContinue)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: _buildStepReadyHint(
              title: S.of(context)?.advisorMiniReadyTitle ?? 'Validation',
              body: S.of(context)?.advisorMiniReadyStep3 ??
                  'Profil minimum prêt. Projection indicative disponible.',
            ),
          ),
      ],
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

  double? _parseChfController(TextEditingController controller) {
    final raw = controller.text.replaceAll("'", '').replaceAll(' ', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _applyIncomeQuickPick(int amount) {
    _usedIncomePreset = true;
    _incMetric('quick_pick_income');
    _incomeController.text = '$amount';
    _provider.setIncomeDraft('$amount');
    _analytics.trackEvent(
      'onboarding_quick_pick_used',
      category: 'engagement',
      data: _withOnboardingContext({
        'field': 'income_monthly',
        'value': amount,
      }),
    );
    setState(() {});
  }

  Map<String, dynamic>? _computeStep2AhaData() =>
      _provider.computeStep2AhaData();

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

  Widget _buildStep4GoalAndPreview() {
    final l10n = S.of(context);
    final canComplete = _mainGoal != null;
    final readiness = _computeAdvisorReadiness();
    final hasCoreProjectionContext = _provider.canAdvanceFromStep3 &&
        (!_provider.isHouseholdWithPartner || _provider.hasPartnerRequiredData);
    final preview =
        (_mainGoal != null && hasCoreProjectionContext) ? _computePreviewProjection() : null;

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
          _buildAdvisorReadinessCard(readiness),
          const SizedBox(height: 12),
          if (preview != null) _buildProjectionPreviewCard(preview),
          if (preview == null)
            _buildStepReadyHint(
              title: 'Aperçu en préparation',
              body:
                  'On finalise d’abord les données de base du foyer. La projection chiffrée sera affichée juste après.',
            ),
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

  Map<String, dynamic> _computeAdvisorReadiness() {
    int points = 0;
    int total = 7;
    final missing = <String>[];

    if (_provider.birthYear != null && _provider.canton != null) {
      points += 1;
    } else {
      missing.add('Âge + canton');
    }
    if (_provider.effectiveIncomeMonthly > 0 &&
        _provider.employmentStatus != null) {
      points += 1;
    } else {
      missing.add('Revenu + statut');
    }
    if (_provider.housingStatus != null &&
        _provider.effectiveHousingCostMonthly > 0) {
      points += 1;
    } else {
      missing.add('Logement');
    }
    if (_provider.householdType != null) {
      points += 1;
    } else {
      missing.add('Type de foyer');
    }
    if ((_provider.taxProvisionMonthly ?? 0) > 0 ||
        (_provider.lamalPremiumMonthly ?? 0) > 0 ||
        (_provider.otherFixedCostsMonthly ?? 0) > 0) {
      points += 1;
    } else {
      missing.add('Charges fixes');
    }
    final debtCaptured = (_provider.draftDebtPayments ?? '').isNotEmpty ||
        _provider.debtPaymentsMonthly != null;
    if (debtCaptured) {
      points += 1;
    } else {
      missing.add('Dettes/leasing');
    }
    if (_provider.effectiveCashSavingsTotal > 0 ||
        _provider.effectiveInvestmentsTotal > 0 ||
        _provider.effectivePillar3aTotal > 0) {
      points += 1;
    } else {
      missing.add('Patrimoine (liquidités/placements/3a)');
    }

    if (_provider.isHouseholdWithPartner) {
      total += 3;
      if (_provider.civilStatusChoice != null) {
        points += 1;
      } else {
        missing.add('État civil couple');
      }
      if (_provider.effectivePartnerIncomeMonthly > 0 &&
          _provider.partnerEmploymentStatus != null) {
        points += 1;
      } else {
        missing.add('Revenu + statut partenaire');
      }
      if (_provider.effectivePartnerBirthYear != null) {
        points += 1;
      } else {
        missing.add('Âge partenaire');
      }
    }

    final score = ((points / total) * 100).round();
    final level = score >= 80
        ? 'haute'
        : score >= 60
            ? 'moyenne'
            : 'faible';
    return {'score': score, 'level': level, 'missing': missing};
  }

  Widget _buildAdvisorReadinessCard(Map<String, dynamic> readiness) {
    final l10n = S.of(context);
    final score = readiness['score'] as int;
    final level = readiness['level'] as String;
    final missing = (readiness['missing'] as List).cast<String>();
    final color = switch (level) {
      'haute' => MintColors.success,
      'moyenne' => MintColors.warning,
      _ => MintColors.error,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n?.advisorReadinessLabel ?? 'Fiabilité conseil'}: $score%',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            () {
              final levelLabel = l10n?.advisorReadinessLevel ?? 'Niveau';
              final detail = missing.isEmpty
                  ? (l10n?.advisorReadinessSufficient ?? 'Socle suffisant pour un plan initial.')
                  : '${l10n?.advisorReadinessToComplete ?? 'À compléter'}: ${missing.take(2).join(', ')}${missing.length > 2 ? '…' : ''}';
              return '$levelLabel $level. $detail';
            }(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.3,
            ),
          ),
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
        _provider.setMainGoal(value);
        setState(() {});
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

  Map<String, dynamic>? _computePreviewProjection() =>
      _provider.computePreviewProjection();

  Widget _buildProjectionPreviewCard(Map<String, dynamic> preview) {
    final l10n = S.of(context);
    final base = preview['base'] as double;
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
                  'Aperçu provisoire: $targetLabel',
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
            l10n?.advisorMiniPreviewBase ?? 'Base',
            base,
            MintColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Estimation préliminaire sur âge + revenu + canton. Le diagnostic complet ajoute patrimoine, prévoyance et dettes.',
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
    final income = _provider.incomeMonthly ??
        (double.tryParse(
              _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
            ) ??
            0);
    final partnerIncome = _provider.partnerIncome ??
        (double.tryParse(
              _partnerIncomeController.text
                  .replaceAll("'", '')
                  .replaceAll(' ', ''),
            ) ??
            0);
    final householdIncome = income + partnerIncome;
    final householdType = _provider.householdType ?? _householdType;
    final firstName = (_provider.firstName ?? _firstNameController.text).trim();
    final partnerFirstName =
        (_provider.partnerFirstName ?? _partnerFirstNameController.text).trim();
    final showPartnerIncome = partnerIncome > 0;
    final fixedCount = [
      _parseChfController(_housingController),
      _parseChfController(_debtPaymentsController),
      _parseChfController(_taxProvisionController),
      _parseChfController(_lamalController),
      _parseChfController(_otherFixedController),
    ].where((v) => (v ?? 0) > 0).length;
    final cash = _parseChfController(_cashSavingsController) ?? 0;
    final investments = _parseChfController(_investmentsController) ?? 0;
    final total3a = _parseChfController(_pillar3aTotalController) ?? 0;
    final housing = _parseChfController(_housingController) ?? 0;
    final debtPayments = _parseChfController(_debtPaymentsController) ?? 0;
    final horizon = '~${preview['yearsLeft']} ans';
    final goalLabel = _labelForGoal(_mainGoal ?? 'retirement', l10n);
    final employmentLabel = _labelForEmployment(_employmentStatus, l10n);
    final householdLabel = _labelForHousehold(householdType, l10n);
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
          if (firstName.isNotEmpty)
            _mintUnderstoodRow('Prénom: $firstName'),
          if (partnerFirstName.isNotEmpty)
            _mintUnderstoodRow('Partenaire: $partnerFirstName'),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyLocation(cantonLabel, horizon) ??
                'Base fiscale: $cantonLabel · $horizon',
          ),
          _mintUnderstoodRow(
            l10n?.advisorMiniReadyIncome(income.round().toString()) ??
                'Revenu net: CHF ${income.round()}/mois',
          ),
          if (housing > 0)
            _mintUnderstoodRow(
              'Logement: CHF ${housing.round()}/mois',
            ),
          if (debtPayments > 0)
            _mintUnderstoodRow(
              'Dettes/Leasing: CHF ${debtPayments.round()}/mois',
            ),
          if (cash > 0)
            _mintUnderstoodRow(
              'Liquidités: CHF ${cash.round()}',
            ),
          if (investments > 0)
            _mintUnderstoodRow(
              'Placements: CHF ${investments.round()}',
            ),
          if (total3a > 0)
            _mintUnderstoodRow(
              'Total 3a: CHF ${total3a.round()}',
            ),
          if (showPartnerIncome)
            _mintUnderstoodRow(
              'Revenu partenaire: CHF ${partnerIncome.round()}/mois',
            ),
          if (showPartnerIncome)
            _mintUnderstoodRow(
              'Revenu foyer total: CHF ${householdIncome.round()}/mois',
            ),
          _mintUnderstoodRow(
            'Charges fixes captées: $fixedCount/5',
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
