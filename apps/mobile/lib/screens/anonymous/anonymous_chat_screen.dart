import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, LengthLimitingTextInputFormatter;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/eclairage_models.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
// ADR-20260223: financial_core via barrel only — no direct sub-imports.
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/anonymous/eclairage_card.dart';
import 'package:mint_mobile/widgets/auth/auth_gate_bottom_sheet.dart';
// v2.12 Phase 86 — `widgets/coach/eclairage_card.dart` was a Phase 80
// duplicate of the panel-locked Phase 72 widget at
// widgets/anonymous/eclairage_card.dart. Deleted in this integration
// to resolve the « EclairageCard imported from both » build error.

/// Data class for a single chat message in the anonymous flow.
///
/// Phase 80 (v2.11): coach messages may carry an [eclairage] card rendered
/// inline beneath the text bubble. When the dart-define
/// `MINT_E2E_FORCE_ECLAIRAGE_KIND` is set, the card kind is forced via
/// [ChatToolDispatcher.dispatchEclairagePayload].
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Optional eclairage card attached to this coach message (Phase 80).
  /// Always null on user messages.
  final EclairageCardData? eclairage;

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

  /// Test-only override for the `/anonymous/chat` round-trip. When non-null,
  /// [_sendMessage] calls this instead of [CoachChatApiService]. Lets the
  /// ECL-01 gate widget tests (hotfix 2026-06-12) drive deterministic coach
  /// responses carrying an `eclairage` payload without a live backend or an
  /// HTTP mock seam (MintHttpClient.shared is a final static). Always null in
  /// production — the default branch hits the real service.
  @visibleForTesting
  final Future<Map<String, dynamic>> Function(String message)? sendOverride;

  const AnonymousChatScreen({super.key, this.intent, this.sendOverride});

  @override
  State<AnonymousChatScreen> createState() => _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends State<AnonymousChatScreen>
    with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _conversationId = _newConversationId();
  bool _isLoading = false;
  bool _isAuthGateLocked = false;
  // Holds a message typed while the previous coach turn is still in flight.
  // Without it, the second-fast Enter press is silently dropped by the
  // `onSubmitted` guard, breaking the 3-message → auth-gate path
  // (cassure #4, 2026-05-13). Single slot — only the most recent attempted
  // submission is kept; older queued text is overwritten by intent.
  String? _queuedMessage;
  bool _intentSent = false;

  // ── Phase 71a state machine (panel §4) ─────────────────────────────
  /// Whether the cold-open coach opener bubble has been added to
  /// `_messages`. Set true after `_addOpenerIfNeeded`. Drives the chips
  /// visibility (chips show only while `_messages.length <= 1`, which is
  /// equivalent to "opener present, no user reply yet").
  bool _openerShown = false;

  /// Whether an `eclairage` card has already been delivered in this
  /// conversation. Wired ECL-01 gate (hotfix 2026-06-12): once ANY coach
  /// turn has attached a Premier Éclairage card, every subsequent turn must
  /// NOT render another — the backend may (re)emit `response['eclairage']`
  /// across turns, and the walker / seed fallback path
  /// ([_resolveEclairageForTurn]) fires on every turn when a CoachProfileSeed
  /// is pinned. Without this gate the user saw two IDENTICAL cards in one
  /// conversation (device bug, sim iPhone 17 Pro).
  ///
  /// Set true the moment a card is attached to a coach message; restored from
  /// persisted messages on cold-restore (see [_hydrateFromStoreOrShowOpener]).
  bool _eclairageDelivered = false;
  bool _restoredConversation = false;

  /// Number of completed coach responses in the current session. Increments
  /// only after `_messages.add(coach response)` — not on user-send, not
  /// on error.
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
      if (widget.intent != null && widget.intent!.isNotEmpty && !_intentSent) {
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
        _conversationId = latestId;
        _openerFadeController.value = 1.0;
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
          final coachTurns =
              restored.where((m) => m.role == 'assistant').length;
          _coachTurnsCompleted = coachTurns;
          // ECL-01 restore (hotfix 2026-06-12): the Premier Éclairage card is
          // emitted by the backend once the conversation reaches ≥2 coach
          // turns (anonymous_chat.py: `new_count >= 2 && !eclairage_delivered`)
          // and is delivered exactly once. ConversationStore persists only the
          // bubble text, not the card payload, so a restored conversation that
          // already crossed that threshold must mark the gate as delivered —
          // otherwise the FIRST new turn after cold-restore would render a
          // second card.
          _eclairageDelivered = coachTurns >= 2;
          _restoredConversation = true;
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
    if (!mounted) return;
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

  Future<void> _startNewConversation() async {
    await ReportPersistenceService.clearConversationNamespace(userId: null);
    final canSend = await AnonymousSessionService.canSendMessage();
    if (!mounted) return;

    _conversationId = _newConversationId();
    _inputController.clear();
    _openerFadeController.reset();
    setState(() {
      _messages.clear();
      _isLoading = false;
      _isAuthGateLocked = !canSend;
      _queuedMessage = null;
      _openerShown = false;
      _eclairageDelivered = false;
      _coachTurnsCompleted = 0;
      _restoredConversation = false;
    });

    if (!canSend) {
      _showAuthGate();
      return;
    }
    _addOpenerIfNeeded();
    _scrollToBottom();
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

    // Cassure #4 fix (2026-05-13): if a prior coach turn is still in flight,
    // queue this submission instead of silently dropping it. The tail of
    // the current `_sendMessage` drains the queue. Fixes "user presses
    // Enter twice fast" + the Maestro E2E flow that hit auth-gate
    // because msg 3's Enter fired while msg 2 was still loading.
    if (_isLoading) {
      _queuedMessage = trimmed;
      return;
    }

    // Check if user can still send
    final canSend = await AnonymousSessionService.canSendMessage();
    if (!mounted) return;
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

    final response = widget.sendOverride != null
        ? await widget.sendOverride!(trimmed)
        : await CoachChatApiService.sendAnonymousMessage(
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
      _drainQueuedMessage();
      return;
    }

    // Phase 80 (v2.11): parse the eclairage payload from response['eclairage']
    // through ChatToolDispatcher so the MINT_E2E_FORCE_ECLAIRAGE_KIND
    // dart-define overrides the resolved kind in non-release builds (ECLW-01,
    // ECLW-04). Falls back to PremierEclairageSelector when no payload but
    // a forced kind + an active CoachProfileSeed are present (ECLW-02, ECLW-03).
    final eclairage = _resolveEclairageForTurn(response);

    setState(() {
      _messages.add(_ChatMessage(
        text: coachMessage,
        isUser: false,
        timestamp: DateTime.now(),
        eclairage: eclairage,
      ));
      _isLoading = false;
      // Phase 71a panel §4: increment ONLY after a real coach response.
      _coachTurnsCompleted += 1;
      // ECL-01 gate (hotfix 2026-06-12): latch the delivered flag the moment a
      // card is attached so no later turn renders a duplicate.
      if (eclairage != null) _eclairageDelivered = true;
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
    _drainQueuedMessage();
  }

  /// Fires a queued message that was typed while a previous coach turn
  /// was still loading. See cassure #4 (2026-05-13).
  void _drainQueuedMessage() {
    final next = _queuedMessage;
    _queuedMessage = null;
    if (next != null && next.isNotEmpty && mounted) {
      _sendMessage(next);
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
        redirectPath: _postAuthRedirectPath,
        onDismissed: _onDismissed,
      ),
    );
  }

  String get _postAuthRedirectPath {
    return Uri(
      path: '/coach/chat',
      queryParameters: {'conversationId': _conversationId},
    ).toString();
  }

  void _onDismissed() {
    setState(() {
      _isAuthGateLocked = true;
    });
  }

  /// Resolve the eclairage card to render alongside this coach turn — Phase 80.
  ///
  /// Decision tree (matches `ChatToolDispatcher.dispatchEclairagePayload`):
  ///   1. Read `response['eclairage']` (backend Phase 81 contract — once
  ///      shipped emits a structured map for archetype-pinned turns).
  ///   2. Run it through [ChatToolDispatcher.dispatchEclairagePayload] so
  ///      `MINT_E2E_FORCE_ECLAIRAGE_KIND` (debug builds only — ECLW-04
  ///      `kReleaseMode` guard) overrides the kind.
  ///   3. When the dispatcher returns null AND we have an active
  ///      [CoachProfileSeeds.activeSeed] (walker / widget-test runs with
  ///      `MINT_E2E_ARCHETYPE` pinned), invoke [PremierEclairageSelector]
  ///      to derive a fallback `PremierEclairage`, then up-shift it to an
  ///      [EclairageCardData] template (ECLW-03). This guarantees the
  ///      walker captures a real card even when the backend half of the
  ///      contract has not landed yet (Phase 81 sequencing).
  EclairageCardData? _resolveEclairageForTurn(Map<String, dynamic> response) {
    // ECL-01 gate (hotfix 2026-06-12): at most ONE Premier Éclairage card per
    // conversation. Once delivered, never render another — guards against the
    // backend (re)emitting `response['eclairage']` on later turns and against
    // the seed fallback below firing on every turn in walker / pinned-seed
    // builds.
    if (_eclairageDelivered) return null;

    final raw = response['eclairage'];
    final rawMap = raw is Map<String, dynamic>
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : null);

    final dispatched = ChatToolDispatcher.dispatchEclairagePayload(rawMap);
    if (dispatched != null) return dispatched;

    // Walker / widget-test fallback: when no backend payload AND no forced
    // kind, but a CoachProfileSeed is pinned via dart-define, run the
    // selector against the seed's MinimalProfileResult so PremierEclairage
    // V2 priorities (archetype × stress × lifecycle) drive the surface.
    final seed = CoachProfileSeeds.activeSeed;
    if (seed == null) return null;

    final profile = _seedToMinimalProfile(seed);
    final picked = PremierEclairageSelector.select(profile);
    return _premierToEclairageCard(picked);
  }

  /// Synthesize a [MinimalProfileResult] stub from a [CoachProfileSeed]
  /// good enough for [PremierEclairageSelector] to produce a deterministic
  /// fallback card. Avoids hitting the backend or financial_core wizard.
  MinimalProfileResult _seedToMinimalProfile(CoachProfileSeed seed) {
    final salary = seed.grossMonthlySalary;
    final annual = salary * 12;
    return MinimalProfileResult(
      avsMonthlyRente: 1800,
      lppAnnualRente: 18000,
      lppMonthlyRente: 1500,
      totalMonthlyRetirement: 3300,
      grossMonthlySalary: salary,
      replacementRate: 3300 / (salary > 0 ? salary : 1),
      retirementGapMonthly: salary > 3300 ? salary - 3300 : 0,
      taxSaving3a: 1800,
      marginalTaxRate: 0.28,
      currentSavings: 8000,
      estimatedMonthlyExpenses: salary * 0.65,
      monthlyDebtImpact: 0,
      liquidityMonths: 2.5,
      canton: seed.canton,
      age: seed.age,
      grossAnnualSalary: annual,
      householdType: 'single',
      isPropertyOwner: false,
      existing3a: 0,
      existingLpp: 35000,
      employmentStatus: 'salarie',
      // Audit fix 2026-05-09 (perimeter STUB
      // .planning/decisions/2026-05-09-perimeter-archetype-input-normalization/):
      // never assume Swiss-native for an anonymous user. Pass null so
      // PremierEclairageSelector / visibility scorer treat the
      // nationality as unknown rather than silently skipping every
      // expat / FATCA / cross-border code path.
      nationalityGroup: null,
      plafond3a: 7258,
      estimatedFields: const [
        'currentSavings',
        'existingLpp',
        'nationalityGroup'
      ],
    );
  }

  /// Map a [PremierEclairage] (legacy v1/v2 model) onto an
  /// [EclairageCardData] template so the unified card widget can render it.
  EclairageCardData? _premierToEclairageCard(PremierEclairage pe) {
    final kind = switch (pe.type) {
      PremierEclairageType.taxSaving3a => EclairageKind.fiscalMargin3a,
      PremierEclairageType.liquidityAlert => EclairageKind.liquidityRunway,
      PremierEclairageType.compoundGrowth => EclairageKind.compoundGrowthEdge,
      PremierEclairageType.retirementGap => EclairageKind.lppRachatWindow,
      PremierEclairageType.retirementIncome => EclairageKind.lppRachatWindow,
      PremierEclairageType.hourlyRate => EclairageKind.fiscalMargin3a,
    };
    return EclairageCardData.fromForcedKind(kind);
  }

  /// Persist anonymous messages to SharedPreferences (unprefixed keys) so
  /// auth_provider._migrateLocalDataIfNeeded() can find and migrate them
  /// after account creation, regardless of navigation path.
  ///
  /// Fire-and-forget — never blocks UI. Called after each coach response.
  void _persistToSharedPreferences() {
    final chatMessages = _messages
        .map((m) => ChatMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
              timestamp: m.timestamp,
            ))
        .toList();

    ConversationStore.setCurrentUserId(null);
    ConversationStore()
        .saveConversation(_conversationId, chatMessages)
        .catchError((e) {
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
    final showChips =
        _openerShown && _messages.length <= 1 && !_isAuthGateLocked;

    return Scaffold(
      backgroundColor: MintColors.craieHandoff,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — back button + restored-thread reset.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: MintColors.inkPrimary,
                    onPressed: () => context.go('/'),
                    tooltip: l.anonymousChatBack,
                  ),
                  const Spacer(),
                  if (_restoredConversation)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 210) {
                              return IconButton(
                                key: const ValueKey(
                                  'anonymous_chat_new_conversation',
                                ),
                                onPressed:
                                    _isLoading ? null : _startNewConversation,
                                icon: const Icon(Icons.add_comment_outlined),
                                color: MintColors.inkPrimary,
                                tooltip: l.anonymousChatNewConversation,
                              );
                            }
                            return TextButton.icon(
                              key: const ValueKey(
                                'anonymous_chat_new_conversation',
                              ),
                              onPressed:
                                  _isLoading ? null : _startNewConversation,
                              icon: const Icon(
                                Icons.add_comment_outlined,
                                size: 18,
                              ),
                              label: Text(
                                l.anonymousChatNewConversation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: MintColors.inkPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  final isOpener = index == 0 && _openerShown;
                  // Phase 72: [_buildMessageBubble] already renders the
                  // EclairageCard immediately below the coach bubble when this
                  // message carries an `eclairage` payload (see the
                  // `message.eclairage != null` branch there). The ListView
                  // itemBuilder previously ALSO wrapped the bubble in a Column
                  // and re-rendered a second EclairageCard — producing TWO
                  // identical cards per turn (device bug, hotfix 2026-06-12).
                  // Return the bubble directly; the card render lives in one
                  // place only.
                  return _buildMessageBubble(msg, isOpener: isOpener);
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
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ).copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // lint-ignore: prefer_mint_cta
                        // Phase 97 W7 iter#12 L001 — stable Maestro locator.
                        // julien_swiss.yaml + lauren_expat_us.yaml step 05
                        // assertVisible {id: 'anon-chat-register-cta'}.
                        key: const Key('anon-chat-register-cta'),
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
                          style: MintTextStyles.labelLarge(
                            color: MintColors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
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
    final chips = [
      l.anonymousChatChip1,
      l.anonymousChatChip2,
      l.anonymousChatChip3
    ];
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: MintColors.craieHandoff,
                    border:
                        Border.all(color: MintColors.borderSubtle, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chips[i],
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.inkPrimary,
                    ).copyWith(fontWeight: FontWeight.w500),
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
            style: MintTextStyles.labelSmall(
              color: MintColors.textMutedAaa,
            ).copyWith(fontStyle: FontStyle.italic),
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
                  // Phase 97 W7 iter#12 L001 — stable Maestro locator.
                  // julien_swiss.yaml + lauren_expat_us.yaml depend on this.
                  key: const Key('anon-chat-input'),
                  controller: _inputController,
                  // Field stays editable during loading so a fast second
                  // Enter is captured by the queue inside `_sendMessage`
                  // instead of being silently dropped (cassure #4 fix).
                  // Visual loading feedback comes from the typing
                  // indicator + the greyed-out send button below.
                  enabled: true,
                  autofocus: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  // Panel §5 row 2 : hard cap at 500 chars (paste-defence).
                  maxLength: 500,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  style: MintTextStyles.bodyLarge(
                    color: MintColors.inkPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: l.anonymousChatInputHint,
                    hintStyle: MintTextStyles.bodyLarge(
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
    final bubble = Align(
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
        // obs #158 (2026-05-17) — coach LLM emits markdown bold (`**…**`),
        // italic (`_…_`), etc. The main coach surface
        // (`widgets/coach/coach_message_bubble.dart:89-118`) already renders
        // these via MarkdownBody. The anonymous chat surface was the orphan
        // raw-Text holdout — users were seeing literal asterisks. Mirror the
        // proven pattern from coach_message_bubble. Guard with `!isUser` so
        // user-typed bubbles stay plain text (users don't emit markdown ;
        // their input is echoed back via `Text(message.text)` in the user
        // branch to avoid markdown-injection via user message into the chat
        // surface).
        child: isUser
            ? Text(
                message.text,
                style: MintTextStyles.labelLarge(
                  color: MintColors.white,
                ).copyWith(fontWeight: FontWeight.w400),
              )
            : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: MintTextStyles.labelLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(fontWeight: FontWeight.w400, height: 1.45),
                  strong: MintTextStyles.labelLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.45),
                  em: MintTextStyles.labelLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                  listBullet: MintTextStyles.labelLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(fontWeight: FontWeight.w400, height: 1.45),
                  h3: MintTextStyles.labelLarge(
                    color: MintColors.inkPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize:
                        15, // lint-ignore: prefer_mint_text_style — h3 markdown needs +1pt above labelLarge (14pt)
                    height: 1.45,
                  ),
                ),
                shrinkWrap: true,
                softLineBreak: false,
                selectable: true,
              ),
      ),
    );

    // Phase 80: render the eclairage card inline beneath coach bubbles when
    // present. Forced via dart-define for walker / widget tests, otherwise
    // emitted by the backend (Phase 81 contract).
    //
    // Phase 97 W7 iter#12 L001 — stable Maestro locators for the anonymous
    // chat surface. The opener bubble (first coach message, isOpener=true)
    // gets 'anon-chat-opener-bubble' ; every subsequent coach bubble gets
    // 'anon-chat-message-assistant'. User bubbles stay key-less (Maestro
    // doesn't assert on them). Both keys are referenced by
    // tools/simulator/flows/{julien_swiss,lauren_expat_us}.yaml.
    final Key? assistantKey = isUser
        ? null
        : isOpener
            ? const Key('anon-chat-opener-bubble')
            : const Key('anon-chat-message-assistant');
    final renderedBubble = isOpener
        ? FadeTransition(
            opacity: _openerFadeController,
            child: bubble,
          )
        : bubble;

    if (message.eclairage == null) {
      return Padding(
        key: assistantKey,
        padding: const EdgeInsets.only(bottom: 12),
        child: renderedBubble,
      );
    }

    return Padding(
      key: assistantKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          renderedBubble,
          // v2.12 Phase 86 integration — convert EclairageCardData →
          // Map<String, dynamic> payload to feed the panel-locked Phase
          // 72 EclairageCard widget (anon path). Phase 80's typed
          // eclairage_models.dart stays the canonical model ; we just
          // adapt at the render boundary.
          EclairageCard(payload: <String, dynamic>{
            'kind': message.eclairage!.kind.wireName,
            'headline': message.eclairage!.headline,
            'body': message.eclairage!.body,
            'chf_range_low': message.eclairage!.chfRangeLow,
            'chf_range_high': message.eclairage!.chfRangeHigh,
            'chf_range_period': message.eclairage!.chfRangePeriod,
            'soft_account_hint': message.eclairage!.softAccountHint,
            'lsfin_disclaimer': message.eclairage!.lsfinDisclaimer,
          }),
        ],
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

String _newConversationId() =>
    'anonymous_${DateTime.now().millisecondsSinceEpoch}';

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
