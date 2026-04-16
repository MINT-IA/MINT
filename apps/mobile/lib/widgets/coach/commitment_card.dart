import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  COMMITMENT CARD — Phase 14 / CMIT-01
//
//  Editable WHEN / WHERE / IF-THEN card rendered inline in coach
//  chat when the LLM calls `show_commitment_card`.
//
//  User can edit pre-filled fields, then:
//   - Accept → onAccept fires with edited values
//   - Swipe to dismiss → onDismiss fires (no persistence)
//
//  Sources:
//    - Gollwitzer (1999) — implementation intentions
//    - CMIT-01: editable WHEN/WHERE/IF-THEN card per locked decision
// ────────────────────────────────────────────────────────────

class CommitmentCard extends StatefulWidget {
  /// Pre-filled WHEN text from LLM proposal.
  final String whenText;

  /// Pre-filled WHERE/HOW text from LLM proposal.
  final String whereText;

  /// Pre-filled IF...THEN text from LLM proposal.
  final String ifThenText;

  /// Called when user taps Accept with (whenText, whereText, ifThenText).
  final void Function(String whenText, String whereText, String ifThenText)?
      onAccept;

  /// Called when user swipes to dismiss.
  final VoidCallback? onDismiss;

  const CommitmentCard({
    super.key,
    required this.whenText,
    required this.whereText,
    required this.ifThenText,
    this.onAccept,
    this.onDismiss,
  });

  @override
  State<CommitmentCard> createState() => _CommitmentCardState();
}

class _CommitmentCardState extends State<CommitmentCard> {
  late final TextEditingController _whenController;
  late final TextEditingController _whereController;
  late final TextEditingController _ifThenController;

  @override
  void initState() {
    super.initState();
    _whenController = TextEditingController(text: widget.whenText);
    _whereController = TextEditingController(text: widget.whereText);
    _ifThenController = TextEditingController(text: widget.ifThenText);
  }

  @override
  void dispose() {
    _whenController.dispose();
    _whereController.dispose();
    _ifThenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => widget.onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.close,
          color: MintColors.textMuted,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: MintColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.commitmentCardTitle,
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // WHEN field
            _buildField(
              label: l10n.commitmentWhen,
              controller: _whenController,
            ),
            const SizedBox(height: 12),

            // WHERE/HOW field
            _buildField(
              label: l10n.commitmentWhere,
              controller: _whereController,
            ),
            const SizedBox(height: 12),

            // IF...THEN field
            _buildField(
              label: l10n.commitmentIfThen,
              controller: _ifThenController,
            ),
            const SizedBox(height: 16),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.onAccept?.call(
                    _whenController.text.trim(),
                    _whereController.text.trim(),
                    _ifThenController.text.trim(),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.commitmentAccept,
                  style: MintTextStyles.labelMedium(
                    color: MintColors.white,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MintTextStyles.labelSmall(
            color: MintColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: 2,
          minLines: 1,
          style: MintTextStyles.bodySmall(
            color: MintColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: MintColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: MintColors.border,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: MintColors.border,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: MintColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
