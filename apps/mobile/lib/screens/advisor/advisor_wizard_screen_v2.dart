import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/widgets/wizard_question_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/fiscal_intelligence_service.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/wizard/wizard_score_preview.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';

/// Wizard V2 avec ordre logique : Profil → Budget → Prévoyance → Patrimoine
class AdvisorWizardScreenV2 extends StatefulWidget {
  final String? initialSection;
  const AdvisorWizardScreenV2({super.key, this.initialSection});

  @override
  State<AdvisorWizardScreenV2> createState() => _AdvisorWizardScreenV2State();
}

class _AdvisorWizardScreenV2State extends State<AdvisorWizardScreenV2> {
  final Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  late List<WizardQuestion> _questions;
  bool _showDeductionScreen = false;

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
          // Show deduction screen if coming from mini-onboarding with significant data
          final isMiniUser = savedAnswers.containsKey('q_net_income_period_chf') &&
              savedAnswers.containsKey('q_canton');
          _showDeductionScreen = isMiniUser && widget.initialSection != null;
        });
      }
    }
    // Jump to requested section if specified via route parameter
    if (widget.initialSection != null && mounted && !_showDeductionScreen) {
      _jumpToSection(widget.initialSection!);
    }
  }

  List<DeductionItem> _buildDeductionItems() {
    final items = <DeductionItem>[];
    // Emergency fund coverage
    final cash = _toDouble(_answers['q_cash_total']) ?? 0;
    final housing = _toDouble(_answers['q_housing_cost_period_chf']) ?? 0;
    final tax = _toDouble(_answers['q_tax_provision_monthly_chf']) ?? 0;
    final lamal = _toDouble(_answers['q_lamal_premium_monthly_chf']) ?? 0;
    final other = _toDouble(_answers['q_other_fixed_costs_monthly_chf']) ?? 0;
    final debt = _toDouble(_answers['q_debt_payments_period_chf']) ?? 0;
    final monthlyExpenses = housing + tax + lamal + other + debt;
    if (monthlyExpenses > 0 && cash > 0) {
      final months = cash / monthlyExpenses;
      items.add(DeductionItem(
        label: 'Fonds d'urgence',
        value: '${months.toStringAsFixed(1)} mois de charges',
        source: 'liquidités / charges',
        isPositive: months >= 3,
      ));
    }
    // Computed savings
    final income = _toDouble(_answers['q_net_income_period_chf']) ?? 0;
    if (income > 0 && monthlyExpenses > 0) {
      final surplus = income - monthlyExpenses;
      items.add(DeductionItem(
        label: 'Capacité d'épargne',
        value: 'CHF ${surplus.round()}/mois',
        source: 'revenu - dépenses',
        isPositive: surplus > 0,
      ));
    }
    // LPP status
    final employment = _answers['q_employment_status'];
    if (employment == 'employee' && income * 12 > 22680) {
      items.add(const DeductionItem(
        label: 'Caisse de pension (LPP)',
        value: 'Affilié (obligatoire)',
        source: 'salarié + revenu > 22k',
      ));
    }
    // Debt status
    if (debt > 0) {
      items.add(DeductionItem(
        label: 'Dettes de consommation',
        value: 'CHF ${debt.round()}/mois de remboursements',
        source: 'déclaré',
        isPositive: false,
      ));
    } else {
      items.add(const DeductionItem(
        label: 'Dettes de consommation',
        value: 'Aucune',
        source: 'déclaré',
      ));
    }
    // Property equity
    final propertyValue = _toDouble(_answers['q_property_value']) ?? 0;
    final mortgageBalance = _toDouble(_answers['q_mortgage_balance']) ?? 0;
    if (propertyValue > 0) {
      final equity = propertyValue - mortgageBalance;
      final ltv = (mortgageBalance / propertyValue * 100);
      items.add(DeductionItem(
        label: 'Patrimoine immobilier',
        value: 'Équité CHF ${equity.round()} (LTV ${ltv.toStringAsFixed(0)}%)',
        source: 'bien - hypothèque',
        isPositive: ltv <= 80,
      ));
    }
    return items;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().replaceAll("'", '').trim());
  }

  void _jumpToSection(String section) {
    final sectionIndex = switch (section) {
      'identity' || 'profil' => 0,
      'income' || 'budget' => 8,
      'pension' || 'prevoyance' => 17,
      'property' || 'patrimoine' => 29,
      _ => 0,
    };
    final sectionEndIndex = switch (section) {
      'identity' || 'profil' => 8,
      'income' || 'budget' => 17,
      'pension' || 'prevoyance' => 29,
      'property' || 'patrimoine' => _questions.length,
      _ => _questions.length,
    };
    setState(() {
      // Find first UNANSWERED question in this section (skip already-filled)
      for (int i = sectionIndex; i < sectionEndIndex && i < _questions.length; i++) {
        final q = _questions[i];
        if (!WizardConditionsService.shouldAskQuestion(q.id, _answers)) continue;
        if (_answers.containsKey(q.id)) {
          if (!_questionHistory.contains(q.id)) _questionHistory.add(q.id);
          continue;
        }
        // Found first unanswered question in this section
        _currentQuestionIndex = i;
        return;
      }
      // All questions in this section answered — find first unanswered globally
      _recalculateCurrentStep();
    });
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
    if (_currentQuestionIndex < 8) return 'Profil';
    if (_currentQuestionIndex < 17) return 'Budget & Protection';
    if (_currentQuestionIndex < 29) return 'Prévoyance';
    return 'Patrimoine';
  }

  int get _sectionStart => _currentQuestionIndex < 8
      ? 0
      : _currentQuestionIndex < 17
          ? 8
          : _currentQuestionIndex < 29
              ? 17
              : 29;

  int get _sectionEnd => _currentQuestionIndex < 8
      ? 8
      : _currentQuestionIndex < 17
          ? 17
          : _currentQuestionIndex < 29
              ? 29
              : _questions.length;

  int get _sectionQuestionNumber {
    int count = 0;
    for (int i = _sectionStart; i <= _currentQuestionIndex; i++) {
      if (WizardConditionsService.shouldAskQuestion(
          _questions[i].id, _answers)) {
        count++;
      }
    }
    return count;
  }

  int get _sectionTotalQuestions {
    int count = 0;
    for (int i = _sectionStart; i < _sectionEnd; i++) {
      if (WizardConditionsService.shouldAskQuestion(
          _questions[i].id, _answers)) {
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
    final currentQuestion = _questions[_currentQuestionIndex];

    // For multiChoice questions: save the selection without advancing.
    // The user must tap "Valider" (which calls _advanceFromCurrent).
    if (currentQuestion.type == QuestionType.multiChoice && answer is List) {
      setState(() {
        _answers[currentQuestion.id] = answer;
        ReportPersistenceService.saveAnswers(_answers);
      });
      return;
    }

    setState(() {
      _answers[currentQuestion.id] = answer;

      ReportPersistenceService.saveAnswers(_answers);

      if (!_questionHistory.contains(currentQuestion.id)) {
        _questionHistory.add(currentQuestion.id);
      }

      // Auto-inference LPP : salarié avec revenu > 22'680 CHF/an = LPP obligatoire
      _autoInferLpp();

      _navigateToNextQuestion(currentQuestion);
    });
  }

  /// Advance from the current multiChoice question after user confirms.
  void _advanceFromCurrent() {
    setState(() {
      final currentQuestion = _questions[_currentQuestionIndex];
      if (!_questionHistory.contains(currentQuestion.id)) {
        _questionHistory.add(currentQuestion.id);
      }
      _autoInferLpp();
      _navigateToNextQuestion(currentQuestion);
    });
  }

  void _navigateToNextQuestion(WizardQuestion currentQuestion) {
    final nextQuestion =
        WizardConditionsService.getNextQuestion(currentQuestion.id, _answers);

    if (nextQuestion != null) {
      final nextIndex = _questions.indexWhere((q) => q.id == nextQuestion.id);

      if (nextIndex != -1) {
        final currentSectionBeforeUpdate =
            _getSectionForIndex(_currentQuestionIndex);
        final nextSectionName = _getSectionForIndex(nextIndex);

        if (currentSectionBeforeUpdate != nextSectionName) {
          _announceSectionChange(nextSectionName);
          _currentQuestionIndex = nextIndex;
        } else {
          // Même section
          _currentQuestionIndex = nextIndex;
        }
      }
    } else {
      _showReport();
    }
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
    final dynamicSubtitle =
        WizardQuestionsV2.getDynamicSubtitle(currentQuestion.id, _answers);
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
        backgroundColor: Colors.white.withValues(alpha: 0.8),
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
                          color: MintColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: MintColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: MintColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⚡ Estimation — Ton revenu dépasse le seuil LPP '
                                    'de 22'680 CHF/an (art. 7). En tant que salarié·e, '
                                    'tu es en principe affilié·e. '
                                    'Tu peux corriger ci-dessous si nécessaire.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: MintColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _answers.remove('q_has_pension_fund');
                                        _lppAutoInferred = false;
                                      });
                                    },
                                    child: Text(
                                      'Corriger',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: MintColors.info,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_showDeductionScreen) ...[
                      CoachDeductionCard(
                        items: _buildDeductionItems(),
                        onConfirm: () {
                          setState(() {
                            _showDeductionScreen = false;
                            if (widget.initialSection != null) {
                              _jumpToSection(widget.initialSection!);
                            }
                          });
                        },
                        onCorrect: () {
                          setState(() {
                            _showDeductionScreen = false;
                            // Go to Section 2 (Budget) to correct deductions
                            _jumpToSection('budget');
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      WizardQuestionWidget(
                        key: ValueKey(displayQuestion.id),
                        question: displayQuestion,
                        onAnswer: _handleAnswer,
                        currentAnswer: _answers[currentQuestion.id],
                        answers: _answers,
                        defaultExpanded: _currentQuestionIndex < 3,
                        onMultiChoiceConfirm: _advanceFromCurrent,
                      ),
                    ],
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

  /// One unique, mind-blowing insight per wizard question.
  /// Each insight is contextual and uses the user's actual data.
  Widget _buildInsightWidget() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final qId = currentQuestion.id;

    switch (qId) {
      // ── PROFIL ──

      case 'q_birth_year':
        if (_answers['q_birth_year'] != null) {
          final age = _currentAge;
          final yearsToRetirement = (65 - age).clamp(0, 50);
          final horizon = yearsToRetirement > 0
              ? 'Dans $yearsToRetirement ans, CHF 100 investis aujourd'hui '
                'pourraient valoir CHF ${(100 * _compoundFactor(yearsToRetirement)).toStringAsFixed(0)} (5%/an).'
              : 'A $age ans, tu es proche de la retraite. Chaque franc optimise compte.';
          return _buildMindBlowingInsight(
            icon: Icons.timer_outlined,
            title: 'TON HORIZON',
            text: horizon,
            color: MintColors.primary,
          );
        }

      case 'q_canton':
        if (_answers['q_canton'] != null) {
          return _buildMindBlowingInsight(
            icon: Icons.map_outlined,
            title: 'SAVIEZ-VOUS ?',
            text: 'L'ecart d'impots entre le canton le moins cher (ZG) et le plus cher (GE) '
                'peut depasser CHF 20'000/an pour un meme revenu. '
                'Le canton est le levier fiscal n\u00b01 en Suisse.',
            color: Colors.indigo,
          );
        }

      case 'q_civil_status':
        final civilAnswer = _answers['q_civil_status'] as String?;
        if (civilAnswer == 'cohabiting') {
          // Concubinage: Swiss CFA-level warnings
          return _buildMindBlowingInsight(
            icon: Icons.warning_amber,
            title: 'CONCUBINAGE : ZERO PROTECTION LEGALE',
            text: 'Le concubinage n'existe PAS en droit suisse (CC). '
                'Consequences : pas de rente de survivant AVS, '
                'pas de beneficiaire LPP automatique, '
                'pas de droits successoraux, '
                'pas de splitting fiscal. '
                'Actions urgentes : testament, clause beneficiaire LPP/3a, '
                'assurance deces croisee.',
            color: Colors.red.shade700,
          );
        }
        return _buildMindBlowingInsight(
          icon: Icons.balance_outlined,
          title: 'IMPACT FISCAL',
          text: 'Marie = Splitting fiscal (impots calcules sur la moitie du revenu cumule). '
              'Concubinage = Chacun est impose individuellement. '
              'Difference possible : plusieurs milliers de CHF/an.',
          color: Colors.deepPurple,
        );

      case 'q_children':
        return _buildMindBlowingInsight(
          icon: Icons.child_care,
          title: 'DEDUCTIONS ENFANTS',
          text: 'Chaque enfant = CHF 6'600 de deduction federale (LIFD art. 35) '
              '+ deduction cantonale (CHF 6'000-13'000 selon canton) '
              '+ allocations familiales CHF 200-400/mois.',
          color: Colors.teal,
        );

      case 'q_employment_status':
        return _buildMindBlowingInsight(
          icon: Icons.work_outline,
          title: 'CLE DE VOUTE',
          text: 'Ton statut professionnel determine tout : '
              'Salarie = LPP obligatoire + 3a max 7'258 CHF. '
              'Independant = Pas de LPP + 3a max 36'288 CHF (5x plus !). '
              'Le bon statut peut changer toute ta strategie.',
          color: Colors.blueGrey,
        );

      // ── BUDGET & PROTECTION ──

      case 'q_net_income_period_chf':
        if (_answers['q_net_income_period_chf'] != null &&
            _answers['q_canton'] != null &&
            _answers['q_birth_year'] != null) {
          return _buildFiscalInsight();
        }

      case 'q_gross_income':
        if (_answers['q_gross_income'] != null && _answers['q_net_income_period_chf'] != null) {
          final gross = (_answers['q_gross_income'] as num).toDouble();
          final net = (_answers['q_net_income_period_chf'] as num).toDouble();
          final charges = gross - net;
          final chargesPercent = gross > 0 ? (charges / gross * 100) : 0;
          return _buildMindBlowingInsight(
            icon: Icons.receipt_long,
            title: 'TES CHARGES SOCIALES',
            text: 'Brut CHF ${gross.round()} - Net CHF ${net.round()} = '
                'CHF ${charges.round()}/mois de charges sociales (${chargesPercent.toStringAsFixed(1)}%). '
                'Dont AVS 5.3%, LPP ~7-18% selon ton âge, AC 1.1%. '
                'Ces cotisations construisent ta retraite — ce n'est pas de l'argent perdu.',
            color: Colors.blueGrey,
          );
        }

      case 'q_housing_status':
        return _buildMindBlowingInsight(
          icon: Icons.home_outlined,
          title: 'LOUER VS ACHETER',
          text: 'En Suisse, la regle FINMA : '
              'charges max 1/3 du revenu brut, fonds propres min 20%. '
              'Un salaire de CHF 8'000/mois = prix max ~CHF 650'000. '
              'Locataire n'est pas "perdre de l'argent" — c'est de la flexibilite.',
          color: Colors.brown,
        );

      case 'q_housing_cost_period_chf':
        if (_answers['q_net_income_period_chf'] != null &&
            _answers['q_housing_cost_period_chf'] != null) {
          final income = (_answers['q_net_income_period_chf'] as num).toDouble();
          final housing = (_answers['q_housing_cost_period_chf'] as num).toDouble();
          final ratio = income > 0 ? (housing / income * 100) : 0;
          final verdict = ratio > 33
              ? 'Au-dessus du seuil recommande (33%). Attention a ta capacite d'epargne.'
              : ratio > 25
                  ? 'Dans la norme suisse. Marge de manoeuvre correcte.'
                  : 'Excellent ratio ! Tu as une belle capacite d'epargne.';
          return _buildMindBlowingInsight(
            icon: Icons.pie_chart_outline,
            title: 'TON RATIO LOGEMENT',
            text: 'Ton logement = ${ratio.toStringAsFixed(0)}% de ton revenu. $verdict '
                'Norme FINMA : max 33% du revenu brut.',
            color: ratio > 33 ? Colors.red.shade700 : Colors.green.shade700,
          );
        }

      case 'q_has_consumer_debt':
        return _buildMindBlowingInsight(
          icon: Icons.priority_high,
          title: 'MATHEMATIQUE CRUELLE',
          text: 'Un credit conso a 9.9% coute CHF 4'950/an sur CHF 50'000 de dette. '
              'Un ETF monde rapporte ~6%/an. Rembourser ses dettes = '
              'le placement le plus rentable et le seul GARANTI.',
          color: Colors.red.shade700,
        );

      case 'q_debt_payments_period_chf':
        if (_answers['q_debt_payments_period_chf'] != null) {
          final monthly = (_answers['q_debt_payments_period_chf'] as num).toDouble();
          final annualCost = monthly * 12;
          return _buildMindBlowingInsight(
            icon: Icons.trending_down,
            title: 'COUT ANNUEL',
            text: 'Tes remboursements = CHF ${annualCost.toStringAsFixed(0)}/an. '
                'En 10 ans, c'est CHF ${(annualCost * 10).toStringAsFixed(0)} qui ne travaillent pas pour toi. '
                'Methode avalanche : rembourse d'abord le taux le plus eleve.',
            color: Colors.orange.shade800,
          );
        }

      case 'q_total_debt_balance_chf':
        if (_answers['q_total_debt_balance_chf'] != null &&
            _answers['q_debt_payments_period_chf'] != null) {
          final total = (_answers['q_total_debt_balance_chf'] as num).toDouble();
          final monthly = (_answers['q_debt_payments_period_chf'] as num).toDouble();
          final monthsToFreedom = monthly > 0 ? (total / monthly).ceil() : 999;
          final yearsToFreedom = (monthsToFreedom / 12).ceil();
          return _buildMindBlowingInsight(
            icon: Icons.flag_outlined,
            title: 'DATE DE LIBERTE',
            text: 'A CHF ${monthly.toStringAsFixed(0)}/mois, tu seras libre de dettes '
                'dans ~$monthsToFreedom mois ($yearsToFreedom ans). '
                'Augmenter de CHF 200/mois = ${((total / (monthly + 200)).ceil())} mois au lieu de $monthsToFreedom.',
            color: Colors.green.shade700,
          );
        }

      case 'q_lamal_franchise':
        return _buildMindBlowingInsight(
          icon: Icons.health_and_safety,
          title: 'LA REGLE DES CHF 5'000',
          text: 'Franchise 300 → 2'500 CHF = économie ~CHF 1'500-2'400/an de primes. '
              'Si tu as >CHF 5'000 d'épargne d'urgence et <2 visites médecin/an, '
              'la franchise haute est mathématiquement rentable. '
              'Sinon, reste à 300 CHF pour la tranquillité d'esprit.',
          color: Colors.teal,
        );

      // q_emergency_fund and q_savings_monthly removed — deduced from data

      case 'q_savings_allocation':
        if (_answers['q_savings_monthly'] != null) {
          final savings = (_answers['q_savings_monthly'] as num).toDouble();
          if (savings > 0) {
            final totalFuture = savings * 12 * 20 * 1.6;
            final gain = totalFuture - (savings * 12 * 20);
            return _buildMindBlowingInsight(
              icon: Icons.auto_graph,
              title: 'INTERET COMPOSE',
              text: 'CHF ${savings.toStringAsFixed(0)}/mois investis pendant 20 ans = '
                  'CHF ${totalFuture.toStringAsFixed(0)} dont CHF ${gain.toStringAsFixed(0)} d'interets purs. '
                  'Einstein appelait les interets composes "la 8e merveille du monde".',
              color: const Color(0xFF1565C0),
            );
          }
        }

      // ── PREVOYANCE ──

      case 'q_has_pension_fund':
        if (_answers['q_employment_status'] != null) {
          final status = _answers['q_employment_status'] as String;
          if (status == 'employee') {
            return _buildMindBlowingInsight(
              icon: Icons.account_balance,
              title: 'TON 2E PILIER',
              text: 'En tant que salarie, ton employeur cotise autant que toi a ta LPP. '
                  'C'est de l'argent "gratuit" — CHF 3'000-10'000/an selon ton age. '
                  'Taux de conversion garanti : 6.8% sur la part obligatoire (LPP art. 14).',
              color: MintColors.info,
            );
          } else {
            return _buildMindBlowingInsight(
              icon: Icons.account_balance,
              title: 'LPP VOLONTAIRE',
              text: 'Les independants peuvent s'affilier volontairement (LPP art. 4). '
                  'Avantage : cotisations deductibles des impots + '
                  'capital bloque pour un achat immobilier (EPL).',
              color: MintColors.info,
            );
          }
        }

      case 'q_lpp_buyback_available':
        if (_answers['q_net_income_period_chf'] != null && _answers['q_canton'] != null) {
          final income = (_answers['q_net_income_period_chf'] as num).toDouble();
          final canton = _answers['q_canton'] as String;
          // Estimate marginal rate
          final marginalRate = TaxEstimatorService.estimateMarginalTaxRate(
            netMonthlyIncome: income,
            cantonCode: canton,
            civilStatus: _answers['q_civil_status'] as String? ?? 'single',
          ).clamp(0.10, 0.50);
          return _buildMindBlowingInsight(
            icon: Icons.savings,
            title: 'RACHAT = DEDUCTION ILLIMITEE',
            text: 'Contrairement au 3a (plafond 7'258 CHF), le rachat LPP n'a PAS de plafond annuel. '
                'A ton taux marginal de ${(marginalRate * 100).toStringAsFixed(0)}% ($canton), '
                'un rachat de CHF 10'000 = economie fiscale de CHF ${(10000 * marginalRate).toStringAsFixed(0)}. '
                'Attention : blocage 3 ans si retrait (LPP art. 79b).',
            color: Colors.green.shade700,
          );
        }

      case 'q_lpp_current_capital':
        if (_answers['q_lpp_current_capital'] != null && _answers['q_birth_year'] != null) {
          final capital = (_answers['q_lpp_current_capital'] as num).toDouble();
          final age = _currentAge;
          final yearsToRetirement = (65 - age).clamp(0, 40);
          final projectedPension = capital * lppTauxConversionMin / 100;
          final monthlyPension = projectedPension / 12;
          return _buildMindBlowingInsight(
            icon: Icons.account_balance,
            title: 'TA RENTE LPP PROJETEE',
            text: 'Capital actuel CHF ${capital.round()} × taux de conversion 6.8% = '
                'CHF ${projectedPension.round()}/an (CHF ${monthlyPension.round()}/mois) '
                'sur la part obligatoire. Avec $yearsToRetirement ans de cotisations restantes, '
                'ton capital va encore croître significativement.',
            color: MintColors.info,
          );
        }

      case 'q_has_3a':
        if (_answers['q_net_income_period_chf'] != null && _answers['q_canton'] != null) {
          return _build3aInsight();
        }

      case 'q_3a_accounts_count':
        return _buildMindBlowingInsight(
          icon: Icons.account_balance_wallet,
          title: 'STRATEGIE MULTI-COMPTES',
          text: 'Les retraits 3a sont imposes progressivement. '
              'Avec 3 comptes retires sur 3 ans differents, tu paies le taux le plus bas chaque annee. '
              'Economie potentielle : CHF 5'000-15'000 sur l'ensemble du capital.',
          color: Colors.purple,
        );

      // q_3a_providers removed — zero calc impact

      case 'q_3a_annual_contribution':
        if (_answers['q_3a_annual_contribution'] != null) {
          final contribution = (_answers['q_3a_annual_contribution'] as num).toDouble();
          final max3a = 7258.0;
          final gap = (max3a - contribution).clamp(0, max3a);
          if (gap > 500 && _answers['q_canton'] != null) {
            final canton = _answers['q_canton'] as String;
            final marginalRate = TaxEstimatorService.estimateMarginalTaxRate(
              netMonthlyIncome: (_answers['q_net_income_period_chf'] as num?)?.toDouble() ?? 6000,
              cantonCode: canton,
              civilStatus: _answers['q_civil_status'] as String? ?? 'single',
            ).clamp(0.10, 0.50);
            final missedSavings = gap * marginalRate;
            return _buildMindBlowingInsight(
              icon: Icons.warning_amber,
              title: 'ARGENT LAISSE SUR LA TABLE',
              text: 'Tu verses CHF ${contribution.toStringAsFixed(0)} au lieu du max de CHF ${max3a.toStringAsFixed(0)}. '
                  'Gap : CHF ${gap.toStringAsFixed(0)}/an = CHF ${missedSavings.toStringAsFixed(0)} d'impots '
                  'non economises chaque annee dans le canton $canton.',
              color: Colors.amber.shade800,
            );
          }
        }

      case 'q_avs_lacunes_status':
        final age = _currentAge;
        final theoreticalYears = (age - 21).clamp(0, 44);
        return _buildMindBlowingInsight(
          icon: Icons.history_edu,
          title: 'ECHELLE COMPLETE = 44 ANS',
          text: 'A $age ans, tu devrais avoir $theoreticalYears annees de cotisation. '
              'Rente max individuelle : CHF 30'240/an (couple: CHF 45'360). '
              'Chaque annee manquante = -2.3% de rente A VIE. '
              'Tu peux racheter les 5 dernieres annees manquantes (LAVS art. 16).',
          color: MintColors.warning,
        );

      case 'q_avs_arrival_year':
        if (_answers['q_avs_arrival_year'] != null && _answers['q_birth_year'] != null) {
          final arrivalYear = (_answers['q_avs_arrival_year'] as num).toInt();
          final birthYear = (_answers['q_birth_year'] as num).toInt();
          final startAge = 21;
          final gapYears = (arrivalYear - (birthYear + startAge)).clamp(0, 44);
          final renteLoss = AvsCalculator.reductionPercentageFromGap(gapYears);
          final monthlyLoss = AvsCalculator.monthlyLossFromGap(gapYears);
          return _buildMindBlowingInsight(
            icon: Icons.flight_land,
            title: 'TES LACUNES AVS',
            text: 'Arrive en Suisse en $arrivalYear = $gapYears annees de lacune AVS. '
                'Impact : -${renteLoss.toStringAsFixed(1)}% de rente = '
                'CHF ${monthlyLoss.toStringAsFixed(0)}/mois en moins a vie. '
                'Racheter 5 ans = recuperer ~11.5% de rente (LAVS art. 16).',
            color: Colors.red.shade700,
          );
        }

      case 'q_avs_years_abroad':
        if (_answers['q_avs_years_abroad'] != null) {
          final yearsAbroad = (_answers['q_avs_years_abroad'] as num).toInt();
          final renteLoss = (yearsAbroad * 2.3).clamp(0, 100);
          return _buildMindBlowingInsight(
            icon: Icons.public,
            title: 'IMPACT ETRANGER',
            text: '$yearsAbroad ans hors Suisse = -${renteLoss.toStringAsFixed(1)}% de rente AVS. '
                'Bonne nouvelle : les cotisations de jeunesse (18-20 ans) peuvent combler '
                'jusqu'a 3 annees (RAVS art. 52b). '
                'Les accords bilateraux EU/AELE comptent aussi.',
            color: Colors.indigo,
          );
        }

      case 'q_spouse_avs_lacunes_status':
        return _buildMindBlowingInsight(
          icon: Icons.people_outline,
          title: 'RENTE DE COUPLE',
          text: 'Plafond couple = 150% de la rente max individuelle (LAVS art. 35). '
              'Si un conjoint a des lacunes, la rente du couple entier baisse. '
              'Il est parfois plus rentable de racheter les lacunes du conjoint que les siennes.',
          color: Colors.purple.shade700,
        );

      case 'q_spouse_avs_arrival_year':
        if (_answers['q_spouse_avs_arrival_year'] != null && _answers['q_birth_year'] != null) {
          final spouseArrival = (_answers['q_spouse_avs_arrival_year'] as num).toInt();
          // Use partner birth year if available, else estimate
          final partnerBirth = (_answers['q_partner_birth_year'] as num?)?.toInt() ??
              ((_answers['q_birth_year'] as num).toInt());
          final gapYears = (spouseArrival - (partnerBirth + 21)).clamp(0, 44);
          return _buildMindBlowingInsight(
            icon: Icons.flight_land,
            title: 'LACUNES CONJOINT',
            text: 'Ton/ta conjoint·e : $gapYears annees de lacune AVS estimees. '
                'Cela affecte directement la rente de couple (plafond 150%). '
                'Le rachat est possible pour les 5 dernieres annees manquantes.',
            color: Colors.orange.shade800,
          );
        }

      // ── PATRIMOINE ──

      case 'q_has_investments':
        return _buildMindBlowingInsight(
          icon: Icons.show_chart,
          title: 'INFLATION = IMPOT INVISIBLE',
          text: 'CHF 100'000 sur un compte epargne a 0.5% perdent 2-3% de pouvoir '
              'd'achat par an. Dans 20 ans, ils ne "valent" plus que ~CHF 65'000. '
              'Investir (diversifie, long terme) est le seul remede contre l'erosion.',
          color: const Color(0xFF1565C0),
        );

      case 'q_has_life_insurance':
        final civil = _answers['q_civil_status'] as String?;
        if (civil == 'cohabiting') {
          return _buildMindBlowingInsight(
            icon: Icons.warning_amber,
            title: 'PROTECTION URGENTE',
            text: 'En concubinage, ton/ta partenaire n'a AUCUN droit : '
                'pas de rente survivant AVS (LAVS art. 23), pas de LPP automatique, '
                'pas de droits successoraux. Une assurance décès croisée + '
                'testament + clause bénéficiaire LPP/3a sont le MINIMUM VITAL.',
            color: Colors.red.shade700,
          );
        }
        return _buildMindBlowingInsight(
          icon: Icons.shield_outlined,
          title: 'PROTECTION DES PROCHES',
          text: 'L'assurance décès couvre le risque que tes proches ne pourraient pas '
              'absorber financièrement. Coût typique : CHF 15-40/mois pour CHF 200'000 de capital. '
              'En Suisse, la rente de survivant AVS est plafonnée à CHF 24'192/an (80% de 30'240, LAVS art. 23).',
          color: Colors.indigo,
        );

      case 'q_real_estate_project':
        return _buildMindBlowingInsight(
          icon: Icons.house_outlined,
          title: 'REGLE DES 20%',
          text: 'Fonds propres min 20% du prix (max 10% du 2e pilier). '
              'Pour un bien a CHF 800'000 : CHF 160'000 minimum dont CHF 80'000 en cash. '
              'Attention : rachat LPP + achat immo dans les 3 ans = incompatible legalement (LPP art. 79b).',
          color: Colors.brown.shade700,
        );

      case 'q_property_value':
        if (_answers['q_property_value'] != null) {
          final value = (_answers['q_property_value'] as num).toDouble();
          final fortuneEstimate = value * 0.7; // Valeur fiscale ~70%
          return _buildMindBlowingInsight(
            icon: Icons.home_work,
            title: 'FORTUNE IMMOBILIERE',
            text: 'Bien estimé à CHF ${value.round()}. '
                'Valeur fiscale probable : ~CHF ${fortuneEstimate.round()} (60-80% de la valeur vénale). '
                'Cette fortune est imposée chaque année par le canton (LHID art. 14). '
                'Les intérêts hypothécaires sont déductibles — c'est un levier fiscal majeur.',
            color: Colors.brown.shade700,
          );
        }

      case 'q_mortgage_balance':
        if (_answers['q_mortgage_balance'] != null && _answers['q_property_value'] != null) {
          final mortgage = (_answers['q_mortgage_balance'] as num).toDouble();
          final value = (_answers['q_property_value'] as num).toDouble();
          final ltv = value > 0 ? (mortgage / value * 100) : 0;
          final mustAmortize = ltv > 67;
          return _buildMindBlowingInsight(
            icon: Icons.account_balance_wallet,
            title: 'TON RATIO HYPOTHECAIRE',
            text: 'Hypothèque CHF ${mortgage.round()} / Bien CHF ${value.round()} = '
                '${ltv.toStringAsFixed(1)}% LTV (Loan-to-Value). '
                '${mustAmortize ? "Au-dessus de 67% — amortissement obligatoire en 15 ans (directive ASB). " : "En dessous de 67% — pas d'amortissement obligatoire. "}'
                'Les intérêts (~CHF ${(mortgage * 0.015 / 12).round()}/mois à 1.5%) sont déductibles fiscalement.',
            color: ltv > 80 ? Colors.red.shade700 : Colors.green.shade700,
          );
        }

      case 'q_main_goal':
        if (_answers['q_birth_year'] != null) {
          final age = _currentAge;
          final yearsToRetirement = (65 - age).clamp(0, 50);
          return _buildMindBlowingInsight(
            icon: Icons.flag_outlined,
            title: 'TON POTENTIEL',
            text: 'A $age ans avec $yearsToRetirement ans devant toi, '
                'CHF 500/mois investis a 5% = CHF ${(500 * 12 * yearsToRetirement * _compoundFactor(yearsToRetirement) / _compoundFactor(yearsToRetirement)).toStringAsFixed(0)} '
                'de capital a 65 ans. Chaque annee de retard coute cher grace aux interets composes.',
            color: MintColors.primary,
          );
        }

      case 'q_risk_tolerance':
        return _buildMindBlowingInsight(
          icon: Icons.analytics_outlined,
          title: 'RENDEMENTS HISTORIQUES',
          text: 'Sur 20 ans (SPI, MSCI World) : '
              'Prudent (obligations) ~2%/an. '
              'Equilibre (mixte) ~4-5%/an. '
              'Dynamique (actions) ~6-8%/an. '
              'Aucune perte sur 15+ ans historiquement — le temps est le meilleur allie.',
          color: Colors.teal.shade700,
        );
    }

    return const SizedBox.shrink();
  }

  /// Compound factor for N years at 5%
  double _compoundFactor(int years) {
    double factor = 1.0;
    for (int i = 0; i < years; i++) {
      factor *= 1.05;
    }
    return factor;
  }

  int get _currentAge {
    final birthYear = _answers['q_birth_year'];
    if (birthYear == null) return 35;
    return DateTime.now().year - (birthYear as num).toInt();
  }

  int _parseChildrenCount() {
    final raw = _answers['q_children'];
    return switch (raw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
  }

  /// 3a tax savings insight
  Widget _build3aInsight() {
    final income = (_answers['q_net_income_period_chf'] as num).toDouble();
    final canton = _answers['q_canton'] as String;
    final status = _answers['q_civil_status'] as String? ?? 'single';
    final children = _parseChildrenCount();
    final age = _currentAge;

    final taxWithout3a = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: income,
      cantonCode: canton,
      civilStatus: status,
      childrenCount: children,
      age: age,
    );
    final taxWith3a = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: income - (7258 / 12),
      cantonCode: canton,
      civilStatus: status,
      childrenCount: children,
      age: age,
    );
    final savings = (taxWithout3a - taxWith3a).clamp(0.0, double.infinity);
    final yearsToRetirement = (65 - age).clamp(0, 50);
    final lifetimeSavings = savings * yearsToRetirement;

    return _buildMindBlowingInsight(
      icon: Icons.savings,
      title: 'LE 3A = TON ARME FISCALE',
      text: 'Max 3a : 7'258 CHF/an = economie de CHF ${savings.toStringAsFixed(0)}/an '
          'dans le canton $canton. Sur $yearsToRetirement ans = CHF ${lifetimeSavings.toStringAsFixed(0)} '
          'd'impots economises au total. C'est le meilleur outil fiscal en Suisse.',
      color: Colors.green.shade700,
    );
  }

  /// Fiscal insight: Tax Freedom Date — shown once on income question
  Widget _buildFiscalInsight() {
    final income = (_answers['q_net_income_period_chf'] as num).toDouble();
    final canton = _answers['q_canton'] as String;
    final age = _currentAge;
    final status = _answers['q_civil_status'] as String? ?? 'single';
    final children = _parseChildrenCount();

    final annualTax = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: income,
      cantonCode: canton,
      civilStatus: status,
      childrenCount: children,
      age: age,
    );
    final monthsForTax = FiscalIntelligenceService.calculateMonthsWorkedForTax(
      annualTax: annualTax,
      netAnnualIncome: income * 12,
    );
    final dayOfYear = (monthsForTax * 30).round();
    final taxFreedomDate =
        DateTime(DateTime.now().year, 1, 1).add(Duration(days: dayOfYear));
    final formattedDate = "${taxFreedomDate.day}.${taxFreedomDate.month}";

    return _buildMindBlowingInsight(
      icon: Icons.auto_awesome,
      title: 'DATE DE LIBERATION FISCALE',
      text: 'Tu travailles jusqu'au $formattedDate rien que pour payer tes impots '
          '(${monthsForTax.toStringAsFixed(1)} mois sur 12). '
          'Chaque franc d'optimisation fiscale = du temps de vie recupere.',
      color: MintColors.primary,
    );
  }

  /// Neighbor comparison insight — shown once on savings question
  // ignore: unused_element
  Widget _buildNeighborInsight() {
    final income = (_answers['q_net_income_period_chf'] as num).toDouble();
    final canton = _answers['q_canton'] as String;
    final age = _currentAge;
    final status = _answers['q_civil_status'] as String? ?? 'single';
    final children = _parseChildrenCount();

    final neighborComp = FiscalIntelligenceService.findBetterNeighbor(
      currentCanton: canton,
      netMonthlyIncome: income,
      civilStatus: status,
      age: age,
      childrenCount: children,
    );

    if (neighborComp == null) {
      return _buildMindBlowingInsight(
        icon: Icons.emoji_events,
        title: 'BIEN PLACE !',
        text: 'Ton canton ($canton) est deja parmi les plus competitifs fiscalement. '
            'Concentre-toi sur les deductions (3a, LPP, frais professionnels) '
            'plutot que sur un demenagement.',
        color: Colors.green.shade700,
      );
    }

    final savingsAmount = (neighborComp['savings'] as double).toStringAsFixed(0);
    return _buildMindBlowingInsight(
      icon: Icons.compare_arrows,
      title: 'OPTIMISATION CANTONALE',
      text: 'A ${neighborComp['canton']}, tu economiserais CHF $savingsAmount/an d'impots. '
          'Sur 10 ans = CHF ${((neighborComp['savings'] as double) * 10).toStringAsFixed(0)}. '
          'Bien sur, demenager a un cout — mais le chiffre merite reflexion.',
      color: Colors.indigo,
    );
  }

  /// Mind-blowing insight card — premium design with title header
  Widget _buildMindBlowingInsight({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _announceSectionChange(String nextSection) {
    final progressLabel = switch (nextSection) {
      'Budget & Protection' => 'Partie 2/4',
      'Prévoyance' => 'Partie 3/4',
      'Patrimoine' => 'Derniere partie',
      _ => 'Section suivante',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text('$progressLabel • $nextSection'),
        ),
      );
    });
  }

  String _getSectionForIndex(int index) {
    if (index < 8) return 'Profil';
    if (index < 17) return 'Budget & Protection';
    if (index < 29) return 'Prévoyance';
    return 'Patrimoine';
  }
}
