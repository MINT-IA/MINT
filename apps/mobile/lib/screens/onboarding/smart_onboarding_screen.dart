import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_chiffre_choc.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_jit_explanation.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_next_step.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_questions.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_top_actions.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';

// ZERO-PERSISTENCE GUARANTEE (P1):
// All onboarding inputs stay in-memory until the user explicitly saves.
// No SharedPreferences, no analytics payload, no auto-save before consent.

/// Smart Onboarding — Value-First Flow (Lot 2 + P8-2).
///
/// Orchestrates the 5-step onboarding experience:
///   0: [StepQuestions]       — 3 inputs: salary, age, canton
///   1: [StepChiffreChoc]     — reveal of the first impactful number
///   2: [StepJitExplanation]  — SI...ALORS mini-explanation
///   3: [StepTopActions]      — Top 3 coaching tips
///   4: [StepNextStep]        — Enrich profile or go to dashboard
///
/// Uses a [PageView] with programmatic (non-swipeable) navigation so the user
/// always follows the intentional sequence.
///
/// The ViewModel is owned here and passed down to each step.
/// State is managed via [ListenableBuilder] over the ViewModel.
///
/// The reveal animation on page 1 is triggered via [_animTrigger],
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

  @override
  void initState() {
    super.initState();
    _loadDraft();
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
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onStepQuestionsNext() {
    _goToPage(1);
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
    );
    if (hash == _lastTipsHash && _cachedTips != null) return _cachedTips!;

    final coachingProfile = CoachingProfile(
      age: _viewModel.age,
      canton: _viewModel.canton ?? 'ZH',
      revenuAnnuel: _viewModel.grossSalary,
      has3a: _viewModel.existing3a != null && _viewModel.existing3a! > 0,
      montant3a: _viewModel.existing3a ?? 0,
      hasLpp: true,
      avoirLpp: _viewModel.existingLpp ?? 0,
      lacuneLpp: 0,
      chargesFixesMensuelles: profile.estimatedMonthlyExpenses,
      epargneDispo: _viewModel.currentSavings ?? 0,
    );

    final allTips = CoachingService.generateTips(profile: coachingProfile);
    _cachedTips = CoachingService.filterByStressType(allTips, 'stress_general');
    _lastTipsHash = hash;
    return _cachedTips!;
  }

  Future<void> _saveThenGo(BuildContext context) async {
    _saveProfile(context);
    await SmartOnboardingDraftService.clearDraft();
    if (context.mounted) context.go('/home');
  }

  Future<void> _saveThenEnrich(BuildContext context) async {
    _saveProfile(context);
    await SmartOnboardingDraftService.clearDraft();
    if (context.mounted) context.push('/onboarding/enrichment');
  }

  void _saveProfile(BuildContext context) {
    if (_viewModel.canton == null) return;
    context.read<CoachProfileProvider>().updateFromSmartFlow(
          age: _viewModel.age,
          grossSalary: _viewModel.grossSalary,
          canton: _viewModel.canton!,
        );
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
              // ── Page 0: 3 questions ──────────────────────────────────────
              StepQuestions(
                viewModel: _viewModel,
                onNext: _onStepQuestionsNext,
                onInputChanged: _onInputChanged,
              ),

              // ── Page 1: Chiffre choc reveal ──────────────────────────────
              StepChiffreChoc(
                viewModel: _viewModel,
                animTrigger: _animTrigger,
                onEnrich: () => _goToPage(2),
                onDashboard: () => _goToPage(2),
              ),

              // ── Page 2: JIT explanation (SI...ALORS) ─────────────────────
              StepJitExplanation(
                chiffreChoc: _viewModel.chiffreChoc,
                onNext: () => _goToPage(3),
                onBack: () => _goToPage(1),
              ),

              // ── Page 3: Top 3 actions ────────────────────────────────────
              StepTopActions(
                tips: tips,
                onNext: () => _goToPage(4),
                onBack: () => _goToPage(2),
              ),

              // ── Page 4: Next step (enrich or dashboard) ──────────────────
              StepNextStep(
                confidenceScore: _viewModel.confidenceScore,
                onEnrich: () => _saveThenEnrich(context),
                onDashboard: () => _saveThenGo(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
