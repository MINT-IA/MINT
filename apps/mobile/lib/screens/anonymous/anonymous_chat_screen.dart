import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, LengthLimitingTextInputFormatter;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/anonymous/eclairage_card.dart';
import 'package:mint_mobile/widgets/auth/auth_gate_bottom_sheet.dart';

/// Data class for a single chat message in the anonymous flow.
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Phase 72 — optional `eclairage` payload attached to the coach
  /// response that delivered it. When non-null, the [_EclairageCard] is
  /// rendered immediately below this bubble in the messages list.
  final Map<String, dynamic>? eclairage;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.eclairage,
  });
}

/// Full-screen anonymous chat overlay — chat-first Cleo-grade redesign
/// (Phase 71a, panel-locked spec 2026-05-05).
///
/// Cold-open : single coach opener bubble (Flutter const, i18n) fades in
/// 400ms after first paint, plus 3 horizontal chip-suggestions and an
/// always-visible LSFin disclaimer above the input bar. No felt-pills
/// upstream, no wedge salary teaser, no auto-focus on input.
///
/// User can send messages until the auth gate fires (after 3rd coach
/// response). Dismissing the gate locks input but preserves conversation.
class AnonymousChatScreen extends StatefulWidget {
  /// The optional `intent` query-param from a deep link or back-compat
  /// caller. When non-null + non-empty, auto-sends as the first user
  /// message after build.
  final String? intent;

  const AnonymousChatScreen({super.key, this.intent});

  @override
  State<AnonymousChatScreen> createState() => _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends State<AnonymousChatScreen>
    with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _conversationId =
      'anonymous_${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoading = false;
  bool _isAuthGateLocked = false;
  bool _intentSent = false;

  // ── Phase 71a state machine (panel §4) ─────────────────────────────
  /// Whether the cold-open coach opener bubble has been added to
  /// `_messages`. Set true after `_addOpenerIfNeeded`. Drives the chips
  /// visibility (chips show only while `_messages.length <= 1`, which is
  /// equivalent to "opener present, no user reply yet").
  bool _openerShown = false;

  /// Whether an `eclairage` payload has been delivered to the user. Used
  /// by the ECL-01 gate (turns ≥ 2). Reset only on cold-restore that
  /// finds an existing eclairage in the persisted conversation (out of
  /// scope for Phase 71a — backend payload lands Phase 71b).
  bool _eclairageDelivered = false;

  /// Number of completed coach responses in the current session. Increments
  /// only after `_messages.add(coach response)` — not on user-send, not
  /// on error. ECL-01 fires when `_coachTurnsCompleted >= 2 &&
  /// !_eclairageDelivered` (gate read is Phase 71b backend integration).
  // ignore: unused_field
  int _coachTurnsCompleted = 0;

  // Opener fade-in animation controller (400ms, panel §1).
  late final AnimationController _openerFadeController;

