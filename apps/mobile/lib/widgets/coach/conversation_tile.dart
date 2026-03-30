/// Conversation tile widget — Sprint S51.
///
/// Reusable list tile for conversation history display.
/// Shows title, last message preview, relative date, message count, and topic tags.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/theme/colors.dart';

class ConversationTile extends StatelessWidget {
  final ConversationMeta conversation;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Dismissible(
      key: ValueKey(conversation.id),
      direction:
          onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: MintColors.error,
        child: const Icon(Icons.delete_outline, color: MintColors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              l10n.conversationDeleteTitle,
            ),
            content: Text(
              l10n.conversationDeleteConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => ctx.pop(false),
                child: Text(l10n.conversationDeleteCancel),
              ),
              TextButton(
                onPressed: () => ctx.pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.error,
                ),
                child: Text(l10n.conversationDeleteAction),
              ),
            ],
          ),
        );
      },
      child: Semantics(
        label: conversation.title,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Title + date ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.title,
                      style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeDate(context, conversation.lastMessageAt),
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontSize: 12),
                  ),
                ],
              ),

              // ── Row 2: Preview ──
              if (conversation.lastMessagePreview != null) ...[
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessagePreview!,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Row 3: Tags + message count ──
              const SizedBox(height: 8),
              Row(
                children: [
                  // Tags
                  if (conversation.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: conversation.tags
                            .take(3) // Show max 3 tags
                            .map((tag) => _TagChip(label: tag))
                            .toList(),
                      ),
                    )
                  else
                    const Spacer(),

                  // Message count
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 12,
                          color: MintColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${conversation.messageCount}',
                          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  /// Format a date relative to now.
  ///
  /// Uses i18n keys for localized output:
  /// - "Il y a X min" / "Il y a X h" / "Hier" / "12 mars"
  String _formatRelativeDate(BuildContext context, DateTime date) {
    final l10n = S.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(date);

    // Bug fix: handle future dates (clock skew, timezone issues).
    if (diff.isNegative) {
      return l10n.conversationDateNow;
    }

    if (diff.inMinutes < 1) {
      return l10n.conversationDateNow;
    } else if (diff.inMinutes < 60) {
      return l10n.conversationDateMinutesAgo(diff.inMinutes.toString());
    } else if (diff.inHours < 24 && now.day == date.day) {
      return l10n.conversationDateHoursAgo(diff.inHours.toString());
    } else {
      // Dart normalizes day=0 → last day of prev month, so this is safe on the 1st.
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly == yesterday) {
        return l10n.conversationDateYesterday;
      }
      return l10n.conversationDateFormatted(
        date.day.toString(),
        _monthName(context, date.month),
      );
    }
  }

  /// Month name (short) — localized via i18n.
  String _monthName(BuildContext context, int month) {
    final l10n = S.of(context)!;
    const monthKeys = [
      '', // index 0 unused
      'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc',
    ];
    try {
      return l10n.conversationMonth(month.toString());
    } catch (_) {
      return monthKeys[month];
    }
  }
}

// ────────────────────────────────────────────────────────────
//  _TagChip — small topic tag chip
// ────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _tagColor(label).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: MintTextStyles.micro(color: _tagColor(label)).copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Map topic tags to MintColors for visual distinction.
  Color _tagColor(String tag) {
    switch (tag) {
      case 'retraite':
        return MintColors.info;
      case 'lpp':
        return MintColors.pillarLpp;
      case '3a':
        return MintColors.purple;
      case 'impôts':
        return MintColors.deepOrange;
      case 'budget':
        return MintColors.categoryAmber;
      case 'immobilier':
        return MintColors.teal;
      case 'famille':
        return MintColors.categoryMagenta;
      case 'emploi':
        return MintColors.categoryBlue;
      case 'succession':
        return MintColors.successionDark;
      case 'assurance':
        return MintColors.cyan;
      default:
        return MintColors.textSecondary;
    }
  }
}
