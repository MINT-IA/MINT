import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/widgets/wizard_question_widget.dart';
import 'package:mint_mobile/services/fiscal_intelligence_service.dart';
import 'package:mint_mobile/services/wizard_conditions_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/circle_transition_widget.dart';

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

  void _goBack() {
    if (_questionHistory.isNotEmpty) {
      setState(() {
        // Revenir à la dernière question posée
        final lastQuestionId = _questionHistory.removeLast();

        // Si on est actuellement sur une question, on veut revenir à la PRÉCÉDENTE
        // Donc on doit d'abord vérifier si on doit dépiler celle d'avant
        final _ = _questions[_currentQuestionIndex].id;

        // Si l'historique contient la question actuelle (ce qui arrive quand on avance),
        // on l'enlève pour revenir à la précédente réelle.
        // MAIS attention : ici _questionHistory contient les questions DÉJÀ RÉPOLUES.
        // Donc logiquement lastQuestionId EST la question précédente.

        // Cas spécial : si on vient de répondre et qu'on fait back immédiatement,
        // l'état courant est la NOUVELLE question.
        // Donc on veut revenir à lastQuestionId.

        final lastIndex = _questions.indexWhere((q) => q.id == lastQuestionId);
        if (lastIndex != -1) {
          _currentQuestionIndex = lastIndex;
          // On retire la réponse associée pour permettre de changer
          // (Optionnel, mais plus propre de ne pas garder une réponse "future")
          // _answers.remove(currentId);  <-- On garde la réponse pour pré-remplir
        }
      });
    } else if (_currentQuestionIndex > 0) {
      // Fallback au cas où histo vide mais index > 0 (ex: init)
      setState(() {
        // On cherche la question précédente valide à l'envers
        int prevIndex = _currentQuestionIndex - 1;
        while (prevIndex >= 0) {
          final q = _questions[prevIndex];
          if (WizardConditionsService.shouldAskQuestion(q.id, _answers)) {
            _currentQuestionIndex = prevIndex;
            return;
          }
          prevIndex--;
        }
        // Si aucune trouvée
        Navigator.pop(context);
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _showReport() {
    ReportPersistenceService.setCompleted(true);
    context.go('/report', extra: _answers);
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];

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
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
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
            margin: const EdgeInsets.only(right: 16),
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
                    WizardQuestionWidget(
                      key: ValueKey(currentQuestion.id),
                      question: currentQuestion,
                      onAnswer: _handleAnswer,
                      currentAnswer: _answers[currentQuestion.id],
                      answers: _answers,
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
