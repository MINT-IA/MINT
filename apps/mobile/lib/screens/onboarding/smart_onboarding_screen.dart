import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_chiffre_choc.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_jit_explanation.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_next_step.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_ocr_upload.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_questions.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_stress_selector.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_top_actions.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';

// ZERO-PERSISTENCE GUARANTEE (P1):
// All onboarding inputs stay in-memory until the user explicitly saves.
// No SharedPreferences, no analytics payload, no auto-save before consent.

/// Smart Onboarding — Value-First Flow (Lot 2 + P8-2).
///
/// Orchestrates the 7-step onboarding experience:
///   0: [StepStressSelector]  — intention selector (tap, auto-advance)
///   1: [StepQuestions]        — 5 core inputs (salary, age, status, nationality, canton)
///   2: [StepChiffreChoc]      — reveal of the first impactful number
///   3: [StepOcrUpload]        — optional document scan (LPD-compliant)
///   4: [StepJitExplanation]   — SI...ALORS mini-explanation
///   5: [StepTopActions]       — Top 3 coaching tips
///   6: [StepNextStep]         — Enrich profile or go to dashboard
///
/// Uses a [PageView] with programmatic (non-swipeable) navigation so the user
/// always follows the intentional sequence.
///
/// The ViewModel is owned here and passed down to each step.
/// State is managed via [ListenableBuilder] over the ViewModel.
///
/// The reveal animation on page 2 is triggered via [_animTrigger],
/// a [ValueNotifier<int>] whose counter increments each time we navigate
/// to the chiffre choc step.
class SmartOnboardingScreen extends StatefulWidget {
  const SmartOnboardingScreen({super.key});

  @override
  State<SmartOnboardingScreen> createState() => _SmartOnboardingScreenState();
}

class _SmartOnboardingScreenState extends State<SmartOnboardingScreen> {
  final _viewModel = SmartOnboardingViewModel();
  final _pageController = PageController();
  bool _consentPromptOpen = false;
  bool? _onboardingConsent;
  bool _consentDeclinedThisSession = false;

  /// Incrementing counter — [StepChiffreChoc] listens to this to trigger
  /// its reveal animation without needing cross-file private state access.
  final _animTrigger = ValueNotifier<int>(0);

  /// Cached tips to avoid recomputation on every rebuild.
  List<CoachingTip>? _cachedTips;
  int _lastTipsHash = 0;

