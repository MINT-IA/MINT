import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/interactive_simulations.dart';
import 'package:mint_mobile/services/educational_insert_service.dart';
import 'package:mint_mobile/services/haptic_feedback_service.dart';

class WizardQuestionWidget extends StatefulWidget {
  final WizardQuestion question;
  final Function(dynamic) onAnswer;
  final dynamic currentAnswer;
  final Map<String, dynamic>
      answers; // Nouveau: contexte des réponses précédentes

  const WizardQuestionWidget({
    super.key,
    required this.question,
    required this.onAnswer,
    this.currentAnswer,
    this.answers = const {},
  });

  @override
  State<WizardQuestionWidget> createState() => _WizardQuestionWidgetState();
}

class _WizardQuestionWidgetState extends State<WizardQuestionWidget> {
  bool _showExplanation = false;
  bool _showSimulation = false;
  bool _showEducationalInsert = true; // Auto-ouvert pour "just-in-time"

  @override
  Widget build(BuildContext context) {
    // Vérifier si un insert didactique existe pour cette question
    final hasEducationalInsert =
        EducationalInsertService.hasInsert(widget.question.id);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.question.title,
                  style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              if (widget.question.explanation != null)
                IconButton(
                  icon: Icon(
                    _showExplanation ? Icons.close : Icons.help_outline,
                    color: MintColors.primary,
                  ),
                  onPressed: () =>
                      setState(() => _showExplanation = !_showExplanation),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Subtitle
          if (widget.question.subtitle != null)
            Text(
              widget.question.subtitle!,
              style: const TextStyle(
                  fontSize: 16, color: MintColors.textSecondary),
            ),

          const SizedBox(height: 24),

          // Explication didactique (si demandée)
          if (_showExplanation && widget.question.explanation != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MintColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: MintColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Explication',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MintColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.question.explanation!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // === INSERT DIDACTIQUE (Just-in-time, OECD/INFE) ===
          if (hasEducationalInsert && _showEducationalInsert) ...[
            EducationalInsertService.getInsertWidget(
                  questionId: widget.question.id,
                  answers: widget.answers,
                  onAnswer: widget.onAnswer, // Pass the callback!
                  onLearnMore: () {
                    // TODO: Ouvrir modal "En savoir plus"
                    final title = EducationalInsertService.getLearnMoreTitle(
                        widget.question.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('En savoir plus: $title')),
                    );
                  },
                ) ??
                const SizedBox.shrink(),
            const SizedBox(height: 16),
            // Bouton réduire
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showEducationalInsert = false),
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                label: const Text('Réduire', style: TextStyle(fontSize: 12)),
                style:
                    TextButton.styleFrom(foregroundColor: MintColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Bouton "Voir l'explication" (si insert masqué)
          if (hasEducationalInsert && !_showEducationalInsert) ...[
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showEducationalInsert = true),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Comprendre ce sujet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.primary,
                  side: const BorderSide(color: MintColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Simulation interactive legacy (si applicable et pas d'insert)
          if (!hasEducationalInsert && _hasSimulation && _showSimulation) ...[
            _buildSimulation(),
            const SizedBox(height: 24),
          ],

          // Bouton "Voir simulation" legacy
          if (!hasEducationalInsert && _hasSimulation && !_showSimulation) ...[
            OutlinedButton.icon(
              onPressed: () => setState(() => _showSimulation = true),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Voir simulation interactive'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.primary,
                side: const BorderSide(color: MintColors.primary),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Input selon type
          // HACK: Pour q_has_pension_fund, l'insert EST l'input. On masque le standard si l'insert est visible.
          if (!(widget.question.id == 'q_has_pension_fund' &&
              _showEducationalInsert))
            _buildInput(),

          const SizedBox(height: 24),

          // Bouton "Passer" (si allowSkip)
          if (widget.question.allowSkip)
            Center(
              child: TextButton(
                onPressed: () => widget.onAnswer(null),
                child: Text(widget.question.skipLabel),
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasSimulation {
    return widget.question.id == 'q_has_3a' ||
        widget.question.id == 'q_peak_lpp_buyback';
  }

  Widget _buildSimulation() {
    if (widget.question.id == 'q_has_3a') {
      return const Interactive3aSimulation(
        initialMonthlyContribution: 600,
        initialYears: 30,
        isEmployee: true, // TODO: Get from answers
      );
    }

    if (widget.question.id == 'q_peak_lpp_buyback') {
      return const InteractiveLppBuybackSimulation(
        initialBuybackAmount: 15000,
        initialMarginalTaxRate: 30,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInput() {
    switch (widget.question.type) {
      case QuestionType.choice:
        return _buildChoiceInput();

      case QuestionType.multiChoice:
        return _buildMultiChoiceInput();

      case QuestionType.input:
      case QuestionType.text:
      case QuestionType.number:
        return _buildTextInput();

      case QuestionType.canton:
        return _buildCantonGrid();

      case QuestionType.date:
        return _buildDateInput();

      case QuestionType.info:
      case QuestionType.consent:
        return _buildChoiceInput();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChoiceInput() {
    return Column(
      children: widget.question.options!.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildOptionTile(option),
        );
      }).toList(),
    );
  }

  Widget _buildOptionTile(QuestionOption option) {
    final isSelected = widget.currentAnswer == option.value;

    return InkWell(
      onTap: () {
        HapticFeedbackService.light();
        widget.onAnswer(option.value);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? MintColors.accentPastel : Colors.white,
        ),
        child: Row(
          children: [
            if (option.icon != null)
              Icon(
                _getIconData(option.icon!),
                color:
                    isSelected ? MintColors.primary : MintColors.textSecondary,
              ),
            if (option.icon != null) const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.textPrimary,
                    ),
                  ),
                  if (option.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected ? MintColors.primary : MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiChoiceInput() {
    final selectedValues =
        (widget.currentAnswer as List?)?.cast<String>() ?? [];

    return Column(
      children: widget.question.options!.map((option) {
        final isSelected = selectedValues.contains(option.value);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedbackService.selection();
                final newSelection = List<String>.from(selectedValues);
                if (isSelected) {
                  newSelection.remove(option.value);
                } else {
                  newSelection.add(option.value);
                }
                widget.onAnswer(newSelection);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MintColors.primary.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? MintColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? MintColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? MintColors.primary
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Label
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? MintColors.primary
                              : MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInput() {
    final controller = TextEditingController(
      text: widget.currentAnswer?.toString() ?? '',
    );

    final isNumberInput = widget.question.type == QuestionType.number;

    return Column(
      children: [
        TextField(
          controller: controller,
          keyboardType:
              isNumberInput ? TextInputType.number : TextInputType.text,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.question.hint,
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (val) {
            if (isNumberInput) {
              final parsed = int.tryParse(val);
              if (parsed != null) widget.onAnswer(parsed);
            } else {
              if (val.isNotEmpty) widget.onAnswer(val);
            }
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (isNumberInput) {
                final parsed = int.tryParse(controller.text);
                if (parsed != null) widget.onAnswer(parsed);
              } else {
                if (controller.text.isNotEmpty)
                  widget.onAnswer(controller.text);
              }
            },
            child: const Text('Suivant'),
          ),
        ),
      ],
    );
  }

  Widget _buildCantonGrid() {
    final cantons = [
      'AG',
      'AI',
      'AR',
      'BE',
      'BL',
      'BS',
      'FR',
      'GE',
      'GL',
      'GR',
      'JU',
      'LU',
      'NE',
      'NW',
      'OW',
      'SG',
      'SH',
      'SO',
      'SZ',
      'TG',
      'TI',
      'UR',
      'VD',
      'VS',
      'ZG',
      'ZH',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: cantons.length,
      itemBuilder: (context, index) {
        final canton = cantons[index];
        final isSelected = widget.currentAnswer == canton;

        return InkWell(
          onTap: () {
            HapticFeedbackService.light();
            widget.onAnswer(canton);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? MintColors.primary : MintColors.border,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? MintColors.accentPastel : Colors.white,
            ),
            alignment: Alignment.center,
            child: Text(
              canton,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? MintColors.primary : MintColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateInput() {
    // TODO: Implement date picker
    return const Text('Date picker not yet implemented');
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'person': Icons.person,
      'people': Icons.people,
      'family_restroom': Icons.family_restroom,
      'work': Icons.work,
      'business_center': Icons.business_center,
      'school': Icons.school,
      'elderly': Icons.elderly,
      'home': Icons.home,
      'domain': Icons.domain,
      'construction': Icons.construction,
      'credit_card': Icons.credit_card,
      'check_circle': Icons.check_circle,
      'account_balance': Icons.account_balance,
      'shield': Icons.shield,
      'savings': Icons.savings,
      'warning': Icons.warning_amber,
      'trending_up': Icons.trending_up,
      'help': Icons.help_outline,
      'close': Icons.close,
      'public': Icons.public,
      'block': Icons.block,
      'directions_car': Icons.directions_car,
      'child_care': Icons.child_care,
    };

    return iconMap[iconName] ?? Icons.help_outline;
  }
}
