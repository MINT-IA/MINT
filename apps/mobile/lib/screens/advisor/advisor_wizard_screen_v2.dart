import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/widgets/wizard_question_widget.dart';
import 'package:mint_mobile/services/fiscal_intelligence_service.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/circle_transition_widget.dart';
import 'package:mint_mobile/widgets/wizard/wizard_score_preview.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';

/// Wizard V2 avec ordre logique : Profil → Budget → Prévoyance → Patrimoine
class AdvisorWizardScreenV2 extends StatefulWidget {
  const AdvisorWizardScreenV2({super.key});

  @override
  State<AdvisorWizardScreenV2> createState() => _AdvisorWizardScreenV2State();
}

class _AdvisorWizardScreenV2State extends State<AdvisorWizardScreenV2> {
  final Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  late List<WizardQuestion> _questions;


  @override
  void initState() {
    super.initState();
    _questions = WizardQuestionsV2.questions;
    _loadSavedProgress();
  }

  Future<void> _loadSavedProgress() async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isNotEmpty) {
      if (mounted) {
        setState(() {
          _answers.addAll(savedAnswers);
          _recalculateCurrentStep();
        });
      }
    }
  }

  void _recalculateCurrentStep() {
    // Find the first unanswered question that should be asked
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];

      // Skip questions that shouldn't be asked based on conditions
      if (!WizardConditionsService.shouldAskQuestion(q.id, _answers)) {
        continue;
      }

      // If this question has been answered, add to history and continue
      if (_answers.containsKey(q.id)) {
        if (!_questionHistory.contains(q.id)) {
          _questionHistory.add(q.id);
        }
        continue;
      }

      // Found first unanswered question - this is where we resume
      _currentQuestionIndex = i;
      return;
    }

    // All questions answered - wizard is complete
    // Stay at last question (will trigger report on next action)
    _currentQuestionIndex = _questions.length - 1;
  }

  String get _currentSection {
    if (_currentQuestionIndex < 6) return 'Profil';
    if (_currentQuestionIndex < 12) return 'Budget & Protection';
    if (_currentQuestionIndex < 18) return 'Prévoyance';
    return 'Patrimoine';
  }

  int get _sectionStart =>
      _currentQuestionIndex < 6 ? 0 :
      _currentQuestionIndex < 12 ? 6 :
      _currentQuestionIndex < 18 ? 12 : 18;

  int get _sectionEnd =>
      _currentQuestionIndex < 6 ? 6 :
      _currentQuestionIndex < 12 ? 12 :
      _currentQuestionIndex < 18 ? 18 : _questions.length;

  int get _sectionQuestionNumber {
    int count = 0;
    for (int i = _sectionStart; i <= _currentQuestionIndex; i++) {
      if (WizardConditionsService.shouldAskQuestion(_questions[i].id, _answers)) {
        count++;
      }
    }
    return count;
  }

  int get _sectionTotalQuestions {
    int count = 0;
    for (int i = _sectionStart; i < _sectionEnd; i++) {
      if (WizardConditionsService.shouldAskQuestion(_questions[i].id, _answers)) {
        count++;
      }
    }
    return count;
  }

  int get _overallProgress {
    return ((_currentQuestionIndex / _questions.length) * 100).round();
  }

  // Historique des questions posées pour pouvoir revenir en arrière correctement
  final List<String> _questionHistory = [];

  void _handleAnswer(dynamic answer) {
    setState(() {
      final currentQuestion = _questions[_currentQuestionIndex];
      _answers[currentQuestion.id] = answer;

      ReportPersistenceService.saveAnswers(_answers);

      if (!_questionHistory.contains(currentQuestion.id)) {
        _questionHistory.add(currentQuestion.id);
      }

      // Auto-inference LPP : salarié avec revenu > 22'680 CHF/an = LPP obligatoire
      _autoInferLpp();

      final nextQuestion =
          WizardConditionsService.getNextQuestion(currentQuestion.id, _answers);

      if (nextQuestion != null) {
        final nextIndex = _questions.indexWhere((q) => q.id == nextQuestion.id);

        if (nextIndex != -1) {
          final currentSectionBeforeUpdate =
              _getSectionForIndex(_currentQuestionIndex);
          final nextSectionName = _getSectionForIndex(nextIndex);

          if (currentSectionBeforeUpdate != nextSectionName) {
            // Transition Section
            _showSectionTransition(nextSectionName, () {
              setState(() {
                _currentQuestionIndex = nextIndex;
              });
            });
          } else {
            // Même section
            _currentQuestionIndex = nextIndex;
          }
        }
      } else {
        _showReport();
      }
    });
  }

  /// Auto-remplir q_has_pension_fund si salarié avec revenu > seuil LPP
  void _autoInferLpp() {
    if (_answers.containsKey('q_has_pension_fund')) return; // Déjà répondu
    final status = _answers['q_employment_status'];
    final income = _answers['q_net_income_period_chf'];
    if (status == 'employee' && income != null) {
      final monthlyIncome = (income as num).toDouble();
      // Seuil LPP : 22'680 CHF/an (LPP art. 7)
      if (monthlyIncome * 12 > 22680) {
        _answers['q_has_pension_fund'] = 'yes';
        _lppAutoInferred = true;
      }
    }
  }

  bool _lppAutoInferred = false;

  void _goBack() {
    if (_questionHistory.isNotEmpty) {
      setState(() {
        final lastQuestionId = _questionHistory.removeLast();
        final lastIndex = _questions.indexWhere((q) => q.id == lastQuestionId);
        if (lastIndex != -1) {
          _currentQuestionIndex = lastIndex;
        }
      });
    } else if (_currentQuestionIndex > 0) {
      setState(() {
        int prevIndex = _currentQuestionIndex - 1;
        while (prevIndex >= 0) {
          final q = _questions[prevIndex];
          if (WizardConditionsService.shouldAskQuestion(q.id, _answers)) {
            _currentQuestionIndex = prevIndex;
            return;
          }
          prevIndex--;
        }
        _showExitConfirmation();
      });
    } else {
      _showExitConfirmation();
    }
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_outline,
                  color: MintColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Sauvegarder et quitter ?',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tes reponses sont sauvegardees automatiquement. '
              'Tu pourras reprendre exactement ou tu en etais.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_overallProgress% complete — $_currentSection',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Continuer mon diagnostic',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.textSecondary,
                  side: const BorderSide(color: MintColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Sauvegarder et quitter'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }

  void _showReport() {
    ReportPersistenceService.setCompleted(true);
    // Update CoachProfileProvider with wizard answers for immediate display
    context.read<CoachProfileProvider>().updateFromAnswers(_answers);

    // Auto-init budget from wizard answers
    final budgetInputs = BudgetInputs.fromMap(_answers);
    context.read<BudgetProvider>().setInputs(budgetInputs);

    // Build CoachProfile and compute Financial Fitness Score for the reveal
    final profile = CoachProfile.fromWizardAnswers(_answers);
    final score = FinancialFitnessService.calculate(profile: profile);

    // Navigate to the score reveal screen (the "ta-da" moment)
    context.go('/score-reveal', extra: {
      'score': score,
      'profile': profile,
      'wizardAnswers': Map<String, dynamic>.from(_answers),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];

    // Dynamic subtitle override based on profile context
    final dynamicSubtitle = WizardQuestionsV2.getDynamicSubtitle(
        currentQuestion.id, _answers);
    final displayQuestion = dynamicSubtitle != null
        ? WizardQuestion(
            id: currentQuestion.id,
            title: currentQuestion.title,
            subtitle: dynamicSubtitle,
            type: currentQuestion.type,
            options: currentQuestion.options,
            tags: currentQuestion.tags,
            minValue: currentQuestion.minValue,
            maxValue: currentQuestion.maxValue,
          )
        : currentQuestion;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.8),
        foregroundColor: MintColors.textPrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _goBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentSection,
              style: GoogleFonts.outfit(
                fontSize: 16, 
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              'Question $_sectionQuestionNumber/$_sectionTotalQuestions',
              style: GoogleFonts.inter(
                fontSize: 12, 
                color: MintColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_overallProgress%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            tooltip: 'Sauvegarder et quitter',
            onPressed: _showExitConfirmation,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: _overallProgress / 100,
            backgroundColor: MintColors.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(MintColors.primary),
            minHeight: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Question widget
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('wizard_scroll_view'),
                child: Column(
                  children: [
                    // LPP auto-inference banner
                    if (_lppAutoInferred &&
                        currentQuestion.id == 'q_has_pension_fund')
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MintColors.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: MintColors.info.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: MintColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'En tant que salarié(e) avec un revenu > 22\'680 CHF/an, '
                                'tu es automatiquement affilié(e) à la LPP (art. 7).',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: MintColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    WizardQuestionWidget(
                      key: ValueKey(displayQuestion.id),
                      question: displayQuestion,
                      onAnswer: _handleAnswer,
                      currentAnswer: _answers[currentQuestion.id],
                      answers: _answers,
                      defaultExpanded: _currentQuestionIndex < 3,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _buildInsightWidget(),
                    ),
                  ],
                ),
              ),
            ),
            // Score preview — persistent bottom bar
            WizardScorePreview(
              key: ValueKey('score_preview_${_answers.length}'),
              answers: Map<String, dynamic>.from(_answers),
              currentQuestionIndex: _currentQuestionIndex,
              totalQuestions: _questions.length,
              currentSection: _currentSection,
            ),
          ],
        ),
      ),
    );
  }

  /// Construit un widget de "Feedback Educatif (Hermeneutic Loop)"
  /// qui illumine le "Pourquoi" derrière la question actuelle.
  Widget _buildInsightWidget() {
    // 1. Fiscal Intelligence (Si revenu, canton et âge connus)
    if (_answers['q_net_income_period_chf'] != null &&
        _answers['q_canton'] != null &&
        _answers['q_birth_year'] != null) {
      final income = (_answers['q_net_income_period_chf'] as num).toDouble();
      final canton = _answers['q_canton'] as String;
      final birthYear = (_answers['q_birth_year'] as num).toInt();
      final age = DateTime.now().year - birthYear;
      final status = _answers['q_civil_status'] as String? ?? 'single';
      final children =
          int.tryParse(_answers['q_children'] as String? ?? '0') ?? 0;

      // Afficher cet insight surtout quand on parle d'épargne ou prévoyance
      if (_currentSection == 'Budget & Protection' ||
          _currentSection == 'Prévoyance') {
        final annualTax = TaxEstimatorService.estimateAnnualTax(
          netMonthlyIncome: income,
          cantonCode: canton,
          civilStatus: status,
          childrenCount: children,
          age: age,
        );

        final monthsForTax =
            FiscalIntelligenceService.calculateMonthsWorkedForTax(
          annualTax: annualTax,
          netAnnualIncome: income * 12,
        );

        // DATE DE LIBÉRATION FISCALE
        final dayOfYear = (monthsForTax * 30).round();
        final taxFreedomDate =
            DateTime(DateTime.now().year, 1, 1).add(Duration(days: dayOfYear));
        final formattedDate = "${taxFreedomDate.day}.${taxFreedomDate.month}";

        // COMPARAISON VOISIN
        final neighborComp = FiscalIntelligenceService.findBetterNeighbor(
          currentCanton: canton,
          netMonthlyIncome: income,
          civilStatus: status,
          age: age,
          childrenCount: children,
        );

        return Column(
          children: [
            // Insight 1: Tax Freedom
            Container(
              key: const ValueKey('tax_freedom'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MintColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: MintColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "INSIGHT FISCAL",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MintColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: MintColors.textPrimary,
                                height: 1.5),
                            children: [
                              const TextSpan(text: "Tu travailles jusqu'au "),
                              TextSpan(
                                  text: formattedDate,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: MintColors.primary)),
                              TextSpan(
                                  text:
                                      " pour couvrir tes impôts (${monthsForTax.toStringAsFixed(1)} mois)."),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (neighborComp != null) ...[
              const SizedBox(height: 16),
              // Insight 2: Neighbor Comparison
              Container(
                key: const ValueKey('neighbor_comp'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MintColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.compare_arrows,
                          color: MintColors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "OPTIMISATION LOCALE",
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: MintColors.textPrimary,
                                  height: 1.5),
                              children: [
                                const TextSpan(text: "À "),
                                TextSpan(
                                    text: "${neighborComp['canton']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: MintColors.primary)),
                                const TextSpan(text: ", l'économie serait de "),
                                TextSpan(
                                    text:
                                        "CHF ${(neighborComp['savings'] as double).toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: MintColors.primary)),
                                const TextSpan(text: "/an."),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      }
    }

    // 2. Insight Compound Interest (Si épargne mensuelle connue)
    if (_answers['q_savings_monthly'] != null) {
      final savings = (_answers['q_savings_monthly'] as num).toDouble();
      if (savings > 0 && _currentSection == 'Patrimoine') {
        // Simulation 20 ans @ 5%
        final totalFuture =
            savings * 12 * 20 * 1.6; // approx x1.6 sur 20 ans à 5%
        final gain = totalFuture - (savings * 12 * 20);

        return Container(
          key: const ValueKey('compound_insight'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD), // Bleu très doux
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF1565C0), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "En investissant cette épargne, tu pourrais gagner +CHF ${gain.toStringAsFixed(0)} d'intérêts sur 20 ans.",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return const SizedBox.shrink(); // Pas d'insight pour le moment
  }

  void _showSectionTransition(String nextSection, VoidCallback onComplete) {
    String description = "";
    IconData icon = Icons.star;
    Color color = MintColors.primary;

    switch (nextSection) {
      case 'Budget & Protection':
        description =
            "Analysons ta stabilité financière (Dettes, Fonds d'urgence).\n\nCercle 1/3";
        icon = Icons.shield_rounded;
        color = Colors.green;
        break;
      case 'Prévoyance':
        description =
            "Optimisons tes impôts et ta retraite (LPP, 3a).\n\nCercle 2/3";
        icon = Icons.savings_rounded;
        color = Colors.blue;
        break;
      case 'Patrimoine':
        description = "Parlons investissement et projets futurs.\n\nCercle 3/3";
        icon = Icons.trending_up_rounded;
        color = Colors.orange;
        break;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => CircleTransitionWidget(
          nextSectionName: nextSection,
          description: description,
          icon: icon,
          color: color,
          onComplete: () {
            Navigator.of(context).pop();
            onComplete();
          },
        ),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  String _getSectionForIndex(int index) {
    if (index < 6) return 'Profil';
    if (index < 12) return 'Budget & Protection';
    if (index < 18) return 'Prévoyance';
    return 'Patrimoine';
  }
}
