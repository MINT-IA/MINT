import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_chiffre_choc.dart';
import 'package:mint_mobile/screens/onboarding/steps/step_questions.dart';

/// Smart Onboarding — Value-First Flow (Lot 2).
///
/// Orchestrates the 3-question → chiffre choc → action flow.
/// Uses a [PageView] with programmatic (non-swipeable) navigation so the user
/// always follows the intentional sequence.
///
/// Pages:
///   0: [StepQuestions]    — 3 inputs: salary, age, canton
///   1: [StepChiffreChoc]  — reveal of the first impactful number
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

  /// Incrementing counter — [StepChiffreChoc] listens to this to trigger
  /// its reveal animation without needing cross-file private state access.
  final _animTrigger = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pageController.dispose();
    _animTrigger.dispose();
    super.dispose();
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

  Future<void> _saveThenGo(BuildContext context) async {
    _saveProfile(context);
    if (context.mounted) context.go('/home');
  }

  Future<void> _saveThenEnrich(BuildContext context) async {
    _saveProfile(context);
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
              ),

              // ── Page 1: Chiffre choc reveal ──────────────────────────────
              StepChiffreChoc(
                viewModel: _viewModel,
                animTrigger: _animTrigger,
                onEnrich: () {
                  // Save current profile first, then navigate to enrichment
                  _saveThenEnrich(context);
                },
                onDashboard: () => _saveThenGo(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
