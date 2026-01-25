import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/wizard_service.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/models/clarity_state.dart';
import 'package:mint_mobile/widgets/wizard_question_widget.dart';
import 'package:mint_mobile/widgets/report_preview_widget.dart';
import 'package:mint_mobile/screens/advisor/advisor_report_screen.dart';

class AdvisorSessionWizardScreen extends StatefulWidget {
  const AdvisorSessionWizardScreen({super.key});

  @override
  State<AdvisorSessionWizardScreen> createState() =>
      _AdvisorSessionWizardScreenState();
}

class _AdvisorSessionWizardScreenState
    extends State<AdvisorSessionWizardScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, dynamic> _completedActions = {};
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;
  bool _showingPreview = false;

  late List<WizardQuestion> _questions;
  late ClarityState _clarityState;

  @override
  void initState() {
    super.initState();
    _questions = WizardService.getQuestionsForUser(null, _answers);
    _clarityState = ClarityState.calculate(_answers, _completedActions);
  }

  void _handleAnswer(dynamic answer) {
    setState(() {
      final currentQuestion = _questions[_currentQuestionIndex];

      // Valider la réponse
      final error = WizardService.validateAnswer(currentQuestion, answer);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      // Sauvegarder la réponse
      _answers[currentQuestion.id] = answer;

      // Recalculer questions filtrées
      _questions = WizardService.getQuestionsForUser(null, _answers);

      // Recalculer clarity state
      _clarityState = ClarityState.calculate(_answers, _completedActions);

      // Note: On ne déclenche plus l'aperçu automatiquement pour éviter les aller-retours incessants.
      // L'utilisateur peut y accéder via l'icône dans l'AppBar ou à la fin.

      // Passer à la question suivante
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Toutes les questions répondues
        _showFinalReport();
      }
    });
  }

  void _handlePrevious() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _viewPartialReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvisorReportScreen(answers: _answers),
      ),
    );
  }

  void _showReportPreview() {
    setState(() {
      _showingPreview = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: ReportPreviewWidget(
            state: _clarityState,
            onComplete: () {
              Navigator.pop(context);
              if (_clarityState.precisionIndex >= 90) {
                _generatePDF();
              }
            },
            onViewPartialReport: () {
              Navigator.pop(context);
              _viewPartialReport();
            },
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _showingPreview = false;
      });
    });
  }

  void _showFinalReport() {
    // Toujours afficher l'aperçu à la fin pour laisser le choix (Compléter ou Voir)
    _showReportPreview();
  }

  Future<void> _generatePDF() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Créer la session wizard
      final response = await ApiService.post('/sessions/wizard', {
        'answers': _answers,
        'completed_actions': _completedActions,
      });

      final sessionId = response['session_id'];

      // Générer le PDF
      // TODO: Implémenter génération PDF

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan Mint généré avec succès !'),
            backgroundColor: Colors.green,
          ),
        );

        // Rediriger vers le rapport
        context.go('/advisor/sessions/$sessionId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestionIndex >= _questions.length) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Plan Mint'),
        ),
        body: ReportPreviewWidget(
          state: _clarityState,
          onComplete: _generatePDF,
          onViewPartialReport: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdvisorReportScreen(answers: _answers),
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentQuestionIndex > 0
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: MintColors.textPrimary),
                onPressed: _handlePrevious,
              )
            : null,
        title: Text(
          'Plan Mint',
          style: GoogleFonts.montserrat(
            color: MintColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Seuil abaissé à 40% pour permettre une sortie rapide
          if (_clarityState.precisionIndex >= 40)
            IconButton(
              icon: const Icon(Icons.preview, color: MintColors.primary),
              onPressed: _showReportPreview,
              tooltip: 'Aperçu du rapport',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header de progression
          ClarityProgressHeader(state: _clarityState),

          // Question actuelle
          Expanded(
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : WizardQuestionWidget(
                    question: currentQuestion,
                    currentAnswer: _answers[currentQuestion.id],
                    onAnswer: _handleAnswer,
                    answers: _answers, // Contexte pour les inserts didactiques
                  ),
          ),

          // Footer avec indicateur de progression
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
                Row(
                  children: List.generate(
                    math.min(_questions.length, 10),
                    (index) {
                      final isCompleted = index < _currentQuestionIndex;
                      final isCurrent = index == _currentQuestionIndex;

                      return Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? MintColors.primary
                              : isCurrent
                                  ? MintColors.primary.withOpacity(0.5)
                                  : MintColors.border,
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