  @override
  void initState() {
    super.initState();
    _openerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Kick off the cold-open / restore sequence after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _hydrateFromStoreOrShowOpener();

      // Back-compat: if an `intent` arrived as query param, auto-send it.
      // Untouched per panel §8.4.
      if (widget.intent != null &&
          widget.intent!.isNotEmpty &&
          !_intentSent) {
        _intentSent = true;
        _sendMessage(widget.intent!);
      }
    });
  }

  /// Cold-restore vs cold-open hydration.
  ///
  /// On entry, look up the latest anonymous conversation in
  /// `ConversationStore`. If messages exist, hydrate `_messages` from them
  /// and skip the opener+chips (panel §5 row 4). Otherwise, render the
  /// opener bubble with a 400ms fade-in.
  Future<void> _hydrateFromStoreOrShowOpener() async {
    ConversationStore.setCurrentUserId(null);
    final store = ConversationStore();
    final convos = await store.listConversations();
    // Pick the most recent anonymous conversation, if any.
    if (convos.isNotEmpty) {
      final latestId = convos.first.id;
      final restored = await store.loadConversation(latestId);
      if (restored.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(restored.map(
            (m) => _ChatMessage(
              text: m.content,
              isUser: m.role == 'user',
              timestamp: m.timestamp,
            ),
          ));
          // Conversation already had user-coach exchanges; opener should
          // not re-appear. Mark openerShown so chips also stay hidden.
          _openerShown = true;
          _coachTurnsCompleted = restored.where((m) => m.role == 'assistant').length;
        });
        _scrollToBottom();
        return;
      }
    }
    _addOpenerIfNeeded();
  }

  /// Add the static (Flutter const) coach opener bubble + start the 400ms
  /// fade-in. Panel §2 — NOT backend-generated (network-failure resistant).
  void _addOpenerIfNeeded() {
    if (_openerShown || _messages.isNotEmpty) return;
    final l = S.of(context)!;
    setState(() {
      _messages.add(_ChatMessage(
        text: l.anonymousChatOpener,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _openerShown = true;
    });
    _openerFadeController.forward();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _openerFadeController.dispose();
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
    final errorType = response['errorType'] as String?;

    if (isError || coachMessage.isEmpty) {
      // Walk 2026-04-24 P0-2: map errorType → specific ARB copy.
      final l = S.of(context)!;
      final text = switch (errorType) {
        'network' => l.anonymousChatErrorNetwork,
        'service' => l.anonymousChatErrorService,
        'session' => l.anonymousChatErrorSession,
        _ => l.anonymousChatError,
      };
      setState(() {
        _messages.add(_ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    // Phase 72 panel §4: parse `eclairage` payload (Phase 71b backend
    // populates this field). Attach it to the coach message that
    // delivered it so the card renders inline immediately below.
    final rawEclairage = response['eclairage'];
    Map<String, dynamic>? eclairagePayload;
    if (rawEclairage is Map<String, dynamic> && !_eclairageDelivered) {
      eclairagePayload = rawEclairage;
      _eclairageDelivered = true;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: coachMessage,
        isUser: false,
        timestamp: DateTime.now(),
        eclairage: eclairagePayload,
      ));
      _isLoading = false;
      // Phase 71a panel §4: increment ONLY after a real coach response.
      _coachTurnsCompleted += 1;
    });
    _scrollToBottom();

    // Persist eagerly after each coach response so messages survive navigation.
    _persistToSharedPreferences();

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

      _persistToSharedPreferences();

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
        onDismissed: _onDismissed,
      ),
    );
  }

  void _onDismissed() {
    setState(() {
      _isAuthGateLocked = true;
    });
  }

  /// Persist anonymous messages to SharedPreferences (unprefixed keys).
  /// Fire-and-forget — never blocks UI.
  void _persistToSharedPreferences() {
    final chatMessages = _messages
        .map((m) => ChatMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
              timestamp: m.timestamp,
            ))
        .toList();

    ConversationStore.setCurrentUserId(null);
    ConversationStore().saveConversation(_conversationId, chatMessages).catchError((e) {
      debugPrint('[AnonymousChat] Eager persist failed: $e');
    });
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

  /// Pre-fill the input field with the chip text and request focus.
  /// Per panel §3, NO auto-send. The chips fade out once a user message
  /// is sent (driven by `_messages.length <= 1` visibility predicate).
  void _onChipTap(String chipText) {
    HapticFeedback.selectionClick();
    setState(() {
      _inputController.text = chipText;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: chipText.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // Chips visibility predicate (panel §1 + §3) :
    //   • opener has been shown (so we don't render chips on cold-restore)
    //   • exactly one bubble in the list (the opener) — once user sends
    //     a message, _messages.length >= 2, chips disappear.
    //   • not locked.
    final showChips = _openerShown &&
        _messages.length <= 1 &&
        !_isAuthGateLocked;

    return Scaffold(
      backgroundColor: MintColors.craieHandoff,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — back button only (panel §1.1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: MintColors.inkPrimary,
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
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  final isOpener = index == 0 && _openerShown;
                  // Phase 72: render the bubble + (optionally) the
                  // EclairageCard immediately below it when this coach
                  // message delivered an `eclairage` payload.
                  final bubble = _buildMessageBubble(msg, isOpener: isOpener);
                  if (msg.eclairage == null) {
                    return bubble;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      bubble,
                      EclairageCard(payload: msg.eclairage!),
                    ],
                  );
                },
              ),
            ),

            // Chip-suggestions row (panel §1.3 + §3)
            if (showChips) _buildChipsRow(l),

            // Locked state — persistent CTA (unchanged from previous design)
            if (_isAuthGateLocked) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: MintColors.borderSubtle),
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
                          backgroundColor: MintColors.inkPrimary,
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

            // LSFin disclaimer + input bar (panel §1.4 + §1.5)
            if (!_isAuthGateLocked) _buildDisclaimerAndInput(l),
          ],
        ),
      ),
    );
  }

  /// Chips row (panel §1.3) — 3 outlined chips horizontally scrollable.
  Widget _buildChipsRow(S l) {
    final chips = [l.anonymousChatChip1, l.anonymousChatChip2, l.anonymousChatChip3];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return Center(
            child: Semantics(
              label: chips[i],
              button: true,
              child: InkWell(
                onTap: () => _onChipTap(chips[i]),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: MintColors.craieHandoff,
                    border: Border.all(color: MintColors.borderSubtle, width: 1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    chips[i],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MintColors.inkPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Disclaimer line + input bar (panel §1.4 + §1.5).
  Widget _buildDisclaimerAndInput(S l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LSFin disclaimer (always visible per panel §1.4)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Text(
            l.anonymousChatLsfinDisclaimer,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: MintColors.textMutedAaa,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          decoration: const BoxDecoration(
            color: MintColors.craieHandoff,
            border: Border(
              top: BorderSide(color: MintColors.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_isLoading,
                  // Panel §1.5 + §5 row 5 : autofocus OFF on cold-open.
                  autofocus: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isLoading ? null : _sendMessage,
                  // Panel §5 row 2 : hard cap at 500 chars (paste-defence).
                  maxLength: 500,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: MintColors.inkPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: l.anonymousChatInputHint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: MintColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    // Hide counter unless > 400 chars (panel §5 row 2).
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: _isLoading
                    ? MintColors.textMutedAaa
                    : MintColors.inkPrimary,
                onPressed: _isLoading
                    ? null
                    : () => _sendMessage(_inputController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, {bool isOpener = false}) {
    final isUser = message.isUser;
    final bubble = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? MintColors.inkPrimary : MintColors.craieHandoff,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Text(
            message.text,
            style: isOpener
                // Panel §1.2 — opener uses Fraunces 16/1.45 inkPrimary.
                ? GoogleFonts.fraunces(
                    fontSize: 16,
                    color: MintColors.inkPrimary,
                    height: 1.45,
                  )
                : GoogleFonts.inter(
                    fontSize: 15,
                    color: isUser ? MintColors.white : MintColors.inkPrimary,
                    height: 1.4,
                  ),
          ),
        ),
      ),
    );

    // 400ms fade-in only for the opener (panel §1.2).
    if (isOpener) {
      return FadeTransition(
        opacity: _openerFadeController,
        child: bubble,
      );
    }
    return bubble;
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: MintColors.craieHandoff,
            borderRadius: BorderRadius.only(
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
