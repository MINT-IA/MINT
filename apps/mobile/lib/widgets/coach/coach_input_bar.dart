import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  COACH INPUT BAR — extracted from coach_chat_screen.dart
// ────────────────────────────────────────────────────────────

/// Chat input bar with lightning menu trigger, text field, and send button.
class CoachInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onLightningMenu;

  const CoachInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isStreaming,
    required this.onSend,
    required this.onLightningMenu,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.craie,
        border: Border(
          top: BorderSide(
            color: MintColors.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Lightning menu trigger
              GestureDetector(
                onTap: isStreaming ? null : onLightningMenu,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MintColors.porcelaine,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(Icons.bolt_rounded,
                      color: isStreaming
                          ? MintColors.textMuted.withValues(alpha: 0.3)
                          : MintColors.textSecondary,
                      size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: s.coachInputHint,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    enabled: !isStreaming,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: s.coachInputHint,
                      hintStyle: MintTextStyles.bodyMedium(
                          color:
                              MintColors.textMuted.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: MintColors.porcelaine,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              Semantics(
                button: true,
                label: s.coachSendButton,
                child: GestureDetector(
                  onTap: isStreaming ? null : onSend,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isStreaming
                          ? MintColors.textMuted.withValues(alpha: 0.15)
                          : MintColors.primary,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: MintColors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
