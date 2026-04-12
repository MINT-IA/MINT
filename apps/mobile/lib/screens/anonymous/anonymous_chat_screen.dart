import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/auth/auth_gate_bottom_sheet.dart';

/// Data class for a single chat message in the anonymous flow.
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Full-screen anonymous chat overlay — no tabs, no shell, no drawer.
///
/// The user arrives here after tapping a felt-state pill on the intent screen.
/// They can send 3 messages. After the 3rd coach response, a conversion
/// prompt appears as a coach message, followed by the auth gate bottom sheet.
/// Dismissing the gate locks input but preserves the conversation.
class AnonymousChatScreen extends StatefulWidget {
  /// The felt-state pill text or free-text from the intent screen.
  final String? intent;

  const AnonymousChatScreen({super.key, this.intent});

  @override
  State<AnonymousChatScreen> createState() => _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends State<AnonymousChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isAuthGateLocked = false;
  bool _intentSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.intent != null && widget.intent!.isNotEmpty) {
      // Auto-send the intent as the first user message after build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_intentSent) {
          _intentSent = true;
          _sendMessage(widget.intent!);
        }
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Check if user can still send
    final canSend = await AnonymousSessionService.canSendMessage();
    if (!canSend) {
      _showAuthGate();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // Only pass intent on the first message
    final isFirstMessage = _messages.where((m) => m.isUser).length == 1;

    final response = await CoachChatApiService.sendAnonymousMessage(
      message: trimmed,
      intent: isFirstMessage ? widget.intent : null,
    );

    if (!mounted) return;

    final isError = response['error'] == true;
    final coachMessage = response['message'] as String? ?? '';
    final messagesRemaining = response['messagesRemaining'] as int? ?? -1;

    if (isError || coachMessage.isEmpty) {
      // Network/server error fallback
      final l = S.of(context)!;
      setState(() {
        _messages.add(_ChatMessage(
          text: l.anonymousChatError,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: coachMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();

    // After 3rd response (messagesRemaining == 0), show conversion prompt
    if (messagesRemaining == 0) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final l = S.of(context)!;
      setState(() {
        _messages.add(_ChatMessage(
          text: l.anonymousChatConversionPrompt,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _showAuthGate();
    }
  }

  void _showAuthGate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AuthGateBottomSheet(
        onAuthenticated: _onAuthenticated,
        onDismissed: _onDismissed,
      ),
    );
  }

  void _onDismissed() {
    setState(() {
      _isAuthGateLocked = true;
    });
  }

  Future<void> _onAuthenticated(String userId) async {
    // Save anonymous conversation to SharedPreferences (unprefixed) so the
    // migration in auth_provider picks it up and moves it to user namespace.
    // Then append the post-auth welcome message under the user prefix.
    try {
      final now = DateTime.now();
      final conversationId = 'anonymous_${now.millisecondsSinceEpoch}';

      // Convert local _ChatMessage list to ChatMessage for persistence.
      final chatMessages = _messages
          .map((m) => ChatMessage(
                role: m.isUser ? 'user' : 'assistant',
                content: m.text,
                timestamp: m.timestamp,
              ))
          .toList();

      // Save under anonymous (no prefix) — migration will re-key to user.
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      await store.saveConversation(conversationId, chatMessages);

      // Migration happens in auth_provider._migrateLocalDataIfNeeded()
      // which was already called during the auth flow. But since we just
      // saved the conversation AFTER auth completed, we need to migrate now.
      await ConversationStore.migrateAnonymousToUser(userId);

      // Append welcome message under user prefix.
      ConversationStore.setCurrentUserId(userId);
      chatMessages.add(ChatMessage(
        role: 'assistant',
        content: 'Maintenant je me souviendrai de tout.',
        timestamp: DateTime.now(),
      ));
      await store.saveConversation(conversationId, chatMessages);
    } catch (e) {
      // Best-effort — never block navigation to home.
      debugPrint('[AnonymousChat] Post-auth save failed: $e');
    }

    if (mounted) context.go('/home');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.craie,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — back button only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: MintColors.textPrimary,
                  onPressed: () => context.go('/'),
                  tooltip: l.anonymousChatBack,
                ),
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // Loading indicator
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // Locked state — persistent CTA
            if (_isAuthGateLocked) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: MintColors.lightBorder),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      l.anonymousChatLocked,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showAuthGate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MintColors.primary,
                          foregroundColor: MintColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.anonymousChatCreateAccount,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],

            // Input bar — hidden when locked
            if (!_isAuthGateLocked)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: MintColors.craie,
                  border: Border(
                    top: BorderSide(color: MintColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _isLoading ? null : _sendMessage,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: MintColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l.anonymousIntentFreeTextHint,
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: MintColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: _isLoading
                          ? MintColors.textMuted
                          : MintColors.primary,
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(_inputController.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? MintColors.primary : MintColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isUser ? MintColors.white : MintColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _TypingDot(delay: i * 200),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Animated dot for typing indicator.
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: MintColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