  /// Guard so profile pre-fill runs only once.
  bool _didPrefillFromProfile = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrefillFromProfile) {
      _didPrefillFromProfile = true;
      _prefillFromProfile();
    }
  }

  /// Pre-fill ViewModel from existing CoachProfile data (one-time).
  ///
  /// Uses Provider.read (not watch) since this is initialization-only.
  /// Draft data loaded in [_loadDraft] will override these defaults if present.
  void _prefillFromProfile() {
    final defaults =
        context.read<CoachProfileProvider>().getSmartFlowDefaults();
    if (defaults.isEmpty) return;

    final age = defaults['age'];
    if (age is int) _viewModel.setAge(age);

    final grossSalary = defaults['grossSalary'];
    if (grossSalary is num && grossSalary > 0) {
      _viewModel.setGrossSalary(grossSalary.toDouble());
    }

    final canton = defaults['canton'];
    if (canton is String && canton.isNotEmpty) _viewModel.setCanton(canton);

    final lppBalance = defaults['lppBalance'];
    if (lppBalance is num && lppBalance > 0) {
      _viewModel.setExistingLpp(lppBalance.toDouble());
    }

    final epargne3a = defaults['epargne3a'];
    if (epargne3a is num && epargne3a > 0) {
      _viewModel.setExisting3a(epargne3a.toDouble());
    }

    final epargneLiquide = defaults['epargneLiquide'];
    if (epargneLiquide is num && epargneLiquide > 0) {
      _viewModel.setCurrentSavings(epargneLiquide.toDouble());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animTrigger.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    _onboardingConsent = await SmartOnboardingDraftService.isConsentGiven();
    if (_onboardingConsent != true) return;
    final draft = await SmartOnboardingDraftService.loadDraft();
    if (!mounted || draft.isEmpty) return;

    final age = draft['age'];
    if (age is int) _viewModel.setAge(age);

    final grossSalary = draft['grossSalary'];
    if (grossSalary is num) _viewModel.setGrossSalary(grossSalary.toDouble());

    final canton = draft['canton'];
    if (canton is String && canton.isNotEmpty) _viewModel.setCanton(canton);
  }

  Future<void> _onInputChanged() async {
    if (_onboardingConsent != true) {
      _onboardingConsent ??= await SmartOnboardingDraftService.isConsentGiven();
    }

    if (_onboardingConsent == false && _consentDeclinedThisSession) return;

    if (_onboardingConsent != true) {
      final granted = await _showOnboardingConsentSheet();
      _onboardingConsent = granted;
      if (!granted) _consentDeclinedThisSession = true;
      if (!granted) return;
    }

    await SmartOnboardingDraftService.saveDraft(
      age: _viewModel.age,
      grossSalary: _viewModel.grossSalary,
      canton: _viewModel.canton,
    );
  }

  Future<bool> _showOnboardingConsentSheet() async {
    if (_consentPromptOpen || !mounted) return false;
    _consentPromptOpen = true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sauvegarde locale des reponses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tes reponses peuvent etre sauvegardees localement sur ton appareil '
                  'pour reprendre plus tard. Aucune donnee n est envoyee sans ton accord.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Autoriser'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Continuer sans sauvegarde'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _consentPromptOpen = false;
    final granted = result == true;
    await SmartOnboardingDraftService.setConsent(granted);
    return granted;
  }

  void _goToPage(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onStepQuestionsNext() {
    _goToPage(2);
    // Increment trigger so StepChiffreChoc fires its animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animTrigger.value++;
    });
  }

  /// Generate coaching tips from the current minimal profile.
  /// Memoized: only recomputes when inputs change.
  List<CoachingTip> _generateTips() {
    final profile = _viewModel.profile;
    if (profile == null) return [];

    // Simple cache key based on relevant inputs
    final hash = Object.hash(
      _viewModel.age,
      _viewModel.canton,
      _viewModel.grossSalary,
      _viewModel.existing3a,
      _viewModel.existingLpp,
      _viewModel.currentSavings,
      _viewModel.stressType,
    );
    if (hash == _lastTipsHash && _cachedTips != null) return _cachedTips!;

    final coachingProfile = CoachingProfile(
      age: _viewModel.age,
      canton: _viewModel.canton ?? 'ZH',
      revenuAnnuel: _viewModel.grossSalary,
      has3a: _viewModel.existing3a != null && _viewModel.existing3a! > 0,
      has3aAnswered: _viewModel.existing3a != null,
      montant3a: _viewModel.existing3a ?? 0,
      hasLpp: true,
      avoirLpp: _viewModel.existingLpp ?? 0,
      lacuneLpp: 0,
      chargesFixesMensuelles: profile.estimatedMonthlyExpenses,
      epargneDispo: _viewModel.currentSavings ?? 0,
      hasSavingsAnswered: _viewModel.currentSavings != null,
    );

    final allTips = CoachingService.generateTips(profile: coachingProfile);
    _cachedTips = CoachingService.filterByStressType(
      allTips,
      _viewModel.stressType ?? 'stress_general',
    );
    _lastTipsHash = hash;
    return _cachedTips!;
  }

  Future<void> _saveThenGo(BuildContext context) async {
    _saveProfile(context);
    await SmartOnboardingDraftService.clearDraft();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil cree ! Tu peux tracker tes versements '
            'mensuels dans l\'onglet Agir.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      context.go('/home');
    }
  }

  Future<void> _saveThenCheckin(BuildContext context) async {
    _saveProfile(context);
    await SmartOnboardingDraftService.clearDraft();
    if (context.mounted) context.go('/coach/checkin');
  }

  Future<void> _saveThenEnrich(BuildContext context) async {
    _saveProfile(context);
    await SmartOnboardingDraftService.clearDraft();
    if (context.mounted) context.push('/profile/bilan');
  }

  void _saveProfile(BuildContext context) {
    if (_viewModel.canton == null) return;
    final provider = context.read<CoachProfileProvider>();
    provider.updateFromSmartFlow(
      age: _viewModel.age,
      grossSalary: _viewModel.grossSalary,
      canton: _viewModel.canton!,
      firstName: _viewModel.firstName,
      nationalityGroup: _viewModel.nationalityGroup,
      nationalityCountry: _viewModel.nationalityCountry,
      employmentStatus: _viewModel.employmentStatus,
      primaryFocus: _viewModel.stressType,
    );
    // Apply literacy level derived from calibration questions (Step 1).
    // Done via copyWith after the wizard-based profile is built so we don't
    // need to thread it through the wizard answers map.
    if (provider.profile != null) {
      provider.updateProfile(
        provider.profile!.copyWith(
          financialLiteracyLevel: _viewModel.literacyLevel,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final tips = _generateTips();

        return Scaffold(
          body: PageView(
            controller: _pageController,
            // Disable swipe — navigation is controlled programmatically.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // ── Page 0: Stress intention ────────────────────────────────
              StepStressSelector(
                viewModel: _viewModel,
                onNext: () => _goToPage(1),
              ),

              // ── Page 1: 5 questions + 3 calibrage literacy ───────────────
              StepQuestions(
                viewModel: _viewModel,
                onNext: _onStepQuestionsNext,
                onInputChanged: _onInputChanged,
              ),

              // ── Page 2: Chiffre choc reveal ──────────────────────────────
              StepChiffreChoc(
                viewModel: _viewModel,
                animTrigger: _animTrigger,
                onNext: () => _goToPage(3),
                onEnrich: () => _saveThenEnrich(context),
                onDashboard: () => _saveThenGo(context),
              ),

              // ── Page 3: OCR document upload (LPD-compliant, optional) ────
              StepOcrUpload(
                viewModel: _viewModel,
                onNext: () => _goToPage(4),
              ),

              // ── Page 4: JIT explanation (SI...ALORS) ─────────────────────
              StepJitExplanation(
                chiffreChoc: _viewModel.chiffreChoc,
                onNext: () => _goToPage(5),
                onBack: () => _goToPage(3),
              ),

              // ── Page 5: Top 3 actions ────────────────────────────────────
              StepTopActions(
                tips: tips,
                onNext: () => _goToPage(6),
                onBack: () => _goToPage(4),
              ),

              // ── Page 6: Next step (enrich or dashboard) ──────────────────
              StepNextStep(
                confidenceScore: _viewModel.confidenceScore,
                onEnrich: () => _saveThenEnrich(context),
                onDashboard: () => _saveThenGo(context),
                onCheckin: () => _saveThenCheckin(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
