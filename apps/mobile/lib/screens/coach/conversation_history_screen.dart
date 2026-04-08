/// Conversation history screen — Sprint S51.
///
/// Lists all past coach conversations with search, delete, and resume.
/// Route: /coach/history
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/conversation_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final ConversationStore _store = ConversationStore();
  List<ConversationMeta>? _conversations;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _store.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = S.of(context)!.conversationHistoryError;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(String id) async {
    await _store.deleteConversation(id);
    await _loadConversations();
  }

  void _openConversation(String conversationId) {
    // Navigate to chat screen with the conversation ID as a query parameter.
    // The chat screen will load the conversation from the store.
    context.push('/coach/chat?conversationId=$conversationId');
  }

  void _startNewConversation() {
    context.push('/coach/chat');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              l10n.conversationHistoryTitle,
              style: MintTextStyles.titleMedium(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),

          // ── Body ──
          if (_isLoading)
            const SliverFillRemaining(
              child: MintLoadingSkeleton(),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorState(
                message: _error!,
                onRetry: _loadConversations,
              ),
            )
          else if (_conversations == null || _conversations!.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onNewConversation: _startNewConversation),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(MintSpacing.md, MintSpacing.md, MintSpacing.md, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conversation = _conversations![index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ConversationTile(
                        conversation: conversation,
                        onTap: () => _openConversation(conversation.id),
                        onDelete: () => _deleteConversation(conversation.id),
                      ),
                    );
                  },
                  childCount: _conversations!.length,
                ),
              ),
            ),
        ],
      ))),

      // ── FAB: New conversation ──
      floatingActionButton: (!_isLoading && _error == null)
          ? FloatingActionButton.extended(
              onPressed: _startNewConversation,
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.conversationNew,
                style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  _EmptyState — no conversations yet
// ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewConversation;

  const _EmptyState({required this.onNewConversation});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MintEntrance(child: Icon(
              Icons.chat_outlined,
              size: 64,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            )),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
              l10n.conversationEmptyTitle,
              style: MintTextStyles.titleMedium(),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: MintSpacing.sm),
            MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
              l10n.conversationEmptySubtitle,
              style: MintTextStyles.bodyMedium(),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(delay: const Duration(milliseconds: 300), child: Semantics(
              button: true,
              label: l10n.conversationStartFirst,
              child: FilledButton.icon(
                onPressed: onNewConversation,
                icon: const Icon(Icons.add),
                label: Text(
                  l10n.conversationStartFirst,
                style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            )),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  _ErrorState — loading error
// ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: MintColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              l10n.conversationErrorTitle,
              style: MintTextStyles.titleMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              message,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MintSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                l10n.conversationRetry,
                style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.primary,
                side: const BorderSide(color: MintColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
