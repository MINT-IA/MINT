/// Conversation history screen — Sprint S51.
///
/// Lists all past coach conversations with search, delete, and resume.
/// Route: /coach/history
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/conversation_tile.dart';

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
        _error = e.toString();
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
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.conversationHistoryTitle, // TODO: add to ARB files
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MintColors.primary, MintColors.primaryLight],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.white),
              onPressed: () => context.pop(),
            ),
          ),

          // ── Body ──
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: MintColors.primary,
                ),
              ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
      ),

      // ── FAB: New conversation ──
      floatingActionButton: (!_isLoading && _error == null)
          ? FloatingActionButton.extended(
              onPressed: _startNewConversation,
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.conversationNew, // TODO: add to ARB files
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.conversationEmptyTitle, // TODO: add to ARB files
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.conversationEmptySubtitle, // TODO: add to ARB files
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.conversationStartFirst, // TODO: add to ARB files
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
            const SizedBox(height: 16),
            Text(
              l10n.conversationErrorTitle, // TODO: add to ARB files
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                l10n.conversationRetry, // TODO: add to ARB files
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
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
