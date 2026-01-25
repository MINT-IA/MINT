import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/widgets/wizard_question_widget.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
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

  // Sections pour la barre de progression
  final Map<String, int> _sectionRanges = {
    'Profil': 6, // Questions 0-5
    'Budget & Protection': 6, // Questions 6-11
    'Prévoyance': 6, // Questions 12-17
    'Patrimoine': 4, // Questions 18-21
  };

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

  int get _sectionProgress {
    final sectionStart = _getSectionStartIndex(_currentSection);
    final sectionSize = _sectionRanges[_currentSection]!;
    final positionInSection = _currentQuestionIndex - sectionStart;
    return ((positionInSection / sectionSize) * 100).round();
  }

  int get _overallProgress {
    return ((_currentQuestionIndex / _questions.length) * 100).round();
  }

  int _getSectionStartIndex(String section) {
    switch (section) {
      case 'Profil':
        return 0;
      case 'Budget & Protection':
        return 6;
      case 'Prévoyance':
        return 12;
      case 'Patrimoine':
        return 18;
      default:
        return 0;
    }
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
        final currentId = _questions[_currentQuestionIndex].id;

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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialReportScreenV2(
          wizardAnswers: _answers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        backgroundColor: MintColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_overallProgress%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: _overallProgress / 100,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Section badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSectionColor().withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: _getSectionColor().withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSectionColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getSectionIcon(), color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _currentSection,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MintColors.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0), // Orange very light
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_today,
                        color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Miroir Fiscal",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: MintColors.textPrimary,
                                height: 1.4),
                            children: [
                              const TextSpan(text: "Tu travailles jusqu'au "),
                              TextSpan(
                                  text: formattedDate,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange)),
                              TextSpan(
                                  text:
                                      " uniquement pour payer tes impôts (${monthsForTax.toStringAsFixed(1)} mois)."),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF81C784).withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_outlined,
                          color: Color(0xFF2E7D32), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Le Voisin",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: MintColors.textPrimary,
                                  height: 1.4),
                              children: [
                                const TextSpan(text: "En habitant à "),
                                TextSpan(
                                    text: "${neighborComp['canton']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32))),
                                const TextSpan(text: ", tu économiserais "),
                                TextSpan(
                                    text:
                                        "CHF ${(neighborComp['savings'] as double).toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32))),
                                const TextSpan(text: " par an."),
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

  Color _getSectionColor() {
    switch (_currentSection) {
      case 'Profil':
        return Colors.purple;
      case 'Budget & Protection':
        return Colors.green;
      case 'Prévoyance':
        return Colors.blue;
      case 'Patrimoine':
        return Colors.orange;
      default:
        return MintColors.primary;
    }
  }

  IconData _getSectionIcon() {
    switch (_currentSection) {
      case 'Profil':
        return Icons.person;
      case 'Budget & Protection':
        return Icons.shield;
      case 'Prévoyance':
        return Icons.savings;
      case 'Patrimoine':
        return Icons.trending_up;
      default:
        return Icons.auto_awesome;
    }
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
