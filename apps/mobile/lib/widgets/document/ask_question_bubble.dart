// Phase 28-04 — AskQuestionBubble
//
// Hybrid mode: the backend confirmed the document type and most fields
// but needs 1-3 explicit confirmations before saving. Render confirmed
// fields as chips ("avoirLppTotal · 70'377") above the questions, and
// each question gets a free-text input the user can answer in place.
//
// On submit: callback receives a Map<questionIndex, answerText>.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class AskQuestionBubble extends StatefulWidget {
  final List<ExtractedField> confirmedFields;
  final List<String> questions;

  /// Called with answers keyed by question index. Empty map means user
  /// submitted without filling anything (caller decides whether to allow it).
  final ValueChanged<Map<int, String>> onAnswer;

  /// Optional label resolver for chip rendering (defaults to fieldName).
  final String Function(String fieldName)? labelFor;

  const AskQuestionBubble({
    super.key,
    required this.confirmedFields,
    required this.questions,
    required this.onAnswer,
    this.labelFor,
  });

  @override
  State<AskQuestionBubble> createState() => _AskQuestionBubbleState();
}

class _AskQuestionBubbleState extends State<AskQuestionBubble> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.questions.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      key: const Key('askQuestionBubble'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.documentBubbleAskTitle,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (widget.confirmedFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.confirmedFields
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MintColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(widget.labelFor ?? (n) => n)(f.fieldName)} · ${f.value}',
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          for (int i = 0; i < widget.questions.length; i++) ...[
            Text(
              widget.questions[i],
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              key: Key('askQuestionInput_$i'),
              controller: _controllers[i],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MintColors.primary),
                ),
              ),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('askQuestionSubmit'),
              style: TextButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                final answers = <int, String>{};
                for (int i = 0; i < _controllers.length; i++) {
                  final v = _controllers[i].text.trim();
                  if (v.isNotEmpty) answers[i] = v;
                }
                widget.onAnswer(answers);
              },
              child: Text(
                s.documentBubbleAskSubmit,
                style: MintTextStyles.bodySmall(color: MintColors.background)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
